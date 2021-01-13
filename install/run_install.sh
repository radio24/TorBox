#!/bin/bash

# This file is a part of TorBox, an easy to use anonymizing router based on Raspberry Pi.
# Copyright (C) 2020 Patrick Truffer
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
# This script installs the newest version of TorBox on a clean, running
# Raspbian lite.
#
# SYNTAX
# ./run_install.sh
#
# IMPORTANT
# Start it as normal user (usually as pi)!
# Dont run it as root (no sudo)!
#
##########################################################

# Table of contents for this script:
#  1. Checking for Internet connection
#  2. Checking for the WLAN regulatory domain
#  3. Updating the system
#  4. Adding the Tor repository to the source list.
#  5. Installing all necessary packages
#  6. Configuring Tor and obfs4proxy
#  7. Re-checking Internet connectivity
#  8. Downloading and installing the latest version of TorBox
#  9. Installing all configuration files
# 10. Disabling Bluetooth
# 11. Configure the system services
# 12. Adding and implementing the user torbox
# 13. Finishing, cleaning and booting

##########################################################

##### SET VARIABLES ######
#
# SIZE OF THE MENU
#
# How many items do you have in the main menu?
NO_ITEMS=9
#
# How many lines are only for decoration and spaces?
NO_SPACER=0
#
#Set the the variables for the menu
MENU_WIDTH=80
MENU_WIDTH_REDUX=60
MENU_HEIGHT_25=25
MENU_HEIGHT_20=20
MENU_HEIGHT_15=15
MENU_HEIGHT=$((8+NO_ITEMS+NO_SPACER))
MENU_LIST_HEIGHT=$((NO_ITEMS+$NO_SPACER))

#Colors
RED='\033[1;31m'
WHITE='\033[1;37m'
NOCOLOR='\033[0m'

#Other variables


###### DISPLAY THE INTRO ######
clear
whiptail --title "TorBox Installation on Raspberry Pi OS" --msgbox "\n\n        WELCOME TO THE INSTALLATION OF TORBOX ON RASPBERRY PI OS\n\nThis installation runs without user interaction AND CHANGES/DELETES THE CURRENT CONFIGURATION. During the installation, we are going to set up the user \"torbox\" with the default password \"CHANGE-IT\". This user name and the password will be used for logging into your TorBox and to administering it. Please, change the default passwords as soon as possible (the associated menu entries are placed in the configuration sub-menu). We will also disable the user \"pi\"\n\nIMPORTANT: Internet connectivity is necessary for the installation.\n\nIn case of any problems, contact us on https://www.torbox.ch" $MENU_HEIGHT_20 $MENU_WIDTH
clear

# 1. Checking for Internet connection
# Currently a working Internet connection is mandatory. Probably in a later
# version, we will include an option to install the TorBox from a compressed
# file.

clear
echo -e "${RED}[+] Step 1: Do we have Internet?${NOCOLOR}"
wget -q --spider http://google.com
if [ $? -eq 0 ]; then
  echo -e "${RED}[+]         Yes, we have! :-)${NOCOLOR}"
else
  echo -e "${WHITE}[!]         Hmmm, no we don't have... :-(${NOCOLOR}"
  echo -e "${RED}[+]         We will check again in about 30 seconds...${NOCOLOR}"
  sleep 30
  echo ""
  echo -e "${RED}[+]         Trying again...${NOCOLOR}"
  wget -q --spider https://google.com
  if [ $? -eq 0 ]; then
    echo -e "${RED}[+]         Yes, now, we have an Internet connection! :-)${NOCOLOR}"
  else
    echo -e "${WHITE}[!]         Hmmm, still no Internet connection... :-(${NOCOLOR}"
    echo -e "${RED}[+]         We will try to catch a dynamic IP adress and check again in about 30 seconds...${NOCOLOR}"
    (sudo dhclient -r) 2>&1
    sleep 5
    sudo dhclient &>/dev/null &
    sleep 30
    echo ""
    echo -e "${RED}[+]         Trying again...${NOCOLOR}"
    wget -q --spider https://google.com
    if [ $? -eq 0 ]; then
      echo -e "${RED}[+]         Yes, now, we have an Internet connection! :-)${NOCOLOR}"
    else
      echo -e "${WHITE}[!]         Hmmm, still no Internet connection... :-(${NOCOLOR}"
      echo -e "${RED}[+]         We will add a Google nameserver (8.8.8.8) to /etc/resolv.conf and try again...${NOCOLOR}"
      sudo cp /etc/resolv.conf /etc/resolv.conf.bak
      (sudo printf "\n# Added by TorBox install script\nnameserver 8.8.8.8\n" | sudo tee -a /etc/resolv.conf) 2>&1
      sleep 15
      echo ""
      echo -e "${RED}[+]         Dumdidum...${NOCOLOR}"
      sleep 15
      echo -e "${RED}[+]         Trying again...${NOCOLOR}"
      wget -q --spider https://google.com
      if [ $? -eq 0 ]; then
        echo -e "${RED}[+]         Yes, now, we have an Internet connection! :-)${NOCOLOR}"
      else
        echo -e "${RED}[+]         Hmmm, still no Internet connection... :-(${NOCOLOR}"
        echo -e "${RED}[+]         Internet connection is mandatory. We cannot continue - giving up!${NOCOLOR}"
        exit 1
      fi
    fi
  fi
