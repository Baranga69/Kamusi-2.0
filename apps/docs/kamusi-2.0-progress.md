# Kamusi 2.0 — Project Progress & Architecture Notes

_Last updated: 2026-01_

This document captures the technical and product milestones achieved so far in the Kamusi 2.0 project, including database design, ingestion pipelines, and AI-assisted Swahili definition generation.

---

## 1. Project Goal

To build a **modern, African-first Swahili dictionary (Kamusi 2.0)** with:
- Clean UX/UI
- Strong linguistic structure
- Support for evolution (slang, youth language, regional forms)
- AI-assisted but human-governed content creation

---

## 2. Core Architecture Decisions

### 2.1 Lexical Model
Kamusi uses a **lexeme–sense–definition** model:

- **lexeme**
  - lemma
  - part of speech
  - status (core, slang, regional, etc.)
  - workflow (draft, reviewed, published)

- **sense**
  - belongs to a lexeme
  - allows multiple meanings per word

- **sense_definition**
  - language-specific
  - supports multiple sources
  - enforces uniqueness per `(sense_id, lang_code)`

This allows:
- multilingual definitions
- AI + human coexistence
- future expansion (examples, usage notes, domains)

---

## 3. Data Sources

### 3.1 Wiktionary (Baseline)
- Source: English Wiktionary dump
- License: CC BY-SA
- Extracted Swahili entries using `wiktwords`
- Cleaned into a **contract JSONL format**
- Loaded into Postgres with provenance preserved

**Results:**
- ~83,000 raw Swahili-tagged lines
- ~3,803 usable English definitions loaded
- Strong verb + noun coverage

---

### 3.2 AI-Generated Swahili Definitions (Phase 1)

A new **AI source** was introduced:

- Source type: `ai`
- License: Kamusi AI Content License
- Purpose: draft-quality Swahili definitions derived from English glosses
- Requires human review before publication

---

## 4. AI Definition Pipeline (Offline)

### 4.1 Rationale
AI generation is done **offline via scripts** to ensure:
- Cost control
- Reproducibility
- Auditability
- No runtime dependency on AI APIs

---

### 4.2 Pipeline Stages

#### Stage A — Export Candidates
From DB:
- English definitions only
- Excludes morphology-only entries:
  - “Applicative form of…”
  - “Reciprocal form of…”
  - “Stative form of…”
- Excludes senses that already have Swahili

**Output:** `candidates.jsonl`  
**Count:** ~531 high-quality candidates

---

#### Stage B — AI Generation
- Model: `gpt-4o-mini`
- Prompted as a Swahili lexicographer
- Output constraints:
  - Short (6–18 words)
  - Natural Swahili
  - Non-circular
  - Strict JSON output

**Output files:**
- `ai_defs.jsonl` — successful generations
- `ai_defs_errors.jsonl` — parse or generation failures

Markdown code fences are stripped during parsing.

---

#### Stage C — Import into Database
- Inserts `lang_code = 'sw'`
- Uses `(sense_id, lang_code)` uniqueness
- Provenance set to AI source
- Skips existing Swahili definitions

---

## 5. Current Data State

### 5.1 English Definitions
- ~3,803 definitions (Wiktionary)
- Language: `en`
- Workflow: `draft`
- Status: `core`

### 5.2 Swahili Definitions (AI, Phase 1)
- ~531 draft Swahili definitions
- Language: `sw`
- Source: Kamusi AI Definitions v1
- Quality: generally strong, dictionary-appropriate
- Marked for future review

---

## 6. Verified Quality Examples

Example AI output:

> **Kufungua mdomo kwa sababu ya kushangazwa au kuchoka.**  
> (for *achama* — “to gape”)

Characteristics:
- Correct meaning
- Natural phrasing
- Concise
- Non-circular

---

## 7. Known Deferred Improvements

The following are intentionally postponed:

- Add explicit `review_flag` or `is_ai_generated` field
- Admin UI workflow (Approve / Edit / Reject)
- Morphology-aware handling of:
  - applicative (-ia)
  - reciprocal (-ana)
  - causative (-isha/-esha)
  - passive (-wa)
- Auto-linking derived verb forms

These are planned for later phases.

---

## 8. Tooling & Environment

- OS: macOS
- Shell: zsh
- Python: 3.11
- Virtual env: `.venv-ingest`
- Database: PostgreSQL (Docker)
- DB client: pgAdmin4 / VS Code SQLTools
- AI: OpenAI API

---

## 9. Key Design Principles Followed

- Provenance over convenience
- Offline-first AI usage
- Human review as final authority
- Schema designed for growth, not hacks
- African language UX first (not English-first)

---

## 10. Current Status Summary

✅ Solid lexical schema  
✅ Clean Wiktionary ingestion  
✅ AI-assisted Swahili definitions (draft)  
✅ Repeatable pipelines  
✅ Data integrity preserved  

Kamusi 2.0 now has a **real linguistic backbone**.

---

_End of document_