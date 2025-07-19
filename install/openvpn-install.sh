#!/bin/bash
# shellcheck disable=SC1091,SC2129,SC2164,SC2034,SC1072,SC1073,SC1009

# This file is a part of TorBox, an easy to use anonymizing router based on Raspberry Pi.
# Copyright (C) 2024 Patrick Truffer
# Contact: anonym@torbox.ch
# Website: https://www.torbox.ch
# Github:  https://github.com/radio24/TorBox
#
# openvpn-install.sh is based on the Secure OpenVPN server installer for Debian, Ubuntu,
# CentOS, Amazon Linux 2, Fedora, Oracle Linux 8, Arch Linux, Rocky Linux and AlmaLinux,
# which is under MIT Licence (https://raw.githubusercontent.com/Angristan/openvpn-install/master/LICENSE)
# Github:  https://github.com/angristan/openvpn-install
#
# DESCRIPTION
# This script installs an openvpn server and manages the client ovpn-files.
#
# SYNTAX
# ./openvpn-install.sh
#
#
###### SET VARIABLES ######
#
#
# SIZE OF THE MENU
#
# How many items do you have in the main menu?
NO_ITEMS=4
#
# How many lines are only for decoration and spaces?
NO_SPACER=2
#
#Set the the variables for the menu
MENU_WIDTH=80
MENU_HEIGHT_20=20
MENU_HEIGHT_25=25
# MENU_HEIGHT should not exceed 26
MENU_HEIGHT=$((8+NO_ITEMS+NO_SPACER))
MENU_LIST_HEIGHT=$((NO_ITEMS+NO_SPACER))

#Colors (don't change it!)
RED='\033[1;31m'
YELLOW='\033[1;93m'
NOCOLOR='\033[0m'

# Other variables
OPENVPN_CONF_PATH="/etc/openvpn"
OPENVPN_CONF="$OPENVPN_CONF_PATH/server.conf"
TORBOX_PATH="/home/torbox/torbox"
CONFIG_PATH="$TORBOX_PATH/etc"
RUNFILE="$TORBOX_PATH/run/torbox.run"
TXT_DIR="$TORBOX_PATH/text"
ON_A_CLOUD=$1
OPENVPN_PORT=$(grep "^OPENVPN_PORT=.*" ${RUNFILE} | sed "s/.*=//g")
#Can be removed with v.0.5.5
if [ -z "$OPENVPN_PORT" ]; then OPENVPN_PORT="1194"; fi

######## PREPARATIONS ########
# Resetting
clear
sleep 1
shopt -s checkwinsize
[ -f nohup.out ] && sudo rm nohup.out
stty intr ^c
trap
clear
sleep 1

##############################
######## FUNCTIONS ###########

function isRoot() {
	if [ "$EUID" -ne 0 ]; then
		return 1
	fi
}

function tunAvailable() {
	if [ ! -e /dev/net/tun ]; then
		return 1
	fi
}

function checkOS() {
	if [[ -e /etc/debian_version ]]; then
		OS="debian"
		source /etc/os-release

		if [[ $ID == "debian" || $ID == "raspbian" ]]; then
			if [[ $VERSION_ID -lt 9 ]]; then
				echo "Your version of Debian is not supported."
				echo ""
				echo "However, if you're using Debian >= 9 or unstable/testing, you can continue at your own risk."
				echo ""
				until [[ $CONTINUE =~ (y|n) ]]; do
					read -rp "Continue? [y/n]: " -e CONTINUE
				done
				if [[ $CONTINUE == "n" ]]; then
					exit 1
				fi
			fi
		elif [[ $ID == "ubuntu" ]]; then
			OS="ubuntu"
			MAJOR_UBUNTU_VERSION=$(echo "$VERSION_ID" | cut -d '.' -f1)
			if [[ $MAJOR_UBUNTU_VERSION -lt 16 ]]; then
				echo "Your version of Ubuntu is not supported."
				echo ""
				echo "However, if you're using Ubuntu >= 16.04 or beta, you can continue at your own risk."
				echo ""
				until [[ $CONTINUE =~ (y|n) ]]; do
					read -rp "Continue? [y/n]: " -e CONTINUE
				done
				if [[ $CONTINUE == "n" ]]; then
					exit 1
				fi
			fi
		fi
	else
		echo "It looks like you aren't running this installer on a Rapberry PI OS, Debian or Ubuntu system."
		echo "Please report this error to anonym@torbox.ch"
		exit 1
	fi
}

function initialCheck() {
	if ! isRoot; then
		echo "Sorry, you need to run this script as root"
		exit 1
	fi
	if ! tunAvailable; then
		echo "TUN is not available."
		exit 1
	fi
	checkOS

	# TOGGLE01 shows if the OpenVPN server is disabled or not
	VPN_STATUS=""
	VPN_STATUS=$(sudo systemctl is-active openvpn)
	if [ $VPN_STATUS = inactive ] || [ $VPN_STATUS = failed ] ; then
		TOGGLE01="Enable"
		TOGGLE02=""
	else
		TOGGLE01="Disable"
		TOGGLE02="without touching the configuration"
	fi
}

