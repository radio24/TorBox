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
# This script installs the newest version of TorBox on a clean, running
# Debian System (Tested on Buster and Bullseye
# - https://raspi.debian.net/tested-images/).
#
# SYNTAX
# ./run_install_on_debian.sh
#
# IMPORTANT
# Start it as root
#
##########################################################

# Table of contents for this script:
#  1. Checking for Internet connection
#  2. Updating the system
#  3. Adding the Tor repository to the source list.
#  4. Installing all necessary packages
#  5. Configuring Tor with the pluggable transports
#  6. Re-checking Internet connectivity
#  7. Downloading and installing the latest version of TorBox
#  8. Installing all configuration files
#  9. Disabling Bluetooth
# 10. Configure the system services
# 11. Installing additional network drivers
# 12. Adding and implementing the user torbox
# 13. Setting/changing root password
# 14. Finishing, cleaning and booting

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

#Connectivity check
CHECK_URL1="ubuntu.com"
CHECK_URL2="google.com"

#Other variables
RUNFILE="torbox/run/torbox.run"
CHECK_HD1=$(grep -q --text 'Raspberry Pi' /proc/device-tree/model)
CHECK_HD2=$(grep -q "Raspberry Pi" /proc/cpuinfo)

##############################
######## FUNCTIONS ###########



###### DISPLAY THE INTRO ######
clear
whiptail --title "TorBox Installation on Debian" --msgbox "\n\n            WELCOME TO THE INSTALLATION OF TORBOX ON DEBIAN\n\nPlease make sure that you started this script as \"./run_install_on_debian\" in /root.\n\nThis installation runs almost without user interaction AND CHANGES/DELETES THE CURRENT CONFIGURATION. During the installation, we are going to set up the user \"torbox\" with the default password \"CHANGE-IT\". This user name and the password will be used for logging into your TorBox and to administering it. Please, change the default passwords as soon as possible (the associated menu entries are placed in the configuration sub-menu).\n\nIMPORTANT: Internet connectivity is necessary for the installation.\n\nIn case of any problems, contact us on https://www.torbox.ch" $MENU_HEIGHT_20 $MENU_WIDTH
clear

# 1. Checking for Internet connection
clear
echo -e "${RED}[+] Step 1: Do we have Internet?${NOCOLOR}"
echo -e "${RED}[+]         Nevertheless, to be sure, let's add some open nameservers!${NOCOLOR}"
cp /etc/resolv.conf /etc/resolv.conf.bak
( printf "\n# Added by TorBox install script\nnameserver 1.1.1.1\nnameserver 1.0.0.1\nnameserver 8.8.8.8\nnameserver 8.8.4.4\n" |  tee /etc/resolv.conf) 2>&1
sleep 5
# On some Debian systems, wget is not installed, yet
ping -c 1 -q $CHECK_URL1 >&/dev/null
OCHECK=$?
echo ""
if [ $OCHECK -eq 0 ]; then
  echo -e "${RED}[+]         Yes, we have Internet! :-)${NOCOLOR}"
else
  echo -e "${WHITE}[!]        Hmmm, no we don't have Internet... :-(${NOCOLOR}"
  echo -e "${RED}[+]         We will check again in about 30 seconds...${NOCOLOR}"
  sleep 30
  echo ""
  echo -e "${RED}[+]         Trying again...${NOCOLOR}"
  ping -c 1 -q $CHECK_URL2 >&/dev/null
  if [ $? -eq 0 ]; then
    echo -e "${RED}[+]         Yes, now, we have an Internet connection! :-)${NOCOLOR}"
  else
    echo -e "${WHITE}[!]         Hmmm, still no Internet connection... :-(${NOCOLOR}"
    echo -e "${RED}[+]         We will try to catch a dynamic IP adress and check again in about 30 seconds...${NOCOLOR}"
    ( dhclient -r) 2>&1
    sleep 5
     dhclient &>/dev/null &
    sleep 30
    echo ""
    echo -e "${RED}[+]         Trying again...${NOCOLOR}"
    ping -c 1 -q $CHECK_URL1 >&/dev/null
    if [ $? -eq 0 ]; then
      echo -e "${RED}[+]         Yes, now, we have an Internet connection! :-)${NOCOLOR}"
    else
			echo -e "${RED}[+]         Hmmm, still no Internet connection... :-(${NOCOLOR}"
			echo -e "${RED}[+]         Internet connection is mandatory. We cannot continue - giving up!${NOCOLOR}"
			exit 1
    fi
  fi
