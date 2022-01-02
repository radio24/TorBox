#!/usr/bin/python3
# -*- coding: utf-8 -*-

# This file is part of TorBox, an easy to use anonymizing router based on Raspberry Pi.
# Copyright (C) 2022 Patrick Truffer
# Contact: anonym@torbox.ch
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it is useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>.
#
# DESCRIPTION
# This file contains the Python 3 class "wireless_manager", which is used
# by the Torbox Wireless Manager.

import os
import re
import subprocess
import time
import urwid
import asyncio

class WirelessManagerScanner:
    """Scan wifi networks and return the result as a list"""

    networks = {}

    def __init__(self, interface):
        # Interface to work
        self.interface = interface

        # Frequency of channels
        self.channel_freq = {
            2: 2417,
            3: 2422,
            1: 2412,
            5: 2432,
            6: 2437,
            7: 2442,
            4: 2427,
            8: 2447,
            9: 2452,
            10: 2457,
            11: 2462,
            12: 2467,
            13: 2472,
            14: 2484
        }

        self.channel_freq_5ghz = {
            7: 5035,
            8: 5040,
            9: 5045,
            11: 5055,
            12: 5060,
            16: 5080,
            32: 5160,
            34: 5170,
            36: 5180,
            38: 5190,
            40: 5200,
            42: 5210,
            44: 5220,
            46: 5230,
            48: 5240,
            50: 5250,
            52: 5260,
            54: 5270,
            56: 5280,
            58: 5290,
            60: 5300,
            62: 5310,
            64: 5320,
            68: 5340,
            96: 5480,
            100: 5500,
            102: 5510,
            104: 5520,
            106: 5530,
            108: 5540,
            110: 5550,
            112: 5560,
            114: 5570,
            116: 5580,
            118: 5590,
            120: 5600,
            122: 5610,
            124: 5620,
            126: 5630,
            128: 5640,
            132: 5660,
            134: 5670,
            136: 5680,
            138: 5690,
            140: 5700,
            142: 5710,
            144: 5720,
            149: 5745,
            151: 5755,
            153: 5765,
            155: 5775,
            157: 5785,
            159: 5795,
            161: 5805,
            165: 5825,
            169: 5845,
            173: 5865,
            183: 4915,
            184: 4920,
            185: 4925,
            187: 4935,
            188: 4940,
            189: 4945,
            192: 4960,
            196: 4980
        }

        # Flag for hidden networks scan
        self.keep_scanning = True

    def scan(self):
        # scan
        cmd = "wpa_cli", "-i", self.interface, "scan"
        cmd = subprocess.check_output(cmd, stderr=subprocess.DEVNULL)
        time.sleep(1)

        # NOTE: sometimes wpa_cli doesn't scan at the 1st time,
        # so we run it 2 times.
        cmd = "wpa_cli", "-i", self.interface, "scan"
        cmd = subprocess.check_output(cmd, stderr=subprocess.DEVNULL)

        # Process scan result
        cmd = ["wpa_cli", "-i", self.interface, "scan_results"]
        cmd = subprocess.check_output(cmd, stderr=subprocess.DEVNULL)
        r = cmd.strip().split(b"\n")

        # Remove headers from response
        r.remove(r[0])

        # sort the list
        output = []
        for line in r:
            c = line.split(b"\t")

            # Net MAC
            bssid = c[0].decode('utf-8')
            
            # Net Channel
            try:
                channel	= [
                        k for k, v in self.channel_freq.items()\
                            if v == int(c[1])
                        ][0]
            except:
                try:
                    channel = [
                            k for k, v in self.channel_freq_5ghz.items()\
                                if v == int(c[1])
                            ][0]
                except:
                    channel = '?'

            # Net dbm
            dbm_signal = c[2].decode('utf-8')

            # Net Quality
            quality = 2 * (int(c[2]) + 100)
            if quality > 100:
                quality = 100

            # Net Security
            security = c[3].decode('utf-8')
            q = re.search(r'\[(.*?)\]', security)
            security = q[0]

            # Net Name
            try:
                essid		= c[4].decode('utf-8')
            except:
                essid		= '?'
            
            output.append([essid, quality, security, bssid, channel, dbm_signal])
            #0        essid,
            #1        quality,
            #2        security,
            #3        bssid,
            #4        channel,
            #5        dbm_signal

        # Sort by signal strength
        output.sort(key=lambda x: x[1], reverse=True)

        return output


