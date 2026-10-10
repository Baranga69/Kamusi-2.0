# Kamusi Monorepo

Kamusi is a monorepo that houses the API, admin dashboard, mobile app, and shared contracts.

- `apps/api` — FastAPI backend (public read APIs + admin review pipeline)
- `apps/admin` — Next.js review and editorial console
- `apps/mobile` — Flutter dictionary app
- `packages/contracts` — OpenAPI spec, generated from the API

See `ARCHITECTURE.md` for how the pieces fit, `KAMUSI_STATE.md` for current
status, and `DESIGN_SYSTEM.md` for the visual contract.

## Prerequisites

- **Node.js** 20+ with **pnpm** 8+
- **Python** 3.11+
- **Poetry** 1.6+
- **Flutter** 3.16+
- **Docker** + **Docker Compose**

## Quickstart

```bash
pnpm install
make up
make api
```

In another terminal:

```bash
make admin
```

Optional (mobile):

```bash
make mobile
```

## Running services independently

### Postgres

```bash
make up
```

### API (FastAPI)

```bash
make api
```

The health endpoint is available at `http://localhost:8000/health`.

### Admin (Next.js)

```bash
make admin
```

### Mobile (Flutter)

```bash
make mobile
```

## Full dev stack (Postgres + API + Admin)

```bash
make dev
```

## Contracts

`packages/contracts/openapi.yaml` is generated from the FastAPI app, not written
by hand. Regenerate it in the same commit as any route or schema change:

```bash
cd apps/api && poetry run python scripts/export_openapi.py
```

Then generate clients from it:

```bash
pnpm --filter @kamusi/contracts gen:ts
pnpm --filter @kamusi/contracts gen:dart
```

## Tests and checks

```bash
cd apps/api && poetry run pytest
pnpm --filter @kamusi/admin test
cd apps/mobile && flutter analyze
```

CI runs all three on push and pull request (`.github/workflows/ci.yml`).

## Environment variables

Copy the templates and fill them in; `.env` files are gitignored and must never
be committed.

- `apps/api/.env.example` for API settings
- `apps/admin/.env.example` for Admin settings

