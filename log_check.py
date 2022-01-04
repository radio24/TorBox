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
#
#
# DESCRIPTION
# This script checks /var/log/tor/notices.log for error messages and executes
# the sccript automat to automatically restor the tor functionality.
# The script is configured by log_check_config.py
#
# SYNTAX
# sudo ./log_check.py &

import os
import time
import subprocess
import re

from datetime import datetime
from log_check_config import config, matches

for match in matches:
    match['last_update'] = datetime.now().timestamp()
    match['count'] = []

while True:
    for m in matches:
        file = m['file']
        match = re.escape(m['match'])
        match_count = m['match_count']
        match_time = m['match_time']
        match_cmd = m['command']

        c = ["tail", "-n", "100", file]
        output = subprocess.check_output(c).decode('utf-8')

        for line in output.split("\n"):
            if not line:
                continue

            # only process lines with right format
            try:
                dts = line[:15]  # :15 length of date in linux logs
                dts = f"{datetime.now().year} {dts}"
                d = datetime.strptime(dts, '%Y %b %d %H:%M:%S')
                line_ts = d.timestamp()
            except:
                continue

            if m['last_update'] < line_ts:
                m['last_update'] = line_ts
                match_re = match.replace('\*', '(.*)')

                if re.search(match_re, line):
                    match_info = {
                            "ts": line_ts,
                            "line": line
                        }
                    m['count'].append(match_info)

                    if len(m['count']) >= m['match_count']:
                        # Check if we are in time
                        ts_ini = m['count'][0]['ts']
                        ts_end = m['count'][match_count-1]['ts']
                        ts_diff = ts_end - ts_ini

                        if ts_diff <= match_time:
                            # We're in time, execute command
                            os.system(match_cmd)
                            m['count'] = []
                        else:
                            # We are outside of time, reset and count current
                            m['count'] = []
                            m['count'].append(match_info)



    time.sleep(config['check_interval'])
