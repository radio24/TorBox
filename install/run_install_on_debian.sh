#!/bin/bash
# shellcheck disable=SC2001,SC2004,SC2016,SC2059,SC2181

# This file is a part of TorBox, an easy to use anonymizing router based on Raspberry Pi.
# Copyright (C) 2024 radio24
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
# This script installs the newest version of TorBox on a clean Debian-based
# System (Tested with Bookworm).
#
# SYNTAX
# ./run_install.sh [-h|--help] [--randomize_hostname] [--select-tor] [--select-fork fork_owner_name] [--select-branch branch_name] [--on_a_cloud] [--torbox_mini] [--step_by_step] [--continue_with_step]
#
# The -h or --help option shows the help screen.
#
# The --randomize_hostname option is helpful for people in highly authoritarian
# countries to avoid their ISP seeing their default hostname. The ISP can
# see and even block your hostname. When a computer connects to an ISP's
# network, it sends a DHCP request that includes the hostname.
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
# The --on_a_cloud option has to be used if you install TorBox on a cloud or
# as a cloud service. This will enable/disable some features.
#
# The --torbox_mini option creates the TorBox mini on a Raspberry Pi Zero 2 W.
# Important: # Before the script can be started with this option, the Raspberry
# Pi OS lite 32-bit must be installed on the SD card running in the Raspberry Pi Zero 2 W.
#
# The --step_by_step option execute the installation step by step, which
# is ideal to find bugs.
#
# The --continue_with_step In case of an aborted installation, this option
# allows to continue the installation with a certain step, skipping all other
# steps before.
#
# IMPORTANT
# Start it as root
#
##########################################################

# Table of contents for this script:
#  0. Checking for Internet connection
#  1. Adjusting time, if needed
#  2. Updating the system
#  3. Installing all necessary packages
#  4. Installing Tor
#  5. Configuring Tor with its pluggable transports
#  6. Installing Snowflake
#  7. Re-checking Internet connectivity
#  8. Downloading and installing the latest version of TorBox
#  9. Installing all configuration files
# 10. Disabling Bluetooth
# 11. Configure the system services
# 12. Updating run/torbox.run
# 13. TorBox mini specific configurations
# 14. Adding and implementing the user torbox
# 15. Setting/changing root password
# 16. Finishing, cleaning and booting

##########################################################

##### SET VARIABLES ######
#
# Set the the variables for the menu
MENU_WIDTH=80
MENU_WIDTH_REDUX=60
MENU_HEIGHT_25=25
MENU_HEIGHT_20=20
MENU_HEIGHT_10=10

# Colors
RED='\033[1;31m'
YELLOW='\033[1;93m'
NOCOLOR='\033[0m'

# What main version is installed
DEBIAN_VERSION=$(sed 's/\..*//' /etc/debian_version)

# Where is the config.txt?
if [ -f "/boot/dietpi/.version" ]; then
	CONFIGFILE="/boot/config.txt"
elif [ "$DEBIAN_VERSION" -gt "11" ]; then
  CONFIGFILE="/boot/firmware/config.txt"
else
  CONFIGFILE="/boot/config.txt"
fi

# Where is the cmdline.txt?
if [ -f "/boot/dietpi/.version" ]; then
	CMDLINEFILE="/boot/cmdline.txt"
elif [ "$DEBIAN_VERSION" -gt "11" ]; then
  CMDLINEFILE="/boot/firmware/cmdline.txt"
else
  CMDLINEFILE="/boot/cmdline.txt"
fi

# Changes in the variables below (until the ####### delimiter) will be saved
# into run/torbox.run and used after the installation (we not recommend to
# change the values until zou precisely know what you are doing)
# Public nameserver used to circumvent cheap censorship
NAMESERVERS="1.1.1.1,1.0.0.1,8.8.8.8,8.8.4.4"

# Default hostname
HOSTNAME="TorBox054"

# For go
GO_DL_PATH="https://go.dev/dl/"
GO_PROGRAM="/usr/local/go/bin/go"

# Release Page of the official Tor repositories
TOR_RELEASE="official"
TORURL="https://gitlab.torproject.org/tpo/core/tor/-/tags"
TORPATH_TO_RELEASE_TAGS="/tpo/core/tor/-/tags/tor-"
TOR_HREF_FOR_SED="<a class=\".*\" href=\"/tpo/core/tor/-/tags/tor-"
TORURL_DL_PARTIAL="https://dist.torproject.org/tor-"

# Snowflake repositories
SNOWFLAKE_ORIGINAL_WEB="https://gitlab.torproject.org/tpo/anti-censorship/pluggable-transports/snowflake"
# Only until version 2.6.1
SNOWFLAKE_PREVIOUS_USED="https://github.com/syphyr/snowflake"
# Version 2.8.0+
SNOWFLAKE_USED="https://github.com/tgragnato/snowflake"

# OBFS4 repository
OBFS4PROXY_USED="https://salsa.debian.org/pkg-privacy-team/obfs4proxy.git"

# Wiringpi - DEBIAN / UBUNTU SPECIFIC
WIRINGPI_USED="https://github.com/WiringPi/WiringPi.git"

# Connectivity check
CHECK_URL1="debian.org"
CHECK_URL2="google.com"

# Default password
DEFAULT_PASS="CHANGE-IT"

# Catching command line options
OPTIONS=$(getopt -o h --long help,randomize_hostname,select-tor,select-fork:,select-branch:,on_a_cloud,torbox_mini,step_by_step,continue_with_step: -n 'run-install' -- "$@")
if [ $? != 0 ] ; then echo "Syntax error!"; echo ""; OPTIONS="-h" ; fi
eval set -- "$OPTIONS"

SELECT_TOR=
SELECT_BRANCH=
TORBOXMENU_BRANCHNAME=
TORBOXMENU_FORKNAME=
ON_A_CLOUD=
STEP_BY_STEP=
while true; do
  case "$1" in
    -h | --help )
			echo "Copyright (C) 2024 radio24, nyxnor (Contributor)"
      echo "Syntax : run_install_debian.sh [-h|--help] [--randomize_hostname] [--select-tor] [--select-fork fork_name] [--select-branch branch_name] [--on_a_cloud] [--torbox_mini] [--step_by_step] [--continue_with_step]"
			echo "Options: -h, --help     : Shows this help screen ;-)"
			echo "         --randomize_hostname"
			echo "                        : Randomizes the hostname to prevent ISPs to see the default"
			echo "         --select-tor   : Let select a specific tor version (default: newest stable version)"
			echo "         --select-fork fork_owner_name"
			echo "                        : Let select a specific fork from a GitHub user (fork_owner_name)"
			echo "         --select-branch branch_name"
			echo "                        : Let select a specific TorBox branch (default: master)"
			echo "         --on_a_cloud   : Installing on a cloud or as a cloud service"
      echo "         --torbox_mini  : Installing TorBox mini on a Raspberry Pi Zero 2 W"
			echo "         --step_by_step : Executes the installation step by step"
      echo "         --continue_with_step"
      echo "                        : Continue the installation with a certain step"
			echo ""
			echo "For more information visit https://www.torbox.ch/ or https://github.com/radio24/TorBox"
			exit 0
	  ;;
		--randomize_hostname ) RANDOMIZE_HOSTNAME=1; shift ;;
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
		--on_a_cloud ) ON_A_CLOUD="--on_a_cloud"; shift ;;
    --torbox_mini ) TORBOX_MINI="--torbox_mini"; shift ;;
    --step_by_step ) STEP_BY_STEP="--step_by_step"; shift ;;
    --continue_with_step )
      # shellcheck disable=SC2034
      CONTINUE_WITH_STEP="--continue_with_step"
      [ ! -z "$2" ] && STEP_NUMBER="$2"
      shift 2
    ;;
		-- ) shift; break ;;
		* ) break ;;
  esac
done

[ -z "$STEP_NUMBER" ] && STEP_NUMBER="1"

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

