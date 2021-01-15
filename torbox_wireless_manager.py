#!/usr/bin/python3
# -* coding: utf-8 -*-
#-------------------------
# TorBox Wireless Manager
#-------------------------

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
	print("Usage: %s -i <interface>" % (sys.argv[0]) )
	quit()
else:
	# check interface exists
	if not os.path.isfile('/sys/class/net/%s/dev_port' % interface):
		print('[%s]: not available' % interface)
		quit()

from lib.wireless_manager import wireless_manager

def main():
	wm = wireless_manager(interface, autoconnect)
	wm.start()

if __name__ == '__main__':
	main()