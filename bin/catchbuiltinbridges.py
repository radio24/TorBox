#!/usr/bin/python3
#
# This file is part of TorBox, an easy to use anonymizing router based on Raspberry Pi.
# Copyright (C) 2024 radio24
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
# This will fetch the builtin bridges and display it alphabetically sorted.
#
# SYNTAX
# ./catchbuiltinbridges.py [-n, --network=<tor|inet>] [--help]
#
# -n, --network=<tor|inet>: force check over specific network
# --help              Show this message and exit.
#
# ERROR CODES:
# -1: Network error

import click
import requests

# Try to get the builtin bridges through tor
def get_proxy(network=''):
    # Tor Socks Proxy
    proxy = {
        "http": "socks5h://127.0.0.1:9050",
        "https": "socks5h://127.0.0.1:9050",
    }

    if not network:
        # Check if Tor proxy is up, otherwise set inet network
        try:
            response = requests.get("https://bridges.torproject.org/moat/circumvention/builtin", proxies=proxy, timeout=5)
        except:  # noqa
            network = 'inet'

    if network == "inet":
        proxy = {
            "http": "",
            "https": "",
        }
    return proxy

# fmt: off
@click.command()
@click.option('--network', '-n', default='', type=str, help="Force to get bridges over specific network. Example: -n <tor|inet>")
# fmt: on

# Fetch the content from the URL
def fetch_bridges(network):
    proxy = get_proxy(network)

    try:
        response = requests.get("https://bridges.torproject.org/moat/circumvention/builtin", proxies=proxy)
    except:
        print(-1)
        quit()

    # Extract the information in the square brackets from the content
    information = []
    start_index = 0

    # start_index returns the position of the first occurence until not found (-1)
    while True:
        start_index = response.text.find("[", start_index)
        if start_index == -1:
            break
        end_index = response.text.find("]", start_index)
        # Extract the text out of the brackets and creates a list
        information.append(response.text[start_index:end_index + 1])
        start_index = end_index + 1

        # split the lines with commas into separate lines
        lines = []
        for info in information:
            parts = info.split("[")[1].split("]")[0]
            for part in parts.split("\",\""):
                lines.append(part)

        # Remove the quotation marks at the beginning and end of each line
        lines = [line.strip('"') for line in lines]

        # sort the lines
        lines.sort()

        # print the lines
        for line in lines:
            print(line)

if __name__ == '__main__':
    fetch_bridges()
