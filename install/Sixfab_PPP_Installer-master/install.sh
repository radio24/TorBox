#!/bin/bash

# This file is a part of TorBox, an easy to use anonymizing router based on Raspberry Pi.
# Copyright (C) 2025 Patrick Truffer
# Contact: anonym@torbox.ch
# Website: https://www.torbox.ch
# Github:  https://github.com/radio24/TorBox
#
# This file was initially created on November 27, 2020 by Yasin Kaya (selengalp)
# Location of last known original file: https://github.com/sixfab/Sixfab_PPP_Installer
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
# This file installs the support software for Sixfab Shields/HATs.
#
# SYNTAX
# ./install.sh
#
###### SET VARIABLES ######
#
# Colors
YELLOW='\033[1;33m'
RED='\033[1;31m'
BLUE='\033[1;34m'
WHITE='\033[1;37m'
SET='\033[0m'

# Global Varibales
POWERUP_REQ=1
POWERUP_NOT_REQ=0
STATUS_GPRS=19
STATUS_CELL_IOT_APP=20
STATUS_CELL_IOT=23
STATUS_TRACKER=23
POWERKEY_GPRS=26
POWERKEY_CELL_IOT_APP=11
POWERKEY_CELL_IOT=24
POWERKEY_TRACKER=24

# Paths
SOURCE_PATH="/home/torbox/torbox/install/Sixfab_PPP_Installer-master/src"
SCRIPT_PATH="$SOURCE_PATH/reconnect_scripts"
RECONNECT_SCRIPT_NAME="ppp_reconnect.sh"
MANAGER_SCRIPT_NAME="ppp_connection_manager.sh"
SERVICE_NAME="ppp_connection_manager.service"

clear
echo -e "${RED}[+] Installing Sixfab Shield/HATs support${NOCOLOR}"
echo -e ""

# Menu
clear
echo -e "${WHITE}Please choose your Sixfab Shield/HAT:${SET}"
echo -e "${RED}1: GSM/GPRS Shield${SET}"
echo -e "${RED}2: 3G, 4G/LTE Base Shield${SET}"
echo -e "${RED}3: Cellular IoT App Shield${SET}"
echo -e "${RED}4: Cellular IoT HAT${SET}"
echo -e "${RED}5: Tracker HAT${SET}"
echo -e "${RED}6: 3G/4G Base HAT${SET}"
echo -e ""

read shield_hat
clear
case $shield_hat in
    1)    echo -e "${RED}[+] You chose GSM/GPRS Shield${SET}";;
    2)    echo -e "${RED}[+] You chose Base Shield${SET}";;
    3)    echo -e "${RED}[+] You chose CellularIoT Shield${SET}";;
    4)    echo -e "${RED}[+] You chose CellularIoT HAT${SET}";;
	  5)    echo -e "${RED}[+] You chose Tracker HAT${SET}";;
	  6)    echo -e "${RED}[+] You chose 3G/4G Base HAT${SET}";;
    *)    echo -e "${WHITE}[!] Wrong Selection, exiting${SET}"; exit 1;
esac

echo
echo -e "${RED}[+] Copying setup files...${NOCOLOR}"
#Installing ppp and wiringpi is not necessary, because they are alredy there
#However, we have to copy some unchanged configuration files
cp  $SOURCE_PATH/chat-connect .
cp  $SOURCE_PATH/chat-disconnect .
cp  $SOURCE_PATH/provider .
#sudo cp /home/torbox/torbox/install/Sixfab_PPP_Installer-master/ppp_installer/unchanged_files/configure_modem.sh .
sleep 3
clear
echo -e "${RED}Enter your carrier APN:${SET}"
echo -e "${SET}(for more information see here: https://www.torbox.ch/?page_id=1030)${SET}"
read carrierapn

while [ 1 ]
do
  echo ""
	echo -e "${RED}Does your carrier need username and password? [Y/n]${SET}"
	read usernpass

	case $usernpass in
		[Yy]* )  while [ 1 ]
        do

        echo -e "${RED}Enter username${SET}"
        read username

        echo -e "${RED}Enter password${SET}"
        read password
        sed -i "s/noauth/#noauth\nuser \"$username\"\npassword \"$password\"/" provider
        break
        done

        break;;

		[Nn]* )  break;;
		*)  echo -e "${WHITE}Wrong Selection, Select among Y or n${SET}";;
	esac
done

mkdir -p /etc/chatscripts
cp chat-connect /etc/chatscripts/
cp chat-disconnect /etc/chatscripts/

mkdir -p /etc/ppp/peers
sed -i "s/#APN/$carrierapn/" provider
mv provider /etc/ppp/peers/provider
sed -i "s/^auth/#auth/" /etc/ppp/options

if ! (grep -q 'sudo route' /etc/ppp/ip-up ); then
    echo "sudo route add default ppp0" >> /etc/ppp/ip-up
fi

if [[ $shield_hat -eq 2 ]] || [[ $shield_hat -eq 6 ]]; then
	if ! (grep -q 'max_usb_current' /boot/config.txt ); then
		echo "max_usb_current=1" >> /boot/config.txt
	fi
fi

sleep 2
clear
echo -e "${WHITE}The installation of the Sixfab Shield/HATs support is done!${SET}"
echo -e "${RED}To connect to internet use main menu entry 8${SET}"
echo -e ""
read -n 1 -s -r -p "Press any key to continue"
