import os
import uuid
from datetime import datetime, timezone

from flask import current_app
from werkzeug.utils import secure_filename


def _allowed_extension(filename):
    if '.' not in filename:
        return False
    ext = filename.rsplit('.', 1)[1].lower()
    return ext in current_app.config['ALLOWED_STORY_EXTENSIONS']


def save_story_media(user_id, file_storage):
    if not file_storage or not file_storage.filename:
        raise ValueError('Story image is required')

    original_name = secure_filename(file_storage.filename)
    if not _allowed_extension(original_name):
        raise ValueError('Unsupported image format')

    file_storage.seek(0, os.SEEK_END)
    size = file_storage.tell()
    file_storage.seek(0)
    if size > current_app.config['MAX_STORY_SIZE']:
        raise ValueError('Image is too large')

    ext = original_name.rsplit('.', 1)[1].lower()
    filename = f'story_{user_id}_{uuid.uuid4().hex[:12]}.{ext}'
    folder = current_app.config['STORY_UPLOAD_FOLDER']
    os.makedirs(folder, exist_ok=True)
    file_storage.save(os.path.join(folder, filename))
    return filename, datetime.now(timezone.utc)


def story_media_file_path(story):
    if not story or not story.media_filename:
        return None
    return os.path.join(
        current_app.config['STORY_UPLOAD_FOLDER'],
        story.media_filename,
    )


def delete_story_media(story):
    path = story_media_file_path(story)
    if path and os.path.isfile(path):
        os.remove(path)