# New function re-connect
# This function tries to restor a connection to the Internet after failing to install a package
# Syntax: re-connect()
re-connect()
{
	(cp /etc/resolv.conf /etc/resolv.conf.bak) 2>&1
	(printf "$RESOLVCONF" | tee /etc/resolv.conf) 2>&1
	sleep 5
	# On some Debian systems, wget is not installed, yet
	ping -c 1 -q $CHECK_URL1 >&/dev/null
	OCHECK=$?
	echo ""
	if [ $OCHECK -eq 0 ]; then
	  echo -e "${RED}[+]         Yes, we have Internet! :-)${NOCOLOR}"
	else
	  echo -e "${YELLOW}[!]        Hmmm, no we don't have Internet... :-(${NOCOLOR}"
	  echo -e "${RED}[+]        We will check again in about 30 seconds...${NOCOLOR}"
	  sleep 30
	  echo ""
	  echo -e "${RED}[+]         Trying again...${NOCOLOR}"
	  ping -c 1 -q $CHECK_URL2 >&/dev/null
	  if [ $? -eq 0 ]; then
	    echo -e "${RED}[+]         Yes, now, we have an Internet connection! :-)${NOCOLOR}"
	  else
	    echo -e "${YELLOW}[!]         Hmmm, still no Internet connection... :-(${NOCOLOR}"
	    echo -e "${RED}[+]         We will try to catch a dynamic IP adress and check again in about 30 seconds...${NOCOLOR}"
	    (dhclient -r) 2>&1
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
				echo -e "${RED}[+]         Please, try to fix the problem and re-run the installation!${NOCOLOR}"
				exit 1
	    fi
	  fi
	fi
}

# Modified to check, if the packages was installed
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
	 	echo -e "${RED}[+]         Installing ${YELLOW}$packagename${NOCOLOR}"
	 	echo ""
	 	apt-get -y install $packagename
		check=$(dpkg-query -s $packagename | grep "Status" | grep -o "installed")
		if [ "$check" == "installed" ]; then check_installed=1
		else re-connect
		fi
	done
 done
}

# This function downloads and updates tor
# Syntax download_and_compile_tor
# Used predefined variables: $download_tor_url $filename RED YELLOW NOCOLOR TORCONNECT
download_and_compile_tor()
{
	# Difference to the update-function - we cannot use torsocks yet
	wget $download_tor_url
	DLCHECK=$?
	if [ $DLCHECK -eq 0 ]; then
		echo -e "${RED}[+]         Successfully downloaded the selected tor version... ${NOCOLOR}"
		tar xzf $filename
		cd $directoryname
		echo -e "${RED}[+]         Starting configuring, compiling and installing... ${NOCOLOR}"
		# Give it a touch of git (without these lines the compilation will break with a git error)
		git init
		git add -- *
		git config --global user.name "torbox"
		git config --global user.email "torbox@localhost"
		git commit -m "Initial commit"
		# Don't use ./autogen.sh
		if [ -f "autogen.sh" ]; then sh autogen.sh; fi
		./configure
		make
		make install
		cd
		rm -r tor-*
		systemctl stop tor
		systemctl mask tor
		# Both tor services have to be masked to block outgoing tor connections
		systemctl mask tor@default.service
		systemctl stop tor
		systemctl mask tor
		# Both tor services have to be masked to block outgoing tor connections
		systemctl mask tor@default.service
	else
		echo -e ""
		echo -e "${YELLOW}[!] COULDN'T DOWNLOAD TOR!${NOCOLOR}"
		echo -e "${RED}[+] The $TOR_RELEASE Tor repositories may be blocked or offline!${NOCOLOR}"
		echo -e "${RED}[+] Please try again later and if the problem persists, please report it${NOCOLOR}"
		echo -e "${RED}[+] to ${YELLOW}anonym@torbox.ch${RED}. ${NOCOLOR}"
		echo ""
		read -n 1 -s -r -p $'\e[1;31mPlease press any key to continue... \e[0m'
		clear
		exit 0
	fi
}

# select_and_install_tor()
# Syntax select_and_install_tor
# Used predefined variables: RED, YELLOW, NOCOLOR, SELECT_TOR, URL, TORURL_DL_PARTIAL
# With this function change/update of tor from a list of versions is possible
# IMPORTANT: This function is different from the one in the update script!
select_and_install_tor()
{
  # Difference to the update-function - we cannot use torsocks yet
	echo -e "${RED}[+]         Can we access the $TOR_RELEASE Tor repositories on GitHub?${NOCOLOR}"
	#-m 6 must not be lower, otherwise it looks like there is no connection! ALSO IMPORTANT: THIS WILL NOT WORK WITH A CAPTCHA!
	OCHECK=$(curl -m 6 -s $TORURL)
	if [ $? == 0 ]; then
		echo -e "${YELLOW}[!]         YES!${NOCOLOR}"
		echo ""
	else
		echo -e "${YELLOW}[!]         NO!${NOCOLOR}"
		echo -e ""
		echo -e "${RED}[+] The $TOR_RELEASE Tor repositories may be blocked or offline!${NOCOLOR}"
		echo -e "${RED}[+] Please try again later and if the problem persists, please report it${NOCOLOR}"
		echo -e "${RED}[+] to ${YELLOW}anonym@torbox.ch${RED}. ${NOCOLOR}"
		echo ""
		echo -e "${RED}[+] However, an older version of tor is already installed from${NOCOLOR}"
		echo -e "${RED}    the repository.${NOCOLOR}"
		read -n 1 -s -r -p $'\e[1;31mPlease press any key to continue... \e[0m'
		clear
	fi
  echo -e "${RED}[+]         Fetching possible tor versions... ${NOCOLOR}"
	if [ "$TOR_RELEASE" == "official" ]; then
		readarray -t torversion_versionsorted < <(curl --silent $TORURL | grep $TORPATH_TO_RELEASE_TAGS | sed -e "s|$TOR_HREF_FOR_SED||g" | sed -e "s/\">.*//g" | sed -e "s/ //g" | sort -r)
	elif [ "$TOR_RELEASE" == "unofficial" ]; then
		# shellcheck disable=SC2153
		readarray -t torversion_versionsorted < <(curl --silent $TORURL | grep $TORPATH_TO_RELEASE_TAGS | sed -e "s|$TOR_HREF_FOR_SED1||g" | sed -e "s|$TOR_HREF_FOR_SED2||g" | sed -e "s/<a//g" | sed -e "s/\">//g" | sed -e "s/ //g" | sort -r)
	fi

  #How many tor version did we fetch?
	number_torversion=${#torversion_versionsorted[*]}
	if [ $number_torversion = 0 ]; then
		echo -e ""
		echo -e "${YELLOW}[!] COULDN'T FIND ANY TOR VERSIONS${NOCOLOR}"
		echo -e "${RED}[+] The $TOR_RELEASE Tor repositories may be blocked or offline!${NOCOLOR}"
		echo -e "${RED}[+] Please try again later and if the problem persists, please report it${NOCOLOR}"
		echo -e "${RED}[+] to ${YELLOW}anonym@torbox.ch${RED}. ${NOCOLOR}"
		echo ""
		echo -e "${RED}[+] However, an older version of tor is already installed from${NOCOLOR}"
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
			echo -e "${YELLOW}Choose a tor version (alpha versions are not recommended!):${NOCOLOR}"
    	echo ""
    	for (( i=0; i<$number_torversion; i++ ))
    	do
      	menuitem=$((i+1))
      	echo -e "${RED}$menuitem${NOCOLOR} - ${torversion_versionsorted_new[$i]}"
    	done
    	echo ""
    	read -r -p $'\e[1;93mWhich tor version (number) would you like to use? -> \e[0m'
    	echo
    	if [[ $REPLY =~ ^[1234567890]$ ]]; then
				if [ $REPLY -gt 0 ] && [ $((REPLY-1)) -le $number_torversion ]; then
        	CHOICE_TOR=$((REPLY-1))
        	clear
        	echo -e "${RED}[+]         Download the selected tor version...... ${NOCOLOR}"
        	version_string="$(<<< ${torversion_versionsorted_new[$CHOICE_TOR]} sed -e 's/ //g')"
        	download_tor_url="$TORURL_DL_PARTIAL$version_string.tar.gz"
        	filename="tor-$version_string.tar.gz"
					directoryname="tor-$version_string"
					download_and_compile_tor
				else
					clear
					echo -e "${YELLOW}[!] WRONG SELECTION!${NOCOLOR}"
	       	echo -e "${RED}[+] Restart the installation and try again! ${NOCOLOR}"
					echo ""
					sleep 5
					clear
					exit 0
				fi
    	else
				clear
				echo -e "${YELLOW}[!] WRONG SELECTION!${NOCOLOR}"
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
					download_tor_url="$TORURL_DL_PARTIAL$version_string.tar.gz"
        	filename="tor-$version_string.tar.gz"
					directoryname="tor-$version_string"
					i=$number_torversion
				fi
    	done
			echo ""
			echo -e "${RED}[+]         Selected tor version ${YELLOW}$version_string${RED}...${NOCOLOR}"
			echo -e "${RED}[+]         Download the selected tor version...... ${NOCOLOR}"
			download_and_compile_tor
		fi
	fi
}

###### DISPLAY THE INTRO ######
clear
if (whiptail --title "TorBox Installation for Debian-based systems (scroll down!)" --scrolltext --yes-button "INSTALL" --no-button "STOP!" --yesno "         WELCOME TO THE INSTALLATION OF TORBOX ON A DEBIAN-BASED SYSTEM\n\nPlease make sure that you started this script as root with ./run_install_debian in your home directory.\n\nThe installation process runs almost without user interaction. However, macchanger will ask for enabling an autmatic change of the MAC address - REPLY WITH NO!\n\nTHIS INSTALLATION WILL CHANGE/DELETE THE CURRENT CONFIGURATION!\n\nDuring the installation, we are going to set up the user \"torbox\" with the default password \"$DEFAULT_PASS\". This user name and the password will be used for logging into your TorBox and to administering it. Please, change the default passwords as soon as possible (the associated menu entries are placed in the configuration sub-menu).\n\nIMPORTANT\nInternet connectivity is necessary for the installation.\n\nAVAILABLE OPTIONS\n-h, --help     : shows a help screen\n--randomize_hostname\n  	  	   : randomize the hostname to prevent ISPs to see the default\n--select-tor   : select a specific tor version\n--select-fork fork_owner_name\n  	  	   : select a specific fork from a GitHub user\n--select-branch branch_name\n  	  	   : select a specific TorBox branch\n--on_a_cloud   : installing on a cloud or as a cloud service.\n--torbox_mini  : installing TorBox mini on a Raspberry Pi Zero 2 W.\n--step_by_step : executes the installation step by step.\n--continue_with_step\n  	  	   :continue the installation with a certain step.\n\nIn case of any problems, contact us on https://www.torbox.ch." $MENU_HEIGHT_25 $MENU_WIDTH); then
	:
else
	clear
	exit
fi

# Implementation of optional randomization of the hostname to prevent ISPs to see the default
if [ -z "$RANDOMIZE_HOSTNAME" ]; then
	if (whiptail --title "TorBox Installation for Debian-based systems" --defaultno --no-button "USE DEFAULT" --yes-button "CHANGE!" --yesno "In highly authoritarian countries connecting the tor network could be seen as suspicious. The default hostname of TorBox is \"TorBox<nnn>\" (<nnn> representing the version).\n\nWhen a computer connects to an ISP's network, it sends a DHCP request that includes the hostname. Because ISPs can see, log and even block hostnames, setting another hostname or using a randomized hostname may be preferable.\n\nWe recommend randomizing the hostname in highly authoritarian countries or if you think that your ISP blocks tor related network traffic.\n\nDo you want to use the DEFAULT hostname or to CHANGE it?" $MENU_HEIGHT_20 $MENU_WIDTH); then
		if (whiptail --title "TorBox Installation for Debian-based systems" --no-button "SET HOSTNAME" --yes-button "RANDOMIZE HOSTNAME" --yesno "You can set a specific hostname or use a randomized one. Please choose..." $MENU_HEIGHT_10 $MENU_WIDTH); then
			# shellcheck disable=SC2002
			HOSTNAME=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 10 | head -n 1)
		else
			HOSTNAME=$(whiptail --title "TorBox Installation for Debian-based systems" --inputbox "\nEnter the hostname:" $MENU_HEIGHT_10 $MENU_WIDTH_REDUX 3>&1 1>&2 2>&3)
			if [[ $HOSTNAME != *[0123456789ABCDEFGHIJKLMNOPQRSTUVWXZYabcdefghijklmnopqrstuvwxzy-]* ]]; then
				HOSTNAME=$(tr -dc 'a-zA-Z0-9' <<<$HOSTNAME)
			fi
			if ${#HOSTNAME} -gt 64 ; then
				HOSTNAME=$(head -c 64 <<<$HOSTNAME)
			fi
		fi
	fi
else
	# shellcheck disable=SC2002
	HOSTNAME=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 10 | head -n 1)