function resolvePublicIP() {
	# IP version flags, we'll use as default the IPv4
	CURL_IP_VERSION_FLAG="-4"
	DIG_IP_VERSION_FLAG="-4"

	# Behind NAT, we'll default to the publicly reachable IPv4/IPv6.
	if [[ $IPV6_SUPPORT == "y" ]]; then
		CURL_IP_VERSION_FLAG=""
		DIG_IP_VERSION_FLAG="-6"
	fi

	# If there is no public ip yet, we'll try to solve it using: https://api.seeip.org
	if [[ -z $PUBLIC_IP ]]; then
		PUBLIC_IP=$(curl -f -m 5 -sS --retry 2 --retry-connrefused "$CURL_IP_VERSION_FLAG" https://api.seeip.org 2>/dev/null)
	fi

	# If there is no public ip yet, we'll try to solve it using: https://ifconfig.me
	if [[ -z $PUBLIC_IP ]]; then
		PUBLIC_IP=$(curl -f -m 5 -sS --retry 2 --retry-connrefused "$CURL_IP_VERSION_FLAG" https://ifconfig.me 2>/dev/null)
	fi

	# If there is no public ip yet, we'll try to solve it using: https://api.ipify.org
	if [[ -z $PUBLIC_IP ]]; then
		PUBLIC_IP=$(curl -f -m 5 -sS --retry 2 --retry-connrefused "$CURL_IP_VERSION_FLAG" https://api.ipify.org 2>/dev/null)
	fi

	# If there is no public ip yet, we'll try to solve it using: ns1.google.com
	if [[ -z $PUBLIC_IP ]]; then
		PUBLIC_IP=$(dig $DIG_IP_VERSION_FLAG TXT +short o-o.myaddr.l.google.com @ns1.google.com | tr -d '"')
	fi

	if [[ -z $PUBLIC_IP ]]; then
		echo >&2 echo "Couldn't solve the public IP"
		exit 1
	fi

	echo "$PUBLIC_IP"
}


function installQuestions() {
	clear
	echo -e "${YELLOW}[+] Hello!${NOCOLOR}"
	echo -e "${RED}[+] I need to ask you a few questions before starting the setup.${NOCOLOR}"
	echo -e "${RED}[+] You can leave the default options and just press enter if you are okay with them.${NOCOLOR}"
	echo ""
	echo -e "${RED}[+] I need to know the IPv4 address of the network interface you want OpenVPN listening to.${NOCOLOR}"
	echo -e "${RED}[+] On a Cloud: Unless your server is behind NAT, it should be your public IPv4 address, inserted below.${NOCOLOR}"
	echo -e "${RED}[+] On a real Box: It is dependent on your connection --> wlan0/1: 192.168.42.1 - eth0/1: 192.168.43.1.${NOCOLOR}"

	# Detect public IPv4 address and pre-fill for the client
	IP=$(ip -4 addr | sed -ne 's|^.* inet \([^/]*\)/.* scope global.*$|\1|p' | head -1)

	if [[ -z $IP ]]; then
		# Detect public IPv6 address
		IP=$(ip -6 addr | sed -ne 's|^.* inet6 \([^/]*\)/.* scope global.*$|\1|p' | head -1)
	fi
	read -rp "IP address: " -e -i "$IP" IP
	ON_A_CLOUD_RUNFILE=$(grep "^ON_A_CLOUD=.*" ${RUNFILE} | sed "s/.*=//g")
	if [ "$ON_A_CLOUD_RUNFILE" -eq "1" ]; then
		# If $IP is a private IP address, the server must be behind NAT
		if echo "$IP" | grep -qE '^(10\.|172\.1[6789]\.|172\.2[0-9]\.|172\.3[01]\.|192\.168)'; then
			sleep 3
			echo ""
			echo -e "${YELLOW}[!] It seems this server is behind NAT. What is its public IPv4 address or hostname?${NOCOLOR}"
			echo -e "${YELLOW}[!] We need it for the clients to connect to the server.${NOCOLOR}"

			# New v.0.5.4-post: Fix Public IP detection - Fix issue when seeip.org is unreachable. It solves the issue angristan#1241 (https://github.com/angristan/openvpn-install/issues/1241)
			if [[ -z $ENDPOINT ]]; then
				DEFAULT_ENDPOINT=$(resolvePublicIP)
			fi
			until [[ $ENDPOINT != "" ]]; do
				read -rp "Public IPv4 address or hostname: " -e -i "$DEFAULT_ENDPOINT" ENDPOINT
			done
		fi
	else
		ENDPOINT="$IP"
	fi

	echo ""
	echo -e "${RED}[+] Checking for IPv6 connectivity...${NOCOLOR}"
	echo ""
	# "ping6" and "ping -6" availability varies depending on the distribution
	if type ping6 >/dev/null 2>&1; then
		PING6="ping6 -c3 ipv6.google.com > /dev/null 2>&1"
	else
		PING6="ping -6 -c3 ipv6.google.com > /dev/null 2>&1"
	fi
	if eval "$PING6"; then
		echo -e "${YELLOW}[!] Your host appears to have IPv6 connectivity.${NOCOLOR}"
		SUGGESTION="y"
	else
		echo -e "${YELLOW}[!] Your host does not appear to have IPv6 connectivity.${NOCOLOR}"
		SUGGESTION="n"
	fi
	echo ""
	# Ask the user if they want to enable IPv6 regardless its availability.
	until [[ $IPV6_SUPPORT =~ (y|n) ]]; do
		read -rp "Do you want to enable IPv6 support (NAT)? [y/n]: " -e -i $SUGGESTION IPV6_SUPPORT
	done
	# In the original script, choosing the port number, the protocol (UDP or TCP) and the compression was possible.
	# We removed it for the sake of simplicity.
	# To add it again, see here: https://github.com/angristan/openvpn-install/blob/master/openvpn-install.sh
	PORT="1194"
	clear
	echo -e "${YELLOW}[+] Do you want to customize the VPN port (not recommended)?${NOCOLOR}"
	echo -e "${RED}[+] 1194 is the standard port, however, if blocked by a firewall, you might try another port.${NOCOLOR}"
	echo ""
	echo -e "${YELLOW}[!] IMPORTANT: Using a port number other than 1194 is risky and can seriously compromise your security!${NOCOLOR}"
	echo -e "${YELLOW}[!] ALL UDP traffic on this port number will go directly to and eventually through the TorBox by avoiding Tor.${NOCOLOR}"
	echo -e "${YELLOW}[!] For example, using 443 (UDP) let QIUC pass through the TorBox by avoiding the Tor network (see here: https://t.ly/UlrbR).${NOCOLOR}"
	read -rp "Port: " -e -i "$PORT" PORT
	if [ "$PORT" -ne "$OPENVPN_PORT" ]; then
		sed -i "s/--dport $OPENVPN_PORT/--dport $PORT/g" "$CONFIG_PATH"
		# shellcheck disable=SC2034
		(TRASH=$(sudo sh -c "iptables-save > /etc/iptables.ipv4.nat")) 2>/dev/null
		sed -i "s/--dport $OPENVPN_PORT/--dport $PORT/g" "/etc/iptables.ipv4.nat"
		sudo /sbin/iptables-restore < /etc/iptables.ipv4.nat
	fi
	PROTOCOL="udp"
	clear
	echo -e "${YELLOW}[+] Do you want to customize encryption settings?${NOCOLOR}"
	echo -e "${RED}[+] Unless you know what you're doing, you should stick with the default parameters provided.${NOCOLOR}"
	echo -e "${RED}[+] Note that whatever you choose, all the choices presented in the script are safe.${NOCOLOR}"
	#echo "See https://github.com/angristan/openvpn-install#security-and-encryption to learn more."
	echo ""
	until [[ $CUSTOMIZE_ENC =~ (y|n) ]]; do
		read -rp "Customize encryption settings? [y/n]: " -e -i n CUSTOMIZE_ENC
	done
	if [[ $CUSTOMIZE_ENC == "n" ]]; then
		# Use default, sane and fast parameters
		CIPHER="AES-128-GCM"
		CERT_TYPE="1" # ECDSA
		CERT_CURVE="prime256v1"
		CC_CIPHER="TLS-ECDHE-ECDSA-WITH-AES-128-GCM-SHA256"
		DH_TYPE="1" # ECDH
		DH_CURVE="prime256v1"
		HMAC_ALG="SHA256"
		TLS_SIG="1" # tls-crypt
	else
		clear
		echo -e "${YELLOW}[!] Choose which cipher you want to use for the data channel:${NOCOLOR}"
		echo "   1) AES-128-GCM (recommended)"
		echo "   2) AES-192-GCM"
		echo "   3) AES-256-GCM"
		echo "   4) AES-128-CBC"
		echo "   5) AES-192-CBC"
		echo "   6) AES-256-CBC"
		echo ""
		until [[ $CIPHER_CHOICE =~ ^[1-6]$ ]]; do
			read -rp "   Cipher [1-6]: " -e -i 1 CIPHER_CHOICE
		done
		case $CIPHER_CHOICE in
		1)
			CIPHER="AES-128-GCM"
			;;
		2)
			CIPHER="AES-192-GCM"
			;;
		3)
			CIPHER="AES-256-GCM"
			;;
		4)
			CIPHER="AES-128-CBC"
			;;
		5)
			CIPHER="AES-192-CBC"
			;;
		6)
			CIPHER="AES-256-CBC"
			;;
		esac
		clear
		echo -e "${YELLOW}[!] Choose what kind of certificate you want to use:${NOCOLOR}"
		echo "   1) ECDSA (recommended)"
		echo "   2) RSA"
		echo ""
		until [[ $CERT_TYPE =~ ^[1-2]$ ]]; do
			read -rp"   Certificate key type [1-2]: " -e -i 1 CERT_TYPE
		done
		case $CERT_TYPE in
		1)
			clear
			echo -e "${YELLOW}[!] Choose which curve you want to use for the certificate's key:${NOCOLOR}"
			echo "   1) prime256v1 (recommended)"
			echo "   2) secp384r1"
			echo "   3) secp521r1"
			echo ""
			until [[ $CERT_CURVE_CHOICE =~ ^[1-3]$ ]]; do
				read -rp"   Curve [1-3]: " -e -i 1 CERT_CURVE_CHOICE
			done
			case $CERT_CURVE_CHOICE in
			1)
				CERT_CURVE="prime256v1"
				;;
			2)
				CERT_CURVE="secp384r1"
				;;
			3)
				CERT_CURVE="secp521r1"
				;;
			esac
			;;
		2)
			clear
			echo -e "${YELLOW}[!] Choose which size you want to use for the certificate's RSA key:${NOCOLOR}"
			echo "   1) 2048 bits (recommended)"
			echo "   2) 3072 bits"
			echo "   3) 4096 bits"
			echo ""
			until [[ $RSA_KEY_SIZE_CHOICE =~ ^[1-3]$ ]]; do
				read -rp "   RSA key size [1-3]: " -e -i 1 RSA_KEY_SIZE_CHOICE
			done
			case $RSA_KEY_SIZE_CHOICE in
			1)
				RSA_KEY_SIZE="2048"
				;;
			2)
				RSA_KEY_SIZE="3072"
				;;
			3)
				RSA_KEY_SIZE="4096"
				;;
			esac
			;;
		esac
		clear
		echo -e "${YELLOW}[!] Choose which cipher you want to use for the control channel:${NOCOLOR}"
		case $CERT_TYPE in
		1)
			echo "   1) ECDHE-ECDSA-AES-128-GCM-SHA256 (recommended)"
			echo "   2) ECDHE-ECDSA-AES-256-GCM-SHA384"
			echo ""
			until [[ $CC_CIPHER_CHOICE =~ ^[1-2]$ ]]; do
				read -rp"   Control channel cipher [1-2]: " -e -i 1 CC_CIPHER_CHOICE
			done
			case $CC_CIPHER_CHOICE in
			1)
				CC_CIPHER="TLS-ECDHE-ECDSA-WITH-AES-128-GCM-SHA256"
				;;
			2)
				CC_CIPHER="TLS-ECDHE-ECDSA-WITH-AES-256-GCM-SHA384"
				;;
			esac
			;;
		2)
			echo "   1) ECDHE-RSA-AES-128-GCM-SHA256 (recommended)"
			echo "   2) ECDHE-RSA-AES-256-GCM-SHA384"
			echo ""
			until [[ $CC_CIPHER_CHOICE =~ ^[1-2]$ ]]; do
				read -rp"   Control channel cipher [1-2]: " -e -i 1 CC_CIPHER_CHOICE
			done
			case $CC_CIPHER_CHOICE in
			1)
				CC_CIPHER="TLS-ECDHE-RSA-WITH-AES-128-GCM-SHA256"
				;;
			2)
				CC_CIPHER="TLS-ECDHE-RSA-WITH-AES-256-GCM-SHA384"
				;;
			esac
			;;
		esac
		clear
		echo -e "${YELLOW}[!] Choose what kind of Diffie-Hellman key you want to use:${NOCOLOR}"
		echo "   1) ECDH (recommended)"
		echo "   2) DH"
		echo ""
		until [[ $DH_TYPE =~ [1-2] ]]; do
			read -rp"   DH key type [1-2]: " -e -i 1 DH_TYPE
		done
		case $DH_TYPE in
		1)
			clear
			echo -e "${YELLOW}[!] Choose which curve you want to use for the ECDH key:${NOCOLOR}"
			echo "   1) prime256v1 (recommended)"
			echo "   2) secp384r1"
			echo "   3) secp521r1"
			echo ""
			while [[ $DH_CURVE_CHOICE != "1" && $DH_CURVE_CHOICE != "2" && $DH_CURVE_CHOICE != "3" ]]; do
				read -rp"   Curve [1-3]: " -e -i 1 DH_CURVE_CHOICE
			done
			case $DH_CURVE_CHOICE in
			1)
				DH_CURVE="prime256v1"
				;;
			2)
				DH_CURVE="secp384r1"
				;;
			3)
				DH_CURVE="secp521r1"
				;;
			esac
			;;
		2)
			clear
			echo -e "${YELLOW}[!] Choose what size of Diffie-Hellman key you want to use:${NOCOLOR}"
			echo "   1) 2048 bits (recommended)"
			echo "   2) 3072 bits"
			echo "   3) 4096 bits"
			echo ""
			until [[ $DH_KEY_SIZE_CHOICE =~ ^[1-3]$ ]]; do
				read -rp "   DH key size [1-3]: " -e -i 1 DH_KEY_SIZE_CHOICE
			done
			case $DH_KEY_SIZE_CHOICE in
			1)
				DH_KEY_SIZE="2048"
				;;
			2)
				DH_KEY_SIZE="3072"
				;;
			3)
				DH_KEY_SIZE="4096"
				;;
			esac
			;;
		esac
		echo ""
		# The "auth" options behaves differently with AEAD ciphers
		if [[ $CIPHER =~ CBC$ ]]; then
			echo "The digest algorithm authenticates data channel packets and tls-auth packets from the control channel."
		elif [[ $CIPHER =~ GCM$ ]]; then
			echo "The digest algorithm authenticates tls-auth packets from the control channel."
		fi
		sleep 3
		clear
		echo -e "${YELLOW}[!] Which digest algorithm do you want to use for HMAC?${NOCOLOR}"
		echo "   1) SHA-256 (recommended)"
		echo "   2) SHA-384"
		echo "   3) SHA-512"
		echo ""
		until [[ $HMAC_ALG_CHOICE =~ ^[1-3]$ ]]; do
			read -rp "   Digest algorithm [1-3]: " -e -i 1 HMAC_ALG_CHOICE
		done
		case $HMAC_ALG_CHOICE in
		1)
			HMAC_ALG="SHA256"
			;;
		2)
			HMAC_ALG="SHA384"
			;;
		3)
			HMAC_ALG="SHA512"
			;;
		esac
		clear
		echo -e "${YELLOW}[!] You can add an additional layer of security to the control channel with tls-auth and tls-crypt;${NOCOLOR}"
		echo -e "${YELLOW}[!] tls-auth authenticates the packets, while tls-crypt authenticate and encrypt them.${NOCOLOR}"
		echo "   1) tls-crypt (recommended)"
		echo "   2) tls-auth"
		echo ""
		until [[ $TLS_SIG =~ [1-2] ]]; do
			read -rp "Control channel additional security mechanism [1-2]: " -e -i 1 TLS_SIG
		done
	fi
	clear
	echo -e "${RED}[+] Okay, that was all I needed. We are ready to configure your OpenVPN server now.${NOCOLOR}"
	echo -e "${RED}[+] You will be able to generate a client ovpn-file at the end of the configuration.${NOCOLOR}"
	echo ""
	echo -e "${NOCOLOR}    After the generation, download the ovpn-file from the TorBox's home directory to your client machine."
	echo -e "${NOCOLOR}    You can access it by using an SFTP client (it uses the same login and password as your SSH client)."
	echo -e "${NOCOLOR}    Use the ovpn-file with the OpenVPN Connect client software: https://openvpn.net/client/."
	echo -e "${NOCOLOR}    With a MacOS client, we recommend Tunnelblick because of its security features: https://tunnelblick.net/"
	echo ""
	echo -e "${YELLOW}[!] IMPORTANT 1: To activate the OpenVPN Server, you have to select again the Internet source in the Main Menu (entry 5-10)!${NOCOLOR}"
	echo -e "${YELLOW}[!] IMPORTANT 2: Every client machine needs its seperate ovpn-file!${NOCOLOR}"
	echo ""
	read -n1 -r -p "Press any key to continue..."
}

