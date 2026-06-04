from extensions import db
from datetime import datetime, timezone

class UserStatistic(db.Model):
    __tablename__ = 'user_statistic'
    id = db.Column(db.Integer, primary_key=True)
    id_User = db.Column(db.Integer, db.ForeignKey('user_info.id_User'), nullable=False)
    calories = db.Column(db.Float, nullable=False)
    steps = db.Column(db.Integer, nullable=False)
    distance = db.Column(db.Float, nullable=False)
    date = db.Column(db.Date, nullable=False, default=lambda: datetime.now(timezone.utc).date())

    user_info = db.relationship("UserInfo", backref="statistics")
