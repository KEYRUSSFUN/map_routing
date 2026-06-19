from extensions import db
from flask_login import UserMixin

class User(db.Model, UserMixin):
    __tablename__ = 'users'
    id_User = db.Column(db.Integer, primary_key=True)
    password = db.Column(db.String(255), nullable=True)
    email = db.Column(db.String(100), nullable=False)
    google_id = db.Column(db.String(128), nullable=True, unique=True)
    last_seen_at = db.Column(db.DateTime(timezone=True), nullable=True)

    user_info = db.relationship("UserInfo", back_populates="user", uselist=False)
    group_chats = db.relationship('GroupChat', secondary='user_group_chat', back_populates="members")
    friendships = db.relationship(
        'Friendship',
        foreign_keys='Friendship.user_id',
        backref=db.backref('user', lazy='joined'),
        lazy='dynamic'
    )
    friend_of = db.relationship(
        'Friendship',
        foreign_keys='Friendship.friend_id',
        backref=db.backref('friend', lazy='joined'),
        lazy='dynamic'
    )

    def get_friends(self):
        accepted_friendships = self.friendships.filter_by(status='accepted').all()
        return [friendship.friend for friendship in accepted_friendships]

    def get_id(self):
        return int(self.id_User)
