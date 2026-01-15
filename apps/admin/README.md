# Kamusi Admin

Internal admin console for managing lexemes, expressions, tags, sources, and licenses.

## Setup

1. Create a local environment file and set the API base URL:

```bash
cat <<EOF > .env.local
KAMUSI_API_BASE_URL=http://localhost:8000
NEXT_PUBLIC_API_BASE_URL=http://localhost:8000
EOF
```

Required env vars:

- `KAMUSI_API_BASE_URL`: Base URL for the Kamusi API (admin routes use `X-API-Key`).
- `NEXT_PUBLIC_API_BASE_URL`: Optional fallback if `KAMUSI_API_BASE_URL` is not set.
- `ADMIN_API_KEY`: Server-side API key used by the `/api/review` proxy routes.

2. Install dependencies from the repo root:

```bash
pnpm install
```

3. Start the admin app:

```bash
pnpm --filter @kamusi/admin dev
```

## Usage

- Visit `http://localhost:3000`.
- Store your API key in the Login page. The app sends it in the `X-API-Key` header.
- Use the left navigation to manage lexemes, expressions, tags, sources, and licenses.
- Publishing enforces readiness checks (lemma length, POS, Swahili definitions per sense, reviewed workflow state).
- The Publish action calls the backend `/admin/lexemes/{id}/publish` endpoint to update workflow status and search entries.

## Manual testing (Lexeme Creation Studio)

1. Go to **Lexemes → Create lexeme**.
2. Step A: enter lemma + POS, then Save Draft (Ctrl/⌘ + S).
3. Step B: add at least one sense, Swahili definition, and optionally examples (Ctrl/⌘ + Enter adds a sense).
4. Step C: add tags and internal notes.
5. Step D: mark reviewed, then Publish once readiness checks are green.
