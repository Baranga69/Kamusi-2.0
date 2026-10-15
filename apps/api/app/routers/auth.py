"""Sign-in and account management."""
from __future__ import annotations

import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, Query, status
from fastapi.responses import Response
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.security import (
    hash_password,
    issue_session,
    needs_rehash,
    password_problem,
    verify_password,
)
from app.db import get_db
from app.deps import Principal, current_principal, find_user_by_email, require_role
from app.models import USER_ROLES, AppUser
from app.schemas import (
    LoginRequest,
    LoginResponse,
    PasswordChange,
    PasswordReset,
    UserCreate,
    UserPublic,
    UserUpdate,
)

router = APIRouter(prefix="/auth", tags=["auth"])
users_router = APIRouter(
    prefix="/admin/users",
    tags=["users"],
    dependencies=[Depends(require_role("admin"))],
)

INVALID_CREDENTIALS = HTTPException(
    status_code=status.HTTP_401_UNAUTHORIZED,
    detail="Incorrect email or password",
)


def to_public(user: AppUser) -> UserPublic:
    return UserPublic(
        id=user.id,
        email=user.email,
        display_name=user.display_name,
        role=user.role,
        is_active=user.is_active,
        created_at=user.created_at,
        last_login_at=user.last_login_at,
    )


def load_user(db: Session, user_id: str) -> AppUser:
    try:
        key = uuid.UUID(user_id)
    except (TypeError, ValueError):
        raise HTTPException(status_code=404, detail="User not found") from None
    user = db.scalar(select(AppUser).where(AppUser.id == key))
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return user


def validate_role(role: str) -> str:
    if role not in USER_ROLES:
        raise HTTPException(
            status_code=400, detail=f"Role must be one of {', '.join(USER_ROLES)}"
        )
    return role


def validate_password(password: str) -> str:
    problem = password_problem(password)
    if problem:
        raise HTTPException(status_code=422, detail=problem)
    return password


@router.post("/login", response_model=LoginResponse)
def login(payload: LoginRequest, db: Session = Depends(get_db)) -> LoginResponse:
    user = find_user_by_email(db, payload.email)

    # Same error and roughly the same work whether the address is unknown or
    # the password is wrong, so the response does not reveal which.
    if not user:
        verify_password(payload.password, hash_password("placeholder-for-timing"))
        raise INVALID_CREDENTIALS
    if not verify_password(payload.password, user.password_hash):
        raise INVALID_CREDENTIALS
    if not user.is_active:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Account is disabled")

    # Transparently upgrade the stored hash when argon2's parameters change.
    if needs_rehash(user.password_hash):
        user.password_hash = hash_password(payload.password)

    user.last_login_at = datetime.now(timezone.utc)
    db.commit()

    return LoginResponse(
        token=issue_session(user.id),
        expires_in_seconds=settings.session_max_age_seconds,
        user=to_public(user),
    )


@router.get("/me", response_model=UserPublic)
def me(principal: Principal = Depends(current_principal)) -> UserPublic:
    if not principal.is_person:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="An API key is not an account; sign in to read /auth/me",
        )
    return to_public(principal.user)


# response_model=None is required because `from __future__ import annotations`
# makes FastAPI resolve the `-> None` return annotation to NoneType, which it
# would otherwise treat as a body on a 204.
@router.post(
    "/password",
    status_code=status.HTTP_204_NO_CONTENT,
    response_class=Response,
    response_model=None,
)
def change_own_password(
    payload: PasswordChange,
    principal: Principal = Depends(current_principal),
    db: Session = Depends(get_db),
) -> None:
    if not principal.is_person:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN, detail="An API key has no password"
        )
    user = db.scalar(select(AppUser).where(AppUser.id == principal.user.id))
    if not user or not verify_password(payload.current_password, user.password_hash):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Current password is incorrect")

    validate_password(payload.new_password)
    user.password_hash = hash_password(payload.new_password)
    # Ends every existing session, including any an attacker still holds.
    user.sessions_valid_from = datetime.now(timezone.utc)
    db.commit()


@users_router.get("", response_model=list[UserPublic])
def list_users(
    include_inactive: bool = Query(True),
    db: Session = Depends(get_db),
) -> list[UserPublic]:
    stmt = select(AppUser).order_by(func.lower(AppUser.email))
    if not include_inactive:
        stmt = stmt.where(AppUser.is_active.is_(True))
    return [to_public(user) for user in db.scalars(stmt).all()]


@users_router.post("", response_model=UserPublic, status_code=status.HTTP_201_CREATED)
def create_user(payload: UserCreate, db: Session = Depends(get_db)) -> UserPublic:
    validate_role(payload.role)
    validate_password(payload.password)

    email = payload.email.strip()
    if not email or "@" not in email:
        raise HTTPException(status_code=422, detail="A valid email address is required")
    if not payload.display_name.strip():
        raise HTTPException(status_code=422, detail="Display name is required")

    user = AppUser(
        email=email,
        display_name=payload.display_name.strip(),
        password_hash=hash_password(payload.password),
        role=payload.role,
    )
    db.add(user)
    try:
        db.commit()
    except IntegrityError as exc:
        db.rollback()
        raise HTTPException(status_code=409, detail="That email address is already registered") from exc
    db.refresh(user)
    return to_public(user)


@users_router.get("/{user_id}", response_model=UserPublic)
def get_user(user_id: str, db: Session = Depends(get_db)) -> UserPublic:
    return to_public(load_user(db, user_id))


@users_router.put("/{user_id}", response_model=UserPublic)
def update_user(
    user_id: str,
    payload: UserUpdate,
    principal: Principal = Depends(current_principal),
    db: Session = Depends(get_db),
) -> UserPublic:
    user = load_user(db, user_id)

    # Guard against an admin locking themselves out, which would leave the
    # console unreachable if they were the only one.
    acting_on_self = principal.is_person and principal.user.id == user.id
    if acting_on_self and payload.is_active is False:
        raise HTTPException(status_code=400, detail="You cannot disable your own account")
    if acting_on_self and payload.role is not None and payload.role != "admin":
        raise HTTPException(status_code=400, detail="You cannot remove your own admin role")

    if payload.display_name is not None:
        if not payload.display_name.strip():
            raise HTTPException(status_code=422, detail="Display name cannot be empty")
        user.display_name = payload.display_name.strip()
    if payload.role is not None:
        user.role = validate_role(payload.role)
    if payload.is_active is not None:
        user.is_active = payload.is_active
        if not payload.is_active:
            # Revoke outstanding sessions immediately.
            user.sessions_valid_from = datetime.now(timezone.utc)

    db.commit()
    db.refresh(user)
    return to_public(user)


@users_router.post(
    "/{user_id}/password",
    status_code=status.HTTP_204_NO_CONTENT,
    response_class=Response,
    response_model=None,
)
def reset_user_password(
    user_id: str, payload: PasswordReset, db: Session = Depends(get_db)
) -> None:
    user = load_user(db, user_id)
    validate_password(payload.new_password)
    user.password_hash = hash_password(payload.new_password)
    user.sessions_valid_from = datetime.now(timezone.utc)
    db.commit()
