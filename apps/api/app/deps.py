"""Authentication and authorisation for /admin.

Two kinds of caller:

* **A signed-in person**, identified by a session token in the
  `Authorization: Bearer` header. Resolves to a row in `app_user`, so the
  server knows who is acting and records it.
* **A service**, identified by the shared `X-API-Key`. Convenient for scripts,
  ingestion and curl, and treated as having admin rights over content — but
  it is not a person, so it cannot act where the audit trail matters.

That distinction is the point: review decisions require a real account, so
`reviewed_by` is always a name the server established rather than a string the
client supplied.
"""
from __future__ import annotations

import uuid
from dataclasses import dataclass
from datetime import datetime, timezone

from fastapi import Depends, Header, HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.security import InvalidSession, read_session
from app.db import get_db
from app.models import AppUser

ROLE_RANK = {"reviewer": 0, "editor": 1, "admin": 2}

UNAUTHENTICATED = HTTPException(
    status_code=status.HTTP_401_UNAUTHORIZED,
    detail="Sign in or supply a valid API key",
    headers={"WWW-Authenticate": "Bearer"},
)


@dataclass(frozen=True)
class Principal:
    """Whoever is making this request."""

    role: str
    user: AppUser | None = None

    @property
    def is_person(self) -> bool:
        return self.user is not None

    @property
    def display_name(self) -> str:
        return self.user.display_name if self.user else "service"

    def can(self, role: str) -> bool:
        return ROLE_RANK[self.role] >= ROLE_RANK[role]


def _user_from_session(token: str, db: Session) -> AppUser:
    try:
        user_id, issued_at = read_session(token)
    except InvalidSession as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=str(exc),
            headers={"WWW-Authenticate": "Bearer"},
        ) from exc

    # The column is a native UUID, so the subject has to be parsed rather
    # than compared as text.
    try:
        subject = uuid.UUID(user_id)
    except (TypeError, ValueError):
        raise UNAUTHENTICATED from None

    user = db.scalar(select(AppUser).where(AppUser.id == subject))
    if not user or not user.is_active:
        raise UNAUTHENTICATED

    # Deactivating an account or changing a password moves this forward, which
    # invalidates tokens issued before it without needing a session store.
    valid_from = user.sessions_valid_from
    if valid_from.tzinfo is None:
        valid_from = valid_from.replace(tzinfo=timezone.utc)
    if issued_at < valid_from:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Session no longer valid; sign in again",
            headers={"WWW-Authenticate": "Bearer"},
        )
    return user


def current_principal(
    authorization: str | None = Header(default=None),
    x_api_key: str | None = Header(default=None),
    db: Session = Depends(get_db),
) -> Principal:
    if authorization and authorization.lower().startswith("bearer "):
        token = authorization.split(" ", 1)[1].strip()
        if token:
            user = _user_from_session(token, db)
            return Principal(role=user.role, user=user)

    expected = settings.admin_api_key or settings.api_key
    if x_api_key and expected and x_api_key == expected:
        return Principal(role="admin", user=None)

    raise UNAUTHENTICATED


def require_role(role: str):
    """Dependency requiring at least `role`."""

    def dependency(principal: Principal = Depends(current_principal)) -> Principal:
        if not principal.can(role):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"This action requires the {role} role",
            )
        return principal

    return dependency


def require_person(role: str):
    """Dependency requiring a signed-in account, not the shared API key.

    Used where the action is attributed to someone. A service credential is
    rejected even though it otherwise has admin rights, because there is no
    one to record.
    """

    def dependency(principal: Principal = Depends(current_principal)) -> Principal:
        if not principal.is_person:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=(
                    "This action is recorded against a reviewer, so it needs a "
                    "signed-in account rather than an API key"
                ),
            )
        if not principal.can(role):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"This action requires the {role} role",
            )
        return principal

    return dependency


def find_user_by_email(db: Session, email: str) -> AppUser | None:
    return db.scalar(select(AppUser).where(func.lower(AppUser.email) == email.strip().lower()))


def touch_last_login(db: Session, user: AppUser) -> None:
    user.last_login_at = datetime.now(timezone.utc)
    db.commit()


# Kept so existing callers and scripts keep working; equivalent to requiring
# admin rights by any means (session or API key).
require_api_key = require_role("admin")
