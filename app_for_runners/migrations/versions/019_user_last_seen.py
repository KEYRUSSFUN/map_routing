"""Add user last_seen_at for online presence

Revision ID: 019_user_last_seen
Revises: 018_stories
Create Date: 2026-06-18

"""
from alembic import op
import sqlalchemy as sa


revision = '019_user_last_seen'
down_revision = '018_stories'
branch_labels = None
depends_on = None


def upgrade():
    op.add_column(
        'users',
        sa.Column('last_seen_at', sa.DateTime(timezone=True), nullable=True),
    )


def downgrade():
    op.drop_column('users', 'last_seen_at')
