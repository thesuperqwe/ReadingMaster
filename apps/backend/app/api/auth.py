from fastapi import APIRouter, status

from app.api.deps import SessionDep
from app.schemas.auth import LoginRequest, RegisterRequest, TokenResponse, UserOut
from app.services.auth_service import login_user, register_user

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/register", response_model=TokenResponse, status_code=status.HTTP_201_CREATED)
async def register(session: SessionDep, data: RegisterRequest) -> TokenResponse:
    user, access_token = await register_user(session, data)
    return TokenResponse(access_token=access_token, user=UserOut.model_validate(user))


@router.post("/login", response_model=TokenResponse)
async def login(session: SessionDep, data: LoginRequest) -> TokenResponse:
    user, access_token = await login_user(session, data)
    return TokenResponse(access_token=access_token, user=UserOut.model_validate(user))
