from extensions import db
from datetime import datetime, timezone

class UserGroupChatAssociation(db.Model):
    __tablename__ = 'user_group_chat'
    user_id = db.Column(db.Integer, db.ForeignKey('users.id_User'), primary_key=True)
    chat_id = db.Column(db.Integer, db.ForeignKey('group_chat.id'), primary_key=True)
    joined_at = db.Column(db.DateTime, default=lambda: datetime.now(timezone.utc))
    last_read_at = db.Column(db.DateTime, nullable=True)
    invitation_seen_at = db.Column(db.DateTime, nullable=True)

class GroupChat(db.Model):
    __tablename__ = 'group_chat'
    id = db.Column(db.Integer, primary_key=True)
    title = db.Column(db.String(255), nullable=False)
    creator_id = db.Column(db.Integer, db.ForeignKey('users.id_User'), nullable=True)

    creator = db.relationship('User', foreign_keys=[creator_id])
    members = db.relationship('User', secondary='user_group_chat', back_populates="group_chats")
    messages = db.relationship('GroupMessage', backref='chat', lazy='dynamic')

class GroupMessage(db.Model):
    __tablename__ = 'group_message'
    id = db.Column(db.Integer, primary_key=True)
    chat_id = db.Column(db.Integer, db.ForeignKey('group_chat.id'), nullable=False)
    sender_id = db.Column(db.Integer, db.ForeignKey('users.id_User'), nullable=False)
    content = db.Column(db.Text, nullable=False)
    message_type = db.Column(db.String(20), nullable=False, default='text')
    route_share_id = db.Column(
        db.Integer,
        db.ForeignKey('chat_route_share.id'),
        nullable=True,
    )
    timestamp = db.Column(db.DateTime, default=lambda: datetime.now(timezone.utc))

    sender = db.relationship("User", backref="sent_messages")
    route_share = db.relationship(
        'ChatRouteShare',
        backref=db.backref('message', uselist=False),
        foreign_keys=[route_share_id],
    )
    reactions = db.relationship(
        'MessageReaction',
        backref='message',
        lazy='dynamic',
        cascade='all, delete-orphan',
    )