fi

# 2. Check the status of the WLAN regulatory domain to be sure WiFi will work
sleep 10
clear
echo -e "${RED}[+] Step 2: Check the status of the WLAN regulatory domain...${NOCOLOR}"
COUNTRY=$(sudo iw reg get | grep country | cut -d " " -f2)
if [ "$COUNTRY" = "00:" ] ; then
  echo -e "${WHITE}[!]         No WLAN regulatory domain set - that will lead to problems!${NOCOLOR}"
  echo -e "${WHITE}[!]         Therefore we will set it to US! You can change it later.${NOCOLOR}"
  sudo iw reg set US
  INPUT="REGDOMAIN=US"
  sudo sed -i "s/^REGDOMAIN=.*/${INPUT}/" /etc/default/crda
else
  echo -e "${RED}[+]         The WLAN regulatory domain is set correctly! ${NOCOLOR}"
fi
echo -e "${RED}[+]         To be sure we will unblock wlan, now! ${NOCOLOR}"
sudo rfkill unblock wlan

# 3. Updating the system
sleep 10
clear
echo -e "${RED}[+] Step 3: Updating the system...${NOCOLOR}"
sudo apt-get -y update
sudo apt-get -y dist-upgrade
sudo apt-get -y clean
sudo apt-get -y autoclean
sudo apt-get -y autoremove

# 4. Adding the Tor repository to the source list.
sleep 10
clear
echo -e "${RED}[+] Step 4: Adding the Tor repository to the source list....${NOCOLOR}"
echo ""
sudo cp /etc/apt/sources.list /etc/apt/sources.list.bak
sudo printf "\n# Added by TorBox update script\ndeb https://deb.torproject.org/torproject.org buster main\ndeb-src https://deb.torproject.org/torproject.org buster main\n" | sudo tee -a /etc/apt/sources.list
sudo curl https://deb.torproject.org/torproject.org/A3C4F0F979CAA22CDBA8F512EE8CBC9E886DDD89.asc | sudo apt-key add -
sudo apt-get update

# 5. Installing all necessary packages
sleep 10
clear
echo -e "${RED}[+] Step 5: Installing all necessary packages....${NOCOLOR}"
sudo apt-get -y install hostapd isc-dhcp-server obfs4proxy usbmuxd dnsmasq dnsutils tcpdump iftop vnstat links2 debian-goodies apt-transport-https dirmngr python3-setuptools python3-pip python3-pil imagemagick tesseract-ocr ntpdate screen nyx git openvpn ppp wiringpi
sudo apt-get -y install tor deb.torproject.org-keyring

# Additional installations for Python
sudo pip3 install pytesseract
sudo pip3 install mechanize

# 6. Configuring Tor and obfs4proxy
sleep 10
clear
echo -e "${RED}[+] Step 6: Configuring Tor and obfs4proxy....${NOCOLOR}"
sudo setcap 'cap_net_bind_service=+ep' /usr/bin/obfs4proxy
sudo sed -i "s/^NoNewPrivileges=yes/NoNewPrivileges=no/g" /lib/systemd/system/tor@default.service
sudo sed -i "s/^NoNewPrivileges=yes/NoNewPrivileges=no/g" /lib/systemd/system/tor@.service

# 7 Again checking connectivity
sleep 10
clear
echo -e "${RED}[+] Step 7: Re-checking Internet connectivity${NOCOLOR}"
wget -q --spider http://google.com
if [ $? -eq 0 ]; then
  echo -e "${RED}[+]         Yes, we have still Internet connectivity! :-)${NOCOLOR}"
