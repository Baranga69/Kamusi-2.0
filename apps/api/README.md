# Kamusi API

## Setup

```bash
cd apps/api
poetry install
```

## Run API

```bash
cd apps/api
poetry run uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

## Database

Start Postgres at repo root:

```bash
docker compose up -d postgres
```

Run migrations:

```bash
cd apps/api
poetry run alembic upgrade head
```

Seed lookup tables:

```bash
cd apps/api
poetry run python scripts/seed.py
```

## Tests

```bash
cd apps/api
poetry run pytest
```
