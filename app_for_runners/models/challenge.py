from datetime import datetime, timezone

from extensions import db


class Challenge(db.Model):
    __tablename__ = 'challenge'

    id = db.Column(db.Integer, primary_key=True)
    title = db.Column(db.String(200), nullable=False)
    description = db.Column(db.Text, nullable=False, default='')
    metric_type = db.Column(db.String(32), nullable=False, default='distance')
    target_value = db.Column(db.Float, nullable=False)
    start_date = db.Column(db.Date, nullable=False)
    end_date = db.Column(db.Date, nullable=False)
    icon_key = db.Column(db.String(32), nullable=False, default='running')
    is_active = db.Column(db.Boolean, nullable=False, default=True)
    created_at = db.Column(
        db.DateTime,
        nullable=False,
        default=lambda: datetime.now(timezone.utc),
    )

    participants = db.relationship(
        'ChallengeParticipant',
        back_populates='challenge',
        lazy='dynamic',
    )


class ChallengeParticipant(db.Model):
    __tablename__ = 'challenge_participant'

    id = db.Column(db.Integer, primary_key=True)
    challenge_id = db.Column(
        db.Integer,
        db.ForeignKey('challenge.id'),
        nullable=False,
    )
    id_User = db.Column(db.Integer, db.ForeignKey('users.id_User'), nullable=False)
    joined_at = db.Column(
        db.DateTime,
        nullable=False,
        default=lambda: datetime.now(timezone.utc),
    )

    challenge = db.relationship('Challenge', back_populates='participants')
    user = db.relationship('User', backref='challenge_participations')

    __table_args__ = (
        db.UniqueConstraint('challenge_id', 'id_User', name='uq_challenge_participant'),
    )
