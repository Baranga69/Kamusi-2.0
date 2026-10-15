#!/usr/bin/env python3
"""Turn recorded lookups into `search_entry.popularity`.

`popularity` has been in the result ordering since the schema was written and
nothing ever set it, so it was always 0 and ranking was purely match shape.
`lookup_event` records which entries people open; this rolls that up.

What gets credited
------------------
A lookup is recorded against the *entry* someone opened, but a lexeme owns
several search entries — its headword, each definition, each example. Crediting
only the headword would mean a definition hit for a common word never rises,
so the count for a lexeme is applied to every entry that resolves back to it:

    lexeme              -> the lexeme's own entry
    definition          -> via sense_definition -> sense -> lexeme
    example             -> via example_text -> example -> sense -> lexeme
    expression          -> the expression's own entry
    expression_meaning  -> via expression_meaning -> expression

A window, not a lifetime
------------------------
Counts come from the last `--days` (default 90). Popularity should reflect
what people are looking up now, not what was popular when the corpus was
first loaded — a lifetime total would freeze early traffic in place forever.
Re-running recomputes from the events rather than accumulating, so the window
genuinely slides.

Safety
------
Dry run by default. Pass `--apply` to commit.

Usage
-----
    cd apps/api
    export DATABASE_URL="postgresql+psycopg://kamusi:kamusi123@localhost:5433/kamusi"

    poetry run python tools/maintenance/aggregate_popularity.py             # report
    poetry run python tools/maintenance/aggregate_popularity.py --apply     # commit
    poetry run python tools/maintenance/aggregate_popularity.py --apply --prune-after 365

Worth running on a schedule; nightly is plenty.
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

from sqlalchemy import text

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from app.db import SessionLocal  # noqa: E402

# Counts per lexeme / expression over the window, as a CTE the updates share.
RECENT = """
WITH recent AS (
    SELECT target_type, target_id, count(*) AS hits
    FROM lookup_event
    WHERE occurred_at >= now() - make_interval(days => :days)
    GROUP BY target_type, target_id
)
"""

# One statement per search_entry target type, each joining back to the record
# the lookup was recorded against.
UPDATES = {
    "lexeme": RECENT
    + """
UPDATE search_entry se
SET popularity = recent.hits
FROM recent
WHERE se.target_type = 'lexeme'
  AND recent.target_type = 'lexeme'
  AND recent.target_id = se.target_id
  AND se.popularity IS DISTINCT FROM recent.hits
""",
    "definition": RECENT
    + """
UPDATE search_entry se
SET popularity = recent.hits
FROM recent, sense_definition sd
JOIN sense s ON s.id = sd.sense_id
WHERE se.target_type = 'definition'
  AND sd.id = se.target_id
  AND recent.target_type = 'lexeme'
  AND recent.target_id = s.lexeme_id
  AND se.popularity IS DISTINCT FROM recent.hits
""",
    "example": RECENT
    + """
UPDATE search_entry se
SET popularity = recent.hits
FROM recent, example_text et
JOIN example e ON e.id = et.example_id
JOIN sense s ON s.id = e.sense_id
WHERE se.target_type = 'example'
  AND et.id = se.target_id
  AND recent.target_type = 'lexeme'
  AND recent.target_id = s.lexeme_id
  AND se.popularity IS DISTINCT FROM recent.hits
""",
    "expression": RECENT
    + """
UPDATE search_entry se
SET popularity = recent.hits
FROM recent
WHERE se.target_type = 'expression'
  AND recent.target_type = 'expression'
  AND recent.target_id = se.target_id
  AND se.popularity IS DISTINCT FROM recent.hits
""",
    "expression_meaning": RECENT
    + """
UPDATE search_entry se
SET popularity = recent.hits
FROM recent, expression_meaning em
WHERE se.target_type = 'expression_meaning'
  AND em.id = se.target_id
  AND recent.target_type = 'expression'
  AND recent.target_id = em.expression_id
  AND se.popularity IS DISTINCT FROM recent.hits
""",
}

# Entries nobody opened in the window fall back to zero, so popularity decays
# instead of remembering a burst forever.
RESET = """
UPDATE search_entry
SET popularity = 0
WHERE popularity <> 0
"""

SUMMARY = """
SELECT count(*) AS events,
       count(DISTINCT target_id) AS entries,
       min(occurred_at) AS oldest,
       max(occurred_at) AS newest
FROM lookup_event
WHERE occurred_at >= now() - make_interval(days => :days)
"""

TOP = """
SELECT l.lemma AS name, count(*) AS hits
FROM lookup_event le
JOIN lexeme l ON l.id = le.target_id
WHERE le.target_type = 'lexeme'
  AND le.occurred_at >= now() - make_interval(days => :days)
GROUP BY l.lemma
ORDER BY count(*) DESC, l.lemma
LIMIT :limit
"""

PRUNE = """
DELETE FROM lookup_event
WHERE occurred_at < now() - make_interval(days => :days)
"""


def main() -> int:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("--apply", action="store_true", help="commit (default: dry run)")
    parser.add_argument("--days", type=int, default=90, help="window to count over")
    parser.add_argument(
        "--prune-after",
        type=int,
        help="also delete events older than this many days",
    )
    parser.add_argument("--top", type=int, default=10, help="most-looked-up to show")
    args = parser.parse_args()

    mode = "APPLY" if args.apply else "DRY RUN"
    print(f"Mode:   {mode}")
    print(f"Window: last {args.days} days")
    print()

    db = SessionLocal()
    try:
        summary = db.execute(text(SUMMARY), {"days": args.days}).one()
        print(f"Lookups recorded: {summary.events} across {summary.entries} entries")
        if summary.events == 0 and not args.apply:
            print()
            print("Nothing to aggregate yet. Popularity fills in as people use the app.")
            return 0
        # With --apply we carry on even at zero: if nobody has opened anything
        # in the window, popularity should fall to zero rather than keep
        # reporting a burst from months ago.
        print(f"  oldest: {summary.oldest}")
        print(f"  newest: {summary.newest}")
        print()

        top = db.execute(text(TOP), {"days": args.days, "limit": args.top}).all()
        if top:
            print(f"Most looked up:")
            for row in top:
                print(f"  {row.hits:>6}  {row.name}")
            print()

        if not args.apply:
            print("Dry run: nothing written. Re-run with --apply to commit.")
            return 0

        # Reset first so an entry that stopped being opened returns to zero.
        reset = db.execute(text(RESET)).rowcount or 0
        updated = {}
        for target_type, statement in UPDATES.items():
            updated[target_type] = (
                db.execute(text(statement), {"days": args.days}).rowcount or 0
            )

        pruned = 0
        if args.prune_after:
            pruned = db.execute(text(PRUNE), {"days": args.prune_after}).rowcount or 0

        db.commit()
    finally:
        db.close()

    total = sum(updated.values())
    print(f"✅ Popularity rebuilt from {summary.events} lookups")
    print(f"   cleared:  {reset} entries")
    for target_type, count in updated.items():
        print(f"   {target_type + ':':<20}{count}")
    print(f"   total updated: {total}")
    if args.prune_after:
        print(f"   pruned {pruned} events older than {args.prune_after} days")
    return 0


if __name__ == "__main__":
    sys.exit(main())
