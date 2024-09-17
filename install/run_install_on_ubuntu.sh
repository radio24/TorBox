#!/bin/bash
# shellcheck disable=SC2001,SC2004,SC2181

# This file is a part of TorBox, an easy to use anonymizing router based on Raspberry Pi.
# Copyright (C) 2024 Patrick Truffer
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
# Ubuntu.
#
# SYNTAX
# ./run_install.sh [-h|--help] [--randomize_hostname] [--select-tor] [--select-fork fork_owner_name] [--select-branch branch_name] [--on_a_cloud] [--step_by_step]
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
# The --step_by_step option execute the installation step by step, which
# is ideal to find bugs.
#
# IMPORTANT
# Start it as normal user (usually as ubuntu)!
# Dont run it as root (no sudo)!
# If Ubuntu 20.04 is freshly installed, you have to wait one or two minutes
# until you can log in with ubuntu / ubuntu
#
##########################################################

# Table of contents for this script:
#  1a. Checking for Internet connection
#  1b. Adjusting time, if needed
#   2. Updating the system
#   3. Installing all necessary packages
#   4. Install Tor
#   5. Configuring Tor with its pluggable transports
#   6. Install Snowflake
#   7. Re-checking Internet connectivity
#   8. Downloading and installing the latest version of TorBox
#   9. Installing all configuration files
#  10. Disabling Bluetooth
#  11. Configure the system services
#  12. Updating run/torbox.run
#  13. Adding and implementing the user torbox
#  14. Finishing, cleaning and booting

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

# Changes in the variables below (until the ####### delimiter) will be saved
# into run/torbox.run and used after the installation (we not recommend to
# change the values until zou precisely know what you are doing)
# Public nameserver used to circumvent cheap censorship
NAMESERVERS="1.1.1.1,1.0.0.1,8.8.8.8,8.8.4.4"

# Default hostname
HOSTNAME="TorBox053"

# For go
GO_DL_PATH="https://go.dev/dl/"
GO_PROGRAM="/usr/local/go/bin/go"

# NEW post-v.0.5.3: Added
# Release Page of the official Tor repositories
TOR_RELEASE="official"
TORURL="https://gitlab.torproject.org/tpo/core/tor/-/tags"
TORPATH_TO_RELEASE_TAGS="/tpo/core/tor/-/tags/tor-"
TOR_HREF_FOR_SED="<a class=\"gl-font-bold\" href=\"/tpo/core/tor/-/tags/tor-"
TORURL_DL_PARTIAL="https://dist.torproject.org/tor-"

# NEW post-v.0.5.3: Currently not updated
# Release Page of the unofficial Tor repositories on GitHub
#TOR_RELEASE="unofficial"
#TORURL="https://github.com/torproject/tor/tags"
#TORPATH_TO_RELEASE_TAGS="/torproject/tor/releases/tag/"
# WARNING: Sometimes, GitHub will change this prefix!
# TOR_HREF_FOR_SED="href=\"/torproject/tor/releases/tag/tor-"
#TOR_HREF_FOR_SED1="<h2 data-view-component=\"true\" class=\"f4 d-inline\"><a href=\"/torproject/tor/releases/tag/tor-"
#TOR_HREF_FOR_SED2="\" data-view-component=.*"
# TORURL_DL_PARTIAL is the the partial download path of the tor release packages
# (highlighted with "-><-": ->https://github.com/torproject/tor/releases/tag/tor<- -0.4.6.6.tar.gz)
#TORURL_DL_PARTIAL="https://github.com/torproject/tor/archive/refs/tags/tor-"

# Snowflake repositories
# Official: https://gitlab.torproject.org/tpo/anti-censorship/pluggable-transports/snowflake/
SNOWFLAKE_ORIGINAL_WEB="https://git.torproject.org/pluggable-transports/snowflake.git"
# Only until version 2.6.1
SNOWFLAKE_PREVIOUS_USED="https://github.com/syphyr/snowflake"
# Version 2.8.0+
SNOWFLAKE_USED="https://github.com/tgragnato/snowflake"

# OBFS4PROXY
OBFS4PROXY_USED="https://salsa.debian.org/pkg-privacy-team/obfs4proxy.git"

# Wiringpi - DEBIAN / UBUNTU SPECIFIC
WIRINGPI_USED="https://github.com/WiringPi/WiringPi.git"

# above values will be saved into run/torbox.run #######

# Connectivity check
CHECK_URL1="ubuntu.com"
CHECK_URL2="google.com"

# Default password
DEFAULT_PASS="CHANGE-IT"

