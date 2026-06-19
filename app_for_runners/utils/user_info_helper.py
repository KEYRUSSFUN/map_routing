from extensions import db
from models import User, UserInfo

_DEFAULT_WEIGHT = 70.0
_DEFAULT_HEIGHT = 170.0
_DEFAULT_AGE = 25


def ensure_user_info_exists(user_id):
    """Создаёт минимальный профиль, если его нет (FK user_statistic → user_info)."""
    if UserInfo.query.filter_by(id_User=user_id).first():
        return

    user = User.query.get(user_id)
    name = 'Спортсмен'
    if user and user.email:
        name = user.email.split('@')[0][:150]

    db.session.add(
        UserInfo(
            id_User=user_id,
            name=name,
            weight=_DEFAULT_WEIGHT,
            height=_DEFAULT_HEIGHT,
            sex='male',
            Age=_DEFAULT_AGE,
            country='',
        )
    )
    db.session.flush()
