#!/bin/bash
# shellcheck disable=SC2181,SC2001

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
# This script installs the newest version of TorBox on a clean, running
# Debian System (Tested with Bullseye, not with Bookworm
# - https://raspi.debian.net/tested-images/).
#
# SYNTAX
# ./run_install_debian.sh [-h|--help] [--select-tor] [--select-branch branch_name] [--step_by_step]
#
# The -h or --help option shows the help screen.
#
# The --select-tor option allows to select a specific tor version. Without
# this option, the installation script installs the latest stable version.
#
# The --select-branch option allows to install a specific TorBox branch.
# Without this option, the installation script installs the master branch.
#
# The --step_by_step option execute the installation step by step, which
# is ideal to find bugs.
#
# IMPORTANT
# Start it as root
#
##########################################################

# Table of contents for this script:
#  1. Checking for Internet connection
#  2. Updating the system
#  3. Installing all necessary packages
#  4. Installing Tor
#  5. Configuring Tor with its pluggable transports
#  6. Installing Snowflake
#  7. Installing Vanguards
#  8. Re-checking Internet connectivity
#  9. Downloading and installing the latest version of TorBox
# 10. Installing all configuration files
# 11. Disabling Bluetooth
# 12. Configure the system services
# 13. Installing additional network drivers
# 14. Updating run/torbox.run
# 15. Adding and implementing the user torbox
# 16. Setting/changing root password
# 17. Finishing, cleaning and booting

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

# Include/Exclude parts of the installations
# "YES" will install Vanguards / "NO" will not install it -> the related entry in the countermeasure menu will have no effect
VANGUARDS_INSTALL="YES"
# "YES" will install additional network drivers / "NO" will not install them -> these driver can be installed later from the Update and Reset sub-menu
ADDITIONAL_NETWORK_DRIVER="YES"

# Changes in the variables below (until the ####### delimiter) will be saved
# into run/torbox.run and used after the installation (we not recommend to
# change the values until zou precisely know what you are doing)
# Public nameserver used to circumvent cheap censorship
NAMESERVERS="1.1.1.1,1.0.0.1,8.8.8.8,8.8.4.4"

# Used go version
GO_VERSION="go1.18.4.linux-armv6l.tar.gz"
GO_VERSION_64="go1.18.4.linux-arm64.tar.gz"
GO_DL_PATH="https://golang.org/dl/"

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
# Offline?
SNOWFLAKE_ORIGINAL="https://git.torproject.org/pluggable-transports/snowflake.git"
# Only until version 2.2.0 - used until Torbox 0.5.0-Update 1
SNOWFLAKE_PREVIOUS_USED="https://github.com/keroserene/snowflake.git"
# NEW v.0.5.1 - version 2.3.0
SNOWFLAKE_USED="https://github.com/tgragnato/snowflake"

# Vanguards Repository
VANGUARDS_USED="https://github.com/mikeperry-tor/vanguards"
VANGUARDS_COMMIT_HASH=10942de
VANGUARDS_LOG_FILE="/var/log/tor/vanguards.log"

# Wiringpi - DEBIAN-SPECIFIC
WIRINGPI_USED="https://github.com/WiringPi/WiringPi.git"

# WiFi drivers from Fars Robotics
FARS_ROBOTICS_DRIVERS="http://downloads.fars-robotics.net/wifi-drivers/"

# above values will be saved into run/torbox.run #######

# Connectivity check - DEBIAN-SPECIFIC
CHECK_URL1="ubuntu.com"
CHECK_URL2="google.com"

# Default password
DEFAULT_PASS="CHANGE-IT"

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
			echo "Copyright (C) 2022 Patrick Truffer, nyxnor (Contributor)"
			echo "Syntax : run_install_debian.sh [-h|--help] [--select-tor] [--select-branch branch_name] [--step_by_step]"
			echo "Options: -h, --help     : Shows this help screen ;-)"
			echo "         --select-tor   : Let select a specific tor version (default: newest stable version)"
			echo "         --select-fork fork_owner_name"
			echo "                        : Let select a specific fork from a GitHub user (fork_owner_name)"
			echo "         --select-branch branch_name"
			echo "                        : Let select a specific TorBox branch (default: master)"
			echo "         --step_by_step : Executes the installation step by step"
			echo ""
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

#Identifying the hardware (see also https://gist.github.com/jperkin/c37a574379ef71e339361954be96be12)
if grep -q --text 'Raspberry Pi' /proc/device-tree/model ; then CHECK_HD1="Raspberry Pi" ; fi
if grep -q "Raspberry Pi" /proc/cpuinfo ; then CHECK_HD2="Raspberry Pi" ; fi


##############################
######## FUNCTIONS ###########

