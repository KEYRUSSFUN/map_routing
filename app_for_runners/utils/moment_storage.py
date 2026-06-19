import os
import uuid
from datetime import datetime, timezone

from flask import current_app
from werkzeug.utils import secure_filename


def _allowed_extension(filename):
    if '.' not in filename:
        return False
    ext = filename.rsplit('.', 1)[1].lower()
    return ext in current_app.config['ALLOWED_MOMENT_EXTENSIONS']


def save_moment_photo(user_id, file_storage):
    if not file_storage or not file_storage.filename:
        raise ValueError('Photo file is required')

    original_name = secure_filename(file_storage.filename)
    if not _allowed_extension(original_name):
        raise ValueError('Unsupported image format')

    file_storage.seek(0, os.SEEK_END)
    size = file_storage.tell()
    file_storage.seek(0)
    if size > current_app.config['MAX_MOMENT_SIZE']:
        raise ValueError('Image is too large')

    ext = original_name.rsplit('.', 1)[1].lower()
    filename = f'moment_{user_id}_{uuid.uuid4().hex[:12]}.{ext}'
    folder = current_app.config['MOMENT_UPLOAD_FOLDER']
    os.makedirs(folder, exist_ok=True)
    file_storage.save(os.path.join(folder, filename))
    return filename, datetime.now(timezone.utc)


def moment_photo_file_path(moment):
    if not moment or not moment.photo_filename:
        return None
    return os.path.join(
        current_app.config['MOMENT_UPLOAD_FOLDER'],
        moment.photo_filename,
    )


def delete_moment_photo(moment):
    path = moment_photo_file_path(moment)
    if path and os.path.isfile(path):
        os.remove(path)
