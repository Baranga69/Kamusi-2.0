"""Path-parameter id handling.

Primary keys are native `uuid` columns. Postgres adapts a string to uuid on
the way in, so comparing a path parameter directly happens to work there, but
SQLite does not — and a malformed id should be a 404 rather than whatever the
driver raises. Parsing explicitly makes both true.
"""
from __future__ import annotations

import uuid

from fastapi import HTTPException


def as_uuid(value: str, detail: str = "Not found") -> uuid.UUID:
    try:
        return uuid.UUID(str(value))
    except (TypeError, ValueError):
        raise HTTPException(status_code=404, detail=detail) from None