fi

# 0. Checking for Internet connection
clear
echo -e "${RED}[+] Step 0: Do we have Internet?${NOCOLOR}"
echo -e "${RED}[+]         Nevertheless, to be sure, let's add some open nameservers!${NOCOLOR}"
re-connect
# NEW v.0.5.4-post
# Avahi can lead loosing the IP address
# See here: https://www.heise.de/ratgeber/Raspi-mit-Debian-verliert-Internet-Verbindung-9998575.html
systemctl mask avahi-daemon
systemctl disable avahi-daemon
systemctl stop avahi-daemon
systemctl mask avahi-daemon.socket
systemctl disable avahi-daemon.socket
systemctl stop avahi-daemon.socket

if [ "$STEP_NUMBER" -le "1" ]; then
  # 1. Adjusting time, if needed
  clear
  if [ -f "/etc/timezone" ]; then
	  mv /etc/timezone /etc/timezone.bak
	  (printf "Etc/UTC" | tee /etc/timezone) 2>&1
  fi
  timedatectl set-timezone UTC
  clear
  echo -e "${YELLOW}[!] SYSTEM-TIME CHECK${NOCOLOR}"
  echo -e "${RED}[!] Tor needs a correctly synchronized time.${NOCOLOR}"
  echo -e "${RED}    The system should display the current UTC time:${NOCOLOR}"
  echo
  echo -e "             Date: ${YELLOW}$(date '+%Y-%m-%d')${NOCOLOR}"
  echo -e "             Time: ${YELLOW}$(date '+%H:%M')${NOCOLOR}"
  echo
  echo -e "${RED}    You can find the correct time here: ${YELLOW}https://time.is/UTC${NOCOLOR}"
  echo
  while true
  do
	  read -r -p $'\e[1;31m    Do you want to adjust the system time [Y/n]? -> \e[0m'
	  # The following line is for the prompt to appear on a new line.
	  if [[ $REPLY =~ ^[YyNn]$ ]] ; then
		  echo
		  echo
		  break
	  fi
  done
  if [[ $REPLY =~ ^[Yy]$ ]] ; then
	  echo ""
	  read -r -p $'\e[1;31mPlease enter the date (YYYY-MM-DD): \e[0m' DATESTRING
	  echo ""
	  echo -e "${RED}Please enter the UTC time (HH:MM)${NOCOLOR}"
	  read -r -p $'You can find the correct time here: https://time.is/UTC: ' TIMESTRING
	  # Check and set date
	  if [[ $DATESTRING =~ ^[1-2]{1}[0-9]{3}-[0-9]{2}-[0-9]{2}$ ]]; then
		  echo ""
		  date -s "$DATESTRING"
		  echo -e "${RED}[+] Date set successfully!${NOCOLOR}"
		  if [[ $TIMESTRING =~ ^[0-9]{2}:[0-9]{2}$ ]]; then
			  echo ""
			  date -s "$TIMESTRING"
			  echo -e "${RED}[+] Time set successfully!${NOCOLOR}"
			  sleep 5
			  clear
		  else
			  echo ""
			  echo -e "${YELLOW}[!] INVALIDE TIME FORMAT!${NOCOLOR}"
			  echo ""
			  read -n 1 -s -r -p $'\e[1;31mPlease press any key to continue... \e[0m'
			  clear
		  fi
	  else
		  echo ""
		  echo -e "${YELLOW}[!] INVALIDE DATE FORMAT!${NOCOLOR}"
		  echo ""
		  read -n 1 -s -r -p $'\e[1;31mPlease press any key to continue... \e[0m'
		  clear
	  fi
  fi
fi

if [ "$STEP_NUMBER" -le "2" ]; then
  # 2. Updating the system
  clear
  echo -e "${RED}[+] Step 2: Updating the system...${NOCOLOR}"
  # Using backport for go
  if grep "^# deb http://deb.debian.org/debian bullseye-backports main" /etc/apt/sources.list ; then sed -i "s'# deb http://deb.debian.org/debian bullseye-backports main'deb http://deb.debian.org/debian bullseye-backports main'g" /etc/apt/sources.list ; fi
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
fi