function installOpenVPN() {
	# Information: The auto-installatin feature from the orginal script is removed.
	# Answer setup questions first
	installQuestions

	# Get the "public" interface from the default route
	NIC=$(ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)' | head -1)
	if [[ -z $NIC ]] && [[ $IPV6_SUPPORT == 'y' ]]; then
		NIC=$(ip -6 route show default | sed -ne 's/^default .* dev \([^ ]*\) .*$/\1/p')
	fi

	# $NIC can not be empty for script rm-openvpn-rules.sh
	if [[ -z $NIC ]]; then
		echo
		echo "Could not detect public interface."
		echo "This needs for setup MASQUERADE."
		until [[ $CONTINUE =~ (y|n) ]]; do
			read -rp "Continue? [y/n]: " -e CONTINUE
		done
		if [[ $CONTINUE == "n" ]]; then
			exit 1
		fi
	fi

	# Find out if the machine uses nogroup or nobody for the permissionless group
	if grep -qs "^nogroup:" /etc/group; then
		NOGROUP=nogroup
	else
		NOGROUP=nobody
	fi

	# Install the latest version of easy-rsa from source, if not already installed.
	if [[ ! -d $OPENVPN_CONF_PATH/easy-rsa/ ]]; then
		# There are new versions, but compatibility could be a problem --> may check later
		local version="3.1.2"
		wget -O ~/easy-rsa.tgz https://github.com/OpenVPN/easy-rsa/releases/download/v${version}/EasyRSA-${version}.tgz
		mkdir -p $OPENVPN_CONF_PATH/easy-rsa
		tar xzf ~/easy-rsa.tgz --strip-components=1 --no-same-owner --directory $OPENVPN_CONF_PATH/easy-rsa
		rm -f ~/easy-rsa.tgz

		cd $OPENVPN_CONF_PATH/easy-rsa/ || return
		case $CERT_TYPE in
		1)
			echo "set_var EASYRSA_ALGO ec" >vars
			echo "set_var EASYRSA_CURVE $CERT_CURVE" >>vars
			;;
		2)
			echo "set_var EASYRSA_KEY_SIZE $RSA_KEY_SIZE" >vars
			;;
		esac

		# Generate a random, alphanumeric identifier of 16 characters for CN and one for server name
		SERVER_CN="cn_$(head /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)"
		echo "$SERVER_CN" >SERVER_CN_GENERATED
		SERVER_NAME="server_$(head /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)"
		echo "$SERVER_NAME" >SERVER_NAME_GENERATED

		# Create the PKI, set up the CA, the DH params and the server certificate
		./easyrsa init-pki
		EASYRSA_CA_EXPIRE=3650 ./easyrsa --batch --req-cn="$SERVER_CN" build-ca nopass

		if [[ $DH_TYPE == "2" ]]; then
			# ECDH keys are generated on-the-fly so we don't need to generate them beforehand
			openssl dhparam -out dh.pem $DH_KEY_SIZE
		fi

		EASYRSA_CA_EXPIRE=3650 ./easyrsa --batch build-server-full "$SERVER_NAME" nopass
		EASYRSA_CRL_DAYS=3650 ./easyrsa gen-crl

		case $TLS_SIG in
		1)
			# Generate tls-crypt key
			openvpn --genkey --secret $OPENVPN_CONF_PATH/tls-crypt.key
			;;
		2)
			# Generate tls-auth key
			openvpn --genkey --secret $OPENVPN_CONF_PATH/tls-auth.key
			;;
		esac
	else
		# If easy-rsa is already installed, grab the generated SERVER_NAME
		# for client configs
		cd $OPENVPN_CONF_PATH/easy-rsa/ || return
		SERVER_NAME=$(cat SERVER_NAME_GENERATED)
	fi

	# Move all the generated files
	cp pki/ca.crt pki/private/ca.key "pki/issued/$SERVER_NAME.crt" "pki/private/$SERVER_NAME.key" $OPENVPN_CONF_PATH/easy-rsa/pki/crl.pem $OPENVPN_CONF_PATH
	if [[ $DH_TYPE == "2" ]]; then
		cp dh.pem $OPENVPN_CONF_PATH
	fi

	# Make cert revocation list readable for non-root
	chmod 644 $OPENVPN_CONF_PATH/crl.pem

	# Generate server.conf
	echo "port $PORT" >$OPENVPN_CONF
	if [[ $IPV6_SUPPORT == 'n' ]]; then
		echo "proto $PROTOCOL" >>$OPENVPN_CONF
	elif [[ $IPV6_SUPPORT == 'y' ]]; then
		echo "proto ${PROTOCOL}6" >>$OPENVPN_CONF
	fi

	# Changed by torbox: dev tun -> dev tun1
	# Changed by torbox: 10.8.0.0 -> 192.168.44.0
	echo "dev tun1
