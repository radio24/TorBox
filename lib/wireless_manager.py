#!/usr/bin/python3
# -*- coding: utf-8 -*-

# This file is part of TorBox, an easy to use anonymizing router based on Raspberry Pi.
# Copyright (C) 2021 Patrick Truffer
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
import subprocess
import time
import urwid
import asyncio

from .wifi_scanner import wifi_scanner


class wireless_manager:

    # Flags counting scanning between different methods inside the class
    scan_times_current = 1
    scan_times = 3

    # Default color palette
    _palette = [
        ("column_headers",          "white, bold",      ""),
        ("reveal_focus",            "black",            "dark cyan",    "standout"),
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
        self.wpa_logfile = "/tmp/tbm-%s.log"% self.interface
        open(self.wpa_logfile, 'w+').close()  # Clean/create wpa_logfile

        # wifi scanner
        self.scanner = wifi_scanner(self.interface)

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
            n = subprocess.check_call(
                    cmd,
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL
                )

            # Check if we got connect by wpa_supplicant
            # run dhcp for getting ip
            cmd = ["dhclient", self.interface]
            n = subprocess.check_call(
                    cmd,
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL
                )

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
        self.loop = urwid.MainLoop(
            widget,
            self._palette,
            unhandled_input = self._manage_hotkeys,
            event_loop = self._event_loop
        )
        self.loop.set_alarm_in(0.1, self.scan, user_data=[False])

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
                urwid.Text('Torbox Wireless Manager', 'center'),
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
                status = output[8].split("=")[1]

                if status == 'COMPLETED':
                    # Connected
                    ssid = output[2].split("=")[1]
                    ip_addr = output[9].split("=")[1]
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

            footer = urwid.Pile([
                    urwid.Text(
                            '[ENTER]: Connect [R]efresh [Q]uit',
                            align="center"
                        ),
                    _netstatus
                ])
            return footer

    def __get_container(self, widget, header=True, footer=True):
        """Default container. It can be with or without header and footer"""
        frame = urwid.Frame(
            widget,
            header = self.__get_header(header),
            footer = self.__get_footer(footer)
        )
        return frame

    def start(self):
        """Start the urwid interface"""
        self.loop.run()

    def _manage_hotkeys(self, key):
        # (Q) QUIT
        if key in ('Q', 'q'):
            # Exit urwid
            raise urwid.ExitMainLoop()

        # (R) Refresh network list
        if key in ('R','r'):
            self.scan()

        # (D) Refresh network list
        if key in ('D','d'):
            self.__disconnect()

    def scan(self, _loop=object, _data=[False]):
        """Show scanning popup and start scanning for networks"""
        hidden = _data[0]

        # scanning popup
        if hidden is False:
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
        else:
            if self.scan_times_current < self.scan_times:
                _text = urwid.Text(
                        '\nScanning HIDDEN networks. Please wait (%s/%s)' %\
                            (self.scan_times_current, self.scan_times),
                        align='center'
                    )
            else:
                _text = urwid.Text(
                        '\nScanning HIDDEN networks. Please wait...',
                        align='center'
                    )
            _text = urwid.AttrMap(_text, 'scanning_hidden')

            _body = urwid.Pile([
                _text
            ])

            _body = urwid.Filler(_body)
            _body = urwid.AttrMap(_body, 'scanning_hidden')

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
            height = ('relative', 12)
        )

        self.loop.widget = overlay
        self.loop.set_alarm_in(0.1, self.__network_scan_list, user_data=[hidden])

    def __disconnect(self):
        """Disconnect from any network"""

        cmd = ["dhclient", "-r", self.interface]
        n = subprocess.check_call(
                cmd,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL
            )

        cmd = ["wpa_cli", "-i", self.interface, "disconnect"]
        r = subprocess.check_call(
                cmd,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL
            )

    def __network_scan_list(self, _loop=object, _data=[False]):
        """Show network list after scan is done"""

        hidden_scan = _data[0]

        if hidden_scan:
            self.network_list = self.scanner.scan_hidden()
        else:
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

            # clean hidden ssid for UI
            networks = self.network_list
            for bssid in networks.keys():
                __essid = networks[bssid][0]
                if '\\x00' in __essid or '?' in __essid or __essid == '':
                    __essid = '-HIDDEN-'
                networks[bssid][0] = __essid

            # Networks found
            _netlist = [
                SelectableRow(
                        networks[bssid],
                        self.__connect_network
                    ) for bssid in networks.keys()
                ]
            _netlist = urwid.ListBox(urwid.SimpleFocusListWalker(_netlist))

            pile = urwid.Pile([
                urwid.Text('Networks found:'),
                urwid.Divider('-'),
                _network_header,
                urwid.Divider('-'),
                urwid.BoxAdapter(_netlist, terminal_rows),
            ])

            widget = urwid.Filler(pile)
            widget = self.__get_container(widget)

            self.loop.widget = widget

    def __connect_network(self, network):
        """
        If network is already configured  connect without asking password
        If security is ESS, we don't ask for password
        """
        essid = network[0]
        bssid = network[3]
        security = network[2]

        cmd = "wpa_cli -i %s list_networks |grep '%s'" % (self.interface, bssid)
        n = subprocess.Popen(
                cmd,
                shell=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL
            )
        _str = n.communicate()[0]

        try:
            network_id = _str.strip().split(b"\t")[0]
            network_id = int(network_id)
            self.__disconnect()
        except:
            network_id = False

        if network_id is False and security != '[ESS]':
            self.__connect_dialog(network)
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
                height = ('relative', 9)
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
        def _button_connect_callback(
                    essid_input, bssid, pass_input, hidden_flag, widget
                ):
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
                height = ('relative', 9)
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
                _button_connect_callback(
                        _input_essid_edit,
                        bssid,
                        _input_pass_edit,
                        _hidden_flag,
                        self.loop.widget
                    )
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
            r = subprocess.check_call(
                    cmd,
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL
                )

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
            r = subprocess.check_call(
                    cmd,
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL
                )

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
                r = subprocess.check_call(
                        cmd,
                        stdout=subprocess.DEVNULL,
                        stderr=subprocess.DEVNULL
                    )
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
                r = subprocess.check_call(
                        cmd,
                        stdout=subprocess.DEVNULL,
                        stderr=subprocess.DEVNULL
                    )

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
                r = subprocess.check_call(
                        cmd,
                        stdout=subprocess.DEVNULL,
                        stderr=subprocess.DEVNULL
                    )

            # Enable network
            cmd = [
                    "wpa_cli",
                    "-i",
                    self.interface,
                    "enable_network",
                    "{}".format(network_id)
                ]
            r = subprocess.check_call(
                    cmd,
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL
                )


        # Select the network
        cmd = [
                "wpa_cli",
                "-i",
                self.interface,
                "select_network",
                "{}".format(network_id)
            ]
        r = subprocess.check_call(
                cmd,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL
            )

        # Clean wpa_supplicant log
        try:
            os.remove(self.wpa_logfile)
            cmd = [
                    "wpa_cli",
                    "-i",
                    self.interface,
                    "relog"
                ]
            n = subprocess.check_call(
                    cmd,
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL
                )
        except:
            raise urwid.ExitMainLoop()

        # FIXME: Log note
        cmd = ["wpa_cli", "-i", self.interface, "note", "Restarted"]
        r = subprocess.check_call(
                cmd,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL
            )

        # Check wpa_supplicant log for connect/error event
        f = open(self.wpa_logfile, 'r')
        wpa_supplicant_event = False

        while wpa_supplicant_event is False:
            f.seek(0)
            if 'CTRL-EVENT-CONNECTED' in f.read():
                wpa_supplicant_event = 'CONNECTED'
            f.seek(0)
            if ('CTRL-EVENT-DISCONNECTED' in f.read()
                    or 'CTRL-EVENT-ASSOC-REJECT' in f.read()):
                wpa_supplicant_event = 'DISCONNECTED'
            f.seek(0)
            if 'CTRL-EVENT-ASSOC-REJECT' in f.read():
                wpa_supplicant_event = 'DISCONNECTED'
        f.close()

        # Password error
        if (wpa_supplicant_event == 'DISCONNECTED'):
            cmd = ["wpa_cli", "-i", self.interface, "disconnect"]
            n = subprocess.check_call(
                    cmd,
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL
                )

            cmd = [
                    "wpa_cli",
                    "-i",
                    self.interface,
                    "remove_network",
                    "{}".format(network_id)
                ]
            n = subprocess.check_call(
                    cmd,
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL
                )

            """Popup: Password wrong. Enter a new one or cancel"""
            # Header
            _header = urwid.Text('Password error', align = 'center')
            _header = urwid.AttrMap(_header, 'connect_title')
            _divider = urwid.Divider('-')
            _divider = urwid.AttrMap(_divider, 'connect_title_divider')
            _header = urwid.Pile([
                _divider,
                _header,
                _divider
            ])

            _text = urwid.Text(
                    'Password is not valid for this network.',
                    align='center'
                )
            _text = urwid.AttrMap(_text, 'connect_wrong_pass')
            _text = urwid.Padding(
                    _text,
                    align='center',
                    left=15,
                    right=15,
                    min_width=20
                )
            _text = urwid.Pile([
                urwid.Divider(' '),
                _text,
                urwid.Divider(' ')
            ])

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

            _button = urwid.Columns([
                _button_new_password,
                _button_cancel
            ])
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
                height = ('relative', 20)
            )

            self.loop.widget = overlay

        else:
            # run dhcp for getting ip
            cmd = ["dhclient", self.interface]
            n = subprocess.check_call(
                    cmd,
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL
                )

            # Save wpa_supplicant config
            cmd = ["wpa_cli", "-i", self.interface, "save_config"]
            r = subprocess.check_call(
                    cmd,
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL
                )

            self.__network_scan_list(self.loop, [False])

class SelectableRow(urwid.WidgetWrap):
    """Urwid class for custom list"""
    def __init__(self, contents, on_select=None):
        self.contents = contents
        self.on_select = on_select

        self._columns = urwid.Columns([urwid.Text(str(c)) for c in contents])
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