fi

# 2. Updating the system
sleep 10
clear
echo -e "${RED}[+] Step 2: Updating the system...${NOCOLOR}"
apt-get -y update
apt-get -y dist-upgrade
apt-get -y clean
apt-get -y autoclean
apt-get -y autoremove

# Additional installations for Debian systems, needed from the start
apt-get -y install wget curl gnupg

# 3. Adding the Tor repository to the source list.
sleep 10
clear
echo -e "${RED}[+] Step 3: Adding the Tor repository to the source list....${NOCOLOR}"
echo ""
cp /etc/apt/sources.list /etc/apt/sources.list.bak
printf "\n# Added by TorBox update script\ndeb https://deb.torproject.org/torproject.org buster main\ndeb-src https://deb.torproject.org/torproject.org buster main\n" |  tee -a /etc/apt/sources.list
curl https://deb.torproject.org/torproject.org/A3C4F0F979CAA22CDBA8F512EE8CBC9E886DDD89.asc |  apt-key add -
apt-get -y update

# 4. Installing all necessary packages
sleep 10
clear
echo -e "${RED}[+] Step 4: Installing all necessary packages....${NOCOLOR}"
apt-get -y install hostapd isc-dhcp-server obfs4proxy usbmuxd dnsmasq dnsutils tcpdump iftop vnstat links2 debian-goodies apt-transport-https dirmngr python3-pip python3-pil imagemagick tesseract-ocr ntpdate screen nyx net-tools unzip git openvpn ppp tor tor-geoipdb

# Additional installations for Debian systems
apt-get -y install sudo resolvconf

# Additional installations for Debian bullseye systems
if hostnamectl | grep -q "bullseye" ; then
  apt-get -y install iptables
fi

#Install wiringpi - however, it is not sure if it works correctly under Debian
cd ~
git clone https://github.com/WiringPi/WiringPi.git
cd WiringPi
./build
cd ~
rm -r WiringPi

# Additional installations for Python
pip3 install pytesseract
pip3 install mechanize
pip3 install urwid

# Additional installation for GO
cd ~
rm -rf /usr/local/go
wget https://golang.org/dl/go1.16.3.linux-arm64.tar.gz
tar -C /usr/local -xzvf go1.16.3.linux-arm64.tar.gz
printf "\n# Added by TorBox\nexport PATH=$PATH:/usr/local/go/bin\n" |  tee -a .profile
export PATH=$PATH:/usr/local/go/bin

# 5. Configuring Tor with the pluggable transports
sleep 10
clear
echo -e "${RED}[+] Step 5: Configuring Tor with the pluggable transports....${NOCOLOR}"
cp /usr/share/tor/geoip* /usr/bin
chmod a+x /usr/bin/geoip*
setcap 'cap_net_bind_service=+ep' /usr/bin/obfs4proxy
sed -i "s/^NoNewPrivileges=yes/NoNewPrivileges=no/g" /lib/systemd/system/tor@default.service
sed -i "s/^NoNewPrivileges=yes/NoNewPrivileges=no/g" /lib/systemd/system/tor@.service

# Additional installation for Snowflake
cd ~
git clone https://git.torproject.org/pluggable-transports/snowflake.git
export GO111MODULE="on"
cd ~/snowflake/proxy
/usr/local/go/bin/go get
/usr/local/go/bin/go build
cp proxy /usr/bin/snowflake-proxy

cd ~/snowflake/client
/usr/local/go/bin/go get
/usr/local/go/bin/go build
cp client /usr/bin/snowflake-client

cd ~
rm -rf snowflake
rm -rf go*

