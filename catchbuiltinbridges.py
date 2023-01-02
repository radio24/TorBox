#!/usr/bin/python3
#
# This file is part of TorBox, an easy to use anonymizing router based on Raspberry Pi.
# Copyright (C) 2023 Patrick Truffer
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
# ./catchbuiltinbridges.py
#

import requests

# fetch the content from the URL
response = requests.get("https://bridges.torproject.org/moat/circumvention/builtin")

# extract the information in the square brackets from the content
information = []
start_index = 0

# start_index returns the position of the first occurence until not found (-1)
while True:
  start_index = response.text.find("[", start_index)
  if start_index == -1:
    break
  end_index = response.text.find("]", start_index)
# extract the text out of the brackets and creates a list
  information.append(response.text[start_index:end_index + 1])
  start_index = end_index + 1

# split the lines with commas into separate lines
lines = []
for info in information:
  parts = info.split("[")[1].split("]")[0]
  for part in parts.split("\",\""):
    lines.append(part)

# remove the quotation marks at the beginning and end of each line
lines = [line.strip('"') for line in lines]

# sort the lines
lines.sort()

# print the lines
for line in lines:
  print(line)