user nobody
group $NOGROUP
persist-key
persist-tun
keepalive 10 120
topology subnet
server 192.168.44.0 255.255.255.0
ifconfig-pool-persist ipp.txt" >>$OPENVPN_CONF

	# DNS resolvers
	# Current system resolvers
	# Locate the proper resolv.conf
	# Needed for systems running systemd-resolved
	if grep -q "127.0.0.53" "/etc/resolv.conf"; then
		RESOLVCONF='/run/systemd/resolve/resolv.conf'
	else
		RESOLVCONF='/etc/resolv.conf'
	fi
	# Obtain the resolvers from resolv.conf and use them for OpenVPN
	sed -ne 's/^nameserver[[:space:]]\+\([^[:space:]]\+\).*$/\1/p' $RESOLVCONF | while read -r line
	do
		# Copy, if it's a IPv4 |or| if IPv6 is enabled, IPv4/IPv6 does not matter
		if [[ $line =~ ^[0-9.]*$ ]] || [[ $IPV6_SUPPORT == 'y' ]]; then
			# Not sure if this is really necessary (remove it, if clients don't resolve domain names)
			echo "push \"dhcp-option DNS $line\"" >>$OPENVPN_CONF
		fi
	done
	echo 'push "redirect-gateway def1 bypass-dhcp"' >>$OPENVPN_CONF

	# IPv6 network settings if needed
	if [[ $IPV6_SUPPORT == 'y' ]]; then
		echo 'server-ipv6 fd42:42:42:42::/112
