#!/bin/bash
# shellcheck disable=SC1091,SC2129,SC2164,SC2034,SC1072,SC1073,SC1009

# This file is a part of TorBox, an easy to use anonymizing router based on Raspberry Pi.
# Copyright (C) 2025 radio24
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
# IMPORTANT
# Currently, this script doesn't support peer-fingerprint authentication mode used by OpenVPN 2.6+.
# The original script implement this feature with commit #df242ee (https://github.com/angristan/openvpn-install/commit/df242ee069e06b312c6af0b06487d108decd24fc#diff-0742f10ff479ac71573debd44cfad7847d79c1f575a81e44a4ac0c6063853e1c)
# Please give me a hint, if you need that feature (anonym@torbox.ch).
#
#
###### SET VARIABLES ######
#
#
# SIZE OF THE MENU
#
# How many items do you have in the main menu?
NO_ITEMS=7
NO_ITEMS_RENEW=2
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
MENU_HEIGHT_RENEW=$((8+NO_ITEMS_RENEW+NO_SPACER))
MENU_LIST_HEIGHT=$((NO_ITEMS+NO_SPACER))
MENU_LIST_HEIGHT_RENEW=$((NO_ITEMS_RENEW+NO_SPACER))

#Colors (don't change it!)
RED='\033[1;31m'
YELLOW='\033[1;93m'
GREEN='\033[1;32m'
NOCOLOR='\033[0m'
COLOR_DIM='\033[0;90m'
COLOR_RESET='\033[0m'

# Tested easyrsa version. Newer versions may not work, yet.
readonly EASYRSA_VERSION="3.2.5"
readonly EASYRSA_SHA256="662ee3b453155aeb1dff7096ec052cd83176c460cfa82ac130ef8568ec4df490"

#Run commands verbose or not
VERBOSE=0

# Other variables
OPENVPN_SERVER_PATH="/etc/openvpn/server"
OPENVPN_CONF="$OPENVPN_SERVER_PATH/server.conf"
# Home directory of the user, where the client configuration will be written
homeDir="/home/torbox"
TORBOX_PATH="/home/torbox/torbox"
CONFIG_PATH="$TORBOX_PATH/etc"
RUNFILE="$TORBOX_PATH/run/torbox.run"
TXT_DIR="$TORBOX_PATH/text"
ON_A_CLOUD=$1
OPENVPN_PORT=$(grep "^OPENVPN_PORT=.*" ${RUNFILE} | sed "s/.*=//g")
if [ -z "$OPENVPN_PORT" ]; then OPENVPN_PORT="1194"; fi
NEW_CLIENT="y"
MAX_CLIENT_NAME_LENGTH="64"

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
######## CONSTANS ###########
readonly DEFAULT_CERT_VALIDITY_DURATION_DAYS=3650 # 10 years
readonly DEFAULT_CRL_VALIDITY_DURATION_DAYS=5475  # 15 years

######## FUNCTIONS ###########

# Logging functions
# The original script uses these function for logging purposes
# In our fork, we don't _log_to_file and removed this function.
function log_info() {
	echo -e "${YELLOW}[INFO]${COLOR_RESET} $*"
}

function log_warn() {
	echo -e "${RED}[WARN]${COLOR_RESET} $*"
}

function log_fatal() {
	echo -e "${RED}[ERROR]${COLOR_RESET} $*"
	exit 1
}

function log_success() {
	echo -e "${GREEN}[OK]${COLOR_RESET} $*"
}

function log_prompt() {
	echo -e "${YELLOW}$*${COLOR_RESET}"
}

function log_menu() {
	# For menu options - only show in interactive mode
	echo "$@"
}

function log_header() {
	# For section headers
		echo ""
		echo -e "${YELLOW}=== $* ===${COLOR_RESET}"
		echo ""
}

# Run a command with optional output suppression
# Usage: run_cmd "description" command [args...]
function run_cmd() {
	local desc="$1"
	shift
	# Display the command being run
	echo -e "${COLOR_DIM}> $*${COLOR_RESET}"
	if [[ $VERBOSE -eq 1 ]]; then
			"$@"
	else
			"$@" >/dev/null 2>&1
	fi
	local ret=$?
	if [[ $ret -eq 0 ]]; then
		log_debug "$desc completed successfully"
	else
		log_error "$desc failed with exit code $ret"
	fi
	return $ret
}

# Run a command that must succeed, exit on failure
# Usage: run_cmd_fatal "description" command [args...]
function run_cmd_fatal() {
	local desc="$1"
	shift
	if ! run_cmd "$desc" "$@"; then
		log_fatal "$desc failed"
	fi
}

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

# For Raspberry OS, we only need Debian-support.
function checkOS() {
	if [[ -e /etc/debian_version ]]; then
		OS="debian"
		source /etc/os-release
		if [[ $ID == "debian" || $ID == "raspbian" ]]; then
			if [[ $VERSION_ID -lt 11 ]]; then
				log_warn "Your version of Debian is not supported."
				log_info "However, if you're using Debian >= 11 or unstable/testing, you can continue at your own risk."
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
			if [[ $MAJOR_UBUNTU_VERSION -lt 18 ]]; then
				log_warn "Your version of Ubuntu is not supported."
				log_info "However, if you're using Ubuntu >= 18.04 or beta, you can continue at your own risk."
				until [[ $CONTINUE =~ (y|n) ]]; do
					read -rp "Continue? [y/n]: " -e CONTINUE
				done
				if [[ $CONTINUE == "n" ]]; then
					exit 1
				fi
			fi
		fi
	else
		log_fatal "It looks like you aren't running this installer on a Rapberry PI OS, Debian or Ubuntu system.\nPlease report this error to anonym@torbox.ch"
	fi
}

function initialCheck() {
	log_debug "Checking root privileges..."
	if ! isRoot; then
		log_fatal "Sorry, you need to run this script as root."
	fi
	log_debug "Root check passed"

	log_debug "Checking TUN device availability..."
	if ! tunAvailable; then
		log_fatal "TUN is not available."
	fi
	log_debug "TUN device available at /dev/net/tun"

	log_debug "Detecting operating system..."
	checkOS
	log_debug "Detected OS: $OS"
	#checkArchPendingKernelUpgrade

	# TOGGLE01 shows if the OpenVPN server is disabled or not
	VPN_STATUS=""
	VPN_STATUS=$(sudo systemctl is-active openvpn-server@server)
	if [ "$VPN_STATUS" = "inactive" ] || [ "$VPN_STATUS" = "failed" ] ; then
		TOGGLE01="Enable"
		TOGGLE02=""
	else
		TOGGLE01="Disable"
		TOGGLE02="without touching the configuration"
	fi
}

# Check if OpenVPN version is at least the specified version
# Usage: openvpnVersionAtLeast "2.5"
# Returns 0 if version is >= specified, 1 otherwise
function openvpnVersionAtLeast() {
	local required_version="$1"
	local installed_version

	if ! command -v openvpn &>/dev/null; then
		return 1
	fi

	installed_version=$(openvpn --version 2>/dev/null | head -1 | awk '{print $2}')
	if [[ -z "$installed_version" ]]; then
		return 1
	fi

	# Compare versions using sort -V
	if [[ "$(printf '%s\n' "$required_version" "$installed_version" | sort -V | head -n1)" == "$required_version" ]]; then
		return 0
	fi
	return 1
}

# NOT NECESSARY: Only used by DCO-check, which is also not necesarry (see below)
# Check if kernel version is at least the specified version

# NOT NECESSARY: Gives only a message, doesn't configure anything!
# Check if Data Channel Offload (DCO) is available
# DCO requires: OpenVPN 2.6+, kernel support (Linux 6.16+ or ovpn-dco module)

