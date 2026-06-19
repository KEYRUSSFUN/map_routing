from datetime import datetime, timezone

from extensions import db


class Story(db.Model):
    __tablename__ = 'stories'

    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(
        db.Integer,
        db.ForeignKey('users.id_User', ondelete='CASCADE'),
        nullable=False,
        index=True,
    )
    media_filename = db.Column(db.String(255), nullable=False)
    caption = db.Column(db.String(500), nullable=True)
    created_at = db.Column(
        db.DateTime(timezone=True),
        nullable=False,
        default=lambda: datetime.now(timezone.utc),
    )
    expires_at = db.Column(db.DateTime(timezone=True), nullable=False, index=True)

    views = db.relationship(
        'StoryView',
        back_populates='story',
        cascade='all, delete-orphan',
        lazy='dynamic',
    )


class StoryView(db.Model):
    __tablename__ = 'story_views'
    __table_args__ = (
        db.UniqueConstraint('story_id', 'viewer_id', name='uq_story_view'),
    )

    id = db.Column(db.Integer, primary_key=True)
    story_id = db.Column(
        db.Integer,
        db.ForeignKey('stories.id', ondelete='CASCADE'),
        nullable=False,
        index=True,
    )
    viewer_id = db.Column(
        db.Integer,
        db.ForeignKey('users.id_User', ondelete='CASCADE'),
        nullable=False,
        index=True,
    )
    viewed_at = db.Column(
        db.DateTime(timezone=True),
        nullable=False,
        default=lambda: datetime.now(timezone.utc),
    )

    story = db.relationship('Story', back_populates='views')
