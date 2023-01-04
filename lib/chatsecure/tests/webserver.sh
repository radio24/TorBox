#!/bin/sh

# For devlopment purposes:
#
# Use this script for testing the production mode which use unix socket
# example: ./lib/chatsecure/tcs -n SERVICE -od localhost -m SERVICE_TEST

echo "[+] Listening port: 80 | unix-socket: /tmp/tcs_SERVICE.sock ..."
socat TCP-LISTEN:80,fork,reuseaddr UNIX-CONNECT:/tmp/tcs_SERVICE.sock
