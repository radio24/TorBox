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
# Ubuntu 20.04 LTS (32bit; https://ubuntu.com/download/raspberry-pi).
#
# SYNTAX
# ./run_install_on_ubuntu.sh
#
# IMPORTANT
# Start it as normal user (usually as ubuntu)!
# Dont run it as root (no sudo)!
# If Ubuntu 20.04 is freshly installed, you have to wait one or two minutes until you can log in with ubuntu / ubuntu
#
##########################################################

# Table of contents for this script:
# 1. Checking for Internet connection
# 2. Checking for the WLAN regulatory domain
# 3. Updating the system
# 4. Adding the Tor repository to the source list.
# 5. Installing all necessary packages
# 6. Configuring Tor and obfs4proxy
# 7. Again checking connectivity
# 8. Downloading and installing the latest version of TorBox
# 9. Installing all configuration files
#10. Disabling Bluetooth
#11. hanging the password of pi to "CHANGE-IT"
#12. Configure the system services and rebooting

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
MENU_HEIGHT_15=15
MENU_HEIGHT=$((8+NO_ITEMS+NO_SPACER))
MENU_LIST_HEIGHT=$((NO_ITEMS+$NO_SPACER))

#Colors
RED='\033[1;31m'
WHITE='\033[1;37m'
NOCOLOR='\033[0m'

#Other variables


# 0. Read state
if test -f .log; then
    state=$(cat .log)
else
    state=1
fi



case $state in

1 )
# 1. Checking for Internet connection
# Currently a working Internet connection is mandatory. Probably in a later
# version, we will include an option to install the TorBox from a compressed
# file.

clear
echo -e "${RED}[+] Step 1: Do we have Internet?${NOCOLOR}"
wget -q --spider http://ubuntu.com
if [ $? -eq 0 ]; then
  echo -e "${RED}[+] Yes, we have! :-)${NOCOLOR}"
else
  echo -e "${WHITE}[!] Hmmm, no we don't have... :-(${NOCOLOR}"
  echo -e "${RED}[+] We will check again in about 30 seconds...${NOCOLOR}"
  sleep 30
  echo ""
  echo -e "${RED}[+] Trying again...${NOCOLOR}"
  wget -q --spider http://ubuntu.com
  if [ $? -eq 0 ]; then
    echo -e "${RED}[+] Yes, now, we have an Internet connection! :-)${NOCOLOR}"
  else
    echo -e "${WHITE}[!] Hmmm, still no Internet connection... :-(${NOCOLOR}"
    echo -e "${RED}[+] We will try to catch a dynamic IP adress and check again in about 30 seconds...${NOCOLOR}"
    (sudo dhclient -r) 2>&1
    sleep 5
    sudo dhclient &>/dev/null &
    sleep 30
    echo ""
    echo -e "${RED}[+] Trying again...${NOCOLOR}"
    wget -q --spider http://ubuntu.com
    if [ $? -eq 0 ]; then
      echo -e "${RED}[+] Yes, now, we have an Internet connection! :-)${NOCOLOR}"
    else
      echo -e "${WHITE}[!] Hmmm, still no Internet connection... :-(${NOCOLOR}"
      echo -e "${RED}[+] We will add a Google nameserver (8.8.8.8) to /etc/resolv.conf and try again...${NOCOLOR}"
      sudo cp /etc/resolv.conf /etc/resolv.conf.bak
      (sudo printf "\n# Added by TorBox install script\nnameserver 8.8.8.8\n" | sudo tee -a /etc/resolv.conf) 2>&1
      sleep 15
      echo -e "${RED}[+] Dumdidum...${NOCOLOR}"
      sleep 15
      echo -e "${RED}[+] Trying again...${NOCOLOR}"
      wget -q --spider http://ubuntu.com
      if [ $? -eq 0 ]; then
        echo -e "${RED}[+] Yes, now, we have an Internet connection! :-)${NOCOLOR}"
      else
        echo -e "${RED}[+] Hmmm, still no Internet connection... :-(${NOCOLOR}"
        echo -e "${RED}[+] Internet connection is mandatory. We cannot continue - giving up!${NOCOLOR}"
        exit 1
      fi
    fi
  fi
