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
# Ubuntu 20.04 LTS (32/64bit; https://ubuntu.com/download/raspberry-pi).
#
# SYNTAX
# ./run_install_on_ubuntu.sh
#
# IMPORTANT
# Start it as normal user (usually as ubuntu)!
# Dont run it as root (no sudo)!
# If Ubuntu 20.04 is freshly installed, you have to wait one or two minutes
# until you can log in with ubuntu / ubuntu
#
##########################################################

# Table of contents for this script:
#  1. Checking for Internet connection
#  2. Updating the system
#  3. Installing all necessary packages
#  4. Installing wicd
#  5. Configuring Tor and obfs4proxy
#  6. Re-checking Internet connectivity
#  7. Downloading and installing the latest version of TorBox
#  8. Installing all configuration files
#  9. Disabling Bluetooth
# 10. Configure the system services
# 11. Adding and implementing the user torbox
# 12. Finishing, cleaning and booting

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
# Only Ubuntu - Sets the background of TorBox menu to dark blue
sudo rm /etc/alternatives/newt-palette; sudo ln -s /etc/newt/palette.original /etc/alternatives/newt-palette
whiptail --title "TorBox Installation on Ubuntu" --msgbox "\n\n             WELCOME TO THE INSTALLATION OF TORBOX ON UBUNTU\n\nThis installation runs without user interaction AND CHANGES/DELETES THE CURRENT CONFIGURATION. During the installation, we are going to set up the user \"torbox\" with the default password \"CHANGE-IT\". This user name and the password will be used for logging into your TorBox and to administering it. Please, change the default passwords as soon as possible (the associated menu entries are placed in the configuration sub-menu).\n\nIMPORTANT: Internet connectivity is necessary for the installation.\n\nIn case of any problems, contact us on https://www.torbox.ch" $MENU_HEIGHT_20 $MENU_WIDTH
clear

# 1. Checking for Internet connection
# Currently a working Internet connection is mandatory. Probably in a later
# version, we will include an option to install the TorBox from a compressed
# file.

clear
echo -e "${RED}[+] Step 1: Do we have Internet?${NOCOLOR}"
wget -q --spider http://ubuntu.com
if [ $? -eq 0 ]; then
  echo -e "${RED}[+]         Yes, we have! :-)${NOCOLOR}"
else
  echo -e "${WHITE}[!]         Hmmm, no we don't have... :-(${NOCOLOR}"
  echo -e "${RED}[+]         We will check again in about 30 seconds...${NOCOLOR}"
  sleep 30
  echo ""
  echo -e "${RED}[+]         Trying again...${NOCOLOR}"
  wget -q --spider http://ubuntu.com
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
    wget -q --spider http://ubuntu.com
    if [ $? -eq 0 ]; then
      echo -e "${RED}[+]         Yes, now, we have an Internet connection! :-)${NOCOLOR}"
    else
      echo -e "${WHITE}[!]         Hmmm, still no Internet connection... :-(${NOCOLOR}"
      echo -e "${RED}[+]         We will add a Google nameserver (8.8.8.8) to /etc/resolv.conf and try again...${NOCOLOR}"
      sudo cp /etc/systemd/resolved.conf /etc/systemd/resolved.conf.bak
      (sudo printf "\n# Added by TorBox install script\nDNS=8.8.8.8\n" | sudo tee -a /etc/systemd/resolved.conf) 2>&1
      sudo systemctl restart systemd-resolved
      sleep 15
      echo -e "${RED}[+]         Dumdidum...${NOCOLOR}"
      sleep 15
      echo -e "${RED}[+]         Trying again...${NOCOLOR}"
      wget -q --spider http://ubuntu.com
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

# 2. Updating the system
sleep 10
clear
echo -e "${RED}[+] Step 2a: Remove Ubuntu's unattended update feature (this will take about 30 seconds)...${NOCOLOR}"
(sudo killall unattended-upgr) 2> /dev/null
sleep 15
echo -e "${RED}[+]          Please wait...${NOCOLOR}"
(sudo killall unattended-upgr) 2> /dev/null
sleep 15
sudo apt-get -y purge unattended-upgrades
sudo dpkg --configure -a
echo ""
echo -e "${RED}[+] Step 2b: Remove Ubuntu's cloud-init...${NOCOLOR}"
sudo apt-get -y purge cloud-init
sudo rm -Rf /etc/cloud
echo ""
echo -e "${RED}[+] Step 2c: Updating the system...${NOCOLOR}"
sudo apt-get -y update
sudo apt-get -y dist-upgrade
sudo apt-get -y clean
sudo apt-get -y autoclean
sudo apt-get -y autoremove