# 6. Again checking connectivity
sleep 10
clear
echo -e "${RED}[+] Step 6: Re-checking Internet connectivity${NOCOLOR}"
wget -q --spider http://$CHECK_URL1
if [ $? -eq 0 ]; then
  echo -e "${RED}[+]         Yes, we have still Internet connectivity! :-)${NOCOLOR}"
else
  echo -e "${WHITE}[!]         Hmmm, no we don't have Internet... :-(${NOCOLOR}"
  echo -e "${RED}[+]          We will check again in about 30 seconds...${NOCOLOR}"
  sleeo 30
  echo -e "${RED}[+]          Trying again...${NOCOLOR}"
  wget -q --spider https://$CHECK_URL2
  if [ $? -eq 0 ]; then
    echo -e "${RED}[+]          Yes, now, we have an Internet connection! :-)${NOCOLOR}"
  else
    echo -e "${RED}[+]          Hmmm, still no Internet connection... :-(${NOCOLOR}"
    echo -e "${RED}[+]          We will try to catch a dynamic IP adress and check again in about 30 seconds...${NOCOLOR}"
     dhclient -r
    sleep 5
     dhclient &>/dev/null &
    sleep 30
    echo -e "${RED}[+]          Trying again...${NOCOLOR}"
    wget -q --spider http://$CHECK_URL1
    if [ $? -eq 0 ]; then
      echo -e "${RED}[+]          Yes, now, we have an Internet connection! :-)${NOCOLOR}"
    else
      echo -e "${RED}[+]          Hmmm, still no Internet connection... :-(${NOCOLOR}"
			echo -e "${RED}[+]          Let's add some open nameservers and try again...${NOCOLOR}"
			cp /etc/resolv.conf /etc/resolv.conf.bak
			( printf "\n# Added by TorBox install script\nnameserver 1.1.1.1\nnameserver 1.0.0.1\nnameserver 8.8.8.8\nnameserver 8.8.4.4\n" |  tee /etc/resolv.conf) 2>&1
      sleep 5
      echo ""
      echo -e "${RED}[+]          Dumdidum...${NOCOLOR}"
      sleep 15
      echo -e "${RED}[+]          Trying again...${NOCOLOR}"
      wget -q --spider http://$CHECK_URL1
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
wget https://github.com/radio24/TorBox/archive/refs/heads/master.zip
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
  echo -e "${WHITE}[!]      I can't update TorBox menu !!${NOCOLOR}"
  echo -e "${WHITE}[!]      You may try it later or manually !!${NOCOLOR}"
  sleep 2
  exit 1
fi

