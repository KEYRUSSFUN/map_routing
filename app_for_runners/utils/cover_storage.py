import os
from datetime import datetime, timezone

from flask import current_app
from werkzeug.utils import secure_filename


def _allowed_extension(filename):
    if '.' not in filename:
        return False
    ext = filename.rsplit('.', 1)[1].lower()
    return ext in current_app.config['ALLOWED_COVER_EXTENSIONS']


def save_user_cover(user_id, file_storage):
    if not file_storage or not file_storage.filename:
        raise ValueError('Cover file is required')

    original_name = secure_filename(file_storage.filename)
    if not _allowed_extension(original_name):
        raise ValueError('Unsupported image format')

    file_storage.seek(0, os.SEEK_END)
    size = file_storage.tell()
    file_storage.seek(0)
    if size > current_app.config['MAX_COVER_SIZE']:
        raise ValueError('Image is too large')

    ext = original_name.rsplit('.', 1)[1].lower()
    filename = f'cover_{user_id}.{ext}'
    folder = current_app.config['COVER_UPLOAD_FOLDER']
    os.makedirs(folder, exist_ok=True)

    for existing in os.listdir(folder):
        if existing.startswith(f'cover_{user_id}.'):
            existing_path = os.path.join(folder, existing)
            if os.path.isfile(existing_path):
                os.remove(existing_path)

    file_storage.save(os.path.join(folder, filename))
    return filename, datetime.now(timezone.utc)


def cover_file_path(user_info):
    if not user_info or not user_info.cover_filename:
        return None
    return os.path.join(
        current_app.config['COVER_UPLOAD_FOLDER'],
        user_info.cover_filename,
    )
