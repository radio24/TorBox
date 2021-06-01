#!/usr/bin/python3
# -*- coding: utf-8 -*-

# This file is part of TorBox, an easy to use anonymizing router based on Raspberry Pi.
# Copyright (C) 2021 Patrick Truffer
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
    "check_interval": 1,  # seconds to wait before checking for messages again
}

matches = [
    {
        "file": '/var/log/tor/notices.log',
        "match": "Have tried resolving or connecting to address '[scrubbed]' at * different places. Giving up",  # user * as wildcard
        "match_count": 3,  # min matches to execute command
        "match_time": 60*60,  # (seconds)
        "command": 'cat /etc/passwd > /tmp/executed.out',
    },
    #{
    #    "file": '/var/log/tor/notices.log',
    #    "match": "Have tried resolving or connecting to address '[scrubbed]' at * different places. Giving up",  # user * as wildcard
    #    "match_count": 3,  # min matches to execute command
    #    "match_time": 60*60,  # (seconds)
    #    "command": 'cat /etc/passwd > /tmp/executed.out',
    #},
]
