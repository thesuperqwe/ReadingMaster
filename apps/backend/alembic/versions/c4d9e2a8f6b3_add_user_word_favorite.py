"""add favorite flag to user words

Revision ID: c4d9e2a8f6b3
Revises: b7d3e8a1c2f4
Create Date: 2026-08-31 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = 'c4d9e2a8f6b3'
down_revision: Union[str, Sequence[str], None] = 'b7d3e8a1c2f4'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column('user_words', sa.Column('favorite', sa.Boolean(), server_default='false', nullable=False))


def downgrade() -> None:
    op.drop_column('user_words', 'favorite')