fi

# 2. Check the status of the WLAN regulatory domain to be sure WiFi will work
# sleep 10
# clear
# echo -e "${RED}[+] Step 2: Check the status of the WLAN regulatory domain...${NOCOLOR}"
# COUNTRY=$(sudo iw reg get | grep country | cut -d " " -f2)
# if [ "$COUNTRY" = "00:" ] ; then
#  echo -e "${WHITE}[!] No WLAN regulatory domain set - that will lead to problems!${NOCOLOR}"
#  echo -e "${WHITE}[!] Therefore we will set it to US! You can change it later.${NOCOLOR}"
#  sudo iw reg set US
#  INPUT="REGDOMAIN=US"
#  sudo sed -i "s/^REGDOMAIN=.*/${INPUT}/" /etc/default/crda
# else
#  echo -e "${RED}[+] The WLAN regulatory domain is set correctly! ${NOCOLOR}"
# fi
# echo -e "${RED}[+] To be sure we will unblock wlan, now! ${NOCOLOR}"
# sudo rfkill unblock wlan

echo 3 | tee .log
exit 1;;
3 )
# 3. Updating the system
sleep 10
clear
echo -e "${RED}[+] Step 3: Remove Ubuntus' unattended update feature...${NOCOLOR}"
(sudo killall unattended-upgr) 2> /dev/null
sleep 10
sudo apt-get -y remove unattended-upgrades
sudo dpkg --configure -a
echo -e "${RED}[+] Step 3: Updating the system and installing additional software...${NOCOLOR}"
sudo apt-get -y update
sudo apt-get -y dist-upgrade
sudo apt-get -y clean
sudo apt-get -y autoclean
sudo apt-get -y autoremove

# 4. Adding the Tor repository to the source list.
# sleep 10
# clear
# echo -e "${RED}[+] Step 4: Adding the Tor repository to the source list....${NOCOLOR}"
# echo ""
# sudo cp /etc/apt/sources.list /etc/apt/sources.list.bak
# sudo printf "\n# Added by TorBox update script\ndeb https://deb.torproject.org/torproject.org buster main\ndeb-src https://deb.torproject.org/torproject.org buster main\n" | sudo tee -a /etc/apt/sources.list
# sudo curl https://deb.torproject.org/torproject.org/A3C4F0F979CAA22CDBA8F512EE8CBC9E886DDD89.asc | sudo apt-key add -
# sudo apt-get update

echo 4 | tee .log
exit 1;;
4 )
# 4. Installing all necessary packages
# The problem with Ubuntu 20.04 is that they removed the support for python2 which is necessary for wicd
sleep 10
clear
echo -e "${RED}[+] Step 4: Installing all necessary packages....${NOCOLOR}"
sudo apt-get -y install python2 hostapd isc-dhcp-server obfs4proxy usbmuxd dnsmasq dnsutils tcpdump iftop vnstat links2 debian-goodies apt-transport-https dirmngr python3-setuptools ntpdate screen nyx tor net-tools ifupdown unzip equivs
curl https://bootstrap.pypa.io/get-pip.py --output get-pip.py
sudo python2 get-pip.py

# urwid for python2, which is necessary for wicd-curse
sudo pip install urwid

echo 5 | tee .log
exit 1;;
5 )
# 5. Installing wicd (this is necessary because starting with Ubuntu 20.04, they kicked the package out of their repository; see also here: https://askubuntu.com/questions/1240154/how-to-install-wicd-on-ubuntu-20-04)
echo -e "${RED}[+] Step 5: Installing wicd....${NOCOLOR}"

