import os
import shutil
import mimetypes
import urllib
from pathlib import Path

from flask import jsonify, send_file, abort

ACCESS_FILE = '.access'  # File for reading permissions
DOWNLOADS_PATH = os.environ.get('MEDIA_ROOT')


# Function to check if a directory has the required permissions
def has_permissions(directory_path, permission_required):
    directory_permissions = get_permissions(directory_path)
    if directory_permissions:
        return all(char in directory_permissions for char in permission_required)
    return False


# Function to format file size
def format_size(size):
    if size is None:
        return None

    if isinstance(size, str):
        return size

    for unit in ['B', 'KB', 'MB', 'GB', 'TB']:
        if size < 1024.0:
            break
        size /= 1024.0
    return f"{size:.2f} {unit}"


# Function to get directory size
def get_directory_size(directory_path):
    total_size = 0
    # if directory does not have 'r' permission, return 0
    if not has_permissions(directory_path, 'x'):
        return 0
    for dirpath, dirnames, filenames in os.walk(directory_path):
        for filename in filenames:
            filepath = os.path.join(dirpath, filename)
            total_size += os.path.getsize(filepath)
    return total_size


# Function to get file information
def get_file_info(file_path):
    mime_type, encoding = mimetypes.guess_type(file_path)

    file_size = os.path.getsize(file_path)
    formatted_size = format_size(file_size)

    file_info = {
        'data': {
            'name': os.path.basename(file_path),
            'size': formatted_size,
            'size_bytes': file_size,
            'type': mime_type.split('/')[0] if mime_type else None
        }
    }

    return file_info


# Function to get permissions from .access file
def get_permissions(directory_path):
    access_file_path = os.path.join(DOWNLOADS_PATH, ACCESS_FILE)
    if os.path.exists(access_file_path):
        with open(access_file_path, 'r') as access_file:
            for line in access_file:
                path, permissions = line.strip().split(';')
                if Path(path) == Path(directory_path):
                    return permissions
    return "rx"


# Function to get directory tree recursively without pagination
def get_directory_tree(directory_path):
    dir_contents = []

    items = os.listdir(directory_path)
    folders = [item for item in items if os.path.isdir(os.path.join(directory_path, item))]
    files = [item for item in items if not os.path.isdir(os.path.join(directory_path, item)) and not item.startswith('.access')]

    folders.sort()
    files.sort()

    # List all items
    for item in folders + files:
        item_path = os.path.join(directory_path, item)
        if os.path.isdir(item_path):
            directory_info = {
                'data': {
                    'name': item,
                    'type': 'Folder',
                    'path': os.path.relpath(item_path, DOWNLOADS_PATH),
                    'size': format_size(get_directory_size(item_path)),
                    'size_bytes': get_directory_size(item_path),
                    # 'path': item_path,
                }
            }
            dir_contents.append(directory_info)
        else:
            dir_contents.append(get_file_info(item_path))

    return dir_contents


# Function to list files in a directory
def list_files(request):
    # List files in the specified directory path from the request
    directory_path = request.args.get('path', '')

    if directory_path == '/':
        directory_path = ''

    directory_path = Path(DOWNLOADS_PATH) / Path(directory_path)
    relative_path = os.path.relpath(directory_path, DOWNLOADS_PATH)

    # Check if the directory path is valid and within DOWNLOADS_PATH
    if not os.path.exists(directory_path) or not os.path.isdir(directory_path):
        return jsonify({'error': 'Invalid directory path'}), 400

    # check permissions for directory
    permissions = get_permissions(directory_path)

    # Default permissions for directories not listed in .access
    permissions = 'rx' if permissions is None else permissions

    files = []
    # Check if the specified directory has 'x' permission to list files
    if 'x' in permissions:
        # List all files in the specified directory
        files = get_directory_tree(directory_path)

    # Count all files and folders in the current directory
    total_file_count = sum(1 for _ in os.listdir(directory_path) if
                           not _.startswith('.') and os.path.normpath(
                               _) != _.startswith('.access'))

    if directory_path == Path(DOWNLOADS_PATH):
        parent_path = os.path.relpath(DOWNLOADS_PATH, DOWNLOADS_PATH)
    else:
        parent_path = os.path.relpath(directory_path.parent, DOWNLOADS_PATH)

    if parent_path == '.':
        parent_path = '/'

    response = {
        'current': {
            'path': '/' if relative_path == '.' else relative_path,
            'parent_path': parent_path,
            'permissions': permissions,
            'size': format_size(get_directory_size(directory_path)),
            'size_bytes': get_directory_size(directory_path),
            'total_file_count': total_file_count
        },
        'tree': files,
    }

    return jsonify(response)


# Function to download a folder as a zip file
def download_dir(request):
    folder_path = request.args.get('path', '')
    # urldecode folder_path
    folder_path = urllib.parse.unquote(folder_path)
    # clean for double /
    folder_path = folder_path.replace('//', '/')
    # Folder path is relative to DOWNLOADS_PATH. Get full path
    folder_path = os.path.join(DOWNLOADS_PATH, folder_path)

    check = request.args.get('check', '')
    if check:
        # Check if there is enough space to create the zip file
        disk_info = shutil.disk_usage(DOWNLOADS_PATH)
        folder_size = get_directory_size(folder_path)
        if folder_size > disk_info.free:
            abort(400, {'error': 'Insufficient space to create the zip file'})
        else:
            return jsonify({'message': 'Enough space to create the zip file'})

    # Protect against directory traversal
    if '..' in os.path.relpath(folder_path, DOWNLOADS_PATH):
        abort(400, {'error': 'Invalid folder specified'})

    # Check if the specified folder exists
    if not os.path.exists(folder_path) or not os.path.isdir(folder_path):
        abort(400, {'error': 'Invalid folder specified'})

    # Check if the specified folder has 'r' permission
    if not has_permissions(folder_path, 'r'):
        abort(400,
              {'error': 'Insufficient permissions to download this folder'})

    # Check if there is enough space to create the zip file
    disk_info = shutil.disk_usage(DOWNLOADS_PATH)
    folder_size = get_directory_size(folder_path)
    if folder_size > disk_info.free:
        abort(400, {'error': 'Insufficient space to create the zip file'})

    # Get the name of the directory inside the folder_path
    folder_name = os.path.basename(folder_path)

    # If folder name is empty, then it's the root directory
    if folder_name == '':
        folder_name = 'root'

    # Create in the /tmp directory a zip file of the specified folder
    shutil.make_archive('/tmp/' + folder_name, 'zip', folder_path)

    # Return the zip file as a response to the client
    return send_file(f'/tmp/{folder_name}.zip', as_attachment=True)
