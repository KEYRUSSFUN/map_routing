"""Add id column to Friendship

Revision ID: 20bfa948e72d
Revises: 
Create Date: 2025-06-22 00:11:08.727097

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = '20bfa948e72d'
down_revision = None
branch_labels = None
depends_on = None


def upgrade():
    # ### commands auto generated by Alembic - please adjust! ###
    op.drop_table('geolocation')
    # ### end Alembic commands ###


def downgrade():
    # ### commands auto generated by Alembic - please adjust! ###
    op.create_table('geolocation',
    sa.Column('id_Geolocation', sa.INTEGER(), nullable=False),
    sa.Column('id_User', sa.INTEGER(), nullable=True),
    sa.Column('point1', sa.NUMERIC(), nullable=True),
    sa.Column('point2', sa.NUMERIC(), nullable=True),
    sa.Column('distance', sa.FLOAT(), nullable=False),
    sa.ForeignKeyConstraint(['id_User'], ['user_info.id_User'], ),
    sa.PrimaryKeyConstraint('id_Geolocation')
    )
    # ### end Alembic commands ###