# 8. Installing all configuration files
sleep 10
clear
cd torbox
echo -e "${RED}[+] Step 8: Installing all configuration files....${NOCOLOR}"
(cp /etc/default/hostapd /etc/default/hostapd.bak) 2> /dev/null
cp etc/default/hostapd /etc/default/
echo -e "${RED}[+] Copied /etc/default/hostapd -- backup done${NOCOLOR}"
(cp /etc/default/isc-dhcp-server /etc/default/isc-dhcp-server.bak) 2> /dev/null
cp etc/default/isc-dhcp-server /etc/default/
echo -e "${RED}[+] Copied /etc/default/isc-dhcp-server -- backup done${NOCOLOR}"
(cp /etc/dhcp/dhclient.conf /etc/dhcp/dhclient.conf.bak) 2> /dev/null
cp etc/dhcp/dhclient.conf /etc/dhcp/
echo -e "${RED}[+] Copied /etc/dhcp/dhclient.conf -- backup done${NOCOLOR}"
(cp /etc/dhcp/dhcpd.conf /etc/dhcp/dhcpd.conf.bak) 2> /dev/null
cp etc/dhcp/dhcpd.conf /etc/dhcp/
echo -e "${RED}[+] Copied /etc/dhcp/dhcpd.conf -- backup done${NOCOLOR}"
(cp /etc/hostapd/hostapd.conf /etc/hostapd/hostapd.conf.bak) 2> /dev/null
cp etc/hostapd/hostapd.conf /etc/hostapd/
echo -e "${RED}[+] Copied /etc/hostapd/hostapd.conf -- backup done${NOCOLOR}"
(cp /etc/iptables.ipv4.nat /etc/iptables.ipv4.nat.bak) 2> /dev/null
cp etc/iptables.ipv4.nat /etc/
echo -e "${RED}[+] Copied /etc/iptables.ipv4.nat -- backup done${NOCOLOR}"
(cp /etc/motd /etc/motd.bak) 2> /dev/null
cp etc/motd /etc/
echo -e "${RED}[+] Copied /etc/motd -- backup done${NOCOLOR}"
(cp /etc/network/interfaces /etc/network/interfaces.bak) 2> /dev/null
cp etc/network/interfaces /etc/network/
echo -e "${RED}[+] Copied /etc/network/interfaces -- backup done${NOCOLOR}"
cp etc/systemd/system/rc-local.service /etc/systemd/system/rc-local.service
(cp /etc/rc.local /etc/rc.local.bak) 2> /dev/null
cp etc/rc.local.ubuntu /etc/rc.local
chmod a+x /etc/rc.local
echo -e "${RED}[+] Copied /etc/rc.local -- backup done${NOCOLOR}"
if grep -q "#net.ipv4.ip_forward=1" /etc/sysctl.conf ; then
  cp /etc/sysctl.conf /etc/sysctl.conf.bak
  sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
  echo -e "${RED}[+] Changed /etc/sysctl.conf -- backup done${NOCOLOR}"
fi
(cp /etc/tor/torrc /etc/tor/torrc.bak) 2> /dev/null
cp etc/tor/torrc /etc/tor/
echo -e "${RED}[+] Copied /etc/tor/torrc -- backup done${NOCOLOR}"
echo -e "${RED}[+] Activating IP forwarding${NOCOLOR}"
sh -c "echo 1 > /proc/sys/net/ipv4/ip_forward"
echo -e "${RED}[+] Changing .profile${NOCOLOR}"
cd
printf "\n# Added by TorBox\ncd torbox\n./menu\n" | sudo tee -a .profile

# 9. Disabling Bluetooth
sleep 10
clear
echo -e "${RED}[+] Step 9: Because of security considerations, we completely disable the Bluetooth functionality${NOCOLOR}"
if ! grep "# Added by TorBox" /boot/firmware/config.txt ; then
   printf "\n# Added by TorBox\ndtoverlay=disable-bt\n." | tee -a /boot/firmware/config.txt
fi

# 10. Configure the system services
sleep 10
clear
echo -e "${RED}[+] Step 10: Configure the system services...${NOCOLOR}"
systemctl unmask hostapd
systemctl enable hostapd
systemctl start hostapd
systemctl unmask isc-dhcp-server
systemctl enable isc-dhcp-server
systemctl start isc-dhcp-server
systemctl unmask tor
systemctl enable tor
systemctl start tor
systemctl unmask ssh
systemctl enable ssh
systemctl start ssh
# sudo systemctl disable dhcpcd - not installed on Debian
systemctl stop dnsmasq
systemctl disable dnsmasq
systemctl enable resolvconf
systemctl start resolvconf
systemctl enable rc-local
echo ""
echo -e "${RED}[+]          Stop logging, now..${NOCOLOR}"
systemctl stop rsyslog
systemctl disable rsyslog
systemctl daemon-reload
echo""

# 11. Installing additional network drivers
sleep 10
clear
echo -e "${RED}[+] Step 11: Installing additional network drivers...${NOCOLOR}"
echo -e " "

# Update kernel headers - important: this has to be done every time after upgrading the kernel
echo -e "${RED}[+] Installing additional software... ${NOCOLOR}"
apt-get install -y linux-headers-$(uname -r)
apt-get install -y firmware-realtek dkms libelf-dev build-essential
cd ~
sleep 2