function resolvePublicIPv4() {
	local public_ip=""

	# Try to resolve public IPv4 using: https://api.seeip.org
	if [[ -z $public_ip ]]; then
		public_ip=$(curl -f -m 5 -sS --retry 2 --retry-connrefused -4 https://api.seeip.org 2>/dev/null)
	fi

	# Try to resolve using: https://ifconfig.me
	if [[ -z $public_ip ]]; then
		public_ip=$(curl -f -m 5 -sS --retry 2 --retry-connrefused -4 https://ifconfig.me 2>/dev/null)
	fi

	# Try to resolve using: https://api.ipify.org
	if [[ -z $public_ip ]]; then
		public_ip=$(curl -f -m 5 -sS --retry 2 --retry-connrefused -4 https://api.ipify.org 2>/dev/null)
	fi

	# Try to resolve using: ns1.google.com
	if [[ -z $public_ip ]]; then
		public_ip=$(dig -4 TXT +short o-o.myaddr.l.google.com @ns1.google.com | tr -d '"')
	fi

	echo "$public_ip"
}

function resolvePublicIPv6() {
	local public_ip=""

	# Try to resolve public IPv6 using: https://api6.seeip.org
	if [[ -z $public_ip ]]; then
		public_ip=$(curl -f -m 5 -sS --retry 2 --retry-connrefused -6 https://api6.seeip.org 2>/dev/null)
	fi

	# Try to resolve using: https://ifconfig.me (IPv6)
	if [[ -z $public_ip ]]; then
		public_ip=$(curl -f -m 5 -sS --retry 2 --retry-connrefused -6 https://ifconfig.me 2>/dev/null)
	fi

	# Try to resolve using: https://api64.ipify.org (dual-stack, prefer IPv6)
	if [[ -z $public_ip ]]; then
		public_ip=$(curl -f -m 5 -sS --retry 2 --retry-connrefused -6 https://api64.ipify.org 2>/dev/null)
	fi

	# Try to resolve using: ns1.google.com
	if [[ -z $public_ip ]]; then
		public_ip=$(dig -6 TXT +short o-o.myaddr.l.google.com @ns1.google.com | tr -d '"')
	fi

	echo "$public_ip"
}

# Legacy wrapper for backward compatibility
function resolvePublicIP() {
	if [[ $ENDPOINT_TYPE == "6" ]]; then
		resolvePublicIPv6
	else
		resolvePublicIPv4
	fi
}

# NOT NECESSARY
# Helper function to write client config file with proper path and permissions
# Usage: writeClientConfig <client_name>

# Helper function to regenerate the CRL after certificate changes
function regenerateCRL() {
	export EASYRSA_CRL_DAYS=$DEFAULT_CRL_VALIDITY_DURATION_DAYS
	run_cmd_fatal "Regenerating CRL" ./easyrsa gen-crl
	run_cmd "Removing old CRL" rm -f $OPENVPN_SERVER_PATH/crl.pem
	run_cmd_fatal "Copying new CRL" cp $OPENVPN_SERVER_PATH/easy-rsa/pki/crl.pem $OPENVPN_SERVER_PATH/crl.pem
	run_cmd "Setting CRL permissions" chmod 644 $OPENVPN_SERVER_PATH/crl.pem
}

# Helper function to generate .ovpn client config file
function generateClientConfig() {
	local client="$1"
	local filepath="$2"

	# Determine if we use tls-auth or tls-crypt
	local tls_sig=""
	if grep -qs "^tls-crypt" $OPENVPN_CONF; then
		tls_sig="1"
	elif grep -qs "^tls-auth" $OPENVPN_CONF; then
		tls_sig="2"
	fi

	# Generate the custom client.ovpn
	run_cmd "Creating client config" cp $OPENVPN_SERVER_PATH/client-template.txt "$filepath"
	{
		echo "<ca>"
		cat "$OPENVPN_SERVER_PATH/easy-rsa/pki/ca.crt"
		echo "</ca>"

		echo "<cert>"
		awk '/BEGIN/,/END CERTIFICATE/' "$OPENVPN_SERVER_PATH/easy-rsa/pki/issued/$client.crt"
		echo "</cert>"

		echo "<key>"
		cat "$OPENVPN_SERVER_PATH/easy-rsa/pki/private/$client.key"
		echo "</key>"

		case $tls_sig in
		1)
			# Generate per-client tls-crypt-v2 key in /etc/openvpn/server/
			# Using /tmp would fail on Ubuntu 25.04+ due to AppArmor restrictions
			tls_crypt_v2_tmpfile=$(mktemp $OPENVPN_SERVER_PATH/tls-crypt-v2-client.XXXXXX)
			if [[ -z "$tls_crypt_v2_tmpfile" ]] || [[ ! -f "$tls_crypt_v2_tmpfile" ]]; then
				log_error "Failed to create temporary file for tls-crypt-v2 client key"
				exit 1
			fi
			if ! openvpn --tls-crypt-v2 $OPENVPN_SERVER_PATH/tls-crypt-v2.key \
				--genkey tls-crypt-v2-client "$tls_crypt_v2_tmpfile"; then
				rm -f "$tls_crypt_v2_tmpfile"
				log_error "Failed to generate tls-crypt-v2 client key"
				exit 1
			fi
			echo "<tls-crypt-v2>"
			cat "$tls_crypt_v2_tmpfile"
			echo "</tls-crypt-v2>"
			rm -f "$tls_crypt_v2_tmpfile"
			;;
		2)
			echo "<tls-crypt>"
			cat $OPENVPN_SERVER_PATH/tls-crypt.key
			echo "</tls-crypt>"
			;;
		3)
			echo "key-direction 1"
			echo "<tls-auth>"
			cat $OPENVPN_SERVER_PATH/tls-auth.key
			echo "</tls-auth>"
			;;
		esac
	} >>"$filepath"
}

function getDaysUntilExpiry() {
	local cert_file="$1"
	if [[ -f "$cert_file" ]]; then
		local expiry_date
		expiry_date=$(openssl x509 -in "$cert_file" -noout -enddate | cut -d= -f2)
		local expiry_epoch
		expiry_epoch=$(date -d "$expiry_date" +%s 2>/dev/null || date -j -f "%b %d %T %Y %Z" "$expiry_date" +%s 2>/dev/null)
		if [[ -z "$expiry_epoch" ]]; then
			echo "?"
			return
		fi
		local now_epoch
		now_epoch=$(date +%s)
		echo $(((expiry_epoch - now_epoch) / 86400))
	else
		echo "?"
	fi
}

# Helper function to list valid clients and select one
# Arguments: show_expiry (optional, "true" to show expiry info)
# Sets global variables:
#   CLIENT - the selected client name
#   CLIENTNUMBER - the selected client number (1-based index)
#   NUMBEROFCLIENTS - total count of valid clients
function selectClient() {
	local show_expiry="${1:-false}"
	local client_number

	NUMBEROFCLIENTS=$(tail -n +2 $OPENVPN_SERVER_PATH/easy-rsa/pki/index.txt | grep -c "^V")
	if [[ $NUMBEROFCLIENTS == '0' ]]; then
		log_fatal "You have no existing clients!"
	fi

	# If CLIENT is set, validate it exists as a valid client
	if [[ -n $CLIENT ]]; then
		if tail -n +2 $OPENVPN_SERVER_PATH/easy-rsa/pki/index.txt | grep "^V" | cut -d '=' -f 2 | grep -qx "$CLIENT"; then
			return
		else
			log_fatal "Client '$CLIENT' not found or not valid"
		fi
	fi

	if [[ $show_expiry == "true" ]]; then
		local i=1
		while read -r client; do
			local client_cert="$OPENVPN_SERVER_PATH/easy-rsa/pki/issued/$client.crt"
			local days
			days=$(getDaysUntilExpiry "$client_cert")
			local expiry
			expiry=$(formatExpiry "$days")
			echo "     $i) $client $expiry"
			((i++))
		done < <(tail -n +2 $OPENVPN_SERVER_PATH/easy-rsa/pki/index.txt | grep "^V" | cut -d '=' -f 2)
	else
		tail -n +2 $OPENVPN_SERVER_PATH/easy-rsa/pki/index.txt | grep "^V" | cut -d '=' -f 2 | nl -s ') '
	fi

	until [[ ${CLIENTNUMBER:-$client_number} -ge 1 && ${CLIENTNUMBER:-$client_number} -le $NUMBEROFCLIENTS ]]; do
		if [[ $NUMBEROFCLIENTS == '1' ]]; then
			read -rp "Select one client [1]: " client_number
		else
			read -rp "Select one client [1-$NUMBEROFCLIENTS]: " client_number
		fi
	done
	CLIENTNUMBER="${CLIENTNUMBER:-$client_number}"
	CLIENT=$(tail -n +2 $OPENVPN_SERVER_PATH/easy-rsa/pki/index.txt | grep "^V" | cut -d '=' -f 2 | sed -n "$CLIENTNUMBER"p)
}

function listClients() {
	local index_file="$OPENVPN_SERVER_PATH/easy-rsa/pki/index.txt"
	local cert_dir="$OPENVPN_SERVER_PATH/easy-rsa/pki/issued"
	local number_of_clients
	local format="${OUTPUT_FORMAT:-table}"

	# Exclude server certificates (CN starting with server_)
	number_of_clients=$(tail -n +2 "$index_file" | grep "^[VR]" | grep -cv "/CN=server_")

	if [[ $number_of_clients == '0' ]]; then
		if [[ $format == "json" ]]; then
			echo '{"clients":[]}'
		else
			log_warn "You have no existing client certificates!"
		fi
		return
	fi

	# Collect client data
	local clients_data=()
	while read -r line; do
		local status="${line:0:1}"
		local client_name
		client_name=$(echo "$line" | sed 's/.*\/CN=//')

		local status_text
		if [[ "$status" == "V" ]]; then
			status_text="valid"
		elif [[ "$status" == "R" ]]; then
			status_text="revoked"
		else
			status_text="unknown"
		fi

		local cert_file="$cert_dir/$client_name.crt"
		local expiry_date="unknown"
		local days_remaining="null"

		if [[ -f "$cert_file" ]]; then
			local enddate
			enddate=$(openssl x509 -enddate -noout -in "$cert_file" 2>/dev/null | cut -d= -f2)

			if [[ -n "$enddate" ]]; then
				local expiry_epoch
				expiry_epoch=$(date -d "$enddate" +%s 2>/dev/null || date -j -f "%b %d %H:%M:%S %Y %Z" "$enddate" +%s 2>/dev/null)

				if [[ -n "$expiry_epoch" ]]; then
					expiry_date=$(date -d "@$expiry_epoch" +%Y-%m-%d 2>/dev/null || date -r "$expiry_epoch" +%Y-%m-%d 2>/dev/null)
					local now_epoch
					now_epoch=$(date +%s)
					days_remaining=$(((expiry_epoch - now_epoch) / 86400))
				fi
			fi
		fi

		clients_data+=("$client_name|$status_text|$expiry_date|$days_remaining")
	done < <(tail -n +2 "$index_file" | grep "^[VR]" | grep -v "/CN=server_" | sort -t$'\t' -k2)

	if [[ $format == "json" ]]; then
		# Output JSON
		echo '{"clients":['
		local first=true
		for client_entry in "${clients_data[@]}"; do
			IFS='|' read -r name status expiry days <<<"$client_entry"
			[[ $first == true ]] && first=false || printf ','
			# Handle null for days_remaining (no quotes for JSON null)
			local days_json
			if [[ "$days" == "null" || -z "$days" ]]; then
				days_json="null"
			else
				days_json="$days"
			fi
			printf '{"name":"%s","status":"%s","expiry":"%s","days_remaining":%s}\n' \
				"$(json_escape "$name")" "$(json_escape "$status")" "$(json_escape "$expiry")" "$days_json"
		done
		echo ']}'
	else
		# Output table
		log_header "Client Certificates"
		log_info "Found $number_of_clients client certificate(s)"
		log_menu ""
		printf "   %-25s %-10s %-12s %s\n" "Name" "Status" "Expiry" "Remaining"
		printf "   %-25s %-10s %-12s %s\n" "----" "------" "------" "---------"

		for client_entry in "${clients_data[@]}"; do
			IFS='|' read -r name status expiry days <<<"$client_entry"
			local relative
			if [[ $days == "null" ]]; then
				relative="unknown"
			elif [[ $days -lt 0 ]]; then
				relative="$((-days)) days ago"
			elif [[ $days -eq 0 ]]; then
				relative="today"
			elif [[ $days -eq 1 ]]; then
				relative="1 day"
			else
				relative="$days days"
			fi
			# Capitalize status for table display
			local status_display="${status^}"
			printf "   %-25s %-10s %-12s %s\n" "$name" "$status_display" "$expiry" "$relative"
		done
		log_menu ""
	fi
}

function renewMenu() {
	local server_name server_cert server_days server_expiry renew_option

	# Get server certificate expiry for menu display (extract basename since path may be relative)
	server_name=$(basename "$(grep '^cert ' $OPENVPN_CONF | cut -d ' ' -f 2)" .crt)
	if [[ -z "$server_name" ]]; then
		server_expiry="(unknown expiry)"
	else
		server_cert="$OPENVPN_SERVER_PATH/easy-rsa/pki/issued/$server_name.crt"
		server_days=$(getDaysUntilExpiry "$server_cert")
		server_expiry=$(formatExpiry "$server_days")
	fi

	######## PREPARATIONS ########
	# Resetting
	shopt -s checkwinsize
	[ -f nohup.out ] && sudo rm nohup.out
	stty intr ^c
	trap

	###### DISPLAY THE MENU ######
	clear
	CHOICE_RENEW=$(whiptail --cancel-button "Back" --title "TorBox v.0.5.5 - OpenVPN Server Management" --menu "Choose an option (ESC -> back to the main menu)" $MENU_HEIGHT_RENEW $MENU_WIDTH $MENU_LIST_HEIGHT_RENEW \
	"==" "===============================================================" \
	" 1" "Renew a client certificate"  \
	" 2" "Renew the server certificate $server_expiry"  \
	"==" "===============================================================" \
	3>&1 1>&2 2>&3)
	exitstatus=$?
	# exitstatus == 255 means that the ESC key was pressed
	[ "$exitstatus" == "255" ] && manageMenu

	CHOICE_RENEW=$(echo "$CHOICE_RENEW" | tr -d ' ')
	case "$CHOICE_RENEW" in
	1)
		renewClient
		;;
	2)
		renewServer
		;;
	esac
}

function formatExpiry() {
	local days="$1"
	if [[ "$days" == "?" ]]; then
		echo "(unknown expiry)"
	elif [[ $days -lt 0 ]]; then
		echo "(EXPIRED $((-days)) days ago)"
	elif [[ $days -eq 0 ]]; then
		echo "(expires today)"
	elif [[ $days -eq 1 ]]; then
		echo "(expires in 1 day)"
	else
		echo "(expires in $days days)"
	fi
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
	log_menu ""
	log_prompt "Detecting server IP addresses..."

	# Detect IPv4 address
	IP_IPV4=$(ip -4 addr | sed -ne 's|^.* inet \([^/]*\)/.* scope global.*$|\1|p' | head -1)
	# Detect IPv6 address
	IP_IPV6=$(ip -6 addr | sed -ne 's|^.* inet6 \([^/]*\)/.* scope global.*$|\1|p' | head -1)

	if [[ -n $IP_IPV4 ]]; then
		log_prompt "  IPv4 address detected: $IP_IPV4"
	else
		log_prompt "  No IPv4 address detected"
	fi
	if [[ -n $IP_IPV6 ]]; then
		log_prompt "  IPv6 address detected: $IP_IPV6"
	else
		log_prompt "  No IPv6 address detected"
	fi

	log_prompt "What IP version should clients use to connect to this server?"

	# Determine default based on available addresses
	if [[ -n $IP_IPV4 ]]; then
		ENDPOINT_TYPE_DEFAULT=1
	fi
	if [[ -n $IP_IPV6 ]]; then
		ENDPOINT_TYPE_DEFAULT=2
	fi

	log_menu "   1) IPv4 (recommended)"
	log_menu "   2) IPv6 (BETA)"
	until [[ $ENDPOINT_TYPE_CHOICE =~ ^[1-2]$ ]]; do
		read -rp "Endpoint type [1-2]: " -e -i $ENDPOINT_TYPE_DEFAULT ENDPOINT_TYPE_CHOICE
	done
	case $ENDPOINT_TYPE_CHOICE in
	1)
		ENDPOINT_TYPE="4"
		read -rp "IP address: " -e -i "$IP_IPV4" IP
		;;
	2)
		ENDPOINT_TYPE="6"
		read -rp "IP address: " -e -i "$IP_IPV6" IP
		;;
	esac

	# If IPv4 and private IP, server is behind NAT
	if [[ $ENDPOINT_TYPE == "4" ]] && echo "$IP" | grep -qE '^(10\.|172\.1[6789]\.|172\.2[0-9]\.|172\.3[01]\.|192\.168)'; then
		log_menu ""
		log_prompt "It seems this server is behind NAT. What is its public IPv4 address or hostname?"
		log_prompt "We need it for the clients to connect to the server."
		if [[ -z $ENDPOINT ]]; then
			DEFAULT_ENDPOINT=$(resolvePublicIPv4)
		fi
		until [[ $ENDPOINT != "" ]]; do
			read -rp "Public IPv4 address or hostname: " -e -i "$DEFAULT_ENDPOINT" ENDPOINT
		done
	elif [[ $ENDPOINT_TYPE == "6" ]]; then
		# For IPv6, check if it's a link-local address (starts with fe80)
		if echo "$IP" | grep -qiE '^fe80'; then
			log_menu ""
			log_prompt "The detected IPv6 address is link-local. What is the public IPv6 address or hostname?"
			log_prompt "We need it for the clients to connect to the server."
			if [[ -z $ENDPOINT ]]; then
				DEFAULT_ENDPOINT=$(resolvePublicIPv6)
			fi
			until [[ $ENDPOINT != "" ]]; do
				read -rp "Public IPv6 address or hostname: " -e -i "$DEFAULT_ENDPOINT" ENDPOINT
			done
		fi
	fi

	log_menu ""
	log_prompt "What IP versions should VPN clients use?"
	log_prompt "This determines both their VPN addresses and internet access through the tunnel."

	# Check IPv6 connectivity for suggestion
	if type ping6 >/dev/null 2>&1; then
		PING6="ping6 -c1 -W2 ipv6.google.com > /dev/null 2>&1"
	else
		PING6="ping -6 -c1 -W2 ipv6.google.com > /dev/null 2>&1"
	fi
	HAS_IPV6_CONNECTIVITY="n"
	if eval "$PING6"; then
		HAS_IPV6_CONNECTIVITY="y"
	fi

	# Default suggestion based on connectivity
	if [[ $HAS_IPV6_CONNECTIVITY == "y" ]]; then
		CLIENT_IP_DEFAULT=3 # Dual-stack if IPv6 available
	else
		CLIENT_IP_DEFAULT=1 # IPv4 only otherwise
	fi

	log_menu "   1) IPv4 only (recommended)"
	log_menu "   2) IPv6 only (BETA)"
	log_menu "   3) Dual-stack (IPv4 + IPv6 - BETA)"
	until [[ $CLIENT_IP_CHOICE =~ ^[1-3]$ ]]; do
		read -rp "Client IP versions [1-3]: " -e -i $CLIENT_IP_DEFAULT CLIENT_IP_CHOICE
	done
	case $CLIENT_IP_CHOICE in
	1)
		CLIENT_IPV4="y"
		CLIENT_IPV6="n"
		;;
	2)
		CLIENT_IPV4="n"
		CLIENT_IPV6="y"
		;;
	3)
		CLIENT_IPV4="y"
		CLIENT_IPV6="y"
		;;
	esac

	# In the original script, choosing the client ip, port number, the protocol (UDP or TCP), MTU size and the compression was possible.
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
	log_prompt "Do you want to allow a single .ovpn profile to be used on multiple devices simultaneously?"
	log_prompt "Note: Enabling this disables persistent IP addresses for clients."
	until [[ $MULTI_CLIENT =~ (y|n) ]]; do
		read -rp "Allow multiple devices per client? [y/n]: " -e -i n MULTI_CLIENT
	done
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
		# TLS 1.3 cipher suites (OpenSSL format with underscores)
		TLS13_CIPHERSUITES="${TLS13_CIPHERSUITES:-TLS_AES_256_GCM_SHA384:TLS_AES_128_GCM_SHA256:TLS_CHACHA20_POLY1305_SHA256}"
		TLS_VERSION_MIN="${TLS_VERSION_MIN:-1.2}"
		# TLS key exchange groups (replaces deprecated ecdh-curve)
		TLS_GROUPS="${TLS_GROUPS:-X25519:prime256v1:secp384r1:secp521r1}"
		HMAC_ALG="SHA256"
		TLS_SIG="1" # tls-crypt-v2
	else
		clear
		log_prompt "Choose which cipher you want to use for the data channel:"
		log_menu "   1) AES-128-GCM (recommended)"
		log_menu "   2) AES-192-GCM"
		log_menu "   3) AES-256-GCM"
		log_menu "   4) AES-128-CBC"
		log_menu "   5) AES-192-CBC"
		log_menu "   6) AES-256-CBC"
		log_menu "   7) CHACHA20-POLY1305 (requires OpenVPN 2.5+, good for devices without AES-NI)"
		echo ""
		until [[ $CIPHER_CHOICE =~ ^[1-7]$ ]]; do
			read -rp "Cipher [1-7]: " -e -i 1 CIPHER_CHOICE
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
		7)
			# Verify ChaCha20-Poly1305 compatibility if selected
			INSTALLED_VERSION=$(openvpn --version 2>/dev/null | head -1 | awk '{print $2}')
			if ! openvpnVersionAtLeast "2.5"; then
				log_fatal "ChaCha20-Poly1305 requires OpenVPN 2.5 or later. Installed version: $INSTALLED_VERSION"
			fi
			log_info "OpenVPN version supports ChaCha20-Poly1305"
			CIPHER="CHACHA20-POLY1305"
			;;
		esac
		clear
		log_prompt "Choose what kind of certificate you want to use:"
		log_menu "   1) ECDSA (recommended)"
		log_menu "   2) RSA"
		echo ""
		until [[ $CERT_TYPE =~ ^[1-2]$ ]]; do
			read -rp "   Certificate key type [1-2]: " -e -i 1 CERT_TYPE
		done
		case $CERT_TYPE in
		1)
			clear
			log_prompt "Choose which curve you want to use for the certificate's key:"
			log_menu "   1) prime256v1 (recommended)"
			log_menu "   2) secp384r1"
			log_menu "   3) secp521r1"
			echo ""
			until [[ $CERT_CURVE_CHOICE =~ ^[1-3]$ ]]; do
				read -rp "   Curve [1-3]: " -e -i 1 CERT_CURVE_CHOICE
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
			log_prompt "Choose which size you want to use for the certificate's RSA key:"
			log_menu "   1) 2048 bits (recommended)"
			log_menu "   2) 3072 bits"
			log_menu "   3) 4096 bits"
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
		log_prompt "Choose which cipher you want to use for the control channel:"
		case $CERT_TYPE in
		1)
			log_menu "   1) ECDHE-ECDSA-AES-128-GCM-SHA256 (recommended)"
			log_menu "   2) ECDHE-ECDSA-AES-256-GCM-SHA384"
			log_menu "   3) ECDHE-ECDSA-CHACHA20-POLY1305 (requires OpenVPN 2.5+)"
			until [[ $CC_CIPHER_CHOICE =~ ^[1-3]$ ]]; do
				read -rp "Control channel cipher [1-3]: " -e -i 1 CC_CIPHER_CHOICE
			done
			case $CC_CIPHER_CHOICE in
			1)
				CC_CIPHER="TLS-ECDHE-ECDSA-WITH-AES-128-GCM-SHA256"
				;;
			2)
				CC_CIPHER="TLS-ECDHE-ECDSA-WITH-AES-256-GCM-SHA384"
				;;
			3)
				CC_CIPHER="TLS-ECDHE-ECDSA-WITH-CHACHA20-POLY1305-SHA256"
				;;
			esac
			;;
		2)
			log_menu "   1) ECDHE-RSA-AES-128-GCM-SHA256 (recommended)"
			log_menu "   2) ECDHE-RSA-AES-256-GCM-SHA384"
			log_menu "   3) ECDHE-RSA-CHACHA20-POLY1305 (requires OpenVPN 2.5+)"
			until [[ $CC_CIPHER_CHOICE =~ ^[1-3]$ ]]; do
				read -rp "Control channel cipher [1-3]: " -e -i 1 CC_CIPHER_CHOICE
			done
			case $CC_CIPHER_CHOICE in
			1)
				CC_CIPHER="TLS-ECDHE-RSA-WITH-AES-128-GCM-SHA256"
				;;
			2)
				CC_CIPHER="TLS-ECDHE-RSA-WITH-AES-256-GCM-SHA384"
				;;
			3)
				CC_CIPHER="TLS-ECDHE-RSA-WITH-CHACHA20-POLY1305-SHA256"
				;;
			esac
			;;
		esac
		clear
		log_prompt "Choose the minimum TLS version:"
		log_menu "   1) TLS 1.2 (recommended, compatible with all clients)"
		log_menu "   2) TLS 1.3 (more secure, requires OpenVPN 2.5+ clients)"
		until [[ $TLS_VERSION_MIN_CHOICE =~ ^[1-2]$ ]]; do
			read -rp "Minimum TLS version [1-2]: " -e -i 1 TLS_VERSION_MIN_CHOICE
		done
		case $TLS_VERSION_MIN_CHOICE in
		1)
			TLS_VERSION_MIN="1.2"
			;;
		2)
			TLS_VERSION_MIN="1.3"
			;;
		esac
		log_menu ""
		log_prompt "Choose TLS 1.3 cipher suites (used when TLS 1.3 is negotiated):"
		log_menu "   1) All secure ciphers (recommended)"
		log_menu "   2) AES-256-GCM only"
		log_menu "   3) AES-128-GCM only"
		log_menu "   4) ChaCha20-Poly1305 only"
		until [[ $TLS13_CIPHER_CHOICE =~ ^[1-4]$ ]]; do
			read -rp "TLS 1.3 cipher suite [1-4]: " -e -i 1 TLS13_CIPHER_CHOICE
		done
		case $TLS13_CIPHER_CHOICE in
		1)
			TLS13_CIPHERSUITES="TLS_AES_256_GCM_SHA384:TLS_AES_128_GCM_SHA256:TLS_CHACHA20_POLY1305_SHA256"
			;;
		2)
			TLS13_CIPHERSUITES="TLS_AES_256_GCM_SHA384"
			;;
		3)
			TLS13_CIPHERSUITES="TLS_AES_128_GCM_SHA256"
			;;
		4)
			TLS13_CIPHERSUITES="TLS_CHACHA20_POLY1305_SHA256"
			;;
		esac
		log_menu ""
		log_prompt "Choose TLS key exchange groups (for ECDH key exchange):"
		log_menu "   1) All modern curves (recommended)"
		log_menu "   2) X25519 only (most secure, may have compatibility issues)"
		log_menu "   3) NIST curves only (prime256v1, secp384r1, secp521r1)"
		until [[ $TLS_GROUPS_CHOICE =~ ^[1-3]$ ]]; do
			read -rp "TLS groups [1-3]: " -e -i 1 TLS_GROUPS_CHOICE
		done
		case $TLS_GROUPS_CHOICE in
		1)
			TLS_GROUPS="X25519:prime256v1:secp384r1:secp521r1"
			;;
		2)
			TLS_GROUPS="X25519"
			;;
		3)
			TLS_GROUPS="prime256v1:secp384r1:secp521r1"
			;;
		esac
		echo ""
		# # The "auth" options behaves differently with AEAD ciphers (GCM, ChaCha20-Poly1305)
		if [[ $CIPHER =~ CBC$ ]]; then
			log_prompt "The digest algorithm authenticates data channel packets and tls-auth packets from the control channel."
		elif [[ $CIPHER =~ GCM$ ]] || [[ $CIPHER == "CHACHA20-POLY1305" ]]; then
			log_prompt "The digest algorithm authenticates tls-auth packets from the control channel."
		fi
		sleep 3
		clear
		log_prompt "Which digest algorithm do you want to use for HMAC?"
		log_menu "   1) SHA-256 (recommended)"
		log_menu "   2) SHA-384"
		log_menu "   3) SHA-512"
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
		log_prompt "You can add an additional layer of security to the control channel."
		log_menu "   1) tls-crypt-v2 (recommended): Encrypts control channel, unique key per client"
		log_menu "   2) tls-crypt: Encrypts control channel, shared key for all clients"
		log_menu "   3) tls-auth: Authenticates control channel, no encryption"
		until [[ $TLS_SIG =~ ^[1-3]$ ]]; do
			read -rp "Control channel additional security mechanism [1-3]: " -e -i 1 TLS_SIG
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