if [ "$STEP_NUMBER" -le "3" ]; then
  # 3. Installing all necessary packages
  clear
  echo -e "${RED}[+] Step 3: Installing all necessary packages....${NOCOLOR}"
  # Necessary packages for Debian systems (not necessary with Raspberry Pi OS)
  # NEW v.0.5.4 Installing resolvconf will overwrite resolv.conf
  check_install_packages "resolvconf"
  sleep 3
  (printf "$RESOLVCONF" | tee /etc/resolv.conf) 2>&1
  sleep 5
  check_install_packages "wget curl gnupg net-tools unzip sudo rfkill resolvconf"
  # Installation of standard packages
	if [ "$TORBOX_MINI" == "--torbox_mini" ]; then
		check_install_packages "hostapd isc-dhcp-server usbmuxd dnsmasq dnsutils tcpdump iftop vnstat debian-goodies apt-transport-https dirmngr imagemagick tesseract-ocr ntpdate screen git openvpn ppp nyx apt-transport-tor qrencode nginx basez iptables ipset macchanger openssl ca-certificates lshw libjpeg-dev ifupdown"
	else
		check_install_packages "hostapd isc-dhcp-server usbmuxd dnsmasq dnsutils tcpdump iftop vnstat debian-goodies apt-transport-https dirmngr imagemagick tesseract-ocr ntpdate screen git openvpn ppp dkms nyx apt-transport-tor qrencode nginx basez iptables ipset macchanger openssl ca-certificates lshw iw libjpeg-dev ifupdown"
	fi
	# Installation of developer packages - THIS PACKAGES ARE NECESSARY FOR THE COMPILATION OF TOR!! Without them, tor will disconnect and restart every 5 minutes!!
  check_install_packages "build-essential automake libevent-dev libssl-dev asciidoc bc devscripts dh-apparmor libcap-dev liblzma-dev libsystemd-dev libzstd-dev quilt pkg-config zlib1g-dev"
  # IMPORTANT tor-geoipdb installs also the tor package
  check_install_packages "tor-geoipdb"
	# NEW v.0.5.4-post: DietPi support
	if [ -f "/boot/dietpi/.version" ] ; then
		check_install_packages "less torsocks"
	fi
	# Install dbus, if not already installed (dietpi)
	DBUS_STATUS=$(systemctl is-active hostapd)
	if [ "$DBUS_STATUS" = "inactive" ]; then
		check_install_packages "dbus dbus-user-session systemd"
		systemctl restart dbus.service
	fi
  systemctl stop tor
  systemctl mask tor
  # Both tor services have to be masked to block outgoing tor connections
  systemctl mask tor@default.service
  # An old version of easy-rsa was available by default in some openvpn packages
  if [[ -d /etc/openvpn/easy-rsa/ ]]; then
	  rm -rf /etc/openvpn/easy-rsa/
  fi

  if [ "$STEP_BY_STEP" = "--step_by_step" ]; then
	  echo ""
	  read -n 1 -s -r -p $'\e[1;31mPlease press any key to continue... \e[0m'
	  clear
  fi

  #Install wiringpi
  clear
  echo -e "${RED}[+] Step 3: Installing all necessary packages....${NOCOLOR}"
  echo ""
  echo -e "${RED}[+]         Installing ${YELLOW}WiringPi${NOCOLOR}"
  echo ""
  cd
  git clone $WIRINGPI_USED
  DLCHECK=$?
  if [ $DLCHECK -eq 0 ]; then
	  cd WiringPi
	  ./build
	  cd
	  rm -r WiringPi
	  if [ "$STEP_BY_STEP" = "--step_by_step" ]; then
		  echo ""
		  read -n 1 -s -r -p $'\e[1;31mPlease press any key to continue... \e[0m'
		  clear
	  fi
  else
	  echo ""
	  echo -e "${YELLOW}[!] COULDN'T CLONE THE WIRINGPI REPOSITORY!${NOCOLOR}"
	  echo -e "${RED}[+] The WiringPi repository may be blocked or offline!${NOCOLOR}"
	  echo -e "${RED}[+] Please try again later and if the problem persists, please report it${NOCOLOR}"
	  echo -e "${RED}[+] to ${YELLOW}anonym@torbox.ch${RED}. ${NOCOLOR}"
	  echo ""
	  read -n 1 -s -r -p $'\e[1;31mPlease press any key to continue... \e[0m'
	  clear
  fi

  # Additional installations for Python
  clear
  echo -e "${RED}[+] Step 3: Installing all necessary packages....${NOCOLOR}"
  echo ""
  echo -e "${RED}[+]         Link \"python\" to \"python3\"${NOCOLOR}"
  ln /usr/bin/python3 /usr/bin/python
  echo -e "${RED}[+]         Installing ${YELLOW}Python modules${NOCOLOR}"
  echo ""

  # For Debian 12 needed
  PYTHON_LIB_PATH=$(python3 -c "import sys; print(sys.path)" | cut -d ' ' -f3 | sed "s/'//g" | sed "s/,//g" | sed "s/.zip//g" | sed "s/ //g")
  if [ -f "$PYTHON_LIB_PATH/EXTERNALLY-MANAGED" ] ; then
    rm "$PYTHON_LIB_PATH/EXTERNALLY-MANAGED"
  fi

	# Install and check Python requirements
	# How to deal with Pipfile, Pipfile.lock and requirements.txt:
	# 1. Check the Pipfile --> is the package in the list?
	# 2. Execute: pipenv lock (this should only be done on a test system not during installation or to prepare an image!)
	# 3. Execute: pipenv requirements >requirements.txt
	# 4. Execute: sudo pip install -r requirements (this will update outdated packages)
	# 5. Check the list of outdated packages: pip list --outdated
	# Remark: we install all Python libraries globally because otherwice some programs troubling to find the library in the local environment
	# NEW v.0.5.4: Some Python libraries have to be installed manually
	# bcrypt needs rust, which waste 1 Gb of space.
	# check_install_packages "python3-pip python3-pil python3-opencv python3-bcrypt python3-numpy"
	# NEW v.0.5.4-post: python3-opencv doesn't seem to be necessary
	check_install_packages "python3-pip python3-pil python3-bcrypt python3-numpy"
	cd
	pip install --upgrade pip
	pip3 install pipenv
	# bcrypt needs rust, which waste 1 Gb of space, but the python3- package is too old
	pip install --only-binary=:all: cryptography
	pip install --only-binary=:all: pillow
	# Don't try to create Pipfile.lock during the installation process. It is too slow and complicated!
	# The best way is to build it on a cloud installation
	#wget --no-cache https://raw.githubusercontent.com/$TORBOXMENU_FORKNAME/TorBox/$TORBOXMENU_BRANCHNAME/Pipfile
	#pipenv lock -v
	wget --no-cache https://raw.githubusercontent.com/$TORBOXMENU_FORKNAME/TorBox/$TORBOXMENU_BRANCHNAME/Pipfile.lock
	pipenv requirements >requirements.txt
	# If the creation of requirements.txt failes then use the (most probably older) one from our repository
	# wget --no-cache https://raw.githubusercontent.com/$TORBOXMENU_FORKNAME/TorBox/$TORBOXMENU_BRANCHNAME/requirements.txt
	sed -i "/^cryptography==.*/d" requirements.txt
	sed -i "/^pip==.*/d" requirements.txt
	sed -i "/^pillow==.*/d" requirements.txt
	sed -i "s/^typing-extensions==/typing_extensions==/g" requirements.txt
	re-connect
  pip3 install -r requirements.txt
  sleep 5
  clear
  echo -e "${YELLOW}Following Python modules are installed:${NOCOLOR}"
	if [ -f "requirements.failed" ]; then rm requirements.failed; fi
  REPLY="Y"
  while [ "$REPLY" == "Y" ] || [ "$REPLY" == "y" ]; do
	  REPLY=""
		# NEW v.0.5.4
		# grep -v '^\s*$ filters out empty lines or lines containing only whitespace.
		# tail -n +2 will skipp the first line
		readarray -t REQUIREMENTS < <(grep -v '^\s*$' requirements.txt | tail -n +2)
	  for REQUIREMENT in "${REQUIREMENTS[@]}"; do
			# NEW v.0.5.4
			if grep "==" <<< $REQUIREMENT ; then REQUIREMENT=$(sed s"/==.*//" <<< $REQUIREMENT); fi
		  VERSION=$(pip3 freeze | grep -i $REQUIREMENT== | sed "s/${REQUIREMENT}==//i" 2>&1)
  	  echo -e "${RED}${REQUIREMENT} version: ${YELLOW}$VERSION${NOCOLOR}"
		  if [ -z "$VERSION" ]; then
			  # shellcheck disable=SC2059
			  (printf "$REQUIREMENT\n" | tee -a requirements.failed) >/dev/null 2>&1
		  fi
	  done
		if [ -f "requirements.failed" ]; then
		  echo ""
		  echo -e "${YELLOW}Not all required Python modules could be installed!${NOCOLOR}"
		  read -r -p $'\e[1;93mWould you like to try it again [Y/n]? -> \e[0m'
		  if [[ $REPLY =~ ^[YyNn]$ ]] ; then
			  if [ "$REPLY" == "Y" ] || [ "$REPLY" == "y" ]; then
				  pip3 install -r requirements.failed
				  sleep 5
				  rm requirements.failed
				  unset REQUIREMENTS
				  clear
			  fi
		  fi
	  fi
  done

  if [ "$STEP_BY_STEP" = "--step_by_step" ]; then
	  echo ""
	  read -n 1 -s -r -p $'\e[1;31mPlease press any key to continue... \e[0m'
	  clear
  fi

  # Additional installation for go
  clear
  echo -e "${RED}[+] Step 3: Installing all necessary packages....${NOCOLOR}"
  echo ""
  echo -e "${RED}[+]         Installing ${YELLOW}go${NOCOLOR}"
  echo ""

  # New way to download the current version of go
  if uname -m | grep -q -E "arm64|aarch64"; then PLATFORM="linux-arm64"
  elif uname -m | grep -q -E "x86_64"; then PLATFORM="linux-amd64"
  else PLATFORM="linux-armv6l"
  fi

  # Fetch the filename of the latest go version
  GO_FILENAME=$(curl -s "$GO_DL_PATH" | grep "$PLATFORM" | grep -m 1 'class=\"download\"' | cut -d'"' -f6 | cut -d'/' -f3)
  wget --no-cache "$GO_DL_PATH$GO_FILENAME"
  DLCHECK=$?

	# If the download failed, install the package from the distribution
  if [ "$DLCHECK" != "0" ] ; then
	  echo ""
	  echo -e "${YELLOW}[!] COULDN'T DOWNLOAD GO (for $PLATFORM)!${NOCOLOR}"
	  echo -e "${RED}[+] The Go repositories may be blocked or offline!${NOCOLOR}"
	  echo -e "${RED}[+] We try to install the distribution package, instead.${NOCOLOR}"
	  echo
	  if [ "$STEP_BY_STEP" = "--step_by_step" ]; then
		  echo ""
		  read -n 1 -s -r -p $'\e[1;31mPlease press any key to continue... \e[0m'
		  clear
	  else
		  sleep 10
	  fi
	  re-connect
	  if grep "^deb http://deb.debian.org/debian bullseye-backports main" /etc/apt/sources.list ; then
		  apt-get -y -t bullseye-backports install golang
	  else
		  apt-get -y install golang
		  GO_PROGRAM="/usr/local/go/bin/go"
		  if [ -f $GO_PROGRAM ]; then
			  GO_VERSION_NR=$($GO_PROGRAM version | cut -d ' ' -f3 | cut -d '.' -f2)
		  else
			  GO_PROGRAM=go
			  #This can lead to command not found - ignore it
			  GO_VERSION_NR=$($GO_PROGRAM version | cut -d ' ' -f3 | cut -d '.' -f2)
		  fi
		  if [ "$GO_VERSION_NR" -lt "17" ]; then
			  echo ""
			  echo -e "${YELLOW}[!] TOO LOW GO VERSION NUMBER${NOCOLOR}"
			  echo -e "${RED}[+] At least go version 1.17 is needed to compile pluggable ${NOCOLOR}"
			  echo -e "${RED}[+] transports. We tried several ways to get a newer go version, ${NOCOLOR}"
			  echo -e "${RED}[+] but failed. Please, try it again later or install go manually. ${NOCOLOR}"
			  echo ""
			  exit 1
	  	fi
	  fi
  else
	  tar -C /usr/local -xzvf $GO_FILENAME
	  rm $GO_FILENAME
  fi

	# What if .profile doesn't exist?
  if [ -f ".profile" ]; then
	  if ! grep "Added by TorBox (001)" .profile ; then
		  printf "\n# Added by TorBox (001)\nexport PATH=$PATH:/usr/local/go/bin\n" | tee -a .profile
	  fi
  else
	  printf "\n# Added by TorBox (001)\nexport PATH=$PATH:/usr/local/go/bin\n" | tee -a .profile
  fi
  export PATH=$PATH:/usr/local/go/bin

  if [ "$STEP_BY_STEP" = "--step_by_step" ]; then
	  echo ""
	  read -n 1 -s -r -p $'\e[1;31mPlease press any key to continue... \e[0m'
	  clear
  else
	  sleep 10
  fi
