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

from threading import Thread, Event
import time
import subprocess
from pprint import pprint
import re


class wifi_scanner:

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

		# FIXME: sometimes wpa_cli doesn't scan at the 1st time, so we run it 2 times in case.
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
			bssid		= c[0].decode('utf-8')
			# Net Channel
			try:
				channel		= [k for k, v in self.channel_freq.items() if v == int(c[1])][0]
			except:
				try:
					channel		= [k for k, v in self.channel_freq_5ghz.items() if v == int(c[1])][0]
				except:
					channel		= '?'

			# Net dbm
			dbm_signal	= c[2].decode('utf-8')
			# Net Quality
			quality		= 2 * (int(c[2]) + 100)
			if quality > 100: quality = 100
			# Net Security
			security	= c[3].decode('utf-8')
			q = re.search(r'\[(.*?)\]', security)
			security = q[0]
			# Net Name
			try:
				essid		= c[4].decode('utf-8')
			except:
				essid		= '?'
			#if '\\x00' in essid:
			#	essid = 'HIDDEN'
			self.networks[bssid] = [essid, quality, security, bssid, channel, dbm_signal]

		return self.networks




	#def scan_hidden(self):
	#	# set up the interface for Monitor mode
	#	cmd = "ifconfig wlan0 down"
	#	os.system(cmd)
	#	cmd = "iw phy phy0 interface add mon0 type monitor"
	#	os.system(cmd)
	#	cmd = "ifconfig mon0 up"
	#	os.system(cmd)

	#	# start the channel changer
	#	channel_changer = Thread(target=self.__change_channel)
	#	channel_changer.daemon = True
	#	channel_changer.start()
	#	self.stop_event = Event()

	#	# start sniffing
	#	while self.keep_scanning:
	#		try:
	#			sniff(prn=self.__callback, iface='mon0', stop_filter=lambda x: self.stop_event.is_set())
	#		except Exception as e:
	#			pass

	#	# set up the interface for Managed mode
	#	cmd = ["ifconfig", "mon0", "down"]
	#	subprocess.check_call(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

	#	cmd = ["iw", "dev", "mon0", "del"]
	#	subprocess.check_call(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
	#
	#	cmd = ["ifconfig", "wlan0", "up"]
	#	subprocess.check_call(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

	#	return self.networks

	#def __callback(self, packet):
	#	if self.keep_scanning and packet.haslayer(Dot11Beacon):
	#		# extract the MAC address of the network
	#		bssid = packet[Dot11].addr2
	#		# get the name of it
	#		ssid = packet[Dot11Elt].info.decode()
	#		# if we got x00 on ssid, it's a hidden ssid
	#		try:
	#			dbm_signal = packet.dBm_AntSignal
	#			quality = 2 * (dbm_signal + 100)
	#			if quality > 100:
	#				quality = 100
	#		except:
	#			dbm_signal = "N/A"
	#			quality = "N/A"
	#		# extract network stats
	#		stats = packet[Dot11Beacon].network_stats()
	#		# get the channel of the AP
	#		channel = stats.get("channel")
	#		# get the crypto
	#		crypto = stats.get("crypto")
	#		self.networks[bssid] = [ssid, quality, '|'.join(crypto), bssid, channel, dbm_signal]
#
	#def __change_channel(self):
	#	# we use time to stop the scanning after 10 seconds
	#	time_limit = time.time() + 10
	#
	#	ch = 1
	#	while self.keep_scanning:
	#		if time.time() >= time_limit:
	#			self.keep_scanning = False
	#
	#		# change channel freq
	#		cmd = ["iw", "dev", "mon0", "set", "freq", "%s" % self.channel_freq[ch]]
	#		try:
	#			subprocess.check_call(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
	#		except:
	#			pass
	#		# switch channel from 1 to 14 each 0.5s
	#		ch = ch % 14 + 1
#
	#		time.sleep(0.5)
	#
	#	# Stop event
	#	self.stop_event.set()
