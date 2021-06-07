# -*- coding: utf-8 -*-
#
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
# This file contains the Python 3 class "wifi_scanner", which is used 
# by the class "wireless_manager" of the Torbox Wireless Manager.

import time
import subprocess
import re


class wifi_scanner:
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

        # FIXME: sometimes wpa_cli doesn't scan at the 1st time,
        # so we run it 2 times in case.
        cmd = "wpa_cli", "-i", self.interface, "scan"
        cmd = subprocess.check_output(cmd, stderr=subprocess.DEVNULL)

        # Process scan result
        cmd = ["wpa_cli", "-i", self.interface, "scan_results"]
        cmd = subprocess.check_output(cmd, stderr=subprocess.DEVNULL)
        r = cmd.strip().split(b"\n")

        # Remove headers from response
        r.remove(r[0])

        # sort the list
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
            
            self.networks[bssid] = [
                    essid,
                    quality,
                    security,
                    bssid,
                    channel,
                    dbm_signal
                ]

        return self.networks
