#!/usr/bin/python3

# This file is part of TorBox, an easy to use anonymizing router based on Raspberry Pi.
# Copyright (C) 2022 Patrick Truffer
# Contact: anonym@torbox.ch
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it is useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>.
#
# DESCRIPTION
# This file fetches THREE new bridges. The return values are:
# obfs4 <IP address>:<Port> <Fingerprint> <Certificate> <iat-mode>
# or -1 if fetching the bridge fails over tor and clearnet.
#
# IMPORTANT
# The bridge database delivers only 1-3 bridges approximately every 24 hours,
# of which we pick one. With the bridges already delivered this should be sufficient.
#
# SYNTAX
# ./bridges_get.py [-n, --network=<tor|inet>] [-h, --help]
#
# -h, --help: print the help screen
# -n, --network=<tor|inet>: force check over specific network

import click
import base64
import requests
import numpy as np
import cv2 as cv
from pytesseract import image_to_string


def get_proxy(network=''):
    # Tor Socks Proxy
    proxy = {
        "http": "socks5://127.0.0.1:9050",
        "https": "socks5://127.0.0.1:9050",
    }

    if not network:
        # Check if Tor proxy is up, otherwise set inet network
        try:
            r = requests.get("https://torproject.org", proxies=proxy, timeout=5)
        except:  # noqa
            network = 'inet'

    if network == "inet":
        proxy = {
            "http": "",
            "https": "",
        }
    return proxy


def get_challenge(proxy):
    moat_fetch = "https://bridges.torproject.org/moat/fetch"
    headers = {"Content-type": "application/vnd.api+json"}
    data = {
        "data": [{
            "version": "0.1.0",
            "type": "client-transports",
            "supported": ["obfs4"],
        }]
    }

    try:
        r = requests.post(moat_fetch, json=data, proxies=proxy, headers=headers)
        r = r.json()
        r = r["data"][0]
    except:
        print(-1)
        quit()
    return r["image"], r["challenge"], r["transport"]


def readb64(encoded_data):
   nparr = np.frombuffer(base64.b64decode(encoded_data), np.uint8)
   img = cv.imdecode(nparr, cv.IMREAD_COLOR)
   return img


def beat_captcha(image):
    img = readb64(image)
    ret, img = cv.threshold(img, 100, 255, cv.THRESH_BINARY)

    kernel = np.ones((5, 5), np.uint8)
    img = cv.morphologyEx(img, cv.MORPH_OPEN, kernel)

    # Read chars from img
    captcha_text = image_to_string(img,
                                   config='-c tessedit_char_whitelist=' \
                                          '0123456789' \
                                          'ABCDEFGHIJKMNLOPKRSTUVWXYZ' \
                                          'abcdefghijklmnopqrstuvwxyz')
    captcha_text = captcha_text.strip()
    return captcha_text


def solve_challenge(captcha_text, challenge, transport, proxy):
    moat_check = "https://bridges.torproject.org/moat/check"
    headers = {"Content-type": "application/vnd.api+json"}
    data = {
        "data": [{
            "id": "2",
            "type": "moat-solution",
            "version": "0.1.0",
            "transport": transport,
            "challenge": challenge,
            "solution": captcha_text,
            "qrcode": "false",
        }]
    }
    r = requests.post(moat_check, json=data, proxies=proxy, headers=headers)
    r = r.json()
    if r.get('errors'):
        return False
    return r["data"][0]["bridges"]


def get_bridges(network):
    proxy = get_proxy(network)
    bridges = False
    while not bridges:
        captcha_img, challenge, transport = get_challenge(proxy)
        captcha_text = beat_captcha(captcha_img)
        bridges = solve_challenge(captcha_text, challenge, transport, proxy)

    return bridges


@click.command()
@click.option('--network', '-n', default='', type=str, help="Force to get bridges over specific network.      Example: -n <tor|inet>")
def main(network):
    bridges = get_bridges(network)
    print("\n".join(bridges))


if __name__ == '__main__':
    main()