fi

if [ "$STEP_NUMBER" -le "4" ]; then
  # 4. Installing tor
  clear
  echo -e "${RED}[+] Step 4: Installing Tor...${NOCOLOR}"
	re-connect
  select_and_install_tor

  if [ "$STEP_BY_STEP" = "--step_by_step" ]; then
	  echo ""
	  read -n 1 -s -r -p $'\e[1;31mPlease press any key to continue... \e[0m'
 	 clear
  else
	  sleep 10
  fi
fi

if [ "$STEP_NUMBER" -le "5" ]; then
  # 5. Configuring Tor with its pluggable transports
  clear
  echo -e "${RED}[+] Step 5: Configuring Tor with its pluggable transports....${NOCOLOR}"
  cd
  git clone $OBFS4PROXY_USED
  DLCHECK=$?
  if [ $DLCHECK -eq 0 ]; then
		if [ "$TORBOX_MINI" == "--torbox_mini" ]; then
			export GOARCH=arm
			export GOARM=6
		fi
	  export GO111MODULE="on"
	  cd obfs4proxy
		# NEW v.0.5.4 With or without the path
	  if [ -f /usr/local/go/bin/go ]; then
		  GO_PROGRAM=/usr/local/go/bin/go
	  else
		  GO_PROGRAM=go
	  fi
	  $GO_PROGRAM build -o obfs4proxy/obfs4proxy ./obfs4proxy
	  cp ./obfs4proxy/obfs4proxy /usr/bin
	  cd
	  rm -rf obfs4proxy
	  rm -rf go*
  else
	  echo ""
	  echo -e "${YELLOW}[!] COULDN'T CLONE THE OBFS4PROXY REPOSITORY!${NOCOLOR}"
	  echo -e "${RED}[+] The obfs4proxy repository may be blocked or offline!${NOCOLOR}"
	  echo -e "${RED}[+] Please try again later and if the problem persists, please report it${NOCOLOR}"
	  echo -e "${RED}[+] to ${YELLOW}anonym@torbox.ch${RED}. ${NOCOLOR}"
	  echo -e "${RED}[+] In the meantime, we install the distribution package, which may be outdated.${NOCOLOR}"
	  echo ""
	  read -n 1 -s -r -p $'\e[1;31mPlease press any key to continue... \e[0m'
	  check_install_packages obfs4proxy
	  clear
  fi
  setcap 'cap_net_bind_service=+ep' /usr/bin/obfs4proxy
  (mv /usr/local/bin/tor* /usr/bin) 2>/dev/null
  (chmod a+x /usr/share/tor/geoip*) 2>/dev/null
  # Debian specific
  (chmod a+x /usr/local/share/tor/geoip*) 2>/dev/null
  # Copy not moving!
  (cp /usr/share/tor/geoip* /usr/bin) 2>/dev/null
  # Debian specific
  (cp /usr/local/share/tor/geoip* /usr/bin) 2>/dev/null
  sed -i "s/^NoNewPrivileges=yes/NoNewPrivileges=no/g" /lib/systemd/system/tor@default.service
  sed -i "s/^NoNewPrivileges=yes/NoNewPrivileges=no/g" /lib/systemd/system/tor@.service

  if [ "$STEP_BY_STEP" = "--step_by_step" ]; then
	  echo ""
	  read -n 1 -s -r -p $'\e[1;31mPlease press any key to continue... \e[0m'
	  clear
  else
	  sleep 10
  fi
fi

if [ "$STEP_NUMBER" -le "6" ]; then
  # 6. Install Snowflake
  clear
  echo -e "${RED}[+] Step 6: Installing Snowflake...${NOCOLOR}"
  echo -e "${RED}[+]         This can take some time, please be patient!${NOCOLOR}"
  cd
  git clone $SNOWFLAKE_USED
  DLCHECK=$?
  if [ $DLCHECK -eq 0 ]; then
		if [ "$TORBOX_MINI" == "--torbox_mini" ]; then
			export GOARCH=arm
			export GOARM=6
		fi
	  export GO111MODULE="on"
	  cd snowflake/proxy
	  $GO_PROGRAM get
	  $GO_PROGRAM build
	  cp proxy /usr/bin/snowflake-proxy
	  cd
	  cd snowflake/client
	  $GO_PROGRAM get
	  $GO_PROGRAM build
	  cp client /usr/bin/snowflake-client
	  cd
	  rm -rf snowflake
	  rm -rf go*
  else
	  echo ""
	  echo -e "${YELLOW}[!] COULDN'T CLONE THE SNOWFLAKE REPOSITORY!${NOCOLOR}"
	  echo -e "${RED}[+] The Snowflake repository may be blocked or offline!${NOCOLOR}"
	  echo -e "${RED}[+] Please try again later and if the problem persists, please report it${NOCOLOR}"
	  echo -e "${RED}[+] to ${YELLOW}anonym@torbox.ch${RED}. ${NOCOLOR}"
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
fi