mkdir -p ~/Downloads/wicd
cd ~/Downloads/wicd
wget http://archive.ubuntu.com/ubuntu/pool/universe/w/wicd/python-wicd_1.7.4+tb2-6_all.deb
wget http://archive.ubuntu.com/ubuntu/pool/universe/w/wicd/wicd-daemon_1.7.4+tb2-6_all.deb
wget http://archive.ubuntu.com/ubuntu/pool/universe/w/wicd/wicd_1.7.4+tb2-6_all.deb
wget http://archive.ubuntu.com/ubuntu/pool/universe/w/wicd/wicd-curses_1.7.4+tb2-6_all.deb
wget http://archive.ubuntu.com/ubuntu/pool/universe/w/wicd/wicd-cli_1.7.4+tb2-6_all.deb
cd
sudo apt-get -y install ./Downloads/wicd/python-wicd_1.7.4+tb2-6_all.deb
sudo apt-get -y install ./Downloads/wicd/wicd-daemon_1.7.4+tb2-6_all.deb
sudo apt-get -y install ./Downloads/wicd/wicd-cli_1.7.4+tb2-6_all.deb

# Creating a dependency-dummy für wicd-curses (based on https://unix.stackexchange.com/questions/404444/how-to-make-apt-ignore-unfulfilled-dependencies-of-installed-package)
equivs-control python-urwid.control
sed -i "s/Package: <package name; defaults to equivs-dummy>/Package: python-urwid/g" python-urwid.control
sed -i "s/^# Version: <enter version here; defaults to 1.0>/Version: 1.2/g" python-urwid.control
equivs-build python-urwid.control
sudo dpkg -i python-urwid_1.2_all.deb

# Finally !!!
sudo apt-get -y install ./Downloads/wicd/wicd-curses_1.7.4+tb2-6_all.deb

echo 6 | tee .log
exit 1;;
6 )
# 6. Configuring Tor and obfs4proxy
sleep 10
clear
echo -e "${RED}[+] Step 6: Configuring Tor and obfs4proxy....${NOCOLOR}"
sudo setcap 'cap_net_bind_service=+ep' /usr/bin/obfs4proxy
sudo sed -i "s/^NoNewPrivileges=yes/NoNewPrivileges=no/g" /lib/systemd/system/tor@default.service
sudo sed -i "s/^NoNewPrivileges=yes/NoNewPrivileges=no/g" /lib/systemd/system/tor@.service

echo 7 | tee .log
exit 1;;
7 )
# 7 Again checking connectivity
sleep 10
clear
echo -e "${RED}[+] Step 7: Re-checking Internet connectivity${NOCOLOR}"
wget -q --spider http://google.com
if [ $? -eq 0 ]; then
  echo -e "${RED}[+] Yes, we have still Internet connectivity! :-)${NOCOLOR}"
else
  echo -e "${RED}[+] Hmmm, no we don't have... :-(${NOCOLOR}"
  echo -e "${RED}[+] We will check again in about 30 seconds...${NOCOLOR}"
  sleeo 30
  echo -e "${RED}[+] Trying again...${NOCOLOR}"
  wget -q --spider https://google.com
  if [ $? -eq 0 ]; then
    echo -e "${RED}[+] Yes, now, we have an Internet connection! :-)${NOCOLOR}"
  else
    echo -e "${RED}[+] Hmmm, still no Internet connection... :-(${NOCOLOR}"
    echo -e "${RED}[+] We will try to catch a dynamic IP adress and check again in about 30 seconds...${NOCOLOR}"
    sudo dhclient -r
    sleep 5
    sudo dhclient &>/dev/null &
    sleep 30
    echo -e "${RED}[+] Trying again...${NOCOLOR}"
    wget -q --spider https://google.com
    if [ $? -eq 0 ]; then
      echo -e "${RED}[+] Yes, now, we have an Internet connection! :-)${NOCOLOR}"
    else
      echo -e "${RED}[+] Hmmm, still no Internet connection... :-(${NOCOLOR}"
      echo -e "${RED}[+] We will add a Google nameserver (8.8.8.8) to /etc/resolv.conf and try again...${NOCOLOR}"
      sudo cp /etc/resolv.conf /etc/resolv.conf.bak
      sudo printf "\n# Added by TorBox install script\nnameserver 8.8.8.8\n" | sudo tee -a /etc/resolv.conf
      sleep 15
      echo -e "${RED}[+] Dumdidum...${NOCOLOR}"
      sleep 15
      echo -e "${RED}[+] Trying again...${NOCOLOR}"
      wget -q --spider https://google.com
      if [ $? -eq 0 ]; then
        echo -e "${RED}[+] Yes, now, we have an Internet connection! :-)${NOCOLOR}"
      else
        echo -e "${RED}[+] Hmmm, still no Internet connection... :-(${NOCOLOR}"
        echo -e "${RED}[+] Internet connection is mandatory. We cannot continue - giving up!${NOCOLOR}"
        exit 1
      fi
    fi
  fi
