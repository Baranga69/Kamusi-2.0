# Kamusi 2.0 — Architecture Overview

> This document explains how Kamusi 2.0 is structured and why.
> It exists to prevent architectural drift.

Last updated: 2026-01-12

---

## 1. High-Level Architecture

Kamusi 2.0 is a **monorepo-based, API-driven system**.
        Mobile (Flutter)
        ↓
        FastAPI (Public APIs)
        ↓
        PostgreSQL (kamusi)
        ↑
        FastAPI (Admin APIs)
        ↑
        Admin Panel (Next.js)

---

## 2. Monorepo Structure

apps/
api/        # FastAPI backend
admin/      # Next.js admin portal
mobile/     # Flutter mobile app

Reasons for monorepo:
- Shared domain models
- Easier coordination between API + UI
- Single source of truth
- Easier AI/Codex operation across modules

---

## 3. Backend (FastAPI)

### Stack
- FastAPI
- SQLAlchemy ORM
- PostgreSQL
- Pydantic v2
- Uvicorn

### Router Separation

- `public.py`
  - Search
  - Lookup
  - Lexeme details
  - Used by mobile app

- `admin.py`
  - Review workflows
  - Approvals
  - Editorial actions

Public and admin concerns are **explicitly separated**.

---

## 4. Data Access Pattern

- SQLAlchemy ORM
- Explicit queries (no magic repository layer)
- Filters enforced at API level (workflow, review status)

Rules:
- Search NEVER queries lexeme table directly
- Search ALWAYS goes through `search_entry`
- Visibility rules enforced server-side

---

## 5. Database

### Database
- PostgreSQL
- Single database: `kamusi`

### Key Concepts
- Lexeme → Sense → Definition hierarchy
- Workflow controls visibility
- Status describes linguistic classification
- AI metadata is first-class, not bolted on

---

## 6. Ingestion Architecture

### Wiktionary
- Offline extraction
- Transform scripts normalize data
- Load scripts insert curated data

### AI Definitions
- Offline generation
- JSONL intermediate format
- Explicit import step
- Never generated live in production APIs

This prevents:
- API latency issues
- Cost spikes
- Non-deterministic behavior

---

## 7. Admin Panel (Next.js)

Purpose:
- Editorial control
- Review pipeline
- Quality assurance

Admin is:
- Authoritative
- Required for publication
- Separate from public access

---

## 8. Mobile App (Flutter)

Role:
- Consume public APIs
- Display lexical data
- Provide best reading experience

Mobile app:
- Never modifies data directly
- Never bypasses workflow rules
- Reflects backend truth exactly

---

## 9. AI & Automation

AI is used for:
- Draft generation
- Assistance
- Acceleration

AI is NOT:
- Autonomous
- Self-publishing
- Allowed to bypass review

Human editorial control is mandatory.

---

## 10. Scalability & Future

Planned expansions:
- Methali (proverbs)
- Semi (idioms)
- Regional variants
- Dialect tagging
- Multi-language definitions beyond Swahili/English

Architecture already supports this without redesign.

---

## 11. Anti-Patterns (Avoid)

- Bypassing search_entry
- Hardcoding visibility rules in UI
- Live AI generation in user-facing APIs
- Multiple databases
- Premature microservices

---

## 12. Guiding Principle

> **Correctness, clarity, and cultural respect
> matter more than speed or novelty.**

---

End of document.