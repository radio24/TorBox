#!/bin/bash
# shellcheck disable=SC2004,SC2181,SC2001

# This file is a part of TorBox, an easy to use anonymizing router based on Raspberry Pi.
# Copyright (C) 2023 Patrick Truffer
# Contact: anonym@torbox.ch
# Website: https://www.torbox.ch
# Github:  https://github.com/radio24/TorBox
#
# Copyright (C) 2022 nyxnor (Contributor)
# Github:  https://github.com/nyxnor
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
# Raspberry Pi OS lite. Please before starting the installation ensure that
# the user account "torbox" is already created and that you are logged in as such.
#
# SYNTAX
# ./run_install.sh [-h|--help] [--select-tor] [--select-fork fork_owner_name] [--select-branch branch_name] [--step_by_step]
#
# The -h or --help option shows the help screen.
#
# The --select-tor option allows to select a specific tor version. Without
# this option, the installation script installs the latest stable version.
#
# The --select-fork option allows to install a specific fork. The
# fork_owner_name is the GitHub user name of the for-owner.
#
# The --select-branch option allows to install a specific TorBox branch.
# Without this option, the installation script installs the master branch.
#
# The --step_by_step option execute the installation step by step, which
# is ideal to find bugs.
#
# IMPORTANT
# Start the insatllation as user "torbox""!
# Dont run it as root (no sudo)!
#
##########################################################

# Table of contents for this script:
#  1. Checking for Internet connection
#  2. Checking for the WLAN regulatory domain
#  3. Updating the system
#  4. Installing all necessary packages
#  5. Install Tor
#  6. Configuring Tor with its pluggable transports
#  7. Install Snowflake
#  8. Re-checking Internet connectivity
#  9. Downloading and installing the latest version of TorBox
# 10. Installing all configuration files
# 11. Disabling Bluetooth
# 12. Configure the system services
# 13. Updating run/torbox.run
# 14. Finishing, cleaning and booting

##########################################################

##### SET VARIABLES ######
#
# Set the the variables for the menu
MENU_WIDTH=80
MENU_HEIGHT_25=25

# Colors
RED='\033[1;31m'
WHITE='\033[1;37m'
NOCOLOR='\033[0m'

# Changes in the variables below (until the ####### delimiter) will be saved
# into run/torbox.run and used after the installation (we not recommend to
# change the values until zou precisely know what you are doing)
# Public nameserver used to circumvent cheap censorship
NAMESERVERS="1.1.1.1,1.0.0.1,8.8.8.8,8.8.4.4"

# Used go version
GO_VERSION="go1.20.3.linux-armv6l.tar.gz"
GO_VERSION_64="go1.20.3.linux-arm64.tar.gz"
GO_DL_PATH="https://go.dev/dl/"

# Release Page of the unofficial Tor repositories on GitHub
TORURL="https://github.com/torproject/tor/tags"
TORPATH_TO_RELEASE_TAGS="/torproject/tor/releases/tag/"
#WARNING: Sometimes, GitHub will change this prefix!
#TOR_HREF_FOR_SED="href=\"/torproject/tor/releases/tag/tor-"
TOR_HREF_FOR_SED1="<h2 data-view-component=\"true\" class=\"f4 d-inline\"><a href=\"/torproject/tor/releases/tag/tor-"
TOR_HREF_FOR_SED2="\" data-view-component=.*"
# TORURL_DL_PARTIAL is the the partial download path of the tor release packages
# (highlighted with "-><-": ->https://github.com/torproject/tor/releases/tag/tor<- -0.4.6.6.tar.gz)
TORURL_DL_PARTIAL="https://github.com/torproject/tor/archive/refs/tags/tor"

# Snowflake repositories
SNOWFLAKE_ORIGINAL_WEB="https://gitweb.torproject.org/pluggable-transports/snowflake.git"
# Only until version 2.2.0 - used until Torbox 0.5.0-Update 1
SNOWFLAKE_PREVIOUS_USED="https://github.com/keroserene/snowflake.git"
# NEW v.0.5.2 - version 2.3.0
SNOWFLAKE_USED="https://github.com/tgragnato/snowflake"

# NEW v.0.5.2
OBFS4PROXY_USED="https://salsa.debian.org/pkg-privacy-team/obfs4proxy.git"

# Wiringpi
WIRINGPI_USED="https://project-downloads.drogon.net/wiringpi-latest.deb"

# Connectivity check
CHECK_URL1="http://ubuntu.com"
CHECK_URL2="https://google.com"

# Catching command line options
OPTIONS=$(getopt -o h --long help,select-tor,select-fork:,select-branch:,step_by_step -n 'run-install' -- "$@")
if [ $? != 0 ] ; then echo "Syntax error!"; echo ""; OPTIONS="-h" ; fi
eval set -- "$OPTIONS"

SELECT_TOR=
SELECT_BRANCH=
TORBOXMENU_BRANCHNAME=
TORBOXMENU_FORKNAME=
STEP_BY_STEP=
while true; do
  case "$1" in
    -h | --help )
			echo "Copyright (C) 2023 Patrick Truffer, nyxnor (Contributor)"
			echo "Syntax : run_install.sh [-h|--help] [--select-tor] [--select-branch branch_name] [--step_by_step]"
			echo "Options: -h, --help     : Shows this help screen ;-)"
			echo "         --select-tor   : Let select a specific tor version (default: newest stable version)"
			echo "         --select-fork fork_owner_name"
			echo "                        : Let select a specific fork from a GitHub user (fork_owner_name)"
			echo "         --select-branch branch_name"
			echo "                        : Let select a specific TorBox branch (default: master)"
			echo "         --step_by_step : Executes the installation step by step"
			echo ""
			echo "Please before starting the installation ensure that the user account \"torbox\" is already created"
			echo "and that you are logged in as such."
			echo "For more information visit https://www.torbox.ch/ or https://github.com/radio24/TorBox"
			exit 0
	  ;;
    --select-tor ) SELECT_TOR="--select-tor"; shift ;;
		--select-fork )
		  # shellcheck disable=SC2034
			SELECT_FORK="--select-fork"
			[ ! -z "$2" ] && TORBOXMENU_FORKNAME="$2"
			shift 2
		;;
    --select-branch )
		  # shellcheck disable=SC2034
			SELECT_BRANCH="--select-branch"
			[ ! -z "$2" ] && TORBOXMENU_BRANCHNAME="$2"
			shift 2
		;;
    --step_by_step ) STEP_BY_STEP="--step_by_step"; shift ;;
		-- ) shift; break ;;
		* ) break ;;
  esac
