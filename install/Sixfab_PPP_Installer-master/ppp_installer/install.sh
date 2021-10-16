#!/bin/bash

# Colors
YELLOW='\033[1;33m'
RED='\033[1;31m'
BLUE='\033[1;34m'
WHITE='\033[1;37m'
SET='\033[0m'

# Global Varibales
POWERUP_REQ=1
POWERUP_NOT_REQ=0
STATUS_GPRS=19
STATUS_CELL_IOT_APP=20
STATUS_CELL_IOT=23
STATUS_TRACKER=23
POWERKEY_GPRS=26
POWERKEY_CELL_IOT_APP=11
POWERKEY_CELL_IOT=24
POWERKEY_TRACKER=24

# Paths
# SIXFAB_PATH="/opt/sixfab"
# PPP_PATH="/opt/sixfab/ppp_connection_manager"

clear
echo -e "${RED}[+] Installing Sixfab Shield/HATs support${NOCOLOR}"
echo -e ""

# Check Sixfab path
# if [[ -e $SIXFAB_PATH ]]; then
#    echo -e "${RED}[+] Sixfab path already exist!" ${SET}
# else
#     sudo mkdir $SIXFAB_PATH
#     echo -e "${RED}[+] Sixfab path is created." ${SET}
# fi

# Check PPP path
# if [[ -e $PPP_PATH ]]; then
#     echo -e "${RED}[+] PPP path already exist!" ${SET}
# else
#     sudo mkdir $PPP_PATH
#     echo -e "${RED}[+] PPP path is created." ${SET}
# fi
sleep 5

# Menu
clear
echo -e "${WHITE}Please choose your Sixfab Shield/HAT:${SET}"
echo -e "${RED}1: GSM/GPRS Shield${SET}"
echo -e "${RED}2: 3G, 4G/LTE Base Shield${SET}"
echo -e "${RED}3: Cellular IoT App Shield${SET}"
echo -e "${RED}4: Cellular IoT HAT${SET}"
echo -e "${RED}5: Tracker HAT${SET}"
echo -e "${RED}6: 3G/4G Base HAT${SET}"
echo -e ""

read shield_hat
clear
case $shield_hat in
    1)    echo -e "${RED}[+] You chose GSM/GPRS Shield${SET}";;
    2)    echo -e "${RED}[+] You chose Base Shield${SET}";;
    3)    echo -e "${RED}[+] You chose CellularIoT Shield${SET}";;
    4)    echo -e "${RED}[+] You chose CellularIoT HAT${SET}";;
	  5)    echo -e "${RED}[+] You chose Tracker HAT${SET}";;
	  6)    echo -e "${RED}[+] You chose 3G/4G Base HAT${SET}";;
    *)    echo -e "${WHITE}[!] Wrong Selection, exiting${SET}"; exit 1;
esac
sleep 3

#Downloading setup files as will as ppp wiringpi is not necessary, because they are alredy there
#However, we have to copy some unchanged configuration files
sudo cp unchanged_files/provider .
sudo cp unchanged_files/configure_modem.sh .

clear
echo -e "${RED}Enter your carrier APN:${SET}"
echo -e "${RED}(for more information see here: https://www.torbox.ch/?page_id=1030)${SET}"
read carrierapn

while [ 1 ]
do
  echo ""
	echo -e "${RED}Does your carrier need username and password? [Y/n]${SET}"
	read usernpass

	case $usernpass in
		[Yy]* )  while [ 1 ]
        do

        echo -e "${RED}Enter username${SET}"
        read username

        echo -e "${RED}Enter password${SET}"
        read password
        sed -i "s/noauth/#noauth\nuser \"$username\"\npassword \"$password\"/" provider
        break
        done

        break;;

		[Nn]* )  break;;
		*)  echo -e "${WHITE}Wrong Selection, Select among Y or n${SET}";;
	esac
done

mkdir -p /etc/chatscripts
cp chat-connect /etc/chatscripts/
cp chat-disconnect /etc/chatscripts/

mkdir -p /etc/ppp/peers
sed -i "s/#APN/$carrierapn/" provider
mv provider /etc/ppp/peers/provider

