# TorBox WebSSH
A web-client SSH for accessing TorBox Menu from browser

## Installation
###### Note: Instructions are exclusive for TorBox Project.

### Requirements
To install dependencies, run

```pip install -r requirements.txt```

## Usage
TorBox WebSSH will run by default in 192.168.42.1 which is default TorBox wlan's IP address.

```./webssh```

For more options see

```
./webssh --help

Usage: twebssh [OPTIONS]

Options:
  --unix-socket TEXT  Unix socket path
  --wifi BOOLEAN      TorBox inet from wifi Default: 1
  --help                  Show this message and exit.
```

#### NOTE: Default unix socket path is /run/user/$UID/torbox/webssh.sock where $UID is the system user id.