if [ "$STEP_NUMBER" -le "7" ]; then
  # 7. Again checking connectivity
  clear
  echo -e "${RED}[+] Step 7: Re-checking Internet connectivity${NOCOLOR}"
  re-connect
fi

if [ "$STEP_NUMBER" -le "8" ]; then
  # 8. Downloading and installing the latest version of TorBox
  sleep 10
  clear
  echo -e "${RED}[+] Step 8: Downloading and installing the latest version of TorBox...${NOCOLOR}"
  echo -e "${RED}[+]         Selected branch ${YELLOW}$TORBOXMENU_BRANCHNAME${RED}...${NOCOLOR}"
  cd
  wget $TORBOXURL
  DLCHECK=$?
  if [ $DLCHECK -eq 0 ] ; then
	  echo -e "${RED}[+]         TorBox' menu Successfully downloaded... ${NOCOLOR}"
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
	  echo -e "${YELLOW}[!] COULDN'T DOWNLOAD TORBOX!${NOCOLOR}"
	  echo -e "${RED}[+] The TorBox repositories may be blocked or offline!${NOCOLOR}"
	  echo -e "${RED}[+] Please try again later and if the problem persists, please report it${NOCOLOR}"
	  echo -e "${RED}[+] to ${YELLOW}anonym@torbox.ch${RED}. ${NOCOLOR}"
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
fi

if [ "$STEP_NUMBER" -le "9" ]; then
  # 9. Installing all configuration files
  clear
  cd torbox
  echo -e "${RED}[+] Step 9: Installing all configuration files....${NOCOLOR}"
  echo ""
  (cp /etc/default/hostapd /etc/default/hostapd.bak) 2>/dev/null
  cp etc/default/hostapd /etc/default/
  echo -e "${RED}[+]${NOCOLOR}         Copied /etc/default/hostapd -- backup done"
  (cp /etc/default/isc-dhcp-server /etc/default/isc-dhcp-server.bak) 2>/dev/null
  cp etc/default/isc-dhcp-server /etc/default/
  echo -e "${RED}[+]${NOCOLOR}         Copied /etc/default/isc-dhcp-server -- backup done"
  (cp /etc/dhcp/dhclient.conf /etc/dhcp/dhclient.conf.bak) 2>/dev/null
  cp etc/dhcp/dhclient.conf /etc/dhcp/
  echo -e "${RED}[+]${NOCOLOR}         Copied /etc/dhcp/dhclient.conf -- backup done"
  (cp /etc/dhcp/dhcpd.conf /etc/dhcp/dhcpd.conf.bak) 2>/dev/null
	if [ "$TORBOX_MINI" == "--torbox_mini" ]; then
    cp etc/dhcp/dhcpd-mini.conf /etc/dhcp/dhcpd.conf
  else
    cp etc/dhcp/dhcpd.conf /etc/dhcp/
  fi
  echo -e "${RED}[+]${NOCOLOR}         Copied /etc/dhcp/dhcpd.conf -- backup done"
  (cp /etc/hostapd/hostapd.conf /etc/hostapd/hostapd.conf.bak) 2>/dev/null
  cp etc/hostapd/hostapd.conf /etc/hostapd/
  echo -e "${RED}[+]${NOCOLOR}         Copied /etc/hostapd/hostapd.conf -- backup done"
  (cp /etc/iptables.ipv4.nat /etc/iptables.ipv4.nat.bak) 2>/dev/null
  if [ "$ON_A_CLOUD" == "--on_a_cloud" ]; then cp etc/iptables.ipv4-cloud.nat /etc/iptables.ipv4.nat
	elif [ "$TORBOX_MINI" == "--torbox_mini" ]; then cp etc/iptables.ipv4-mini.nat /etc/iptables.ipv4.nat
  else cp etc/iptables.ipv4.nat /etc/; fi
  echo -e "${RED}[+]${NOCOLOR}         Copied /etc/iptables.ipv4.nat -- backup done"
  (cp /etc/motd /etc/motd.bak) 2>/dev/null
  cp etc/motd /etc/
  echo -e "${RED}[+]${NOCOLOR}         Copied /etc/motd -- backup done"

  # NEW v.0.5.4: TorBox on a Cloud - there are two scenario
  # 1 - The VPS get the network configuration via DHCP --> we can use our /etc/network/interfaces
  # 2 - The VPS the network of the VPS is statically configured --> don't change /etc/network/interfaces
  #     but disable with Predictable Network Interface Name in /etc/network/interfaces
	(cp /etc/network/interfaces /etc/network/interfaces.bak) 2>/dev/null
  if [ "$ON_A_CLOUD" == "--on_a_cloud" ]; then
	  NIC=$(ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)' | head -1)
	  if ! grep "$NIC" /etc/network/interfaces | grep "static"; then
		  cp etc/network/interfaces /etc/network/
		  echo
		  echo -e "${YELLOW}[!]         The VPS network is configured via DHCP - copying /etc/network/interfaces -- Backup done!"
		  echo -e "${YELLOW}            If you need support from the TorBox team, then please report this!"
		  echo
		  sleep 10
	  else
		  sed -i "s/\<$NIC\>/eth0/g" /etc/network/interfaces
		  echo
		  echo -e "${YELLOW}[!]         The VPS network is configured statically - keeping /etc/network/interfaces!"
		  echo -e "${YELLOW}            However, we changed $NIC into eth0!"
		  echo -e "${YELLOW}            If you need support from the TorBox team, then please report this!"
		  echo
		  sleep 10
	  fi
	elif [ "$TORBOX_MINI" == "--torbox_mini" ]; then
		cp etc/network/interfaces.mini /etc/network/interfaces
	else
		cp etc/network/interfaces /etc/network/
	fi
  # NEW v.0.5.4: Disable Predictable Network Interface Names, because we need eth0, wlan0, wlan1 etc.
  # Added for TorBox on a Cloud -- has to be tested with a common Debian image
	if [ ! -f "/boot/dietpi/.version" ] ; then
  	echo -e "${RED}[+]${NOCOLOR}         Disabling Predictable Network Interface Names"
  	if grep "GRUB_CMDLINE_LINUX=" /etc/default/grub; then
	  	GRUB_CONFIG=$(grep "GRUB_CMDLINE_LINUX=" /etc/default/grub | sed 's/GRUB_CMDLINE_LINUX=//g' | sed 's/"//g')
	  	if [[ ${GRUB_CONFIG} != *"net.ifnames"* ]] && [[ ${GRUB_CONFIG} != *"biosdevname"* ]]; then
		  	if [ "$GRUB_CONFIG" == "" ]; then
			  	GRUB_CONFIG_NEW="GRUB_CMDLINE_LINUX=\"net.ifnames=0 biosdevname=0\""
			  	#This is necessary to work with special characters in sed
			  	GRUB_CONFIG_NEW="$(<<< "$GRUB_CONFIG_NEW" sed -e 's`[][\\/.*^$]`\\&`g')"
			  	sed -i "s/^GRUB_CMDLINE_LINUX=.*/$GRUB_CONFIG_NEW/g" /etc/default/grub
		  	else
			  	GRUB_CONFIG_NEW="GRUB_CMDLINE_LINUX=\"$GRUB_CONFIG net.ifnames=0 biosdevname=0\""
			  	#This is necessary to work with special characters in sed
			  	GRUB_CONFIG_NEW="$(<<< "$GRUB_CONFIG_NEW" sed -e 's`[][\\/.*^$]`\\&`g')"
			  	sed -i "s/^GRUB_CMDLINE_LINUX=.*/$GRUB_CONFIG_NEW/g" /etc/default/grub
		  	fi
	  	fi
  	else
	  	(printf "GRUB_CMDLINE_LINUX=\"net.ifnames=0 biosdevname=0\"" | tee -a /etc/default/grub) 2>&1
  	fi
  	update-grub
	fi
  # With Debian 11 (Bullseye) there is no default rc.local file anymore. But this doesn't mean it has been completely removed.
  # URL: https://blog.wijman.net/enable-rc-local-in-debian-bullseye/
  cp etc/systemd/system/rc-local.service /etc/systemd/system/rc-local.service
  (cp /etc/rc.local /etc/rc.local.bak) 2>/dev/null
	if [ "$TORBOX_MINI" == "--torbox_mini" ]; then
		cp etc/rc.local.mini /etc/rc.local
	else
		cp etc/rc.local /etc/
	fi
  chmod a+x /etc/rc.local
  systemctl daemon-reload
  echo -e "${RED}[+]${NOCOLOR}         Copied /etc/rc.local -- backup done"
  if grep -q "#net.ipv4.ip_forward=1" /etc/sysctl.conf ; then
    cp /etc/sysctl.conf /etc/sysctl.conf.bak
    sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
    echo -e "${RED}[+]${NOCOLOR}         Changed /etc/sysctl.conf -- backup done"
  fi
  # NEW v.0.5.4: Cloudspecific torrc
  (cp /etc/tor/torrc /etc/tor/torrc.bak) 2>/dev/null
  if [ "$ON_A_CLOUD" == "--on_a_cloud" ]; then cp etc/tor/torrc-cloud /etc/tor/torrc
  else cp etc/tor/torrc /etc/tor/ ; fi
  echo -e "${RED}[+]${NOCOLOR}         Copied /etc/tor/torrc -- backup done"
  echo -e "${RED}[+]${NOCOLOR}         Activating IP forwarding"
  sh -c "echo 1 > /proc/sys/net/ipv4/ip_forward"
  (cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak) 2>/dev/null
  cp etc/nginx/nginx.conf /etc/nginx/
  echo -e "${RED}[+]${NOCOLOR}         Copied /etc/nginx/nginx.conf -- backup done"
  echo ""

  #Back to the home directory
  cd
	# What if .profile doesn't exist?
  if [ -f ".profile" ]; then
	  if ! grep "Added by TorBox (002)" .profile ; then
		  printf "\n# Added by TorBox (002)\ncd torbox\n./menu\n" | tee -a .profile
	  fi
  else
	  printf "\n# Added by TorBox (002)\ncd torbox\n./menu\n" | tee -a .profile
  fi

  echo -e "${RED}[+]          Make tor ready for Onion Services${NOCOLOR}"
  (mkdir /var/lib/tor/services) 2>/dev/null
  chown -R debian-tor:debian-tor /var/lib/tor/services
  chmod -R go-rwx /var/lib/tor/services
  (mkdir /var/lib/tor/onion_auth) 2>/dev/null
  chown -R debian-tor:debian-tor /var/lib/tor/onion_auth
  chmod -R go-rwx /var/lib/tor/onion_auth

  if [ "$STEP_BY_STEP" = "--step_by_step" ]; then
	  echo ""
	  read -n 1 -s -r -p $'\e[1;31mPlease press any key to continue... \e[0m'
	  clear
  else
	  sleep 10
  fi
