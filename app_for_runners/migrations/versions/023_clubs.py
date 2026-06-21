"""Add clubs

Revision ID: 023_clubs
Revises: 022_user_cover
Create Date: 2026-06-20

"""
from alembic import op
import sqlalchemy as sa


revision = '023_clubs'
down_revision = '022_user_cover'
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        'club',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('title', sa.String(length=255), nullable=False),
        sa.Column('description', sa.Text(), nullable=True),
        sa.Column('sport_type', sa.String(length=50), nullable=False),
        sa.Column('club_type', sa.String(length=50), nullable=False),
        sa.Column('privacy', sa.String(length=20), nullable=False),
        sa.Column('location_scope', sa.String(length=20), nullable=False),
        sa.Column('location_label', sa.String(length=255), nullable=True),
        sa.Column('profile_link', sa.String(length=512), nullable=True),
        sa.Column('avatar_filename', sa.String(length=255), nullable=True),
        sa.Column('cover_filename', sa.String(length=255), nullable=True),
        sa.Column('creator_id', sa.Integer(), nullable=False),
        sa.Column('group_chat_id', sa.Integer(), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(['creator_id'], ['users.id_User']),
        sa.ForeignKeyConstraint(['group_chat_id'], ['group_chat.id']),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_table(
        'club_member',
        sa.Column('club_id', sa.Integer(), nullable=False),
        sa.Column('user_id', sa.Integer(), nullable=False),
        sa.Column('role', sa.String(length=20), nullable=False),
        sa.Column('status', sa.String(length=20), nullable=False),
        sa.Column('joined_at', sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(['club_id'], ['club.id']),
        sa.ForeignKeyConstraint(['user_id'], ['users.id_User']),
        sa.PrimaryKeyConstraint('club_id', 'user_id'),
    )


def downgrade():
    op.drop_table('club_member')
    op.drop_table('club')