else
  echo -e "${RED}[+]          Hmmm, no we don't have... :-(${NOCOLOR}"
  echo -e "${RED}[+]          We will check again in about 30 seconds...${NOCOLOR}"
  sleeo 30
  echo -e "${RED}[+]          Trying again...${NOCOLOR}"
  wget -q --spider https://google.com
  if [ $? -eq 0 ]; then
    echo -e "${RED}[+]          Yes, now, we have an Internet connection! :-)${NOCOLOR}"
  else
    echo -e "${RED}[+]          Hmmm, still no Internet connection... :-(${NOCOLOR}"
    echo -e "${RED}[+]          We will try to catch a dynamic IP adress and check again in about 30 seconds...${NOCOLOR}"
    sudo dhclient -r
    sleep 5
    sudo dhclient &>/dev/null &
    sleep 30
    echo -e "${RED}[+]          Trying again...${NOCOLOR}"
    wget -q --spider https://google.com
    if [ $? -eq 0 ]; then
      echo -e "${RED}[+]          Yes, now, we have an Internet connection! :-)${NOCOLOR}"
    else
      echo -e "${RED}[+]          Hmmm, still no Internet connection... :-(${NOCOLOR}"
      echo -e "${RED}[+]          We will add a Google nameserver (8.8.8.8) to /etc/resolv.conf and try again...${NOCOLOR}"
      sudo cp /etc/resolv.conf /etc/resolv.conf.bak
      sudo printf "\n# Added by TorBox install script\nnameserver 8.8.8.8\n" | sudo tee -a /etc/resolv.conf
      sleep 15
      echo ""
      echo -e "${RED}[+]          Dumdidum...${NOCOLOR}"
      sleep 15
      echo -e "${RED}[+]          Trying again...${NOCOLOR}"
      wget -q --spider https://google.com
      if [ $? -eq 0 ]; then
        echo -e "${RED}[+]          Yes, now, we have an Internet connection! :-)${NOCOLOR}"
      else
        echo -e "${RED}[+]          Hmmm, still no Internet connection... :-(${NOCOLOR}"
        echo -e "${RED}[+]          Internet connection is mandatory. We cannot continue - giving up!${NOCOLOR}"
        exit 1
      fi
    fi
  fi
fi

# 8. Downloading and installing the latest version of TorBox
sleep 10
clear
echo -e "${RED}[+] Step 8: Downloading and installing the latest version of TorBox...${NOCOLOR}"
cd
echo -e "${RED}[+]         Downloading TorBox menu from GitHub...${NOCOLOR}"
wget https://github.com/radio24/TorBox/archive/master.zip
if [ -e master.zip ]; then
  echo -e "${RED}[+]       Unpacking TorBox menu...${NOCOLOR}"
  unzip master.zip
  echo ""
  echo -e "${RED}[+]       Removing the old one...${NOCOLOR}"
  (rm -r torbox) 2> /dev/null
  echo -e "${RED}[+]       Moving the new one...${NOCOLOR}"
  mv TorBox-master torbox
  echo -e "${RED}[+]       Cleaning up...${NOCOLOR}"
  (rm -r master.zip) 2> /dev/null
  echo ""
else
  echo -e "${RED} ${NOCOLOR}"
  echo -e "${WHITE}[!]      Downloading TorBox menu from GitHub failed !!${NOCOLOR}"
  echo -e "${WHITE}[!]      I'can't update TorBox menu !!${NOCOLOR}"
  echo -e "${WHITE}[!]      You may try it later or manually !!${NOCOLOR}"
  sleep 2
  exit 1
fi