tun-ipv6
push tun-ipv6
push "route-ipv6 2000::/3"
push "redirect-gateway ipv6"' >>$OPENVPN_CONF
	fi

	if [[ $DH_TYPE == "1" ]]; then
		echo "dh none" >>$OPENVPN_CONF
		echo "ecdh-curve $DH_CURVE" >>$OPENVPN_CONF
	elif [[ $DH_TYPE == "2" ]]; then
		echo "dh dh.pem" >>$OPENVPN_CONF
	fi

	case $TLS_SIG in
	1)
		echo "tls-crypt tls-crypt.key" >>$OPENVPN_CONF
		;;
	2)
		echo "tls-auth tls-auth.key 0" >>$OPENVPN_CONF
		;;
	esac

	echo "crl-verify crl.pem
ca ca.crt
cert $SERVER_NAME.crt
key $SERVER_NAME.key
auth $HMAC_ALG
cipher $CIPHER
ncp-ciphers $CIPHER
tls-server
tls-version-min 1.2
tls-cipher $CC_CIPHER
client-config-dir $OPENVPN_CONF_PATH/ccd
status /var/log/openvpn/status.log
verb 3" >>$OPENVPN_CONF

	# Create client-config-dir dir
	mkdir -p $OPENVPN_CONF_PATH/ccd
	# Create log dir
	mkdir -p /var/log/openvpn

	# Enable routing
	echo 'net.ipv4.ip_forward=1' >/etc/sysctl.d/99-openvpn.conf
	if [[ $IPV6_SUPPORT == 'y' ]]; then
		echo 'net.ipv6.conf.all.forwarding=1' >>/etc/sysctl.d/99-openvpn.conf
	fi
	# Apply sysctl rules
	sysctl --system

	# If SELinux is enabled and a custom port was selected, we need this
	if hash sestatus 2>/dev/null; then
		if sestatus | grep "Current mode" | grep -qs "enforcing"; then
			if [[ $PORT != '443' ]]; then
				semanage port -a -t openvpn_port_t -p "$PROTOCOL" "$PORT"
			fi
		fi
	fi

	# Setting torbox.run
	sudo sed -i "s/^OPENVPN_FROM_INTERNET=.*/OPENVPN_FROM_INTERNET=1/" ${RUNFILE}
	sudo sed -i "s/^OPENVPN_PORT=.*/OPENVPN_FROM_INTERNET=$PORT/" ${RUNFILE}

	# Finally, restart and enable OpenVPN
		# Don't modify package-provided service
		cp /lib/systemd/system/openvpn\@.service /etc/systemd/system/openvpn\@.service

		# Workaround to fix OpenVPN service on OpenVZ
		sed -i 's|LimitNPROC|#LimitNPROC|' /etc/systemd/system/openvpn\@.service
		# Another workaround to keep using /etc/openvpn/
		sed -i 's|/etc/openvpn/server|/etc/openvpn|' /etc/systemd/system/openvpn\@.service

		systemctl daemon-reload
		systemctl unmask openvpn@server
		systemctl enable openvpn@server
		systemctl restart openvpn@server
		systemctl unmask openvpn
		systemctl enable openvpn
		systemctl restart openvpn
		systemctl daemon-reload

	# NOT NECESSARY --> we have our own iptables rules
	# Add iptables rules in two scripts
	# mkdir -p /etc/iptables

	# Changed by torbox: dev tun0 -> dev tun1
	# Changed by torbox: 10.8.0.0 -> 192.168.44.0
	# Script to add rules
	# echo "#!/bin/sh
	# iptables -t nat -I POSTROUTING 1 -s 192.168.44.0/24 -o $NIC -j MASQUERADE
	# iptables -I INPUT 1 -i tun1 -j ACCEPT
	# iptables -I FORWARD 1 -i $NIC -o tun1 -j ACCEPT
	# iptables -I FORWARD 1 -i tun1 -o $NIC -j ACCEPT
	# iptables -I INPUT 1 -i $NIC -p $PROTOCOL --dport $PORT -j ACCEPT" >/etc/iptables/add-openvpn-rules.sh

	# if [[ $IPV6_SUPPORT == 'y' ]]; then
	#	echo "ip6tables -t nat -I POSTROUTING 1 -s fd42:42:42:42::/112 -o $NIC -j MASQUERADE
	# ip6tables -I INPUT 1 -i tun1 -j ACCEPT
	# ip6tables -I FORWARD 1 -i $NIC -o tun1 -j ACCEPT
	# ip6tables -I FORWARD 1 -i tun1 -o $NIC -j ACCEPT
	# ip6tables -I INPUT 1 -i $NIC -p $PROTOCOL --dport $PORT -j ACCEPT" >>/etc/iptables/add-openvpn-rules.sh
	#	fi

	# Script to remove rules
	#	echo "#!/bin/sh
	# iptables -t nat -D POSTROUTING -s 192.168.44.0/24 -o $NIC -j MASQUERADE
	# iptables -D INPUT -i tun1 -j ACCEPT
	# iptables -D FORWARD -i $NIC -o tun1 -j ACCEPT
	# iptables -D FORWARD -i tun1 -o $NIC -j ACCEPT
	# iptables -D INPUT -i $NIC -p $PROTOCOL --dport $PORT -j ACCEPT" >/etc/iptables/rm-openvpn-rules.sh

	#	if [[ $IPV6_SUPPORT == 'y' ]]; then
	#		echo "ip6tables -t nat -D POSTROUTING -s fd42:42:42:42::/112 -o $NIC -j MASQUERADE
	# ip6tables -D INPUT -i tun1 -j ACCEPT
	# ip6tables -D FORWARD -i $NIC -o tun1 -j ACCEPT
	# ip6tables -D FORWARD -i tun1 -o $NIC -j ACCEPT
	# ip6tables -D INPUT -i $NIC -p $PROTOCOL --dport $PORT -j ACCEPT" >>/etc/iptables/rm-openvpn-rules.sh
	#	fi

	# chmod +x /etc/iptables/add-openvpn-rules.sh
	# chmod +x /etc/iptables/rm-openvpn-rules.sh

	# Handle the rules via a systemd script
	# echo "[Unit]
