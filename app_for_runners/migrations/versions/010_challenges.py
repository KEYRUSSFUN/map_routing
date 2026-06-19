"""Add challenges

Revision ID: 010_challenges
Revises: 009_user_achievements
Create Date: 2026-06-17

"""
from datetime import date, datetime, timezone

from alembic import op
import sqlalchemy as sa


revision = '010_challenges'
down_revision = '009_user_achievements'
branch_labels = None
depends_on = None

_SEED_CREATED_AT = datetime(2026, 6, 17, tzinfo=timezone.utc)


def upgrade():
    challenge_table = op.create_table(
        'challenge',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('title', sa.String(length=200), nullable=False),
        sa.Column('description', sa.Text(), nullable=False),
        sa.Column('metric_type', sa.String(length=32), nullable=False),
        sa.Column('target_value', sa.Float(), nullable=False),
        sa.Column('start_date', sa.Date(), nullable=False),
        sa.Column('end_date', sa.Date(), nullable=False),
        sa.Column('icon_key', sa.String(length=32), nullable=False),
        sa.Column('is_active', sa.Boolean(), nullable=False),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.PrimaryKeyConstraint('id'),
    )

    op.create_table(
        'challenge_participant',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('challenge_id', sa.Integer(), nullable=False),
        sa.Column('id_User', sa.Integer(), nullable=False),
        sa.Column('joined_at', sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(['challenge_id'], ['challenge.id']),
        sa.ForeignKeyConstraint(['id_User'], ['users.id_User']),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('challenge_id', 'id_User', name='uq_challenge_participant'),
    )

    op.bulk_insert(
        challenge_table,
        [
            {
                'id': 1,
                'title': 'Недельный забег 25 км',
                'description': 'Пробегите 25 км за неделю вместе с сообществом.',
                'metric_type': 'distance',
                'target_value': 25.0,
                'start_date': date(2026, 6, 10),
                'end_date': date(2026, 6, 24),
                'icon_key': 'running',
                'is_active': True,
                'created_at': _SEED_CREATED_AT,
            },
            {
                'id': 2,
                'title': 'Городской велоспринт',
                'description': 'Проедьте 50 км на велосипеде за две недели.',
                'metric_type': 'distance',
                'target_value': 50.0,
                'start_date': date(2026, 6, 18),
                'end_date': date(2026, 7, 2),
                'icon_key': 'cycling',
                'is_active': True,
                'created_at': _SEED_CREATED_AT,
            },
            {
                'id': 3,
                'title': 'Шаговый марафон',
                'description': 'Наберите 300 000 шагов за месяц.',
                'metric_type': 'steps',
                'target_value': 300000.0,
                'start_date': date(2026, 6, 1),
                'end_date': date(2026, 6, 30),
                'icon_key': 'steps',
                'is_active': True,
                'created_at': _SEED_CREATED_AT,
            },
        ],
    )


def downgrade():
    op.drop_table('challenge_participant')
    op.drop_table('challenge')