# 9. Installing all configuration files
sleep 10
clear
cd torbox
echo -e "${RED}[+] Step 9: Installing all configuration files....${NOCOLOR}"
(sudo cp /etc/default/hostapd /etc/default/hostapd.bak) 2> /dev/null
sudo cp etc/default/hostapd /etc/default/
echo -e "${RED}[+] Copied /etc/default/hostapd -- backup done${NOCOLOR}"
(sudo cp /etc/default/isc-dhcp-server /etc/default/isc-dhcp-server.bak) 2> /dev/null
sudo cp etc/default/isc-dhcp-server /etc/default/
echo -e "${RED}[+] Copied /etc/default/isc-dhcp-server -- backup done${NOCOLOR}"
(sudo cp /etc/dhcp/dhclient.conf /etc/dhcp/dhclient.conf.bak) 2> /dev/null
sudo cp etc/dhcp/dhclient.conf /etc/dhcp/
echo -e "${RED}[+] Copied /etc/dhcp/dhclient.conf -- backup done${NOCOLOR}"
(sudo cp /etc/dhcp/dhcpd.conf /etc/dhcp/dhcpd.conf.bak) 2> /dev/null
sudo cp etc/dhcp/dhcpd.conf /etc/dhcp/
echo -e "${RED}[+] Copied /etc/dhcp/dhcpd.conf -- backup done${NOCOLOR}"
(sudo cp /etc/hostapd/hostapd.conf /etc/hostapd/hostapd.conf.bak) 2> /dev/null
sudo cp etc/hostapd/hostapd.conf /etc/hostapd/
echo -e "${RED}[+] Copied /etc/hostapd/hostapd.conf -- backup done${NOCOLOR}"
(sudo cp /etc/iptables.ipv4.nat /etc/iptables.ipv4.nat.bak) 2> /dev/null
sudo cp etc/iptables.ipv4.nat /etc/
echo -e "${RED}[+] Copied /etc/iptables.ipv4.nat -- backup done${NOCOLOR}"
(sudo cp /etc/motd /etc/motd.bak) 2> /dev/null
sudo cp etc/motd /etc/
echo -e "${RED}[+] Copied /etc/motd -- backup done${NOCOLOR}"
(sudo cp /etc/network/interfaces /etc/network/interfaces.bak) 2> /dev/null
sudo cp etc/network/interfaces /etc/network/
echo -e "${RED}[+] Copied /etc/network/interfaces -- backup done${NOCOLOR}"
(sudo cp /etc/rc.local /etc/rc.local.bak) 2> /dev/null
sudo cp etc/rc.local /etc/
echo -e "${RED}[+] Copied /etc/rc.local -- backup done${NOCOLOR}"
if grep -q "#net.ipv4.ip_forward=1" /etc/sysctl.conf ; then
  sudo cp /etc/sysctl.conf /etc/sysctl.conf.bak
  sudo sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
  echo -e "${RED}[+] Changed /etc/sysctl.conf -- backup done${NOCOLOR}"
fi
(sudo cp /etc/tor/torrc /etc/tor/torrc.bak) 2> /dev/null
sudo cp etc/tor/torrc /etc/tor/
echo -e "${RED}[+] Copied /etc/tor/torrc -- backup done${NOCOLOR}"
echo -e "${RED}[+] Activating IP forwarding${NOCOLOR}"
sudo sh -c "echo 1 > /proc/sys/net/ipv4/ip_forward"
echo -e "${RED}[+] Changing .profile if necessary${NOCOLOR}"
cd
if ! grep "# Added by TorBox" .profile ; then
  sudo cp .profile .profile.bak
  sudo printf "\n# Added by TorBox\ncd torbox\nsleep 2\n./menu\n" | sudo tee -a .profile
fi
cd

# 10. Disabling Bluetooth
sleep 10
clear
echo -e "${RED}[+] Step 10: Because of security considerations, we completely disable the Bluetooth functionality${NOCOLOR}"
if ! grep "# Added by TorBox" /boot/config.txt ; then
  sudo printf "\n# Added by TorBox\ndtoverlay=disable-bt\n" | sudo tee -a /boot/config.txt
  sudo systemctl disable hciuart.service
  sudo systemctl disable bluealsa.service
  sudo systemctl disable bluetooth.service
  sudo apt-get -y purge bluez
  sudo apt-get -y autoremove
fi

# 11. Configure the system services
sleep 10
clear
echo -e "${RED}[+] Step 11: Configure the system services...${NOCOLOR}"
sudo systemctl unmask hostapd
sudo systemctl enable hostapd
sudo systemctl start hostapd
sudo systemctl unmask isc-dhcp-server
sudo systemctl enable isc-dhcp-server
sudo systemctl start isc-dhcp-server
sudo systemctl unmask tor
sudo systemctl enable tor
sudo systemctl start tor
sudo systemctl unmask ssh
sudo systemctl enable ssh
sudo systemctl start ssh
sudo systemctl disable dhcpcd
sudo systemctl stop dnsmasq
sudo systemctl disable dnsmasq
sudo systemctl daemon-reload
echo ""
echo -e "${RED}[+]          Stop logging, now..${NOCOLOR}"
sudo systemctl stop rsyslog
sudo systemctl disable rsyslog
echo""

