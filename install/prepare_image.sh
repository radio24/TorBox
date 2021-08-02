#!/bin/bash

# This file is a part of TorBox, an easy to use anonymizing router based on Raspberry Pi.
# Copyright (C) 2021 Patrick Truffer
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
.  lib/torbox.lib

if command -v snowflake-client &> /dev/null
then SNOWFLAKE="exists";
else SNOWFLAKE="is missing"; fi

if ps -ax | grep "[l]og_check.py" ; then
  clear
  LOGCHECK="Activated!"
else
    clear
    LOGCHECK="Deactivated!"
fi

VANGUARDSSTATUS=$(sudo systemctl is-active vanguards@default.service)
if [ ${VANGUARDSSTATUS} == "active" ]; then
  VANGUARDSSTATUSb="Activated!"
else
  VANGUARDSSTATUSb="Deactivated!"
fi

if [ -d "/home/pi" ]; then
  ROOT_DIR="${WHITE}WARNING! ${RED}User \"pi\" is still active!${NOCOLOR}"
else
  ROOT_DIR="${RED}User \"pi\" is removed!${NOCOLOR}"
fi

TORBOXMENU_BRANCHNAME=$(grep "^TORBOXMENU_BRANCHNAME=" ${RUNFILE} | cut -c23-) 2> /dev/null


clear
echo -e "${WHITE}[!] CHECK INSTALLED VERSIONS${NOCOLOR}"
echo
echo -e "${RED}Hostname                                     :${WHITE} $(cat /etc/hostname)${NOCOLOR}"
echo -e "${RED}Kernel version                               :${WHITE} $(uname -a)${NOCOLOR}"
echo -e "${RED}Tor version                                  :${WHITE} $(tor -v | head -1 | sed "s/Tor version //")${NOCOLOR}"
echo -e "${RED}Obfs4proxy version                           :${WHITE} $(obfs4proxy --version | head -1 | sed "s/obfs4proxy-//")${NOCOLOR}"
echo -e "${RED}Snowflake                                    :${WHITE} $SNOWFLAKE ${NOCOLOR}"
echo -e "${RED}Nyx version                                  :${WHITE} $(nyx -v | head -1 | sed "s/nyx version //")${NOCOLOR}"
echo -e "${RED}Go version                                   :${WHITE} $(go version | head -1 | sed "s/go version //")${NOCOLOR}"
echo -e "${RED}Installed time zone                          :${WHITE} $(cat /etc/timezone)${NOCOLOR}"
echo -e "${RED}TorBox's automatic countermeasures are       :${WHITE} $LOGCHECK ${NOCOLOR}"
echo -e "${RED}Vanguards is                                 :${WHITE} $VANGUARDSSTATUSb ${NOCOLOR}"
echo -e "${RED}TorBox Menu is locked to the following Branch:${WHITE} $TORBOXMENU_BRANCHNAME ${NOCOLOR}"
echo -e "$ROOT_DIR"
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
echo -e "${RED}[+] Stopping and masking tor${NOCOLOR}"
sudo systemctl stop tor
(sudo systemctl mask tor) 2> /dev/null
echo -e "${RED}[+] Deactivating all bridges${NOCOLOR}"
deactivate_obfs4_bridges
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
echo -e "${RED}[+] Resetting Tor statistics...${NOCOLOR}"
(sudo rm /var/log/tor/notices.log) 2> /dev/null
(sudo -u debian-tor touch /var/log/tor/notices.log) 2> /dev/null
(sudo rm /var/log/tor/vanguards.log) 2> /dev/null
(sudo -u debian-tor touch /var/log/tor/vanguards.log) 2> /dev/null
echo -e "${RED}[+] Deleting all stored wireless passwords${NOCOLOR}"
(sudo rm /etc/wpa_supplicant/wpa_supplicant-wlan0.conf) 2> /dev/null
(sudo rm /etc/wpa_supplicant/wpa_supplicant-wlan1.conf) 2> /dev/null
echo
erase_logs
echo
echo -e "${RED}[+] Setting the correct time${NOCOLOR}"
sudo /usr/sbin/ntpdate pool.ntp.org
sleep 3
echo " "
echo -e "${RED}[+] Setting the right start trigger${NOCOLOR}"
sudo sed -i "s/^FRESH_INSTALLED=.*/FRESH_INSTALLED=2/" ${RUNFILE}
echo -e "${RED}[+] Fixing and cleaning${NOCOLOR}"
sudo apt --fix-broken install
sudo apt-get -y clean; sudo apt-get -y autoclean; sudo apt-get -y autoremove
sudo setcap 'cap_net_bind_service=+ep' /usr/bin/obfs4proxy
sudo sed -i "s/^NoNewPrivileges=yes/NoNewPrivileges=no/g" /lib/systemd/system/tor@default.service
sudo sed -i "s/^NoNewPrivileges=yes/NoNewPrivileges=no/g" /lib/systemd/system/tor@.service
sudo systemctl daemon-reload
echo ""
echo -e "${WHITE}[!] PREPARATIONS FOR THE IMAGE IS FINISHED!${NOCOLOR}"
echo -e "${RED}[+] We will shutdown the TorBox now.${NOCOLOR}"
echo
read -n 1 -s -r -p $'\e[1;31mPlease press any key to continue... \e[0m'
clear
sudo shutdown -h now
