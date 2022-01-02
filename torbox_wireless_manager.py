#!/usr/bin/python3

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
# This is the TorBox Wireless Manager - an easy, userfriendly way to
# connect the TorBox to a wireless network. It is a replacement of wicd,
# which is based on Python 2 and seemes to be abadone by the developers.
#
# SYNTAX
# sudo torbox_wireless_manager.py -i <interface> [-a|--autoconnect]
#
# -i <interface>: Interface to connect - mandatory!
# -a|--autoconnect: Don't show an interactive user menu, just try to automatically connect to an already know network

import sys
import getopt
import os

interface = False

options, remainder = getopt.getopt(sys.argv[1:], 'i:a', ['interface=',
														'autoconnect'])

# Autoconnect flag
autoconnect = False

for opt, arg in options:
	if opt in ('-i', '--interface'):
		interface = arg
	elif opt in ('-a', '--autoconnect'):
		autoconnect = True

if not interface:
	print("Usage: %s -i <interface> [-a|--autoconnect]" % (sys.argv[0]) )
	quit()
else:
	# check interface exists
	if not os.path.isfile('/sys/class/net/%s/dev_port' % interface):
		print('[%s]: not available' % interface)
		quit()

from lib.wireless_manager import WirelessManager

def main():
	twm = WirelessManager(interface, autoconnect)
	twm.start()

if __name__ == '__main__':
	main()
