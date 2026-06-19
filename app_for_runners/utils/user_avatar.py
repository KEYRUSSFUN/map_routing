from flask import url_for


def avatar_url_for(user_info, *, external=False):
    if not user_info or not user_info.avatar_filename:
        return None

    avatar_url = url_for(
        'profile.get_user_avatar',
        user_id=user_info.id_User,
        _external=external,
    )
    if user_info.avatar_updated_at:
        avatar_url += f'?v={int(user_info.avatar_updated_at.timestamp())}'
    return avatar_url
