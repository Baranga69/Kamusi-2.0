#!/usr/bin/env python3
"""Undo a bulk import.

Importing at volume means sometimes discovering afterwards that a batch was
wrong — a bad part-of-speech mapping, a prompt that produced nonsense, a
source that turned out to be mislicensed. Without a way to undo one batch, the
only recovery is restoring the whole database, which also throws away every
good edit made since.

What it refuses to delete
-------------------------
Reverting removes content, so it is deliberately conservative. It will not
touch:

* **a definition a human has acted on** — approved, edited or rejected. That
  is a person's work and a record of their judgement. Reviewing something is
  also a decision that it should exist.
* **a sense that still has definitions** from another run or from hand
  authoring, and a lexeme that still has such senses. A later import or an
  editor may have built on what this one created.

Anything skipped is reported with the reason. A partial revert is the right
outcome when a human has since engaged with part of the batch — the
alternative is destroying their work.

Safety
------
Dry run by default. Pass ``--apply`` to commit. Take a backup first; this is
the one tool here that deletes content.

Usage
-----
    cd apps/api
    export DATABASE_URL="postgresql+psycopg://kamusi:kamusi123@localhost:5433/kamusi"

    python tools/maintenance/revert_import.py --list
    python tools/maintenance/revert_import.py <run-id>            # dry run
    python tools/maintenance/revert_import.py <run-id> --apply
"""
from __future__ import annotations

import argparse
import sys
import uuid
from pathlib import Path

from sqlalchemy import text

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from app.db import SessionLocal  # noqa: E402

LIST_RUNS = """
SELECT r.id, r.kind, r.tool, r.status, r.started_at, r.finished_at,
       r.lexemes_created, r.senses_created, r.definitions_created,
       s.title AS source_title
FROM import_run r
LEFT JOIN source s ON s.id = r.source_id
ORDER BY r.started_at DESC
LIMIT :limit
"""

RUN = """
SELECT r.*, s.title AS source_title
FROM import_run r
LEFT JOIN source s ON s.id = r.source_id
WHERE r.id = :run_id
"""

# What the run still owns, now.
OWNED = """
SELECT
    (SELECT count(*) FROM lexeme WHERE import_run_id = :run_id) AS lexemes,
    (SELECT count(*) FROM sense WHERE import_run_id = :run_id) AS senses,
    (SELECT count(*) FROM sense_definition WHERE import_run_id = :run_id) AS definitions
"""

# Definitions a person has already judged. Reviewing something is also a
# decision that it should exist.
REVIEWED = """
SELECT coalesce(review_status, 'unreviewed') AS review_status, count(*) AS n
FROM sense_definition
WHERE import_run_id = :run_id
  AND review_status IN ('approved', 'edited', 'rejected')
GROUP BY review_status
ORDER BY review_status
"""

DELETE_DEFINITIONS = """
DELETE FROM sense_definition
WHERE import_run_id = :run_id
  AND coalesce(review_status, 'unreviewed') NOT IN ('approved', 'edited', 'rejected')
"""

# Only senses this run created that nothing is left hanging off.
DELETE_SENSES = """
DELETE FROM sense
WHERE import_run_id = :run_id
  AND NOT EXISTS (SELECT 1 FROM sense_definition d WHERE d.sense_id = sense.id)
  AND NOT EXISTS (SELECT 1 FROM example e WHERE e.sense_id = sense.id)
"""

DELETE_LEXEMES = """
DELETE FROM lexeme
WHERE import_run_id = :run_id
  AND NOT EXISTS (SELECT 1 FROM sense s WHERE s.lexeme_id = lexeme.id)
"""

# search_entry has no foreign keys, so it has to be cleaned explicitly.
PRUNE_INDEX = """
DELETE FROM search_entry
WHERE (target_type = 'lexeme'
       AND NOT EXISTS (SELECT 1 FROM lexeme l WHERE l.id = search_entry.target_id))
   OR (target_type = 'definition'
       AND NOT EXISTS (SELECT 1 FROM sense_definition d WHERE d.id = search_entry.target_id))
   OR (target_type = 'example'
       AND NOT EXISTS (SELECT 1 FROM example_text t WHERE t.id = search_entry.target_id))
"""

KEPT_SENSES = """
SELECT count(*) AS n
FROM sense s
WHERE s.import_run_id = :run_id
  AND EXISTS (SELECT 1 FROM sense_definition d WHERE d.sense_id = s.id)
"""

KEPT_LEXEMES = """
SELECT count(*) AS n
FROM lexeme l
WHERE l.import_run_id = :run_id
  AND EXISTS (SELECT 1 FROM sense s WHERE s.lexeme_id = l.id)
"""

SAMPLE = """
SELECT l.lemma, left(d.definition, 48) AS preview,
       coalesce(d.review_status, 'unreviewed') AS review_status
FROM sense_definition d
JOIN sense s ON s.id = d.sense_id
JOIN lexeme l ON l.id = s.lexeme_id
WHERE d.import_run_id = :run_id
ORDER BY l.lemma
LIMIT :limit
"""


