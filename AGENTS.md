# Kamusi-2.0 — AGENTS.md (Root)

This file defines global guardrails for AI agents (Codex) working in this monorepo.

## Repo layout
- `apps/api` — FastAPI backend (PostgreSQL, SQLAlchemy)
- `apps/mobile` — Flutter mobile app (dictionary UX)
- `apps/admin` — Next.js admin portal (lexeme/definition review pipeline)
- `docker-compose.yml` — local infra (Postgres, etc.)

## Current status (important)
- Core APIs are already integrated into the mobile UI and working locally.
- Data has been ingested (Wiktionary baseline + some AI-generated Swahili defs).
- The monorepo must remain runnable with minimal friction.

---

# Golden rules (must follow)
## 1) Don’t break working flows
- Preserve existing API contracts (request/response shapes).
- Preserve working mobile search → detail navigation.
- Preserve admin portal boot flow and basic routes.

## 2) Keep changes scoped
- Make changes in **small, reviewable units**.
- Prefer incremental improvements over large refactors.
- Do not “re-architect” unless explicitly asked.

## 3) Avoid cross-module surprise
- Only modify the module(s) explicitly requested by the task.
- If you must touch another module, document why and keep changes minimal.

## 4) One source of truth per layer
- Backend is the source of truth for data rules and filtering.
- Mobile is the source of truth for presentation and UX.
- Admin is the source of truth for review workflows (approve/edit/reject).

## 5) No schema changes without explicit approval
- Do **not** add/rename/drop DB columns, enums, or tables unless the task explicitly requests a migration.
- If a schema mismatch is discovered, propose the migration as a separate, clearly labeled step.

---

# Branching / PR expectations
When producing a change (PR-ready):
- Include:
  - Summary of changes
  - Files changed
  - Why this change matters
  - Manual test plan (step-by-step)
- Keep formatting consistent with existing repo conventions.

---

# Environment & configuration guardrails
## Local dev base URLs
- Mobile should not hardcode `localhost`.
- Use `--dart-define=API_BASE_URL=...` or a single centralized config.
- Document emulator/simulator/device values clearly.

## Secrets
- Never commit secrets or API keys.
- `.env` values must remain local; use `.env.example` for templates.

---

# API contract stability rules
- Do not rename endpoints, path params, or response fields without:
  1) updating all clients (mobile/admin)
  2) documenting migration steps
- Prefer additive changes (new optional fields) over breaking changes.
- If filtering rules change (e.g., draft vs published), update docs and clients together.

---

# Database rules
- Treat Postgres enum changes as high-risk:
  - do not remove enum values casually
  - prefer adding values or using new enums + migration
- Any migration must be reproducible with Alembic and documented.

---

# Quality bar by module
## apps/api (FastAPI)
- Add/modify routes only when explicitly asked.
- Keep validation strict but developer-friendly.
- Provide clear error messages and avoid 500s for user-caused input errors.
- Add tests for new logic where feasible.

## apps/mobile (Flutter)
- UX improvements must preserve existing API integration.
- Prefer reusable components and consistent design tokens.
- Handle loading/error/empty states consistently.
- Avoid introducing heavy dependencies without need.

## apps/admin (Next.js)
- Focus on lexeme/definition review workflows.
- Maintain a clear moderation pipeline:
  - Approve / Edit / Reject
  - Audit metadata (who/when)
- Keep UI fast and minimal; avoid premature complexity.

---

# AI definitions & moderation (global)
- AI-generated Swahili definitions must be treated as “untrusted until reviewed”
  unless explicitly configured otherwise.
- Default stance:
  - show AI defs only if `review_status in {approved, edited}`
- Keep room for future:
  - review flags
  - “auto-downgrade morphology-only” logic
  - admin review queue and bulk review tools

---

# Documentation rules
- If you add a feature or change behavior, update docs in the same PR:
  - module README or `/docs`
  - examples (curl, screenshots, etc.)
- Keep documentation short, practical, and runnable.

---

# Output format for agent responses
When you finish a task, report:
- What you changed (bullets)
- Files changed (list)
- How to test (step-by-step)
- Risks/notes (if any)

---

# Safe defaults
If unsure:
- do the smallest change that works
- avoid breaking changes
- ask for explicit direction before cross-cutting refactors