if ! (grep -q 'sudo route' /etc/ppp/ip-up ); then
    echo "sudo route add default ppp0" >> /etc/ppp/ip-up
fi

if [ $shield_hat -eq 2 ]; then
	if ! (grep -q 'max_usb_current' /boot/config.txt ); then
		echo "max_usb_current=1" >> /boot/config.txt
	fi
fi

# auto connect/reconnect doesn't work
# while [ 1 ]
# do
#	echo -e "${RED}Do you want to activate auto connect/reconnect service at R.Pi boot up? [Y/n] ${SET}"
#	read auto_reconnect
#
#	case $auto_reconnect in
#		[Yy]* ) sed -i "s/SIM_APN/$carrierapn/" configure_modem.sh
#
#            if [ $shield_hat -eq 1 ]; then
#              cp unchanged_files/reconnect_gprsshield ppp_reconnect.sh
#        			sed -i "s/STATUS_PIN/$STATUS_GPRS/" configure_modem.sh
#				      sed -i "s/POWERKEY_PIN/$POWERKEY_GPRS/" configure_modem.sh
#				      sed -i "s/POWERUP_FLAG/$POWERUP_REQ/" configure_modem.sh
#
#			      elif [ $shield_hat -eq 2 ]; then
#              cp unchanged_files/reconnect_baseshield ppp_reconnect.sh
#				      sed -i "s/POWERUP_FLAG/$POWERUP_NOT_REQ/" configure_modem.sh
#
#			      elif [ $shield_hat -eq 3 ]; then
#              cp unchanged_files/reconnect_cellulariot_app ppp_reconnect.sh
#				      sed -i "s/STATUS_PIN/$STATUS_CELL_IOT_APP/" configure_modem.sh
#				      sed -i "s/POWERKEY_PIN/$POWERKEY_CELL_IOT_APP/" configure_modem.sh
#				      sed -i "s/POWERUP_FLAG/$POWERUP_REQ/" configure_modem.sh
#
#			      elif [ $shield_hat -eq 4 ]; then
#              cp unchanged_files/reconnect_cellulariot_app ppp_reconnect.sh
#				      sed -i "s/STATUS_PIN/$STATUS_CELL_IOT/" configure_modem.sh
#				      sed -i "s/POWERKEY_PIN/$POWERKEY_CELL_IOT/" configure_modem.sh
#				      sed -i "s/POWERUP_FLAG/$POWERUP_REQ/" configure_modem.sh
#
#			      elif [ $shield_hat -eq 5 ]; then
#              cp unchanged_files/reconnect_tracker ppp_reconnect.sh
#				      sed -i "s/STATUS_PIN/$STATUS_TRACKER/" configure_modem.sh
#				      sed -i "s/POWERKEY_PIN/$POWERKEY_TRACKER/" configure_modem.sh
#				      sed -i "s/POWERUP_FLAG/$POWERUP_REQ/" configure_modem.sh
#
#			      elif [ $shield_hat -eq 6 ]; then
#              cp unchanged_files/reconnect_basehat ppp_reconnect.sh
#				      sed -i "s/POWERUP_FLAG/$POWERUP_NOT_REQ/" configure_modem.sh
#
#			      fi
#
#            cp functions.sh $PPP_PATH
#            cp configs.sh $PPP_PATH
#            mv configure_modem.sh $PPP_PATH
#            mv ppp_reconnect.sh $PPP_PATH
#            cp ppp_connection_manager.sh $PPP_PATH
#            cp ppp_connection_manager.service /etc/systemd/system/
#            systemctl daemon-reload
#            systemctl enable ppp_connection_manager.service
#
#            break;;
#
#		[Nn]* ) echo -e ""
#            echo -e "${WHITE}To connect to internet use main menu entry 8${SET}"
#			  break;;
#		*)   echo -e "${WHITE}Wrong Selection, Select among Y or n${SET}";;
#	esac
# done



sleep 2
clear
echo -e "${WHITE}The installation of the Sixfab Shield/HATs support is done!${SET}"
echo -e "${RED}To connect to internet use main menu entry 8${SET}"
echo -e ""
read -n 1 -s -r -p "Press any key to continue"
