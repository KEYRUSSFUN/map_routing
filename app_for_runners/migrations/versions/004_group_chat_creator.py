"""Add group chat creator

Revision ID: 004_group_chat_creator
Revises: 003_user_avatar
Create Date: 2026-06-07

"""
from alembic import op
import sqlalchemy as sa


revision = '004_group_chat_creator'
down_revision = '003_user_avatar'
branch_labels = None
depends_on = None


def upgrade():
    op.add_column(
        'group_chat',
        sa.Column('creator_id', sa.Integer(), nullable=True),
    )
    op.create_foreign_key(
        'fk_group_chat_creator_id',
        'group_chat',
        'users',
        ['creator_id'],
        ['id_User'],
    )


def downgrade():
    op.drop_constraint('fk_group_chat_creator_id', 'group_chat', type_='foreignkey')
    op.drop_column('group_chat', 'creator_id')
