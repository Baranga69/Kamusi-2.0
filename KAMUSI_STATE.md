# Kamusi 2.0 — Project State (Continuity Document)

> Purpose: This file captures the *current truth* of Kamusi 2.0.
> Any AI agent, contributor, or future self should read this first
> before making changes.

Last updated: 2026-01-12

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
- Must be populated explicitly
- Drafts only appear if explicitly allowed

### Invariants (DO NOT BREAK)
- Visibility depends on `workflow`
- AI Swahili definitions are hidden unless approved/edited
- English definitions act as fallback
- Search never queries lexeme table directly

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
- ~500+ Swahili definitions generated offline
- Generated via OpenAI API
- Stored as:
  - `is_ai_generated = true`
  - `review_status = pending`
- Hidden from public UI unless approved

Known issues:
- Morphology-only senses exist
- Some AI definitions are generic placeholders
- Admin review pipeline is required

---

## 6. Admin Panel (Next.js)

Purpose:
- Review lexemes
- Approve / edit / reject AI definitions
- Control workflow status (draft → published)

Status:
- Scaffold exists
- APIs connected
- Review UX improvements in progress

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

1. Admin review UX (approve/edit/reject)
2. Improve AI definition quality + flags
3. Mobile UI/UX polish (Material 3, typography)
4. Expand corpus (methali, semi, regional variants)

---

## 12. Rules for AI / Codex Agents

- Do NOT re-ingest Wiktionary unless explicitly requested
- Do NOT relax workflow filters casually
- Do NOT redesign UI without following design system
- Prefer incremental changes over rewrites
- Preserve Swahili-first principle at all times

---

End of document.