# 12. Adding the user torbox
sleep 10
clear
echo -e "${RED}[+] Step 12: Set up the torbox user...${NOCOLOR}"
echo -e "${RED}[+]          In this step the user \"torbox\" with the default${NOCOLOR}"
echo -e "${RED}[+]          password \"CHANGE-IT\" is created.  ${NOCOLOR}"
echo ""
echo -e "${WHITE}[!] IMPORTANT${NOCOLOR}"
echo -e "${WHITE}    To use TorBox, you have to log in with \"torbox\"${NOCOLOR}"
echo -e "${WHITE}    and the default password \"CHANGE-IT\"!!${NOCOLOR}"
echo -e "${WHITE}    Please, change the default passwords as soon as possible!!${NOCOLOR}"
echo -e "${WHITE}    The associated menu entries are placed in the configuration sub-menu.${NOCOLOR}"
echo ""
sudo adduser --disabled-password --gecos "" torbox
echo -e "CHANGE-IT\nCHANGE-IT\n" | sudo passwd torbox
sudo adduser torbox sudo
sudo adduser torbox netdev
sudo mv /home/pi/* /home/torbox/
(sudo mv /home/pi/.profile /home/torbox/) 2> /dev/null
sudo mkdir /home/torbox/openvpn
(sudo rm .bash_history) 2> /dev/null
sudo chown -R torbox.torbox /home/torbox/
if ! sudo grep "# Added by TorBox" /etc/sudoers ; then
  sudo printf "\n# Added by TorBox\ntorbox  ALL=(ALL) NOPASSWD: ALL\n" | sudo tee -a /etc/sudoers
  (sudo visudo -c) 2> /dev/null
fi
cd /home/torbox/

# 13. Finishing, cleaning and booting
echo ""
echo ""
echo -e "${RED}[+] Step 13: We are finishing and cleaning up now!${NOCOLOR}"
echo -e "${RED}[+]          This will erase all log files and cleaning up the system.${NOCOLOR}"
echo -e "${RED}[+]          For security reason, we will lock the \"pi\" account.${NOCOLOR}"
echo -e "${RED}[+]          This can be undone with \"sudo chage -E-1 pi\" (with its default password).${NOCOLOR}"
echo -e "${RED}[+]          If you don't need the \"pi\" account anymore, you can remove it with \"sudo userdel -r pi\".${NOCOLOR}"
echo ""
echo -e "${WHITE}[!] IMPORTANT${NOCOLOR}"
echo -e "${WHITE}    After this last step, TorBox has to be rebooted manually.${NOCOLOR}"
echo -e "${WHITE}    In order to do so type \"exit\" and log in with \"torbox\" and the default password \"CHANGE-IT\"!! ${NOCOLOR}"
echo -e "${WHITE}    Then in the TorBox menu, you have to chose entry 14.${NOCOLOR}"
echo -e "${WHITE}    After rebooting, please, change the default passwords immediately!!${NOCOLOR}"
echo -e "${WHITE}    The associated menu entries are placed in the configuration sub-menu.${NOCOLOR}"
echo ""
read -n 1 -s -r -p $'\e[1;31mTo complete the installation, please press any key... \e[0m'
clear
echo -e "${RED}[+] Erasing ALL LOG-files...${NOCOLOR}"
echo " "
for logs in `sudo find /var/log -type f`; do
  echo -e "${RED}[+]${NOCOLOR} Erasing $logs"
  sudo rm $logs
  sleep 1
done
echo -e "${RED}[+]${NOCOLOR} Erasing History..."
#.bash_history is already deleted
history -c
echo ""
echo -e "${RED}[+] Setting up the hostname...${NOCOLOR}"
# This has to be at the end to avoid unnecessary error messages
sudo cp /etc/hostname /etc/hostname.bak
sudo cp torbox/etc/hostname /etc/
echo -e "${RED}[+]Copied /etc/hostname -- backup done${NOCOLOR}"
sudo cp /etc/hosts /etc/hosts.bak
sudo cp torbox/etc/hosts /etc/
echo -e "${RED}[+]Copied /etc/hosts -- backup done${NOCOLOR}"
echo -e "${RED}[+]Disable the user pi...${NOCOLOR}"
# This can be undone by sudo chage -E-1 pi
# Later, you can also delete the user pi with "sudo userdel -r pi"
echo ""
echo -e "${WHITE}[!] IMPORTANT${NOCOLOR}"
echo -e "${WHITE}    TorBox has to be rebooted manually.${NOCOLOR}"
echo -e "${WHITE}    In order to do so type \"exit\" and log in with \"torbox\" and the default password \"CHANGE-IT\"!! ${NOCOLOR}"
echo -e "${WHITE}    Then in the TorBox menu, you have to chose entry 14.${NOCOLOR}"
echo -e "${WHITE}    After rebooting, please, change the default passwords immediately!!${NOCOLOR}"
echo -e "${WHITE}    The associated menu entries are placed in the configuration sub-menu.${NOCOLOR}"
(sudo chage -E0 pi) 2> /dev/null
