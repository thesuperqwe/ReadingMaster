"""add chapter fields to pages and quiz questions

Revision ID: a9c1b7e3f5d2
Revises: f4b8c2e9d1a7
Create Date: 2026-08-31 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = 'a9c1b7e3f5d2'
down_revision: Union[str, Sequence[str], None] = 'f4b8c2e9d1a7'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column('book_pages', sa.Column('chapter_index', sa.Integer(), nullable=True))
    op.add_column('book_pages', sa.Column('chapter_title', sa.String(length=255), nullable=True))
    op.add_column('quiz_questions', sa.Column('chapter_index', sa.Integer(), nullable=True))
    op.add_column('quiz_questions', sa.Column('chapter_title', sa.String(length=255), nullable=True))


def downgrade() -> None:
    op.drop_column('quiz_questions', 'chapter_title')
    op.drop_column('quiz_questions', 'chapter_index')
    op.drop_column('book_pages', 'chapter_title')
    op.drop_column('book_pages', 'chapter_index')