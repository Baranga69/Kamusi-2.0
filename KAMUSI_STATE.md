# Kamusi 2.0 — Project State (Continuity Document)

> Purpose: This file captures the *current truth* of Kamusi 2.0.
> Any AI agent, contributor, or future self should read this first
> before making changes.

Last updated: 2026-10-09

---

## 1. Project Identity

**Kamusi 2.0** is a modern, Swahili-first dictionary platform for Africa.

Primary goals:
- High-quality Swahili lexical data
- Modern, calm, reading-first UI/UX
- AI-assisted definitions with human review
- Support for dialects, slang, and language evolution

Non-goals:
- Not a translation app
- Not crowdsourced without moderation
- Not English-first

---

## 2. Architecture Overview

**Monorepo structure**
- apps/
- api/        → FastAPI backend
- admin/      → Next.js admin portal
- mobile/     → Flutter mobile app
- Single PostgreSQL database: `kamusi`
- All modules run locally during development
- APIs are shared between admin + mobile

---

## 3. Backend (FastAPI)

### Stack
- FastAPI
- SQLAlchemy ORM
- PostgreSQL
- Pydantic v2
- Uvicorn

### Key Routers
- `public.py` → mobile-facing APIs
- `admin.py` → admin-only review/management

### Core Public Endpoints
- `GET /search?q=`
- `GET /lookup/lemma?lemma=`
- `GET /lexemes/{lexeme_id}`

Important:
- Draft content is **excluded by default**
- Drafts can be included only with `include_drafts=true`
- Search relies on `search_entry` table, not lexeme table directly

---

## 4. Database Model (Key Truths)

### Core Tables

**lexeme**
- `lemma`
- `normalized_lemma`
- `pos_id`
- `status` (ENUM: core, slang, regional, deprecated, neologism)
- `workflow` (ENUM: draft, published, archived)

**sense**
- Multiple senses per lexeme
- Each sense has its own workflow

**sense_definition**
- `lang_code` (en, sw)
- `definition`
- `gloss`
- `is_ai_generated` (bool)
- `review_status` (pending, approved, edited, rejected)
- `model` (AI model used)
- `prompt_version`

**search_entry**
- Powers `/search`
- Written on publish (`services/publish.py`); never populated by ingestion
- Five target types, each keyed on the row whose text it holds:
  `lexeme`, `definition` (sense_definition.id), `example` (example_text.id),
  `expression`, `expression_meaning` (expression_meaning.id)
- `/search` resolves every hit back to the lexeme or expression a reader can
  open, and reports which kind matched via `match_kind`
- Unreviewed AI Swahili definitions are not indexed, so their text cannot leak
  through `/search`
- Derived state: reconcile with `tools/maintenance/rebuild_search_index.py`

### Invariants (DO NOT BREAK)
- Visibility depends on `workflow`
- AI Swahili definitions are hidden unless approved/edited — enforced in both
  the read path (`routers/public.py`) and the index path (`services/publish.py`)
- English definitions act as fallback
- Search never queries lexeme table directly
- `normalize_sw` drops dashes and apostrophes, so `ng'ombe` and `ngombe` share
  one key. Changing it invalidates every stored key; rerun
  `tools/maintenance/reindex_normalized.py`

### Visibility in search (fixed 2026-10-09)
`/search` enforces visibility at read time rather than trusting the index:
an entry is dropped unless its owning lexeme, sense or expression is
`published` (override with `include_drafts=true`), its owning record still
exists, and it is not an unreviewed AI Swahili definition. Filtering runs
before the limit, and results are ordered deterministically by match rank,
then popularity.

The index itself is still append-only on publish, so rows linger after an
archive. That is now cosmetic rather than a leak; `rebuild_search_index.py`
reconciles it.

### Search relevance (2026-10-10)
- Matching is still `LIKE '%term%'` over the normalized column, but migration
  0003 adds `pg_trgm` GIN indexes, so the planner has an index path for it
  instead of always scanning.
- A trigram pass tops up thin result sets with near spellings, flagged
  `is_fuzzy` and always sorted after literal matches. Postgres only.
- Results are collapsed to one hit per lexeme or expression, preferring the
  headword over a definition over an example.

