from datetime import datetime, timezone

from extensions import db


class Club(db.Model):
    __tablename__ = 'club'

    id = db.Column(db.Integer, primary_key=True)
    title = db.Column(db.String(255), nullable=False)
    description = db.Column(db.Text, nullable=True)
    sport_type = db.Column(db.String(50), nullable=False)
    club_type = db.Column(db.String(50), nullable=False)
    privacy = db.Column(db.String(20), nullable=False, default='open')
    location_scope = db.Column(db.String(20), nullable=False, default='worldwide')
    location_label = db.Column(db.String(255), nullable=True)
    profile_link = db.Column(db.String(512), nullable=True)
    avatar_filename = db.Column(db.String(255), nullable=True)
    cover_filename = db.Column(db.String(255), nullable=True)
    creator_id = db.Column(db.Integer, db.ForeignKey('users.id_User'), nullable=False)
    group_chat_id = db.Column(db.Integer, db.ForeignKey('group_chat.id'), nullable=True)
    show_activity_feed = db.Column(db.Boolean, nullable=False, default=True)
    show_leaderboards = db.Column(db.Boolean, nullable=False, default=True)
    admins_only_posting = db.Column(db.Boolean, nullable=False, default=False)
    created_at = db.Column(
        db.DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
    )

    creator = db.relationship('User', foreign_keys=[creator_id])
    group_chat = db.relationship('GroupChat', foreign_keys=[group_chat_id])
    members = db.relationship(
        'ClubMember',
        back_populates='club',
        cascade='all, delete-orphan',
    )


class ClubMember(db.Model):
    __tablename__ = 'club_member'

    club_id = db.Column(db.Integer, db.ForeignKey('club.id'), primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id_User'), primary_key=True)
    role = db.Column(db.String(20), nullable=False, default='member')
    status = db.Column(db.String(20), nullable=False, default='active')
    notification_level = db.Column(db.String(20), nullable=False, default='all')
    joined_at = db.Column(
        db.DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
    )

    club = db.relationship('Club', back_populates='members')
    user = db.relationship('User')
