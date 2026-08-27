import uuid

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import Child
from app.schemas.child import ChildCreate


async def get_child_for_parent(
    session: AsyncSession, child_id: uuid.UUID, parent_id: uuid.UUID
) -> Child:
    child = await session.scalar(
        select(Child).where(Child.id == child_id, Child.parent_id == parent_id)
    )
    if child is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Child not found")
    return child


async def create_child(session: AsyncSession, parent_id: uuid.UUID, data: ChildCreate) -> Child:
    child = Child(
        parent_id=parent_id,
        name=data.name,
        grade=data.grade,
        reading_level=data.reading_level,
        vocabulary_size=0,
    )
    session.add(child)
    await session.commit()
    await session.refresh(child)
    return child


async def list_children(session: AsyncSession, parent_id: uuid.UUID) -> list[Child]:
    rows = await session.scalars(
        select(Child).where(Child.parent_id == parent_id).order_by(Child.created_at)
    )
    return list(rows)
