"""Add user achievements

Revision ID: 009_user_achievements
Revises: 008_message_reactions
Create Date: 2026-06-17

"""
from alembic import op
import sqlalchemy as sa


revision = '009_user_achievements'
down_revision = '008_message_reactions'
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        'user_achievement',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('id_User', sa.Integer(), nullable=False),
        sa.Column('achievement_id', sa.String(length=64), nullable=False),
        sa.Column('unlocked_at', sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(['id_User'], ['users.id_User']),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('id_User', 'achievement_id', name='uq_user_achievement'),
    )


def downgrade():
    op.drop_table('user_achievement')
