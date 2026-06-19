"""Add workout metadata fields to routes

Revision ID: 013_workout_metadata
Revises: 012_performance_indexes
Create Date: 2026-06-17

"""
from alembic import op
import sqlalchemy as sa


revision = '013_workout_metadata'
down_revision = '012_performance_indexes'
branch_labels = None
depends_on = None


def upgrade():
    op.add_column('routes', sa.Column('title', sa.String(length=255), nullable=True))
    op.add_column('routes', sa.Column('activity_type', sa.String(length=32), nullable=True))
    op.add_column('routes', sa.Column('description', sa.Text(), nullable=True))
    op.add_column('routes', sa.Column('tags', sa.Text(), nullable=True))
    op.add_column('routes', sa.Column('effort_level', sa.Integer(), nullable=True))
    op.add_column('routes', sa.Column('notes', sa.Text(), nullable=True))
    op.add_column('routes', sa.Column('privacy', sa.String(length=32), nullable=True))
    op.add_column('routes', sa.Column('distance', sa.Float(), nullable=True))
    op.add_column('routes', sa.Column('duration_seconds', sa.Integer(), nullable=True))
    op.add_column('routes', sa.Column('calories', sa.Integer(), nullable=True))
    op.add_column('routes', sa.Column('elevation_gain_m', sa.Float(), nullable=True))
    op.add_column('routes', sa.Column('avg_speed_kmh', sa.Float(), nullable=True))
    op.add_column('routes', sa.Column('started_at', sa.DateTime(), nullable=True))
    op.add_column('routes', sa.Column('photo_filename', sa.String(length=255), nullable=True))


def downgrade():
    op.drop_column('routes', 'photo_filename')
    op.drop_column('routes', 'started_at')
    op.drop_column('routes', 'avg_speed_kmh')
    op.drop_column('routes', 'elevation_gain_m')
    op.drop_column('routes', 'calories')
    op.drop_column('routes', 'duration_seconds')
    op.drop_column('routes', 'distance')
    op.drop_column('routes', 'privacy')
    op.drop_column('routes', 'notes')
    op.drop_column('routes', 'effort_level')
    op.drop_column('routes', 'tags')
    op.drop_column('routes', 'description')
    op.drop_column('routes', 'activity_type')
    op.drop_column('routes', 'title')
