"""Add public route snapshot to chat route shares

Revision ID: 014_route_share_snapshot
Revises: 013_workout_metadata
Create Date: 2026-06-17

"""
import json

from alembic import op
import sqlalchemy as sa


revision = '014_route_share_snapshot'
down_revision = '013_workout_metadata'
branch_labels = None
depends_on = None


def upgrade():
    op.add_column(
        'chat_route_share',
        sa.Column('snapshot_json', sa.Text(), nullable=True),
    )


def downgrade():
    op.drop_column('chat_route_share', 'snapshot_json')
