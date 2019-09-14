# TorBox
TorBox is an easy to use, anonymizing router based on Raspberry Pi. TorBox creates a separate WiFi that routes the encrypted network data over the Tor network. The type of client (desktop, laptop, tablet, mobile, etc.) and operating system on the client don’t matter.

For more information visit the [TorBox website](https://www.torbox.ch)<br />
TorBox Image (870 MB) : [v.0.2.4 (08.08.2019)](https://www.torbox.ch/data/torbox-20190808-v024-rpi4.gz)<br />
TorBox Menu only : [v.0.2.4 (08.08.2019)](https://www.torbox.ch/data/torbox024-rpi4-20190808.zip)<br />

### Disclaimer
**Use it at your own risk!**

TorBox is ideal for providing additional protection for the entire data stream up to the Tor network and for overcoming censorship. However, **anonymity is hard to get – solely using Tor doesn’t guarantee it**. Malware, Cookies, Java, Flash, Javascript and more will most certainly compromise your anonymity. Even the people from the [Tor Project themselves state](https://2019.www.torproject.org/about/overview.html.en#stayinganonymous) that “Tor can’t solve all anonymity problems. It focuses only on protecting the transport of data.” Therefore, **it is strongly advised not to use TorBox, if your well-being depends on your anonymity**. In such a situation it is advisable to use [Tails](https://tails.boum.org/) (read [here](https://browserleaks.com/), [here](https://en.wikipedia.org/wiki/Device_fingerprint) and [here](https://panopticlick.eff.org/about#defend-against) why). [Here](https://www.torbox.ch/?page_id=112#05) are additional browser add-ons to improve anonymity, security and/or usability.

### Quick Installation Guide
1. Download the latest TorBox image file.
2. Transfer the downloaded image file on an [SD Card](https://en.wikipedia.org/wiki/Secure_Digital); for example with [Etcher](https://www.balena.io/etcher/). TorBox needs at least a 4 Gbyte SD Card, but 8 Gbyte is recommended.
3. Put the SD Card into your Raspberry Pi, link it with an internet router using an Ethernet cable or place a USB WiFi adapter in one of the USB ports to use an already existing WiFi. Afterward, start the Raspberry Pi. During the start, the system on the SD card automatically expands over the entire free partition – user interaction, screen, and peripherals are not required.
4. After 2-3 minutes, when the green LED stops to flicker, connect your client to the new WiFi “TorBox024” (password: CHANGE-IT). Then use an [SSH-client](https://en.wikipedia.org/wiki/Comparison_of_SSH_clients) to access 192.168.42.1 (username: pi / password: CHANGE-IT). Now, you should see the TorBox menu. Choose the preferred connection setup and **change the default passwords as soon as possible** (the associated entries are placed in the advanced menu).

A Raspberry Pi 3 ([Model B](https://www.raspberrypi.org/products/raspberry-pi-3-model-b/) / [Model B+](https://www.raspberrypi.org/products/raspberry-pi-3-model-b-plus/)) or a [Raspberry Pi 4 Model B](https://www.raspberrypi.org/products/raspberry-pi-4-model-b/) is recommended.

Do you have additional questions? Check out our [FAQ on the TorBox website](https://www.torbox.ch/?page_id=112).

### Features
* TorBox routes all your network data through the Tor network.
* With the SSH-accessible menu, TorBox provides you with a user-friendly interface.
* TorBox supports internet access and client connections via WiFi (an additional USB WiFi adapter is necessary) or cable, which can easily be changed via the provided interface.
* It easily overcomes captive portals and offers, if necessary, measures against “disconnect when idle features” (sometimes seen with WiFis in airports, hotels, coffee houses).
* TorBox supports [OBFS4](https://2019.www.torproject.org/docs/pluggable-transports.html) bridges, which help to overcome censorship ([with an easy to use interface](https://www.torbox.ch/?page_id=112#censorship)).
* It provides [SOCKS v5 proxy functionality](https://en.wikipedia.org/wiki/SOCKS).
* It allows easy access to .onion websites without client configuration (Chrome) or via SOCKS v5 proxy (Firefox).

### Building From Scratch
All that you need to run TorBox on your Raspberry Pi is the image file. However, if you like to build it from scratch on your own, whether you like to implement it to an existing system, to another hardware, respectively another operating system or you don’t trust an image file, which you didn’t bundle of your own. Then [check out our detailed manual](https://www.torbox.ch/?page_id=205). It helps you to build a TorBox from scratch.

### I want to help...
GREAT! There is a  lot to improve and to fix (security of the entire system, graphical menu, cool logos ...). We are searching for people, who want to help and we need especially your feedback to improve the system. 
You can also make [a donation to the Tor Project](https://donate.torproject.org) -- without them TorBox would not exist.

### Contact
[TorBox website](https://www.torbox.ch)
[TorBox email](mailto:anonym@torbox.ch)