fi

if [ "$STEP_NUMBER" -le "10" ]; then
	# 10. Disabling Bluetooth
	clear
	echo -e "${RED}[+] Step 10: Because of security considerations, we completely disable Bluetooth functionality, if available${NOCOLOR}"
	if [ -f "${CONFIGFILE}" ] ; then
		if ! grep "# Added by TorBox" ${CONFIGFILE} ; then
			sudo printf "\n# Added by TorBox\ndtoverlay=disable-bt\n" | sudo tee -a ${CONFIGFILE}
		fi
	fi
	if [ -e /dev/rfkill ]; then rfkill block bluetooth; fi
	if [ "$STEP_BY_STEP" = "--step_by_step" ]; then
		echo ""
		read -n 1 -s -r -p $'\e[1;31mPlease press any key to continue... \e[0m'
		clear
	else
		sleep 10
	fi
fi

if [ "$STEP_NUMBER" -le "11" ]; then
	# 11. Configure the system services
	clear
	echo -e "${RED}[+] Step 11: Configure the system services...${NOCOLOR}"
	systemctl daemon-reload
	if [ "$TORBOX_MINI" == "--torbox_mini" ] || [ "$ON_A_CLOUD" == "--on_a_cloud" ]; then
  	systemctl stop hostapd
  	systemctl disable hostapd
  	systemctl mask hostapd
	else
  	systemctl unmask hostapd
  	systemctl enable hostapd
  	systemctl start hostapd
	fi
	systemctl unmask isc-dhcp-server
	systemctl enable isc-dhcp-server
	systemctl start isc-dhcp-server
	systemctl stop tor
	systemctl mask tor
	# Both tor services have to be masked to block outgoing tor connections
	systemctl mask tor@default.service
	systemctl unmask ssh
	systemctl enable ssh
	systemctl start ssh
	# Debian specific
	systemctl unmask resolvconf
	systemctl enable resolvconf
	systemctl start resolvconf
	# This doesn't work - rc-local will be still masked
	#systemctl unmask rc-local
	#systemctl enable rc-local

	# NEW v.0.5.4-post: DietPi support
	if [ -f "/boot/dietpi/.version" ] ; then
		systemctl unmask systemd-logind.service
	fi
	echo ""
	echo -e "${RED}[+]          Stop logging, now...${NOCOLOR}"
	systemctl stop rsyslog
	systemctl disable rsyslog
	systemctl mask rsyslog
	systemctl stop systemd-journald-dev-log.socket
	systemctl stop systemd-journald-audit.socket
	systemctl stop systemd-journald.socket
	systemctl stop systemd-journald.service
	systemctl mask systemd-journald.service
	echo""

	# Make Nginx ready for Webssh and Onion Services
	echo -e "${RED}[+]          Make Nginx ready for Webssh and Onion Services${NOCOLOR}"
	systemctl stop nginx
	(rm /etc/nginx/sites-enabled/default) 2>/dev/null
	(rm /etc/nginx/sites-available/default) 2>/dev/null
	(rm -r /var/www/html) 2>/dev/null
	# This is necessary for Nginx / TFS
	(chown torbox:torbox /var/www) 2>/dev/null
	# Configuring webssh
	cp torbox/etc/nginx/sites-available/sample-webssh.conf /etc/nginx/sites-available/webssh.conf
	ln -sf /etc/nginx/sites-available/webssh.conf /etc/nginx/sites-enabled/
	# HAS TO BE TESTED: https://unix.stackexchange.com/questions/164866/nginx-leaves-old-socket
	(sed "s|STOP_SCHEDULE=\"${STOP_SCHEDULE:-QUIT/5/TERM/5/KILL/5}\"|STOP_SCHEDULE=\"${STOP_SCHEDULE:-TERM/5/KILL/5}\"|g" /etc/init.d/nginx) 2>/dev/null
	#systemctl start nginx
	systemctl daemon-reload

	if [ "$STEP_BY_STEP" = "--step_by_step" ]; then
		echo ""
		read -n 1 -s -r -p $'\e[1;31mPlease press any key to continue... \e[0m'
		clear
	else
		sleep 10
	fi
fi

if [ "$STEP_NUMBER" -le "12" ]; then
	# 12. Updating run/torbox.run
	clear
	echo -e "${RED}[+] Step 12: Configuring TorBox and update run/torbox.run...${NOCOLOR}"
	echo -e "${RED}[+]          Update run/torbox.run${NOCOLOR}"
	sed -i "s/^NAMESERVERS=.*/NAMESERVERS=${NAMESERVERS_ORIG}/g" ${RUNFILE}
	sed -i "s|^GO_DL_PATH=.*|GO_DL_PATH=${GO_DL_PATH}|g" ${RUNFILE}
	sed -i "s|^OBFS4PROXY_USED=.*|OBFS4PROXY_USED=${OBFS4PROXY_USED}|g" ${RUNFILE}
	sed -i "s|^SNOWFLAKE_USED=.*|SNOWFLAKE_USED=${SNOWFLAKE_USED}|g" ${RUNFILE}
	sed -i "s|^WIRINGPI_USED=.*|WIRINGPI_USED=${WIRINGPI_USED}|g" ${RUNFILE}
	# NEW v.0.5.4: Specifc configurations for an installation on a cloud
	# Important: Randomizing MAC addresses could prevent the assignement of an IP address
	if [ "$ON_A_CLOUD" == "--on_a_cloud" ]; then
		sed -i "s/^FRESH_INSTALLED=.*/FRESH_INSTALLED=1/" ${RUNFILE}
		sed -i "s/^ON_A_CLOUD=.*/ON_A_CLOUD=1/" ${RUNFILE}
		sed -i "s/^TORBOX_MINI=.*/TORBOX_MINI=0/" ${RUNFILE}
		sed -i "s/=random/=permanent/" ${RUNFILE}
	elif [ "$TORBOX_MINI" == "--torbox_mini" ]; then
		sed -i "s/^FRESH_INSTALLED=.*/FRESH_INSTALLED=3/" ${RUNFILE}
		sed -i "s/^ON_A_CLOUD=.*/ON_A_CLOUD=0/" ${RUNFILE}
		sed -i "s/^TORBOX_MINI=.*/TORBOX_MINI=1/" ${RUNFILE}
	else
		sed -i "s/^FRESH_INSTALLED=.*/FRESH_INSTALLED=3/" ${RUNFILE}
		sed -i "s/^ON_A_CLOUD=.*/ON_A_CLOUD=0/" ${RUNFILE}
		sed -i "s/^TORBOX_MINI=.*/TORBOX_MINI=0/" ${RUNFILE}
	fi
	if [ "$STEP_BY_STEP" = "--step_by_step" ]; then
 		echo ""
 		read -n 1 -s -r -p $'\e[1;31mPlease press any key to continue... \e[0m'
 		clear
	else
 		sleep 10
	fi