class WirelessManager:

    # Flags counting scanning between different methods inside the class
    scan_times_current = 1
    scan_times = 3

    network_list = []
    network_list_hidden = []
    network_list_hidden_show = False


    # Default color palette
    _palette = [
        ("column_headers",          "white, bold",      ""),
        ("reveal_focus",            "black",            "dark cyan",    "standout"),
        ("reveal_focus_hidden",     "black",            "light gray",    "standout"),
        ("start_msg",               "white, bold",      "",             "standout"),
        ("network_status_off",      "dark red, bold",   ""),
        ("network_status_on",       "light green, bold",""),
        ("connect_title",           "light red",        "light gray"),
        ("connect_title_divider",   "black",            "light gray"),
        ("connect_ask_focus",       "black",            "light cyan"),
        ("connect_ask",             "black",            "light gray"),
        ("connect_input",           "white",            "dark blue"),
        ("connect_button_connect",  "white, bold",      "dark red"),
        ("connect_button_cancel",   "white, bold",      "dark red"),
        ("connect_buttons",         "black",            "light gray"),
        ("connect_wrong_pass",      "yellow",           "dark red"),
        ("scanning",                "white",            "dark cyan"),
        ("scanning_hidden",         "white",            "brown"),
        ("connecting",              "white",            "dark cyan"),
    ]

    def __init__(self, interface='wlan0', autoconnect=False):
        """TWM will manage wireless connections using wpa_supplicant, it uses
        one config for each interface used"""

        # Interface to use
        self.interface = interface

        # wpa_supplicant log
        self.wpa_logfile = "/var/log/tor/twm-%s.log"% self.interface
        open(self.wpa_logfile, 'w+').close()  # Clean/create wpa_logfile

        # wifi scanner
        self.scanner = WirelessManagerScanner(self.interface)

        # config for wpa_supplicant
        wpa_config = "/etc/wpa_supplicant/wpa_supplicant-%s.conf" % self.interface
        if not os.path.isfile(wpa_config):
            with open(wpa_config, 'w+') as f:
                f.write("ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev\n")
                f.write("update_config=1\n")

        # Start wpa_supplicant
        cmd = [
                "wpa_supplicant",
                "-i",
                self.interface,
                "-c",
                wpa_config,
                "-B",
                #"-D", # use wext driver
                #"wext", # use wext driver
                "-f",
                self.wpa_logfile
            ]
        self.ws = subprocess.Popen(cmd)
        self.ws.wait()

        if autoconnect is True:
            """when autoconnect flag is True, we return 1 or 0 based on result"""

            # Disable dhcp connection from current interface
            cmd = ["dhclient", "-r", self.interface]
            n = subprocess.check_call(cmd,
                                      stdout=subprocess.DEVNULL,
                                      stderr=subprocess.DEVNULL)

            # Check if we got connect by wpa_supplicant
            # run dhcp for getting ip
            cmd = ["dhclient", self.interface]
            n = subprocess.check_call(cmd,
                                      stdout=subprocess.DEVNULL,
                                      stderr=subprocess.DEVNULL)

            # Give some time to dhclient
            time.sleep(5)

            # Check if it's connected
            if self.__is_connected() is True:
                print('1')
            else:
                print('0')

            quit()

        urwid.set_encoding("UTF-8")

        # Starting UI
        _start_box = urwid.Text('Starting....', 'center')
        _start_box = urwid.Filler( _start_box, valign="middle", top=1, bottom=1 )
        _start_box = urwid.AttrMap( _start_box, 'start_msg' )

        widget = self.__get_container(_start_box, True, False)

        # Async eventloop
        self._async_loop = asyncio.get_event_loop()
        self._event_loop = urwid.AsyncioEventLoop(loop=self._async_loop)

        # urwid main loop
        self.loop = urwid.MainLoop(widget,
                                   self._palette,
                                   unhandled_input = self.__manage_hotkeys,
                                   event_loop = self._event_loop)

        #self.loop.set_alarm_in(0.1, self.scan, user_data=[False])
        self.loop.set_alarm_in(0.1, self.scan)

    def __manage_hotkeys(self, key):
        # (Q) QUIT
        if key in ('Q', 'q'):
            # Exit urwid
            raise urwid.ExitMainLoop()

        # (R) Refresh network list
        if key in ('R','r'):
            self.scan()

        # (H) Show/hide Hidden networks
        if key in ('H','h'):
            self.__hidden_network_toggle()

        # (D) Disconnect from network
        #if key in ('D','d'):
        #    self.__disconnect()

    def __hidden_network_toggle(self):
        # Check if we have hidden networks to show
        if len(self.network_list_hidden):
            self.network_list_hidden_show = not self.network_list_hidden_show
            self.loop.set_alarm_in(0.1,
                                self.__network_scan_list,
                                user_data=[self.network_list_hidden_show])
        else:
            # Inform that there are no hidden networks
            _header = urwid.Text('TorBox Wireless Manager', align = 'center')
            _header = urwid.AttrMap(_header, 'connect_title')

            _divider = urwid.Divider('-')
            _divider = urwid.AttrMap(_divider, 'connect_title_divider')
            _header = urwid.Pile([_divider,
                                _header,
                                _divider])

            _text = urwid.Text('No hidden networks found.',
                                align='center')
            _text = urwid.AttrMap(_text, 'connect_wrong_pass')
            _text = urwid.Padding(_text,
                                align='center',
                                left=15,
                                right=15,
                                min_width=20)

            _text = urwid.Pile([urwid.Divider(' '),
                                _text,
                                urwid.Divider(' ')])

            # buttons
            _button_cancel = urwid.Button('OK', self.__network_scan_list)
            _button_cancel = urwid.AttrMap(
                    _button_cancel,
                    "connect_buttons",
                    "connect_button_connect"
                )
            _button_cancel = urwid.Padding(
                    _button_cancel,
                    align='center',
                    left=5,
                    min_width=15
                )

            _button = urwid.Columns([_button_cancel])
            _button = urwid.Padding(
                    _button, align='center',
                    left=30,
                    right=30,
                    min_width=15
                )
            _button = urwid.AttrMap(_button, 'connect_buttons')

            _body = urwid.Pile([
                _header,
                _text,
                _button,
                _divider
            ])

            _body = urwid.Filler(_body)
            _body = urwid.AttrMap(_body, 'connect_ask')

            _connect_box = urwid.Frame(
                _body,
                header=urwid.Divider(' '),
                focus_part='body'
            )

            # Create a popup
            overlay = urwid.Overlay(
                _connect_box,
                self.loop.widget,
                align = 'center',
                valign = 'middle',
                width = ('relative', 35),
                height = ('relative', 20),
                min_width = 35,
                min_height = 9
            )

            self.loop.widget = overlay

    def __disconnect(self):
        """Disconnect from any network"""

        cmd = ["dhclient", "-r", self.interface]
        n = subprocess.check_call(cmd,
                                  stdout=subprocess.DEVNULL,
                                  stderr=subprocess.DEVNULL)

        cmd = ["wpa_cli", "-i", self.interface, "disconnect"]
        r = subprocess.check_call(cmd,
                                  stdout=subprocess.DEVNULL,
                                  stderr=subprocess.DEVNULL)

    def __is_connected(self):
        """ Check if wireless connection is active """
        try:
            cmd = ["wpa_cli", "-i", self.interface, "status"]
            output = subprocess.check_output(cmd)
            output = output.decode("utf-8")
            output = output.split("\n")
            status = output[8].split("=")[1]

            # Connected
            if status == 'COMPLETED':
                self.connected = True
            else:
                self.connected = False
        except:
            self.connected = False

        return self.connected

    def __get_header(self, r=True):
        """Header for container. It includes title of program"""
        if r:
            header = urwid.Pile([
                urwid.Divider('-'),
                urwid.Text('TorBox Wireless Manager', 'center'),
                urwid.Divider('-'),
            ])

        return header

    def __get_footer(self, r=True):
        """Footer for container. It includes hot keys and connection information"""
        if r:
            try:
                cmd = ["wpa_cli", "-i", self.interface, "status"]
                output = subprocess.check_output(cmd)
                output = output.decode("utf-8")
                output = output.split("\n")

                ssid = status = ip_addr = '-'
                for line in output:
                    if line:
                        key, val = line.split("=")
                        if key == 'ssid':
                            ssid = val
                        if key == 'wpa_state':
                            status = val
                        if key == 'ip_address':
                            ip_addr = val

                if status == 'COMPLETED':
                    # Connected
                    _netstatus = urwid.AttrMap(
                            urwid.Text('Connected: %s [%s]' % (ssid, ip_addr)),
                            'network_status_on'
                        )
                    self.connected = True
                else:
                    # Not connected
                    _netstatus = urwid.AttrMap(
                            urwid.Text('Not connected'),
                            'network_status_off'
                        )
                    self.connected = False
            except:
                # Not connected on exceptions
                _netstatus = urwid.AttrMap(
                        urwid.Text('Not connected'),
                        'network_status_off'
                    )
                self.connected = False

            _footer = urwid.Pile([
                    urwid.Text(
                            '[ENTER]: Connect | [R]efresh | [H]idden | [Q]uit',
                            align="center"
                        ),
                    _netstatus
                ])
            return _footer

    def __get_container(self, widget, header=True, footer=True):
        """Default container. It can be with or without header and footer"""
        _frame = urwid.Frame(
            widget,
            header = self.__get_header(header),
            footer = self.__get_footer(footer)
        )
        return _frame

    def __network_scan_list(self, _loop=object, _data=[False]):
        """Show network list after scan is done"""

        hidden_show = _data[0]

        terminal_cols, terminal_rows = urwid.raw_display.Screen()\
                                        .get_cols_rows()

        # Headers columns
        _headers = ["SSID", "%", "Sec", "MAC", "CH", "dBm"]
        _network_header = urwid.AttrMap(
                urwid.Columns(
                        [urwid.Text(c) for c in _headers]
                    ),
                "network_header"
            )

        # Networks found
        if hidden_show:
            network_list = self.network_list_hidden
        else:
            network_list = self.network_list

        _netlist = []
        for network in network_list:
            row = SelectableRow(network, hidden_show, self.__connect_network)
            _netlist.append(row)

        _netlist = urwid.ListBox(urwid.SimpleFocusListWalker(_netlist))

        _pile = urwid.Pile([
            urwid.Text('Networks found:'),
            urwid.Divider('-'),
            _network_header,
            urwid.Divider('-'),
            # 9 rows used by container
            urwid.BoxAdapter(_netlist, terminal_rows-9),
        ])

        _widget = urwid.Filler(_pile)
        _widget = self.__get_container(_widget)

        self.loop.widget = _widget

    def __connect_network(self, network):
        """
        If network is already configured  connect without asking password
        If security is ESS, we don't ask for password
        """
        essid = network[0]
        bssid = network[3]
        security = network[2]

        # Look for saved networks
        cmd = "wpa_cli -i %s list_networks |grep '%s'" % (self.interface, bssid)
        n = subprocess.Popen(cmd,
                             shell=True,
                             stdout=subprocess.PIPE,
                             stderr=subprocess.DEVNULL)
        
        _str = n.communicate()[0]

        # Check if we have network id from wpa_cli
        try:
            network_id = _str.strip().split(b"\t")[0]
            network_id = int(network_id)
            self.__disconnect()
        except:
            network_id = False

        # If no network id, the network is not saved, we open connect
        # dialog (ask password) if it's not ESS (free wifi)
        if network_id is False and security != '[ESS]':
            self.__connect_dialog(network)
        # Otherwise, we try to connect without asking password
        # (free wifi and saved networks)
        else:
            _text = urwid.Text(
                    'Connecting to [%s]. Please wait...' % (essid),
                    align='center'
                )
            _text = urwid.AttrMap(_text, 'connecting')

            _body = urwid.Pile([
                _text
            ])

            _body = urwid.Filler(_body)
            _body = urwid.AttrMap(_body, 'connecting')

            _connect_box = urwid.Frame(
                _body,
                header=urwid.Divider(' '),
                focus_part='body'
            )

            # store actual widget
            self.last_widget = self.loop.widget

            # Create a popup
            overlay = urwid.Overlay(
                _connect_box,
                self.loop.widget,
                align = 'center',
                valign = 'middle',
                width = ('relative', 35),
                height = ('relative', 9),
                min_height = 6
            )

            self.loop.widget = overlay
            self.loop.set_alarm_in(
                    0.1,
                    self.__network_connect,
                    user_data=[essid, bssid, False, False, network_id]
                )

    def __connect_dialog(self, network, widget=False):
        """Show dialog for connecting to selected network"""

        # Network info
        essid = network[0]
        bssid = network[3]

        # Callbacks for buttons
        def _button_connect_callback(essid_input,
                                     bssid,
                                     pass_input,
                                     hidden_flag,
                                     widget):
            essid = essid_input.get_edit_text()
            password = pass_input.get_edit_text()
            self.loop.widget = self.last_widget

            if essid == '' or password == '':
                return

            _text = urwid.Text(
                    'Connecting to [%s]. Please wait...' % (essid),
                    align='center'
                )
            _text = urwid.AttrMap(_text, 'connecting')

            _body = urwid.Pile([
                _text
            ])

            _body = urwid.Filler(_body)
            _body = urwid.AttrMap(_body, 'connecting')

            _connect_box = urwid.Frame(
                _body,
                header=urwid.Divider(' '),
                focus_part='body'
            )

            # store actual widget
            self.last_widget = self.loop.widget

            # Create a popup
            overlay = urwid.Overlay(
                _connect_box,
                self.loop.widget,
                align = 'center',
                valign = 'middle',
                width = ('relative', 35),
                height = ('relative', 9),
                min_height = 6
            )

            self.loop.widget = overlay

            self.loop.set_alarm_in(
                    0.1,
                    self.__network_connect,
                    user_data=[essid, bssid, password, hidden_flag, False]
                )

        def _button_cancel_callback(widget):
            self.loop.widget = self.last_widget

        def connect_box_keypress(size, key):
            if key == 'esc':
                self.loop.widget = self.last_widget
            else:
                return urwid.Frame.keypress(self.connect_box, size, key)

        # Header
        _header = urwid.Text('Connect to [%s]' % essid, align = 'center')
        _header = urwid.AttrMap(_header, 'connect_title')
        _divider = urwid.Divider('-')
        _divider = urwid.AttrMap(_divider, 'connect_title_divider')
        _header = urwid.Pile([
            _divider,
            _header,
            _divider
        ])

        # Ask
        _ask_pass = urwid.Text('Enter password:', align="center")
        _ask_pass = urwid.AttrMap(_ask_pass, 'connect_ask', 'connect_ask_focus')

        # input
        _input_pass_edit = urwid.Edit('', align="center", multiline=True)
        _input_pass = urwid.AttrMap(_input_pass_edit, "connect_input")
        _input_pass = urwid.Padding(
                _input_pass,
                left=15,
                right=15,
                min_width=15
            )
        # When pressing return, we connect
        def _pass_edit_change(widget, text):
            if text.endswith('\n'):
                _input_pass_edit.set_edit_text(text.strip('\n'))
                _button_connect_callback(_input_essid_edit,
                                         bssid,
                                         _input_pass_edit,
                                         _hidden_flag,
                                         self.loop.widget)
                return
        urwid.connect_signal(_input_pass_edit, 'change', _pass_edit_change)

        body = urwid.Pile([
            _ask_pass,
            _input_pass,
        ])

        # input
        _input_essid_edit = urwid.Edit('', align="center", edit_text=essid)
        _input_essid = urwid.AttrMap(_input_essid_edit, "connect_input")
        _input_essid = urwid.Padding(
                _input_essid,
                left=15,
                right=15,
                min_width=15
            )

        _hidden_flag = False
        if essid == '-HIDDEN-':
            _hidden_flag = True
            # Ask ESSID
            _input_essid_edit.set_edit_text('')
            _ask_essid = urwid.Text('ESSID Name:', align="center")
            _ask_essid = urwid.AttrMap(
                    _ask_essid,
                    'connect_ask',
                    'connect_ask_focus'
                )

            body = urwid.Pile([
                _ask_essid,
                _input_essid,
                _ask_pass,
                _input_pass,
            ])

        body = urwid.Filler(body)
        body = urwid.AttrMap(body, 'connect_ask')

        _footer = urwid.Pile([
            _divider
        ])

        _connect_box = urwid.Frame(
            body = body,
            header = _header,
            footer = _footer,
            focus_part='body'
        )
        _connect_box.keypress = connect_box_keypress
        self.connect_box = _connect_box

        # store actual widget
        if widget is False:
            self.last_widget = self.loop.widget

        # Create a popup
        overlay = urwid.Overlay(
            _connect_box,
            self.loop.widget,
            align = 'center',
            valign = 'middle',
            width = ('relative', 45),
            height = ('relative', 25)
        )

        self.loop.widget = overlay

    def __network_connect(self, _loop, _data, saved_network=False):

        essid = _data[0]
        bssid = _data[1]
        password = _data[2]
        hidden_flag = _data[3]
        saved_network = _data[4]

        # we need to disconnect 1st If we are connected and trying to connect
        if self.connected:
            self.__disconnect()

        if saved_network is not False:
            network_id = saved_network
        else:
            """Configure NEW connection"""

            # We get a new network id on wpa_supplicant
            cmd = ["wpa_cli", "-i", self.interface, "add_network"]
            n = subprocess.check_output(cmd, stderr=subprocess.DEVNULL)
            network_id = int(n.strip().split(b"\n")[0])

            # Set the BSSID where we are going to connect
            cmd = [
                    "wpa_cli",
                    "-i",
                    self.interface,
                    "set_network",
                    "{}".format(network_id),
                    "bssid",
                    '{}'.format(bssid)
                ]
            r = subprocess.check_call(cmd,
                                      stdout=subprocess.DEVNULL,
                                      stderr=subprocess.DEVNULL)

            # Set the essid where we are going to connect
            cmd = [
                    "wpa_cli",
                    "-i",
                    self.interface,
                    "set_network",
                    "{}".format(network_id),
                    "ssid",
                    '"{}"'.format(essid)
                ]
            r = subprocess.check_call(cmd,
                                      stdout=subprocess.DEVNULL,
                                      stderr=subprocess.DEVNULL)

            if password is not False:
                # Set the password
                cmd = [
                        "wpa_cli",
                        "-i",
                        self.interface,
                        "set_network",
                        "{}".format(network_id),
                        "psk",
                        '"{}"'.format(password)
                    ]
                r = subprocess.check_call(cmd,
                                          stdout=subprocess.DEVNULL,
                                          stderr=subprocess.DEVNULL)
            else:
                # No key management
                cmd = [
                        "wpa_cli",
                        "-i",
                        self.interface,
                        "set_network",
                        "{}".format(network_id),
                        "key_mgmt",
                        'NONE'
                    ]
                r = subprocess.check_call(cmd,
                                          stdout=subprocess.DEVNULL,
                                          stderr=subprocess.DEVNULL)

            # Scan AP for hidden networks
            if hidden_flag:
                cmd = [
                    "wpa_cli",
                    "-i",
                    self.interface,
                    "set_network",
                    "{}".format(network_id),
                    "scan_ssid",
                    '1'
                ]
                r = subprocess.check_call(cmd,
                                          stdout=subprocess.DEVNULL,
                                          stderr=subprocess.DEVNULL)

            # Enable network
            cmd = [
                    "wpa_cli",
                    "-i",
                    self.interface,
                    "enable_network",
                    "{}".format(network_id)
                ]
            r = subprocess.check_call(cmd,
                                      stdout=subprocess.DEVNULL,
                                      stderr=subprocess.DEVNULL)


        # Select the network
        cmd = [
                "wpa_cli",
                "-i",
                self.interface,
                "select_network",
                "{}".format(network_id)
            ]
        r = subprocess.check_call(cmd,
                                  stdout=subprocess.DEVNULL,
                                  stderr=subprocess.DEVNULL)

        # Clean wpa_supplicant log
        try:
            os.remove(self.wpa_logfile)
            #open(self.wpa_logfile, 'w+').close()
            cmd = [
                    "wpa_cli",
                    "-i",
                    self.interface,
                    "relog"
                ]
            n = subprocess.check_call(cmd,
                                      stdout=subprocess.DEVNULL,
                                      stderr=subprocess.DEVNULL)
        except:
            raise urwid.ExitMainLoop()

        # FIXME: Log note
        cmd = ["wpa_cli", "-i", self.interface, "note", "Restarted"]
        r = subprocess.check_call(cmd,
                                  stdout=subprocess.DEVNULL,
                                  stderr=subprocess.DEVNULL)

        # Check wpa_supplicant log for connect/error event
        f = open(self.wpa_logfile, 'r')
        wpa_supplicant_event = False

        connect_count = 0
        while wpa_supplicant_event is False:
            connect_count += 1

            f.seek(0)
            if 'CTRL-EVENT-CONNECTED' in f.read():
                wpa_supplicant_event = 'CONNECTED'
            f.seek(0)
            if 'CTRL-EVENT-DISCONNECTED' in f.read():
                wpa_supplicant_event = 'DISCONNECTED'
            f.seek(0)
            if 'CTRL-EVENT-ASSOC-REJECT' in f.read():
                wpa_supplicant_event = 'DISCONNECTED'
            f.seek(0)
            if 'CTRL-EVENT-AUTH-REJECT' in f.read():
                wpa_supplicant_event = 'DISCONNECTED'
            f.seek(0)
            if 'CTRL-EVENT-ASSOC-REJECT' in f.read():
                wpa_supplicant_event = 'DISCONNECTED'
            
            # Limit 10 seconds to wait for a connection, otherwise cancel
            if connect_count == 10 and wpa_supplicant_event is False:
                wpa_supplicant_event = 'DISCONNECTED'
                password = False  # Don't ask for new password
            else:
                time.sleep(1)
        f.close()

        # Password error
        if (wpa_supplicant_event == 'DISCONNECTED'):
            cmd = ["wpa_cli", "-i", self.interface, "disconnect"]
            n = subprocess.check_call(cmd,
                                      stdout=subprocess.DEVNULL,
                                      stderr=subprocess.DEVNULL)

            cmd = [
                    "wpa_cli",
                    "-i",
                    self.interface,
                    "remove_network",
                    "{}".format(network_id)
                ]
            n = subprocess.check_call(cmd,
                                      stdout=subprocess.DEVNULL,
                                      stderr=subprocess.DEVNULL)

            
            """Popup can't connect"""
            # Can't connect (connection without password)
            if password is False:
                _header = urwid.Text('Connection error', align = 'center')
            # Password wrong. Enter a new one or cancel
            else:
                _header = urwid.Text('Password error', align = 'center')
            _header = urwid.AttrMap(_header, 'connect_title')
            _divider = urwid.Divider('-')
            _divider = urwid.AttrMap(_divider, 'connect_title_divider')
            _header = urwid.Pile([_divider,
                                _header,
                                _divider])

            if password is False:
                _text = urwid.Text('Cannot connect to this network.',
                                    align='center')
            else:
                _text = urwid.Text('Password is not valid for this network.',
                                    align='center')
            _text = urwid.AttrMap(_text, 'connect_wrong_pass')
            _text = urwid.Padding(_text,
                                align='center',
                                left=15,
                                right=15,
                                min_width=20)

            _text = urwid.Pile([urwid.Divider(' '),
                                _text,
                                urwid.Divider(' ')])

            # Args to pass to __connect_dialog
            _network = [essid,0,0,bssid]

            # buttons
            _button_new_password_button = urwid.Button('New Password')
            _button_new_password = urwid.AttrMap(
                    _button_new_password_button,
                    "connect_buttons",
                    "connect_button_connect"
                )
            _button_new_password = urwid.Padding(
                    _button_new_password,
                    align='center',
                    right=0,
                    min_width=15
                )
            urwid.connect_signal(
                    _button_new_password_button,
                    'click',
                    self.__connect_dialog,
                    user_args=[_network]
                )

            _button_cancel = urwid.Button('Cancel', self.__network_scan_list)
            _button_cancel = urwid.AttrMap(
                    _button_cancel,
                    "connect_buttons",
                    "connect_button_connect"
                )
            _button_cancel = urwid.Padding(
                    _button_cancel,
                    align='center',
                    left=5,
                    min_width=15
                )

            if password is False:
                _button = urwid.Columns([_button_cancel])
                _button = urwid.Padding(
                        _button, align='center',
                        left=30,
                        right=30,
                        min_width=15
                    )
            else:
                _button = urwid.Columns([_button_new_password,
                                    _button_cancel])
                _button = urwid.Padding(
                        _button, align='center',
                        left=15,
                        right=15,
                        min_width=15
                    )
            _button = urwid.AttrMap(_button, 'connect_buttons')

            _body = urwid.Pile([
                _header,
                _text,
                _button,
                _divider
            ])

            _body = urwid.Filler(_body)
            _body = urwid.AttrMap(_body, 'connect_ask')

            _connect_box = urwid.Frame(
                _body,
                header=urwid.Divider(' '),
                focus_part='body'
            )

            # Create a popup
            overlay = urwid.Overlay(
                _connect_box,
                self.last_widget,
                align = 'center',
                valign = 'middle',
                width = ('relative', 35),
                height = ('relative', 20),
                min_height = 10
            )

            self.loop.widget = overlay
        # Connection success
        else:
            # ask ip to dhcp
            cmd = ["dhclient", self.interface]
            n = subprocess.check_call(cmd,
                                      stdout=subprocess.DEVNULL,
                                      stderr=subprocess.DEVNULL)

            # Save wpa_supplicant config
            cmd = ["wpa_cli", "-i", self.interface, "save_config"]
            r = subprocess.check_call(cmd,
                                      stdout=subprocess.DEVNULL,
                                      stderr=subprocess.DEVNULL)

            self.__network_scan_list(self.loop, [False])

    def __network_scan(self, _loop=object, data=[]):
        self.network_list = self.scanner.scan()

        # If we didn't hit the counter of scans, we scan again
        if self.scan_times_current < self.scan_times:
            # We add count on current scans
            self.scan_times_current += 1

            # Sleep for a second
            time.sleep(2)

            # Scan again
            self.scan()
        else:
            from pprint import pprint

            # Separate hidden networks
            hidden_idx = []
            self.network_list_hidden = []

            for idx,network in enumerate(self.network_list):
                essid = network[0]
                if '\\x00' in essid or '?' in essid or essid == '':
                    network[0] = '-HIDDEN-'
                    self.network_list_hidden.append(network)
            
            for network in self.network_list_hidden:
                self.network_list.remove(network)
            
            self.loop.set_alarm_in(0.1, self.__network_scan_list, user_data=[False])

    def start(self):
        """Start the urwid interface"""
        self.loop.run()

    def scan(self, _loop=object, _data=[]):
        """Show scanning popup and start scanning for networks"""

        # scanning popup
        if self.scan_times_current < self.scan_times:
            _text = urwid.Text(
                    '\nScanning. Please wait (%s/%s)' %\
                        (self.scan_times_current, self.scan_times),
                    align='center'
                )
        else:
            _text = urwid.Text('\nScanning. Please wait...', align='center')
        
        _text = urwid.AttrMap(_text, 'scanning')
        _body = urwid.Pile([
            _text
        ])
        _body = urwid.Filler(_body)
        _body = urwid.AttrMap(_body, 'scanning')

        _connect_box = urwid.Frame(
            _body,
            header=urwid.Divider(' '),
            focus_part='body'
        )

        # store actual widget
        self.last_widget = self.loop.widget

        # Create a popup
        overlay = urwid.Overlay(
            _connect_box,
            self.loop.widget,
            align = 'center',
            valign = 'middle',
            width = ('relative', 40),
            height = ('relative', 12),
            min_height = 6,
        )

        self.loop.widget = overlay
        self.loop.set_alarm_in(0.1, self.__network_scan)


class SelectableRow(urwid.WidgetWrap):
    """Urwid class for custom list"""
    def __init__(self, contents, hidden, on_select=None):
        self.contents = contents
        self.on_select = on_select

        self._columns = urwid.Columns([urwid.Text(str(c)) for c in contents])
        if hidden:
            self._focusable_columns = urwid.AttrMap(
                    self._columns,
                    '',
                    'reveal_focus_hidden'
                )
        else:
            self._focusable_columns = urwid.AttrMap(
                    self._columns,
                    '',
                    'reveal_focus'
                )

        super(SelectableRow, self).__init__(self._focusable_columns)

    def selectable(self):
        return True

    def update_contents(self, contents):
        # update the list record inplace...
        self.contents[:] = contents

        # ... and update the displayed items
        for t, (w, _) in zip(contents, self._columns.contents):
            w.set_text(t)

    def keypress(self, size, key):
        # onSelect
        if self.on_select and key in ('enter',):
        #if self.on_select and key.lower() == 'c':
            self.on_select(self.contents)
            pass

        return key

    def __repr__(self):
        return '%s(contents=%r)' % (self.__class__.__name__, self.contents)
