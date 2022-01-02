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
# If TorBox was installed with VANGUARDS_INSTALL="NO" then this script
# can install Vanguards later.
#
# SYNTAX
# ./install_vanguards.sh
#
# IMPORTANT
# Start it as normal user (usually as trobox)!
# Dont run it as root (no sudo)!
#
###### SET VARIABLES ######

#Colors
RED='\033[1;31m'
WHITE='\033[1;37m'
NOCOLOR='\033[0m'

# Vanguards Repository
VANGUARDS_USED="https://github.com/mikeperry-tor/vanguards"
VANGUARDS_COMMIT_HASH=10942de
VANGUARDS_LOG_FILE="/var/log/tor/vanguards.log"

# Default password
DEFAULT_PASS="CHANGE-IT"

clear
cd
echo -e "${RED}[+] Step 8: Installing Vanguards...${NOCOLOR}"
(sudo rm -rf vanguards) 2> /dev/null
(sudo rm -rf /var/lib/tor/vanguards) 2> /dev/null
sudo git clone $VANGUARDS_USED
DLCHECK=$?
if [ $DLCHECK -eq 0 ]; then
  sleep 1
else
  echo ""
  echo -e "${WHITE}[!] COULDN'T CLONE THE VANGUARDS REPOSITORY!${NOCOLOR}"
  echo -e "${RED}[+] The Vanguards repository may be blocked or offline!${NOCOLOR}"
  echo -e "${RED}[+] Please try again later and if the problem persists, please report it${NOCOLOR}"
  echo -e "${RED}[+] to ${WHITE}anonym@torbox.ch${RED}. ${NOCOLOR}"
  echo ""
  read -n 1 -s -r -p $'\e[1;31mPlease press any key to continue... \e[0m'
  clear
fi
sudo chown -R debian-tor:debian-tor vanguards
cd vanguards
sudo -u debian-tor git reset --hard ${VANGUARDS_COMMIT_HASH}
cd
sudo mv vanguards /var/lib/tor/
sudo cp /var/lib/tor/vanguards/vanguards-example.conf /etc/tor/vanguards.conf
sudo sed -i "s/^control_pass =.*/control_pass = ${DEFAULT_PASS}/" /etc/tor/vanguards.conf
#This is necessary to work with special characters in sed
sudo sed -i "s|^logfile =.*|logfile = ${VANGUARDS_LOG_FILE}|" /etc/tor/vanguards.conf
# Because of TorBox's automatic counteractions, Vanguard cannot interfere with tor's log file
sudo sed -i "s/^enable_logguard =.*/enable_logguard = False/" /etc/tor/vanguards.conf
sudo sed -i "s/^log_protocol_warns =.*/log_protocol_warns = False/" /etc/tor/vanguards.conf
sudo chown -R debian-tor:debian-tor /var/lib/tor/vanguards
sudo chmod -R go-rwx /var/lib/tor/vanguards
(sudo -u debian-tor touch /var/log/tor/vanguards.log) 2> /dev/null
(sudo chmod -R go-rwx /var/log/tor/vanguards.log) 2> /dev/null
cd torbox
sudo cp etc/systemd/system/vanguards@default.service /etc/systemd/system/
(sudo systemctl unmask vanguards@default.service) 2> /dev/null
(sudo systemctl enable vanguards@default.service) 2> /dev/null
sudo systemctl daemon-reload
(sudo systemctl start vanguards@default.service) 2> /dev/null
