#!/usr/bin/env python3
"""Approve AI Swahili definitions in bulk, after screening them.

An unreviewed AI definition is invisible to readers by design, so a corpus of
them is a corpus nobody can use. Reviewing each one in the console is the
right thing when a person is reading each one; it is not a way to clear
several hundred that a quality gate has already judged clean.

What this is, honestly
----------------------
This is **not** a person having read each definition. It approves what
`app.core.quality.check_definition` finds no fault with, and it records that
in `review_note` so the audit trail never implies otherwise. Anything the gate
objects to is left for a human, because that is exactly the set worth a
person's attention.

Approval is a real editorial act: it makes the text visible to readers. So it
takes `--reviewer`, which must name the person accountable for the decision,
and it is a dry run until `--apply`.

Undo
----
An applied run writes a journal of the definitions it touched;
`--undo <journal>` returns them to unreviewed.

Usage
-----
    cd apps/api
    export DATABASE_URL="postgresql+psycopg://kamusi:kamusi123@localhost:5433/kamusi"

    python tools/maintenance/bulk_approve_ai_defs.py --reviewer you@example.com
    python tools/maintenance/bulk_approve_ai_defs.py --reviewer you@example.com --apply
    python tools/maintenance/bulk_approve_ai_defs.py --undo out/bulk_approve-<stamp>.jsonl
"""
from __future__ import annotations

import argparse
import json
import random
import sys
from datetime import datetime, timezone
from pathlib import Path

from sqlalchemy import select, text, update

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from app.core.quality import check_definition  # noqa: E402
from app.db import SessionLocal  # noqa: E402
from app.models import SenseDefinition  # noqa: E402

BATCH_SIZE = 200

CANDIDATES = """
SELECT sd.id, sd.definition AS sw, l.lemma, en.definition AS en
FROM sense_definition sd
JOIN sense s ON s.id = sd.sense_id
JOIN lexeme l ON l.id = s.lexeme_id
LEFT JOIN sense_definition en
       ON en.sense_id = s.id AND en.lang_code = 'en'
WHERE sd.lang_code = 'sw'
  AND sd.is_ai_generated
  AND sd.review_status = 'unreviewed'
ORDER BY l.lemma
"""


def run_undo(db, journal: Path) -> int:
    if not journal.exists():
        print(f"❌ No journal at {journal}")
        return 1
    entries = [json.loads(line) for line in journal.read_text().splitlines() if line.strip()]
    if not entries:
        print("Journal is empty; nothing to undo.")
        return 0

    ids = [entry["definition_id"] for entry in entries]
    restored = 0
    for start in range(0, len(ids), BATCH_SIZE):
        chunk = ids[start : start + BATCH_SIZE]
        result = db.execute(
            update(SenseDefinition)
            .where(SenseDefinition.id.in_(chunk))
            .values(review_status="unreviewed", reviewed_by=None, reviewed_at=None, review_note=None)
        )
        restored += result.rowcount or 0
        db.commit()
    print(f"✅ Returned {restored} definitions to unreviewed.")
    print("   They are hidden from readers again and back in the review queue.")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("--reviewer", help="email of the person accountable for this approval")
    parser.add_argument("--apply", action="store_true", help="commit (default: dry run)")
    parser.add_argument("--limit", type=int, help="approve at most this many")
    parser.add_argument("--sample", type=int, default=12, help="definitions to show")
    parser.add_argument(
        "--note",
        help="what goes in review_note (default describes the bulk screening)",
    )
    parser.add_argument("--undo", type=Path, help="restore from a run's journal")
    parser.add_argument(
        "--journal-dir", type=Path, default=Path("out"), help="where to write the journal"
    )
    args = parser.parse_args()

    db = SessionLocal()
    try:
        if args.undo:
            return run_undo(db, args.undo)

        rows = db.execute(text(CANDIDATES)).all()
        clean, flagged = [], []
        for row in rows:
            problems = check_definition(row.sw, lemma=row.lemma, source_definition=row.en)
            (flagged if problems else clean).append((row, problems))

        print(f"Mode:     {'APPLY' if args.apply else 'DRY RUN'}")
        print(f"Unreviewed AI Swahili definitions: {len(rows)}")
        print(f"  clean by the quality gate:       {len(clean)}")
        print(f"  flagged, left for a human:       {len(flagged)}")
        print()

        if flagged:
            print("Left for review:")
            for row, problems in flagged[:8]:
                print(f"  {row.lemma:<18}{','.join(problems):<28}{row.sw[:40]}")
            if len(flagged) > 8:
                print(f"  ... and {len(flagged) - 8} more")
            print()

        selected = [row for row, _ in clean]
        if args.limit:
            selected = selected[: args.limit]

        if selected and args.sample:
            # Random rather than the first N: the first N by lemma are not a
            # fair look at what you are about to make visible.
            print(f"Random sample of {min(args.sample, len(selected))} to be approved:")
            for row in random.Random(0).sample(selected, min(args.sample, len(selected))):
                print(f"  {row.lemma:<18}{row.sw[:58]}")
            print()

        if not selected:
            print("Nothing to approve.")
            return 0

        if not args.apply:
            print(f"Dry run: nothing approved. {len(selected)} would become visible to readers.")
            print("Read the sample above, then re-run with --reviewer <email> --apply.")
            return 0

        if not args.reviewer or "@" not in args.reviewer:
            print("❌ --reviewer <email> is required to approve.")
            print("   Approval makes text visible to readers; the audit trail has to")
            print("   name the person accountable for that, not a script.")
            return 1

        note = args.note or (
            "Bulk approval: passed app.core.quality.check_definition with no "
            "objection. Not individually read."
        )
        stamp = datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S")
        args.journal_dir.mkdir(parents=True, exist_ok=True)
        journal_path = args.journal_dir / f"bulk_approve-{stamp}.jsonl"

        now = datetime.utcnow()
        approved = 0
        with journal_path.open("w", encoding="utf-8") as journal:
            for start in range(0, len(selected), BATCH_SIZE):
                chunk = selected[start : start + BATCH_SIZE]
                for row in chunk:
                    journal.write(
                        json.dumps(
                            {"definition_id": str(row.id), "lemma": row.lemma},
                            ensure_ascii=False,
                        )
                        + "\n"
                    )
                journal.flush()
                result = db.execute(
                    update(SenseDefinition)
                    .where(
                        SenseDefinition.id.in_([row.id for row in chunk]),
                        # Guard against a row a human reviewed while this ran.
                        SenseDefinition.review_status == "unreviewed",
                    )
                    .values(
                        review_status="approved",
                        reviewed_by=args.reviewer,
                        reviewed_at=now,
                        review_note=note,
                    )
                )
                approved += result.rowcount or 0
                db.commit()
                print(f"  {min(start + BATCH_SIZE, len(selected)):>6,} / {len(selected):,}", flush=True)

        print()
        print(f"✅ Approved {approved} definitions as {args.reviewer}")
        print(f"   review_note: {note}")
        print(f"   journal:     {journal_path}")
        print("Undo with:")
        print(f"   python tools/maintenance/bulk_approve_ai_defs.py --undo {journal_path}")
        print()
        print("These are now visible to readers, so the lexemes carrying them can")
        print("be published: tools/maintenance/bulk_publish.py")
        return 0
    finally:
        db.close()


if __name__ == "__main__":
    sys.exit(main())
