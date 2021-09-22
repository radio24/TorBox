@echo off
cls
echo.
rem # This script starts Tor Browser on Windows without Tor.
rem # It uses TorBox's SOKCKS 5 values as proxy settings for the Tor Browser.
rem # This prevents a "Tor over Tor" Scenario.
rem # For more information see here:
rem # https://www.torbox.ch/?page_id=1218
rem # https://www.torbox.ch/?page_id=112#torovertor
rem # https://www.whonix.org/wiki/Other_Operating_Systems#Tor_Browser_Settings
rem # https://www.whonix.org/wiki/Other_Operating_Systems#Remove_Proxy_Settings
rem # https://www.whonix.org/wiki/Other_Operating_Systems#Configure_Tor_Browser_Settings

rem # Edit if necessary! This is the relative path to TorBrowser's used profile (without final \):
set DEFAULT=Browser\TorBrowser\Data\Browser\profile.default

cls
echo.
echo This script will start the Tor Browser without Tor and link to your TorBox.
echo Without TorBox the Tor Browser will not work !!
echo After closing the Tor Browser the script restores the old settings.
echo If asked, say NO to the question of overwriting prefs.bak because otherwise,
echo restoring the old settings may not be possible anymore!!
echo.
pause
cls

copy %DEFAULT%\prefs.js browser\TorBrowser\Data\Browser\profile.default\prefs.bak /-y
set TOR_NO_DISPLAY_NETWORK_SETTINGS=1
set TOR_SKIP_CONTROLPORTTEST=1
set TOR_SKIP_LAUNCH=1
echo.
echo.
echo user_pref("extensions.torbutton.use_privoxy", false); > %DEFAULT%\user.js
echo user_pref("extensions.torbutton.settings_method", "custom"); >> %DEFAULT%\user.js
echo user_pref("extensions.torbutton.socks_host", "192.168.43.1"); >> %DEFAULT%\user.js
echo user_pref("extensions.torbutton.socks_port", 9050); >> %DEFAULT%\user.js
echo user_pref("network.proxy.socks", "192.168.43.1"); >> %DEFAULT%\user.js
echo user_pref("network.proxy.socks_port", 9050); >> %DEFAULT%\user.js
echo user_pref("extensions.torbutton.custom.socks_host", "192.168.43.1"); >> %DEFAULT%\user.js
echo user_pref("extensions.torbutton.custom.socks_port", 9050); >> %DEFAULT%\user.js
echo user_pref("extensions.torlauncher.control_host", "192.168.43.1"); >> %DEFAULT%\user.js
echo user_pref("extensions.torlauncher.control_port", 9051); >> %DEFAULT%\user.js
"Start Tor Browser.lnk" --detach

timeout /t 2 /nobreak > NUL
cls
echo.
echo Tor Browser successfully launched!
echo DONT CLOSE THAT WINDOW, YET if you want to restore the original behavior of
echo the Tor Browser with its own Tor instance. Close first the Tor Browser, then...
pause

copy %DEFAULT%\prefs.bak %DEFAULT%\prefs.js
del %DEFAULT%\prefs.bak
del %DEFAULT%\user.js

timeout /t 2 /nobreak > NUL
cls
echo.
echo "You can close this window now."
timeout /t 10 > NUL
exit