# Catching command line options
OPTIONS=$(getopt -o h --long help,randomize_hostname,select-tor,select-fork:,select-branch:,on_a_cloud,step_by_step -n 'run-install' -- "$@")
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
			echo "Copyright (C) 2024 Patrick Truffer, nyxnor (Contributor)"
			echo "Syntax : run_install_debian.sh [-h|--help] [--randomize_hostname] [--select-tor] [--select-fork fork_name] [--select-branch branch_name] [--on_a_cloud] [--step_by_step]"
			echo "Options: -h, --help     : Shows this help screen ;-)"
			echo "         --randomize_hostname"
			echo "                        : Randomizes the hostname to prevent ISPs to see the default"
			echo "         --select-tor   : Let select a specific tor version (default: newest stable version)"
			echo "         --select-fork fork_owner_name"
			echo "                        : Let select a specific fork from a GitHub user (fork_owner_name)"
			echo "         --select-branch branch_name"
			echo "                        : Let select a specific TorBox branch (default: master)"
			echo "         --on_a_cloud   : Installing on a cloud or as a cloud service"
			echo "         --step_by_step : Executes the installation step by step"
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
	i=$(($i + 1))
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
#	if [ -f "/etc/systemd/resolved.conf" ]; then
#		(sudo cp /etc/systemd/resolved.conf /etc/systemd/resolved.conf.bak) 2>/dev/null
#	fi
# THIS SEEMS TO BE WRONG!!!!
#	(sudo printf "$RESOLVCONF" | sudo tee /etc/systemd/resolved.conf) 2>&1
#	sudo systemctl restart systemd-resolved
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
		sudo systemctl restart systemd-resolved
	  ping -c 1 -q $CHECK_URL2 >&/dev/null
	  if [ $? -eq 0 ]; then
	    echo -e "${RED}[+]         Yes, now, we have an Internet connection! :-)${NOCOLOR}"
	  else
	    echo -e "${YELLOW}[!]         Hmmm, still no Internet connection... :-(${NOCOLOR}"
	    echo -e "${RED}[+]         We will try to catch a dynamic IP adress and check again in about 30 seconds...${NOCOLOR}"
			if [ -f "/etc/resolv.conf" ]; then
				(sudo cp /etc/resolv.conf /etc/resolv.conf.bak) 2>&1
			fi
			(sudo printf "$RESOLVCONF" | sudo tee /etc/resolv.conf) 2>&1
			(sudo dhclient -r) 2>&1
	    sleep 5
	    sudo dhclient &>/dev/null &
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
    	echo -e "${RED}[+]         Installing ${YELLOW}$packagename${NOCOLOR}"
    	echo ""
    	sudo apt-get -y install $packagename
			check=$(dpkg-query -s $packagename | grep "Status" | grep -o "installed")
			if [ "$check" == "installed" ]; then check_installed=1
			else re-connect
			fi
		done
  done
}