fi

# 8. Downloading and installing the latest version of TorBox
sleep 10
clear
echo -e "${RED}[+] Step 8: Download and install the latest version of TorBox....${NOCOLOR}"
cd
echo -e "${RED}[+]         Downloading TorBox menu from GitHub...${NOCOLOR}"
wget https://github.com/radio24/TorBox/archive/master.zip
if [ -e master.zip ]; then
  echo -e "${RED}[+]       Unpacking TorBox menu...${NOCOLOR}"
  unzip master.zip
  echo -e "${RED}[+]       Removing the old one...${NOCOLOR}"
  rm -r torbox
  echo -e "${RED}[+]       Moving the new one...${NOCOLOR}"
  mv TorBox-master torbox
  echo -e "${RED}[+]       Cleaning up...${NOCOLOR}"
  (rm -r master.zip) 2> /dev/null
  # Only Ubuntu - Sets the background of TorBox menu to dark blue
  sudo rm /etc/alternatives/newt-palette; sudo ln -s /etc/newt/palette.original /etc/alternatives/newt-palette
  echo ""
else
  echo -e "${RED} ${NOCOLOR}"
  echo -e "${WHITE}[!]      Downloading TorBox menu from GitHub failed !!${NOCOLOR}"
  echo -e "${WHITE}[!]      I'can't update TorBox menu !!${NOCOLOR}"
  echo -e "${WHITE}[!]      You may try it later or manually !!${NOCOLOR}"
  sleep 2
  exit 1
fi

