# TorBox ChatSecure

Encrypted web chat room to communicate in group or one-to-one. Similar to text
apps, it includes end-to-end encryption on all messages, using auto-generated
keys on the client side.


# Run

## Production

*For this example, SERVICE is the name of the service*

### Start TCS

For running in productive mode, use the `tcs` command.

Example:
```
./tcs -n SERVICE -od hash.onion
```

The following files will be created

- Pid file in `./pid/SERVICE.pid`,
- Database in `./db/SERVICE.db`
- Unix socket in `/var/run/tcs_SERVICE.sock`

### Stop TCS
To stop TCS, kill the pid using the pid file. This will do a graceful shutdown and delete the created files.

Example:
```kill  `cat ./pid/SERVICE.pid` ```

or

```pkill -F ./pid/SERVICE.pid```


#### For more info run
```
./tcs --help

Usage: tcs [OPTIONS]

Options:
  -n, --name TEXT           Onion Service Name
  -od, --onion-domain TEXT  Onion domain where TCS will be published
  --dev BOOLEAN             Run in development mode (Default: 0)
  --debug BOOLEAN           Run in debug mode (--dev must be true) (Default:
                            0)
  --help                    Show this message and exit.
```


## Development

### ReactJS

webclient directory contains react application

```bash
cd webclient
yarn
yarn run dev
```

### Docker backend
Run the python backend in docker in port 5000. Access from browser to this port will show the latest build of the
frontend

```bash
docker-compose up
```

### Python backend
chatsecure backend run in flask + socketio

```bash
pip install -r requirements.txt
python main.py
```

---

### Library dependency

*Just for reference*

`$ sudo apt install python3-pgpy`


