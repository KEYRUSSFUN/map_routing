from flask import url_for

ALLOWED_COVER_PRESETS = frozenset(
    {
        'sport_trail',
        'sport_sprint',
        'sport_mountain',
        'sport_stadium',
        'sport_cycling',
        'sport_sunset',
        'sport_ocean',
        'sport_forest',
    }
)


def is_valid_cover_preset(preset):
    return preset in ALLOWED_COVER_PRESETS


def cover_url_for(user_info, *, external=False):
    if not user_info or not user_info.cover_filename:
        return None

    cover_url = url_for(
        'profile.get_user_cover',
        user_id=user_info.id_User,
        _external=external,
    )
    if user_info.cover_updated_at:
        cover_url += f'?v={int(user_info.cover_updated_at.timestamp())}'
    return cover_url