# Check if client name is valid (non-fatal, returns true/false)
function is_valid_client_name() {
	local name="$1"
	[[ "$name" =~ ^[a-zA-Z0-9_-]+$ ]] && [[ ${#name} -le $MAX_CLIENT_NAME_LENGTH ]]
}

function installOpenVPN() {
	# Information: The auto-installatin feature from the orginal script is removed.
	# Answer setup questions first
	installQuestions

	# Get the "public" interface from the default route
	NIC=$(ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)' | head -1)
	if [[ -z $NIC ]] && [[ $CLIENT_IPV6 == 'y' ]]; then
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
	if [[ ! -d $OPENVPN_SERVER_PATH/easy-rsa/ ]]; then
		run_cmd_fatal "Downloading Easy-RSA v${EASYRSA_VERSION}" curl -fL --retry 5 -o ~/easy-rsa.tgz "https://github.com/OpenVPN/easy-rsa/releases/download/v${EASYRSA_VERSION}/EasyRSA-${EASYRSA_VERSION}.tgz"
		log_info "Verifying Easy-RSA checksum..."
		CHECKSUM_OUTPUT=$(echo "${EASYRSA_SHA256}  $HOME/easy-rsa.tgz" | sha256sum -c 2>&1) || {
			run_cmd "Cleaning up failed download" rm -f ~/easy-rsa.tgz
			log_fatal "SHA256 checksum verification failed for easy-rsa download!"
		}
		run_cmd_fatal "Creating Easy-RSA directory" mkdir -p $OPENVPN_SERVER_PATH/easy-rsa
		run_cmd_fatal "Extracting Easy-RSA" tar xzf ~/easy-rsa.tgz --strip-components=1 --no-same-owner --directory $OPENVPN_SERVER_PATH/easy-rsa
		run_cmd "Cleaning up archive" rm -f ~/easy-rsa.tgz

		cd $OPENVPN_SERVER_PATH/easy-rsa/ || return
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
		# Note: 2>/dev/null suppresses "Broken pipe" errors from fold when head exits early
		SERVER_CN="cn_$(head /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 2>/dev/null | head -n 1)"
		echo "$SERVER_CN" >SERVER_CN_GENERATED
		SERVER_NAME="server_$(head /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 2>/dev/null | head -n 1)"
		echo "$SERVER_NAME" >SERVER_NAME_GENERATED

		# Create the PKI, set up the CA, the DH params and the server certificate
		log_info "Initializing PKI..."
		run_cmd_fatal "Initializing PKI" ./easyrsa init-pki
		export EASYRSA_CA_EXPIRE=$DEFAULT_CERT_VALIDITY_DURATION_DAYS
		log_info "Building CA..."
		run_cmd_fatal "Building CA" ./easyrsa --batch --req-cn="$SERVER_CN" build-ca nopass
		export EASYRSA_CERT_EXPIRE=${SERVER_CERT_DURATION_DAYS:-$DEFAULT_CERT_VALIDITY_DURATION_DAYS}
		log_info "Building server certificate..."
		run_cmd_fatal "Building server certificate" ./easyrsa --batch build-server-full "$SERVER_NAME" nopass
		export EASYRSA_CRL_DAYS=$DEFAULT_CRL_VALIDITY_DURATION_DAYS
		run_cmd_fatal "Generating CRL" ./easyrsa gen-crl

		log_info "Generating TLS key..."
		case $TLS_SIG in
		1)
			# Generate tls-crypt-v2 server key
			run_cmd_fatal "Generating tls-crypt-v2 server key" openvpn --genkey tls-crypt-v2-server $OPENVPN_SERVER_PATH/tls-crypt-v2.key
			;;
		2)
			# Generate tls-crypt key
			run_cmd_fatal "Generating tls-crypt key" openvpn --genkey secret $OPENVPN_SERVER_PATH/tls-crypt.key
			;;
		3)
			# Generate tls-auth key
			run_cmd_fatal "Generating tls-auth key" openvpn --genkey secret $OPENVPN_SERVER_PATH/tls-auth.key
			;;
		esac

	else
		# If easy-rsa is already installed, grab the generated SERVER_NAME
		# for client configs
		cd $OPENVPN_SERVER_PATH/easy-rsa/ || return
		SERVER_NAME=$(cat SERVER_NAME_GENERATED)
	fi

	# Move all the generated files
	run_cmd_fatal "Copying certificates to /etc/openvpn/server" cp pki/ca.crt pki/private/ca.key "pki/issued/$SERVER_NAME.crt" "pki/private/$SERVER_NAME.key" $OPENVPN_SERVER_PATH/easy-rsa/pki/crl.pem $OPENVPN_SERVER_PATH

	# Make cert revocation list readable for non-root
	chmod 644 $OPENVPN_SERVER_PATH/crl.pem

	# Generate server.conf
	echo "port $PORT" >$OPENVPN_CONF
	# Protocol selection: use proto6 variants if endpoint is IPv6
	if [[ $ENDPOINT_TYPE == "6" ]]; then
		echo "proto ${PROTOCOL}6" >>$OPENVPN_CONF
	else
		echo "proto $PROTOCOL" >>$OPENVPN_CONF
	fi
	if [[ $MULTI_CLIENT == "y" ]]; then
		echo "duplicate-cn" >>$OPENVPN_CONF
	fi

	# Changed by torbox: dev tun -> dev tun1
	# Changed by torbox: 10.8.0.0 -> 192.168.44.0
	echo "dev tun1
user nobody
group $NOGROUP
persist-key
persist-tun
keepalive 10 120
topology subnet" >>$OPENVPN_CONF

	# IPv4 server directive - always assign IPv4 to clients for proper routing
	# Even for IPv6-only mode, we need IPv4 addresses so redirect-gateway def1 can block IPv4 leaks
	echo "server 192.168.44.0 255.255.255.0" >>$OPENVPN_CONF

	# IPv6 server directive (only if clients get IPv6)
	if [[ $CLIENT_IPV6 == "y" ]]; then
		VPN_SUBNET_IPV6="fd42:42:42:42::"
		#VPN_GATEWAY_IPV6="${VPN_SUBNET_IPV6}1"
		{
			echo "server-ipv6 ${VPN_SUBNET_IPV6}/112"
			echo "tun-ipv6"
			echo "push tun-ipv6"
		} >>$OPENVPN_CONF
	fi

	# ifconfig-pool-persist is incompatible with duplicate-cn
	if [[ $MULTI_CLIENT != "y" ]]; then
		echo "ifconfig-pool-persist ipp.txt" >>$OPENVPN_CONF
	fi

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
		# Copy IPv4 resolvers if client has IPv4, or IPv6 resolvers if client has IPv6
		if [[ $line =~ ^[0-9.]*$ ]] && [[ $CLIENT_IPV4 == 'y' ]]; then
			echo "push \"dhcp-option DNS $line\"" >>$OPENVPN_CONF
		elif [[ $line =~ : ]] && [[ $CLIENT_IPV6 == 'y' ]]; then
			echo "push \"dhcp-option DNS $line\"" >>$OPENVPN_CONF
		fi
	done

	# Redirect gateway settings - always redirect both IPv4 and IPv6 to prevent leaks
	# For IPv4: redirect-gateway def1 routes all IPv4 through VPN (or drops it if IPv4 not configured)
	# For IPv6: route-ipv6 + redirect-gateway ipv6 routes all IPv6, or block-ipv6 drops it
	echo 'push "redirect-gateway def1 bypass-dhcp"' >>$OPENVPN_CONF
	if [[ $CLIENT_IPV6 == "y" ]]; then
		echo 'push "route-ipv6 2000::/3"' >>$OPENVPN_CONF
		echo 'push "redirect-gateway ipv6"' >>$OPENVPN_CONF
	else
		# Block IPv6 on clients to prevent IPv6 leaks when VPN only handles IPv4
		echo 'push "block-ipv6"' >>$OPENVPN_CONF
	fi

	# NOT NECESSARY: we use the default
	#if [[ -n $MTU ]]; then
	# 	echo "tun-mtu $MTU" >>$OPENVPN_CONF
	#fi

	# Use ECDH key exchange (dh none) with tls-groups for curve negotiation
	echo "dh none" >>$OPENVPN_CONF
	echo "tls-groups $TLS_GROUPS" >>$OPENVPN_CONF

	case $TLS_SIG in
	1)
		echo "tls-crypt-v2 tls-crypt-v2.key" >>$OPENVPN_CONF
		;;
	2)
		echo "tls-crypt tls-crypt.key" >>$OPENVPN_CONF
		;;
	3)
		echo "tls-auth tls-auth.key 0" >>$OPENVPN_CONF
		;;
	esac

	echo "crl-verify crl.pem
