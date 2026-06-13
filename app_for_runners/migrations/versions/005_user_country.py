"""Add country to user_info

Revision ID: 005_user_country
Revises: 004_group_chat_creator
Create Date: 2026-06-10

"""
from alembic import op
import sqlalchemy as sa


revision = '005_user_country'
down_revision = '004_group_chat_creator'
branch_labels = None
depends_on = None


def upgrade():
    op.add_column(
        'user_info',
        sa.Column('country', sa.String(length=100), nullable=True),
    )


def downgrade():
    op.drop_column('user_info', 'country')
