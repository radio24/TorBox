#!/bin/env bash

INTERVAL=60 # Seconds, Interval between two connection check of internet
DOUBLE_CHECK_WAIT=10    # Seconds, wait time for double check when the connection is down
PING_TIMEOUT=9  # Seconds, Timeout of ping command          
NETWORK_CHECK_TIMEOUT=150   # Count, Check network for ($NETWORK_TIMEOUT x 2 Seconds)