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

## CORS (Admin UI)

If you access the API from the admin UI in the browser, set `CORS_ORIGINS` to allow that origin:

```bash
export CORS_ORIGINS="http://localhost:3000"
```

You can also provide a comma-separated list or a JSON array.

## Public API

```bash
curl "http://localhost:8000/search?q=agua&lang=sw&limit=20"
curl "http://localhost:8000/lexemes/<LEXEME_ID>?lang=sw&include_drafts=true"
curl "http://localhost:8000/word-of-the-day?lang=sw"
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
