"""Add user avatar fields

Revision ID: 003_user_avatar
Revises: 002_read_tracking
Create Date: 2026-06-07

"""
from alembic import op
import sqlalchemy as sa


revision = '003_user_avatar'
down_revision = '002_read_tracking'
branch_labels = None
depends_on = None


def upgrade():
    op.add_column(
        'user_info',
        sa.Column('avatar_filename', sa.String(length=255), nullable=True),
    )
    op.add_column(
        'user_info',
        sa.Column('avatar_updated_at', sa.DateTime(), nullable=True),
    )


def downgrade():
    op.drop_column('user_info', 'avatar_updated_at')
    op.drop_column('user_info', 'avatar_filename')
