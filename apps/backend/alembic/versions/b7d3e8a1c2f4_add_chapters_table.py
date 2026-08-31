"""add chapters table

Revision ID: b7d3e8a1c2f4
Revises: a9c1b7e3f5d2
Create Date: 2026-08-31 00:00:00.000000

"""
import uuid
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = 'b7d3e8a1c2f4'
down_revision: Union[str, Sequence[str], None] = 'a9c1b7e3f5d2'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        'chapters',
        sa.Column('id', sa.Uuid(), nullable=False),
        sa.Column('book_id', sa.Uuid(), nullable=False),
        sa.Column('index', sa.Integer(), nullable=False),
        sa.Column('title', sa.String(length=255), nullable=False),
        sa.Column('word_count', sa.Integer(), server_default='0', nullable=False),
        sa.Column('segment_count', sa.Integer(), server_default='0', nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.ForeignKeyConstraint(['book_id'], ['books.id'], name=op.f('fk_chapters_book_id_books'), ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id', name=op.f('pk_chapters')),
        sa.UniqueConstraint('book_id', 'index', name=op.f('uq_chapters_book_id')),
    )
    op.create_index(op.f('ix_chapters_book_id'), 'chapters', ['book_id'], unique=False)

    bind = op.get_bind()
    rows = bind.execute(
        sa.text(
            """
            SELECT book_id,
                   COALESCE(chapter_index, 0) AS chapter_index,
                   COALESCE(chapter_title, '前言') AS chapter_title,
                   COUNT(*) AS segment_count,
                   SUM(cardinality(string_to_array(btrim(content), ' '))) AS word_count
            FROM book_pages
            GROUP BY book_id, COALESCE(chapter_index, 0), COALESCE(chapter_title, '前言')
            """
        )
    ).fetchall()

    for row in rows:
        bind.execute(
            sa.text(
                """
                INSERT INTO chapters (id, book_id, index, title, word_count, segment_count, created_at)
                VALUES (:id, :book_id, :index, :title, :word_count, :segment_count, now())
                """
            ),
            {
                "id": uuid.uuid4(),
                "book_id": row[0],
                "index": row[1],
                "title": row[2],
                "word_count": int(row[4] or 0),
                "segment_count": int(row[3]),
            },
        )


def downgrade() -> None:
    op.drop_index(op.f('ix_chapters_book_id'), table_name='chapters')
    op.drop_table('chapters')