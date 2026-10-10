"""Password hashing and session tokens.

Sessions are signed, not stored. A token carries the user id and its issue
time; `app_user.sessions_valid_from` is the revocation point, so deactivating
an account or changing a password ends existing sessions without a session
table to sweep.
"""
from __future__ import annotations

from datetime import datetime, timezone

from argon2 import PasswordHasher
from argon2.exceptions import InvalidHashError, VerificationError, VerifyMismatchError
from itsdangerous import BadSignature, SignatureExpired, URLSafeTimedSerializer

from app.core.config import settings

SESSION_SALT = "kamusi-admin-session"
MIN_PASSWORD_LENGTH = 12

_hasher = PasswordHasher()


class InvalidSession(Exception):
    """The token is missing, malformed, expired or signed with another key."""


def hash_password(password: str) -> str:
    return _hasher.hash(password)


def verify_password(password: str, password_hash: str) -> bool:
    try:
        _hasher.verify(password_hash, password)
    except (VerifyMismatchError, VerificationError, InvalidHashError):
        return False
    return True


def needs_rehash(password_hash: str) -> bool:
    """True when the hash predates the current argon2 parameters."""
    try:
        return _hasher.check_needs_rehash(password_hash)
    except InvalidHashError:
        return False


def password_problem(password: str) -> str | None:
    """Return why a password is unacceptable, or None if it is fine.

    Deliberately a length floor rather than a character-class rule: length is
    what actually resists guessing, and composition rules push people toward
    predictable substitutions.
    """
    if len(password) < MIN_PASSWORD_LENGTH:
        return f"Password must be at least {MIN_PASSWORD_LENGTH} characters"
    return None


def _serializer() -> URLSafeTimedSerializer:
    return URLSafeTimedSerializer(settings.session_secret, salt=SESSION_SALT)


def issue_session(user_id, issued_at: datetime | None = None) -> str:
    issued_at = issued_at or datetime.now(timezone.utc)
    return _serializer().dumps({"sub": str(user_id), "iat": issued_at.isoformat()})


def read_session(token: str) -> tuple[str, datetime]:
    """Return (user_id, issued_at) or raise InvalidSession."""
    try:
        payload = _serializer().loads(token, max_age=settings.session_max_age_seconds)
    except SignatureExpired as exc:
        raise InvalidSession("Session expired") from exc
    except BadSignature as exc:
        raise InvalidSession("Invalid session") from exc

    if not isinstance(payload, dict) or "sub" not in payload or "iat" not in payload:
        raise InvalidSession("Malformed session")

    try:
        issued_at = datetime.fromisoformat(payload["iat"])
    except (TypeError, ValueError) as exc:
        raise InvalidSession("Malformed session") from exc

    if issued_at.tzinfo is None:
        issued_at = issued_at.replace(tzinfo=timezone.utc)
    return payload["sub"], issued_at
