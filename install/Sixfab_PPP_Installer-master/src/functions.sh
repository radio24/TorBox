#!/bin/bash

source configs.sh

YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[1;34m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
SET='\033[0m'

function debug
{
    ECHO_PARAM=${2:-''}
    echo -e $ECHO_PARAM ${GREEN}$(date "+%Y/%m/%d->${BLUE}%H:%M:%S") ${SET} "$1"
}

function check_network()
{   
    # Check the network is ready
    debug "Checking the network is ready..."

    for n in $(seq 1 $NETWORK_CHECK_TIMEOUT); do
        NETWORK_OK=0

        debug "SIM Status: " "-n" # no line break
        atcom AT+CPIN? | grep "CPIN: READY"
        SIM_READY=$?

        if [[ $SIM_READY -ne 0 ]]; then  atcom AT+CPIN? | grep "CPIN:"; fi


        debug "Network Registration Status: " "-n" # no line break
        NR_TEXT=`atcom AT+CREG? | grep "CREG:"`
        echo $NR_TEXT

         # For super SIM
        echo $NR_TEXT | grep "CREG: 0,5" > /dev/null
        NETWORK_REG_1=$?
        echo $NR_TEXT | grep "CREG: 1,5" > /dev/null
        NETWORK_REG_2=$?
        echo $NR_TEXT | grep "CREG: 2,5" > /dev/null
        NETWORK_REG_3=$?

        # For native SIM
        echo $NR_TEXT | grep "CREG: 0,1" > /dev/null
        NETWORK_REG_4=$?
        echo $NR_TEXT | grep "CREG: 1,1" > /dev/null
        NETWORK_REG_5=$?
        echo $NR_TEXT | grep "CREG: 2,1" > /dev/null
        NETWORK_REG_6=$?

        # Combined network registration status
        NETWORK_REG=$((NETWORK_REG_1 & NETWORK_REG_2 & NETWORK_REG_3 & NETWORK_REG_4 & NETWORK_REG_5 & NETWORK_REG_6))
        
        if [[ $SIM_READY -eq 0 ]] && [[ $NETWORK_REG -eq 0 ]]; then
            debug "Network is ready."
            NETWORK_OK=1
            return 0
            break
        else
            debug "Retrying network registration..."
        fi
        sleep 2
    done
    debug "Network registration is failed! Please check SIM card, data plan, antennas etc."
    return 1
}