# 3. Installing all necessary packages
# The problem with Ubuntu 20.04 is that they removed the support for python2 which is necessary for wicd
sleep 10
clear
echo -e "${RED}[+] Step 3: Installing all necessary packages....${NOCOLOR}"
sudo apt-get -y install python2 hostapd isc-dhcp-server tor obfs4proxy usbmuxd dnsmasq dnsutils tcpdump iftop vnstat links2 debian-goodies apt-transport-https dirmngr python3-setuptools python3-pip python3-pil imagemagick tesseract-ocr ntpdate screen nyx net-tools ifupdown unzip equivs
curl https://bootstrap.pypa.io/get-pip.py --output get-pip.py
sudo python2 get-pip.py

# Additional installations for Python 3
sudo pip3 install pytesseract
sudo pip3 install mechanize

# urwid for Python 2, which is necessary for wicd-curse
sudo pip install urwid

# 4. Installing wicd (this is necessary because starting with Ubuntu 20.04, they
#    kicked the package out of their repository; see also here:
#    https://askubuntu.com/questions/1240154/how-to-install-wicd-on-ubuntu-20-04)
sleep 10
clear
echo -e "${RED}[+] Step 4: Installing wicd....${NOCOLOR}"
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
sudo apt-get -y install ./Downloads/wicd/wicd_1.7.4+tb2-6_all.deb

# Creating a dependency-dummy for wicd-curses (based on
# https://unix.stackexchange.com/questions/404444/how-to-make-apt-ignore-unfulfilled-dependencies-of-installed-package)
equivs-control python-urwid.control
sed -i "s/Package: <package name; defaults to equivs-dummy>/Package: python-urwid/g" python-urwid.control
sed -i "s/^# Version: <enter version here; defaults to 1.0>/Version: 1.2/g" python-urwid.control
equivs-build python-urwid.control
sudo dpkg -i python-urwid_1.2_all.deb

# Finally !!!
sudo apt-get -y install ./Downloads/wicd/wicd-curses_1.7.4+tb2-6_all.deb

# 5. Configuring Tor and obfs4proxy
sleep 10
clear
echo -e "${RED}[+] Step 5: Configuring Tor and obfs4proxy....${NOCOLOR}"
sudo setcap 'cap_net_bind_service=+ep' /usr/bin/obfs4proxy
sudo sed -i "s/^NoNewPrivileges=yes/NoNewPrivileges=no/g" /lib/systemd/system/tor@default.service
sudo sed -i "s/^NoNewPrivileges=yes/NoNewPrivileges=no/g" /lib/systemd/system/tor@.service

# 6. Again checking connectivity
sleep 10
clear
echo -e "${RED}[+] Step 6: Re-checking Internet connectivity...${NOCOLOR}"
wget -q --spider http://google.com
if [ $? -eq 0 ]; then
  echo -e "${RED}[+]         Yes, we have still Internet connectivity! :-)${NOCOLOR}"
else
  echo -e "${RED}[+]         Hmmm, no we don't have... :-(${NOCOLOR}"
  echo -e "${RED}[+]         We will check again in about 30 seconds...${NOCOLOR}"
  sleep 30
  echo -e "${RED}[+]         Trying again...${NOCOLOR}"
  wget -q --spider https://google.com
  if [ $? -eq 0 ]; then
    echo -e "${RED}[+]         Yes, now, we have an Internet connection! :-)${NOCOLOR}"
  else
    echo -e "${RED}[+]         Hmmm, still no Internet connection... :-(${NOCOLOR}"
    echo -e "${RED}[+]         We will try to catch a dynamic IP adress and check again in about 30 seconds...${NOCOLOR}"
    sudo dhclient -r
    sleep 5
    sudo dhclient &>/dev/null &
    sleep 30
    echo -e "${RED}[+]         Trying again...${NOCOLOR}"
    wget -q --spider https://google.com
    if [ $? -eq 0 ]; then
      echo -e "${RED}[+]         Yes, now, we have an Internet connection! :-)${NOCOLOR}"
    else
      echo -e "${RED}[+]         Hmmm, still no Internet connection... :-(${NOCOLOR}"
      echo -e "${RED}[+]         We will add a Google nameserver (8.8.8.8) to /etc/resolv.conf and try again...${NOCOLOR}"
      sudo cp /etc/systemd/resolved.conf /etc/systemd/resolved.conf.bak
      (sudo printf "\n# Added by TorBox install script\nDNS=8.8.8.8\n" | sudo tee -a /etc/systemd/resolved.conf) 2>&1
      sudo systemctl restart systemd-resolved
      sleep 15
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