# Installing the RTL8188EU
clear
echo -e "${RED}[+] Step 11: Installing additional network drivers...${NOCOLOR}"
echo -e " "
echo -e "${RED}[+] Installing the Realtek RTL8188EU Wireless Network Driver ${NOCOLOR}"
cd ~
git clone https://github.com/lwfinger/rtl8188eu.git
cd rtl8188eu
make all
make install
cd ~
rm -r rtl8188eu
sleep 2

# Installing the RTL8188FU
clear
echo -e "${RED}[+] Step 11: Installing additional network drivers...${NOCOLOR}"
echo -e " "
echo -e "${RED}[+] Installing the Realtek RTL8188FU Wireless Network Driver ${NOCOLOR}"
git clone https://github.com/kelebek333/rtl8188fu
dkms add ./rtl8188fu
dkms build rtl8188fu/1.0
dkms install rtl8188fu/1.0
cp ./rtl8188fu/firmware/rtl8188fufw.bin /lib/firmware/rtlwifi/
rm -r rtl8188fu
sleep 2

# Installing the RTL8192EU
clear
echo -e "${RED}[+] Step 11: Installing additional network drivers...${NOCOLOR}"
echo -e " "
echo -e "${RED}[+] Installing the Realtek RTL8192EU Wireless Network Driver ${NOCOLOR}"
git clone https://github.com/clnhub/rtl8192eu-linux.git
cd rtl8192eu-linux
dkms add .
dkms install rtl8192eu/1.0
cd ~
rm -r rtl8192eu-linux
sleep 2

# Installing the RTL8812AU
clear
echo -e "${RED}[+] Step 11: Installing additional network drivers...${NOCOLOR}"
echo -e " "
echo -e "${RED}[+] Installing the Realtek RTL8812AU Wireless Network Driver ${NOCOLOR}"
git clone https://github.com/morrownr/8812au.git
cd 8812au
cp ~/torbox/install/Network/install-rtl8812au.sh .
chmod a+x install-rtl8812au.sh
if [ -z "$CHECK_HD1" ] || [ -z "$CHECK_HD2" ]; then
	if uname -r | grep -q "arm64"; then
		./raspi64.sh
	else
	 ./raspi32.sh
 fi
fi
./install-rtl8812au.sh
cd ~
rm -r 8812au
sleep 2

# Installing the RTL8814AU
clear
echo -e "${RED}[+] Step 11: Installing additional network drivers...${NOCOLOR}"
echo -e " "
echo -e "${RED}[+] Installing the Realtek RTL8814AU Wireless Network Driver ${NOCOLOR}"
git clone https://github.com/morrownr/8814au.git
cd 8814au
cp ~/torbox/install/Network/install-rtl8814au.sh .
chmod a+x install-rtl8814au.sh
if [ -z "$CHECK_HD1" ] || [ -z "$CHECK_HD2" ]; then
	if uname -r | grep -q "arm64"; then
		./raspi64.sh
	else
	 ./raspi32.sh
 fi
fi
./install-rtl8814au.sh
cd ~
rm -r 8814au
sleep 2

# Installing the RTL8821AU
clear
echo -e "${RED}[+] Step 11: Installing additional network drivers...${NOCOLOR}"
echo -e " "
echo -e "${RED}[+] Installing the Realtek RTL8821AU Wireless Network Driver ${NOCOLOR}"
git clone https://github.com/morrownr/8821au.git
cd 8821au
cp ~/torbox/install/Network/install-rtl8821au.sh .
chmod a+x install-rtl8821au.sh
if [ -z "$CHECK_HD1" ] || [ -z "$CHECK_HD2" ]; then
	if uname -r | grep -q "arm64"; then
		./raspi64.sh
	else
	 ./raspi32.sh
 fi
fi
./install-rtl8821au.sh
cd ~
rm -r 8821au
sleep 2

# Installing the RTL8821CU
clear
echo -e "${RED}[+] Step 11: Installing additional network drivers...${NOCOLOR}"
echo -e " "
echo -e "${RED}[+] Installing the Realtek RTL8821CU Wireless Network Driver ${NOCOLOR}"
git clone https://github.com/morrownr/8821cu.git
cd 8821cu
cp ~/torbox/install/Network/install-rtl8821cu.sh .
chmod a+x install-rtl8821cu.sh
if [ -z "$CHECK_HD1" ] || [ -z "$CHECK_HD2" ]; then
	if uname -r | grep -q "arm64"; then
		./raspi64.sh
	else
	 ./raspi32.sh
 fi
