import uuid

from fastapi import APIRouter

from app.api.deps import CurrentUser, SessionDep
from app.schemas.stats import ParentStatsResponse
from app.services.child_service import get_child_for_parent
from app.services.stats_service import build_parent_stats

router = APIRouter(prefix="/children", tags=["stats"])


@router.get("/{child_id}/stats", response_model=ParentStatsResponse)
async def get_parent_stats(
    session: SessionDep,
    user: CurrentUser,
    child_id: uuid.UUID,
) -> ParentStatsResponse:
    child = await get_child_for_parent(session, child_id, user)
    return await build_parent_stats(session, child)