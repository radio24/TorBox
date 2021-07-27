#!/bin/bash

# This file is a part of TorBox, an easy to use anonymizing router based on Raspberry Pi.
# Copyright (C) 2021 Patrick Truffer
# Contact: anonym@torbox.ch
# Website: https://www.torbox.ch
# Github:  https://github.com/radio24/TorBox
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
# This script prepares the freshly installed TorBox for the building of an image
#
# SYNTAX
# ./rprepare_image
#
clear
echo -e "${WHITE}[!] CHECK INSTALLED VERSIONS${NOCOLOR}"
echo
echo "Hostname           :"
echo "Kernel version     :"
echo "Tor version        :"
echo "Nyx version        :"
echo "Go version         :"
echo "Installed time zone:"
