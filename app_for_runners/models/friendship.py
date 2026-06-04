from extensions import db
from datetime import datetime, timezone

class Friendship(db.Model):
    __tablename__ = 'friendships'
    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id_User'))
    friend_id = db.Column(db.Integer, db.ForeignKey('users.id_User'))
    status = db.Column(db.String(20), default='pending')
    created_at = db.Column(db.DateTime, default=lambda: datetime.now(timezone.utc))

    def __repr__(self):
        return f'<Friendship {self.id}: {self.user_id} - {self.friend_id}>'
