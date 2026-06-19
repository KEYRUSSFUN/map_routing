"""Add photo to chat route shares

Revision ID: 015_route_share_photo
Revises: 014_route_share_snapshot
Create Date: 2026-06-17

"""
from alembic import op
import sqlalchemy as sa


revision = '015_route_share_photo'
down_revision = '014_route_share_snapshot'
branch_labels = None
depends_on = None


def upgrade():
    op.add_column(
        'chat_route_share',
        sa.Column('photo_filename', sa.String(length=255), nullable=True),
    )


def downgrade():
    op.drop_column('chat_route_share', 'photo_filename')
