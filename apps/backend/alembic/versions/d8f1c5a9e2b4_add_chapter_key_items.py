"""add key items cache to chapters

Revision ID: d8f1c5a9e2b4
Revises: c4d9e2a8f6b3
Create Date: 2026-09-01 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = 'd8f1c5a9e2b4'
down_revision: Union[str, Sequence[str], None] = 'c4d9e2a8f6b3'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column('chapters', sa.Column('key_items', sa.JSON(), nullable=True))


def downgrade() -> None:
    op.drop_column('chapters', 'key_items')