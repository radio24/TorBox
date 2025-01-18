#!/bin/bash
#
# This script starts Tor Browser on macOS without Tor.
# It uses TorBox's SOKCKS 5 values as proxy settings for the Tor Browser.
# This prevents a "Tor over Tor" Scenario.
# For more information, see here:
# https://www.torbox.ch/?page_id=1218
# https://www.torbox.ch/?page_id=112#torovertor
# https://www.whonix.org/wiki/Other_Operating_Systems#Tor_Browser_Settings
# https://www.whonix.org/wiki/Other_Operating_Systems#Remove_Proxy_Settings
# https://www.whonix.org/wiki/Other_Operating_Systems#Configure_Tor_Browser_Settings

clear
echo " "
echo "This script starts the Tor Browser without Tor and link to your TorBox."
echo "Without TorBox, the Tor Browser will not work !!"
echo "After closing the Tor Browser, the script restores the old settings."
read -n 1 -s -r -p "Press any key to continue"
clear

export TOR_NO_DISPLAY_NETWORK_SETTINGS=1
export TOR_SKIP_CONTROLPORTTEST=1
export TOR_SKIP_LAUNCH=1
FIREFOX_PROF_PATH=$(grep "^Path" ~/Library/Application\ Support/TorBrowser-Data/Browser/profiles.ini)
DEFAULT=$(echo $FIREFOX_PROF_PATH |cut -c6-)
echo " "
echo " "
echo "user_pref(\"extensions.torbutton.use_privoxy\", false);
user_pref(\"extensions.torbutton.settings_method\", \"custom\");
user_pref(\"extensions.torbutton.socks_host\", \"192.168.42.1\");
user_pref(\"extensions.torbutton.socks_port\", 9050);
user_pref(\"network.proxy.socks\", \"192.168.42.1\");
user_pref(\"network.proxy.socks_port\", 9050);
user_pref(\"extensions.torbutton.custom.socks_host\", \"192.168.42.1\");
user_pref(\"extensions.torbutton.custom.socks_port\", 9050);
user_pref(\"extensions.torlauncher.control_host\", \"192.168.42.1\");
user_pref(\"extensions.torlauncher.control_port\", 9051);" | tee -a ~/Library/Application\ Support/TorBrowser-Data/Browser/$DEFAULT/user.js
/Applications/Tor\ Browser.app/Contents/MacOS/firefox &
sleep 2
clear
echo " "
echo "Tor Browser successfully launched!"
echo "DONT CLOSE THAT WINDOW, YET if you want to restore the original behavior of"
echo "the Tor Browser with its own Tor instance. Close first the Tor Browser, then"
read -n 1 -s -r -p "press any key to continue"

rm ~/Library/Application\ Support/TorBrowser-Data/Browser/$DEFAULT/user.js
sed -i -e "s/^user_pref(\"extensions.torbutton.use_privoxy\".*//g" ~/Library/Application\ Support/TorBrowser-Data/Browser/$DEFAULT/prefs.js
sed -i -e "s/^user_pref(\"extensions.torbutton.settings_method\".*//g" ~/Library/Application\ Support/TorBrowser-Data/Browser/$DEFAULT/prefs.js
sed -i -e "s/^user_pref(\"extensions.torbutton.socks_host\".*//g" ~/Library/Application\ Support/TorBrowser-Data/Browser/$DEFAULT/prefs.js
sed -i -e "s/^user_pref(\"extensions.torbutton.socks_port\".*//g" ~/Library/Application\ Support/TorBrowser-Data/Browser/$DEFAULT/prefs.js
sed -i -e "s/^user_pref(\"network.proxy.socks\".*//g" ~/Library/Application\ Support/TorBrowser-Data/Browser/$DEFAULT/prefs.js
sed -i -e "s/^user_pref(\"network.proxy.socks_port\".*//g" ~/Library/Application\ Support/TorBrowser-Data/Browser/$DEFAULT/prefs.js
sed -i -e "s/^user_pref(\"extensions.torbutton.custom.socks_host\".*//g" ~/Library/Application\ Support/TorBrowser-Data/Browser/$DEFAULT/prefs.js
sed -i -e "s/^user_pref(\"extensions.torbutton.custom.socks_port\".*//g" ~/Library/Application\ Support/TorBrowser-Data/Browser/$DEFAULT/prefs.js
sed -i -e "s/^user_pref(\"extensions.torlauncher.control_host\".*//g" ~/Library/Application\ Support/TorBrowser-Data/Browser/$DEFAULT/prefs.js
sed -i -e "s/^user_pref(\"extensions.torlauncher.control_port\".*//g" ~/Library/Application\ Support/TorBrowser-Data/Browser/$DEFAULT/prefs.js
sleep 2
clear
echo " "
echo "You can close this window now."
sleep 10
exit
