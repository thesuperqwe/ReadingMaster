"""add last activity timestamp to reading sessions

Revision ID: f4b8c2e9d1a7
Revises: e7a3c9d4f2b1
Create Date: 2026-08-31 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = 'f4b8c2e9d1a7'
down_revision: Union[str, Sequence[str], None] = 'e7a3c9d4f2b1'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column('reading_sessions', sa.Column('last_activity_at', sa.DateTime(timezone=True), nullable=True))


def downgrade() -> None:
    op.drop_column('reading_sessions', 'last_activity_at')