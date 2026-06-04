from extensions import db
from datetime import datetime, timezone

class UserGroupChatAssociation(db.Model):
    __tablename__ = 'user_group_chat'
    user_id = db.Column(db.Integer, db.ForeignKey('users.id_User'), primary_key=True)
    chat_id = db.Column(db.Integer, db.ForeignKey('group_chat.id'), primary_key=True)
    joined_at = db.Column(db.DateTime, default=lambda: datetime.now(timezone.utc))

class GroupChat(db.Model):
    __tablename__ = 'group_chat'
    id = db.Column(db.Integer, primary_key=True)
    title = db.Column(db.String(255), nullable=False)

    members = db.relationship('User', secondary='user_group_chat', back_populates="group_chats")
    messages = db.relationship('GroupMessage', backref='chat', lazy='dynamic')

class GroupMessage(db.Model):
    __tablename__ = 'group_message'
    id = db.Column(db.Integer, primary_key=True)
    chat_id = db.Column(db.Integer, db.ForeignKey('group_chat.id'), nullable=False)
    sender_id = db.Column(db.Integer, db.ForeignKey('users.id_User'), nullable=False)
    content = db.Column(db.Text, nullable=False)
    timestamp = db.Column(db.DateTime, default=lambda: datetime.now(timezone.utc))

    sender = db.relationship("User", backref="sent_messages")