#Description=iptables rules for OpenVPN
#Before=network-online.target
#Wants=network-online.target

#[Service]
#Type=oneshot
#ExecStart=/etc/iptables/add-openvpn-rules.sh
#ExecStop=/etc/iptables/rm-openvpn-rules.sh
#RemainAfterExit=yes

#[Install]
#WantedBy=multi-user.target" >/etc/systemd/system/iptables-openvpn.service

	# Enable service and apply rules
	# systemctl daemon-reload
	# systemctl enable iptables-openvpn
	# systemctl start iptables-openvpn

	# If the server is behind a NAT, use the correct IP address for the clients to connect to
	if [[ $ENDPOINT != "" ]]; then
		IP=$ENDPOINT
	fi

	# client-template.txt is created so we have a template to add further users later
	echo "client" >$OPENVPN_CONF_PATH/client-template.txt
	echo "proto udp" >>$OPENVPN_CONF_PATH/client-template.txt
	echo "explicit-exit-notify" >>$OPENVPN_CONF_PATH/client-template.txt
	echo "remote $IP $PORT
dhcp-option DNS 192.168.44.1
dev tun
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
verify-x509-name $SERVER_NAME name
auth $HMAC_ALG
auth-nocache
cipher $CIPHER
tls-client
tls-version-min 1.2
tls-cipher $CC_CIPHER
ignore-unknown-option block-outside-dns
setenv opt block-outside-dns # Prevent Windows 10 DNS leak
verb 3" >>$OPENVPN_CONF_PATH/client-template.txt

	# Generate the custom client.ovpn
	newClient
	# Remove or change:
	echo "If you want to add more clients, you simply need to run this script another time!"
}

function newClient() {
	clear
	echo -e "${YELLOW}[+] Creating a ovpn-file for one (1) client...${NOCOLOR}"
	echo -e "${RED}[+] Tell me a name for the client.${NOCOLOR}"
	echo "    The name must consist of alphanumeric character. It may also include an underscore or a dash."

	until [[ $CLIENT =~ ^[a-zA-Z0-9_-]+$ ]]; do
		read -rp "    Client name: " -e CLIENT
	done

	echo ""
	echo -e "${RED}[+] Do you want to protect the configuration file with a password?${NOCOLOR}"
	echo -e "${RED}[+] (e.g. encrypt the private key with a password)${NOCOLOR}"
	echo "    1) Add a passwordless client"
	echo "    2) Use a password for the client"

	until [[ $PASS =~ ^[1-2]$ ]]; do
		read -rp "    Select an option [1-2]: " -e -i 1 PASS
	done

	# Changed based on https://github.com/angristan/openvpn-install/pull/1185/files
	# CLIENTEXISTS=$(tail -n +2 /etc/openvpn/easy-rsa/pki/index.txt | grep -c -E "/CN=$CLIENT\$")
	# if [[ $CLIENTEXISTS == '1' ]]; then
	CLIENTEXISTS=$(tail -n +2 $OPENVPN_CONF_PATH/easy-rsa/pki/index.txt | grep -E "^V" | grep -c -E "/CN=$CLIENT\$")
	if [[ $CLIENTEXISTS != '0' ]]; then
		echo ""
		echo -e "${YELLOW}[!] The specified client name was already found, please choose another one.${NOCOLOR}"
		exit
	else
		cd $OPENVPN_CONF_PATH/easy-rsa/ || return
		case $PASS in
		1)
			EASYRSA_CERT_EXPIRE=3650 ./easyrsa --batch build-client-full "$CLIENT" nopass
			;;
		2)
			echo ""
			echo -e "${YELLOW}[!] You will be asked for the client password below...${NOCOLOR}"
			EASYRSA_CERT_EXPIRE=3650 ./easyrsa --batch build-client-full "$CLIENT"
			;;
		esac
		echo ""
		echo -e "${YELLOW}[+] DONE! Client $CLIENT added.${NOCOLOR}"
		echo ""
		read -n1 -r -p "Press any key to continue..."
	fi

	# Home directory of the user, where the client configuration will be written
	homeDir="/home/torbox"

	# Determine if we use tls-auth or tls-crypt
	if grep -qs "^tls-crypt" $OPENVPN_CONF; then
		TLS_SIG="1"
	elif grep -qs "^tls-auth" $OPENVPN_CONF; then
		TLS_SIG="2"
	fi

	# Generates the custom client.ovpn
	cp $OPENVPN_CONF_PATH/client-template.txt "$homeDir/$CLIENT.ovpn"
	{
		echo "<ca>"
		cat "$OPENVPN_CONF_PATH/easy-rsa/pki/ca.crt"
		echo "</ca>"

		echo "<cert>"
		awk '/BEGIN/,/END CERTIFICATE/' "$OPENVPN_CONF_PATH/easy-rsa/pki/issued/$CLIENT.crt"
		echo "</cert>"

		echo "<key>"
		cat "$OPENVPN_CONF_PATH/easy-rsa/pki/private/$CLIENT.key"
		echo "</key>"

		case $TLS_SIG in
		1)
			echo "<tls-crypt>"
			cat $OPENVPN_CONF_PATH/tls-crypt.key
			echo "</tls-crypt>"
			;;
		2)
			echo "key-direction 1"
			echo "<tls-auth>"
			cat $OPENVPN_CONF_PATH/tls-auth.key
			echo "</tls-auth>"
			;;
		esac
	} >>"$homeDir/$CLIENT.ovpn"
	chown torbox:torbox "$homeDir/$CLIENT.ovpn"

	clear
	echo -e "${YELLOW}[+] All done! The ovpn-file has been written to $homeDir/$CLIENT.ovpn.${NOCOLOR}"
	echo -e "${RED}[+] Download the ovpn-file to your client machine.${NOCOLOR}"
	echo -e "${RED}[+] You will be able to generate a client ovpn-file at the end of the configuration.${NOCOLOR}"
	echo -e "${RED}[+] You can access it by using a SFTP client (it uses the same login and password as your SSH client).${NOCOLOR}"
	echo -e "${RED}[+] Use the ovpn-file with the OpenVPN Connect client software: https://openvpn.net/client/.${NOCOLOR}"
	echo -e "${RED}[+] With a MacOS client, we recommend Tunnelblick because of its security features: https://tunnelblick.net/"
	echo ""
	echo -e "${YELLOW}[!] IMPORTANT: Every client machine needs its seperate ovpn-file!${NOCOLOR}"
	echo ""
	read -n1 -r -p "Press any key to continue..."
	exit 0
}

