import os
import uuid

from flask import current_app
from werkzeug.utils import secure_filename


def _allowed_extension(filename):
    if '.' not in filename:
        return False
    ext = filename.rsplit('.', 1)[1].lower()
    return ext in current_app.config['ALLOWED_WORKOUT_PHOTO_EXTENSIONS']


def save_route_share_photo(file_storage):
    if not file_storage or not file_storage.filename:
        raise ValueError('Photo file is required')

    original_name = secure_filename(file_storage.filename)
    if not _allowed_extension(original_name):
        raise ValueError('Unsupported image format')

    file_storage.seek(0, os.SEEK_END)
    size = file_storage.tell()
    file_storage.seek(0)
    if size > current_app.config['MAX_WORKOUT_PHOTO_SIZE']:
        raise ValueError('Image is too large')

    ext = original_name.rsplit('.', 1)[1].lower()
    folder = current_app.config['ROUTE_SHARE_PHOTO_FOLDER']
    os.makedirs(folder, exist_ok=True)

    stored_filename = f'{uuid.uuid4().hex}.{ext}'
    file_storage.save(os.path.join(folder, stored_filename))
    return stored_filename


def route_share_photo_path(stored_filename):
    if not stored_filename:
        return None
    return os.path.join(
        current_app.config['ROUTE_SHARE_PHOTO_FOLDER'],
        stored_filename,
    )


def delete_route_share_photo(stored_filename):
    path = route_share_photo_path(stored_filename)
    if path and os.path.isfile(path):
        os.remove(path)
