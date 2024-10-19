import os
import urllib
import shutil
from pathlib import Path

from flask import (
    Flask, jsonify, request, send_from_directory, abort, send_file
)
from flask_compress import Compress
from flask_cors import CORS

from utils.files import list_files, format_size, has_permissions, download_dir

# Get environment variables
ONION_DOMAIN = os.environ.get('ONION_DOMAIN')
DOWNLOADS_PATH = os.environ.get('MEDIA_ROOT')

BASE_DIR = Path(os.path.dirname(os.path.abspath(__file__)))
app = Flask(
    __name__,
    static_url_path='/assets',
    static_folder=BASE_DIR / "webclient/dist/assets"
)
CORS(app, origins=ONION_DOMAIN)
Compress(app)


# Endpoint to get the directory tree with pagination
@app.route('/get_tree', methods=['GET'])
def get_tree():
    return list_files(request)


# Endpoint to get disk information
@app.route('/get_disk_info', methods=['GET'])
def get_disk_info():
    disk_info = shutil.disk_usage(DOWNLOADS_PATH)

    formatted_disk_info = {
        'used': {
            'value': disk_info.used,
            'text': format_size(disk_info.used),
        },
        'available': {
            'value': disk_info.free,
            'text': format_size(disk_info.free),
        },
        'total': {
            'value': disk_info.total,
            'text': format_size(disk_info.total),
        },
    }

    return jsonify(formatted_disk_info)


# Endpoint to upload files
@app.route('/upload_files', methods=['POST'])
def upload_files():
    # Get upload path from get parameters
    upload_path = request.args.get('path', '')

    # upload_path must not contain '..' to avoid directory traversal
    if '..' in upload_path:
        abort(400, {'error': 'Invalid directory specified'})

    # uplod_path must be a subdirectory of DOWNLOADS_PATH
    upload_path = os.path.join(DOWNLOADS_PATH, upload_path)

    # Check if the specified directory exists
    if not os.path.exists(upload_path) or not os.path.isdir(upload_path):
        abort(400, {'error': 'Invalid directory specified'})

    # Check if the specified directory has 'w' permission
    if not has_permissions(upload_path, 'w'):
        abort(400, {'error': 'Insufficient permissions to upload to this directory'})

    files = request.files.getlist('files[]')

    if not files:
        return jsonify({'error': 'No files selected'})

    success_messages = []
    error_messages = []

    for file in files:
        if file.filename == '':
            error_messages.append('No selected file')
        else:
            # Check if another file with the same name exists, change the name if necessary
            file_path = os.path.join(upload_path, file.filename)
            if os.path.exists(file_path):
                file_name, file_extension = os.path.splitext(file.filename)
                counter = 1
                while os.path.exists(file_path):
                    file_path = os.path.join(upload_path, f'{file_name} ({counter}){file_extension}')
                    counter += 1

            file.save(file_path)
            # file.save(os.path.join(upload_path, file.filename))
            success_messages.append(f'File "{file.filename}" uploaded successfully')

    response = {'success_messages': success_messages, 'error_messages': error_messages}
    return jsonify(response)


# Endpoint to download a file
@app.route('/download', methods=['GET'])
def download():
    file_path = request.args.get('path', '')
    # urldecode file_path
    file_path = urllib.parse.unquote(file_path)
    # clean for double /
    file_path = file_path.replace('//', '/')

    # File path is relative to DOWNLOADS_PATH. Get full path
    file_path = os.path.join(DOWNLOADS_PATH, file_path)

    # Protect against directory traversal.
    if '..' in os.path.relpath(file_path, DOWNLOADS_PATH):
        abort(400, {'error': 'Invalid file specified'})

    # Check if the specified file exists
    if not os.path.exists(file_path) or not os.path.isfile(file_path):
        abort(400, {'error': 'Invalid file specified'})

    # Check if the parent directory has 'r' permission
    if not has_permissions(os.path.dirname(file_path), 'r'):
        abort(400, {'error': 'Insufficient permissions to download this file'})

    return send_file(file_path, as_attachment=True)


# Endpoint to download a folder as a zip file
@app.route('/download_folder', methods=['GET'])
def download_folder():
    return download_dir(request)


# webclient index.html located in webclient/dist
@app.route('/')
def index():
    return send_from_directory(BASE_DIR / "webclient/dist", 'index.html')


def main():
    app.run(debug=True)


if __name__ == '__main__':
    main()
