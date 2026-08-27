"""add review schedule to user_words

Revision ID: e7a3c9d4f2b1
Revises: c202f959c643
Create Date: 2026-08-27 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = 'e7a3c9d4f2b1'
down_revision: Union[str, Sequence[str], None] = 'c202f959c643'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column('user_words', sa.Column('review_stage', sa.Integer(), server_default='0', nullable=False))
    op.add_column('user_words', sa.Column('next_review_at', sa.DateTime(timezone=True), nullable=True))
    op.add_column('user_words', sa.Column('mastered', sa.Boolean(), server_default='false', nullable=False))


def downgrade() -> None:
    op.drop_column('user_words', 'mastered')
    op.drop_column('user_words', 'next_review_at')
    op.drop_column('user_words', 'review_stage')