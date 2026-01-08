# Kamusi Admin

Internal admin console for managing lexemes, expressions, tags, sources, and licenses.

## Setup

1. Copy the environment file and set the API base URL:

```bash
cp .env.example .env.local
```

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
- Publishing enforces the workflow rules for lexemes (POS required and each sense must have a Swahili definition).