# This function installs the packages in a controlled way, so that the correct
# installation can be checked.
# Syntax install_network_drivers <packagenames>
check_install_packages()
{
 packagenames=$1
 for packagename in $packagenames; do
	 clear
	 echo -e "${RED}[+] Step 3: Installing all necessary packages....${NOCOLOR}"
	 echo ""
	 echo -e "${RED}[+]         Installing ${WHITE}$packagename${NOCOLOR}"
	 echo ""
	 apt-get -y install $packagename
#   echo ""
#   read -n 1 -s -r -p "Press any key to continue"
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
		echo -e "${RED}    the repository.${NOCOLOR}"
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
		echo -e "${RED}    the repository.${NOCOLOR}"
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
        	if [ -d ~/debian-packages ]; then rm -r ~/debian-packages ; fi
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
						systemctl stop tor
						systemctl mask tor
						# Both tor services have to be masked to block outgoing tor connections
						systemctl mask tor@default.service
          	make install
						systemctl stop tor
						systemctl mask tor
						# Both tor services have to be masked to block outgoing tor connections
						systemctl mask tor@default.service
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
						echo -e "${RED}    the repository.${NOCOLOR}"
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
			if [ -d ~/debian-packages ]; then rm -r ~/debian-packages ; fi
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
				systemctl stop tor
				systemctl mask tor
				# Both tor services have to be masked to block outgoing tor connections
				systemctl mask tor@default.service
				make install
				systemctl stop tor
				systemctl mask tor
				# Both tor services have to be masked to block outgoing tor connections
				systemctl mask tor@default.service
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
if (whiptail --title "TorBox Installation on Debian(scroll down!)" --scrolltext --no-button "INSTALL" --yes-button "STOP!" --yesno "         WELCOME TO THE INSTALLATION OF TORBOX ON DEBIAN\n\nPlease make sure that you started this script as \"./run_install_debian\" (without sudo !!) in your home directory.\n\nThe installation process runs almost without user interaction. However, macchanger will ask for enabling an autmatic change of the MAC address - REPLY WITH NO!\n\nTHIS INSTALLATION WILL CHANGE/DELETE THE CURRENT CONFIGURATION!\n\nDuring the installation, we are going to set up the user \"torbox\" with the default password \"$DEFAULT_PASS\". This user name and the password will be used for logging into your TorBox and to administering it. Please, change the default passwords as soon as possible (the associated menu entries are placed in the configuration sub-menu).\n\nIMPORTANT\nInternet connectivity is necessary for the installation.\n\nAVAILABLE OPTIONS\n-h, --help     : shows a help screen\n--select-tor   : select a specific tor version\n--select-fork fork_owner_name\n  	  	   : select a specific fork from a GitHub user\n--select-branch branch_name\n  	  	   : select a specific TorBox branch\n--step_by_step : Executes the installation step by step.\n\nIn case of any problems, contact us on https://www.torbox.ch." $MENU_HEIGHT_25 $MENU_WIDTH); then
	clear
	exit
fi

# 1. Checking for Internet connection
clear
echo -e "${RED}[+] Step 1: Do we have Internet?${NOCOLOR}"
echo -e "${RED}[+]         Nevertheless, to be sure, let's add some open nameservers!${NOCOLOR}"
if [ -f "/etc/resolv.conf" ]; then
	(cp /etc/resolv.conf /etc/resolv.conf.bak) 2>&1
fi
(printf "$RESOLVCONF" | tee /etc/resolv.conf) 2>&1
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

if [ "$STEP_BY_STEP" = "--step_by_step" ]; then
	echo ""
	read -n 1 -s -r -p $'\e[1;31mPlease press any key to continue... \e[0m'
	clear
else
	sleep 10
fi

# 3. Installing all necessary packages
clear
echo -e "${RED}[+] Step 3: Installing all necessary packages....${NOCOLOR}"
systemctl stop tor
systemctl mask tor
# Both tor services have to be masked to block outgoing tor connections
systemctl mask tor@default.service

# Necessary packages for Debian systems (not necessary with Raspberry Pi OS)
check_install_packages "wget curl gnupg net-tools unzip sudo resolvconf"
# NEW v.0.5.1: New packages: macchanger and shellinabox removed
# Installation of standard packages
check_install_packages "hostapd isc-dhcp-server usbmuxd dnsmasq dnsutils tcpdump iftop vnstat debian-goodies apt-transport-https dirmngr python3-pip python3-pil imagemagick tesseract-ocr ntpdate screen git openvpn ppp python3-stem dkms nyx obfs4proxy apt-transport-tor qrencode nginx basez iptables macchanger"
# Installation of developper packages - THIS PACKAGES ARE NECESARY FOR THE COMPILATION OF TOR!! Without them, tor will disconnect and restart every 5 minutes!!
check_install_packages "build-essential automake libevent-dev libssl-dev asciidoc bc devscripts dh-apparmor libcap-dev liblzma-dev libsystemd-dev libzstd-dev quilt pkg-config zlib1g-dev"
# tor-geoipdb installiert auch tor
check_install_packages "tor-geoipdb"
systemctl stop tor
systemctl mask tor
# Both tor services have to be masked to block outgoing tor connections
systemctl mask tor@default.service

if [ "$STEP_BY_STEP" = "--step_by_step" ]; then
	echo ""
	read -n 1 -s -r -p $'\e[1;31mPlease press any key to continue... \e[0m'
	clear
fi

#Install wiringpi
clear
echo -e "${RED}[+] Step 3: Installing all necessary packages....${NOCOLOR}"
echo ""
echo -e "${RED}[+]         Installing ${WHITE}WiringPi${NOCOLOR}"
echo ""
cd ~
git clone $WIRINGPI_USED
DLCHECK=$?
if [ $DLCHECK -eq 0 ]; then
	cd WiringPi
	./build
	cd ~
	rm -r WiringPi
	if [ "$STEP_BY_STEP" = "--step_by_step" ]; then
		echo ""
		read -n 1 -s -r -p $'\e[1;31mPlease press any key to continue... \e[0m'
		clear
	fi
else
	echo ""
	echo -e "${WHITE}[!] COULDN'T CLONE THE WIRINGPI REPOSITORY!${NOCOLOR}"
	echo -e "${RED}[+] The WiringPi repository may be blocked or offline!${NOCOLOR}"
	echo -e "${RED}[+] Please try again later and if the problem persists, please report it${NOCOLOR}"
	echo -e "${RED}[+] to ${WHITE}anonym@torbox.ch${RED}. ${NOCOLOR}"
	echo ""
	read -n 1 -s -r -p $'\e[1;31mPlease press any key to continue... \e[0m'
	clear
fi

# Additional installations for Python
clear
echo -e "${RED}[+] Step 3: Installing all necessary packages....${NOCOLOR}"
echo ""
echo -e "${RED}[+]         Installing ${WHITE}Python modules${NOCOLOR}"
echo ""
pip3 install pytesseract
pip3 install mechanize==0.47
pip3 install PySocks
pip3 install urwid
pip3 install Pillow
pip3 install requests
pip3 install Django
pip3 install click
pip3 install gunicorn
# NEW v.0.5.1
sudo pip3 install click
sudo pip3 install paramiko
sudo pip3 install tornado
sudo pip3 install APScheduler
sudo pip3 install backports.zoneinfo
sudo pip3 install eventlet
sudo pip3 install python-socketio

if [ "$STEP_BY_STEP" = "--step_by_step" ]; then
	echo ""
	read -n 1 -s -r -p $'\e[1;31mPlease press any key to continue... \e[0m'
	clear
fi

# Additional installation for GO
clear
echo -e "${RED}[+] Step 3: Installing all necessary packages....${NOCOLOR}"
echo ""
echo -e "${RED}[+]         Installing ${WHITE}go${NOCOLOR}"
echo ""
if uname -m | grep -q -E "arm64|aarch64"; then
  wget https://golang.org/dl/$GO_VERSION_64
  DLCHECK=$?
  if [ $DLCHECK -eq 0 ] ; then
  	tar -C /usr/local -xzvf $GO_VERSION_64
  	if ! grep "# Added by TorBox (001)" .profile ; then
  		printf "\n# Added by TorBox (001)\nexport PATH=$PATH:/usr/local/go/bin\n" | sudo tee -a .profile
  	fi
  	export PATH=$PATH:/usr/local/go/bin
  	rm $GO_VERSION_64
    if [ "$STEP_BY_STEP" = "--step_by_step" ]; then
    	echo ""
    	read -n 1 -s -r -p $'\e[1;31mPlease press any key to continue... \e[0m'
    	clear
    else
    	sleep 10
    fi
  else
  	echo ""
  	echo -e "${WHITE}[!] COULDN'T DOWNLOAD GO (arm64)!${NOCOLOR}"
  	echo -e "${RED}[+] The Go repositories may be blocked or offline!${NOCOLOR}"
  	echo -e "${RED}[+] Please try again later and if the problem persists, please report it${NOCOLOR}"
  	echo -e "${RED}[+] to ${WHITE}anonym@torbox.ch${RED}. ${NOCOLOR}"
  	echo ""
  	read -n 1 -s -r -p $'\e[1;31mPlease press any key to continue... \e[0m'
  	exit 0
  fi
else
  wget https://golang.org/dl/$GO_VERSION
  DLCHECK=$?
  if [ $DLCHECK -eq 0 ] ; then
  	tar -C /usr/local -xzvf $GO_VERSION
  	if ! grep "# Added by TorBox (001)" .profile ; then
  		printf "\n# Added by TorBox (001)\nexport PATH=$PATH:/usr/local/go/bin\n" | sudo tee -a .profile
  	fi
  	export PATH=$PATH:/usr/local/go/bin
  	rm $GO_VERSION
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

# 4. Installing Tor
clear
echo -e "${RED}[+] Step 4: Installing Tor...${NOCOLOR}"
select_and_install_tor

if [ "$STEP_BY_STEP" = "--step_by_step" ]; then
	echo ""
	read -n 1 -s -r -p $'\e[1;31mPlease press any key to continue... \e[0m'
	clear
else
	sleep 10
fi

# 5. Configuring Tor with its pluggable transports
clear
echo -e "${RED}[+] Step 5: Configuring Tor with its pluggable transports....${NOCOLOR}"
(mv /usr/local/bin/tor* /usr/bin) 2> /dev/null
(chmod a+x /usr/share/tor/geoip*) 2> /dev/null
# Debian specific
(chmod a+x /usr/local/share/tor/geoip*) 2> /dev/null
# Copy not moving!
(cp /usr/share/tor/geoip* /usr/bin) 2> /dev/null
# Debian specific
(cp /usr/local/share/tor/geoip* /usr/bin) 2> /dev/null
setcap 'cap_net_bind_service=+ep' /usr/bin/obfs4proxy
sed -i "s/^NoNewPrivileges=yes/NoNewPrivileges=no/g" /lib/systemd/system/tor@default.service
sed -i "s/^NoNewPrivileges=yes/NoNewPrivileges=no/g" /lib/systemd/system/tor@.service

if [ "$STEP_BY_STEP" = "--step_by_step" ]; then
	echo ""
	read -n 1 -s -r -p $'\e[1;31mPlease press any key to continue... \e[0m'
	clear
else
	sleep 10
fi

# 6. Install Snowflake
clear
echo -e "${RED}[+] Step 6: Installing Snowflake...${NOCOLOR}"
cd ~
git clone $SNOWFLAKE_USED
DLCHECK=$?
if [ $DLCHECK -eq 0 ]; then
	sleep 1
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
export GO111MODULE="on"
cd ~/snowflake/proxy
#These paths to go are Debian specific
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

if [ "$STEP_BY_STEP" = "--step_by_step" ]; then
	echo ""
	read -n 1 -s -r -p $'\e[1;31mPlease press any key to continue... \e[0m'
	clear
else
	sleep 10
fi

# 7. Installing Vanguards
if [ "$VANGUARDS_INSTALL" = "YES" ]; then
	clear
	cd
	echo -e "${RED}[+] Step 7: Installing Vanguards...${NOCOLOR}"
	(rm -rf vanguards) 2> /dev/null
	(rm -rf /var/lib/tor/vanguards) 2> /dev/null
	git clone $VANGUARDS_USED
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
	chown -R debian-tor:debian-tor vanguards
	cd vanguards
	git reset --hard ${VANGUARDS_COMMIT_HASH}
	cd
	mv vanguards /var/lib/tor/
	cp /var/lib/tor/vanguards/vanguards-example.conf /etc/tor/vanguards.conf
	sed -i "s/^control_pass =.*/control_pass = ${DEFAULT_PASS}/" /etc/tor/vanguards.conf
	#This is necessary to work with special characters in sed
	sed -i "s|^logfile =.*|logfile = ${VANGUARDS_LOG_FILE}|" /etc/tor/vanguards.conf
	# Because of TorBox's automatic counteractions, Vanguard cannot interfere with tor's log file
	sed -i "s/^enable_logguard =.*/enable_logguard = False/" /etc/tor/vanguards.conf
	sed -i "s/^log_protocol_warns =.*/log_protocol_warns = False/" /etc/tor/vanguards.conf
	chown -R debian-tor:debian-tor /var/lib/tor/vanguards
	chmod -R go-rwx /var/lib/tor/vanguards

	if [ "$STEP_BY_STEP" = "--step_by_step" ]; then
		echo ""
		read -n 1 -s -r -p $'\e[1;31mPlease press any key to continue... \e[0m'
		clear
	else
		sleep 10
	fi
fi

# 8. Again checking connectivity
clear
echo -e "${RED}[+] Step 8: Re-checking Internet connectivity${NOCOLOR}"
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
			if [ -f "/etc/resolv.conf" ]; then
				(cp /etc/resolv.conf /etc/resolv.conf.bak) 2>&1
			fi
			(printf "$RESOLVCONF" | tee /etc/resolv.conf) 2>&1
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

# 9. Downloading and installing the latest version of TorBox
sleep 10
clear
echo -e "${RED}[+] Step 9: Downloading and installing the latest version of TorBox...${NOCOLOR}"
echo -e "${RED}[+]         Selected branch ${WHITE}$TORBOXMENU_BRANCHNAME${RED}...${NOCOLOR}"
cd
wget $TORBOXURL
DLCHECK=$?
if [ $DLCHECK -eq 0 ] ; then
	echo -e "${RED}[+]         TorBox' menu sucessfully downloaded... ${NOCOLOR}"
	echo -e "${RED}[+]         Unpacking TorBox menu...${NOCOLOR}"
	unzip $TORBOXMENU_BRANCHNAME.zip
	echo ""
	echo -e "${RED}[+]         Removing the old one...${NOCOLOR}"
	(rm -r torbox) 2> /dev/null
	echo -e "${RED}[+]         Moving the new one...${NOCOLOR}"
	mv TorBox-$TORBOXMENU_BRANCHNAME torbox
	echo -e "${RED}[+]         Cleaning up...${NOCOLOR}"
	(rm -r $TORBOXMENU_BRANCHNAME.zip) 2> /dev/null
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
echo -e "${RED}[+] Step 10: Installing all configuration files....${NOCOLOR}"
echo ""
# NEW v.0.5.1: shellinabox removed
# Configuring Vanguards
if [ "$VANGUARDS_INSTALL" = "YES" ]; then
  (cp etc/systemd/system/vanguards@default.service /etc/systemd/system/) 2> /dev/null
  echo -e "${RED}[+]${NOCOLOR}         Copied vanguards@default.service"
fi
(cp /etc/default/hostapd /etc/default/hostapd.bak) 2> /dev/null
cp etc/default/hostapd /etc/default/
echo -e "${RED}[+]${NOCOLOR}         Copied /etc/default/hostapd -- backup done"
(cp /etc/default/isc-dhcp-server /etc/default/isc-dhcp-server.bak) 2> /dev/null
cp etc/default/isc-dhcp-server /etc/default/
echo -e "${RED}[+]${NOCOLOR}         Copied /etc/default/isc-dhcp-server -- backup done"
(cp /etc/dhcp/dhclient.conf /etc/dhcp/dhclient.conf.bak) 2> /dev/null
cp etc/dhcp/dhclient.conf /etc/dhcp/
echo -e "${RED}[+]${NOCOLOR}         Copied /etc/dhcp/dhclient.conf -- backup done"
(cp /etc/dhcp/dhcpd.conf /etc/dhcp/dhcpd.conf.bak) 2> /dev/null
cp etc/dhcp/dhcpd.conf /etc/dhcp/
echo -e "${RED}[+]${NOCOLOR}         Copied /etc/dhcp/dhcpd.conf -- backup done"
(cp /etc/hostapd/hostapd.conf /etc/hostapd/hostapd.conf.bak) 2> /dev/null
cp etc/hostapd/hostapd.conf /etc/hostapd/
echo -e "${RED}[+]${NOCOLOR}         Copied /etc/hostapd/hostapd.conf -- backup done"
(cp /etc/iptables.ipv4.nat /etc/iptables.ipv4.nat.bak) 2> /dev/null
cp etc/iptables.ipv4.nat /etc/
echo -e "${RED}[+]${NOCOLOR}         Copied /etc/iptables.ipv4.nat -- backup done"
(cp /etc/motd /etc/motd.bak) 2> /dev/null
cp etc/motd /etc/
echo -e "${RED}[+]${NOCOLOR}         Copied /etc/motd -- backup done"
(cp /etc/network/interfaces /etc/network/interfaces.bak) 2> /dev/null
cp etc/network/interfaces /etc/network/
echo -e "${RED}[+]${NOCOLOR}         Copied /etc/network/interfaces -- backup done"
cp etc/systemd/system/rc-local.service /etc/systemd/system/rc-local.service
(cp /etc/rc.local /etc/rc.local.bak) 2> /dev/null
cp etc/rc.local.ubuntu /etc/rc.local
chmod a+x /etc/rc.local
echo -e "${RED}[+]${NOCOLOR}         Copied /etc/rc.local -- backup done"
if grep -q "#net.ipv4.ip_forward=1" /etc/sysctl.conf ; then
  cp /etc/sysctl.conf /etc/sysctl.conf.bak
  sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
  echo -e "${RED}[+]${NOCOLOR}         Changed /etc/sysctl.conf -- backup done"
fi
(cp /etc/tor/torrc /etc/tor/torrc.bak) 2> /dev/null
cp etc/tor/torrc /etc/tor/
echo -e "${RED}[+]${NOCOLOR}         Copied /etc/tor/torrc -- backup done"
echo -e "${RED}[+]${NOCOLOR}         Activating IP forwarding"
sh -c "echo 1 > /proc/sys/net/ipv4/ip_forward"
(cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak) 2> /dev/null
cp etc/nginx/nginx.conf /etc/nginx/
echo -e "${RED}[+]${NOCOLOR}         Copied /etc/nginx/nginx.conf -- backup done"

#Back to the home directory
cd
if ! grep "# Added by TorBox (002)" .profile ; then
	printf "\n# Added by TorBox (002)\ncd torbox\n./menu\n" | tee -a .profile
fi

echo -e "${RED}[+]          Make Tor ready for Onion Services${NOCOLOR}"
mkdir /var/lib/tor/services
chown -R debian-tor:debian-tor /var/lib/tor/services
chmod -R go-rwx /var/lib/tor/services
mkdir /var/lib/tor/onion_auth
chown -R debian-tor:debian-tor /var/lib/tor/onion_auth
chmod -R go-rwx /var/lib/tor/onion_auth

if [ "$STEP_BY_STEP" = "--step_by_step" ]; then
	echo ""
	read -n 1 -s -r -p $'\e[1;31mPlease press any key to continue... \e[0m'
	clear
else
	sleep 10
fi

# 11. Disabling Bluetooth
clear
echo -e "${RED}[+] Step 11: Because of security considerations, we completely disable the Bluetooth functionality${NOCOLOR}"
if ! grep "# Added by TorBox" /boot/firmware/config.txt ; then
   printf "\n# Added by TorBox\ndtoverlay=disable-bt\n." | tee -a /boot/firmware/config.txt
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
systemctl daemon-reload
systemctl unmask hostapd
systemctl enable hostapd
systemctl start hostapd
systemctl unmask isc-dhcp-server
systemctl enable isc-dhcp-server
systemctl start isc-dhcp-server
systemctl stop tor
systemctl stop tor
systemctl mask tor
# Both tor services have to be masked to block outgoing tor connections
systemctl mask tor@default.service
systemctl unmask ssh
systemctl enable ssh
systemctl start ssh
# sudo systemctl disable dhcpcd - not installed on Debian
systemctl stop dnsmasq
systemctl disable dnsmasq
# Debian specific
systemctl unmask resolvconf
systemctl enable resolvconf
systemctl start resolvconf
systemctl unmask rc-local
systemctl enable rc-local
echo ""
echo -e "${RED}[+]          Stop logging, now...${NOCOLOR}"
systemctl stop rsyslog
systemctl disable rsyslog
systemctl mask rsyslog
# NEW v.0.5.1
systemctl stop systemd-journald-dev-log.socket
systemctl stop systemd-journald-audit.socket
systemctl stop systemd-journald.socket
systemctl stop systemd-journald.service
systemctl mask systemd-journald.service
echo""

# Make Nginx ready for Webssh and Onion Services
echo -e "${RED}[+]          Make Nginx ready for Webssh and Onion Services${NOCOLOR}"
systemctl stop nginx
(rm /etc/nginx/sites-enabled/default) 2> /dev/null
(rm /etc/nginx/sites-available/default) 2> /dev/null
(rm -r /var/www/html) 2> /dev/null
# This is necessary for Nginx / TFS
(chown torbox:torbox /var/www)
# HAS TO BE TESTED: https://unix.stackexchange.com/questions/164866/nginx-leaves-old-socket
sleep 5
(sed "s|STOP_SCHEDULE=\"${STOP_SCHEDULE:-QUIT/5/TERM/5/KILL/5}\"|STOP_SCHEDULE=\"${STOP_SCHEDULE:-TERM/5/KILL/5}\"|g" /etc/init.d/nginx) 2> /dev/null
systemctl start nginx
systemctl daemon-reload

if [ "$STEP_BY_STEP" = "--step_by_step" ]; then
	echo ""
	read -n 1 -s -r -p $'\e[1;31mPlease press any key to continue... \e[0m'
	clear
else
	sleep 10
fi

# 13. Installing additional network drivers
if [ "$ADDITIONAL_NETWORK_DRIVER" = "YES" ]; then
	clear
	echo -e "${RED}[+] Step 13: Installing additional network drivers...${NOCOLOR}"
	echo -e " "

	# Update kernel headers - important: this has to be done every time after upgrading the kernel
	echo -e "${RED}[+] Installing additional software... ${NOCOLOR}"
	apt-get install -y linux-headers-$(uname -r)
	apt-get install -y firmware-realtek dkms libelf-dev build-essential
	cd ~
	sleep 2

	# Installing the RTL8188EU
	clear
	echo -e "${RED}[+] Step 13: Installing additional network drivers...${NOCOLOR}"
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
	echo -e "${RED}[+] Step 13: Installing additional network drivers...${NOCOLOR}"
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
	echo -e "${RED}[+] Step 13: Installing additional network drivers...${NOCOLOR}"
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
	echo -e "${RED}[+] Step 13: Installing additional network drivers...${NOCOLOR}"
	echo -e " "
	echo -e "${RED}[+] Installing the Realtek RTL8812AU Wireless Network Driver ${NOCOLOR}"
	git clone https://github.com/morrownr/8812au-20210629.git
	cd 8812au-20210629
	cp /home/torbox/torbox/install/Network/install-rtl8812au.sh .
	chmod a+x install-rtl8812au.sh
	if [ ! -z "$CHECK_HD1" ] || [ ! -z "$CHECK_HD2" ]; then
		if uname -m | grep -q -E "arm64|aarch64"; then
			./ARM64_RPI.sh
		else
	 	./ARM_RPI.sh
 	fi
	fi
	./install-rtl8812au.sh
	cd ~
	rm -r 8812au-20210629
	sleep 2

	# Installing the RTL8814AU
	clear
	echo -e "${RED}[+] Step 13: Installing additional network drivers...${NOCOLOR}"
	echo -e " "
	echo -e "${RED}[+] Installing the Realtek RTL8814AU Wireless Network Driver ${NOCOLOR}"
	git clone https://github.com/morrownr/8814au.git
	cd 8814au
	cp /home/torbox/torbox/install/Network/install-rtl8814au.sh .
	chmod a+x install-rtl8814au.sh
	if [ ! -z "$CHECK_HD1" ] || [ ! -z "$CHECK_HD2" ]; then
		if uname -m | grep -q -E "arm64|aarch64"; then
			./ARM64_RPI.sh
		else
	 	./ARM_RPI.sh
 	fi
	fi
	./install-rtl8814au.sh
	cd ~
	rm -r 8814au
	sleep 2

	# Installing the RTL8821AU
	clear
	echo -e "${RED}[+] Step 13: Installing additional network drivers...${NOCOLOR}"
	echo -e " "
	echo -e "${RED}[+] Installing the Realtek RTL8821AU Wireless Network Driver ${NOCOLOR}"
	git clone https://github.com/morrownr/8821au-20210708.git
	cd 8821au-20210708
	cp /home/torbox/torbox/install/Network/install-rtl8821au.sh .
	chmod a+x install-rtl8821au.sh
	if [ ! -z "$CHECK_HD1" ] || [ ! -z "$CHECK_HD2" ]; then
		if uname -m | grep -q -E "arm64|aarch64"; then
			./ARM64_RPI.sh
		else
	 	./ARM_RPI.sh
 	fi
	fi
	./install-rtl8821au.sh
	cd ~
	rm -r 8821au-20210708
	sleep 2

	# Installing the RTL8821CU
	clear
	echo -e "${RED}[+] Step 13: Installing additional network drivers...${NOCOLOR}"
	echo -e " "
	echo -e "${RED}[+] Installing the Realtek RTL8821CU Wireless Network Driver ${NOCOLOR}"
	git clone https://github.com/morrownr/8821cu-20210118.git
	cd 8821cu-20210118
	cp /home/torbox/torbox/install/Network/install-rtl8821cu.sh .
	chmod a+x install-rtl8821cu.sh
	if [ ! -z "$CHECK_HD1" ] || [ ! -z "$CHECK_HD2" ]; then
		if uname -m | grep -q -E "arm64|aarch64"; then
			./ARM64_RPI.sh
		else
	 	./ARM_RPI.sh
 	fi
	fi
	./install-rtl8821cu.sh
	cd ~
	rm -r 8821cu-20210118
	sleep 2

	# Installing the RTL88x2BU
	clear
	echo -e "${RED}[+] Step 13: Installing additional network drivers...${NOCOLOR}"
	echo -e " "
	echo -e "${RED}[+] Installing the Realtek RTL88x2BU Wireless Network Driver ${NOCOLOR}"
	git clone https://github.com/morrownr/88x2bu-20210702.git
	cd 88x2bu-20210702
	cp /home/torbox/torbox/install/Network/install-rtl88x2bu.sh .
	chmod a+x install-rtl88x2bu.sh
	if [ ! -z "$CHECK_HD1" ] || [ ! -z "$CHECK_HD2" ]; then
		if uname -m | grep -q -E "arm64|aarch64"; then
			./ARM64_RPI.sh
		else
	 	./ARM_RPI.sh
 	fi
	fi
	./install-rtl88x2bu.sh
	cd ~
	rm -r 88x2bu-20210702
	sleep 2

	if [ "$STEP_BY_STEP" = "--step_by_step" ]; then
		echo ""
		read -n 1 -s -r -p $'\e[1;31mPlease press any key to continue... \e[0m'
		clear
	else
		sleep 10
	fi

fi

#14. Updating run/torbox.run
clear
echo -e "${RED}[+] Step 14: Configuring TorBox and update run/torbox.run...${NOCOLOR}"
echo -e "${RED}[+]          Update run/torbox.run${NOCOLOR}"
sed -i "s/^NAMESERVERS=.*/NAMESERVERS=${NAMESERVERS_ORIG}/g" ${RUNFILE}
sed -i "s/^GO_VERSION_64=.*/GO_VERSION_64=${GO_VERSION_64}/g" ${RUNFILE}
sed -i "s/^GO_VERSION=.*/GO_VERSION=${GO_VERSION}/g" ${RUNFILE}
sed -i "s|^GO_DL_PATH=.*|GO_DL_PATH=${GO_DL_PATH}|g" ${RUNFILE}
sed -i "s|^SNOWFLAKE_ORIGINAL=.*|SNOWFLAKE_ORIGINAL=${SNOWFLAKE_ORIGINAL}|g" ${RUNFILE}
sed -i "s|^SNOWFLAKE_USED=.*|SNOWFLAKE_USED=${SNOWFLAKE_USED}|g" ${RUNFILE}
sed -i "s|^VANGUARDS_USED=.*|VANGUARDS_USED=${VANGUARDS_USED}|g" ${RUNFILE}
sed -i "s/^VANGUARDS_COMMIT_HASH=.*/VANGUARDS_COMMIT_HASH=${VANGUARDS_COMMIT_HASH}/g" ${RUNFILE}
sed -i "s|^VANGUARD_LOG_FILE=.*|VANGUARD_LOG_FILE=${VANGUARDS_LOG_FILE}|g" ${RUNFILE}
sed -i "s|^WIRINGPI_USED=.*|WIRINGPI_USED=${WIRINGPI_USED}|g" ${RUNFILE}
sed -i "s|^FARS_ROBOTICS_DRIVERS=.*|FARS_ROBOTICS_DRIVERS=${FARS_ROBOTICS_DRIVERS}|g" ${RUNFILE}
sed -i "s/^FRESH_INSTALLED=.*/FRESH_INSTALLED=3/" ${RUNFILE}

if [ "$STEP_BY_STEP" = "--step_by_step" ]; then
 echo ""
 read -n 1 -s -r -p $'\e[1;31mPlease press any key to continue... \e[0m'
 clear
else
 sleep 10
fi

# 15. Adding the user torbox
clear
echo -e "${RED}[+] Step 15: Set up the torbox user...${NOCOLOR}"
echo -e "${RED}[+]          In this step the user \"torbox\" with the default${NOCOLOR}"
echo -e "${RED}[+]          password \"$DEFAULT_PASS\" is created.  ${NOCOLOR}"
echo ""
echo -e "${WHITE}[!] IMPORTANT${NOCOLOR}"
echo -e "${WHITE}    To use TorBox, you have to log in with \"torbox\"${NOCOLOR}"
echo -e "${WHITE}    and the default password \"$DEFAULT_PASS\"!!${NOCOLOR}"
echo -e "${WHITE}    Please, change the default passwords as soon as possible!!${NOCOLOR}"
echo -e "${WHITE}    The associated menu entries are placed in the configuration sub-menu.${NOCOLOR}"
echo ""
adduser --disabled-password --gecos "" torbox
echo -e "$DEFAULT_PASS\n$DEFAULT_PASS\n" |  passwd torbox
adduser torbox
adduser torbox netdev
# This is necessary for Nginx / TFS
(sudo chown torbox:torbox /var/www) 2> /dev/null
mv /root/* /home/torbox/
(mv /root/.profile /home/torbox/) 2> /dev/null
mkdir /home/torbox/openvpn
(rm .bash_history) 2> /dev/null
chown -R torbox:torbox /home/torbox/
if !  grep "# Added by TorBox" /etc/sudoers ; then
  printf "\n# Added by TorBox\ntorbox  ALL=(ALL) NOPASSWD: ALL\n" |  tee -a /etc/sudoers
  (visudo -c) 2> /dev/null
fi
cd /home/torbox/

if [ "$STEP_BY_STEP" = "--step_by_step" ]; then
	echo ""
	read -n 1 -s -r -p $'\e[1;31mPlease press any key to continue... \e[0m'
	clear
else
	sleep 10
fi

# 16. Setting/changing root password
clear
echo -e "${RED}[+] Step 16: Setting/changing the root password...${NOCOLOR}"
echo -e "${RED}[+]          For security reason, we will ask you now for a (new) root password.${NOCOLOR}"
echo ""
passwd

# 17. Finishing, cleaning and booting
sleep 10
clear
echo -e "${RED}[+] Step 17: We are finishing and cleaning up now!${NOCOLOR}"
echo -e "${RED}[+]          This will erase all log files and cleaning up the system.${NOCOLOR}"
echo ""
echo -e "${WHITE}[!] IMPORTANT${NOCOLOR}"
echo -e "${WHITE}    After this last step, TorBox has to be rebooted manually.${NOCOLOR}"
echo -e "${WHITE}    In order to do so type \"exit\" and log in with \"torbox\" and the default password \"$DEFAULT_PASS\"!! ${NOCOLOR}"
echo -e "${WHITE}    Then in the TorBox menu, you have to chose entry 14.${NOCOLOR}"
echo -e "${WHITE}    After rebooting, please, change the default passwords immediately!!${NOCOLOR}"
echo -e "${WHITE}    The associated menu entries are placed in the configuration sub-menu.${NOCOLOR}"
echo ""
read -n 1 -s -r -p $'\e[1;31mTo complete the installation, please press any key... \e[0m'
clear
echo -e "${RED}[+] Erasing big not usefull packages...${NOCOLOR}"
(rm -r debian-packages) 2> /dev/null
(rm -r WiringPi) 2> /dev/null
# Find the bigest space waster packages: dpigs -H
apt-get -y remove libgl1-mesa-dri texlive* lmodern
apt-get -y clean
apt-get -y autoclean
apt-get -y autoremove
echo -e "${RED}[+] Setting the timezone to UTC${NOCOLOR}"
timedatectl set-timezone UTC

echo -e "${RED}[+] Erasing ALL LOG-files...${NOCOLOR}"
echo -e "${RED}[+] Erasing ALL LOG-files...${NOCOLOR}"
echo " "
for logs in $(find /var/log -type f); do
  echo -e "${RED}[+]${NOCOLOR} Erasing $logs"
  rm $logs
  sleep 1
done
echo -e "${RED}[+]${NOCOLOR} Erasing History..."
#.bash_history is already deleted
history -c
# To start TACA notices.log has to be present
(sudo -u debian-tor touch /var/log/tor/notices.log) 2> /dev/null
(chmod -R go-rwx /var/log/tor/notices.log) 2> /dev/null
# To ensure the correct permissions
(sudo -u debian-tor touch /var/log/tor/vanguards.log) 2> /dev/null
(chmod -R go-rwx /var/log/tor/vanguards.log) 2> /dev/null
echo ""
echo -e "${RED}[+] Setting up the hostname...${NOCOLOR}"
# This has to be at the end to avoid unnecessary error messages
(hostnamectl set-hostname TorBox051) 2> /dev/null
(cp /etc/hosts /etc/hosts.bak) 2> /dev/null
(cp torbox/etc/hosts /etc/) 2> /dev/null
echo -e "${RED}[+] Copied /etc/hosts -- backup done${NOCOLOR}"
echo -e "${RED}[+] Rebooting...${NOCOLOR}"
sleep 3
if [ "$STEP_BY_STEP" = "--step_by_step" ]; then
	echo ""
	read -n 1 -s -r -p $'\e[1;31mPlease press any key to continue... \e[0m'
	clear
else
	sleep 10
fi
reboot