# This function downloads and updates tor
# Syntax download_and_compile_tor
# Used predefined variables: $download_tor_url $filename RED WHITE NOCOLOR TORCONNECT
download_and_compile_tor()
{
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
		sudo make install
		cd
		sudo rm -r tor-*
		sudo systemctl stop tor
		sudo systemctl mask tor
		# Both tor services have to be masked to block outgoing tor connections
		sudo systemctl mask tor@default.service
		sudo systemctl stop tor
		sudo systemctl mask tor
		# Both tor services have to be masked to block outgoing tor connections
		sudo systemctl mask tor@default.service
	else
		echo -e ""
		echo -e "${YELLOW}[!] COULDN'T DOWNLOAD TOR!${NOCOLOR}"
		echo -e "${RED}[+] The unofficial Tor repositories may be blocked or offline!${NOCOLOR}"
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
		echo -e "${YELLOW}[!]         YES!${NOCOLOR}"
		echo ""
	else
		echo -e "${YELLOW}[!]         NO!${NOCOLOR}"
		echo -e ""
		echo -e "${RED}[+] The unofficial Tor repositories may be blocked or offline!${NOCOLOR}"
		echo -e "${RED}[+] Please try again later and if the problem persists, please report it${NOCOLOR}"
		echo -e "${RED}[+] to ${YELLOW}anonym@torbox.ch${RED}. ${NOCOLOR}"
		echo ""
		echo -e "${RED}[+] However, an older version of tor is alredy installed from${NOCOLOR}"
		echo -e "${RED}    the repository.${NOCOLOR}"
		read -n 1 -s -r -p $'\e[1;31mPlease press any key to continue... \e[0m'
		clear
	fi
  echo -e "${RED}[+]         Fetching possible tor versions... ${NOCOLOR}"
	# NEW post-v.0.5.3: Added
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
		echo -e "${RED}[+] The unofficial Tor repositories may be blocked or offline!${NOCOLOR}"
		echo -e "${RED}[+] Please try again later and if the problem persists, please report it${NOCOLOR}"
		echo -e "${RED}[+] to ${YELLOW}anonym@torbox.ch${RED}. ${NOCOLOR}"
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
			echo -e "${YELLOW}Choose a tor version (alpha versions are not recommended!):${NOCOLOR}"
    	echo ""
    	for (( i=0; i<$number_torversion; i++ ))
    	do
      	menuitem=$(( $i + 1 ))
      	echo -e "${RED}$menuitem${NOCOLOR} - ${torversion_versionsorted_new[$i]}"
    	done
    	echo ""
    	read -r -p $'\e[1;93mWhich tor version (number) would you like to use? -> \e[0m'
    	echo
    	if [[ $REPLY =~ ^[1234567890]$ ]]; then
				if [ $REPLY -gt 0 ] && [ $(( $REPLY - 1 )) -le $number_torversion ]; then
        	CHOICE_TOR=$((REPLY-1))
        	clear
        	echo -e "${RED}[+]         Download the selected tor version...... ${NOCOLOR}"
        	version_string="$(<<< ${torversion_versionsorted_new[$CHOICE_TOR]} sed -e 's/ //g')"
        	download_tor_url="$TORURL_DL_PARTIAL$version_string.tar.gz"
        	filename="tor-$version_string.tar.gz"
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
# Only Ubuntu - Sets the background of TorBox menu to dark blue
sudo rm /etc/alternatives/newt-palette; sudo ln -s /etc/newt/palette.original /etc/alternatives/newt-palette

if (whiptail --title "TorBox Installation on Ubuntu (scroll down!)" --scrolltext --no-button "INSTALL" --yes-button "STOP!" --yesno "         WELCOME TO THE INSTALLATION OF TORBOX ON UBUNTU\n\nPlease make sure that you started this script as \"./run_install_ubuntu\" (without sudo !!) in your home directory (/home/ubuntu).\n\nThe installation process runs almost without user interaction. However, macchanger will ask for enabling an autmatic change of the MAC address - REPLY WITH NO!\n\nTHIS INSTALLATION WILL CHANGE/DELETE THE CURRENT CONFIGURATION!\n\nDuring the installation, we are going to set up the user \"torbox\" with the default password \"$DEFAULT_PASS\". This user name and the password will be used for logging into your TorBox and to administering it. Please, change the default passwords as soon as possible (the associated menu entries are placed in the configuration sub-menu).\n\nIMPORTANT\nInternet connectivity is necessary for the installation.\n\nAVAILABLE OPTIONS\n-h, --help     : shows a help screen\n--randomize_hostname\n  	  	   : randomize the hostname to prevent ISPs to see the default\n--select-tor   : select a specific tor version\n--select-fork fork_owner_name\n  	  	   : select a specific fork from a GitHub user\n--select-branch branch_name\n  	  	   : select a specific TorBox branch\n--on_a_cloud   : installing on a cloud or as a cloud service.\n--step_by_step : Executes the installation step by step.\n\nIn case of any problems, contact us on https://www.torbox.ch." $MENU_HEIGHT_25 $MENU_WIDTH); then
	clear
	exit
fi

if [ -z "$RANDOMIZE_HOSTNAME" ]; then
	if (whiptail --title "TorBox Installation on Ubuntu" --defaultno --no-button "USE DEFAULT" --yes-button "CHANGE!" --yesno "In highly authoritarian countries connecting the tor network could be seen as suspicious. The default hostname of TorBox is \"TorBox<nnn>\" (<nnn> representing the version).\n\nWhen a computer connects to an ISP's network, it sends a DHCP request that includes the hostname. Because ISPs can see, log and even block hostnames, setting another hostname or using a randomized hostname may be preferable.\n\nWe recommend randomizing the hostname in highly authoritarian countries or if you think that your ISP blocks tor related network traffic.\n\nDo you want to use the DEFAULT hostname or to CHANGE it?" $MENU_HEIGHT_20 $MENU_WIDTH); then
		if (whiptail --title "TorBox Installation on Ubuntu" --no-button "SET HOSTNAME" --yes-button "RANDOMIZE HOSTNAME" --yesno "You can set a specific hostname or use a randomized one. Please choose..." $MENU_HEIGHT_10 $MENU_WIDTH); then
			# shellcheck disable=SC2002
			HOSTNAME=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 10 | head -n 1)
		else
			HOSTNAME=$(whiptail --title "TorBox Installation on Ubuntu" --inputbox "\nEnter the hostname:" $MENU_HEIGHT_10 $MENU_WIDTH_REDUX 3>&1 1>&2 2>&3)
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

# 1a. Checking for Internet connection
clear
echo -e "${RED}[+] Step 1: Do we have Internet?${NOCOLOR}"
echo -e "${RED}[+]         Nevertheless, first, let's add some open nameservers!${NOCOLOR}"

# NEW v.0.5.3
re-connect

# 1b. Adjusting time, if needed
clear
if [ -f "/etc/timezone" ]; then
	sudo mv /etc/timezone /etc/timezone.bak
	(printf "Etc/UTC" | sudo tee /etc/timezone) 2>&1
fi
sudo timedatectl set-timezone UTC
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
		sudo date -s "$DATESTRING"
		echo -e "${RED}[+] Date set successfully!${NOCOLOR}"
		if [[ $TIMESTRING =~ ^[0-9]{2}:[0-9]{2}$ ]]; then
			echo ""
			sudo date -s "$TIMESTRING"
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

