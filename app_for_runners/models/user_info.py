from extensions import db

class UserInfo(db.Model):
    __tablename__ = 'user_info'
    id_User = db.Column(db.Integer, db.ForeignKey('users.id_User'), primary_key=True)
    name = db.Column(db.String(150), nullable=False)
    weight = db.Column(db.Float, nullable=False)
    height = db.Column(db.Float, nullable=False)
    sex = db.Column(db.String(10), nullable=False)
    Age = db.Column(db.Integer, nullable=False)
    # Country = db.Column(db.String(30), nullable=False)

    user = db.relationship("User", back_populates="user_info")
