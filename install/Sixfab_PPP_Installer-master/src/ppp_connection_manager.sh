#!/bin/bash

source functions.sh

for i in {1..4}; do
    bash configure_modem.sh
    
    if [[ $MODEM_CONFIG -eq 0 ]]; then
        break
    fi
    sleep 1
done

if [[ $MODEM_CONFIG -eq 0 ]]; then
    bash ppp_reconnect.sh
else
    debug "Modem configuration is failed multiple times!" 
    debug "Checkout other troubleshooting steps on docs.sixfab.com."
    exit 1
fi
