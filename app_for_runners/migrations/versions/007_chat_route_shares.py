"""Add chat route sharing

Revision ID: 007_chat_route_shares
Revises: 006_group_invitation_seen
Create Date: 2026-06-10

"""
from alembic import op
import sqlalchemy as sa


revision = '007_chat_route_shares'
down_revision = '006_group_invitation_seen'
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        'chat_route_share',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('chat_id', sa.Integer(), nullable=False),
        sa.Column('uploader_id', sa.Integer(), nullable=False),
        sa.Column('original_filename', sa.String(length=255), nullable=False),
        sa.Column('stored_filename', sa.String(length=255), nullable=False),
        sa.Column('title', sa.String(length=255), nullable=True),
        sa.Column('file_size', sa.Integer(), nullable=False),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(['chat_id'], ['group_chat.id']),
        sa.ForeignKeyConstraint(['uploader_id'], ['users.id_User']),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('stored_filename'),
    )

    op.add_column(
        'group_message',
        sa.Column('message_type', sa.String(length=20), nullable=False, server_default='text'),
    )
    op.add_column(
        'group_message',
        sa.Column('route_share_id', sa.Integer(), nullable=True),
    )
    op.create_foreign_key(
        'fk_group_message_route_share_id',
        'group_message',
        'chat_route_share',
        ['route_share_id'],
        ['id'],
    )


def downgrade():
    op.drop_constraint('fk_group_message_route_share_id', 'group_message', type_='foreignkey')
    op.drop_column('group_message', 'route_share_id')
    op.drop_column('group_message', 'message_type')
    op.drop_table('chat_route_share')
