# TorBox WebSSH
A web-client SSH for accessing TorBox Menu from browser

## Installation
###### Note: Instructions are exclusive for TorBox Project.

### Requirements
To install dependencies, run

```sudo pip install -r requirements.txt```

## Usage
TorBox WebSSH by default will:
- listen on all interfaces.
- listen on 80 port
- listen on 443 port if certfile and keyfile is passed

```sudo ./twebssh```

For more options see

```
./twebssh --help
Usage: twebssh [OPTIONS]

Options:
  --unix-socket TEXT  Unix socket path
  --port INTEGER      HTTP listen port. Default: 80
  --sslport INTEGER   HTTPS listen port. Default: 443
  --certfile TEXT     Path to crt file to enable HTTPS
  --keyfile TEXT      Path to key file to enable HTTPS
  --help              Show this message and exit.

```

#### NOTE: Default unix socket path is /run/user/$UID/torbox/webssh.sock where $UID is the system user id.