### Known gaps (not yet invariant)
- No stemming or Swahili morphological awareness in search: a user searching
  an inflected form only finds the lemma if the strings happen to overlap.
- `search_entry.popularity` participates in ranking but is never written, so
  it is always 0. Feeding real lookup counts into it is the next meaningful
  relevance win.

---

## 5. Data Ingestion State

### Wiktionary Ingest
- Source: English Wiktionary dump
- Tooling: `wiktextract` + custom transform scripts
- Result:
  - ~3,800 Swahili lexemes ingested
  - English definitions stored
  - POS distribution heavily verb-weighted (expected)

### AI Swahili Definitions
- 531 Swahili definitions generated offline (`ai_defs.jsonl`)
- Generated via OpenAI API
- Stored as:
  - `is_ai_generated = true`
  - `review_status = 'unreviewed'`
- Hidden from public UI unless `review_status` is `approved` or `edited`

Known issues:
- Morphology-only senses exist
- Some AI definitions are generic placeholders
- Admin review pipeline is required

> **Action required on any database populated before 2026-10-09.**
> `import_ai_defs.py` previously inserted these rows without the provenance
> columns, so they landed `is_ai_generated = false`, `review_status = NULL`.
> That silently disabled the public AI guard *and* hid the rows from the review
> queue. The importer is fixed; existing rows need the one-off repair:
> `apps/api/tools/ai_defs/backfill_ai_provenance.py` (dry run by default).

---

## 6. Admin Panel (Next.js)

Purpose:
- Review lexemes
- Approve / edit / reject AI definitions
- Control workflow status (draft → published)

Status:
- Review pipeline works end to end (queue, detail, approve/edit/reject, bulk)
- List views and the tag/source/license CRUD pages work against the API
- The lexeme and expression **editor** pages still assume a single nested
  aggregate payload the API does not expose, so saving from them does not
  round-trip. See the "Known gap" section of `apps/admin/README.md`.

Admin is the *gatekeeper* for public data quality.

---

## 7. Mobile App (Flutter)

### Current State
- Connected to live local API
- Search endpoint working
- Lexeme detail endpoint working (after schema fixes)
- Real data rendering (not mocked)

### UX Direction (LOCKED)
- Material 3
- Calm, scholarly, reading-first
- No loud colors, no heavy borders
- Soft surfaces, generous spacing
- Serif typography for definitions

Visual identity details live in `DESIGN_SYSTEM.md`.

---

## 8. Design System (Summary)

Tone:
- Calm
- Trustworthy
- Modern
- African-aware (subtle)

Colors:
- Primary: #3A4A6B (deep indigo / blue-gray)
- Secondary: #4F8F8B (muted teal)
- Surfaces: warm neutrals
- No pure black text unless required

Typography:
- Serif for lemmas + definitions
- Sans for UI chrome
- Optimized line height for reading

---

## 9. AI Usage Policy

AI is used to:
- Generate draft Swahili definitions
- Assist (not replace) lexicography

AI is NOT allowed to:
- Publish definitions without review
- Override human editorial decisions
- Change linguistic structure without approval

---

## 10. Current Snapshot

As of this document:
- ~3,800 lexemes in DB
- ~500 AI Swahili definitions generated
- Search + lookup working
- Admin + mobile wired to API
- UX refinement underway
- Review pipeline next major milestone

---

## 11. Next Priorities (Ordered)

1. Run `backfill_ai_provenance.py` and `reindex_normalized.py` against the
   working database, then confirm the review queue is populated
2. Decide the lexeme/expression editor contract: aggregate write endpoints on
   the API, or sequence per-entity calls in the admin UI
3. Improve AI definition quality + flags
4. Mobile UI/UX polish — including the Material 3 colour-role migration
   (`background`, `surfaceVariant`), which needs a `DESIGN_SYSTEM.md` decision
5. Expand corpus (methali, semi, regional variants) — `/search` now resolves
   expression and meaning hits, so the surface is ready for the content

---

## 12. Rules for AI / Codex Agents

- Do NOT re-ingest Wiktionary unless explicitly requested
- Do NOT relax workflow filters casually
- Do NOT redesign UI without following design system
- Prefer incremental changes over rewrites
- Preserve Swahili-first principle at all times

---

End of document.
