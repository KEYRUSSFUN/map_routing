from extensions import db

class UserInfo(db.Model):
    __tablename__ = 'user_info'
    id_User = db.Column(db.Integer, db.ForeignKey('users.id_User'), primary_key=True)
    name = db.Column(db.String(150), nullable=False)
    weight = db.Column(db.Float, nullable=False)
    height = db.Column(db.Float, nullable=False)
    sex = db.Column(db.String(10), nullable=False)
    Age = db.Column(db.Integer, nullable=False)
    country = db.Column(db.String(100), nullable=True)
    avatar_filename = db.Column(db.String(255), nullable=True)
    avatar_updated_at = db.Column(db.DateTime, nullable=True)

    user = db.relationship("User", back_populates="user_info")
