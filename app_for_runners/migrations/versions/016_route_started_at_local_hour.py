"""Add local start hour for earlyBird achievement

Revision ID: 016_route_started_at_local_hour
Revises: 015_route_share_photo
Create Date: 2026-06-17

"""
from alembic import op
import sqlalchemy as sa


revision = '016_route_started_at_local_hour'
down_revision = '015_route_share_photo'
branch_labels = None
depends_on = None


def upgrade():
    op.add_column(
        'routes',
        sa.Column('started_at_local_hour', sa.Integer(), nullable=True),
    )


def downgrade():
    op.drop_column('routes', 'started_at_local_hour')
