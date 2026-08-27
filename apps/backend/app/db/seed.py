import asyncio

from sqlalchemy import select

from app.db.session import async_session_factory
from app.models import Book, BookPage, BookWord, Child, QuizOption, QuizQuestion, User, Word


async def seed() -> None:
    async with async_session_factory() as session:
        existing_user = await session.scalar(select(User).where(User.email == "test@example.com"))
        if existing_user is not None:
            print("Seed data already exists; skipping.")
            return

        parent = User(
            email="test@example.com",
            password_hash="dev-only-password-hash",
            role="parent",
        )
        child = Child(name="小明", grade=3, reading_level="LEVEL_2", parent=parent)
        session.add_all([parent, child])
        await session.flush()

        book = Book(
            title="The Little Dog",
            description="A simple story about Tom and his dog.",
            level="LEVEL_2",
            estimated_minutes=8,
            word_count=32,
            category="animals",
            status="PUBLISHED",
        )
        pages = [
            BookPage(page_no=1, content="Tom has a little dog.", book=book),
            BookPage(page_no=2, content="The dog is very cute.", book=book),
            BookPage(page_no=3, content="Tom likes to play with his dog.", book=book),
        ]
        session.add_all([book, *pages])
        await session.flush()

        word_rows = {
            "little": Word(
                word="little",
                phonetic="/ˈlɪtl/",
                meaning_zh="小的",
                simple_definition="small in size",
                example_sentence="Tom has a little dog.",
                example_translation="汤姆有一只小狗。",
                part_of_speech="adjective",
            ),
            "dog": Word(
                word="dog",
                phonetic="/dɔːɡ/",
                meaning_zh="狗",
                simple_definition="a friendly animal that people keep as a pet",
                example_sentence="The dog is very cute.",
                example_translation="这只狗非常可爱。",
                part_of_speech="noun",
            ),
            "cute": Word(
                word="cute",
                phonetic="/kjuːt/",
                meaning_zh="可爱的",
                simple_definition="nice and lovely",
                example_sentence="The dog is very cute.",
                example_translation="这只狗非常可爱。",
                part_of_speech="adjective",
            ),
            "play": Word(
                word="play",
                phonetic="/pleɪ/",
                meaning_zh="玩",
                simple_definition="to do things for fun",
                example_sentence="Tom likes to play with his dog.",
                example_translation="汤姆喜欢和他的狗玩。",
                part_of_speech="verb",
            ),
        }
        session.add_all(word_rows.values())
        await session.flush()

        session.add_all(
            [
                BookWord(book_id=book.id, word_id=word_rows["little"].id, is_key_word=True),
                BookWord(book_id=book.id, word_id=word_rows["dog"].id, is_key_word=True),
                BookWord(book_id=book.id, word_id=word_rows["cute"].id, is_key_word=True),
                BookWord(book_id=book.id, word_id=word_rows["play"].id, is_key_word=True),
            ]
        )

        quiz_questions = [
            QuizQuestion(
                question="What does Tom have?",
                question_type="single_choice",
                correct_option="A",
                book=book,
                options=[
                    QuizOption(option_key="A", content="A dog"),
                    QuizOption(option_key="B", content="A cat"),
                    QuizOption(option_key="C", content="A rabbit"),
                ],
            ),
            QuizQuestion(
                question="How is the dog?",
                question_type="single_choice",
                correct_option="B",
                book=book,
                options=[
                    QuizOption(option_key="A", content="Ugly"),
                    QuizOption(option_key="B", content="Cute"),
                    QuizOption(option_key="C", content="Big"),
                ],
            ),
            QuizQuestion(
                question="What does Tom like to do?",
                question_type="single_choice",
                correct_option="A",
                book=book,
                options=[
                    QuizOption(option_key="A", content="Play with his dog"),
                    QuizOption(option_key="B", content="Eat lunch"),
                    QuizOption(option_key="C", content="Go to school"),
                ],
            ),
        ]
        session.add_all(quiz_questions)

        await session.commit()
        print("Seed data created.")
        print("Parent login: test@example.com")


def main() -> None:
    asyncio.run(seed())


if __name__ == "__main__":
    main()
