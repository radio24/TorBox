#!/bin/bash

set +e

CURRENT_HOSTNAME=`cat /etc/hostname | tr -d " \t\n\r"`
if [ -f /usr/lib/raspberrypi-sys-mods/imager_custom ]; then
   /usr/lib/raspberrypi-sys-mods/imager_custom set_hostname torbox
else
   echo torbox >/etc/hostname
   sed -i "s/127.0.1.1.*$CURRENT_HOSTNAME/127.0.1.1\ttorbox/g" /etc/hosts
fi
FIRSTUSER=`getent passwd 1000 | cut -d: -f1`
FIRSTUSERHOME=`getent passwd 1000 | cut -d: -f6`
if [ -f /usr/lib/raspberrypi-sys-mods/imager_custom ]; then
   /usr/lib/raspberrypi-sys-mods/imager_custom enable_ssh
else
   systemctl enable ssh
fi
if [ -f /usr/lib/userconf-pi/userconf ]; then
   /usr/lib/userconf-pi/userconf 'torbox' '$5$SnGd5XLYja$v7e8vDzDefhqXEzWfe41sshwmWLvpzEnustg5gSdR51'
else
   echo "$FIRSTUSER:"'$5$SnGd5XLYja$v7e8vDzDefhqXEzWfe41sshwmWLvpzEnustg5gSdR51' | chpasswd -e
   if [ "$FIRSTUSER" != "torbox" ]; then
      usermod -l "torbox" "$FIRSTUSER"
      usermod -m -d "/home/torbox" "torbox"
      groupmod -n "torbox" "$FIRSTUSER"
      if grep -q "^autologin-user=" /etc/lightdm/lightdm.conf ; then
         sed /etc/lightdm/lightdm.conf -i -e "s/^autologin-user=.*/autologin-user=torbox/"
      fi
      if [ -f /etc/systemd/system/getty@tty1.service.d/autologin.conf ]; then
         sed /etc/systemd/system/getty@tty1.service.d/autologin.conf -i -e "s/$FIRSTUSER/torbox/"
      fi
      if [ -f /etc/sudoers.d/010_pi-nopasswd ]; then
         sed -i "s/^$FIRSTUSER /torbox /" /etc/sudoers.d/010_pi-nopasswd
      fi
   fi
fi
cat >/etc/network/interfaces.d/usb0 <<'GADGET'
auto usb0
allow-hotplug usb0
iface usb0 inet static
address 192.168.44.1
netmask 255.255.255.0

GADGET
rm -f /boot/firstrun.sh
sed -i 's| systemd.run.*||g' /boot/cmdline.txt
exit 0