# 2. Updating the system
clear
echo -e "${RED}[+] Step 2a: Remove Ubuntu's unattended update feature...${NOCOLOR}"
echo -e "${RED}[+]          Next we start the Ubuntu configure tool for unattended updates.${NOCOLOR}"
echo -e "${RED}[+]          In the tool, please select \"NO\" and press ENTER to continue!${NOCOLOR}"
echo ""
sleep 5
(sudo dpkg-reconfigure unattended-upgrades) 2>&1
clear
# shellcheck disable=SC2009
while ps -ax | grep "[u]nattended-upgr" | grep -v "[s]hutdown" ;
do
  clear
  echo -e "${RED}[+]         Ubuntu's unattended update feature is still aktiv! It has to be disabled!${NOCOLOR}"
  echo -e "${RED}[+]         Next we start again the Ubuntu configure tool for unattended updates.${NOCOLOR}"
  echo -e "${RED}[+]         In the tool, please select \"NO\" and press ENTER to continue!${NOCOLOR}"
  echo ""
  read -n 1 -s -r -p "Press any key to continue"
  sudo dpkg-reconfigure unattended-upgrades
  sleep 5
done
clear
(sudo apt-get -y purge unattended-upgrades) 2>&1
sudo dpkg --configure -a
echo ""

echo -e "${RED}[+] Step 2b: Remove Ubuntu's cloud-init...${NOCOLOR}"
sudo apt-get -y purge cloud-init
sudo rm -Rf /etc/cloud
echo ""

echo -e "${RED}[+] Step 2c: Updating the system...${NOCOLOR}"
# NEW v.0.5.3: Surpress the system restart dialog
sudo apt-get -y remove needrestart
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

echo -e "${RED}[+]         Did an information window tell you that you just updated the Linux kernel?${NOCOLOR}"
echo -e "${RED}[+]         In this case, we recommend rebooting the system and restarting the installation.${NOCOLOR}"
echo ""
read -r -p $'\e[1;93mWould you like to reboot the system now [Y/n]? -> \e[0m'
echo
if [[ $REPLY =~ ^[YyNn]$ ]] ; then
  if [[ $REPLY =~ ^[Yy]$ ]] ; then sync; reboot ; fi
else exit 0 ; fi

# 3. Installing all necessary packages
clear
echo -e "${RED}[+] Step 3: Installing all necessary packages....${NOCOLOR}"
# Necessary packages for Ubuntu systems (not necessary with Raspberry Pi OS)
check_install_packages "net-tools ifupdown unzip equivs rfkill iw"
# Installation of standard packages
# NEW post-v.0.5.3: openssl ca-certificates added
check_install_packages "hostapd isc-dhcp-server usbmuxd dnsmasq dnsutils tcpdump iftop vnstat debian-goodies apt-transport-https dirmngr python3-pip python3-pil imagemagick tesseract-ocr ntpdate screen git openvpn ppp python3-stem dkms nyx apt-transport-tor qrencode nginx basez ipset macchanger openssl ca-certificates lshw"
# Installation of developper packages - THIS PACKAGES ARE NECESARY FOR THE COMPILATION OF TOR!! Without them, tor will disconnect and restart every 5 minutes!!
check_install_packages "build-essential automake libevent-dev libssl-dev asciidoc bc devscripts dh-apparmor libcap-dev liblzma-dev libsystemd-dev libzstd-dev quilt pkg-config zlib1g-dev"
# IMPORTANT tor-geoipdb installs also the tor package
check_install_packages "tor-geoipdb"
sudo systemctl stop tor
sudo systemctl mask tor
# Both tor services have to be masked to block outgoing tor connections
sudo systemctl mask tor@default.service
# NEW post-v.0.5.3: Added
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
	sudo ./build
	cd
	sudo rm -r WiringPi
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
(sudo ln /usr/bin/python3 /usr/bin/python) 2>/dev/null
echo ""
echo -e "${RED}[+]         Installing ${YELLOW}Python modules${NOCOLOR}"
echo ""

# NEW v.0.5.3
PYTHON_LIB_PATH=$(python -c "import sys; print(sys.path)" | cut -d ' ' -f3 | sed "s/'//g" | sed "s/,//g" | sed "s/.zip//g" | sed "s/ //g")
if [ -f "$PYTHON_LIB_PATH/EXTERNALLY-MANAGED" ] ; then
  sudo rm "$PYTHON_LIB_PATH/EXTERNALLY-MANAGED"
fi

# NEW v.0.5.4: opencv-python-headless hangs when installed with pip
check_install_packages "python3-opencv"

# NEW v.0.5.3: New way to install and check Python requirements
# Important: mechanize 0.4.8 cannot correctly be installed under Raspberry Pi OS
#            the folder /usr/local/lib/python3.9/distpackages/mechanize is missing
cd
wget --no-cache https://raw.githubusercontent.com/$TORBOXMENU_FORKNAME/TorBox/$TORBOXMENU_BRANCHNAME/requirements.txt
sudo pip3 install -r requirements.txt
sleep 5

