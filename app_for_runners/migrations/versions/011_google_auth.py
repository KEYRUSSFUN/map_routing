"""Add Google OAuth fields to users

Revision ID: 011_google_auth
Revises: 010_challenges
Create Date: 2026-06-17

"""
from alembic import op
import sqlalchemy as sa


revision = '011_google_auth'
down_revision = '010_challenges'
branch_labels = None
depends_on = None


def upgrade():
    op.add_column('users', sa.Column('google_id', sa.String(length=128), nullable=True))
    op.create_unique_constraint('uq_users_google_id', 'users', ['google_id'])
    op.alter_column('users', 'password', existing_type=sa.String(length=255), nullable=True)


def downgrade():
    op.alter_column('users', 'password', existing_type=sa.String(length=255), nullable=False)
    op.drop_constraint('uq_users_google_id', 'users', type_='unique')
    op.drop_column('users', 'google_id')