ca ca.crt
cert $SERVER_NAME.crt
key $SERVER_NAME.key
auth $HMAC_ALG
cipher $CIPHER
ignore-unknown-option data-ciphers
data-ciphers $CIPHER
ncp-ciphers $CIPHER
tls-server
tls-version-min $TLS_VERSION_MIN
remote-cert-tls client
tls-cipher $CC_CIPHER
tls-ciphersuites $TLS13_CIPHERSUITES
client-config-dir $OPENVPN_SERVER_PATH/ccd
status /var/log/openvpn/status.log
verb 3" >>$OPENVPN_CONF

	# Create client-config-dir dir
	run_cmd_fatal "Creating client config directory" mkdir -p $OPENVPN_SERVER_PATH/ccd
	# Create log dir
	run_cmd_fatal "Creating log directory" mkdir -p /var/log/openvpn
	# Enable routing
	log_info "Enabling IP forwarding..."
	run_cmd_fatal "Creating sysctl.d directory" mkdir -p /etc/sysctl.d

	# Enable IPv4 forwarding if clients get IPv4
	if [[ $CLIENT_IPV4 == 'y' ]]; then
		echo 'net.ipv4.ip_forward=1' >/etc/sysctl.d/99-openvpn.conf
	else
		echo '# IPv4 forwarding not needed (no IPv4 clients)' >/etc/sysctl.d/99-openvpn.conf
	fi
	# Enable IPv6 forwarding if clients get IPv6
	if [[ $CLIENT_IPV6 == 'y' ]]; then
		echo 'net.ipv6.conf.all.forwarding=1' >>/etc/sysctl.d/99-openvpn.conf
	fi
	# Apply sysctl rules
	sysctl --system

	# If SELinux is enabled and a custom port was selected, we need this
	if hash sestatus 2>/dev/null; then
		if sestatus | grep "Current mode" | grep -qs "enforcing"; then
			if [[ $PORT != '1194' ]]; then
				# Strip "6" suffix from protocol (semanage expects "udp" or "tcp", not "udp6"/"tcp6")
				SELINUX_PROTOCOL="${PROTOCOL%6}"
				run_cmd "Configuring SELinux port" semanage port -a -t openvpn_port_t -p "$SELINUX_PROTOCOL" "$PORT"
			fi
		fi
	fi

	# Setting torbox.run
	sudo sed -i "s/^OPENVPN_FROM_INTERNET=.*/OPENVPN_FROM_INTERNET=1/" ${RUNFILE}
	sudo sed -i "s/^OPENVPN_PORT=.*/OPENVPN_PORT=$PORT/" ${RUNFILE}

	# Finally, restart and enable OpenVPN
	# OpenVPN 2.4+ uses openvpn-server@.service with config in /etc/openvpn/server/
	log_info "Configuring OpenVPN service..."

	# Find the service file (location and name vary by distro)
	# Modern distros: openvpn-server@.service in /usr/lib/systemd/system/ or /lib/systemd/system/
	# openSUSE: openvpn@.service (old-style) that we need to adapt
	if [[ -f /usr/lib/systemd/system/openvpn-server@.service ]]; then
		SERVICE_SOURCE="/usr/lib/systemd/system/openvpn-server@.service"
	elif [[ -f /lib/systemd/system/openvpn-server@.service ]]; then
		SERVICE_SOURCE="/lib/systemd/system/openvpn-server@.service"
	elif [[ -f /usr/lib/systemd/system/openvpn@.service ]]; then
		# openSUSE uses old-style service, we'll create our own openvpn-server@.service
		SERVICE_SOURCE="/usr/lib/systemd/system/openvpn@.service"
	elif [[ -f /lib/systemd/system/openvpn@.service ]]; then
		SERVICE_SOURCE="/lib/systemd/system/openvpn@.service"
	else
		log_fatal "Could not find openvpn-server@.service or openvpn@.service file"
	fi

	# Don't modify package-provided service, copy to /etc/systemd/system/
	run_cmd_fatal "Copying OpenVPN service file" cp "$SERVICE_SOURCE" /etc/systemd/system/openvpn-server@.service

	# Workaround to fix OpenVPN service on OpenVZ
	run_cmd "Patching service file (LimitNPROC)" sed -i 's|LimitNPROC|#LimitNPROC|' /etc/systemd/system/openvpn-server@.service

	# Ensure the service uses /etc/openvpn/server/ as working directory
	# This is needed for openSUSE which uses old-style paths by default
	if grep -q "cd /etc/openvpn/" /etc/systemd/system/openvpn-server@.service; then
		run_cmd "Patching service file (paths)" sed -i 's|/etc/openvpn/|/etc/openvpn/server/|g' /etc/systemd/system/openvpn-server@.service
	fi

	run_cmd "Reloading systemd" systemctl daemon-reload
	run_cmd "Unmask OpenVPN service" systemctl unmask openvpn-server@server
	run_cmd "Enabling OpenVPN service" systemctl enable openvpn-server@server
	run_cmd "Starting OpenVPN service" systemctl restart openvpn-server@server

	# NOT NECESSARY: Configure firewall rules or add iptables rules --> we have our own iptables rules

	# If the server is behind a NAT, use the correct IP address for the clients to connect to
	if [[ $ENDPOINT != "" ]]; then
		IP=$ENDPOINT
	fi

	# client-template.txt is created so we have a template to add further users later
	echo "client" >$OPENVPN_SERVER_PATH/client-template.txt
	echo "proto udp" >>$OPENVPN_SERVER_PATH/client-template.txt
	echo "explicit-exit-notify" >>$OPENVPN_SERVER_PATH/client-template.txt
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
ignore-unknown-option data-ciphers
data-ciphers $CIPHER
ncp-ciphers $CIPHER
tls-client
tls-version-min $TLS_VERSION_MIN
tls-cipher $CC_CIPHER
tls-ciphersuites $TLS13_CIPHERSUITES
ignore-unknown-option block-outside-dns
setenv opt block-outside-dns # Prevent Windows 10 DNS leak
verb 3" >>$OPENVPN_SERVER_PATH/client-template.txt

	# Generate the custom client.ovpn
	if [[ $NEW_CLIENT == "n" ]]; then
		log_info "No clients added. To add clients, simply run the script again."
	else
		log_info "Generating first client certificate..."
		newClient
		log_success "If you want to add more clients, you simply need to run this script another time!"
	fi
}

