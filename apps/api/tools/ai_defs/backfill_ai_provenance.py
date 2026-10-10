#!/usr/bin/env python3
"""One-off repair: tag already-imported Swahili definitions as AI-generated.

Why this exists
---------------
``import_ai_defs.py`` used to insert Swahili definitions without setting
``is_ai_generated``, ``review_status``, ``ai_model`` or ``ai_prompt_version``.
Migration 0002 drops the column defaults after backfilling, so those rows
landed with ``is_ai_generated = false`` and ``review_status = NULL``. Two
consequences:

* the public API's AI guard never fires, so unreviewed machine output is served
  as though a lexicographer wrote it;
* the admin review queue filters on ``is_ai_generated IS TRUE`` and
  ``review_status = 'unreviewed'``, so those rows are invisible to reviewers
  and the approve/edit/reject endpoints refuse to touch them.

The importer is fixed going forward. This script repairs rows already in the
database. Rows are matched by ``source_id`` — the AI source you passed as
``AI_SOURCE_ID`` at import time — which is the only durable marker those
inserts left behind.

Safety
------
Dry run by default: it reports what it would change and writes nothing. Pass
``--apply`` to commit. Rows that a human has already acted on
(``review_status IN ('approved','edited','rejected')``) are never touched.

Usage
-----
    export KAMUSI_DB_URL="postgresql://kamusi:kamusi123@localhost:5433/kamusi"
    export AI_SOURCE_ID="<the source uuid used when importing>"

    python tools/ai_defs/backfill_ai_provenance.py                    # dry run
    python tools/ai_defs/backfill_ai_provenance.py --apply            # commit
    python tools/ai_defs/backfill_ai_provenance.py --apply \
        --jsonl ../../ai_defs.jsonl   # also restore per-row model/prompt version
"""
from __future__ import annotations

import argparse
import json
import os
import sys
import uuid
from pathlib import Path

import psycopg
from psycopg.rows import dict_row

DEFAULT_DB_URL = "postgresql://kamusi:kamusi123@localhost:5433/kamusi"

PREVIEW_SQL = """
SELECT sd.id,
       sd.review_status,
       sd.is_ai_generated,
       l.lemma,
       left(sd.definition, 60) AS preview
FROM sense_definition sd
JOIN sense s ON s.id = sd.sense_id
JOIN lexeme l ON l.id = s.lexeme_id
WHERE sd.lang_code = 'sw'
  AND sd.source_id = %s
  AND (sd.is_ai_generated IS NOT TRUE OR sd.review_status IS NULL)
  AND coalesce(sd.review_status, 'unreviewed') NOT IN ('approved', 'edited', 'rejected')
ORDER BY l.lemma
"""

COUNT_SQL = """
SELECT count(*) AS n
FROM sense_definition sd
WHERE sd.lang_code = 'sw'
  AND sd.source_id = %s
  AND (sd.is_ai_generated IS NOT TRUE OR sd.review_status IS NULL)
  AND coalesce(sd.review_status, 'unreviewed') NOT IN ('approved', 'edited', 'rejected')
"""

SKIPPED_SQL = """
SELECT coalesce(review_status, 'NULL') AS review_status, count(*) AS n
FROM sense_definition
WHERE lang_code = 'sw'
  AND source_id = %s
  AND review_status IN ('approved', 'edited', 'rejected')
GROUP BY review_status
ORDER BY review_status
"""

UPDATE_SQL = """
UPDATE sense_definition sd
SET is_ai_generated = true,
    review_status = 'unreviewed',
    ai_model = coalesce(sd.ai_model, %s),
    ai_prompt_version = coalesce(sd.ai_prompt_version, %s)
WHERE sd.lang_code = 'sw'
  AND sd.source_id = %s
  AND (sd.is_ai_generated IS NOT TRUE OR sd.review_status IS NULL)
  AND coalesce(sd.review_status, 'unreviewed') NOT IN ('approved', 'edited', 'rejected')
"""

# Applied per sense when --jsonl supplies the original generation metadata.
UPDATE_ONE_SQL = """
UPDATE sense_definition
SET ai_model = coalesce(ai_model, %s),
    ai_prompt_version = coalesce(ai_prompt_version, %s)
WHERE lang_code = 'sw'
  AND source_id = %s
  AND sense_id = %s
"""

# search_entry rows written by an earlier publish may still carry the text of a
# now-hidden definition, which would leak it through /search.
STALE_INDEX_SQL = """
SELECT count(*) AS n
FROM search_entry se
JOIN sense_definition sd ON sd.id = se.target_id
WHERE se.target_type = 'definition'
  AND sd.lang_code = 'sw'
  AND sd.is_ai_generated = true
  AND coalesce(sd.review_status, 'unreviewed') NOT IN ('approved', 'edited')
"""

