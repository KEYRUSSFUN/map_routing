"""Initial schema

Revision ID: 001_initial_schema
Revises:
Create Date: 2026-06-06

"""
from alembic import op
import sqlalchemy as sa


revision = '001_initial_schema'
down_revision = None
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        'users',
        sa.Column('id_User', sa.Integer(), nullable=False),
        sa.Column('password', sa.String(length=255), nullable=False),
        sa.Column('email', sa.String(length=100), nullable=False),
        sa.PrimaryKeyConstraint('id_User'),
    )

    op.create_table(
        'user_info',
        sa.Column('id_User', sa.Integer(), nullable=False),
        sa.Column('name', sa.String(length=150), nullable=False),
        sa.Column('weight', sa.Float(), nullable=False),
        sa.Column('height', sa.Float(), nullable=False),
        sa.Column('sex', sa.String(length=10), nullable=False),
        sa.Column('Age', sa.Integer(), nullable=False),
        sa.ForeignKeyConstraint(['id_User'], ['users.id_User']),
        sa.PrimaryKeyConstraint('id_User'),
    )

    op.create_table(
        'friendships',
        sa.Column('id', sa.Integer(), autoincrement=True, nullable=False),
        sa.Column('user_id', sa.Integer(), nullable=True),
        sa.Column('friend_id', sa.Integer(), nullable=True),
        sa.Column('status', sa.String(length=20), nullable=True),
        sa.Column('created_at', sa.DateTime(), nullable=True),
        sa.ForeignKeyConstraint(['friend_id'], ['users.id_User']),
        sa.ForeignKeyConstraint(['user_id'], ['users.id_User']),
        sa.PrimaryKeyConstraint('id'),
    )

    op.create_table(
        'group_chat',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('title', sa.String(length=255), nullable=False),
        sa.PrimaryKeyConstraint('id'),
    )

    op.create_table(
        'user_group_chat',
        sa.Column('user_id', sa.Integer(), nullable=False),
        sa.Column('chat_id', sa.Integer(), nullable=False),
        sa.Column('joined_at', sa.DateTime(), nullable=True),
        sa.ForeignKeyConstraint(['chat_id'], ['group_chat.id']),
        sa.ForeignKeyConstraint(['user_id'], ['users.id_User']),
        sa.PrimaryKeyConstraint('user_id', 'chat_id'),
    )

    op.create_table(
        'group_message',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('chat_id', sa.Integer(), nullable=False),
        sa.Column('sender_id', sa.Integer(), nullable=False),
        sa.Column('content', sa.Text(), nullable=False),
        sa.Column('timestamp', sa.DateTime(), nullable=True),
        sa.ForeignKeyConstraint(['chat_id'], ['group_chat.id']),
        sa.ForeignKeyConstraint(['sender_id'], ['users.id_User']),
        sa.PrimaryKeyConstraint('id'),
    )

    op.create_table(
        'user_statistic',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('id_User', sa.Integer(), nullable=False),
        sa.Column('calories', sa.Float(), nullable=False),
        sa.Column('steps', sa.Integer(), nullable=False),
        sa.Column('distance', sa.Float(), nullable=False),
        sa.Column('date', sa.Date(), nullable=False),
        sa.ForeignKeyConstraint(['id_User'], ['user_info.id_User']),
        sa.PrimaryKeyConstraint('id'),
    )

    op.create_table(
        'routes',
        sa.Column('id_Route', sa.Integer(), nullable=False),
        sa.Column('id_User', sa.Integer(), nullable=False),
        sa.Column('path', sa.Text(), nullable=False),
        sa.Column('creation_date', sa.DateTime(), nullable=True),
        sa.ForeignKeyConstraint(['id_User'], ['users.id_User']),
        sa.PrimaryKeyConstraint('id_Route'),
    )


def downgrade():
    op.drop_table('routes')
    op.drop_table('user_statistic')
    op.drop_table('group_message')
    op.drop_table('user_group_chat')
    op.drop_table('group_chat')
    op.drop_table('friendships')
    op.drop_table('user_info')
    op.drop_table('users')