function revokeClient() {
	NUMBEROFCLIENTS=$(tail -n +2 $OPENVPN_CONF_PATH/easy-rsa/pki/index.txt | grep -c "^V")
	if [[ $NUMBEROFCLIENTS == '0' ]]; then
		clear
		echo -e "${YELLOW}[!] You have no existing clients!${NOCOLOR}"
		exit 1
	fi

	clear
	echo -e "${RED}[+] Select the existing client certificate you want to revoke${NOCOLOR}"
	tail -n +2 $OPENVPN_CONF_PATH/easy-rsa/pki/index.txt | grep "^V" | cut -d '=' -f 2 | nl -s ') '
	trap "sudo bash /home/torbox/torbox/install/openvpn-install.sh; exit 0" SIGINT
	stty intr q
	until [[ $CLIENTNUMBER -ge 1 && $CLIENTNUMBER -le $NUMBEROFCLIENTS ]]; do
		if [[ $CLIENTNUMBER == '1' ]]; then
			read -rp "    Select one client [1; q->quit]: " CLIENTNUMBER
		else
			read -rp "    Select one client [1-$NUMBEROFCLIENTS; q->quit]]: " CLIENTNUMBER
		fi
	done
	stty intr ^c
	CLIENT=$(tail -n +2 $OPENVPN_CONF_PATH/easy-rsa/pki/index.txt | grep "^V" | cut -d '=' -f 2 | sed -n "$CLIENTNUMBER"p)
	cd $OPENVPN_CONF_PATH/easy-rsa/ || return
	./easyrsa --batch revoke "$CLIENT"
	# Added based on https://github.com/angristan/openvpn-install/pull/1185/files
	./easyrsa upgrade ca
	EASYRSA_CRL_DAYS=3650 ./easyrsa gen-crl
	rm -f $OPENVPN_CONF_PATH/crl.pem
	cp $OPENVPN_CONF_PATH/easy-rsa/pki/crl.pem $OPENVPN_CONF_PATH/crl.pem
	chmod 644 $OPENVPN_CONF_PATH/crl.pem
	if [ -f "/home/torbox/$CLIENT.ovpn" ]; then rm "/home/torbox/$CLIENT.ovpn"; fi
	sed -i "/^$CLIENT,.*/d" $OPENVPN_CONF_PATH/ipp.txt
	cp $OPENVPN_CONF_PATH/easy-rsa/pki/index.txt{,.bk}

	echo ""
	echo -e "${YELLOW}[+] Done! Certificate for client $CLIENT revoked.${NOCOLOR}"
	echo ""
	read -n1 -r -p "Press any key to continue..."
}

function stopOpenVPN() {
	clear
	if [ "$TOGGLE01" = "Disable" ]; then
		INPUT=$(cat text/disable_openvpn-text)
		DISABLED_CHOICE=$(whiptail --nocancel --title "TorBox - INFO" --radiolist "$INPUT" $MENU_HEIGHT_20 $MENU_WIDTH 2 \
		"1" "Temporary   - Disable the OpenVPN server until next boot" OFF \
		"2" "Permanently - Disable the OpenVPN server until enabled again" OFF 3>&1 1>&2 2>&3)
		exitstatus=$?
		if [ $exitstatus = 0 ]; then
			if [ ! -z "$DISABLED_CHOICE" ]; then
				if [ $DISABLED_CHOICE = 1 ]; then
					clear
					echo " "
					echo -e "${RED}[+] Temporary disabling the OpenVPN server...${NOCOLOR}"
					sudo systemctl stop openvpn@server
					sudo systemctl stop openvpn
					sudo systemctl daemon-reload
					sleep 2
				elif [ $DISABLED_CHOICE = 2 ]; then
					clear
					echo -e "${RED}[+] Permanently disabling the OpenVPN server...${NOCOLOR}"
					sudo systemctl mask --now openvpn@server
					sudo systemctl mask --now openvpn
					sudo systemctl daemon-reload
					# Setting torbox.run
					sudo sed -i "s/^OPENVPN_FROM_INTERNET=.*/OPENVPN_FROM_INTERNET=0/" ${RUNFILE}
					sleep 2
				fi
			fi
		else
			clear
		fi
	else
		clear
		read -rp $'\e[1;93mDo you want to enable OpenVPN? [y/n]: \e[0m' -e ENABLE
		if [[ $ENABLE == 'y' ]]; then
				clear
				echo -e "${RED}[+] Enabling TorBox's WLAN now...${NOCOLOR}"
				sudo systemctl unmask openvpn@server
				sudo systemctl unmask openvpn
				sudo systemctl enable openvpn@server
				sudo systemctl enable openvpn
				sudo systemctl start openvpn@server
				sudo systemctl start openvpn
				# Setting torbox.run
				sudo sed -i "s/^OPENVPN_FROM_INTERNET=.*/OPENVPN_FROM_INTERNET=1/" ${RUNFILE}
				sleep 2
			fi
	fi
}

