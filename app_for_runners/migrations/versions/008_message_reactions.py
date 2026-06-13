"""Add message reactions

Revision ID: 008_message_reactions
Revises: 007_chat_route_shares
Create Date: 2026-06-10

"""
from alembic import op
import sqlalchemy as sa


revision = '008_message_reactions'
down_revision = '007_chat_route_shares'
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        'message_reaction',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('message_id', sa.Integer(), nullable=False),
        sa.Column('user_id', sa.Integer(), nullable=False),
        sa.Column('emoji', sa.String(length=16), nullable=False),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(['message_id'], ['group_message.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['user_id'], ['users.id_User']),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('message_id', 'user_id', name='uq_message_user_reaction'),
    )


def downgrade():
    op.drop_table('message_reaction')
