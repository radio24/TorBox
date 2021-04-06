#!/bin/bash

SCRIPT_NAME="install-rtl8821cu.sh"
SCRIPT_VERSION="20210401"

DRV_NAME="rtl8821cu"
DRV_VERSION="5.8.1.7"
OPTIONS_FILE="8821cu.conf"

DRV_DIR="$(pwd)"
KRNL_VERSION="$(uname -r)"

echo ""
echo "${SCRIPT_NAME} version ${SCRIPT_VERSION}"

# check to ensure sudo was used
if [[ $EUID -ne 0 ]]; then
	echo "You must run this script with superuser (root) privileges."
	echo "Try: \"sudo ./${SCRIPT_NAME}\""
	exit 1
fi

# check for previous installation
if [[ -d "/usr/src/${DRV_NAME}-${DRV_VERSION}" ]]; then
	echo "It appears that this driver may already be installed."
	exit 1
fi

# the add command requires source in /usr/src/${DRV_NAME}-${DRV_VERSION}
echo "Copying source files to: /usr/src/${DRV_NAME}-${DRV_VERSION}"
cp -rf "${DRV_DIR}" /usr/src/${DRV_NAME}-${DRV_VERSION}
echo "Copying ${OPTIONS_FILE} to: /etc/modprobe.d"
cp -f ${OPTIONS_FILE} /etc/modprobe.d
echo "All required files have been copied to the proper places."

dkms add -m ${DRV_NAME} -v ${DRV_VERSION}
# dkms add ${DRV_NAME}/${DRV_VERSION}
RESULT=$?

if [[ "$RESULT" != "0" ]]; then
	echo "An error occurred while running: dkms add : ${RESULT}"
	echo "Please report errors."
	exit $RESULT
fi

dkms build -m ${DRV_NAME} -v ${DRV_VERSION}
RESULT=$?

if [[ "$RESULT" != "0" ]]; then
	echo "An error occurred while running: dkms build : ${RESULT}"
	echo "Please report errors."
	exit $RESULT
fi

dkms install -m ${DRV_NAME} -v ${DRV_VERSION}
RESULT=$?

if [[ "$RESULT" != "0" ]]; then
	echo "An error occurred while running: dkms install : ${RESULT}"
	echo "Please report errors."
	exit $RESULT
fi

echo "The driver was installed successfully."

exit 0