# Helper function to get the home directory for storing client configs
# Helper function to get the owner of a client config file (if client matches a system user)
# Helper function to set proper ownership and permissions on client config file
# BOTH HELPER NOT NECESSARY: It is always /home/torbox

function formatBytes() {
	local bytes=$1
	# Validate input is numeric
	if ! [[ "$bytes" =~ ^[0-9]+$ ]]; then
		echo "N/A"
		return
	fi
	if [[ $bytes -ge 1073741824 ]]; then
		awk "BEGIN {printf \"%.1fG\", $bytes/1073741824}"
	elif [[ $bytes -ge 1048576 ]]; then
		awk "BEGIN {printf \"%.1fM\", $bytes/1048576}"
	elif [[ $bytes -ge 1024 ]]; then
		awk "BEGIN {printf \"%.1fK\", $bytes/1024}"
	else
		echo "${bytes}B"
	fi
}

function listConnectedClients() {
	local status_file="/var/log/openvpn/status.log"
	local format="${OUTPUT_FORMAT:-table}"

	if [[ ! -f "$status_file" ]]; then
		if [[ $format == "json" ]]; then
			echo '{"error":"Status file not found","clients":[]}'
		else
			log_warn "Status file not found: $status_file"
			log_info "Make sure OpenVPN is running."
		fi
		return
	fi

	local client_count
	client_count=$(grep -c "^CLIENT_LIST" "$status_file" 2>/dev/null) || client_count=0

	if [[ "$client_count" -eq 0 ]]; then
		if [[ $format == "json" ]]; then
			echo '{"clients":[]}'
		else
			log_header "Connected Clients"
			log_info "No clients currently connected."
			log_info "Note: Data refreshes every 60 seconds."
		fi
		return
	fi

	# Collect client data
	local clients_data=()
	while IFS=',' read -r _ name real_addr vpn_ip _ bytes_recv bytes_sent connected_since _; do
		clients_data+=("$name|$real_addr|$vpn_ip|$bytes_recv|$bytes_sent|$connected_since")
	done < <(grep "^CLIENT_LIST" "$status_file")

	if [[ $format == "json" ]]; then
		echo '{"clients":['
		local first=true
		for client_entry in "${clients_data[@]}"; do
			IFS='|' read -r name real_addr vpn_ip bytes_recv bytes_sent connected_since <<<"$client_entry"
			[[ $first == true ]] && first=false || printf ','
			printf '{"name":"%s","real_address":"%s","vpn_ip":"%s","bytes_received":%s,"bytes_sent":%s,"connected_since":"%s"}\n' \
				"$(json_escape "$name")" "$(json_escape "$real_addr")" "$(json_escape "$vpn_ip")" \
				"${bytes_recv:-0}" "${bytes_sent:-0}" "$(json_escape "$connected_since")"
		done
		echo ']}'
	else
		log_header "Connected Clients"
		log_info "Found $client_count connected client(s)"
		log_menu ""
		printf "   %-20s %-22s %-16s %-20s %s\n" "Name" "Real Address" "VPN IP" "Connected Since" "Transfer"
		printf "   %-20s %-22s %-16s %-20s %s\n" "----" "------------" "------" "---------------" "--------"

		for client_entry in "${clients_data[@]}"; do
			IFS='|' read -r name real_addr vpn_ip bytes_recv bytes_sent connected_since <<<"$client_entry"
			local recv_human sent_human
			recv_human=$(formatBytes "$bytes_recv")
			sent_human=$(formatBytes "$bytes_sent")
			local transfer="↓${recv_human} ↑${sent_human}"
			printf "   %-20s %-22s %-16s %-20s %s\n" "$name" "$real_addr" "$vpn_ip" "$connected_since" "$transfer"
		done
		log_menu ""
		log_info "Note: Data refreshes every 60 seconds."
	fi
}

