from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import create_access_token, hash_password, verify_password
from app.models import User
from app.schemas.auth import LoginRequest, RegisterRequest


async def register_user(session: AsyncSession, data: RegisterRequest) -> tuple[User, str]:
    email = str(data.email)
    existing = await session.scalar(select(User).where(User.email == email))
    if existing is not None:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Email already registered")

    user = User(email=email, password_hash=hash_password(data.password), role="parent")
    session.add(user)
    await session.commit()
    await session.refresh(user)

    return user, create_access_token(str(user.id))


async def login_user(session: AsyncSession, data: LoginRequest) -> tuple[User, str]:
    email = str(data.email)
    user = await session.scalar(select(User).where(User.email == email))
    if user is None or not verify_password(data.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
        )

    return user, create_access_token(str(user.id))
