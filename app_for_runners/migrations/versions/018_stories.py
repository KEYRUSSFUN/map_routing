"""Add stories and story views

Revision ID: 018_stories
Revises: 017_chat_settings
Create Date: 2026-06-18

"""
from alembic import op
import sqlalchemy as sa


revision = '018_stories'
down_revision = '017_chat_settings'
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        'stories',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('user_id', sa.Integer(), nullable=False),
        sa.Column('media_filename', sa.String(length=255), nullable=False),
        sa.Column('caption', sa.String(length=500), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('expires_at', sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(['user_id'], ['users.id_User'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index('ix_stories_user_id', 'stories', ['user_id'])
    op.create_index('ix_stories_expires_at', 'stories', ['expires_at'])

    op.create_table(
        'story_views',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('story_id', sa.Integer(), nullable=False),
        sa.Column('viewer_id', sa.Integer(), nullable=False),
        sa.Column('viewed_at', sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(['story_id'], ['stories.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['viewer_id'], ['users.id_User'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('story_id', 'viewer_id', name='uq_story_view'),
    )
    op.create_index('ix_story_views_story_id', 'story_views', ['story_id'])
    op.create_index('ix_story_views_viewer_id', 'story_views', ['viewer_id'])


def downgrade():
    op.drop_index('ix_story_views_viewer_id', table_name='story_views')
    op.drop_index('ix_story_views_story_id', table_name='story_views')
    op.drop_table('story_views')
    op.drop_index('ix_stories_expires_at', table_name='stories')
    op.drop_index('ix_stories_user_id', table_name='stories')
    op.drop_table('stories')