function newClient() {
	clear
	echo -e "${YELLOW}[+] Creating a ovpn-file for one (1) client...${NOCOLOR}"
	echo -e "${RED}[+] Tell me a name for the client.${NOCOLOR}"
	echo "    The name must consist of alphanumeric characters, underscores, or dashes (max $MAX_CLIENT_NAME_LENGTH characters)."
	until is_valid_client_name "$CLIENT"; do
		read -rp "    Client name: " -e CLIENT
	done

	if [[ -z $CLIENT_CERT_DURATION_DAYS ]] || ! [[ $CLIENT_CERT_DURATION_DAYS =~ ^[0-9]+$ ]] || [[ $CLIENT_CERT_DURATION_DAYS -lt 1 ]]; then
		log_menu ""
		log_prompt "How many days should the client certificate be valid for?"
		until [[ $CLIENT_CERT_DURATION_DAYS =~ ^[0-9]+$ ]] && [[ $CLIENT_CERT_DURATION_DAYS -ge 1 ]]; do
			read -rp "Certificate validity (days): " -e -i $DEFAULT_CERT_VALIDITY_DURATION_DAYS CLIENT_CERT_DURATION_DAYS
		done
	fi

	echo ""
	echo -e "${RED}[+] Do you want to protect the configuration file with a password?${NOCOLOR}"
	echo -e "${RED}[+] (e.g. encrypt the private key with a password)${NOCOLOR}"
	echo "    1) Add a passwordless client"
	echo "    2) Use a password for the client"

	until [[ $PASS =~ ^[1-2]$ ]]; do
		read -rp "    Select an option [1-2]: " -e -i 1 PASS
	done

	CLIENTEXISTS=$(tail -n +2 $OPENVPN_SERVER_PATH/easy-rsa/pki/index.txt | grep -E "^V" | grep -c -E "/CN=$CLIENT\$")
	if [[ $CLIENTEXISTS != '0' ]]; then
		echo ""
		echo -e "${YELLOW}[!] The specified client name was already found, please choose another one.${NOCOLOR}"
		exit
	else
		cd $OPENVPN_SERVER_PATH/easy-rsa/ || return
		log_info "Generating client certificate..."
		export EASYRSA_CERT_EXPIRE=$CLIENT_CERT_DURATION_DAYS
		case $PASS in
		1)
			run_cmd_fatal "Building client certificate" ./easyrsa --batch build-client-full "$CLIENT" nopass
			;;
		2)
			log_warn "You will be asked for the client password below"
			# Run directly (not via run_cmd) so password prompt is visible to user
			if [[ -z "$PASSPHRASE" ]]; then
				log_warn "You will be asked for the client password below"
				# Run directly (not via run_cmd) so password prompt is visible to user
				if ! ./easyrsa --batch build-client-full "$CLIENT"; then
					log_fatal "Building client certificate failed"
				fi
			else
				log_info "Using provided passphrase for client certificate"
				# Use env var to avoid exposing passphrase in install log
				export EASYRSA_PASSPHRASE="$PASSPHRASE"
				run_cmd_fatal "Building client certificate" ./easyrsa --batch --passin=env:EASYRSA_PASSPHRASE --passout=env:EASYRSA_PASSPHRASE build-client-full "$CLIENT"
				unset EASYRSA_PASSPHRASE
			fi
			;;
		esac
		log_success "Client $CLIENT added and is valid for $CLIENT_CERT_DURATION_DAYS days."

		# Write the .ovpn config file with proper path and permissions
		# writeClientConfig "$CLIENT" --> these function is not necessary for TorBox
		clientFilePath="$homeDir/$CLIENT.ovpn"
		# generateClientConfig "$client" "$clientFilePath"
		generateClientConfig "$CLIENT" "$clientFilePath"

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
	fi
}