done

# TorBox Repository
[ -z "$TORBOXMENU_FORKNAME" ] && TORBOXMENU_FORKNAME="radio24"
[ -z "$TORBOXMENU_BRANCHNAME" ] && TORBOXMENU_BRANCHNAME="master"
TORBOXURL="https://github.com/$TORBOXMENU_FORKNAME/TorBox/archive/refs/heads/$TORBOXMENU_BRANCHNAME.zip"

#Other variables
RUNFILE="torbox/run/torbox.run"
i=0
n=0

######## PREPARATIONS ########
#
# Configure variable for resolv.conf, if needed
NAMESERVERS_ORIG=$NAMESERVERS
ONE_NAMESERVER=$(cut -d ',' -f1 <<< $NAMESERVERS)
NAMESERVERS=$(cut -f2- -d ',' <<< $NAMESERVERS)
i=0
while [ "$ONE_NAMESERVER" != " " ]
do
	if [ $i = 0 ]; then
		RESOLVCONF="\n# Added by TorBox install script\n"
	fi
	RESOLVCONF="${RESOLVCONF}nameserver $ONE_NAMESERVER\n"
	i=$((i+1))
	if [ "$ONE_NAMESERVER" = "$NAMESERVERS" ]; then
		ONE_NAMESERVER=" "
	else
		ONE_NAMESERVER=$(cut -d ',' -f1 <<< $NAMESERVERS)
		NAMESERVERS=$(cut -f2- -d ',' <<< $NAMESERVERS)
	fi
done

##############################
######## FUNCTIONS ###########

# NEW v.0.5.3: New function re-connect
# This function tries to restor a connection to the Internet after failing to install a package
# Syntax: re-connect()
re-connect()
{
	if [ -f "/etc/resolv.conf" ]; then
		(sudo cp /etc/resolv.conf /etc/resolv.conf.bak) 2>&1
	fi
	(sudo printf "$RESOLVCONF" | sudo tee /etc/resolv.conf) 2>&1
	sleep 5
	wget -q --spider $CHECK_URL1
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
	  wget -q --spider $CHECK_URL2
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
	    wget -q --spider $CHECK_URL1
	    if [ $? -eq 0 ]; then
	      echo -e "${RED}[+]         Yes, now, we have an Internet connection! :-)${NOCOLOR}"
	    else
				echo -e "${RED}[+]         Hmmm, still no Internet connection... :-(${NOCOLOR}"
				echo -e "${RED}[+]         Internet connection is mandatory. We cannot continue - giving up!${NOCOLOR}"
				echo -e "${RED}[+]         Please, try to fix the problem and re-run the installation!${NOCOLOR}"
				exit 1
	    fi
	  fi
	fi
}

# NEW v.0.5.3: Modified to check, if the packages was installed
# This function installs the packages in a controlled way, so that the correct
# installation can be checked.
# Syntax check_install_packages <packagenames>
check_install_packages()
{
 packagenames=$1
 for packagename in $packagenames; do
	 check_installed=0
	 while [ $check_installed == "0" ]; do
	 	clear
	 	echo -e "${RED}[+] Step 3: Installing all necessary packages....${NOCOLOR}"
	 	echo ""
	 	echo -e "${RED}[+]         Installing ${WHITE}$packagename${NOCOLOR}"
	 	echo ""
	 	sudo apt-get -y install $packagename
		check=$(dpkg-query -s $packagename | grep "Status" | grep -o "installed")
		if [ "$check" == "installed" ]; then check_installed=1
		else re-connect
		fi
	done
 done
}

