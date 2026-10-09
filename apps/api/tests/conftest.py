import uuid

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.core.config import settings
from app.db import Base, get_db
from app.main import app

TEST_API_KEY = "dev-api-key"


@pytest.fixture(autouse=True)
def test_api_key() -> str:
    """Pin the admin key so tests do not depend on a developer's local .env."""
    previous = (settings.api_key, settings.admin_api_key)
    settings.api_key = TEST_API_KEY
    settings.admin_api_key = TEST_API_KEY
    yield TEST_API_KEY
    settings.api_key, settings.admin_api_key = previous


@pytest.fixture()
def db_session() -> Session:
    # StaticPool keeps every connection pointed at the same in-memory database.
    # Without it, sync endpoints run on Starlette's threadpool and would each
    # open a fresh, empty SQLite database.
    engine = create_engine(
        "sqlite+pysqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    TestingSessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False)
    session = TestingSessionLocal()
    try:
        yield session
    finally:
        session.close()
        engine.dispose()


@pytest.fixture()
def client(db_session: Session) -> TestClient:
    def override_get_db():
        yield db_session

    app.dependency_overrides[get_db] = override_get_db
    with TestClient(app) as test_client:
        yield test_client
    app.dependency_overrides.clear()


def make_uuid() -> str:
    return str(uuid.uuid4())
