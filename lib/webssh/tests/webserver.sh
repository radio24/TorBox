#!/bin/sh

# For development purposes:
#
# Use this script for testing the production mode which use unix socket
# example: ./lib/chatsecure/tcs -n SERVICE -od localhost -m SERVICE_TEST

echo "[+] Listening port: 80 | unix-socket: /tmp/webssh.sock ..."
socat TCP-LISTEN:80,fork,reuseaddr UNIX-CONNECT:/tmp/webssh.sock
