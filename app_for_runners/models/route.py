from extensions import db
from datetime import datetime, timezone

class Route(db.Model):
    __tablename__ = 'routes'
    id_Route = db.Column(db.Integer, primary_key=True)
    id_User = db.Column(db.Integer, db.ForeignKey('users.id_User'), nullable=False)
    path = db.Column(db.Text, nullable=False)  # GeoJSON путь
    creation_date = db.Column(db.DateTime, default=datetime.utcnow)

    title = db.Column(db.String(255), nullable=True)
    activity_type = db.Column(db.String(32), nullable=True)
    description = db.Column(db.Text, nullable=True)
    tags = db.Column(db.Text, nullable=True)  # JSON-массив строк
    effort_level = db.Column(db.Integer, nullable=True)
    notes = db.Column(db.Text, nullable=True)
    privacy = db.Column(db.String(32), nullable=True)
    distance = db.Column(db.Float, nullable=True)
    duration_seconds = db.Column(db.Integer, nullable=True)
    calories = db.Column(db.Integer, nullable=True)
    elevation_gain_m = db.Column(db.Float, nullable=True)
    avg_speed_kmh = db.Column(db.Float, nullable=True)
    started_at = db.Column(db.DateTime, nullable=True)
    started_at_local_hour = db.Column(db.Integer, nullable=True)
    photo_filename = db.Column(db.String(255), nullable=True)

    user = db.relationship('User', backref='routes')
