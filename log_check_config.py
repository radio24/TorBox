#!/usr/bin/python3
# -*- coding: utf-8 -*-

# This file is part of TorBox, an easy to use anonymizing router based on Raspberry Pi.
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

config = {
    "check_interval": 1,  # (seconds) wait before checking for matches again
}

matches = [
    {
        "file": '/var/log/tor/notices.log',
        "match": "*Most likely this means the Tor network is overloaded*",  # use * as wildcard
        "match_count": 1,  # min matches to execute command
        "match_time": 60*60,  # (seconds) time range of match count to execute cmd
        "command": 'sudo bash /home/torbox/torbox/automat 1',
    },
    {
        "file": '/var/log/tor/notices.log',
        "match": "*This could indicate a route manipulation attack, network overload, bad local network connectivity, or a bug.*",  # use * as wildcard
        "match_count": 1,  # min matches to execute command
        "match_time": 60*60,  # (seconds) time range of match count to execute cmd
        "command": 'sudo bash /home/torbox/torbox/automat 1',
    },
    {
        "file": '/var/log/tor/notices.log',
        "match": "*Tor has not observed any network activity for the past*",  # use * as wildcard
        "match_count": 1,  # min matches to execute command
        "match_time": 60*60,  # (seconds) time range of match count to execute cmd
        "command": 'sudo bash /home/torbox/torbox/automat 2',
    },
    {
        "file": '/var/log/tor/notices.log',
        "match": "*We tried for * seconds to connect to * using exit *",  # use * as wildcard
        "match_count": 25,  # min matches to execute command
        "match_time": 2*60,  # (seconds) time range of match count to execute cmd
        "command": 'sudo bash /home/torbox/torbox/automat 3',
    },
    {
        "file": '/var/log/tor/notices.log',
        "match": "*Tried for * seconds to get a connection to * Giving up*",  # use * as wildcard
        "match_count": 40,  # min matches to execute command
        "match_time": 2*60,  # (seconds) time range of match count to execute cmd
        "command": 'sudo bash /home/torbox/torbox/automat 3',
    },
    {
        "file": '/var/log/tor/notices.log',
        "match": "*connections have failed*",  # use * as wildcard
        "match_count": 25,  # min matches to execute command
        "match_time": 2*60,  # (seconds) time range of match count to execute cmd
        "command": 'sudo bash /home/torbox/torbox/automat 2 1',
    },
    {
        "file": '/var/log/tor/notices.log',
        "match": "*Tor needs an accurate clock to work correctly*",  # use * as wildcard
        "match_count": 1,  # min matches to execute command
        "match_time": 60*60,  # (seconds) time range of match count to execute cmd
        "command": 'sudo bash /home/torbox/torbox/automat 4',
    },
]