echo 9 | tee .log
exit 1;;
9 )
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
sudo cp etc/iptables.ipv4.nat /etc/
echo -e "${RED}[+] Copied /etc/hosts -- backup done${NOCOLOR}"
sudo mkdir /etc/update-motd.d/bak
sudo mv /etc/update-motd.d/* bak
echo -e "${RED}[+] Disabled Ubuntu's update-motd feature -- backup done${NOCOLOR}"
(sudo cp /etc/motd /etc/motd.bak) 2> /dev/null
sudo cp etc/motd /etc/
echo -e "${RED}[+] Copied /etc/motd -- backup not necessary${NOCOLOR}"
sudo cp etc/network/interfaces /etc/network/
echo -e "${RED}[+] Copied /etc/network/interfaces -- backup done${NOCOLOR}"
(sudo cp /etc/rc.local /etc/rc.local.bak) 2> /dev/null
sudo cp etc/rc.local /etc/
echo -e "${RED}[+] Copied /etc/rc.local -- backup done${NOCOLOR}"
if grep "#net.ipv4.ip_forward=1" /etc/sysctl.conf ; then
  sudo cp /etc/sysctl.conf /etc/sysctl.conf.bak
  sudo sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
  echo -e "${RED}[+] Changed /etc/sysctl.conf -- backup done${NOCOLOR}"
fi
(sudo cp /etc/tor/torrc /etc/tor/torrc.bak) 2> /dev/null
sudo cp etc/tor/torrc /etc/tor/
echo -e "${RED}[+] Copied /etc/tor/torrc -- backup done${NOCOLOR}"
(sudo cp /etc/wicd/manager-settings.conf /etc/wicd/manager-settings.conf.bak) 2> /dev/null
sudo cp etc/wicd/manager-settings.conf /etc/wicd/
echo -e "${RED}[+] Copied /etc/wicd/manager-settings.conf -- backup done${NOCOLOR}"
(sudo cp /etc/wicd/wired-settings.conf /etc/wicd/wired-settings.conf.bak) 2> /dev/null
sudo cp etc/wicd/wired-settings.conf /etc/wicd/
echo -e "${RED}[+] Copied /etc/wicd/wired-settings.conf -- backup done${NOCOLOR}"
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
# sleep 10
# clear
# echo -e "${RED}[+] Step 10: Because of security considerations, we completely disable the Bluetooth functionality${NOCOLOR}"
# if ! grep "# Added by TorBox" /boot/config.txt ; then
#  sudo printf "\n# Added by TorBox\ndtoverlay=disable-bt\n." | sudo tee -a /boot/config.txt
#  sudo systemctl disable hciuart.service
#  sudo systemctl disable bluealsa.service
#  sudo systemctl disable bluetooth.service
#  sudo apt-get -y purge bluez
#  sudo apt-get -y autoremove
# fi

echo 11 | tee .log
exit 1;;
11 )
# We have to disable that or ask the user for a password
# 11. Changing the password of pi to "CHANGE-IT"
sleep 10
clear
echo -e "${RED}[+] Step 11: We change the password of the user \"ubuntu\" to \"CHANGE-IT\".${NOCOLOR}"
echo 'ubuntu:CHANGE-IT' | sudo chpasswd

echo 12 | tee .log
exit 1;;
12 )
# 12. Configure the system services and rebooting
sleep 10
clear
echo -e "${RED}[+] Step 12: Configure the system services...${NOCOLOR}"
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
#sudo systemctl disable dhcpcd
sudo systemctl stop dnsmasq
sudo systemctl disable dnsmasq
sudo systemctl daemon-reload
echo ""
echo -e "${RED}[+] Stop logging, now..${NOCOLOR}"
sudo systemctl stop rsyslog
sudo systemctl disable rsyslog
echo""
read -p "The system needs to reboot. This will also erase all log files. Would you do it now? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]
then
  clear
  echo -e "${RED}[+] Erasing ALL LOG-files...${NOCOLOR}"
  echo " "
  for logs in `sudo find /var/log -type f`; do
    echo -e "${RED}[+]${NOCOLOR} Erasing $logs"
    sudo rm $logs
    sleep 1
  done
  echo -e "${RED}[+]${NOCOLOR} Erasing .bash_history"
  sudo rm .bash_history
  sudo history -c
  echo ""
  # This has to be at the end to avoid unnecessary error messages
  sudo cp /etc/hostname /etc/hostname.bak
  sudo cp torbox/etc/hostname /etc/
  echo -e "${RED}[+] Copied /etc/hostname -- backup done${NOCOLOR}"
  sudo cp /etc/hosts /etc/hosts.bak
  sudo cp torbox/etc/hosts /etc/
  echo -e "${RED}[+] Copied /etc/hosts -- backup done${NOCOLOR}"
  echo echo -e "${RED}[+] Rebooting...${NOCOLOR}"
  sudo reboot
else
  # This has to be at the end to avoid unnecessary error messages
  sudo cp /etc/hostname /etc/hostname.bak
  sudo cp torbox/etc/hostname /etc/
  echo -e "${RED}[+] Copied /etc/hostname -- backup done${NOCOLOR}"
  sudo cp /etc/hosts /etc/hosts.bak
  sudo cp torbox/etc/hosts /etc/
  echo -e "${RED}[+] Copied /etc/hosts -- backup done${NOCOLOR}"
  echo ""
  echo -e "${WHITE}[!] You need to reboot the system as soon as possible!${NOCOLOR}"
  echo -e "${WHITE}[!] The log files are not deleted, yet. You can do this later with configuration sub-menu.${NOCOLOR}"
fi
exit 0

esac # End of case
