import os
import os
from datetime import datetime, timezone

from flask import current_app
from werkzeug.utils import secure_filename


def _allowed_extension(filename):
    if '.' not in filename:
        return False
    ext = filename.rsplit('.', 1)[1].lower()
    return ext in current_app.config['ALLOWED_CLUB_EXTENSIONS']


def _save_image(folder_key, entity_id, prefix, file_storage):
    if not file_storage or not file_storage.filename:
        raise ValueError('Image file is required')

    original_name = secure_filename(file_storage.filename)
    if not _allowed_extension(original_name):
        raise ValueError('Unsupported image format')

    file_storage.seek(0, os.SEEK_END)
    size = file_storage.tell()
    file_storage.seek(0)
    max_size = current_app.config['MAX_CLUB_IMAGE_SIZE']
    if size > max_size:
        raise ValueError('Image is too large')

    ext = original_name.rsplit('.', 1)[1].lower()
    filename = f'{prefix}_{entity_id}.{ext}'
    folder = current_app.config[folder_key]
    os.makedirs(folder, exist_ok=True)

    for existing in os.listdir(folder):
        if existing.startswith(f'{prefix}_{entity_id}.'):
            existing_path = os.path.join(folder, existing)
            if os.path.isfile(existing_path):
                os.remove(existing_path)

    file_storage.save(os.path.join(folder, filename))
    return filename, datetime.now(timezone.utc)


def save_club_avatar(club_id, file_storage):
    return _save_image('CLUB_AVATAR_UPLOAD_FOLDER', club_id, 'club_avatar', file_storage)


def save_club_cover(club_id, file_storage):
    return _save_image('CLUB_COVER_UPLOAD_FOLDER', club_id, 'club_cover', file_storage)


def club_avatar_file_path(club):
    if not club or not club.avatar_filename:
        return None
    return os.path.join(
        current_app.config['CLUB_AVATAR_UPLOAD_FOLDER'],
        club.avatar_filename,
    )


def club_cover_file_path(club):
    if not club or not club.cover_filename:
        return None
    return os.path.join(
        current_app.config['CLUB_COVER_UPLOAD_FOLDER'],
        club.cover_filename,
    )


def delete_club_avatar(filename):
    if not filename:
        return
    path = os.path.join(
        current_app.config['CLUB_AVATAR_UPLOAD_FOLDER'],
        filename,
    )
    if os.path.isfile(path):
        os.remove(path)


def delete_club_cover(filename):
    if not filename:
        return
    path = os.path.join(
        current_app.config['CLUB_COVER_UPLOAD_FOLDER'],
        filename,
    )
    if os.path.isfile(path):
        os.remove(path)
