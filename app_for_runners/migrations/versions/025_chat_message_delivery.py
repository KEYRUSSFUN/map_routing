"""Track chat message delivery per member

Revision ID: 025_chat_message_delivery
Revises: 024_club_channel
Create Date: 2026-06-21

"""
from alembic import op
import sqlalchemy as sa


revision = '025_chat_message_delivery'
down_revision = '024_club_channel'
branch_labels = None
depends_on = None


def upgrade():
    op.add_column(
        'user_group_chat',
        sa.Column('last_received_at', sa.DateTime(), nullable=True),
    )


def downgrade():
    op.drop_column('user_group_chat', 'last_received_at')
