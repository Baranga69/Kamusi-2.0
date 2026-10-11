# Kamusi API

## Setup

```bash
cd apps/api
cp .env.example .env   # then fill in
poetry install
```

## Run API

```bash
cd apps/api
poetry run uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

## CORS (Admin UI)

If you access the API from the admin UI in the browser, set `CORS_ORIGINS` to allow that origin:

```bash
export CORS_ORIGINS="http://localhost:3000"
```

You can also provide a comma-separated list or a JSON array.

## Public API

```bash
curl "http://localhost:8000/search?q=agua&lang=sw&limit=20"
curl "http://localhost:8000/search?q=baraka&lang=sw"          # methali / semi
curl "http://localhost:8000/search?q=ngombee&lang=sw"         # typo -> ng'ombe
curl "http://localhost:8000/search?q=mti&lang=sw&include_drafts=true"
curl "http://localhost:8000/search?q=mti&lang=sw&fuzzy=false"
curl "http://localhost:8000/lexemes/<LEXEME_ID>?lang=sw"
curl "http://localhost:8000/lookup/lemma?lemma=ng'ombe&lang=sw"
curl "http://localhost:8000/word-of-the-day?lang=sw"
```

Visibility rules are enforced server-side:

- unpublished content is excluded unless `include_drafts=true`
- an AI-generated Swahili definition is hidden unless its `review_status` is
  `approved` or `edited`
- `/search` reads `search_entry`, never the `lexeme` table directly

### How /search resolves a hit

`search_entry` holds one row per searchable string. Every hit is resolved back
to the record a reader can open, and `match_kind` says what matched:

| `target_type` | `match_kind` | resolves to |
| --- | --- | --- |
| `lexeme` | `lemma` | that lexeme |
| `definition` | `definition` | the definition's lexeme |
| `example` | `example` | the example's lexeme |
| `expression` | `expression` | that expression |
| `expression_meaning` | `meaning` | the meaning's expression |

A result carries either `lexeme_id`/`lemma` or `expression_id`/`expression_text`,
never both. Filtering happens before the limit is applied, so a request for 20
results returns the 20 best *visible* matches rather than whatever survives from
the first 20 rows. Entries are excluded when the owning lexeme, sense or
expression is not `published` (unless `include_drafts=true`), when the owning
record has been deleted, or when the hit is an unreviewed AI Swahili
definition.

A word that matches on its headword, one of its definitions and one of its
examples is three index rows but one dictionary entry, so results are collapsed
to the strongest hit per entry — headword first, then meaning, then example.

### Typo tolerance

Search runs a strict pass (exact, then prefix, then substring). If that leaves
room under `limit`, a second pass tops the list up with trigram-similar
spellings, so "ngombee" still finds "ng'ombe". Those results carry
`is_fuzzy: true` and always sort after every literal match, so a client can
present them as "did you mean" and adding them never reorders a good match.

This needs `pg_trgm` (migration 0003) and is skipped on any other backend.
`fuzzy=false` turns it off per request; `SEARCH_FUZZY_THRESHOLD` (default 0.3,
the pg_trgm default) sets how close a spelling has to be — lower widens the
net, higher demands a closer match.

## Accounts and roles

There are two ways to authenticate against `/admin/*`:

- **A person**, with a session token in `Authorization: Bearer`. Obtained from
  `POST /auth/login` and tied to a row in `app_user`.
- **A service**, with the shared `X-API-Key`. For scripts, ingestion and curl.
  It has admin rights over content but is *not* an account, so it cannot take
  review decisions — there would be no one to record.

| Role | Can |
| --- | --- |
| `reviewer` | work the review queue (approve / edit / reject) |
| `editor` | + create and edit entries, move them through the workflow |
| `admin` | + manage accounts, licences and sources, delete anything |

`reviewed_by` is always taken from the session, never from the request body, so
the audit trail records who actually acted. A `reviewer` field in a review
payload is ignored.

### Create the first account

There is no open sign-up. Bootstrap one, then add the rest from the console or
`POST /admin/users`:

```bash
cd apps/api
poetry run python scripts/create_user.py --email you@example.com \
    --name "Your Name" --role admin
```

The same script with `--update` is the way back in if every admin password is
lost.

### Sessions

Tokens are signed, not stored, so there is no session table to sweep.
`SESSION_SECRET` signs them — rotating it invalidates every session, and the
app logs a warning while the built-in development value is in use.
`SESSION_MAX_AGE_SECONDS` (default 12 hours) bounds their life.
Disabling an account or changing a password moves `sessions_valid_from`
forward, which revokes that account's existing tokens immediately.

```bash
curl -X POST -H 'content-type: application/json' \
  -d '{"email":"you@example.com","password":"..."}' \
  http://localhost:8000/auth/login
# -> {"token": "...", "expires_in_seconds": 43200, "user": {...}}

curl -H "Authorization: Bearer $TOKEN" http://localhost:8000/auth/me
```

## Admin API

```bash
export KEY=dev-api-key   # a service credential; a session token also works

# Browse (list projections, for the admin portal's list views)
curl -H "X-API-Key: $KEY" "http://localhost:8000/admin/lexemes?query=mti&status=published&pos_code=NOUN"
curl -H "X-API-Key: $KEY" "http://localhost:8000/admin/expressions?status=draft"
curl -H "X-API-Key: $KEY" "http://localhost:8000/admin/tags?query=chakula"
curl -H "X-API-Key: $KEY" "http://localhost:8000/admin/sources"
curl -H "X-API-Key: $KEY" "http://localhost:8000/admin/licenses"

# Seeded vocabularies, so clients never hardcode a lookup id
curl -H "X-API-Key: $KEY" "http://localhost:8000/admin/lookups"

# Per-entity CRUD lives at /admin/{collection} and /admin/{collection}/{id}
# Workflow transitions:
curl -X POST -H "X-API-Key: $KEY" "http://localhost:8000/admin/lexemes/<ID>/review"
curl -X POST -H "X-API-Key: $KEY" "http://localhost:8000/admin/lexemes/<ID>/publish"
```

### Review queue

```bash
curl -H "X-API-Key: $KEY" \
  "http://localhost:8000/admin/review/queue?status=unreviewed&pos_code=VERB&lexeme_status=slang&sort=oldest"
```

Review actions take no `reviewer` field: who acted is read from the session
and recorded server-side, so a client cannot choose whose name is logged. An
older client still sending one keeps working — the value is ignored.

`sort` accepts `oldest`, `newest`, `lemma`, or `confidence` — the last leads
with the definitions the model was least sure about, which is where reviewer
attention is worth most. Rows with no recorded confidence sort last: unknown
is not the same as poor.

`status` accepts `unreviewed`, `approved`, `edited`, `rejected`, or `reviewed`
(which means approved + edited). Approve / edit / reject act only on rows that
are still `unreviewed` and return 409 otherwise, so two reviewers cannot
overwrite each other. Reading the queue works with either credential; acting on
an item needs a signed-in account.

## Database

Start Postgres at repo root:

```bash
docker compose up -d postgres
```

Run migrations:

```bash
cd apps/api
poetry run alembic upgrade head
```

Seed lookup tables (languages, parts of speech, registers, domains, expression
types, tag types). The admin portal's selects are empty until this runs:

```bash
cd apps/api
poetry run python scripts/seed.py
```

### Demo content

`seed.py` leaves the dictionary itself empty, which gives you a search box that
finds nothing, no word of the day, an empty review queue and a Jifunze tab that
correctly reports it has nothing to quiz. To get a usable app:

```bash
cd apps/api
poetry run python scripts/seed_demo.py
```

That adds published Swahili words with definitions and examples, published
methali with their meanings, and a handful of **unreviewed** AI Swahili
definitions. The last group is the interesting part: they are hidden from
readers and waiting in the admin review queue, so you can approve one and watch
it appear in `/lexemes` and in search. Pass `--skip-review-queue` to leave them
out.

Idempotent — re-running adds nothing.

## Tests

```bash
cd apps/api
poetry run pytest
```

That runs against in-memory SQLite, so it needs no services. SQLite cannot
exercise the migrations, the native enums or the trigram search, so point the
suite at a real Postgres to cover those — CI runs both:

```bash
createdb kamusi_test
TEST_DATABASE_URL=postgresql+psycopg://kamusi:kamusi123@localhost:5433/kamusi_test \
  poetry run pytest
```

On Postgres the schema is built by running the Alembic migrations, so a broken
migration fails the suite. Tests marked `@pytest.mark.postgres` skip on
SQLite.

## Contracts

`packages/contracts/openapi.yaml` is generated from the running app, never
hand-edited. Regenerate it in the same commit as any route or schema change:

```bash
cd apps/api
poetry run python scripts/export_openapi.py
poetry run python scripts/export_openapi.py --check   # what CI runs
```

## Maintenance tools

### Repair AI provenance (one-off)

Swahili definitions imported before `import_ai_defs.py` set the provenance
columns are invisible to the review queue and served to readers as though a
human wrote them. Dry run first:

```bash
cd apps/api
export KAMUSI_DB_URL="postgresql://kamusi:kamusi123@localhost:5433/kamusi"
export AI_SOURCE_ID="<source uuid used at import time>"

poetry run python tools/ai_defs/backfill_ai_provenance.py
poetry run python tools/ai_defs/backfill_ai_provenance.py --apply \
  --jsonl ../../ai_defs.jsonl --prune-search-index
```

### Rebuild search popularity

`search_entry.popularity` is part of result ordering and nothing used to set
it, so it was always 0. Opening an entry now records an anonymous
`lookup_event` — what was opened, in which language, when; no IP, no user
agent, no account — and this rolls those up:

```bash
cd apps/api
poetry run python tools/maintenance/aggregate_popularity.py            # report
poetry run python tools/maintenance/aggregate_popularity.py --apply    # commit
poetry run python tools/maintenance/aggregate_popularity.py --apply --prune-after 365
```

Counts come from a sliding window (`--days`, default 90) and are recomputed
rather than accumulated, so popularity reflects what people look up now rather
than freezing early traffic in place. A lexeme's count is applied to every
search entry that resolves back to it — headword, definitions, examples — so a
definition hit for a common word rises too.

Worth running nightly. It is also the report of what Swahili speakers actually
look up, which is the most interesting dataset this project will produce.

### Reconcile the search index

`search_entry` is derived, but publishing only ever adds to it — nothing
removed rows when an entry was archived, and older publishes never indexed
example texts or expression meanings at all. `/search` filters on visibility at
read time so nothing leaks, but the table still drifts. This reconciles it with
published content (and is a no-op on a clean index):

```bash
cd apps/api
poetry run python tools/maintenance/rebuild_search_index.py            # report
poetry run python tools/maintenance/rebuild_search_index.py --apply    # commit
```

Worth running after a bulk archive, after this upgrade, and on a schedule.

### Rebuild normalization keys (after a `normalize_sw` change)

`normalize_sw` now drops dashes and apostrophes instead of turning them into
spaces, so `ng'ombe` and `ngombe` share one key. Stored keys predating that
change are stale and must be recomputed:

```bash
cd apps/api
poetry run python tools/maintenance/reindex_normalized.py            # report
poetry run python tools/maintenance/reindex_normalized.py --apply    # commit
```

Lexeme rewrites that would collide on `(normalized_lemma, pos_id)` are reported
and skipped — those pairs are duplicates under the new key and need an
editorial decision about which entry survives.

## Ingestion

Offline only; never run from a request path. See `tools/ingest/wiktionary` and
`tools/ai_defs`. The AI pipeline is:

```
export_candidates.py  ->  candidates.jsonl
generate_ai_defs.py   ->  ai_defs.jsonl        (OpenAI, offline)
import_ai_defs.py     ->  sense_definition rows, is_ai_generated=true,
                          review_status='unreviewed'
```

Imported definitions stay hidden from readers until a reviewer approves or
edits them in the admin portal.