# select_and_install_tor()
# Syntax select_and_install_tor
# Used predefined variables: RED, WHITE, NOCOLOR, SELECT_TOR, URL, TORURL_DL_PARTIAL
# With this function change/update of tor from a list of versions is possible
# IMPORTANT: This function is different from the one in the update script!
select_and_install_tor()
{
  # Difference to the update-function - we cannot use torsocks yet
  echo -e "${RED}[+]         Can we access the unofficial Tor repositories on GitHub?${NOCOLOR}"
	#-m 6 must not be lower, otherwise it looks like there is no connection! ALSO IMPORTANT: THIS WILL NOT WORK WITH A CAPTCHA!
	OCHECK=$(curl -m 6 -s $TORURL)
	if [ $? == 0 ]; then
		echo -e "${WHITE}[!]         YES!${NOCOLOR}"
		echo ""
	else
		echo -e "${WHITE}[!]         NO!${NOCOLOR}"
		echo -e ""
		echo -e "${RED}[+] The unofficial Tor repositories may be blocked or offline!${NOCOLOR}"
		echo -e "${RED}[+] Please try again later and if the problem persists, please report it${NOCOLOR}"
		echo -e "${RED}[+] to ${WHITE}anonym@torbox.ch${RED}. ${NOCOLOR}"
		echo ""
		echo -e "${RED}[+] However, an older version of tor is alredy installed from${NOCOLOR}"
		echo -e "${RED}    the Raspberry PI OS repository.${NOCOLOR}"
		read -n 1 -s -r -p $'\e[1;31mPlease press any key to continue... \e[0m'
		clear
	fi
	echo -e "${RED}[+]         Fetching possible tor versions... ${NOCOLOR}"
	readarray -t torversion_versionsorted < <(curl --silent $TORURL | grep $TORPATH_TO_RELEASE_TAGS | sed -e "s|$TOR_HREF_FOR_SED1||g" | sed -e "s|$TOR_HREF_FOR_SED2||g" | sed -e "s/<a//g" | sed -e "s/\">//g" | sed -e "s/ //g" | sort -r)

  #How many tor version did we fetch?
	number_torversion=${#torversion_versionsorted[*]}
	if [ $number_torversion = 0 ]; then
		echo -e ""
		echo -e "${WHITE}[!] COULDN'T FIND ANY TOR VERSIONS${NOCOLOR}"
		echo -e "${RED}[+] The unofficial Tor repositories may be blocked or offline!${NOCOLOR}"
		echo -e "${RED}[+] Please try again later and if the problem persists, please report it${NOCOLOR}"
		echo -e "${RED}[+] to ${WHITE}anonym@torbox.ch${RED}. ${NOCOLOR}"
		echo ""
		echo -e "${RED}[+] However, an older version of tor is alredy installed from${NOCOLOR}"
		echo -e "${RED}    the Raspberry PI OS repository.${NOCOLOR}"
		echo ""
		read -n 1 -s -r -p $'\e[1;31mPlease press any key to continue... \e[0m'
		clear
  else
		#We will build a new array with only the relevant tor versions
    i=0
    while [ $i -lt $number_torversion ]
    do
      if [ $n = 0 ]; then
        torversion_versionsorted_new[0]=${torversion_versionsorted[0]}
        covered_version_full=${torversion_versionsorted[0]}
        covered_version=$(cut -d '.' -f1-3 <<< ${torversion_versionsorted[0]})
        i=$((i+1))
        n=$((n+1))
      else
        actual_version_full=${torversion_versionsorted[$i]}
        actual_version=$(cut -d '.' -f1-3 <<< ${torversion_versionsorted[$i]})
        if [ "$actual_version" == "$covered_version" ]; then
          covered_version_work="$(<<< "$covered_version_full" sed -e 's/\.//g' | sed -e s/"\^{}\|\-[a-z].*$"//g)"
          actual_version_work="$(<<< "$actual_version_full" sed -e 's/\.//g' | sed -e s/"\^{}\|\-[a-z].*$"//g)"
          if [ $actual_version_work -le $covered_version_work ]; then i=$((i+1))
          else
            n=$((n-1))
            torversion_versionsorted_new[$n]=${torversion_versionsorted[$i]}
            covered_version_full=$actual_version_full
            covered_version=$actual_version
            i=$((i+1))
            n=$((n+1))
          fi
        else
          torversion_versionsorted_new[$n]=${torversion_versionsorted[$i]}
          covered_version_full=$actual_version_full
          covered_version=$actual_version
          i=$((i+1))
          n=$((n+1))
        fi
      fi
    done
    number_torversion=$n

    #Display and chose a tor version
		if [ "$SELECT_TOR" = "--select-tor" ]; then
			clear
			echo -e "${WHITE}Choose a tor version (alpha versions are not recommended!):${NOCOLOR}"
    	echo ""
    	for (( i=0; i<$number_torversion; i++ ))
    	do
      	menuitem=$((i+1))
      	echo -e "${RED}$menuitem${NOCOLOR} - ${torversion_versionsorted_new[$i]}"
    	done
    	echo ""
    	read -r -p $'\e[1;37mWhich tor version (number) would you like to use? -> \e[0m'
    	echo
    	if [[ $REPLY =~ ^[1234567890]$ ]]; then
				if [ $REPLY -gt 0 ] && [ $((REPLY-1)) -le $number_torversion ]; then
        	CHOICE_TOR=$((REPLY-1))
        	clear
        	echo -e "${RED}[+]         Download the selected tor version...... ${NOCOLOR}"
        	version_string="$(<<< ${torversion_versionsorted_new[$CHOICE_TOR]} sed -e 's/ //g')"
        	download_tor_url="$TORURL_DL_PARTIAL-$version_string.tar.gz"
        	filename="tor-$version_string.tar.gz"
        	if [ -d ~/debian-packages ]; then sudo rm -r ~/debian-packages ; fi
        	mkdir ~/debian-packages; cd ~/debian-packages

					# Difference to the update-function - we cannot use torsocks yet
        	wget $download_tor_url
          DLCHECK=$?
        	if [ $DLCHECK -eq 0 ]; then
          	echo -e "${RED}[+]         Sucessfully downloaded the selected tor version... ${NOCOLOR}"
          	tar xzf $filename
          	cd "$(ls -d -- */)"
          	echo -e "${RED}[+]         Starting configuring, compiling and installing... ${NOCOLOR}"
						# Give it a touch of git (without these lines the compilation will break with a git error)
						git init
						git add -- *
						git config --global user.name "torbox"
						git config --global user.email "torbox@localhost"
						git commit -m "Initial commit"
						# Don't use ./autogen.sh
						sh autogen.sh
          	./configure
          	make
						sudo systemctl stop tor
						sudo systemctl mask tor
						# Both tor services have to be masked to block outgoing tor connections
						sudo systemctl mask tor@default.service
          	sudo make install
						sudo systemctl stop tor
						sudo systemctl mask tor
						# Both tor services have to be masked to block outgoing tor connections
						sudo systemctl mask tor@default.service
          	#read -n 1 -s -r -p $'\e[1;31mPlease press any key to continue... \e[0m'
        	else
						echo -e ""
						echo -e "${WHITE}[!] COULDN'T DOWNLOAD TOR!${NOCOLOR}"
						echo -e "${RED}[+] The unofficial Tor repositories may be blocked or offline!${NOCOLOR}"
						echo -e "${RED}[+] Please try again later and if the problem persists, please report it${NOCOLOR}"
						echo -e "${RED}[+] to ${WHITE}anonym@torbox.ch${RED}. ${NOCOLOR}"
						echo ""
						echo ""
						echo -e "${RED}[+] However, an older version of tor is alredy installed from${NOCOLOR}"
						echo -e "${RED}    the Raspberry PI OS repository.${NOCOLOR}"
						read -n 1 -s -r -p $'\e[1;31mPlease press any key to continue... \e[0m'
						clear
					fi
				else
					clear
					echo -e "${WHITE}[!] WRONG SELECTION!${NOCOLOR}"
	       	echo -e "${RED}[+] Restart the installation and try again! ${NOCOLOR}"
					echo ""
					sleep 5
					clear
					exit 0
				fi
    	else
				clear
				echo -e "${WHITE}[!] WRONG SELECTION!${NOCOLOR}"
				echo -e "${RED}[+] Restart the installation and try again! ${NOCOLOR}"
				echo ""
				sleep 5
				clear
				exit 0
			fi

		#Install the latest stable version of tor
		else
			echo ""
			echo -e "${RED}[+]         Selecting a tor version to install.${NOCOLOR}"
    	for (( i=0; i<$number_torversion; i++ ))
    	do
				if grep -v "-" <<< "${torversion_versionsorted_new[$i]}"; then
					version_string="$(<<< ${torversion_versionsorted_new[$i]} sed -e 's/ //g')"
					download_tor_url="$TORURL_DL_PARTIAL-$version_string.tar.gz"
        	filename="tor-$version_string.tar.gz"
					i=$number_torversion
				fi
    	done
			echo ""
			echo -e "${RED}[+]         Selected tor version ${WHITE}$version_string${RED}...${NOCOLOR}"
			echo -e "${RED}[+]         Download the selected tor version...... ${NOCOLOR}"
			if [ -d ~/debian-packages ]; then sudo rm -r ~/debian-packages ; fi
			mkdir ~/debian-packages; cd ~/debian-packages

			# Difference to the update-function - we cannot use torsocks yet
			wget $download_tor_url
			DLCHECK=$?
			if [ $DLCHECK -eq 0 ]; then
				echo -e "${RED}[+]         Sucessfully downloaded the selected tor version... ${NOCOLOR}"
				tar xzf $filename
				cd "$(ls -d -- */)"
				echo -e "${RED}[+]         Starting configuring, compiling and installing... ${NOCOLOR}"
				# Give it a touch of git (without these lines the compilation will break with a git error)
				git init
				git add -- *
				git config --global user.name "torbox"
				git config --global user.email "torbox@localhost"
				git commit -m "Initial commit"
				# Don't use ./autogen.sh
        sh autogen.sh
				./configure
				make
				sudo systemctl stop tor
				sudo systemctl mask tor
				# Both tor services have to be masked to block outgoing tor connections
				sudo systemctl mask tor@default.service
				sudo make install
				sudo systemctl stop tor
				sudo systemctl mask tor
				# Both tor services have to be masked to block outgoing tor connections
				sudo systemctl mask tor@default.service
			else
				echo -e ""
				echo -e "${WHITE}[!] COULDN'T DOWNLOAD TOR!${NOCOLOR}"
				echo -e "${RED}[+] The unofficial Tor repositories may be blocked or offline!${NOCOLOR}"
				echo -e "${RED}[+] Please try again later and if the problem persists, please report it${NOCOLOR}"
				echo -e "${RED}[+] to ${WHITE}anonym@torbox.ch${RED}. ${NOCOLOR}"
				echo ""
				read -n 1 -s -r -p $'\e[1;31mPlease press any key to continue... \e[0m'
				clear
				exit 0
			fi
		fi
	fi
}

###### DISPLAY THE INTRO ######
clear
if (whiptail --title "TorBox Installation on Raspberry Pi OS (scroll down!)" --scrolltext --no-button "INSTALL" --yes-button "STOP!" --yesno "         WELCOME TO THE INSTALLATION OF TORBOX ON RASPBERRY PI OS\n\nBefore we start, please ensure that you have already created a user account \"torbox\" and are currently logged in as such. Also, at the end of the installation, we will remove Rasperi Pi OS's auto-login feature - be sure you know your password for \"torbox\"!!\n\nBy the way, this script should be started as \"./run_install\" (without sudo !!) in your home directory, which is \"/home/torbox\".The installation process runs almost without user interaction. However, macchanger will ask for enabling an autmatic change of the MAC address - REPLY WITH NO!\n\nTHIS INSTALLATION WILL CHANGE/DELETE THE CURRENT CONFIGURATION!\n\nIMPORTANT\nInternet connectivity is necessary for the installation.\n\nAVAILABLE OPTIONS\n-h, --help     : shows a help screen\n--select-tor   : select a specific tor version\n--select-fork fork_owner_name\n  	  	   : select a specific fork from a GitHub user\n--select-branch branch_name\n  	  	   : select a specific TorBox branch\n--step_by_step : executes the installation step by step.\n\nIn case of any problems, contact us on https://www.torbox.ch." $MENU_HEIGHT_25 $MENU_WIDTH); then
	clear
	exit
fi
exitstatus=$?
# exitstatus == 255 means that the ESC key was pressed
[ "$exitstatus" == "255" ] && exit 0

# 1. Checking for Internet connection
clear
echo -e "${RED}[+] Step 1: Do we have Internet?${NOCOLOR}"
echo -e "${RED}[+]         Nevertheless, to be sure, let's add some open nameservers!${NOCOLOR}"

# NEW v.0.5.3
re-connect

# 2. Check the status of the WLAN regulatory domain to be sure WiFi will work
sleep 10
clear
echo -e "${RED}[+] Step 2: Check the status of the WLAN regulatory domain...${NOCOLOR}"
COUNTRY=$(sudo iw reg get | grep country | cut -d " " -f2)
if [ "$COUNTRY" = "00:" ]; then
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

if [ "$STEP_BY_STEP" = "--step_by_step" ]; then
	echo ""
	read -n 1 -s -r -p $'\e[1;31mPlease press any key to continue... \e[0m'
	clear
else
	sleep 10
fi

# 4. Installing all necessary packages
clear
echo -e "${RED}[+] Step 4: Installing all necessary packages....${NOCOLOR}"
(sudo systemctl stop tor) 2>/dev/null
(sudo systemctl mask tor) 2>/dev/null
# Both tor services have to be masked to block outgoing tor connections
(sudo systemctl mask tor@default.service) 2>/dev/null

# NEW v.0.5.2: (Re)moved: obfs4proxy
# Installation of standard packages
check_install_packages "hostapd isc-dhcp-server usbmuxd dnsmasq dnsutils tcpdump iftop vnstat debian-goodies apt-transport-https dirmngr python3-pip python3-pil imagemagick tesseract-ocr ntpdate screen git openvpn ppp python3-stem raspberrypi-kernel-headers dkms nyx apt-transport-tor qrencode nginx basez iptables ipset macchanger"
# Installation of developper packages - THIS PACKAGES ARE NECESARY FOR THE COMPILATION OF TOR!! Without them, tor will disconnect and restart every 5 minutes!!
check_install_packages "build-essential automake libevent-dev libssl-dev asciidoc bc devscripts dh-apparmor libcap-dev liblzma-dev libsystemd-dev libzstd-dev quilt zlib1g-dev"
# IMPORTANT tor-geoipdb installs also the tor package
check_install_packages "tor-geoipdb"
sudo systemctl stop tor
sudo systemctl mask tor
# Both tor services have to be masked to block outgoing tor connections
sudo systemctl mask tor@default.service

if [ "$STEP_BY_STEP" = "--step_by_step" ]; then
	echo ""
	read -n 1 -s -r -p $'\e[1;31mPlease press any key to continue... \e[0m'
	clear
fi

#Install wiringpi
clear
echo -e "${RED}[+] Step 4: Installing all necessary packages....${NOCOLOR}"
echo ""
echo -e "${RED}[+]         Installing ${WHITE}WiringPi${NOCOLOR}"
echo ""
wget $WIRINGPI_USED
sudo dpkg -i wiringpi-latest.deb
# NEW v.0.5.2: not nice, but working
sudo apt -y --fix-broken install
sudo dpkg -i wiringpi-latest.deb
sudo rm wiringpi-latest.deb

if [ "$STEP_BY_STEP" = "--step_by_step" ]; then
	echo ""
	read -n 1 -s -r -p $'\e[1;31mPlease press any key to continue... \e[0m'
	clear
fi

# Additional installations for Python
clear
echo -e "${RED}[+] Step 4: Installing all necessary packages....${NOCOLOR}"
echo ""
echo -e "${RED}[+]         Installing ${WHITE}Python modules${NOCOLOR}"
echo ""
sudo pip3 install pytesseract
# Mit v.0.5.3 zu testen
# sudo pip3 install mechanize==0.4.7
sudo pip3 install mechanize
sudo pip3 install PySocks
sudo pip3 install urwid
sudo pip3 install Pillow
sudo pip3 install requests
sudo pip3 install Django
sudo pip3 install click
sudo pip3 install gunicorn
sudo pip3 install paramiko
sudo pip3 install tornado
sudo pip3 install APScheduler
sudo pip3 install backports.zoneinfo
sudo pip3 install eventlet
sudo pip3 install python-socketio
sudo pip3 install opencv-python-headless
sudo pip3 install numpy

if [ "$STEP_BY_STEP" = "--step_by_step" ]; then
	echo ""
	read -n 1 -s -r -p $'\e[1;31mPlease press any key to continue... \e[0m'
	clear
fi

# Additional installation for GO
clear
echo -e "${RED}[+] Step 4: Installing all necessary packages....${NOCOLOR}"
echo ""
echo -e "${RED}[+]         Installing ${WHITE}go${NOCOLOR}"
echo ""
# NEW v.0.5.3: Check if go is already installed and has the right version
[ -f /usr/local/go/bin/go ] && GO_PROGRAM=/usr/local/go/bin/go || GO_PROGRAM=go
GO_VERSION_NR=$($GO_PROGRAM version | cut -d ' ' -f3 | cut -d '.' -f2)
if [ -z "$GO_VERSION_NR" ] || grep "No such file or directory" $GO_VERSION_NR || [ "$GO_VERSION_NR" -lt "17" ]; then
	if uname -m | grep -q -E "arm64|aarch64"; then DOWNLOAD="$GO_VERSION_64"
	else DOWNLOAD="$GO_VERSION"
	fi
	wget --no-cache "$GO_DL_PATH$DOWNLOAD"
	DLCHECK=$?
	if [ $DLCHECK -eq 0 ] ; then
  	sudo tar -C /usr/local -xzvf $DOWNLOAD
		# NEW v.0.5.3: what if .profile doesn't exist?
		if [ -f ".profile" ]; then
  		if ! grep "Added by TorBox (001)" .profile ; then
  			sudo printf "\n# Added by TorBox (001)\nexport PATH=$PATH:/usr/local/go/bin\n" | tee -a .profile
  		fi
		else
			sudo printf "\n# Added by TorBox (001)\nexport PATH=$PATH:/usr/local/go/bin\n" | tee -a .profile
		fi
  	export PATH=$PATH:/usr/local/go/bin
  	sudo rm $DOWNLOAD
  	if [ "$STEP_BY_STEP" = "--step_by_step" ]; then
  		echo ""
  		read -n 1 -s -r -p $'\e[1;31mPlease press any key to continue... \e[0m'
  		clear
  	else
  	sleep 10
  	fi
	else
		echo ""
		echo -e "${WHITE}[!] COULDN'T DOWNLOAD GO!${NOCOLOR}"
		echo -e "${RED}[+] The Go repositories may be blocked or offline!${NOCOLOR}"
		echo -e "${RED}[+] Please try again later and if the problem persists, please report it${NOCOLOR}"
		echo -e "${RED}[+] to ${WHITE}anonym@torbox.ch${RED}. ${NOCOLOR}"
		echo ""
		read -n 1 -s -r -p $'\e[1;31mPlease press any key to continue... \e[0m'
		exit 0
	fi
fi

# 5. Install Tor
clear
echo -e "${RED}[+] Step 5: Installing Tor...${NOCOLOR}"
select_and_install_tor

if [ "$STEP_BY_STEP" = "--step_by_step" ]; then
	echo ""
	read -n 1 -s -r -p $'\e[1;31mPlease press any key to continue... \e[0m'
	clear
else
	sleep 10
fi

# 6. Configuring Tor with its pluggable transports
clear
echo -e "${RED}[+] Step 6: Configuring Tor with its pluggable transports....${NOCOLOR}"
cd
git clone $OBFS4PROXY_USED
DLCHECK=$?
if [ $DLCHECK -eq 0 ]; then
	export GO111MODULE="on"
	cd obfs4proxy
	# NEW v.0.5.3 - with or without the path
	[ -f /usr/local/go/bin/go ] && GO_PROGRAM=/usr/local/go/bin/go || GO_PROGRAM=go
	$GO_PROGRAM build -o obfs4proxy/obfs4proxy ./obfs4proxy
	sudo cp ./obfs4proxy/obfs4proxy /usr/bin
	cd
	sudo rm -rf obfs4proxy
	sudo rm -rf go*
else
	echo ""
	echo -e "${WHITE}[!] COULDN'T CLONE THE OBFS4PROXY REPOSITORY!${NOCOLOR}"
	echo -e "${RED}[+] The obfs4proxy repository may be blocked or offline!${NOCOLOR}"
	echo -e "${RED}[+] Please try again later and if the problem persists, please report it${NOCOLOR}"
	echo -e "${RED}[+] to ${WHITE}anonym@torbox.ch${RED}. ${NOCOLOR}"
	echo -e "${RED}[+] In the meantime, we install the distribution package, which may be outdated.${NOCOLOR}"
	echo ""
	read -n 1 -s -r -p $'\e[1;31mPlease press any key to continue... \e[0m'
	check_install_packages obfs4proxy
	clear
fi
sudo setcap 'cap_net_bind_service=+ep' /usr/bin/obfs4proxy
(sudo mv /usr/local/bin/tor* /usr/bin) 2>/dev/null
sudo chmod a+x /usr/share/tor/geoip*
# Copying not moving!
(sudo cp /usr/share/tor/geoip* /usr/bin) 2>/dev/null
sudo sed -i "s/^NoNewPrivileges=yes/NoNewPrivileges=no/g" /lib/systemd/system/tor@default.service
sudo sed -i "s/^NoNewPrivileges=yes/NoNewPrivileges=no/g" /lib/systemd/system/tor@.service

if [ "$STEP_BY_STEP" = "--step_by_step" ]; then
	echo ""
	read -n 1 -s -r -p $'\e[1;31mPlease press any key to continue... \e[0m'
	clear
else
	sleep 10
fi

# 7. Install Snowflake
clear
echo -e "${RED}[+] Step 7: Installing Snowflake...${NOCOLOR}"
echo -e "${RED}[+]         This can take some time, please be patient!${NOCOLOR}"
cd
git clone $SNOWFLAKE_USED
DLCHECK=$?
if [ $DLCHECK -eq 0 ]; then
	export GO111MODULE="on"
	cd snowflake/proxy
	$GO_PROGRAM get
	$GO_PROGRAM build
	sudo cp proxy /usr/bin/snowflake-proxy
	cd
	cd snowflake/client
	$GO_PROGRAM get
	$GO_PROGRAM build
	sudo cp client /usr/bin/snowflake-client
	cd
	sudo rm -rf snowflake
	sudo rm -rf go*
else
	echo ""
	echo -e "${WHITE}[!] COULDN'T CLONE THE SNOWFLAKE REPOSITORY!${NOCOLOR}"
	echo -e "${RED}[+] The Snowflake repository may be blocked or offline!${NOCOLOR}"
	echo -e "${RED}[+] Please try again later and if the problem persists, please report it${NOCOLOR}"
	echo -e "${RED}[+] to ${WHITE}anonym@torbox.ch${RED}. ${NOCOLOR}"
	echo ""
	read -n 1 -s -r -p $'\e[1;31mPlease press any key to continue... \e[0m'
	clear
fi
if [ "$STEP_BY_STEP" = "--step_by_step" ]; then
	echo ""
	read -n 1 -s -r -p $'\e[1;31mPlease press any key to continue... \e[0m'
	clear
else
	sleep 10
fi

# 8. Again checking connectivity
clear
echo -e "${RED}[+] Step 9: Re-checking Internet connectivity${NOCOLOR}"
# NEW v.0.5.3
re-connect

# 9. Downloading and installing TorBox
sleep 10
clear
echo -e "${RED}[+] Step 10: Downloading and installing the latest version of TorBox...${NOCOLOR}"
# Showing the selected branch
echo -e "${RED}[+]          Selected branch ${WHITE}$TORBOXMENU_BRANCHNAME${RED}...${NOCOLOR}"
cd
wget $TORBOXURL
DLCHECK=$?
if [ $DLCHECK -eq 0 ] ; then
	echo -e "${RED}[+]         TorBox' menu sucessfully downloaded... ${NOCOLOR}"
	echo -e "${RED}[+]         Unpacking TorBox menu...${NOCOLOR}"
	unzip $TORBOXMENU_BRANCHNAME.zip
	echo ""
	echo -e "${RED}[+]         Removing the old one...${NOCOLOR}"
	(rm -r torbox) 2>/dev/null
	echo -e "${RED}[+]         Moving the new one...${NOCOLOR}"
	mv TorBox-$TORBOXMENU_BRANCHNAME torbox
	echo -e "${RED}[+]         Cleaning up...${NOCOLOR}"
	(rm -r $TORBOXMENU_BRANCHNAME.zip) 2>/dev/null
	echo ""
else
	echo ""
	echo -e "${WHITE}[!] COULDN'T DOWNLOAD TORBOX!${NOCOLOR}"
	echo -e "${RED}[+] The TorBox repositories may be blocked or offline!${NOCOLOR}"
	echo -e "${RED}[+] Please try again later and if the problem persists, please report it${NOCOLOR}"
	echo -e "${RED}[+] to ${WHITE}anonym@torbox.ch${RED}. ${NOCOLOR}"
	echo ""
	read -n 1 -s -r -p $'\e[1;31mPlease press any key to continue... \e[0m'
	exit 0
fi

if [ "$STEP_BY_STEP" = "--step_by_step" ]; then
	echo ""
	read -n 1 -s -r -p $'\e[1;31mPlease press any key to continue... \e[0m'
	clear
else
	sleep 10
fi

# 10. Installing all configuration files
clear
cd torbox
echo -e "${RED}[+] Step 11: Installing all configuration files....${NOCOLOR}"
echo ""
(sudo cp /etc/default/hostapd /etc/default/hostapd.bak) 2>/dev/null
sudo cp etc/default/hostapd /etc/default/
echo -e "${RED}[+]${NOCOLOR}         Copied /etc/default/hostapd -- backup done"
(sudo cp /etc/default/isc-dhcp-server /etc/default/isc-dhcp-server.bak) 2>/dev/null
sudo cp etc/default/isc-dhcp-server /etc/default/
echo -e "${RED}[+]${NOCOLOR}         Copied /etc/default/isc-dhcp-server -- backup done"
(sudo cp /etc/dhcp/dhclient.conf /etc/dhcp/dhclient.conf.bak) 2>/dev/null
sudo cp etc/dhcp/dhclient.conf /etc/dhcp/
echo -e "${RED}[+]${NOCOLOR}         Copied /etc/dhcp/dhclient.conf -- backup done"
(sudo cp /etc/dhcp/dhcpd.conf /etc/dhcp/dhcpd.conf.bak) 2>/dev/null
sudo cp etc/dhcp/dhcpd.conf /etc/dhcp/
echo -e "${RED}[+]${NOCOLOR}         Copied /etc/dhcp/dhcpd.conf -- backup done"
(sudo cp /etc/hostapd/hostapd.conf /etc/hostapd/hostapd.conf.bak) 2>/dev/null
sudo cp etc/hostapd/hostapd.conf /etc/hostapd/
echo -e "${RED}[+]${NOCOLOR}         Copied /etc/hostapd/hostapd.conf -- backup done"
(sudo cp /etc/iptables.ipv4.nat /etc/iptables.ipv4.nat.bak) 2>/dev/null
sudo cp etc/iptables.ipv4.nat /etc/
echo -e "${RED}[+]${NOCOLOR}         Copied /etc/iptables.ipv4.nat -- backup done"
(sudo cp /etc/motd /etc/motd.bak) 2>/dev/null
sudo cp etc/motd /etc/
echo -e "${RED}[+]${NOCOLOR}         Copied /etc/motd -- backup done"
(sudo cp /etc/network/interfaces /etc/network/interfaces.bak) 2>/dev/null
sudo cp etc/network/interfaces /etc/network/
echo -e "${RED}[+]${NOCOLOR}         Copied /etc/network/interfaces -- backup done"
sudo cp etc/systemd/system/rc-local.service /etc/systemd/system/rc-local.service
(sudo cp /etc/rc.local /etc/rc.local.bak) 2>/dev/null
sudo cp etc/rc.local /etc/
sudo chmod a+x /etc/rc.local
echo -e "${RED}[+]${NOCOLOR}         Copied /etc/rc.local -- backup done"
if grep -q "#net.ipv4.ip_forward=1" /etc/sysctl.conf ; then
  sudo cp /etc/sysctl.conf /etc/sysctl.conf.bak
  sudo sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
  echo -e "${RED}[+]${NOCOLOR}         Changed /etc/sysctl.conf -- backup done"
fi
(sudo cp /etc/tor/torrc /etc/tor/torrc.bak) 2>/dev/null
sudo cp etc/tor/torrc /etc/tor/
echo -e "${RED}[+]${NOCOLOR}         Copied /etc/tor/torrc -- backup done"
echo -e "${RED}[+]${NOCOLOR}         Activating IP forwarding"
sudo sh -c "echo 1 > /proc/sys/net/ipv4/ip_forward"
(sudo cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak) 2>/dev/null
(sudo cp etc/nginx/nginx.conf /etc/nginx/) 2>/dev/null
echo -e "${RED}[+]${NOCOLOR}         Copied /etc/nginx/nginx.conf -- backup done"
echo ""

#Back to the home directory
cd

# NEW v.0.5.3: what if .profile doesn't exist?
if [ -f ".profile" ]; then
	if ! grep "Added by TorBox (002)" .profile ; then
		sudo printf "\n# Added by TorBox (002)\ncd torbox\n./menu\n" | tee -a .profile
	fi
else
	printf "\n# Added by TorBox (002)\ncd torbox\n./menu\n" | tee -a .profile
fi

echo -e "${RED}[+]          Make tor ready for Onion Services${NOCOLOR}"
(sudo mkdir /var/lib/tor/services) 2>/dev/null
sudo chown -R debian-tor:debian-tor /var/lib/tor/services
sudo chmod -R go-rwx /var/lib/tor/services
(sudo mkdir /var/lib/tor/onion_auth) 2>/dev/null
sudo chown -R debian-tor:debian-tor /var/lib/tor/onion_auth
sudo chmod -R go-rwx /var/lib/tor/onion_auth

if [ "$STEP_BY_STEP" = "--step_by_step" ]; then
	echo ""
	read -n 1 -s -r -p $'\e[1;31mPlease press any key to continue... \e[0m'
	clear
else
	sleep 10
fi

# 11. Disabling Bluetooth
clear
echo -e "${RED}[+] Step 12: Because of security considerations, we completely disable the Bluetooth functionality${NOCOLOR}"
if ! grep "# Added by TorBox" /boot/config.txt ; then
  sudo printf "\n# Added by TorBox\ndtoverlay=disable-bt\n" | sudo tee -a /boot/config.txt
  sudo systemctl disable hciuart.service
  sudo systemctl disable bluealsa.service
  sudo systemctl disable bluetooth.service
  sudo apt-get -y purge bluez
  sudo apt-get -y autoremove
fi

if [ "$STEP_BY_STEP" = "--step_by_step" ]; then
	echo ""
	read -n 1 -s -r -p $'\e[1;31mPlease press any key to continue... \e[0m'
	clear
else
	sleep 10
fi

# 12. Configure the system services
clear
echo -e "${RED}[+] Step 13: Configure the system services...${NOCOLOR}"
sudo systemctl daemon-reload
sudo systemctl unmask hostapd
sudo systemctl enable hostapd
sudo systemctl start hostapd
sudo systemctl unmask isc-dhcp-server
sudo systemctl enable isc-dhcp-server
sudo systemctl start isc-dhcp-server
sudo systemctl stop tor
sudo systemctl mask tor
# Both tor services have to be masked to block outgoing tor connections
sudo systemctl mask tor@default.service
sudo systemctl unmask ssh
sudo systemctl enable ssh
sudo systemctl start ssh
sudo systemctl disable dhcpcd
echo ""
echo -e "${RED}[+]          Stop logging, now...${NOCOLOR}"
sudo systemctl stop rsyslog
sudo systemctl disable rsyslog
sudo systemctl mask rsyslog
sudo systemctl stop systemd-journald-dev-log.socket
sudo systemctl stop systemd-journald-audit.socket
sudo systemctl stop systemd-journald.socket
sudo systemctl stop systemd-journald.service
sudo systemctl mask systemd-journald.service
echo""

# Make Nginx ready for Webssh and Onion Services
echo -e "${RED}[+]          Make Nginx ready for Webssh and Onion Services${NOCOLOR}"
sudo systemctl stop nginx
(sudo rm /etc/nginx/sites-enabled/default) 2>/dev/null
(sudo rm /etc/nginx/sites-available/default) 2>/dev/null
(sudo rm -r /var/www/html) 2>/dev/null
# This is necessary for Nginx / TFS
(sudo chown torbox:torbox /var/www) 2>/dev/null
sudo cp torbox/etc/nginx/sites-available/sample-webssh.conf /etc/nginx/sites-available/webssh.conf
sudo ln -sf /etc/nginx/sites-available/webssh.conf /etc/nginx/sites-enabled/
# HAS TO BE TESTED: https://unix.stackexchange.com/questions/164866/nginx-leaves-old-socket
(sudo sed "s|STOP_SCHEDULE=\"${STOP_SCHEDULE:-QUIT/5/TERM/5/KILL/5}\"|STOP_SCHEDULE=\"${STOP_SCHEDULE:-TERM/5/KILL/5}\"|g" /etc/init.d/nginx) 2>/dev/null
#sudo systemctl start nginx
sudo systemctl daemon-reload

if [ "$STEP_BY_STEP" = "--step_by_step" ]; then
	echo ""
	read -n 1 -s -r -p $'\e[1;31mPlease press any key to continue... \e[0m'
	clear
else
	sleep 10
fi

# 13. Updating run/torbox.run
clear
echo -e "${RED}[+] Step 15: Configuring TorBox and update run/torbox.run...${NOCOLOR}"
echo -e "${RED}[+]          Update run/torbox.run${NOCOLOR}"
sudo sed -i "s/^NAMESERVERS=.*/NAMESERVERS=${NAMESERVERS_ORIG}/g" ${RUNFILE}
sudo sed -i "s/^GO_VERSION_64=.*/GO_VERSION_64=${GO_VERSION_64}/g" ${RUNFILE}
sudo sed -i "s/^GO_VERSION=.*/GO_VERSION=${GO_VERSION}/g" ${RUNFILE}
sudo sed -i "s|^GO_DL_PATH=.*|GO_DL_PATH=${GO_DL_PATH}|g" ${RUNFILE}
sudo sed -i "s|^OBFS4PROXY_USED=.*|OBFS4PROXY_USED=${OBFS4PROXY_USED}|g" ${RUNFILE}
sudo sed -i "s|^SNOWFLAKE_USED=.*|SNOWFLAKE_USED=${SNOWFLAKE_USED}|g" ${RUNFILE}
sudo sed -i "s|^WIRINGPI_USED=.*|WIRINGPI_USED=${WIRINGPI_USED}|g" ${RUNFILE}
# Is this right? Shouldn't it be FRESH_INSTALLED=3 ?
# If removed, FRESH_INSTALLED=1 is obsolet and can be deleted in first_use
sudo sed -i "s/^FRESH_INSTALLED=.*/FRESH_INSTALLED=1/" ${RUNFILE}

echo -e "${RED}[+]          Update sudo setup${NOCOLOR}"
sudo mkdir /home/torbox/openvpn
sudo chown -R torbox:torbox /home/torbox/
if ! sudo grep "# Added by TorBox" /etc/sudoers ; then
  sudo printf "\n# Added by TorBox\ntorbox  ALL=(ALL) NOPASSWD: ALL\n" | sudo tee -a /etc/sudoers
  (sudo visudo -c) 2>/dev/null
fi
cd /home/torbox/

if [ "$STEP_BY_STEP" = "--step_by_step" ]; then
	echo ""
	read -n 1 -s -r -p $'\e[1;31mPlease press any key to continue... \e[0m'
	clear
else
	sleep 10
fi

# 14. Finishing, cleaning and booting
echo ""
echo ""
echo -e "${RED}[+] Step 17: We are finishing and cleaning up now!${NOCOLOR}"
echo -e "${RED}[+]          This will erase all log files and cleaning up the system.${NOCOLOR}"
echo ""
echo -e "${WHITE}[!] IMPORTANT${NOCOLOR}"
echo -e "${WHITE}    After this last step, TorBox has to be rebooted.${NOCOLOR}"
echo -e "${WHITE}    In order to do so type \"exit\" and log in with \"torbox\" and your choosen password !! ${NOCOLOR}"
echo -e "${WHITE}    Use \"CHANGE-IT\" as password to connect the TorBox WiFi (TorBox053) ${NOCOLOR}"
echo ""
read -n 1 -s -r -p $'\e[1;31mTo complete the installation, please press any key... \e[0m'
clear
echo -e "${RED}[+] Erasing big not usefull packages...${NOCOLOR}"
(sudo rm -r debian-packages) 2>/dev/null
# Find the bigest space waster packages: dpigs -H
sudo apt-get -y remove libgl1-mesa-dri texlive* lmodern
sudo apt-get -y clean
sudo apt-get -y autoclean
sudo apt-get -y autoremove
echo -e "${RED}[+] Setting the timezone to UTC${NOCOLOR}"
sudo timedatectl set-timezone UTC
echo -e "${RED}[+] Erasing ALL LOG-files...${NOCOLOR}"
echo " "
# shellcheck disable=SC2044
for logs in $(sudo find /var/log -type f); do
  echo -e "${RED}[+]${NOCOLOR} Erasing $logs"
  sudo rm $logs
  sleep 1
done
echo -e "${RED}[+]${NOCOLOR} Erasing History..."
#.bash_history is already deleted
history -c
# To start TACA, notices.log has to be present
(sudo -u debian-tor touch /var/log/tor/notices.log) 2>/dev/null
(sudo chmod -R go-rwx /var/log/tor/notices.log) 2>/dev/null
echo ""
echo -e "${RED}[+]${NOCOLOR} Disable auto-login..."
sudo raspi-config nonint do_boot_behaviour B1
echo ""
echo -e "${RED}[+] Setting up the hostname...${NOCOLOR}"
# This has to be at the end to avoid unnecessary error messages
(sudo hostnamectl set-hostname TorBox052) 2>/dev/null
(sudo cp /etc/hosts /etc/hosts.bak) 2>/dev/null
(sudo cp torbox/etc/hosts /etc/) 2>/dev/null
echo -e "${RED}[+] Copied /etc/hosts -- backup done${NOCOLOR}"
echo ""
echo -e "${WHITE}[!] IMPORTANT${NOCOLOR}"
echo -e "${WHITE}    TorBox has to be rebooted.${NOCOLOR}"
echo -e "${WHITE}    In order to do so type \"exit\" and log in with \"torbox\" and your choosen password !! ${NOCOLOR}"
echo -e "${WHITE}    Use \"CHANGE-IT\" as password to connect the TorBox WiFi (TorBox052) ${NOCOLOR}"
echo ""
