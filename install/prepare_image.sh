#!/bin/bash

# This file is a part of TorBox, an easy to use anonymizing router based on Raspberry Pi.
# Copyright (C) 2022 Patrick Truffer
# Contact: anonym@torbox.ch
# Website: https://www.torbox.ch
# Github:  https://github.com/radio24/TorBox
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
# This script prepares the freshly installed TorBox for the building of an image
#
# SYNTAX
# ./prepare_image.sh
#
#
###### SET VARIABLES ######

#Colors
RED='\033[1;31m'
WHITE='\033[1;37m'
NOCOLOR='\033[0m'

##############################
######## FUNCTIONS ###########

# include lib
.  /home/torbox/torbox/lib/torbox.lib

# Is the Snowflake client installed?
if command -v snowflake-client &> /dev/null
then SNOWFLAKE="exists";
else SNOWFLAKE="is missing"; fi

# Is the automatic counteractions feature activated?
if pgrep -f "log_check.py" ; then
  clear
  LOGCHECK="Activated!"
else
    clear
  LOGCHECK="Deactivated!"
fi

# Is Vanguards activated?
VANGUARDSSTATUS=$(sudo systemctl is-active vanguards@default.service)
if [ ${VANGUARDSSTATUS} == "active" ]; then
  VANGUARDSSTATUSb="Activated!"
else
  VANGUARDSSTATUSb="Deactivated!"
fi

# Are bridges activated?
if grep "^UseBridges" ${TORRC}; then
	if grep -o "^Bridge obfs4 " ${TORRC}; then
			MODE_BRIDGES="OBFS4 is running - will be deactivated."
	elif grep -o "^Bridge meek_lite " ${TORRC}; then
			MODE_BRIDGES="Meek-Azure is running - will be deactivated."
	elif grep -o "^Bridge snowflake " ${TORRC} | head -1; then
				MODE_BRIDGES="Snowflake is running - will be deactivated."
	else
			MODE_BRIDGES="Are not running."
	fi
else
		MODE_BRIDGES="Are not running."
fi

# Is the Bridge Relay activated?
if grep "^BridgeRelay" ${TORRC}; then
	BRIDGE_RELAY="Is running - will be deactivated"
else
	BRIDGE_RELAY="Is not running"
fi

# Are Onion Services Running?
if grep "^HiddenServiceDir" ${TORRC}; then
	MODE_OS="Are running"
else
	MODE_OS="Are not running"
fi

# Is the Countermeasure against a tightly configured firewall active?
if grep -o "^ReachableAddresses " ${TORRC} | head -1; then
	FIREWALL="Are running"
else
	FIREWALL="Are not running"
fi

# Is the Countermeasure against a disconnection when idle feature active?
	if pgrep -f "ping -q $PING_SERVER" ; then
		clear
		PING="Is running"
	else
		clear
		PING="Is not running"
	fi

clear
echo -e "${WHITE}[!] CHECK INSTALLED VERSIONS${NOCOLOR}"
echo
echo -e "${RED}Hostname                                     :${WHITE} $(cat /etc/hostname)${NOCOLOR}"
echo -e "${RED}Kernel version                               :${WHITE} $(uname -a)${NOCOLOR}"
echo -e "${RED}Tor version                                  :${WHITE} $(tor -v | head -1 | sed "s/Tor version //" | cut -c1-80)${NOCOLOR}"
echo -e "${RED}Obfs4proxy version                           :${WHITE} $(obfs4proxy --version | head -1 | sed "s/obfs4proxy-//")${NOCOLOR}"
echo -e "${RED}Snowflake                                    :${WHITE} $SNOWFLAKE ${NOCOLOR}"
echo -e "${RED}Nyx version                                  :${WHITE} $(nyx -v | head -1 | sed "s/nyx version //")${NOCOLOR}"
echo -e "${RED}Go version                                   :${WHITE} $(go version | head -1 | sed "s/go version //")${NOCOLOR}"
echo -e "${RED}Installed time zone                          :${WHITE} $(cat /etc/timezone)${NOCOLOR}"
echo -e "${RED}Firewall countermeasures                     :${WHITE} $FIREWALL${NOCOLOR}"
echo -e "${RED}Disconnection when idle countermeasure       :${WHITE} $PING${NOCOLOR}"
echo -e "${RED}TorBox's automatic counteractions are        :${WHITE} $LOGCHECK${NOCOLOR}"
echo -e "${RED}Vanguards is                                 :${WHITE} $VANGUARDSSTATUSb${NOCOLOR}"
echo -e "${RED}Bridges                                      :${WHITE} $MODE_BRIDGES${NOCOLOR}"
echo -e "${RED}Bridge Relay                                 :${WHITE} $BRIDGE_RELAY${NOCOLOR}"
echo -e "${RED}Onion Services                               :${WHITE} $MODE_OS${NOCOLOR}"
echo
echo
echo -e "${WHITE}Following requirements are installed:${NOCOLOR}"
readarray -t REQUIREMENTS < requirements.txt
for REQUIREMENT in "${REQUIREMENTS[@]}"
do
  echo -e "${RED}${REQUIREMENT} version: ${WHITE}$(pip3 freeze | grep $REQUIREMENT | sed "s/${REQUIREMENT}==//")${NOCOLOR}"
