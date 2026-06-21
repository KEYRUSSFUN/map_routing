"""Add profile cover fields

Revision ID: 022_user_cover
Revises: 021_password_reset_tokens
Create Date: 2026-06-20

"""
from alembic import op
import sqlalchemy as sa


revision = '022_user_cover'
down_revision = '021_password_reset_tokens'
branch_labels = None
depends_on = None


def upgrade():
    op.add_column(
        'user_info',
        sa.Column('cover_preset', sa.String(length=50), nullable=True),
    )
    op.add_column(
        'user_info',
        sa.Column('cover_filename', sa.String(length=255), nullable=True),
    )
    op.add_column(
        'user_info',
        sa.Column('cover_updated_at', sa.DateTime(timezone=True), nullable=True),
    )


def downgrade():
    op.drop_column('user_info', 'cover_updated_at')
    op.drop_column('user_info', 'cover_filename')
    op.drop_column('user_info', 'cover_preset')
