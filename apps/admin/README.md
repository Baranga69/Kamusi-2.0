# Kamusi Admin

Internal admin console for managing lexemes, expressions, tags, sources, and licenses.

## Setup

1. Create a local environment file:

```bash
cp .env.example .env.local   # then fill in
```

Required env vars:

- `KAMUSI_API_BASE_URL`: Base URL for the Kamusi API (admin routes use `X-API-Key`).
- `NEXT_PUBLIC_API_BASE_URL`: Optional fallback if `KAMUSI_API_BASE_URL` is not set.
- `ADMIN_API_KEY`: Server-side API key used by the `/api/review` proxy routes.
- `PROD_ADMIN_API_KEY`: Optional fallback for a deployed API.

2. Install dependencies from the repo root:

```bash
pnpm install
```

3. Make sure the API is running and its lookup tables are seeded
   (`poetry run python scripts/seed.py` in `apps/api`). Tag types, parts of
   speech and expression types come from `/admin/lookups`; without them the
   create forms have nothing to select.

4. Start the admin app:

```bash
pnpm --filter @kamusi/admin dev
```

## Usage

- Visit `http://localhost:3000`.
- Store your API key on the Login page. The app sends it in the `X-API-Key` header.
- Use the left navigation to manage lexemes, expressions, tags, sources, and licenses.
- Review queue supports approving, editing, and rejecting AI Swahili definitions with filters, select-all, and keyboard shortcuts.
- Click a lemma in the review queue to open the detail view with diff preview and audit metadata.
- Publishing enforces readiness checks (lemma length, POS, Swahili definitions per sense, reviewed workflow state).
- The Publish action calls the backend `/admin/lexemes/{id}/publish` endpoint to update workflow status and search entries.

## How requests reach the API

Two paths, deliberately:

- **Review actions** go through Next server routes under `app/api/review/*`,
  which inject `ADMIN_API_KEY` server-side. The key never reaches the browser.
- **Everything else** calls the API directly from the browser with the key the
  user pasted on the Login page, held in `localStorage`.

The second path means any browser-side admin action is only as protected as
that pasted key. Treat the console as an internal tool on a trusted network.

## Data shapes

`lib/api.ts` mirrors `apps/api/app/schemas.py`. The API is the source of truth;
when a schema changes, update the types in the same commit. The generated
contract lives in `packages/contracts/openapi.yaml`.

List views use flat projections (`GET /admin/lexemes`, `GET /admin/expressions`)
that return counts rather than nested senses — enough to render a row and link
to the editor.

## Tests

```bash
pnpm --filter @kamusi/admin test        # vitest
pnpm --filter @kamusi/admin exec tsc --noEmit
pnpm --filter @kamusi/admin build
```

## Manual testing (Lexeme Creation Studio)

1. Go to **Lexemes → Create lexeme**.
2. Step A: enter lemma + POS, then Save Draft (Ctrl/⌘ + S).
3. Step B: add at least one sense, Swahili definition, and optionally examples (Ctrl/⌘ + Enter adds a sense).
4. Step C: add tags and internal notes.
5. Step D: mark reviewed, then Publish once readiness checks are green.

## Known gap

The lexeme and expression **editor** pages (`/lexemes/new`, `/lexemes/[id]`,
`/expressions/[id]`) are written against a single nested aggregate payload
(lexeme + senses + definitions + examples in one request). The API exposes
per-entity CRUD instead, so saving from those pages does not round-trip yet.
Closing it means either adding aggregate write endpoints to the API or
reworking those pages to sequence the per-entity calls — a deliberate design
decision, not a patch. The list views, the three lookup CRUD pages, and the
whole review pipeline do work against the current API.
