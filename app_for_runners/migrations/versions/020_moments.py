"""Add moments, likes and comments

Revision ID: 020_moments
Revises: 019_user_last_seen
Create Date: 2026-06-19

"""
from alembic import op
import sqlalchemy as sa


revision = '020_moments'
down_revision = '019_user_last_seen'
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        'moments',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('user_id', sa.Integer(), nullable=False),
        sa.Column('text', sa.String(length=2000), nullable=True),
        sa.Column('photo_filename', sa.String(length=255), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(['user_id'], ['users.id_User'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index('ix_moments_user_id', 'moments', ['user_id'])
    op.create_index('ix_moments_created_at', 'moments', ['created_at'])

    op.create_table(
        'moment_likes',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('moment_id', sa.Integer(), nullable=False),
        sa.Column('user_id', sa.Integer(), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(['moment_id'], ['moments.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['user_id'], ['users.id_User'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('moment_id', 'user_id', name='uq_moment_like'),
    )
    op.create_index('ix_moment_likes_moment_id', 'moment_likes', ['moment_id'])
    op.create_index('ix_moment_likes_user_id', 'moment_likes', ['user_id'])

    op.create_table(
        'moment_comments',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('moment_id', sa.Integer(), nullable=False),
        sa.Column('user_id', sa.Integer(), nullable=False),
        sa.Column('text', sa.String(length=1000), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(['moment_id'], ['moments.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['user_id'], ['users.id_User'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index('ix_moment_comments_moment_id', 'moment_comments', ['moment_id'])
    op.create_index('ix_moment_comments_user_id', 'moment_comments', ['user_id'])
    op.create_index('ix_moment_comments_created_at', 'moment_comments', ['created_at'])


def downgrade():
    op.drop_index('ix_moment_comments_created_at', table_name='moment_comments')
    op.drop_index('ix_moment_comments_user_id', table_name='moment_comments')
    op.drop_index('ix_moment_comments_moment_id', table_name='moment_comments')
    op.drop_table('moment_comments')
    op.drop_index('ix_moment_likes_user_id', table_name='moment_likes')
    op.drop_index('ix_moment_likes_moment_id', table_name='moment_likes')
    op.drop_table('moment_likes')
    op.drop_index('ix_moments_created_at', table_name='moments')
    op.drop_index('ix_moments_user_id', table_name='moments')
    op.drop_table('moments')
