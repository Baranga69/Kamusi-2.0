# Kamusi Monorepo

Kamusi is a monorepo that houses the API, admin dashboard, mobile app, and shared contracts.
This repository is scaffolding-only for now (no business logic or real endpoints).

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

The OpenAPI spec lives in `packages/contracts/openapi.yaml`.

```bash
pnpm --filter @kamusi/contracts gen:ts
pnpm --filter @kamusi/contracts gen:dart
```

## Environment variables

- `apps/api/.env.example` for API settings
- `apps/admin/.env.example` for Admin settings

