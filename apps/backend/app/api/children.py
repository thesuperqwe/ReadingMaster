import uuid
from typing import Annotated

from fastapi import APIRouter, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user
from app.db.session import get_session
from app.schemas.child import ChildCreate, ChildOut
from app.services.child_service import create_child as create_child_service, list_children

router = APIRouter(prefix="/children", tags=["children"])


@router.post("", response_model=ChildOut, status_code=status.HTTP_201_CREATED)
async def create_child(
    session: Annotated[AsyncSession, Depends(get_session)],
    user: Annotated[uuid.UUID, Depends(get_current_user)],
    data: ChildCreate,
) -> ChildOut:
    child = await create_child_service(session, user, data)
    return ChildOut.model_validate(child)


@router.get("", response_model=list[ChildOut])
async def get_children(
    session: Annotated[AsyncSession, Depends(get_session)],
    user: Annotated[uuid.UUID, Depends(get_current_user)],
) -> list[ChildOut]:
    children = await list_children(session, user)
    return [ChildOut.model_validate(child) for child in children]
