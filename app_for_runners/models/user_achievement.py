from datetime import datetime, timezone

from extensions import db


class UserAchievement(db.Model):
    __tablename__ = 'user_achievement'

    id = db.Column(db.Integer, primary_key=True)
    id_User = db.Column(db.Integer, db.ForeignKey('users.id_User'), nullable=False)
    achievement_id = db.Column(db.String(64), nullable=False)
    unlocked_at = db.Column(
        db.DateTime,
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
    )

    user = db.relationship('User', backref='achievements')

    __table_args__ = (
        db.UniqueConstraint('id_User', 'achievement_id', name='uq_user_achievement'),
    )
