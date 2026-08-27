import uuid

from fastapi import APIRouter, Query

from app.api.deps import CurrentUser, SessionDep
from app.schemas.home import HomeResponse
from app.services.home_service import build_home

router = APIRouter(prefix="/home", tags=["home"])


@router.get("", response_model=HomeResponse)
async def get_home(
    session: SessionDep,
    user: CurrentUser,
    child_id: uuid.UUID = Query(...),
) -> HomeResponse:
    return await build_home(session, user, child_id)
