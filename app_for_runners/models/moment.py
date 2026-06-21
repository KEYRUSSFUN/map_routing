from datetime import datetime, timezone

from extensions import db


class Moment(db.Model):
    __tablename__ = 'moments'

    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(
        db.Integer,
        db.ForeignKey('users.id_User', ondelete='CASCADE'),
        nullable=False,
        index=True,
    )
    club_id = db.Column(
        db.Integer,
        db.ForeignKey('club.id', ondelete='CASCADE'),
        nullable=True,
        index=True,
    )
    text = db.Column(db.String(2000), nullable=True)
    photo_filename = db.Column(db.String(255), nullable=True)
    created_at = db.Column(
        db.DateTime(timezone=True),
        nullable=False,
        default=lambda: datetime.now(timezone.utc),
        index=True,
    )

    likes = db.relationship(
        'MomentLike',
        back_populates='moment',
        cascade='all, delete-orphan',
        lazy='dynamic',
    )
    comments = db.relationship(
        'MomentComment',
        back_populates='moment',
        cascade='all, delete-orphan',
        lazy='dynamic',
    )


class MomentLike(db.Model):
    __tablename__ = 'moment_likes'
    __table_args__ = (
        db.UniqueConstraint('moment_id', 'user_id', name='uq_moment_like'),
    )

    id = db.Column(db.Integer, primary_key=True)
    moment_id = db.Column(
        db.Integer,
        db.ForeignKey('moments.id', ondelete='CASCADE'),
        nullable=False,
        index=True,
    )
    user_id = db.Column(
        db.Integer,
        db.ForeignKey('users.id_User', ondelete='CASCADE'),
        nullable=False,
        index=True,
    )
    created_at = db.Column(
        db.DateTime(timezone=True),
        nullable=False,
        default=lambda: datetime.now(timezone.utc),
    )

    moment = db.relationship('Moment', back_populates='likes')


class MomentComment(db.Model):
    __tablename__ = 'moment_comments'

    id = db.Column(db.Integer, primary_key=True)
    moment_id = db.Column(
        db.Integer,
        db.ForeignKey('moments.id', ondelete='CASCADE'),
        nullable=False,
        index=True,
    )
    user_id = db.Column(
        db.Integer,
        db.ForeignKey('users.id_User', ondelete='CASCADE'),
        nullable=False,
        index=True,
    )
    text = db.Column(db.String(1000), nullable=False)
    created_at = db.Column(
        db.DateTime(timezone=True),
        nullable=False,
        default=lambda: datetime.now(timezone.utc),
        index=True,
    )

    moment = db.relationship('Moment', back_populates='comments')
