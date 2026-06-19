"""Add indexes for hot query paths

Revision ID: 012_performance_indexes
Revises: 011_google_auth
Create Date: 2026-06-17

"""
from alembic import op


revision = '012_performance_indexes'
down_revision = '011_google_auth'
branch_labels = None
depends_on = None


def upgrade():
    op.create_index(
        'ix_friendships_user_id_status',
        'friendships',
        ['user_id', 'status'],
        unique=False,
    )
    op.create_index(
        'ix_friendships_friend_id_status',
        'friendships',
        ['friend_id', 'status'],
        unique=False,
    )
    op.create_index(
        'ix_group_message_chat_id_timestamp',
        'group_message',
        ['chat_id', 'timestamp'],
        unique=False,
    )
    op.create_index(
        'ix_group_message_chat_id_id',
        'group_message',
        ['chat_id', 'id'],
        unique=False,
    )
    op.create_index(
        'ix_user_statistic_user_date',
        'user_statistic',
        ['id_User', 'date'],
        unique=False,
    )
    op.create_index(
        'ix_user_group_chat_user_id',
        'user_group_chat',
        ['user_id'],
        unique=False,
    )
    op.create_index(
        'ix_challenge_participant_challenge_id',
        'challenge_participant',
        ['challenge_id'],
        unique=False,
    )
    op.create_index(
        'ix_message_reaction_message_id',
        'message_reaction',
        ['message_id'],
        unique=False,
    )


def downgrade():
    op.drop_index('ix_message_reaction_message_id', table_name='message_reaction')
    op.drop_index('ix_challenge_participant_challenge_id', table_name='challenge_participant')
    op.drop_index('ix_user_group_chat_user_id', table_name='user_group_chat')
    op.drop_index('ix_user_statistic_user_date', table_name='user_statistic')
    op.drop_index('ix_group_message_chat_id_id', table_name='group_message')
    op.drop_index('ix_group_message_chat_id_timestamp', table_name='group_message')
    op.drop_index('ix_friendships_friend_id_status', table_name='friendships')
    op.drop_index('ix_friendships_user_id_status', table_name='friendships')
