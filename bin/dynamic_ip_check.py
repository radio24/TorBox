#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
# This file is part of TorBox, an easy to use anonymizing router based on Raspberry Pi.
# Copyright (C) 2024 radio24
# Contact: anonym@torbox.ch
# Website: https://www.torbox.ch
# Github: https://github.com/radio24/TorBox
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
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
# This script checks if the IP address of the specific network interface (wlanx)
# has changed. If this is the case, it triggers the restart of the tor service.
#
# SYNTAX
# ./dynamic_ip_check.py [-i wlanx] [--interface wlanx]

import argparse
import subprocess
import sys

def get_ip(interface):
    # Simple function that parses output
    # of ip command and returns interface ip
    command = ['ip', '-4', '-o', 'addr', 'show', interface]
    ip = None
    try:
        ip = subprocess.check_output(command).decode().split()[3]
    except IndexError:
        return
    finally:
        if ip:
           return ip

def main(interface):
    # do while loop
    # exits only when change occurs
    address = get_ip(interface)
    while address == get_ip(interface):
        address = get_ip(interface)

    # Trigger script once we're out of loop
    subprocess.run(['echo','IP CHANGED'])
    subprocess.run(['sudo','systemctl','restart','tor'])


if __name__ == '__main__':
    # Parse command-line arguments
    parser = argparse.ArgumentParser()
    parser.add_argument('-i', '--interface', help='WLAN interface', required=True)
    args = parser.parse_args()

    # use while loop if yout want this script to run
    # continuously
    while True:
        try:
            main(args.interface)
        except KeyboardInterrupt:
            sys.exit()
