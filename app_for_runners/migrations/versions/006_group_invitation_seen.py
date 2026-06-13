"""Add invitation seen tracking for group chats

Revision ID: 006_group_invitation_seen
Revises: 005_user_country
Create Date: 2026-06-10

"""
from alembic import op
import sqlalchemy as sa


revision = '006_group_invitation_seen'
down_revision = '005_user_country'
branch_labels = None
depends_on = None


def upgrade():
    op.add_column(
        'user_group_chat',
        sa.Column('invitation_seen_at', sa.DateTime(), nullable=True),
    )
    op.execute(
        'UPDATE user_group_chat SET invitation_seen_at = joined_at '
        'WHERE joined_at IS NOT NULL'
    )


def downgrade():
    op.drop_column('user_group_chat', 'invitation_seen_at')
