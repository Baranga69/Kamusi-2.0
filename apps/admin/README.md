# Kamusi Admin

Internal admin console for managing lexemes, expressions, tags, sources, and licenses.

## Setup

1. Create a local environment file:

```bash
cp .env.example .env.local   # then fill in
```

Required env vars:

- `KAMUSI_API_BASE_URL`: Base URL for the Kamusi API. Read server-side at
  request time, so one build works across environments.
- `NEXT_PUBLIC_API_BASE_URL`: Optional fallback if `KAMUSI_API_BASE_URL` is not set.

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

- Visit `http://localhost:3000` and sign in with an email and password.
- There is no self-service sign-up. Create the first account with
  `poetry run python scripts/create_user.py` in `apps/api`, then add the rest
  from **Accounts**.
- Use the left navigation to manage lexemes, expressions, tags, sources, and licenses.
- Review queue supports approving, editing, and rejecting AI Swahili definitions with filters, select-all, and keyboard shortcuts.
- Click a lemma in the review queue to open the detail view with diff preview and audit metadata.
- Queue rows carry badges for anything the ingest quality gate objects to —
  "Looks English", "Too short", "Repeats headword" and so on. Nothing is
  hidden on account of a badge; it points at where to look first. The rules
  live in the API (`apps/api/app/core/quality.py`) so the importer and this
  queue cannot disagree about what counts as suspect — `lib/qualityFlags.ts`
  only turns a slug into a readable label.
- Publishing enforces readiness checks (lemma length, POS, Swahili definitions per sense, reviewed workflow state).
- The Publish action calls the backend `/admin/lexemes/{id}/publish` endpoint to update workflow status and search entries.

## How requests reach the API

The browser never holds a credential. Sign-in exchanges an email and password
for a session token, which is stored in an **httpOnly** cookie on this app's
own origin — page scripts cannot read it, so an XSS bug cannot exfiltrate it.

Every admin call then goes to `/api/admin/*`, a catch-all proxy
(`app/api/admin/[...path]/route.ts`) that attaches the session server-side and
forwards to the API. One proxy, one credential path.

That is also what makes the audit trail real: the API resolves the session to
an account, so `reviewed_by` on an approval is established by the server rather
than supplied by the client. Nothing in `lib/api.ts` sends a reviewer name.

## Roles

The navigation only shows what the signed-in role can open, and the API
enforces the same rules regardless:

| Role | Sees |
| --- | --- |
| `reviewer` | Review |
| `editor` | + Lexemes, Expressions, Tags, Sources |
| `admin` | + Licenses, Accounts |

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

`lib/contract.test.ts` validates the request bodies this client produces
against `packages/contracts/openapi.yaml`, which is generated from the running
API. CI separately fails when that spec is stale, so together they mean the
console is checked against the real server contract rather than against its
own mocks.

That gap was not theoretical: review actions once shipped returning 422 for
every caller while the mocked tests stayed green, because the API required a
field the console had correctly stopped sending. Add a case here whenever you
add a request body.

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