function revokeClient() {
	clear
	log_header "Revoke Client"
	log_prompt "Select the existing client certificate you want to revoke"
	selectClient
	cd $OPENVPN_SERVER_PATH/easy-rsa/ || return
	log_info "Revoking certificate for $CLIENT..."
	run_cmd_fatal "Revoking certificate" ./easyrsa --batch revoke-issued "$CLIENT"
	regenerateCRL
	run_cmd "Removing client config from /home" find /home/ -maxdepth 2 -name "$CLIENT.ovpn" -delete
	run_cmd "Removing client config from /root" rm -f "/root/$CLIENT.ovpn"
	run_cmd "Removing IP assignment" sed -i "/^$CLIENT,.*/d" $OPENVPN_SERVER_PATH/ipp.txt
	run_cmd "Backing up index" cp $OPENVPN_SERVER_PATH/easy-rsa/pki/index.txt{,.bk}
	log_success "Certificate for client $CLIENT revoked."
	echo ""
	read -n1 -r -p "Press any key to continue..."
}

function renewClient() {
	clear
	local homeDir client_cert_duration_days
	log_header "Renew Client Certificate"
	log_prompt "Select the existing client certificate you want to renew"
	selectClient "true"
	# Allow user to specify renewal duration (use CLIENT_CERT_DURATION_DAYS env var for headless mode)
	if [[ -z $CLIENT_CERT_DURATION_DAYS ]] || ! [[ $CLIENT_CERT_DURATION_DAYS =~ ^[0-9]+$ ]] || [[ $CLIENT_CERT_DURATION_DAYS -lt 1 ]]; then
		log_menu ""
		log_prompt "How many days should the renewed certificate be valid for?"
		until [[ $client_cert_duration_days =~ ^[0-9]+$ ]] && [[ $client_cert_duration_days -ge 1 ]]; do
			read -rp "Certificate validity (days): " -e -i $DEFAULT_CERT_VALIDITY_DURATION_DAYS client_cert_duration_days
		done
	else
		client_cert_duration_days=$CLIENT_CERT_DURATION_DAYS
	fi
	cd $OPENVPN_SERVER_PATH/easy-rsa/ || return
	log_info "Renewing certificate for $CLIENT..."
	# Backup the old certificate before renewal
	run_cmd "Backing up old certificate" cp "$OPENVPN_SERVER_PATH/easy-rsa/pki/issued/$CLIENT.crt" "$OPENVPN_SERVER_PATH/easy-rsa/pki/issued/$CLIENT.crt.bak"
	# Renew the certificate (keeps the same private key)
	export EASYRSA_CERT_EXPIRE=$client_cert_duration_days
	run_cmd_fatal "Renewing certificate" ./easyrsa --batch renew "$CLIENT"
	# Revoke the old certificate
	run_cmd_fatal "Revoking old certificate" ./easyrsa --batch revoke-renewed "$CLIENT"
	# Regenerate the CRL
	regenerateCRL

	# Regenerate the .ovpn file with the new certificate
	clientFilePath="$homeDir/$CLIENT.ovpn"
	# generateClientConfig "$client" "$clientFilePath"
	generateClientConfig "$CLIENT" "$clientFilePath"

	log_menu ""
	log_success "Certificate for client $CLIENT renewed and is valid for $client_cert_duration_days days."
	log_info "The new configuration file has been written to $homeDir/$CLIENT.ovpn."
	log_info "Download the new .ovpn file and import it in your OpenVPN client."
	echo ""
	read -n1 -r -p "Press any key to continue..."
}