clear
echo -e "${YELLOW}Following Python modules are installed:${NOCOLOR}"
if [ -f "requirements.failed" ]; then rm requirements.failed; fi
REPLY="Y"
while [ "$REPLY" == "Y" ] || [ "$REPLY" == "y" ]; do
	REPLY=""
	readarray -t REQUIREMENTS < requirements.txt
	for REQUIREMENT in "${REQUIREMENTS[@]}"; do
		if grep "==" <<< $REQUIREMENT ; then REQUIREMENT=$(sed s"/==.*//" <<< $REQUIREMENT); fi
		VERSION=$(pip3 freeze | grep -i $REQUIREMENT | sed "s/${REQUIREMENT}==//i" 2>&1)
  	echo -e "${RED}${REQUIREMENT} version: ${YELLOW}$VERSION${NOCOLOR}"
		if [ -z "$VERSION" ]; then
			# shellcheck disable=SC2059
			(printf "$REQUIREMENT\n" | tee -a requirements.failed) >/dev/null 2>&1
		fi
	done
	if [ -f "requirements.failed" ]; then
		echo ""
		echo -e "${YELLOW}Not alle required Python modules could be installed!${NOCOLOR}"
		read -r -p $'\e[1;93mWould you like to try it again [Y/n]? -> \e[0m'
		if [[ $REPLY =~ ^[YyNn]$ ]] ; then
			if [ "$REPLY" == "Y" ] || [ "$REPLY" == "y" ]; then
				sudo pip3 install -r requirements.failed
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

# NEW v.0.5.3: New way to download the current version of go
if uname -m | grep -q -E "arm64|aarch64"; then PLATFORM="linux-arm64"
elif uname -m | grep -q -E "x86_64"; then PLATFORM="linux-amd64"
else PLATFORM="linux-armv6l"
fi

# Fetch the filename of the latest go version
GO_FILENAME=$(curl -s "$GO_DL_PATH" | grep "$PLATFORM" | grep -m 1 'class=\"download\"' | cut -d'"' -f6 | cut -d'/' -f3)
wget --no-cache "$GO_DL_PATH$GO_FILENAME"
DLCHECK=$?
# NEW v.0.5.3: if the download failed, install the package from the distribution
if [ "$DLCHECK" != "0" ] ; then
	echo ""
	echo -e "${YELLOW}[!] COULDN'T DOWNLOAD GO (for $PLATFORM)!${NOCOLOR}"
	echo -e "${RED}[+] The go repositories may be blocked or offline!${NOCOLOR}"
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
	sudo apt-get -y install golang
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
else
  sudo tar -C /usr/local -xzvf $GO_FILENAME
	sudo rm $GO_FILENAME
fi

# NEW v.0.5.3: what if .profile doesn't exist?
if [ -f ".profile" ]; then
	if ! grep "Added by TorBox (001)" .profile ; then
		sudo printf "\n# Added by TorBox (001)\nexport PATH=$PATH:/usr/local/go/bin\n" | tee -a .profile
	fi
else
	sudo printf "\n# Added by TorBox (001)\nexport PATH=$PATH:/usr/local/go/bin\n" | tee -a .profile
fi
export PATH=$PATH:/usr/local/go/bin

if [ "$STEP_BY_STEP" = "--step_by_step" ]; then
	echo ""
	read -n 1 -s -r -p $'\e[1;31mPlease press any key to continue... \e[0m'
	clear
else
	sleep 10
fi

# 4. Installing tor
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
cd
git clone $OBFS4PROXY_USED
DLCHECK=$?
if [ $DLCHECK -eq 0 ]; then
	export GO111MODULE="on"
	cd obfs4proxy
	go build -o obfs4proxy/obfs4proxy ./obfs4proxy
	sudo cp ./obfs4proxy/obfs4proxy /usr/bin
	cd
	sudo rm -rf obfs4proxy
	sudo rm -rf go*
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

# 6. Install Snowflake
# NEW v.0.5.4: Under Ubuntu, snowflake-client has to be added to the apparmor configuration. We will do that under Pt 11
clear
echo -e "${RED}[+] Step 6: Installing Snowflake...${NOCOLOR}"
echo -e "${RED}[+]         This can take some time, please be patient!${NOCOLOR}"
cd
git clone $SNOWFLAKE_USED
DLCHECK=$?
if [ $DLCHECK -eq 0 ]; then
	export GO111MODULE="on"
	cd snowflake/proxy
	go get
	go build
	sudo cp proxy /usr/bin/snowflake-proxy
	cd
	cd snowflake/client
	go get
	go build
	sudo cp client /usr/bin/snowflake-client
	cd
	sudo rm -rf snowflake
	sudo rm -rf go*
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

