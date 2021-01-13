#!/bin/sh

YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[1;34m'
SET='\033[0m'

echo "${YELLOW}Please choose your Sixfab Shield/HAT:${SET}"
echo "${YELLOW}1: GSM/GPRS Shield${SET}"
echo "${YELLOW}2: 3G, 4G/LTE Base Shield${SET}"
echo "${YELLOW}3: Cellular IoT App Shield${SET}"
echo "${YELLOW}4: Cellular IoT HAT${SET}"
echo "${YELLOW}5: Tracker HAT${SET}"
echo "${YELLOW}6: 3G/4G Base HAT${SET}"


read shield_hat
case $shield_hat in
    1)    echo "${YELLOW}You chose GSM/GPRS Shield${SET}";;
    2)    echo "${YELLOW}You chose Base Shield${SET}";;
    3)    echo "${YELLOW}You chose CellularIoT Shield${SET}";;
    4)    echo "${YELLOW}You chose CellularIoT HAT${SET}";;
	5)    echo "${YELLOW}You chose Tracker HAT${SET}";;
	6)    echo "${YELLOW}You chose 3G/4G Base HAT${SET}";;
    *)    echo "${RED}Wrong Selection, exiting${SET}"; exit 1;
esac

#Downloading setup files as will as ppp wiringpi is not necessary, because they are alredy there
#However, we have to copy some unchanged configuration files
sudo cp unchanged_files/provider .

echo "${YELLOW}What is your carrier APN?${SET}"
read carrierapn

while [ 1 ]
do
	echo "${YELLOW}Does your carrier need username and password? [Y/n]${SET}"
	read usernpass

	case $usernpass in
		[Yy]* )  while [ 1 ]
        do

        echo "${YELLOW}Enter username${SET}"
        read username

        echo "${YELLOW}Enter password${SET}"
        read password
        sed -i "s/noauth/#noauth\nuser \"$username\"\npassword \"$password\"/" provider
        break
        done

        break;;

		[Nn]* )  break;;
		*)  echo "${RED}Wrong Selection, Select among Y or n${SET}";;
	esac
done

echo "${YELLOW}What is your device communication PORT? (ttyS0/ttyUSB3/etc.)${SET}"
read devicename

mkdir -p /etc/chatscripts

cp chat-connect /etc/chatscripts/
cp chat-disconnect /etc/chatscripts/

mkdir -p /etc/ppp/peers
sed -i "s/#APN/$carrierapn/" provider
sed -i "s/#DEVICE/$devicename/" provider
mv provider /etc/ppp/peers/provider

if ! (grep -q 'sudo route' /etc/ppp/ip-up ); then
    echo "sudo route add default ppp0" >> /etc/ppp/ip-up
fi

if [ $shield_hat -eq 2 ]; then
	if ! (grep -q 'max_usb_current' /boot/config.txt ); then
		echo "max_usb_current=1" >> /boot/config.txt
	fi
fi

while [ 1 ]
do
	echo "${YELLOW}Do you want to activate auto connect/reconnect service at R.Pi boot up? [Y/n] ${SET}"
	read auto_reconnect

	case $auto_reconnect in
		[Yy]* )
#Downloading setup files as will as ppp wiringpi is not necessary, because they are alredy there
			  cp reconnect.sh /usr/src/
			  cp reconnect.service /etc/systemd/system/

			  systemctl daemon-reload
			  systemctl enable reconnect.service

			  break;;

		[Nn]* )    echo "${YELLOW}To connect to internet run ${BLUE}\"sudo pon\"${YELLOW} and to disconnect run ${BLUE}\"sudo poff\" ${SET}"
			  break;;
		*)   echo "${RED}Wrong Selection, Select among Y or n${SET}";;
	esac
done

#read -p "Press ENTER key to reboot" ENTER
#reboot
