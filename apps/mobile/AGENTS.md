# Kamusi-2.0 Mobile (Flutter) — AGENTS.md

This file defines guardrails for AI agents (Codex) working in `apps/mobile`.

## Current state (important)
- The mobile app is already connected to the FastAPI backend.
- Search and lexeme detail endpoints are integrated and returning data in the UI.
- Your work must preserve existing API wiring and keep the app compiling/running.

## Primary objective (what to optimize now)
Build a modern, polished dictionary UX (Kamusi 2.0) while keeping the existing data/API integration stable.

Focus areas:
1) Search UX & performance
2) Lexeme detail presentation
3) Design system consistency (spacing, typography, colors)
4) Error/loading/empty states
5) Offline-friendly behavior (basic caching)
6) Debug/dev toggles without polluting production UX

---

## Non-goals (do NOT do these)
- Do NOT change backend API contracts or backend code in this task set.
- Do NOT modify database schema, ingestion scripts, or admin portal code.
- Do NOT introduce a new state management framework unless explicitly instructed.
- Do NOT add heavy dependencies without a clear need and explanation.
- Do NOT create duplicate models/services that already exist—refactor in place.

---

## UX principles to follow
- **Fast + calm UI**: results should feel instant and smooth.
- **Minimal visual noise**: modern typography, generous whitespace, clean separators.
- **Predictable navigation**:
  - Search → Results → Detail
  - Back returns to same scroll position and query text
- **User-first definitions**:
  - Prefer Swahili definitions; fallback to English if Swahili missing
  - Avoid showing internal IDs in UI
- **Trust cues**:
  - Label AI definitions subtly (e.g., “AI” badge) only if configured to show
  - Don’t show AI defs unless they are approved/edited (if the API already filters this)

---

## Strict guardrails (must follow)
### 1) Preserve working API integration
- Keep existing endpoints and request shapes unchanged.
- Preserve existing DTO/models unless an update is required to render UI.
- When changing data models, ensure:
  - serialization remains compatible
  - existing screens still work

### 2) No breaking refactors
- Do not restructure the entire app.
- Prefer small PR-sized changes:
  - 1 feature improvement at a time
  - minimal diff
  - easy rollback

### 3) UI changes should be measurable
Every UX change must include:
- screenshot notes in PR description (what changed visually)
- a short “why” (usability / readability / speed)
- a quick test plan (manual steps)

### 4) Consistent component library
- Prefer reusable widgets:
  - `SearchBar`
  - `SearchResultTile`
  - `LexemeHeader`
  - `SenseCard`
  - `DefinitionRow`
  - `EmptyState`, `ErrorState`, `LoadingSkeleton`
- Keep styling consistent via shared theme/constants (no magic numbers repeated).

---

## Functional requirements (current product behavior)
### Search screen
- Debounce typing (~250–400ms)
- Cancel stale requests when a new query is typed (avoid out-of-order results)
- Show:
  - “Start typing…” state
  - “No results” state
  - Network error state with retry
- Support pagination only if backend supports it (otherwise no fake paging)

### Detail screen
- Must handle:
  - 0 senses
  - senses with 0 definitions in selected language
  - multiple definitions per sense
- Display order:
  - lemma, POS label (user-friendly), pronunciation/audio (if available later)
  - senses in order
  - definitions with gloss (if present)
  - examples (if present)
- Keep layout readable; do not overload the screen.

---

## Performance & reliability
- Avoid rebuilding the whole page on every keystroke unnecessarily.
- Prefer `ListView.builder` for results and senses.
- Add lightweight caching:
  - cache last N search queries in memory
  - cache lexeme detail responses in memory
- Never block UI thread with heavy JSON parsing; if payloads grow, consider isolates.

---

## Dev/prod toggles (safe)
Allowed:
- `--dart-define=API_BASE_URL=...`
- A hidden “Developer Settings” page behind a long-press or multi-tap gesture
Not allowed:
- Visible debug UI in release mode
- Hardcoding include_drafts=true in release builds unless explicitly requested

---

## Testing expectations (minimum)
Before submitting changes:
- `flutter analyze` passes
- App runs on:
  - Android emulator
  - (optional) physical device if available
Manual test checklist:
1) Search for “agua”
2) Tap first result
3) Detail loads and renders senses/definitions
4) Back returns to search with query preserved
5) Try no-network: graceful error + retry

---

## Output format for agent work
When you finish a task, report:
- Files changed (list)
- What changed (bullets)
- Why (1–2 lines)
- How to test (step-by-step)

---

## Style expectations
- Write readable, maintainable Dart.
- Use null safety properly.
- Avoid large widgets; extract smaller components.
- Keep naming consistent with existing codebase.