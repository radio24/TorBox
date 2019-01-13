# TorBox
TorBox is an easy to use, anonymizing router based on Raspberry Pi. TorBox creates a separate WiFi that routes the encrypted network data over the Tor network. The type of client (desktop, laptop, tablet, mobile, etc.) and operating system on the client don’t matter.


# Disclaimer
TorBox is in an „alpha test phase“, it is a hobby-hack, a proof of concept ... not more and not less! USE IT AT YOUR OWN RISK!!! It is strongly advised not to use TorBox, if your well-being depends from your anonymity. Anonymity is hard to get - solely using Tor will not guarantee it. Malware, Cookies, Java, Flash, Javaskript and so on can compromise you. The Tor-website itself states that using it can't solve all anonymity problems. It focuses only on protecting the transport of data (https://www.torproject.org/about/overview.html.en). In this high-risk cases using the Tor Browser only (https://www.torproject.org/projects/torbrowser.html.en#downloads) or better Tails (https://tails.boum.org/) is highly recommended.

This HOWTO and the available TorBox image were build for Raspberry Pi 3 (Model B or Model B+; the B+ has a remarkable better network performance), because it is the most powerful version of the Raspberry Pi family so far and it comes with its own wireless network / Bluetooth chip.


#How to access
If you downloaded the TorBox image, then write it on a SD Card (for example with https://etcher.io), put the SD Card into a Raspberry Pi, start it, wait some minutes until the green LED stops to flicker and then try to connect the new access-point „TorBox023“. Connect with your SSH client to 192.168.42.1 (username: pi / password: CHANGE-IT). Now, you should see the TorBox menu.


#Passwords      
If you are using the TorBox image, then all passwords are set to CHANGE-IT. Root login of the TorBox image: pi/CHANGE-IT
You should change the default passwords a soon as possible. This is an easy task: login into your TorBox with an SSH client, "go to the advanced menu" (menu entry 10) and choose the right menu entries.



#BUILDING FROM SCRATCH
This installation/configuration is not necessary, if you have downloaded the TorBox image. Nevertheless, with the steps below, you should be able to built a TorBox from scratch based on Raspbian „Stretch“ Lite (based on Debian 9 „Stretch“). We suppose that you already did the basic configurations with raspbi-config (localization, keyboard layout and so on), that your Raspbian installation is working properly, that it has access to the internet and a sufficient power supply


A - Preparing your system

If you didn’t expand your filesystem over all your SD card storage, than it would be a good time to do it now with „sudo raspi-config“. Already started, eventually you should configure some additional options, like the hostname, the SSID etc, which will save you time later.

To get TorBox working, we have to install some additional software packages. 
But first, we have to be sure that the installed software is up-to-date:

Update firmware, the packet list, installed packages and remove unnecessary packages:
sudo apt-get update
sudo apt-get dist-upgrade
sudo apt-get clean
sudo apt-get autoclean
sudo apt-get autoremove

Depending on what was updated (firmware, kernel, driver ...), you should probably reboot your Raspberry Pi before continue.

Now, install all additional necessary packages:
#hostapd -> necessary to build a wireless access point.
#isc-dhcp-server -> necessary to buil a dhcp server.
#tor obfs4proxy -> necessary to use the Tor network.
#gvfs gvfs-fuse gvfs-backends gvfs-bin ipheth-utils libimobiledevice-utils usbmuxd -> necessary for the support of tethering devices.
#wicd wicd-curses -> an easy to use wireless lan selector and connector (Wireless Interface Connection Daemon).
#dnsmasq -> DNS forwarder (necessary to deal with captiv portals).
#dnsutils tcpdump -> Analytic network tools.
#termsaver slurm iftop vnstat links2 -> terminal screen saver and statistic tools (partially necessary for the menu).
#debian-goodies -> other usefull tools.
#dirmngr -> GNU privacy guard - network certificate management service.
#python3-setuptools -> Necessary tools for Python 3.
#ntpdate -> Client for setting system time.
#screen -> A terminal multiplexer allowing a user to access multiple separate login sessions inside a single terminal window, or detach and reattach sessions from a terminal.

sudo apt-get install hostapd isc-dhcp-server tor obfs4proxy gvfs gvfs-fuse gvfs-backends gvfs-bin ipheth-utils libimobiledevice-utils usbmuxd wicd wicd-curses dnsmasq dnsutils tcpdump termsaver slurm iftop vnstat links2 debian-goodies dirmngr python3-setuptools ntpdate screen

We don’t want to start dnsmasq automatically after booting the system:
sudo update-rc.d dnsmasq disable

Installing „nyx“ - a command-line monitor for Tor:
sudo easy_install3 pip
sudo pip3 install nyx
 

B - Disable Bluetooth
Because of security reasons, we recommend to completely disable the Bluetooth functionality of your Raspberry Pi. Skip this part, if you need Bluetooth functionality or undue it later (see also here: https://scribles.net/disabling-bluetooth-on-raspberry-pi/).

Change your /boot/config.txt:

sudo nano /boot/config.txt 

= add:
# ADDED: Disabling on-board Bluetooth
dtoverlay=pi3-disable-bt

Disable related services:
sudo systemctl disable hciuart.service
sudo systemctl disable bluealsa.service
sudo systemctl disable bluetooth.service

Remove the Bluetooth stack to make Bluetooth unavailable even if external Bluetooth adapter is plugged in:
sudo apt-get purge bluez -y
sudo apt-get autoremove -y

You have to reboot your Raspberry Pi to apply the changes.


C - Set up DHCP server

Set hostname to TorBox (instead of „raspberrypi“):
sudo nano /etc/hostname 
sudo nano /etc/hosts  

sudo nano /etc/dhcp/dhcpd.conf 

= edit:
option domain-name "example.org"; —>  #option domain-name "example.org";
option domain-name-servers ns1.example.org, ns2.example.org; —> #option domain-name-servers ns1.example.org, ns2.example.org;
#authoritative; —> authoritative;

= add:
subnet 192.168.42.0 netmask 255.255.255.0 {
range 192.168.42.10 192.168.42.50;
option broadcast-address 192.168.42.255;
option routers 192.168.42.1;
option domain-name "local";
option domain-name-servers 192.168.42.1;   #Stellt sicher, dass die DNS-Abfrage über Tor geschieht
}

sudo nano /etc/default/isc-dhcp-server

= edit:
INTERFACESv4="" -> INTERFACESv4="wlan0 eth0“ 

The classless static route option (RFC3442) will give us some headache with certain AP under certain conditions (see also https://ubuntuforums.org/showthread.php?t=1156441. Therefore we will remove this option from the configuration:
sudo nano /etc/dhcp/dhclient.conf

=edit:
option rfc3442-classless-static-routes code 121 = array of unsigned integer 8; -> #option rfc3442-classless-static-routes code 121 = array of unsigned integer 8;
request subnet-mask, broadcast-address, time-offset, routers, domain-name, domain-name-servers, domain-search, host-name, dhcp6.name-servers, dhcp6.domain-search, dhcp6.fqdn, dhcp6.sntp-servers, netbios-name-servers, netbios-scope, interface-mtu, rfc3442-classless-static-routes, ntp-servers; -> request subnet-mask, broadcast-address, time-offset, routers, domain-name, domain-name-servers, domain-search, host-name, dhcp6.name-servers, dhcp6.domain-search, dhcp6.fqdn, dhcp6.sntp-servers, netbios-name-servers, netbios-scope, interface-mtu, ntp-servers;



D - Set up the network interfaces

Currently TorBox supports following connections:

OUTPUT Internet	INPUT Client       MODE 		Remarks
--------------------------------------------------------------------------------------------------------------------------
ETH0                         WLAN0                WIRELESS	Cable-Internet
ETH1  			WLAN0                WIRELESS  	Tethering-Internet
WLAN1                      WLAN0                WIRELESS    Wireless-Internet
--------------------------------------------------------------------------------------------------------------------------
ETH1 (via USB)  	ETH0		   CABLE	     	Cable-Cable-connection or Tethering
WLAN0			ETH0		   CABLE		Cable-Wireless-connection
ETH1			ETH0		   CABLE		Tethering-Internet

By default, TorBox will provide an AP at wlan0 (WIRELESS MODE). Nevertheless, some testers requested a way to connect a device with an ethernet cable only. For that reason TorBox can switch to a CABLE MODUS, which exactly provides this capability. However, it i not possible to provide an AP and cable connection capability at the same time.

Below is the default configuration for the WIRELESS MODE (/etc/network/interfaces). It is not nescessary to configure the rest for the CABLE MODE, because all nescessary data is in the TorBox menu package (you will find that configuration file in the "TorBox menu" under /etc/network/interfaces).

sudo nano /etc/network/interfaces

= add:
auto lo

iface lo inet loopback
iface eth0 inet dhcp
iface eth1 inet dhcp
iface wlan1 inet dhcp
allow-hotplug wlan0 wlan1 eth0 eth1

iface wlan0 inet static
  address 192.168.42.1
  netmask 255.255.255.0

wireless-power off


sudo ifdown wlan0
sudo ifup wlan0


E - Configure the WiFi access point

sudo nano /etc/hostapd/hostapd.conf (you will find that configuration file in the "TorBox menu" file under /etc/hostapd)

= add:
interface=wlan0
driver=nl80211        
ssid=TorBox022
hw_mode=g
channel=6
ieee80211n=1
wmm_enabled=1
ht_capab=[HT40][SHORT-GI-20][DSSS_CCK-40]
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_passphrase=CHANGE-IT
wpa_key_mgmt=WPA-PSK
wpa_pairwise=TKIP
rsn_pairwise=CCMP

sudo nano /etc/default/hostapd

= edit:
#DAEMON_CONF="" —> DAEMON_CONF="/etc/hostapd/hostapd.conf"

sudo service hostapd start
sudo service isc-dhcp-server start
sudo update-rc.d hostapd enable
sudo update-rc.d isc-dhcp-server enable 



F - Configure Network Address Translation (NAT)

sudo nano /etc/sysctl.conf

=edit:
#net.ipv4.ip_forward=1 -> net.ipv4.ip_forward=1

We have to enable IP Forward to deal with captive portals:
sudo sh -c "echo 1 > /proc/sys/net/ipv4/ip_forward"



G - Tor

G1 - Installing the latest stable version of Tor

By default Raspbian offers an old stable package of Tor (version 0.2.9.x). We did install it during the preparing of your system (see under „A - Preparing your system“). If you like to stay with the older version, you can skip this subsection. Otherwise, this subsection will install the newest stable version of Tor (0.3.4.x), which is highly recommended.

sudo nano /etc/apt/sources.list

=add
deb https://deb.torproject.org/torproject.org stretch main
deb-src https://deb.torproject.org/torproject.org stretch main

gpg --keyserver keys.gnupg.net --recv A3C4F0F979CAA22CDBA8F512EE8CBC9E886DDD89
gpg --export A3C4F0F979CAA22CDBA8F512EE8CBC9E886DDD89 | sudo apt-key add -
sudo apt-get update
sudo apt-get install build-essential fakeroot devscripts
sudo apt build-dep tor deb.torproject.org-keyring
mkdir ~/debian-packages; cd ~/debian-packages
apt source tor; cd tor-*
debuild -rfakeroot -uc -us; cd ..
sudo dpkg -i tor_*.deb

G2 - Configuring Tor

sudo nano /etc/tor/torrc

= replace the content of /etc/tor/torrc with:
## Configuration for TorBox
Log notice file /var/log/tor/notices.log
VirtualAddrNetworkIPv4 10.192.0.0/10
AutomapHostsSuffixes .onion,.exit
AutomapHostsOnResolve 1
TransPort 192.168.42.1:9040
DNSPort 192.168.42.1:9053
DisableDebuggerAttachment 0
ControlPort 9051
HashedControlPassword <hashpassword>   #Use `tor --hash-password <password>` to get a hashed password (16:……). --- We will add it to ~/torbox/new_ident under „PASSWORD=„““, later.

## TorBox: This is the configuration for bridges to circumvent censorship
#  FascistFirewall 1 => This will not work properly
#UseBridges 1
#UpdateBridgesFromAuthority 1
#ClientTransportPlugin obfs4 exec /usr/bin/obfs4proxy
#Bridge obfs4 77.93.216.5:36735 179446D1793F4C7E4B2A935815B360ACF50F82F4 cert=DrR9Sz91616mnt560tAkCW491VSPDyV/CCqU5xvpyamcoV7jxI1/WepU4Dxq4fLsp7UZJw iat-mode=0

sudo mkdir /var/log/tor
sudo touch /var/log/tor/notices.log
sudo chown debian-tor /var/log/tor/notices.log
sudo service tor start
sudo update-rc.d tor enable

Remark to the entry „DNSPort“: DNS is the only UDP protocol, supported by Tor. In other words, DNS requests will be resolved through the Tor network and will not be leaked. 
Remark to ICMP: Tor will not deal with ICMP. To allow ping, traceroute and so on, ICMP packages will be leaked, but that shouldn’t be a problem.

G3 - Configuring obfs4proxy
sudo setcap 'cap_net_bind_service=+ep' /usr/local/bin/obfs4proxy



H - Configure the Wireless Interface Connection Daemon

WICD is an easy to use network connection manager. It provides a graphical text-interface to choose, configure and connect to a wireless network. Usually it is not necessary to run it manually. If needed, the TorBox menu (see below) will start it. Nevertheless, you should change or add following settings before you use it:

sudo nano /etc/wicd/manager-settings.conf

#change under „[Settings]“ to
wireless_interface = wlan1
wired_interface = eth0
dhcp_client = 1 
#Regarding "dhcp_client": WICD should always use dhclient!! Dhcpcd doesn't work correctly under certain conditions.

sudo nano /etc/wicd/wired-settings.conf

#change under „[wired-default]“ to
dhcphostname = TorBox023



I - Install the TorBox menu

With the TorBox menu, we will give you a user-friendly way to use and change the settings of your TorBox. The menu will be automatically started, whenever someone connect TorBox with an SSH client (for an incomplete list of ssh clients see below) at the TorBox's IP address (192.168.42.1). It is based on shell scripts, which will set the correct packet filtering and NAT rules as well as starts other supporting tools. All scripts are located under "~/torbox". They can be started manually with "sudo sh <shellskript>" which shouldn’t be necessary. To install the menu, use following commands:

cd
wget http://www.torbox.ch/data/torbox023-pre-20181202.zip
sudo unzip torbox023-pre-20181202.zip
cd
sudo nano .profile

= add at the end of the file:
cd torbox
sleep 2
sh menu

sudo  cp /etc/motd /etc/motd.ORIG
sudo cp ~/torbox/etc/motd /etc/motd

To be sure all is up in the right sequenz and running after a restart add following lines to /etc/rc.local:

sudo nano /etc/rc.local

= edit/add after the last „fi“ and before „exit 0“
sudo /sbin/iptables-restore < /etc/iptables.ipv4.nat
sudo service dnsmasq start
sleep 10
sudo /usr/sbin/ntpdate pool.ntp.org
sudo service dnsmasq stop
exit 0 #This is the last line in the file and the only „exit 0“ statement in the file

We want to be sure that we will be able to log into the TorBox via SSH after the restart:
sudo update-rc.d ssh enable

You should change the default passwords a soon as possible. This is an easy task: login into your TorBox with an SSH client, go to the advanced menu (menu entry 12) and choose the according menu entries.



J - A remark to the "Tethering" option

Attention!
If you use tethering via USB your smartphone will probably charge its battery. This could be problematic: If the Raspberry Pi doesn’t receive enough power (indicated by a flashing red led; see here: https://elinux.org/R-Pi_Troubleshooting), you eventually will be unable to connect to the AP of an Internet provider or will expirience all sorts of other strange behaviors. A better solution may be to create with your smartphone a personal hotspot instead of using tethering. Anyway, if you are using the tethering option, you should remove other power consumption devices and make sure that your Raspberry Pi has the best power source as you can get. If you are on the move, a good solution is to put a powerbank (like the RS Pro PB-10400 Power Bank, 5V / 10,4Ah, https://ch.rs-online.com/web/p/externer-akkupack/7757517/) in between.

Using tethering is simple. For example in case of an iPhone: Unlock your iPhone, but let the personal hotspot disabled for the time beeing and connect it with your Raspberry Pi's USB port. Choose to trust your iPhone (necessary!). Enable personal hotspot on your iPhone (USB only). Finally, in the TorBox menu, use entry number 8.

= list the interface (eth1):
ifconfig -s
ifconfig -a





#SSH-CLIENTS / TESTING / TIPS & TRICKS / USEFULL FIREFOX CONFIGURATION & ADDONS / TROUBLESHOOTING


a - SSH-clients and X11 forwarding

There is a hughe collection of SSH clients. Usually it doesn’t matter which one you are using. This are my personal favorites:
OSX: vSSH (http://www.velestar.com)
Windows: PuTTY (http://www.chiark.greenend.org.uk/~sgtatham/putty/)
iOS: vSSH (http://www.velestar.com) / Prompt (https://panic.com/prompt/index.html)
Android: vSSH (http://www.velestar.com)

For a list of other SSH clients, see here: https://en.wikipedia.org/wiki/Comparison_of_SSH_clients

= SSH anpassen für X11-Forwarding:
sudo nano /etc/ssh/sshd_config

= add
X11Forwarding yes
X11DisplayOffset 10

Tunnel X11 through SSH:
ssh -C -X pi@192.168.42.1
epiphany &



b - Usefull browser configration & addons

If your wellbeing depends on you anonymity, then it’s better to use the Tor Browser —> https://www.torproject.org/projects/torbrowser.html.en#downloads

Browser Add-ons:
#https-everywhere -> ESSENTIAL - SECURITY - ensures the use of SSL, if available (use https instead of http; available for Firefox and Chrome)
#uBlock Origin - ESSENTIAL - USABILITY - the only real working and independent ad blocker (available for Firefox, Safari and Chrome)
#Privacy Pass - ESSENTIAL - USABILITY - Privacy Pass is currently supported by Cloudflare to allow users to redeem validly signed tokens instead of completing CAPTCHA solutions. Clients receive 30 signed tokens for each CAPTCHA that is initially solved. (available for Firefox and Chrome)
#uMatrix - ESSENTIAL - SECURITY / ANONYMITY - Point and click matrix to filter net requests according to source, destination and type. (available for Firefox and Chrome)
#Privacy Badger -> IMPORTANT - ANONYMITY - Blocks trackers (available for Firefox and Chrome)
#Privacy Settings -> OPTIONAL - SECURITY / ANONYMITY - Alter Firefox's built-in privacy settings easily with a toolbar panel (not very usefull since QUANTUM; available for Firefox and Chrome).
#User Agent Switcher  -> OPTIONAL - ANONYMITY - Changes the User Agent, so that you don’t stand out (Firefox only).

Important configurations (under about:config):
To disable WebRTC (possible IP leak!!), search for media.peerconnection.enabled and double-click on it --> false.
To disable face detection using cameras, search for camera.control.face_detection.enabled --> false.
To disable geolocation services, search for geo.enabled --> false.
To disable the ability to report what plugins are installed, search plugin.scan.plid.all --> false.
To disable web speech recognition through the microphone, search media.webspeech.synth.enable and media.webspeech.recognition.enable --> false.
To disable all telemetry features, search for "telemetry" and disable all true/false settings related to telemetry by setting them to false.

For more information see: 
https://www.bestvpn.com/blog/7535/recommended-firefox-security-extensions/
https://vikingvpn.com/cybersecurity-wiki/browser-security/guide-hardening-mozilla-firefox-for-privacy-and-security

How do I permanently disable location-aware browsing in Chrome? (RECOMMENDED!)
-> Einstellungen -> Erweiterte Einstellungen anzeigen -> Privat -> Inhaltseinstellungen -> 



c - Some interesting .onion sites

Ahmia Search Engine --> http://msydqstlz2kzerdg.onion/
Deep dot Web News --> http://deepdot35wvmeyd5.onion/
OnionDir - Deep Web Link Directory -> http://dirnxxdraygbifgc.onion/
Deep Web Search Engine --> http://hss3uro2hsxfogfq.onion/
Duck Duck Go Search Engine --> https://3g2upl4pq6kufc4m.onion/
Facebook --> https://facebookcorewwwi.onion/
Imperial Library (Books) --> http://xfmro77i3lixucja.onion/
The Hidden Wiki --> http://zqktlwi4fecvo6ri.onion/wiki/index.php/Main_Page
The Pirate Bay --> http://uj3wazyk5u4hnvtk.onion/
The Tor Project Homepage --> http://expyuzz4wqqyqhjn.onion/
TorLinks --> http://torlinkbgs6aabns.onion/

See also here: http://deepweblinks.org/, https://de.wikipedia.org/wiki/Liste_von_bekannten_Hidden_Services_im_Tor-Netzwerk, https://en.wikipedia.org/wiki/List_of_Tor_hidden_services 



d - Testing

Test your connections: netstat
Test your network traffic speed: slurm -l -i eth0
Test your connections and your traffic speed: sudo iftop -i wlan1
Test your network transfers: watch -n1 vnstat / vnstat -l -i wlan1
Test nameservers: nslookup www.ethz.ch 192.168.42.1
Check the firewall rules dynamically: sudo watch -n1 iptables -vnL  /  sudo watch -n1 iptables -t nat -vnL
Configuration of your wireless network adapter: iwconfig
The anonymizing relay monitor: sudo -u debian-tor nyx
Are you using Tor?: https://check.torproject.org/ (Why do I receive a yellow onion? Because you didn’t change your User Agent, yet)
Are you using Tor’s DNS?: https://dns-leak.com/
DNS Nameserver Spoofability Test: https://www.grc.com/dns/dns.htm
IP Check: http://ip-check.info
Is your browser safe against tracking?: https://panopticlick.eff.org
IP Leak: http://ipleak.com/
What is my IP: http://www.whatismyip.com
IP in menubar (OSX clients): http://www.monkeybreadsoftware.de/Freeware/IPinmenubar.shtml
Tor Network Status: https://torstatus.blutmagie.de/index.php



e - Backup and restore images

The easy way to restor an image on a Mac: Etcher (https://etcher.io)

The Geek way to restore an image on a Mac:
- Find your SD Card reader device: sudo diskutil list
- Restore a compressed image: sudo gzip -dc /path/to/backup.gz | sudo dd of=/dev/rdiskx bs=1m (If the „resource busy“ message appears, then deactivate the mounted SD Card with diskutil).

Backup your SD Card:
sudo dd if=/dev/rdiskx bs=1m | gzip > /path/to/backup.gz



f - FAQ

Q: How can I block an IP address?
A: sudo route add 222.197.94.246 127.0.0.1 -reject

Q: My client connected to the TorBox doesn’t receive any IP address.
A: Usually the DHCP-server on TorBox will provide your client with all necessary information. If it doesn’t work, and you are sure that you client is configure accordingly, first try to restart TorBox. Shouldn’t that doesn’t work either, then try to configure your client manually:
     IPv4-address of your device: 192.168.42.x  (x > 12)
     Net Masq: 255.255.255.0
     Router / Gateway: 192.168.42.1
     DNS: 192.168.42.1 / torbox.ch

Q: My TorBox didn’t receive any IP address from the networks router.
A: TorBox is configured as an DHCP client, which means that the router have to give TorBox all necessary network information (usually the router is configured like that). If that doesn’t work, try to configure TorBox manually according the data of your provider or an actual client, which works with your router properly:
    sudo iptables <interface> <statische_IP_addresse>
    sudo route add default gw <gateway_ip>

Q: Wicd (the network manager) tried to connect a wireless network, but it stucks with "Validating authentication", the programm crashes and/or seems to have a lot of bugs.
A: It is crucial that your Raspberry Pi does receive enough power (the red LED must not blink!! See also here: https://elinux.org/R-Pi_Troubleshooting). If your Raspberry Pi doesn’t get enough power -- for example if it is connected to an USB port of your Laptop -- wicd tends to malfunction. In this case, try to unplugg all other USB devices, use a power adapter or put a battery pack between the power source and your Raspberry Pi (like the RS Pro PB-10400 Power Bank, 5V / 10,4Ah, https://ch.rs-online.com/web/p/externer-akkupack/7757517/).

Q: My TorBox did receive an IP address (192.168.42.*) from the network router, but it doesn’t work.
A: TorBox in its default configration occupies the IP-adresses 192.168.42.0 - 192.168.42.255 for its own purpose. In the very rare case in which the network router uses the same IP range, you have either to change the Ip range of the router or to change the configuration of the TorBox (for example changing all 192.168.42.* to 192.168.43.*. For more information, please contact me.

Q: I’m connected to TorBox and all is working as expected, but Firefox, Safari and any iOS device don't display .onion sites.
A: As per IETF RFC 7686 (https://www.rfc-editor.org/info/rfc7686), "Applications that do not implement the Tor protocol SHOULD generate an error upon the use of .onion and SHOULD NOT perform a DNS lookup." --> To display an .onion site, you have to use the Tor Browser or the Onion Browser on iOS. Currently it still works with Google Chrome, but not with Firefox or Safari.

Q: I don’t have enough size on my SD Card anymore and have to remove the bigest packages, which I don’t need anymore. How can I do that?
A: sudo apt-get install debian-goodies
    dpigs -H (oder dpigs -n 10 -H)

    The last command will give you a list with the biggest installed packages. In a standard Raspbian the biggest installed package by far is usually Wolfram (>600Mb). You can remove it with the following command:
    sudo apt-get remove --purge wolfram-engine
    sudo apt-get autoremove
 