function removeOpenVPN() {
	clear
	read -rp $'\e[1;93mDo you really want to remove OpenVPN? [y/n]: \e[0m' -e -i n REMOVE
	if [[ $REMOVE == 'y' ]]; then
		# Get OpenVPN port from the configuration
		PORT=$(grep '^port ' $OPENVPN_CONF | cut -d " " -f 2)
		PROTOCOL=$(grep '^proto ' $OPENVPN_CONF | cut -d " " -f 2)

		# Stop OpenVPN
		if [[ $OS == "ubuntu" ]] && [[ $VERSION_ID == "16.04" ]]; then
			sudo systemctl disable openvpn
			sudo systemctl stop openvpn
		else
			sudo systemctl disable openvpn@server
			sudo systemctl stop openvpn@server
			# Remove customised service
			if [ -f /etc/systemd/system/openvpn\@.service ]; then rm /etc/systemd/system/openvpn\@.service; fi
			sudo systemctl mask --now openvpn@server
			sudo systemctl disable openvpn
			sudo systemctl stop openvpn
			sudo systemctl mask --now openvpn
		fi
		sudo systemctl daemon-reload

		# SELinux
		if hash sestatus 2>/dev/null; then
			if sestatus | grep "Current mode" | grep -qs "enforcing"; then
				if [[ $PORT != '443' ]]; then
					semanage port -d -t openvpn_port_t -p "$PROTOCOL" "$PORT"
				fi
			fi
		fi

		# Cleanup
		rm -r $OPENVPN_CONF_PATH/ca.crt
		rm -r $OPENVPN_CONF_PATH/ca.key
		rm -r $OPENVPN_CONF_PATH/client-template.txt
		# Not sure - to check
		# rm -rf $OPENVPN_CONF_PATH/crl.pem
		rm -r $OPENVPN_CONF_PATH/easy-rsa
		rm -r $OPENVPN_CONF_PATH/ipp.txt
		rm -r $OPENVPN_CONF
		rm -r $OPENVPN_CONF_PATH/server_*
		rm -f $OPENVPN_CONF_PATH/tls-crypt.key
		rm -f /etc/sysctl.d/99-openvpn.conf
		rm -r /var/log/openvpn
		# Setting torbox.run
		sudo sed -i "s/^OPENVPN_FROM_INTERNET=.*/OPENVPN_FROM_INTERNET=0/" ${RUNFILE}
		echo ""
		echo -e "${YELLOW}[+] OpenVPN removed!${NOCOLOR}"
		sleep 2
	else
		echo ""
		echo -e "${YELLOW}[+] OpenVPN removal aborted!${NOCOLOR}"
		sleep 2
	fi
}

function manageMenu() {
	######## PREPARATIONS ########
	# Resetting
	shopt -s checkwinsize
	[ -f nohup.out ] && sudo rm nohup.out
	stty intr ^c
	trap

	###### DISPLAY THE MENU ######
	clear
	CHOICE=$(whiptail --cancel-button "Back" --title "TorBox v.0.5.4 - OpenVPN Server Management" --menu "Choose an option (ESC -> back to the main menu)" $MENU_HEIGHT $MENU_WIDTH $MENU_LIST_HEIGHT \
	"==" "===============================================================" \
	" 1" "Add a new client"  \
	" 2" "Revoke an existing client"  \
	" 3" "$TOGGLE01 the OpenVPN server $TOGGLE02"  \
	" 4" "Remove the OpenVPN server capability and configuration" \
	"==" "===============================================================" \
	3>&1 1>&2 2>&3)
	exitstatus=$?
	# exitstatus == 255 means that the ESC key was pressed
	[ "$exitstatus" == "255" ] && exit 0

	CHOICE=$(echo "$CHOICE" | tr -d ' ')
	case "$CHOICE" in
	1)
		newClient
		;;
	2)
		revokeClient
		;;
	3)
		stopOpenVPN
		;;
	4)
		removeOpenVPN
		;;
	4)
		exit 0
		;;
	esac
}

# Check for root, TUN, OS...
initialCheck

# Check if OpenVPN is already installed and configures
if [[ -e $OPENVPN_CONF ]]; then
	manageMenu
else
	clear
	# This fix prevents trying to randomise the MAC address of the tun1 interface.
	# It can be removed with TorBox v.0.5.5
	MAC_USB0=$(grep "^MAC_usb0=" ${RUNFILE}) 2>/dev/null
	MAC_TUN1=$(grep "^MAC_tun1=" ${RUNFILE}) 2>/dev/null
	NEW_STRING="$MAC_USB0\nMAC_tun1=permanent"
	if [ -z "$MAC_TUN1" ]; then sed -i "s/^MAC_usb0=.*/$NEW_STRING/" ${RUNFILE}; fi
	######################################################################################
	if [ "$ON_A_CLOUD" == "on_a_cloud" ]; then
		INPUT=$(cat $TXT_DIR/openvpn_server_at_install-text)
		if (whiptail --title "TorBox - INFO (scroll down!)" --yesno --scrolltext "$INPUT" $MENU_HEIGHT_25 $MENU_WIDTH); then
			installOpenVPN
		else
			exit 0
		fi
	else
		INPUT=$(cat $TXT_DIR/openvpn_server-text)
		if (whiptail --title "TorBox - INFO (scroll down!)" --defaultno --no-button "ON A REAL BOX" --yes-button "ON A CLOUD" --yesno --scrolltext "$INPUT" $MENU_HEIGHT_25 $MENU_WIDTH); then
			exitstatus=$?
			# exitstatus = 255 means that the ESC key was pressed
			if [ "$exitstatus" = "255" ] ; then	sed -i "s/^ON_A_CLOUD=.*/ON_A_CLOUD=0/" ${RUNFILE}; exit 1 ; fi
			sed -i "s/^ON_A_CLOUD=.*/ON_A_CLOUD=1/" ${RUNFILE}
		else
			exitstatus=$?
			# exitstatus = 255 means that the ESC key was pressed / exitstatus = 1 is cancelled
			if [ "$exitstatus" = "255" ] ; then	sed -i "s/^ON_A_CLOUD=.*/ON_A_CLOUD=0/" ${RUNFILE}; exit 1 ; fi
			sed -i "s/^ON_A_CLOUD=.*/ON_A_CLOUD=0/" ${RUNFILE}
		fi
		installOpenVPN
	fi
fi