# 7. Downloading and installing the latest version of TorBox
sleep 10
clear
echo -e "${RED}[+] Step 7: Downloading and installing the latest version of TorBox...${NOCOLOR}"
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

# 8. Installing all configuration files
sleep 10
clear
cd torbox
echo -e "${RED}[+] Step 8: Installing all configuration files....${NOCOLOR}"
echo ""
(sudo cp /etc/default/hostapd /etc/default/hostapd.bak) 2> /dev/null
sudo cp etc/default/hostapd /etc/default/
echo -e "${RED}[+]${NOCOLOR}         Copied /etc/default/hostapd -- backup done"
(sudo cp /etc/default/isc-dhcp-server /etc/default/isc-dhcp-server.bak) 2> /dev/null
sudo cp etc/default/isc-dhcp-server /etc/default/
echo -e "${RED}[+]${NOCOLOR}         Copied /etc/default/isc-dhcp-server -- backup done"
(sudo cp /etc/dhcp/dhclient.conf /etc/dhcp/dhclient.conf.bak) 2> /dev/null
sudo cp etc/dhcp/dhclient.conf /etc/dhcp/
echo -e "${RED}[+]${NOCOLOR}         Copied /etc/dhcp/dhclient.conf -- backup done"
(sudo cp /etc/dhcp/dhcpd.conf /etc/dhcp/dhcpd.conf.bak) 2> /dev/null
sudo cp etc/dhcp/dhcpd.conf /etc/dhcp/
echo -e "${RED}[+]${NOCOLOR}         Copied /etc/dhcp/dhcpd.conf -- backup done"
(sudo cp /etc/hostapd/hostapd.conf /etc/hostapd/hostapd.conf.bak) 2> /dev/null
sudo cp etc/hostapd/hostapd.conf /etc/hostapd/
echo -e "${RED}[+]${NOCOLOR}         Copied /etc/hostapd/hostapd.conf -- backup done"
(sudo cp /etc/iptables.ipv4.nat /etc/iptables.ipv4.nat.bak) 2> /dev/null
sudo cp etc/iptables.ipv4.nat /etc/
echo -e "${RED}[+]${NOCOLOR}         Copied /etc/iptables.ipv4.nat -- backup done"
sudo mkdir /etc/update-motd.d/bak
(sudo mv /etc/update-motd.d/* /etc/update-motd.d/bak/) 2> /dev/null
sudo rm /etc/legal
# Comment out with sed
sudo sed -ri "s/^session[[:space:]]+optional[[:space:]]+pam_motd\.so[[:space:]]+motd=\/run\/motd\.dynamic$/#\0/" /etc/pam.d/login
sudo sed -ri "s/^session[[:space:]]+optional[[:space:]]+pam_motd\.so[[:space:]]+motd=\/run\/motd\.dynamic$/#\0/" /etc/pam.d/sshd
echo -e "${RED}[+]${NOCOLOR}         Disabled Ubuntu's update-motd feature -- backup done"
(sudo cp /etc/motd /etc/motd.bak) 2> /dev/null
sudo cp etc/motd /etc/
echo -e "${RED}[+]${NOCOLOR}         Copied /etc/motd -- backup done"
(sudo cp /etc/network/interfaces /etc/network/interfaces.bak) 2> /dev/null
sudo cp etc/network/interfaces /etc/network/
echo -e "${RED}[+]${NOCOLOR}         Copied /etc/network/interfaces -- backup done"
# See also here: https://www.linuxbabe.com/linux-server/how-to-enable-etcrc-local-with-systemd
cp etc/systemd/system/rc-local.service /etc/systemd/system/rc-local.service
(sudo cp /etc/rc.local /etc/rc.local.bak) 2> /dev/null
sudo cp etc/rc.local.ubuntu /etc/rc.local
sudo chmod u+x /etc/rc.local
# We will enable rc-local further below
echo -e "${RED}[+]${NOCOLOR}         Copied /etc/rc.local -- backup done"
# Unlike the Raspberry Pi OS, Ubuntu uses systemd-resolved to resolve DNS queries (see also further below).
# To work correctly in a captive portal environement, we have to set the following options in /etc/systemd/resolved.conf:
# LLMNR=yes / MulticastDNS=yes / Chache=no
(sudo cp /etc/systemd/resolved.conf /etc/systemd/resolved.conf.bak) 2> /dev/null
sudo sp etc/systemd/resolved.conf /etc/systemd/
echo -e "${RED}[+]${NOCOLOR}         Copied /etc/systemd/resolved.conf -- backup done"
if grep -q "#net.ipv4.ip_forward=1" /etc/sysctl.conf ; then
  sudo cp /etc/sysctl.conf /etc/sysctl.conf.bak
  sudo sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
  echo -e "${RED}[+]${NOCOLOR}         Changed /etc/sysctl.conf -- backup done"
fi
(sudo cp /etc/tor/torrc /etc/tor/torrc.bak) 2> /dev/null
sudo cp etc/tor/torrc /etc/tor/
echo -e "${RED}[+]${NOCOLOR}         Copied /etc/tor/torrc -- backup done"
(sudo cp /etc/wicd/manager-settings.conf /etc/wicd/manager-settings.conf.bak) 2> /dev/null
sudo cp etc/wicd/manager-settings.conf /etc/wicd/
echo -e "${RED}[+]${NOCOLOR}         Copied /etc/wicd/manager-settings.conf -- backup done"
(sudo cp /etc/wicd/wired-settings.conf /etc/wicd/wired-settings.conf.bak) 2> /dev/null
sudo cp etc/wicd/wired-settings.conf /etc/wicd/
echo -e "${RED}[+]${NOCOLOR}         Copied /etc/wicd/wired-settings.conf -- backup done"
echo -e "${RED}[+]${NOCOLOR}         Activating IP forwarding"
sudo sh -c "echo 1 > /proc/sys/net/ipv4/ip_forward"
echo -e "${RED}[+]${NOCOLOR}         Changing .profile if necessary"
cd
if ! grep "# Added by TorBox" .profile ; then
  sudo cp .profile .profile.bak
  sudo printf "\n# Added by TorBox\ncd torbox\nsleep 2\n./menu\n" | sudo tee -a .profile
fi
cd

# 9. Disabling Bluetooth
sleep 10
clear
echo -e "${RED}[+] Step 9: Because of security considerations, we disable Bluetooth functionality${NOCOLOR}"
if ! grep "# Added by TorBox" /boot/firmware/config.txt ; then
  sudo printf "\n# Added by TorBox\ndtoverlay=disable-bt\n." | sudo tee -a /boot/firmware/config.txt
fi

# 10. Configure the system services
sleep 10
clear
echo -e "${RED}[+] Step 10: Configure the system services...${NOCOLOR}"
# Under Ubuntu systemd-resolved acts as local DNS server. However, clients can not use it, because systemd-resolved is listening
# on 127.0.0.53:53. This is where dnsmasq comes into play which generally responds to all port 53 requests and then resolves
# them over 127.0.0.53:53. This is what we need to get to the login page at captive portals.
# CLIENT --> DNSMASQ --> resolve.conf --> systemd-resolver --> ext DNS address
# However, this approach only works, if the following options are set in /etc/systemd/resolved.conf: LLMNR=yes / MulticastDNS=yes / Chache=no
# and bind-interfaces in /etc/dnsmasq.conf
#
# Important commands for systemd-resolve:
# sudo systemctl restart systemd-resolve
# sudo systemd-resolve --statistic / --status / --flush-cashes

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
# sudo systemctl disable dhcpcd - not installed on Ubuntu
sudo systemctl restart systemd-resolved
# We can only start dnsmasq together with systemd-resolve, if we activate "bind-interface" in /etc/dnsmasq.conf
# --> https://unix.stackexchange.com/questions/304050/how-to-avoid-conflicts-between-dnsmasq-and-systemd-resolved
# However, we don't want to start dnsmasq automatically after booting the system
sudo sed -i "s/^#bind-interfaces/bind-interfaces/g" /etc/dnsmasq.conf
sudo systemctl disable dnsmasq
sudo systemctl enable rc-local
echo ""
echo -e "${RED}[+]          Stop logging, now..${NOCOLOR}"
sudo systemctl stop rsyslog
sudo systemctl disable rsyslog
sudo systemctl daemon-reload
echo""

# 11. Adding the user torbox
sleep 10
clear
echo -e "${RED}[+] Step 11: Set up the torbox user...${NOCOLOR}"
echo -e "${RED}[+]          In this step the user \"torbox\" with the default${NOCOLOR}"
echo -e "${RED}[+]          password \"CHANGE-IT\" is created.  ${NOCOLOR}"
echo ""
echo -e "${WHITE}[!] IMPORTANT: To use TorBox, you have to log in with \"torbox\"${NOCOLOR}"
echo -e "${WHITE}    and the default password \"CHANGE-IT\"!!${NOCOLOR}"
echo -e "${WHITE}    Please, change the default passwords as soon as possible!!${NOCOLOR}"
echo -e "${WHITE}    The associated menu entries are placed in the configuration sub-menu.${NOCOLOR}"
echo ""
sudo adduser --disabled-password --gecos "" torbox
echo -e "CHANGE-IT\nCHANGE-IT\n" | sudo passwd torbox
sudo adduser torbox sudo
sudo mv /home/ubuntu/* /home/torbox/
(sudo mv /home/ubuntu/.profile /home/torbox/) 2> /dev/null
(sudo rm .bash_history) 2> /dev/null
sudo chown -R torbox.torbox /home/torbox/
if ! sudo grep "# Added by TorBox" /etc/sudoers ; then
  sudo printf "\n# Added by TorBox\ntorbox  ALL=NOPASSWD:ALL\n" | sudo tee -a /etc/sudoers
  # or: sudo printf "\n# Added by TorBox\ntorbox  ALL=(ALL) NOPASSWD: ALL\n" | sudo tee -a /etc/sudoers --- HAST TO BE CHECKED AND COMPARED WITH THE USER "UBUNTU"!!
  (sudo visudo -c) 2> /dev/null
fi
cd /home/torbox/

# 12. Finishing, cleaning and booting
echo ""
read -p $'\e[0;31mThe system needs to reboot. This will also erase all log files and cleaning up the system. Would you do it now (\e[1;37mHIGHLY RECOMMENDED!\e[0;31m)? (Y/n) \e[0m' -n 1 -r
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
  echo -e "${RED}[+]${NOCOLOR} Erasing History..."
  #.bash_history is already deleted
  history -c
  echo ""
  echo -e "${RED}[+]${NOCOLOR} Cleaning up..."
  sudo rm -r Downloads
  sudo rm -r get-pip.py
  sudo rm -r python-urwid*
  echo ""
  echo -e "${RED}[+]${NOCOLOR} Setting up the hostname..."
  # This has to be at the end to avoid unnecessary error messages
  sudo cp /etc/hostname /etc/hostname.bak
  sudo cp torbox/etc/hostname /etc/
  echo -e "${RED}[+]${NOCOLOR} Copied /etc/hostname -- backup done"
  sudo cp /etc/hosts /etc/hosts.bak
  sudo cp torbox/etc/hosts /etc/
  echo -e "${RED}[+]${NOCOLOR} Copied /etc/hosts -- backup done"
  echo -e "${RED}[+]${NOCOLOR} Rebooting..."
  sudo reboot
else
  # This has to be at the end to avoid unnecessary error messages
  sudo cp /etc/hostname /etc/hostname.bak
  sudo cp torbox/etc/hostname /etc/
  echo -e "${RED}[+]${NOCOLOR} Copied /etc/hostname -- backup done"
  sudo cp /etc/hosts /etc/hosts.bak
  sudo cp torbox/etc/hosts /etc/
  echo -e "${RED}[+]${NOCOLOR} Copied /etc/hosts -- backup done"
  echo ""
  echo -e "${WHITE}[!] You need to reboot the system as soon as possible!${NOCOLOR}"
  echo -e "${WHITE}[!] The log files are not deleted, yet. You can do this later with configuration sub-menu.${NOCOLOR}"
fi
exit 0
