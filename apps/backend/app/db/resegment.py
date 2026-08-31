import asyncio

from sqlalchemy import select

from app.db.session import async_session_factory
from app.models import Book
from app.services.book_service import resegment_book


async def resegment_all() -> int:
    async with async_session_factory() as session:
        book_ids = list(await session.scalars(select(Book.id)))
        for book_id in book_ids:
            await resegment_book(session, book_id)
        return len(book_ids)


def main() -> None:
    count = asyncio.run(resegment_all())
    print(f"Resegmented {count} books.")


if __name__ == "__main__":
    main()