# 7. Again checking connectivity
clear
echo -e "${RED}[+] Step 7: Re-checking Internet connectivity...${NOCOLOR}"
# NEW v.0.5.3
re-connect

# 8. Downloading and installing the latest version of TorBox
sleep 10
clear
echo -e "${RED}[+] Step 8: Downloading and installing the latest version of TorBox...${NOCOLOR}"
echo -e "${RED}[+]         Selected branch ${YELLOW}$TORBOXMENU_BRANCHNAME${RED}...${NOCOLOR}"
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

# 9. Installing all configuration files
clear
cd torbox
echo -e "${RED}[+] Step 9: Installing all configuration files....${NOCOLOR}"
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
sudo mkdir /etc/update-motd.d/bak
(sudo mv /etc/update-motd.d/* /etc/update-motd.d/bak/) 2>/dev/null
sudo rm /etc/legal
# Comment out with sed
sudo sed -ri "s/^session[[:space:]]+optional[[:space:]]+pam_motd\.so[[:space:]]+motd=\/run\/motd\.dynamic$/#\0/" /etc/pam.d/login
sudo sed -ri "s/^session[[:space:]]+optional[[:space:]]+pam_motd\.so[[:space:]]+motd=\/run\/motd\.dynamic$/#\0/" /etc/pam.d/sshd
echo -e "${RED}[+]${NOCOLOR}         Disabled Ubuntu's update-motd feature -- backup done"
(sudo cp /etc/motd /etc/motd.bak) 2>/dev/null
sudo cp etc/motd /etc/
echo -e "${RED}[+]${NOCOLOR}         Copied /etc/motd -- backup done"
(sudo cp /etc/network/interfaces /etc/network/interfaces.bak) 2>/dev/null
sudo cp etc/network/interfaces /etc/network/
echo -e "${RED}[+]${NOCOLOR}         Copied /etc/network/interfaces -- backup done"
# NEW v.0.5.3: Ubuntu supports Predictable Network Interface Names, but we need wlan0, wlan1 etc.
# See here: https://askubuntu.com/questions/826325/how-to-revert-usb-wifi-interface-name-from-wlxxxxxxxxxxxxx-to-wlanx
# See here: https://www.freedesktop.org/wiki/Software/systemd/PredictableNetworkInterfaceNames/
if [ -f "/dev/null /etc/udev/rules.d/80-net-setup-link.rules" ]; then sudo rm /dev/null /etc/udev/rules.d/80-net-setup-link.rules; fi
sudo ln -s /dev/null /etc/udev/rules.d/80-net-setup-link.rules
echo -e "${RED}[+]${NOCOLOR}         Predictable Network Interface Names disabled"
# NEW v.0.5.4: Disable Predictable Network Interface Names, because we need eth0, wlan0, wlan1 etc.
# Added for TorBox on a Cloud -- has to be tested with a common Debian image
if grep "GRUB_CMDLINE_LINUX=" /etc/default/grub; then
	GRUB_CONFIG=$(grep "GRUB_CMDLINE_LINUX=" /etc/default/grub | sed 's/GRUB_CMDLINE_LINUX=//g' | sed 's/"//g')
	if [[ ${GRUB_CONFIG} != *"net.ifnames"* ]] && [[ ${GRUB_CONFIG} != *"biosdevname"* ]]; then
		if [ "$GRUB_CONFIG" == "" ]; then
			GRUB_CONFIG_NEW="GRUB_CMDLINE_LINUX=\"net.ifnames=0 biosdevname=0\""
			#This is necessary to work with special characters in sed
			GRUB_CONFIG_NEW="$(<<< "$GRUB_CONFIG_NEW" sed -e 's`[][\\/.*^$]`\\&`g')"
			sudo sed -i "s/^GRUB_CMDLINE_LINUX=.*/$GRUB_CONFIG_NEW/g" /etc/default/grub
		else
			GRUB_CONFIG_NEW="GRUB_CMDLINE_LINUX=\"$GRUB_CONFIG net.ifnames=0 biosdevname=0\""
			#This is necessary to work with special characters in sed
			GRUB_CONFIG_NEW="$(<<< "$GRUB_CONFIG_NEW" sed -e 's`[][\\/.*^$]`\\&`g')"
			sudo sed -i "s/^GRUB_CMDLINE_LINUX=.*/$GRUB_CONFIG_NEW/g" /etc/default/grub
		fi
	fi
else
	(sudo printf "GRUB_CMDLINE_LINUX=\"net.ifnames=0 biosdevname=0\"" | sudo tee -a /etc/default/grub) 2>&1
fi
sudo update-grub
# See also here: https://www.linuxbabe.com/linux-server/how-to-enable-etcrc-local-with-systemd
sudo cp etc/systemd/system/rc-local.service /etc/systemd/system/
(sudo cp /etc/rc.local /etc/rc.local.bak) 2>/dev/null
# NEW v.0.5.3: No special rc.local for Debian/Ubuntu anymore
sudo cp etc/rc.local /etc/rc.local
sudo chmod u+x /etc/rc.local
# We will enable rc-local further below
echo -e "${RED}[+]${NOCOLOR}         Copied /etc/rc.local -- backup done"
# Unlike the Raspberry Pi OS, Ubuntu uses systemd-resolved to resolve DNS queries (see also further below).
# To work correctly in a captive portal environement, we have to set the following options in /etc/systemd/resolved.conf:
# LLMNR=yes / MulticastDNS=yes / Chache=no
(sudo cp /etc/systemd/resolved.conf /etc/systemd/resolved.conf.bak) 2>/dev/null
sudo cp etc/systemd/resolved.conf /etc/systemd/
echo -e "${RED}[+]${NOCOLOR}         Copied /etc/systemd/resolved.conf -- backup done"
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
sudo cp etc/nginx/nginx.conf /etc/nginx/
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

# 10. Disabling Bluetooth
clear
echo -e "${RED}[+] Step 10: Because of security considerations, we completely disable Bluetooth functionality, if available${NOCOLOR}"
if [ -f "/boot/firmware/config.txt" ] ; then
	if ! grep "# Added by TorBox" /boot/firmware/config.txt ; then
  	sudo printf "\n# Added by TorBox\ndtoverlay=disable-bt\n." | sudo tee -a /boot/firmware/config.txt
	fi
fi
sudo rfkill block bluetooth

if [ "$STEP_BY_STEP" = "--step_by_step" ]; then
	echo ""
	read -n 1 -s -r -p $'\e[1;31mPlease press any key to continue... \e[0m'
	clear
else
	sleep 10
fi

# 11. Configure the system services
sleep 10
clear
echo -e "${RED}[+] Step 11: Configure the system services...${NOCOLOR}"
echo ""

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
sudo systemctl restart systemd-resolved
# We can only start dnsmasq together with systemd-resolve, if we activate "bind-interface" in /etc/dnsmasq.conf
# --> https://unix.stackexchange.com/questions/304050/how-to-avoid-conflicts-between-dnsmasq-and-systemd-resolved
sudo sed -i "s/^#bind-interfaces/bind-interfaces/g" /etc/dnsmasq.conf
sudo systemctl unmask rc-local
sudo systemctl enable rc-local
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
# This is not needed in Ubuntu - see here: https://unix.stackexchange.com/questions/164866/nginx-leaves-old-socket
# (sudo sed "s|STOP_SCHEDULE=\"${STOP_SCHEDULE:-QUIT/5/TERM/5/KILL/5}\"|STOP_SCHEDULE=\"${STOP_SCHEDULE:-TERM/5/KILL/5}\"|g" /etc/init.d/nginx)
#sudo systemctl start nginx
sudo systemctl daemon-reload

# NEW v.0.5.3: snowflake-client has to be added to apparmor
if [ -f "/etc/apparmor.d/abstractions/tor" ]; then
	if ! grep "/usr/bin/snowflake-client Pix," /etc/apparmor.d/abstractions/tor; then
		sudo printf "\n# Needed by snowflake\n/usr/bin/snowflake-client Pix,\n" | sudo tee -a /etc/apparmor.d/abstractions/tor;
		sudo systemctl restart apparmor
	fi
else
	cd
	if [ -d "/etc/apparmor.d/abstractions" ]; then
		sudo cp torbox/etc/apparmor.d/abstractions/tor /etc/apparmor.d/abstractions;
		sudo systemctl restart apparmor
	fi
fi

if [ "$STEP_BY_STEP" = "--step_by_step" ]; then
	echo ""
	read -n 1 -s -r -p $'\e[1;31mPlease press any key to continue... \e[0m'
	clear
else
	sleep 10
fi

# 12. Updating run/torbox.run
clear
echo -e "${RED}[+] Step 12: Configuring TorBox and update run/torbox.run...${NOCOLOR}"
echo -e "${RED}[+]          Update run/torbox.run${NOCOLOR}"
sudo sed -i "s/^NAMESERVERS=.*/NAMESERVERS=${NAMESERVERS_ORIG}/g" ${RUNFILE}
sudo sed -i "s|^GO_DL_PATH=.*|GO_DL_PATH=${GO_DL_PATH}|g" ${RUNFILE}
sudo sed -i "s|^OBFS4PROXY_USED=.*|OBFS4PROXY_USED=${OBFS4PROXY_USED}|g" ${RUNFILE}
sudo sed -i "s|^SNOWFLAKE_USED=.*|SNOWFLAKE_USED=${SNOWFLAKE_USED}|g" ${RUNFILE}
sudo sed -i "s|^WIRINGPI_USED=.*|WIRINGPI_USED=${WIRINGPI_USED}|g" ${RUNFILE}
# NEW v.0.5.4: Specifc configurations for an installation on a cloud
# Important: Randomizing MAC addresses could prevent the assignement of an IP address
if [ "$ON_A_CLOUD" == "--on_a_cloud" ]; then
	sudo sed -i "s/^FRESH_INSTALLED=.*/FRESH_INSTALLED=1/" ${RUNFILE}
	sudo sed -i "s/^ON_A_CLOUD=.*/ON_A_CLOUD=1/" ${RUNFILE}
	sudo sed -i "s/=random/=permanent/" ${RUNFILE}
else
	sudo sed -i "s/^FRESH_INSTALLED=.*/FRESH_INSTALLED=3/" ${RUNFILE}
	sudo sed -i "s/^ON_A_CLOUD=.*/ON_A_CLOUD=0/" ${RUNFILE}
fi

if [ "$STEP_BY_STEP" = "--step_by_step" ]; then
	echo ""
	read -n 1 -s -r -p $'\e[1;31mPlease press any key to continue... \e[0m'
	clear
else
	sleep 10
fi

# 13. Adding and implementing the user torbox
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
sudo adduser --disabled-password --gecos "" torbox
echo -e "$DEFAULT_PASS\n$DEFAULT_PASS\n" | sudo passwd torbox
sudo adduser torbox sudo
sudo adduser torbox netdev
if ! sudo grep "# Added by TorBox" /etc/sudoers ; then
  sudo printf "\n# Added by TorBox\ntorbox  ALL=NOPASSWD:ALL\n" | sudo tee -a /etc/sudoers
  # or: sudo printf "\n# Added by TorBox\ntorbox  ALL=(ALL) NOPASSWD: ALL\n" | sudo tee -a /etc/sudoers --- HAST TO BE CHECKED AND COMPARED WITH THE USER "UBUNTU"!!
  (sudo visudo -c) 2>/dev/null
fi

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
echo -e "${RED}[+] Step 14: We are finishing and cleaning up now!${NOCOLOR}"
echo -e "${RED}[+]          This will erase all log files and cleaning up the system.${NOCOLOR}"
echo ""
echo -e "${YELLOW}[!] IMPORTANT${NOCOLOR}"
echo -e "${YELLOW}    After this last step, TorBox will reboot.${NOCOLOR}"
echo -e "${YELLOW}    To use TorBox, you have to log in with \"torbox\" and the default${NOCOLOR}"
echo -e "${YELLOW}    password \"$DEFAULT_PASS\"!! ${NOCOLOR}"
echo -e "${YELLOW}    If connecting via TorBox's WiFi (TorBox053) use \"CHANGE-IT\" as password.${NOCOLOR}"
echo -e "${YELLOW}    After rebooting, please, change the default passwords immediately!!${NOCOLOR}"
echo -e "${YELLOW}    The associated menu entries are placed in the configuration sub-menu.${NOCOLOR}"
echo ""
read -n 1 -s -r -p $'\e[1;31mTo complete the installation, please press any key... \e[0m'
clear
echo -e "${RED}[+] Erasing big not usefull packages...${NOCOLOR}"
(sudo rm -r WiringPi) 2>/dev/null
(sudo rm -r Downloads) 2>/dev/null
(sudo rm -r get-pip.py) 2>/dev/null
(sudo rm -r python-urwid*) 2>/dev/null
# Find the bigest space waster packages: dpigs -H
sudo apt-get -y --purge remove exim4 exim4-base exim4-config exim4-daemon-light
sudo apt-get -y remove libgl1-mesa-dri texlive* lmodern
sudo apt-get -y clean
sudo apt-get -y autoclean
sudo apt-get -y autoremove
echo -e "${RED}[+] Setting the timezone to UTC${NOCOLOR}"
sudo timedatectl set-timezone UTC
echo -e "${RED}[+] Setting up the hostname...${NOCOLOR}"
# NEW v.0.5.3
# This has to be at the end to avoid unnecessary error messages
(sudo hostnamectl set-hostname "$HOSTNAME") 2>/dev/null
sudo systemctl restart systemd-hostnamed
if grep "127.0.1.1.*" /etc/hosts ; then
	(sudo sed -i "s/127.0.1.1.*/127.0.1.1\t$HOSTNAME/g" /etc/hosts) 2>/dev/null
else
	(sudo sed -i "s/^::1/127.0.1.1\t$HOSTNAME\n::1/g" /etc/hosts) 2>/dev/null
fi
#
echo -e "${RED}[+] Moving TorBox files...${NOCOLOR}"
# TEST v.0.5.4: what is if another user is installing torbox?
cd
sudo mv * /home/torbox/
(sudo mv .profile /home/torbox/) 2>/dev/null
sudo mkdir /home/torbox/openvpn
(sudo rm .bash_history) 2>/dev/null
sudo chown -R torbox:torbox /home/torbox/
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
# To start TACA notices.log has to be present
(sudo -u debian-tor touch /var/log/tor/notices.log) 2>/dev/null
(sudo chmod -R go-rwx /var/log/tor/notices.log) 2>/dev/null
echo ""
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
sudo reboot
