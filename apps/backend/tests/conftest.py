import asyncio
import os

import asyncpg
import pytest
from fastapi.testclient import TestClient
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine
from sqlalchemy.pool import NullPool

import app.models  # noqa: F401
from app.db.base import Base
from app.db.session import get_session
from app.main import app

TEST_DB_NAME = "readingmaster_test"
TEST_DATABASE_URL = os.getenv(
    "TEST_DATABASE_URL",
    f"postgresql+asyncpg://readingmaster:readingmaster_dev@localhost:5432/{TEST_DB_NAME}",
)
ADMIN_DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql+asyncpg://readingmaster:readingmaster_dev@localhost:5432/readingmaster",
).replace("postgresql+asyncpg://", "postgresql://")


async def _create_test_database() -> None:
    connection = await asyncpg.connect(ADMIN_DATABASE_URL)
    exists = await connection.fetchval(
        "SELECT 1 FROM pg_database WHERE datname = $1", TEST_DB_NAME
    )
    if not exists:
        await connection.execute(f'CREATE DATABASE "{TEST_DB_NAME}"')
    await connection.close()


asyncio.run(_create_test_database())

test_engine = create_async_engine(TEST_DATABASE_URL, poolclass=NullPool)
TestSession = async_sessionmaker(test_engine, expire_on_commit=False)


async def override_get_session():
    async with TestSession() as session:
        yield session


app.dependency_overrides[get_session] = override_get_session


async def _reset_database() -> None:
    async with test_engine.begin() as connection:
        await connection.run_sync(Base.metadata.drop_all)
        await connection.run_sync(Base.metadata.create_all)


@pytest.fixture(autouse=True)
def reset_database():
    asyncio.run(_reset_database())
    yield
    asyncio.run(_reset_database())


@pytest.fixture
def client():
    with TestClient(app) as test_client:
        yield test_client


async def seed_test_content() -> dict:
    from app.models import Book, BookPage, BookWord, Chapter, QuizOption, QuizQuestion, Word

    async with TestSession() as session:
        book = Book(
            title="The Little Dog",
            description="A simple story about Tom and his dog.",
            level="LEVEL_2",
            estimated_minutes=8,
            word_count=32,
            category="animals",
            status="PUBLISHED",
        )
        session.add(book)
        await session.flush()

        chapter = Chapter(book_id=book.id, index=0, title="正文", word_count=17, segment_count=3)
        pages = [
            BookPage(page_no=1, content="Tom has a little dog.", book_id=book.id, chapter_index=0, chapter_title="正文"),
            BookPage(page_no=2, content="The dog is very cute.", book_id=book.id, chapter_index=0, chapter_title="正文"),
            BookPage(page_no=3, content="Tom likes to play with his dog.", book_id=book.id, chapter_index=0, chapter_title="正文"),
        ]
        session.add_all([chapter, *pages])

        word_rows = {}
        for text, meaning in (
            ("little", "小的"),
            ("dog", "狗"),
            ("cute", "可爱的"),
            ("play", "玩"),
        ):
            word = Word(word=text, meaning_zh=meaning)
            session.add(word)
            await session.flush()
            word_rows[text] = word

        session.add_all(
            [
                BookWord(book_id=book.id, word_id=word_rows["little"].id, is_key_word=True),
                BookWord(book_id=book.id, word_id=word_rows["dog"].id, is_key_word=True),
                BookWord(book_id=book.id, word_id=word_rows["cute"].id, is_key_word=True),
                BookWord(book_id=book.id, word_id=word_rows["play"].id, is_key_word=True),
            ]
        )

        question = QuizQuestion(
            book_id=book.id,
            question="What does Tom have?",
            question_type="single_choice",
            correct_option="A",
        )
        session.add(question)
        await session.flush()
        session.add_all(
            [
                QuizOption(question_id=question.id, option_key="A", content="A dog"),
                QuizOption(question_id=question.id, option_key="B", content="A cat"),
                QuizOption(question_id=question.id, option_key="C", content="A rabbit"),
            ]
        )

        await session.commit()
        return {
            "book_id": str(book.id),
            "question_id": str(question.id),
        }

@pytest.fixture
def seed_content():
    return seed_test_content