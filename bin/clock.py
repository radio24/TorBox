#!/usr/bin/python3

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
# This Python script displays the current time in big letters.
#
# SYNTAX
# ./clock
#

import os
from time import ctime

def asciiClock(hour):
    num = ["   ___   @  / _ \  @ | | | | @ | | | | @ | |_| | @  \___/  @","  __  @ /_ | @  | | @  | | @  | | @  |_| @",
   "  ___   @ |__ \  @    ) | @   / /  @  / /_  @ |____| @","  ____   @ |___ \  @   __) | @  |__ <  @  ___) | @ |____/  @",
   "  _  _    @ | || |   @ | || |_  @ |__   _| @    | |   @    |_|   @","  _____  @ | ____| @ | |__   @ |___ \  @  ___) | @ |____/  @",
   "    __   @   / /   @  / /_   @ |  _ \  @ | (_) | @  \___/  @","  ______  @ |____  | @     / /  @    / /   @   / /    @  /_/     @",
   "   ___   @  / _ \  @ | (_) | @  > _ <  @ | (_) | @  \___/  @","   ___   @  / _ \  @ | (_) | @  \__, | @    / /  @   /_/   @",
   "   @ _ @(_)@ _ @(_)@   @","            @            @ __ _ _ __ @/ _` | '  \@\__,_|_|_|_|@            @",
   "            @            @ _ __ _ __ @| '_ \ '  \@| .__/_|_|_|@|_|@"]
    clock = ""
    for i in range(6):
        # Spacer befor the clock
        clock += "    "
        for j in range(2):
            x = int(hour[j])
            d = x // 10
            u = x % 10
            if d > 0 or j > 0:
                clock += num[d].split("@")[i]
            clock += num[u].split("@")[i]
            if j == 0:
                clock += " " + num[10].split("@")[i] + " "
        clock += "\n"
    return clock

previousMinute = -1
hour = ctime().split()[3].split(":")
h = int(hour[0])
m = hour[1]
if previousMinute != m:
    #os.system("clear") # if using Windows change to "cls"
    print(asciiClock([h, m]))
previousMinute = m
