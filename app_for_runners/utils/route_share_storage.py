import os
import uuid

from flask import current_app
from werkzeug.utils import secure_filename


def _allowed_extension(filename):
    if '.' not in filename:
        return False
    ext = filename.rsplit('.', 1)[1].lower()
    return ext in current_app.config['ALLOWED_ROUTE_SHARE_EXTENSIONS']


def save_chat_route_file(file_storage):
    if not file_storage or not file_storage.filename:
        raise ValueError('GPX file is required')

    original_name = secure_filename(file_storage.filename)
    if not original_name:
        raise ValueError('Invalid file name')
    if not _allowed_extension(original_name):
        raise ValueError('Only GPX files are supported')

    file_storage.seek(0, os.SEEK_END)
    size = file_storage.tell()
    file_storage.seek(0)
    if size > current_app.config['MAX_ROUTE_SHARE_SIZE']:
        raise ValueError('File is too large')
    if size == 0:
        raise ValueError('File is empty')

    folder = current_app.config['ROUTE_SHARE_UPLOAD_FOLDER']
    os.makedirs(folder, exist_ok=True)

    stored_filename = f'{uuid.uuid4().hex}.gpx'
    file_storage.save(os.path.join(folder, stored_filename))

    return original_name, stored_filename, size


def route_share_file_path(stored_filename):
    if not stored_filename:
        return None
    return os.path.join(
        current_app.config['ROUTE_SHARE_UPLOAD_FOLDER'],
        stored_filename,
    )


def delete_route_share_file(stored_filename):
    path = route_share_file_path(stored_filename)
    if path and os.path.isfile(path):
        os.remove(path)
