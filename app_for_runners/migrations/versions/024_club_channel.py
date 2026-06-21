"""Club channel: posts, settings, member prefs

Revision ID: 024_club_channel
Revises: 023_clubs
Create Date: 2026-06-20

"""
from alembic import op
import sqlalchemy as sa


revision = '024_club_channel'
down_revision = '023_clubs'
branch_labels = None
depends_on = None


def upgrade():
    op.add_column(
        'club',
        sa.Column('show_activity_feed', sa.Boolean(), nullable=False, server_default=sa.true()),
    )
    op.add_column(
        'club',
        sa.Column('show_leaderboards', sa.Boolean(), nullable=False, server_default=sa.true()),
    )
    op.add_column(
        'club',
        sa.Column('admins_only_posting', sa.Boolean(), nullable=False, server_default=sa.false()),
    )
    op.add_column(
        'club_member',
        sa.Column(
            'notification_level',
            sa.String(length=20),
            nullable=False,
            server_default='all',
        ),
    )
    op.add_column(
        'moments',
        sa.Column('club_id', sa.Integer(), nullable=True),
    )
    op.create_foreign_key(
        'fk_moments_club_id',
        'moments',
        'club',
        ['club_id'],
        ['id'],
        ondelete='CASCADE',
    )
    op.create_index('ix_moments_club_id', 'moments', ['club_id'])


def downgrade():
    op.drop_index('ix_moments_club_id', table_name='moments')
    op.drop_constraint('fk_moments_club_id', 'moments', type_='foreignkey')
    op.drop_column('moments', 'club_id')
    op.drop_column('club_member', 'notification_level')
    op.drop_column('club', 'admins_only_posting')
    op.drop_column('club', 'show_leaderboards')
    op.drop_column('club', 'show_activity_feed')
