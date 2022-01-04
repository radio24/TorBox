# TorBox FileSharing
A web-client used to share files over in the TorBox Project.

## Installation
###### Note: Instructions are exclusive for TorBox Project.

### Requirements
**TFS** was coded in Python 3.8 and only depend on 3 libraries:
- Django v3.2.10
- click v8.0.3
- gunicorn v20.1.0

To install dependencies, run

```pip install -r requirements.txt```

## Usage
To allow download and upload to one of your directories, simply run

```./tfs -fp /path/to/shared/dir```

For more options see

```
./tfs --help

Usage: tfs [OPTIONS]

Options:
  -fp, --file-path TEXT          Path to save uploaded files
  -ad, --allow-download BOOLEAN  Allow download from file-path (Default: 1)
  -au, --allow-upload BOOLEAN    Allow upload to file-path (Default: 1)
  -m, --msg TEXT                 Message to show in header of web
  --dev BOOLEAN                  Run in development mode (Default: 0)
  --help                         Show this message and exit.
```

## Considerations
**TFS** is running with Django Framework, so the file-path directory should be set on the
web server to point static and media directories. This will be handled by TorBox Menu.
