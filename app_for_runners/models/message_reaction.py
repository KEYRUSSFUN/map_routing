from extensions import db
from datetime import datetime, timezone


class MessageReaction(db.Model):
    __tablename__ = 'message_reaction'

    id = db.Column(db.Integer, primary_key=True)
    message_id = db.Column(
        db.Integer,
        db.ForeignKey('group_message.id', ondelete='CASCADE'),
        nullable=False,
    )
    user_id = db.Column(db.Integer, db.ForeignKey('users.id_User'), nullable=False)
    emoji = db.Column(db.String(16), nullable=False)
    created_at = db.Column(
        db.DateTime,
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
    )

    user = db.relationship('User', backref='message_reactions')

    __table_args__ = (
        db.UniqueConstraint('message_id', 'user_id', name='uq_message_user_reaction'),
    )
