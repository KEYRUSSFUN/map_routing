"""Add read tracking for chats and friend requests

Revision ID: 002_read_tracking
Revises: 001_initial_schema
Create Date: 2026-06-07

"""
from alembic import op
import sqlalchemy as sa


revision = '002_read_tracking'
down_revision = '001_initial_schema'
branch_labels = None
depends_on = None


def upgrade():
    op.add_column(
        'user_group_chat',
        sa.Column('last_read_at', sa.DateTime(), nullable=True),
    )
    op.add_column(
        'friendships',
        sa.Column('viewed_at', sa.DateTime(), nullable=True),
    )


def downgrade():
    op.drop_column('friendships', 'viewed_at')
    op.drop_column('user_group_chat', 'last_read_at')
