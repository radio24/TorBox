# TorBox FileSharing
A web-client used to share files in the TorBox Project.

## Installation
###### Note: Instructions are exclusive for TorBox Project.

### Requirements
**TFS** was developed using Python 3.9, so it is recommended to use this version or higher.

Dependencies:
- Flask
- Flask_compress
- Flask_CORS
- click

To install dependencies, run

```sudo pip install -r requirements.txt```

## Usage
To allow download and upload to one of your directories, simply run

```./tfs -fp /path/to/shared/dir```

For more options see

```
Usage: tfs [OPTIONS]

Options:
  -n, --name TEXT           Onion Service Name
  -od, --onion-domain TEXT  Onion domain where TFS will be published
  -fp, --file-path TEXT     Path to share
  --dev BOOLEAN             Run in development mode (Default: 0)
  --help                    Show this message and exit.

```

### Manage permissions

Permissions are managed by a file inside the shared directory called `.access`
which must contain a list of subdirectories of the shared directory and their
permissions, separated by a semicolon, in the following format:

```
/path/to/directory;rw
/path/to/another/directory;r
```

Where:

- `r` stands for read-only (can download files)
- `w` stands for write (can upload files)
- `x` stands for excecute (can list files)
- `rw` stands for read and write (can upload and download files)
- `rx` stands for read and execute (can list and download files)

By default, all directories are set to `rx` permissions.

Permissions will make the directory appear in the web-client, and will allow
users to download and upload files to it.

## Development

To run TFS in development mode, simply run

```./tfs -n test -od test -fp /path/to/directory --dev 1```