done
echo ""
read -n 1 -s -r -p $'\e[1;31mPlease press any key to continue... \e[0m'
clear
echo -e "${WHITE}[!] PREPARATIONS FOR THE IMAGE${NOCOLOR}"
echo
echo -e "${RED}[+] Setting the correct time${NOCOLOR}"
sudo /usr/sbin/ntpdate pool.ntp.org
echo -e "${RED}[+] Deactivating TorBox's automatic counteractions feature...${NOCOLOR}"
sudo pkill -f "log_check.py"
echo -e "${RED}[+] Stopping and masking tor${NOCOLOR}"
sudo systemctl stop tor
sudo systemctl mask tor
sudo systemctl mask tor@default.service
echo -e "${RED}[+] Deactivating all bridges${NOCOLOR}"
deactivate_obfs4_bridges NORESTART
sudo sed -i "s/^ClientTransportPlugin snowflake /#ClientTransportPlugin snowflake /g" ${TORRC}
sudo sed -i "s/^Bridge snowflake /#Bridge snowflake /g" ${TORRC}
sudo sed -i "s/^Bridge meek_lite /#Bridge meek_lite /g" ${TORRC}
echo -e "${RED}[+] Deactivating the bridge relay${NOCOLOR}"
deactivating_bridge_relay
echo -e "${RED}[+] Removing permanently OBFS4 Bridge Relay data${NOCOLOR}"
(sudo rm -r /var/lib/tor/keys) 2> /dev/null
(sudo rm /var/lib/tor/fingerprint) 2> /dev/null
(sudo rm /var/lib/tor/hashed-fingerprint) 2> /dev/null
(sudo rm -r /var/lib/tor/pt_state) 2> /dev/null
echo -e "${RED}[+] Resetting Tor and force a change of the permanent entry node ${NOCOLOR}"
(sudo rm -r /var/lib/tor/cached-certs) 2> /dev/null
(sudo rm -r /var/lib/tor/cached-consensus) 2> /dev/null
(sudo rm -r /var/lib/tor/cached-descriptors) 2> /dev/null
(sudo rm -r /var/lib/tor/cached-descriptors.new) 2> /dev/null
(sudo rm -r /var/lib/tor/cached-microdesc-consensus) 2> /dev/null
(sudo rm -r /var/lib/tor/cached-microdescs) 2> /dev/null
(sudo rm -r /var/lib/tor/cached-microdescs.new) 2> /dev/null
(sudo rm -r /var/lib/tor/diff-cache) 2> /dev/null
(sudo rm -r /var/lib/tor/lock) 2> /dev/null
(sudo rm -r /var/lib/tor/state) 2> /dev/null
echo -e "${RED}[+] Deleting all stored wireless passwords${NOCOLOR}"
(sudo rm /etc/wpa_supplicant/wpa_supplicant-wlan0.conf) 2> /dev/null
(sudo rm /etc/wpa_supplicant/wpa_supplicant-wlan1.conf) 2> /dev/null
echo -e "${RED}[+] Copy /etc/iptables.ipv4.nat${NOCOLOR}"
sudo cp etc/iptables.ipv4.nat /etc/
echo -e "${RED}[+] Erasing big not usefull packages...${NOCOLOR}"
# Find the bigest space waster packages: dpigs -H
(sudo apt-get -y remove libgl1-mesa-dri texlive* lmodern) 2> /dev/null
echo -e "${RED}[+] Fixing and cleaning${NOCOLOR}"
sudo apt --fix-broken install
sudo apt-get -y clean; sudo apt-get -y autoclean; sudo apt-get -y autoremove
sudo setcap 'cap_net_bind_service=+ep' /usr/bin/obfs4proxy
sudo sed -i "s/^NoNewPrivileges=yes/NoNewPrivileges=no/g" /lib/systemd/system/tor@default.service
sudo sed -i "s/^NoNewPrivileges=yes/NoNewPrivileges=no/g" /lib/systemd/system/tor@.service
sudo systemctl daemon-reload
echo -e "${RED}[+] Deleting all logs and resetting Tor statistics...${NOCOLOR}"
echo
erase_logs
echo
echo -e "${RED}[+] Setting the right start trigger${NOCOLOR}"
sudo sed -i "s/^FRESH_INSTALLED=.*/FRESH_INSTALLED=2/" ${RUNFILE}
echo ""
echo -e "${WHITE}[!] PREPARATIONS FOR THE IMAGE IS FINISHED!${NOCOLOR}"
echo -e "${RED}[+] We will shutdown the TorBox now.${NOCOLOR}"
echo
read -n 1 -s -r -p $'\e[1;31mPlease press any key to continue... \e[0m'
clear
sudo shutdown -h now
