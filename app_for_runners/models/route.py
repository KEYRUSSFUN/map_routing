from extensions import db
from datetime import datetime, timezone

class Route(db.Model):
    __tablename__ = 'routes'
    id_Route = db.Column(db.Integer, primary_key=True)
    id_User = db.Column(db.Integer, db.ForeignKey('users.id_User'), nullable=False)
    path = db.Column(db.Text, nullable=False)  # GeoJSON путь
    creation_date = db.Column(db.DateTime, default=datetime.utcnow)
    
    # Связь с пользователем
    user = db.relationship('User', backref='routes')