fi
./install-rtl8821cu.sh
cd ~
rm -r 8821cu
sleep 2

# Installing the RTL88x2BU
clear
echo -e "${RED}[+] Step 11: Installing additional network drivers...${NOCOLOR}"
echo -e " "
echo -e "${RED}[+] Installing the Realtek RTL88x2BU Wireless Network Driver ${NOCOLOR}"
git clone https://github.com/morrownr/88x2bu.git
cd 88x2bu
cp ~/torbox/install/Network/install-rtl88x2bu.sh .
chmod a+x install-rtl88x2bu.sh
if [ -z "$CHECK_HD1" ] || [ -z "$CHECK_HD2" ]; then
	if uname -r | grep -q "arm64"; then
		./raspi64.sh
	else
	 ./raspi32.sh
 fi
fi
./install-rtl88x2bu.sh
cd ~
rm -r 88x2bu
sleep 2

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
adduser --disabled-password --gecos "" torbox
echo -e "CHANGE-IT\nCHANGE-IT\n" |  passwd torbox
adduser torbox
adduser torbox netdev
mv /root/* /home/torbox/
(mv /root/.profile /home/torbox/) 2> /dev/null
mkdir /home/torbox/openvpn
(rm .bash_history) 2> /dev/null
chown -R torbox.torbox /home/torbox/
if !  grep "# Added by TorBox" /etc/sudoers ; then
  printf "\n# Added by TorBox\ntorbox  ALL=(ALL) NOPASSWD: ALL\n" |  tee -a /etc/sudoers
  (visudo -c) 2> /dev/null
fi
cd /home/torbox/

# 13. Setting/changing root password
sleep 10
clear
echo -e "${RED}[+] Step 12: Setting/changing the root password...${NOCOLOR}"
echo -e "${RED}[+]          For security reason, we will ask you now for a (new) root password.${NOCOLOR}"
echo ""
passwd

# 14. Finishing, cleaning and booting
sleep 10
clear
echo -e "${RED}[+] Step 14: We are finishing and cleaning up now!${NOCOLOR}"
echo -e "${RED}[+]          This will erase all log files and cleaning up the system.${NOCOLOR}"
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
for logs in ` find /var/log -type f`; do
  echo -e "${RED}[+]${NOCOLOR} Erasing $logs"
  rm $logs
  sleep 1
done
echo -e "${RED}[+]${NOCOLOR} Erasing History..."
#.bash_history is already deleted
history -c
echo ""
echo -e "${RED}[+] Setting up the hostname...${NOCOLOR}"
# This has to be at the end to avoid unnecessary error messages
(cp /etc/hostname /etc/hostname.bak) 2> /dev/null
cp torbox/etc/hostname /etc/
echo -e "${RED}[+]Copied /etc/hostname -- backup done${NOCOLOR}"
(cp /etc/hosts /etc/hosts.bak) 2> /dev/null
cp torbox/etc/hosts /etc/
echo -e "${RED}[+]Copied /etc/hosts -- backup done${NOCOLOR}"
echo ""
echo -e "${WHITE}[!] IMPORTANT${NOCOLOR}"
echo -e "${WHITE}    TorBox has to be rebooted.${NOCOLOR}"
echo -e "${WHITE}    In order to do so type \"exit\" and log in with \"torbox\" and the default password \"CHANGE-IT\"!! ${NOCOLOR}"
echo -e "${WHITE}    After rebooting, please, change the default passwords immediately!!${NOCOLOR}"
echo -e "${WHITE}    The associated menu entries are placed in the configuration sub-menu.${NOCOLOR}"
#sed -i "s/^FRESH_INSTALLED=.*/FRESH_INSTALLED=1/" ${RUNFILE}
