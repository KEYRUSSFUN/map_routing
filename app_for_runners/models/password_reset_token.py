from datetime import datetime, timezone

from extensions import db


class PasswordResetToken(db.Model):
    __tablename__ = 'password_reset_tokens'

    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(
        db.Integer,
        db.ForeignKey('users.id_User', ondelete='CASCADE'),
        nullable=False,
        index=True,
    )
    code_hash = db.Column(db.String(255), nullable=False)
    expires_at = db.Column(db.DateTime(timezone=True), nullable=False)
    created_at = db.Column(
        db.DateTime(timezone=True),
        nullable=False,
        default=lambda: datetime.now(timezone.utc),
    )

    user = db.relationship('User', backref=db.backref('password_reset_tokens', lazy='dynamic'))

    @property
    def is_expired(self):
        return datetime.now(timezone.utc) >= self.expires_at
