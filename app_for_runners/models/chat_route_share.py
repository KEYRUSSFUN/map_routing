from extensions import db
from datetime import datetime, timezone


class ChatRouteShare(db.Model):
    __tablename__ = 'chat_route_share'

    id = db.Column(db.Integer, primary_key=True)
    chat_id = db.Column(db.Integer, db.ForeignKey('group_chat.id'), nullable=False)
    uploader_id = db.Column(db.Integer, db.ForeignKey('users.id_User'), nullable=False)
    original_filename = db.Column(db.String(255), nullable=False)
    stored_filename = db.Column(db.String(255), nullable=False, unique=True)
    title = db.Column(db.String(255), nullable=True)
    file_size = db.Column(db.Integer, nullable=False, default=0)
    created_at = db.Column(
        db.DateTime,
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
    )

    chat = db.relationship('GroupChat', backref='route_shares')
    uploader = db.relationship('User', backref='shared_routes')