fi

if [ "$STEP_NUMBER" -le "13" ]; then
	#13.  TorBox mini specific configurations
  if [ "$TORBOX_MINI" == "--torbox_mini" ]; then
    if ! grep "dwc2,g_ether" ${CMDLINEFILE}; then
      if grep "modules-load" ${CMDLINEFILE}; then
        CMDLINE_STRING=$(grep -o "modules-load=.*" ${CMDLINEFILE} | cut -d ' ' -f 1)
        CMDLINE_STRING_NEW="$CMDLINE_STRING,dwc2,g_ether"
        sed -i "s|${CMDLINE_STRING}|${CMDLINE_STRING_NEW}|g" ${CMDLINEFILE}
      else
        sed -i "s|rootwait|modules-load=dwc2,g_ether rootwait|g" ${CMDLINEFILE}
      fi
    fi
  	if ! grep "dwc2,dr_mode=peripheral" ${CONFIGFILE}; then
			(printf "\ndtoverlay=dwc2,dr_mode=peripheral\n" | tee -a ${CONFIGFILE}) >/dev/null 2>&1
  	fi
		clear
		echo -e "${RED}[+] Step 14: TorBox is configured to be used in a Raspberry Pi Zero 2 W${NOCOLOR}"
		if [ "$STEP_BY_STEP" = "--step_by_step" ]; then
			echo ""
			read -n 1 -s -r -p $'\e[1;31mPlease press any key to continue... \e[0m'
			clear
		else
			sleep 10
		fi
	fi
fi

if [ "$STEP_NUMBER" -le "14" ]; then
	# 14. Adding and implementing the user torbox
	clear
	echo -e "${RED}[+] Step 13: Set up the torbox user...${NOCOLOR}"
	echo -e "${RED}[+]          In this step the user \"torbox\" with the default${NOCOLOR}"
	echo -e "${RED}[+]          password \"$DEFAULT_PASS\" is created.  ${NOCOLOR}"
	echo ""
	echo -e "${YELLOW}[!] IMPORTANT${NOCOLOR}"
	echo -e "${YELLOW}    To use TorBox, you have to log in with \"torbox\"${NOCOLOR}"
	echo -e "${YELLOW}    and the default password \"$DEFAULT_PASS\"!!${NOCOLOR}"
	echo -e "${YELLOW}    Please, change the default passwords as soon as possible!!${NOCOLOR}"
	echo -e "${YELLOW}    The associated menu entries are placed in the configuration sub-menu.${NOCOLOR}"
	echo ""
	adduser --disabled-password --gecos "" torbox
	echo -e "$DEFAULT_PASS\n$DEFAULT_PASS\n" |  passwd torbox
	adduser torbox
	adduser torbox netdev
	# This is necessary for Nginx / TFS
	(chown torbox:torbox /var/www) 2>/dev/null
	mv /root/* /home/torbox/
	(mv /root/.profile /home/torbox/) 2>/dev/null
	mkdir /home/torbox/openvpn
	(rm .bash_history) 2>/dev/null
	chown -R torbox:torbox /home/torbox/
	if !  grep "# Added by TorBox" /etc/sudoers ; then
  	printf "\n# Added by TorBox\ntorbox  ALL=(ALL) NOPASSWD: ALL\n" |  tee -a /etc/sudoers
  	(visudo -c) 2>/dev/null
	fi
	cd /home/torbox/

	if [ "$STEP_BY_STEP" = "--step_by_step" ]; then
		echo ""
		read -n 1 -s -r -p $'\e[1;31mPlease press any key to continue... \e[0m'
		clear
	else
		sleep 10
	fi
fi

if [ "$STEP_NUMBER" -le "15" ]; then
	# 15. Setting/changing root password
	clear
	echo -e "${RED}[+] Step 14: Setting/changing the root password...${NOCOLOR}"
	echo -e "${RED}[+]          For security reason, we will ask you now for a (new) root password.${NOCOLOR}"
	echo -e "${RED}[+]          Usually, you don't need to log into the system as root.${NOCOLOR}"
	echo
	echo -e "${YELLOW}             AGAIN: To use TorBox, you have to log in with \"torbox\"${NOCOLOR}"
	echo -e "${YELLOW}             and the default password \"$DEFAULT_PASS\"!!${NOCOLOR}"
	echo ""
	passwd
	# NEW v.0.5.4-post: DietPi support - deactivate user dietpi
	if [ -f "/boot/dietpi/.version" ] ; then
	  sleep 10
		echo -e "${RED}[+] Step 14: Disabling login for user dietpi ...${NOCOLOR}"
		echo -e "${RED}[+]          For security reason, we disable the login for the user dietpi.${NOCOLOR}"
		passwd -l dietpi
		usermod -s /sbin/nologin dietpi
	fi
fi

if [ "$STEP_NUMBER" -le "16" ]; then
	# 16. Finishing, cleaning and booting
	sleep 10
	clear
	echo -e "${RED}[+] Step 15: We are finishing and cleaning up now!${NOCOLOR}"
	echo -e "${RED}[+]          This will erase all log files and cleaning up the system.${NOCOLOR}"
	echo ""
	echo -e "${YELLOW}[!] IMPORTANT${NOCOLOR}"
	echo -e "${YELLOW}    After this last step, TorBox will restart.${NOCOLOR}"
	echo -e "${YELLOW}    To use TorBox, you have to log in with \"torbox\" and the default${NOCOLOR}"
	echo -e "${YELLOW}    password \"$DEFAULT_PASS\"!! ${NOCOLOR}"
	echo -e "${YELLOW}    If connecting via TorBox's WiFi (TorBox054) use \"CHANGE-IT\" as password.${NOCOLOR}"
	echo -e "${YELLOW}    After rebooting, please, change the default passwords immediately!!${NOCOLOR}"
	echo -e "${YELLOW}    The associated menu entries are placed in the configuration sub-menu.${NOCOLOR}"
	echo ""
	read -n 1 -s -r -p $'\e[1;31mTo complete the installation, please press any key... \e[0m'
	clear
	echo -e "${RED}[+] Erasing big not usefull packages...${NOCOLOR}"
	(rm -r WiringPi) 2>/dev/null
	# Find the bigest space waster packages: dpigs -H
	apt-get -y --purge remove exim4 exim4-base exim4-config exim4-daemon-light
	apt-get -y remove libgl1-mesa-dri texlive* lmodern
	apt-get -y clean
	apt-get -y autoclean
	apt-get -y autoremove
	echo -e "${RED}[+] Setting the timezone to UTC${NOCOLOR}"
	timedatectl set-timezone UTC
	echo -e "${RED}[+] Erasing ALL LOG-files...${NOCOLOR}"
	echo " "
	# shellcheck disable=SC2044
	for logs in $(find /var/log -type f); do
  	echo -e "${RED}[+]${NOCOLOR} Erasing $logs"
  	rm $logs
  	sleep 1
	done
	journalctl --vacuum-size=1M
	echo -e "${RED}[+]${NOCOLOR} Erasing History..."
	#.bash_history is already deleted
	history -c
	# To start TACA notices.log has to be present
	(sudo -u debian-tor touch /var/log/tor/notices.log) 2>/dev/null
	(chmod -R go-rwx /var/log/tor/notices.log) 2>/dev/null
	echo ""
	echo -e "${RED}[+] Setting up the hostname...${NOCOLOR}"
	# This has to be at the end to avoid unnecessary error messages
	(hostnamectl set-hostname "$HOSTNAME") 2>/dev/null
	systemctl restart systemd-hostnamed
	if grep 127.0.1.1.* /etc/hosts ; then
		(sed -i "s/127.0.1.1.*/127.0.1.1\t$HOSTNAME/g" /etc/hosts) 2>/dev/null
	else
		(sed -i "s/^::1/127.0.1.1\t$HOSTNAME\n::1/g" /etc/hosts) 2>/dev/null
	fi
	#
	if [ "$STEP_BY_STEP" = "--step_by_step" ]; then
		echo ""
		read -n 1 -s -r -p $'\e[1;31mPlease press any key to REBOOT... \e[0m'
		clear
	else
		sleep 10
	fi
	echo -e "${RED}[+] Rebooting...${NOCOLOR}"
	sync
	sleep 3
	reboot
fi
