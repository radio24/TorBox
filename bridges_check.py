#!/usr/bin/python3

import sys
import getopt
import requests
import json

from binascii import a2b_hex
from hashlib import sha1

# get the options from cmd line
options, remainder = getopt.getopt(sys.argv[1:], 'f:ish', ['fingerprint=', 
                                                        'info=',
                                                        'help',
                                                        'hashed-fingerprint'
                                                        ])
fingerprint = False
hashed_fingerprint = False
get_info_file = False
show_info = False

for opt, arg in options:
    if opt in ('-f', '--fingerprint'):
        fingerprint = arg
    elif opt in ('-i', '--info'):
        if arg == '':
            show_info = True
        get_info_file = arg
    elif opt in ('-s', '--hashed-fingerprint'):
        hashed_fingerprint = True
    elif opt in ('-h', '--help'):
        print("Usage:\n %s [-i] -f <fingerprint>\n\nOptions:\n -f, --fingerprint=<fingerprint>\tGet status of a tor bridge (0: online, 1: offline, 2: not exists) [REQUIRED PARAM]\n\t\t\t\t\t Fingerprint must not be hashed\n -s, --hashed-fingerprint\t\tSearch for hashed fingerprint\n -i, --info <file_name>\t\t\tSave the info from bridge and save to file in JSON format (-i prints to stdout)\n -h, --help\t\t\t\tshow this help\n" % sys.argv[0])
        quit()

# if fingerprint not passed, we show how to use it. fingerprint is required
if not fingerprint:
    print("Usage: %s -f <fingerprint>\nCheck '%s --help' for more info" % (sys.argv[0], sys.argv[0]) )
    quit()

# if fingerprint is not hashed, we hash it before search
if not hashed_fingerprint:
    try:
        fingerprint = sha1(a2b_hex(fingerprint)).hexdigest()
    except:
        print("[X] Fingerprint format error")
        quit()

# search for the fingerprint in the torproject
url = 'https://onionoo.torproject.org/details?lookup=%s' % fingerprint
r = requests.get(url)

# load json data
data = json.loads(r.text)

# if we get bridges, then it exist
if len(data['bridges']):
    b = data['bridges'][0]

    # get the info of existing one to file
    if get_info_file:
        f = open(get_info_file, 'w')
        f.write("{}".format(b))
        f.close()

    # Running
    if b['running']:
        res = 1 # ONLINE
    # Not running
    else:
        res = 0 # OFFLINE
    
    if show_info:
        print("%s:{}".format(b) % (res))
    else:
        print(res)

# else it doesn't exist
else:
    print(2) # NOT EXIST
