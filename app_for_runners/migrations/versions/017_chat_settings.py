"""Add chat photo and per-user notification mute

Revision ID: 017_chat_settings
Revises: 016_route_started_at_local_hour
Create Date: 2026-06-18

"""
from alembic import op
import sqlalchemy as sa


revision = '017_chat_settings'
down_revision = '016_route_started_at_local_hour'
branch_labels = None
depends_on = None


def upgrade():
    op.add_column(
        'group_chat',
        sa.Column('avatar_filename', sa.String(length=255), nullable=True),
    )
    op.add_column(
        'user_group_chat',
        sa.Column(
            'notifications_muted',
            sa.Boolean(),
            nullable=False,
            server_default=sa.false(),
        ),
    )


def downgrade():
    op.drop_column('user_group_chat', 'notifications_muted')
    op.drop_column('group_chat', 'avatar_filename')
