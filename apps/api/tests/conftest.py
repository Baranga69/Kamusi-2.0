"""Test fixtures.

The suite runs against in-memory SQLite by default, so `pytest` needs no
services. Set ``TEST_DATABASE_URL`` to run the same tests against a real
Postgres instead, which is what CI does: SQLite cannot exercise anything
dialect-specific (trigram similarity, ``ON CONFLICT`` behaviour, native
enums), and the schema there is built by running the Alembic migrations, so
a broken migration fails the suite rather than only showing up on deploy.

    TEST_DATABASE_URL=postgresql+psycopg://kamusi@127.0.0.1:5433/kamusi_test \
        poetry run pytest

Tests that need Postgres-only behaviour are marked ``@pytest.mark.postgres``
and skip automatically on SQLite.
"""
import os
import uuid
from pathlib import Path

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, text
from sqlalchemy.orm import Session
from sqlalchemy.pool import StaticPool

from app.core.config import settings
from app.db import Base, get_db
from app.main import app

TEST_API_KEY = "dev-api-key"
TEST_DATABASE_URL = os.getenv("TEST_DATABASE_URL")
SQLITE_URL = "sqlite+pysqlite:///:memory:"


def pytest_configure(config: pytest.Config) -> None:
    config.addinivalue_line(
        "markers", "postgres: requires a real Postgres (skipped on SQLite)"
    )


@pytest.fixture(scope="session")
def is_postgres() -> bool:
    return bool(TEST_DATABASE_URL)


@pytest.fixture(autouse=True)
def _skip_postgres_only(request: pytest.FixtureRequest) -> None:
    if request.node.get_closest_marker("postgres") and not TEST_DATABASE_URL:
        pytest.skip("needs Postgres; set TEST_DATABASE_URL to run")


@pytest.fixture(autouse=True)
def test_api_key() -> str:
    """Pin the admin key so tests do not depend on a developer's local .env."""
    previous = (settings.api_key, settings.admin_api_key)
    settings.api_key = TEST_API_KEY
    settings.admin_api_key = TEST_API_KEY
    yield TEST_API_KEY
    settings.api_key, settings.admin_api_key = previous


def _migrate(url: str) -> None:
    """Build the schema the way production does, by running the migrations."""
    from alembic import command
    from alembic.config import Config

    # migrations/env.py reads settings.database_url, so point it at the test
    # database before Alembic loads it.
    previous = settings.database_url
    settings.database_url = url
    try:
        config = Config(str(Path(__file__).resolve().parents[1] / "alembic.ini"))
        config.set_main_option("sqlalchemy.url", url)
        command.upgrade(config, "head")
    finally:
        settings.database_url = previous


@pytest.fixture(scope="session")
def postgres_engine():
    """Session-scoped Postgres engine with the migrated schema."""
    engine = create_engine(TEST_DATABASE_URL)
    with engine.begin() as connection:
        # Start from a known-empty database so a previous aborted run cannot
        # leave the schema half-built.
        connection.execute(text("DROP SCHEMA public CASCADE"))
        connection.execute(text("CREATE SCHEMA public"))
    _migrate(TEST_DATABASE_URL)
    yield engine
    engine.dispose()


@pytest.fixture()
def db_session(request: pytest.FixtureRequest) -> Session:
    """An isolated session per test.

    On Postgres the schema is expensive to rebuild, so each test runs inside
    an outer transaction that is rolled back afterwards; the session joins it
    via savepoints, so a `commit()` in the code under test is durable for the
    rest of that test and discarded after it.

    On SQLite each test gets its own in-memory database instead. Savepoints
    are not a reliable isolation boundary under pysqlite, and building the
    schema from metadata is cheap.
    """
    if TEST_DATABASE_URL:
        engine = request.getfixturevalue("postgres_engine")
        connection = engine.connect()
        transaction = connection.begin()
        session = Session(bind=connection, join_transaction_mode="create_savepoint")
        try:
            yield session
        finally:
            session.close()
            transaction.rollback()
            connection.close()
        return

    # StaticPool keeps every connection pointed at the same in-memory
    # database. Without it, sync endpoints run on Starlette's threadpool and
    # would each open a fresh, empty SQLite database.
    engine = create_engine(
        SQLITE_URL,
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    # The models declare native enums with create_type=False, which only
    # Alembic creates, so SQLite builds the schema from the metadata (it
    # renders enums as VARCHAR + CHECK).
    Base.metadata.create_all(engine)
    session = Session(bind=engine, autoflush=False)
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
