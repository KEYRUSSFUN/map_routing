import os
from datetime import datetime, timezone

from flask import current_app
from werkzeug.utils import secure_filename


def _allowed_extension(filename):
    if '.' not in filename:
        return False
    ext = filename.rsplit('.', 1)[1].lower()
    return ext in current_app.config['ALLOWED_AVATAR_EXTENSIONS']


def save_chat_photo(chat_id, file_storage):
    if not file_storage or not file_storage.filename:
        raise ValueError('Photo file is required')

    original_name = secure_filename(file_storage.filename)
    if not _allowed_extension(original_name):
        raise ValueError('Unsupported image format')

    file_storage.seek(0, os.SEEK_END)
    size = file_storage.tell()
    file_storage.seek(0)
    if size > current_app.config['MAX_AVATAR_SIZE']:
        raise ValueError('Image is too large')

    ext = original_name.rsplit('.', 1)[1].lower()
    filename = f'chat_{chat_id}.{ext}'
    folder = current_app.config['CHAT_PHOTO_UPLOAD_FOLDER']
    os.makedirs(folder, exist_ok=True)

    for existing in os.listdir(folder):
        if existing.startswith(f'chat_{chat_id}.'):
            existing_path = os.path.join(folder, existing)
            if os.path.isfile(existing_path):
                os.remove(existing_path)

    file_storage.save(os.path.join(folder, filename))
    return filename, datetime.now(timezone.utc)


def chat_photo_file_path(chat):
    if not chat or not chat.avatar_filename:
        return None
    return os.path.join(
        current_app.config['CHAT_PHOTO_UPLOAD_FOLDER'],
        chat.avatar_filename,
    )


def delete_chat_photo(filename):
    if not filename:
        return
    path = os.path.join(
        current_app.config['CHAT_PHOTO_UPLOAD_FOLDER'],
        filename,
    )
    if os.path.isfile(path):
        os.remove(path)