DELETE_STALE_INDEX_SQL = """
DELETE FROM search_entry se
USING sense_definition sd
WHERE sd.id = se.target_id
  AND se.target_type = 'definition'
  AND sd.lang_code = 'sw'
  AND sd.is_ai_generated = true
  AND coalesce(sd.review_status, 'unreviewed') NOT IN ('approved', 'edited')
"""


def load_jsonl_metadata(path: Path) -> dict[str, tuple[str, str]]:
    """Map sense_id -> (model, prompt_version) from a generator output file."""
    metadata: dict[str, tuple[str, str]] = {}
    with path.open("r", encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            if not line:
                continue
            row = json.loads(line)
            sense_id = row.get("sense_id")
            if not sense_id:
                continue
            metadata[str(sense_id)] = (
                row.get("model") or "unknown",
                row.get("prompt_version") or "unknown",
            )
    return metadata


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--apply", action="store_true", help="commit the changes (default: dry run)")
    parser.add_argument("--jsonl", type=Path, help="generator output, to restore per-row model/prompt_version")
    parser.add_argument("--model", default="gpt-4o-mini", help="fallback ai_model value")
    parser.add_argument("--prompt-version", default="v1", help="fallback ai_prompt_version value")
    parser.add_argument("--limit-preview", type=int, default=10, help="rows to show in the preview")
    parser.add_argument(
        "--prune-search-index",
        action="store_true",
        help="also delete search_entry rows for AI Swahili definitions that are now hidden",
    )
    args = parser.parse_args()

    db_url = os.getenv("KAMUSI_DB_URL", DEFAULT_DB_URL)
    source_id = os.getenv("AI_SOURCE_ID")

    if not source_id:
        print("❌ AI_SOURCE_ID is not set. It must be the source uuid used when importing.")
        print('   export AI_SOURCE_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"')
        return 1
    try:
        uuid.UUID(source_id)
    except ValueError:
        print(f"❌ AI_SOURCE_ID is not a valid UUID: {source_id}")
        return 1

    jsonl_metadata: dict[str, tuple[str, str]] = {}
    if args.jsonl:
        if not args.jsonl.exists():
            print(f"❌ JSONL not found: {args.jsonl.resolve()}")
            return 1
        jsonl_metadata = load_jsonl_metadata(args.jsonl)
        print(f"Loaded generation metadata for {len(jsonl_metadata)} senses from {args.jsonl}")

    mode = "APPLY" if args.apply else "DRY RUN"
    print(f"Mode:       {mode}")
    print(f"Database:   {db_url}")
    print(f"AI source:  {source_id}")
    print()

    with psycopg.connect(db_url, row_factory=dict_row) as conn:
        with conn.cursor() as cur:
            cur.execute(COUNT_SQL, (source_id,))
            to_fix = cur.fetchone()["n"]

            cur.execute(SKIPPED_SQL, (source_id,))
            already_reviewed = cur.fetchall()

            cur.execute(STALE_INDEX_SQL)
            stale_index = cur.fetchone()["n"]

            print(f"Rows needing provenance repair: {to_fix}")
            if already_reviewed:
                detail = ", ".join(f"{row['review_status']}={row['n']}" for row in already_reviewed)
                print(f"Rows left alone (human already acted): {detail}")
            print(f"search_entry rows exposing hidden AI definitions: {stale_index}")
            print()

            if to_fix == 0 and stale_index == 0:
                print("Nothing to do.")
                return 0

            if to_fix and args.limit_preview:
                cur.execute(PREVIEW_SQL, (source_id,))
                rows = cur.fetchall()
                print(f"Preview (first {min(args.limit_preview, len(rows))} of {len(rows)}):")
                for row in rows[: args.limit_preview]:
                    print(
                        f"  {row['lemma']:<20} ai={row['is_ai_generated']!s:<5} "
                        f"status={row['review_status'] or 'NULL':<10} {row['preview']}"
                    )
                print()

            if not args.apply:
                print("Dry run: nothing written. Re-run with --apply to commit.")
                return 0

            cur.execute(UPDATE_SQL, (args.model, args.prompt_version, source_id))
            changed = cur.rowcount

            refined = 0
            for sense_id, (model, prompt_version) in jsonl_metadata.items():
                cur.execute(UPDATE_ONE_SQL, (model, prompt_version, source_id, sense_id))
                refined += cur.rowcount

            pruned = 0
            if args.prune_search_index:
                cur.execute(DELETE_STALE_INDEX_SQL)
                pruned = cur.rowcount

            conn.commit()

    print(f"✅ Tagged {changed} definitions as is_ai_generated=true, review_status='unreviewed'")
    if jsonl_metadata:
        print(f"   Restored model/prompt_version on {refined} rows from the JSONL")
    if args.prune_search_index:
        print(f"   Removed {pruned} stale search_entry rows")
    print()
    print("Those definitions are now hidden from the public API and visible in")
    print("the admin review queue at /review.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