function renewServer() {
	clear
	local server_name server_cert_duration_days

	log_header "Renew Server Certificate"

	# Get the server name from the config (extract basename since path may be relative)
	server_name=$(basename "$(grep '^cert ' $OPENVPN_CONF | cut -d ' ' -f 2)" .crt)
	if [[ -z "$server_name" ]]; then
		log_fatal "Could not determine server certificate name from $OPENVPN_CONF"
	fi

	log_prompt "This will renew the server certificate: $server_name"
	log_warn "The OpenVPN service will be restarted after renewal."
	if [[ -z $CONTINUE ]]; then
		read -rp "Do you want to continue? [y/n]: " -e -i n CONTINUE
	fi
	if [[ $CONTINUE != "y" ]]; then
		log_info "Renewal aborted."
		return
	fi

	# Allow user to specify renewal duration (use SERVER_CERT_DURATION_DAYS env var for headless mode)
	if [[ -z $SERVER_CERT_DURATION_DAYS ]] || ! [[ $SERVER_CERT_DURATION_DAYS =~ ^[0-9]+$ ]] || [[ $SERVER_CERT_DURATION_DAYS -lt 1 ]]; then
		log_menu ""
		log_prompt "How many days should the renewed certificate be valid for?"
		until [[ $server_cert_duration_days =~ ^[0-9]+$ ]] && [[ $server_cert_duration_days -ge 1 ]]; do
			read -rp "Certificate validity (days): " -e -i $DEFAULT_CERT_VALIDITY_DURATION_DAYS server_cert_duration_days
		done
	else
		server_cert_duration_days=$SERVER_CERT_DURATION_DAYS
	fi

	cd $OPENVPN_SERVER_PATH/easy-rsa/ || return
	log_info "Renewing server certificate..."

	# Backup the old certificate before renewal
	run_cmd "Backing up old certificate" cp "$OPENVPN_SERVER_PATH/easy-rsa/pki/issued/$server_name.crt" "$OPENVPN_SERVER_PATH/easy-rsa/pki/issued/$server_name.crt.bak"

	# Renew the certificate (keeps the same private key)
	export EASYRSA_CERT_EXPIRE=$server_cert_duration_days
	run_cmd_fatal "Renewing certificate" ./easyrsa --batch renew "$server_name"

	# Revoke the old certificate
	run_cmd_fatal "Revoking old certificate" ./easyrsa --batch revoke-renewed "$server_name"

	# Regenerate the CRL
	regenerateCRL

	# Copy the new certificate to /etc/openvpn/server/
	run_cmd_fatal "Copying new certificate" cp "$OPENVPN_SERVER_PATH/easy-rsa/pki/issued/$server_name.crt" $OPENVPN_SERVER_PATH

	# Restart OpenVPN
	log_info "Restarting OpenVPN service..."
	run_cmd "Restarting OpenVPN" systemctl restart openvpn-server@server
	log_success "Server certificate renewed successfully and is valid for $server_cert_duration_days days."
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
				if [ "$DISABLED_CHOICE" = "1" ]; then
					clear
					echo " "
					echo -e "${RED}[+] Temporary disabling the OpenVPN server...${NOCOLOR}"
					sudo systemctl stop openvpn-server@server
					sudo systemctl daemon-reload
					sleep 2
				elif [ $DISABLED_CHOICE = 2 ]; then
					clear
					echo -e "${RED}[+] Permanently disabling the OpenVPN server...${NOCOLOR}"
					sudo systemctl stop openvpn-server@server
					sudo systemctl disable openvpn-server@server
					sudo systemctl mask --now openvpn-server@server
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
			sudo systemctl unmask openvpn-server@server
			sudo systemctl enable openvpn-server@server
			sudo systemctl start openvpn-server@server
		  sudo systemctl daemon-reload
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
		log_info "Stopping OpenVPN service..."
		run_cmd "Disabling OpenVPN service" systemctl disable openvpn-server@server
		run_cmd "Stopping OpenVPN service" systemctl stop openvpn-server@server
		run_cmd "Masking OpenVPN service" systemctl mask --now openvpn-server@server
		# Remove customised service
		run_cmd "Removing service file" rm -f /etc/systemd/system/openvpn-server@.service
		run_cmd "Reload daemon" systemctl daemon-reload

		# SELinux
		if hash sestatus 2>/dev/null; then
			if sestatus | grep "Current mode" | grep -qs "enforcing"; then
				if [[ $PORT != '1194' ]]; then
					run_cmd "Removing SELinux port" semanage port -d -t openvpn_port_t -p "$PROTOCOL" "$PORT"
				fi
			fi
		fi

		# Cleanup
		run_cmd "Removing client configs from /home" find /home/ -maxdepth 2 -name "*.ovpn" -delete
		run_cmd "Removing client configs from /root" find /root/ -maxdepth 1 -name "*.ovpn" -delete
		run_cmd "Removing /etc/openvpn" rm -rf /etc/openvpn
		run_cmd "Removing OpenVPN docs" rm -rf /usr/share/doc/openvpn*
		run_cmd "Removing sysctl config" rm -f /etc/sysctl.d/99-openvpn.conf
		run_cmd "Removing OpenVPN logs" rm -rf /var/log/openvpn

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
	CHOICE=$(whiptail --cancel-button "Back" --title "TorBox v.0.5.5 - OpenVPN Server Management" --menu "Choose an option (ESC -> back to the main menu)" $MENU_HEIGHT $MENU_WIDTH $MENU_LIST_HEIGHT \
	"==" "===============================================================" \
	" 1" "Add a new client" \
	" 2" "List client certificates" \
	" 3" "Revoke an existing client" \
	" 4" "Renew a certificate" \
	" 5" "List connected clients" \
	" 6" "$TOGGLE01 the OpenVPN server $TOGGLE02" \
	" 7" "Remove the OpenVPN server capability and configuration" \
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
		listClients
		;;
	3)
		revokeClient
		;;
	4)
		renewMenu
		;;
	5)
		listConnectedClients
		;;
	6)
		stopOpenVPN
		;;
	7)
		removeOpenVPN
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