def show_runs(db, limit: int) -> int:
    rows = db.execute(text(LIST_RUNS), {"limit": limit}).all()
    if not rows:
        print("No imports recorded yet.")
        print()
        print("Runs are recorded from migration 0007 onwards. Anything loaded")
        print("before that has no run to revert.")
        return 0

    print(f"{'started':<22}{'kind':<16}{'status':<11}{'lex':>7}{'sen':>7}{'def':>7}  id")
    for row in rows:
        started = row.started_at.strftime("%Y-%m-%d %H:%M:%S")
        print(
            f"{started:<22}{row.kind:<16}{row.status:<11}"
            f"{row.lexemes_created:>7}{row.senses_created:>7}{row.definitions_created:>7}  {row.id}"
        )
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("run_id", nargs="?", help="the import to revert")
    parser.add_argument("--list", action="store_true", help="show recent imports")
    parser.add_argument("--limit", type=int, default=20, help="rows for --list")
    parser.add_argument("--apply", action="store_true", help="commit (default: dry run)")
    parser.add_argument("--sample", type=int, default=8, help="rows to preview")
    args = parser.parse_args()

    db = SessionLocal()
    try:
        if args.list or not args.run_id:
            return show_runs(db, args.limit)

        try:
            run_id = str(uuid.UUID(args.run_id))
        except ValueError:
            print(f"❌ Not a run id: {args.run_id}")
            return 1

        run = db.execute(text(RUN), {"run_id": run_id}).first()
        if not run:
            print(f"❌ No import run {run_id}. Try --list.")
            return 1

        print(f"Import run {run.id}")
        print(f"  kind:    {run.kind} ({run.tool})")
        print(f"  source:  {run.source_title or '-'}")
        print(f"  input:   {run.input_path or '-'}")
        print(f"  started: {run.started_at}")
        print(f"  status:  {run.status}")
        print()

        if run.status == "reverted":
            print("Already reverted. Nothing to do.")
            return 0

        owned = db.execute(text(OWNED), {"run_id": run_id}).one()
        print("Still owned by this run:")
        print(f"  lexemes:     {owned.lexemes}")
        print(f"  senses:      {owned.senses}")
        print(f"  definitions: {owned.definitions}")
        print()

        if not (owned.lexemes or owned.senses or owned.definitions):
            print("This run owns nothing — already undone, or its rows were reassigned.")
            return 0

        reviewed = db.execute(text(REVIEWED), {"run_id": run_id}).all()
        if reviewed:
            total = sum(row.n for row in reviewed)
            detail = ", ".join(f"{row.review_status}={row.n}" for row in reviewed)
            print(f"⚠️  {total} definitions have been reviewed ({detail}).")
            print("    Those are kept: reviewing something is also a decision that")
            print("    it should exist, and the judgement is a person's work.")
            print()

        sample = db.execute(text(SAMPLE), {"run_id": run_id, "limit": args.sample}).all()
        if sample:
            print(f"Sample of what this run created:")
            for row in sample:
                mark = " " if row.review_status == "unreviewed" else "*"
                print(f" {mark} {row.lemma:<18} {row.preview}")
            if owned.definitions > len(sample):
                print(f"   ... and {owned.definitions - len(sample)} more")
            print("   (* reviewed — will be kept)")
            print()

        if not args.apply:
            print("Dry run: nothing deleted. Re-run with --apply to commit.")
            print("Take a backup first — this is the one tool here that removes content.")
            return 0

        definitions = db.execute(text(DELETE_DEFINITIONS), {"run_id": run_id}).rowcount or 0
        senses = db.execute(text(DELETE_SENSES), {"run_id": run_id}).rowcount or 0
        lexemes = db.execute(text(DELETE_LEXEMES), {"run_id": run_id}).rowcount or 0
        orphaned_index = db.execute(text(PRUNE_INDEX)).rowcount or 0

        kept_senses = db.execute(text(KEPT_SENSES), {"run_id": run_id}).one().n
        kept_lexemes = db.execute(text(KEPT_LEXEMES), {"run_id": run_id}).one().n

        db.execute(
            text("UPDATE import_run SET status = 'reverted' WHERE id = :run_id"),
            {"run_id": run_id},
        )
        db.commit()
    finally:
        db.close()

    print("✅ Reverted")
    print(f"   definitions removed: {definitions}")
    print(f"   senses removed:      {senses}")
    print(f"   lexemes removed:     {lexemes}")
    print(f"   search entries tidied: {orphaned_index}")
    if kept_senses or kept_lexemes:
        print()
        print(f"   kept {kept_lexemes} lexemes and {kept_senses} senses that still have")
        print("   content — reviewed definitions, or rows a later import added.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
