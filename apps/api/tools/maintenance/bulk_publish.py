#!/usr/bin/env python3
"""Publish many lexemes at once, and put them back if it was wrong.

Publishing through the admin console is one lexeme and one click, which is
right when a person is reading each entry. It is not a way to release a corpus
of several thousand, and the server-side publish does no readiness checking of
its own, so a loop over every draft would happily publish entries that show a
reader nothing.

What it refuses to publish
--------------------------
Every candidate is screened by `app.services.publish.readiness_problems`, the
same rules the console shows. The one that matters most:

* **no visible Swahili definition** — a sense whose only Swahili definition is
  unreviewed AI has none a reader can see, because the review guard keeps it
  out of the index and the public endpoint hides it. Publishing it produces a
  word that looks complete in the database and empty in the app. This is why
  the review pass has to come first.

Morphology
----------
Senses flagged `is_morphology` are Wiktionary's "Passive form of -ona"
cross-references rather than definitions. Lexemes carrying them are skipped by
default; `--include-morphology` opts in once you have decided how the app
should present them.

Undo
----
Every applied run writes a journal of what it changed, with each lexeme's
previous workflow. `--undo <journal>` restores them.

Un-publishing does not touch `search_entry`: the index already holds rows for
draft content and `/search` filters by workflow, so restoring the workflow is
what makes an entry invisible again. Deleting the rows would also throw away
index entries that existed before this run.

Usage
-----
    cd apps/api
    export DATABASE_URL="postgresql+psycopg://kamusi:kamusi123@localhost:5433/kamusi"

    python tools/maintenance/bulk_publish.py                 # dry run, report
    python tools/maintenance/bulk_publish.py --limit 298 --apply
    python tools/maintenance/bulk_publish.py --undo out/bulk_publish-<stamp>.jsonl
"""
from __future__ import annotations

import argparse
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

from sqlalchemy import func, select
from sqlalchemy.orm import selectinload

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from app.db import SessionLocal  # noqa: E402
from app.models import Lexeme, Sense, SenseDefinition  # noqa: E402
from app.services.publish import (  # noqa: E402
    NotReady,
    publish_lexeme,
    readiness_problems,
)

BATCH_SIZE = 200


def candidates(db, *, include_morphology: bool, workflow: str | None):
    """Draft lexemes, with senses and definitions loaded for screening.

    `selectinload` because readiness walks every sense and definition: lazy
    loading would make this one query per entry per attribute, which at
    corpus scale is the difference between seconds and an afternoon.
    """
    stmt = (
        select(Lexeme)
        .options(
            selectinload(Lexeme.senses).selectinload(Sense.definitions),
            selectinload(Lexeme.senses).selectinload(Sense.examples),
        )
        .order_by(Lexeme.normalized_lemma)
    )
    if workflow:
        stmt = stmt.where(Lexeme.workflow == workflow)
    rows = db.scalars(stmt).unique().all()

    if include_morphology:
        return rows
    return [lx for lx in rows if not any(s.is_morphology for s in lx.senses)]


def screen(rows) -> tuple[list, dict[str, int]]:
    """Split candidates into publishable and a tally of why the rest are not."""
    ready, blocked = [], {}
    for lexeme in rows:
        problems = readiness_problems(lexeme)
        if problems:
            for problem in problems:
                blocked[problem] = blocked.get(problem, 0) + 1
        else:
            ready.append(lexeme)
    return ready, blocked


def run_undo(db, journal: Path) -> int:
    if not journal.exists():
        print(f"❌ No journal at {journal}")
        return 1

    entries = [json.loads(line) for line in journal.read_text().splitlines() if line.strip()]
    if not entries:
        print("Journal is empty; nothing to undo.")
        return 0

    print(f"Restoring {len(entries)} lexemes from {journal.name}")
    restored = 0
    for index, entry in enumerate(entries, start=1):
        lexeme = db.scalar(
            select(Lexeme)
            .options(selectinload(Lexeme.senses))
            .where(Lexeme.id == entry["lexeme_id"])
        )
        if not lexeme:
            continue
        lexeme.workflow = entry["previous_workflow"]
        previous_senses = entry.get("previous_sense_workflows", {})
        for sense in lexeme.senses:
            # Fall back to the lexeme's own previous state for a sense added
            # after the run; it was never published by us either way.
            sense.workflow = previous_senses.get(str(sense.id), entry["previous_workflow"])
        restored += 1
        if index % BATCH_SIZE == 0:
            db.commit()
            print(f"  {index:>6,} / {len(entries):,}", flush=True)
    db.commit()

    print(f"✅ Restored {restored} lexemes to their previous workflow.")
    print()
    print("search_entry was left alone: the index holds draft rows too and")
    print("/search filters by workflow, so these are hidden again already.")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("--apply", action="store_true", help="commit (default: dry run)")
    parser.add_argument("--limit", type=int, help="publish at most this many")
    parser.add_argument(
        "--include-morphology",
        action="store_true",
        help="also publish lexemes whose senses are grammatical cross-references",
    )
    parser.add_argument(
        "--workflow",
        default="draft",
        help="which workflow state to take candidates from (default: draft)",
    )
    parser.add_argument("--undo", type=Path, help="restore from a run's journal")
    parser.add_argument(
        "--journal-dir",
        type=Path,
        default=Path("out"),
        help="where to write the run journal (default: out/)",
    )
    parser.add_argument("--sample", type=int, default=8, help="entries to preview")
    args = parser.parse_args()

    db = SessionLocal()
    try:
        if args.undo:
            return run_undo(db, args.undo)

        rows = candidates(
            db, include_morphology=args.include_morphology, workflow=args.workflow
        )
        ready, blocked = screen(rows)

        total_drafts = db.scalar(
            select(func.count()).select_from(Lexeme).where(Lexeme.workflow == args.workflow)
        )
        print(f"Mode:       {'APPLY' if args.apply else 'DRY RUN'}")
        print(f"Candidates: {len(rows)} of {total_drafts} in '{args.workflow}'")
        if not args.include_morphology:
            print("            (morphology-only entries excluded)")
        print()
        print(f"Ready to publish:  {len(ready)}")
        print(f"Not ready:         {len(rows) - len(ready)}")
        if blocked:
            # Reasons sum to more than entries: one lexeme can fail several.
            for problem, count in sorted(blocked.items(), key=lambda p: (-p[1], p[0])):
                print(f"  {problem:<32}{count}")
        print()

        selected = ready[: args.limit] if args.limit else ready
        if args.limit:
            print(f"Limited to the first {len(selected)} by lemma.")
            print()

        if selected and args.sample:
            print("Sample of what would publish:")
            for lexeme in selected[: args.sample]:
                sw = next(
                    (
                        d.definition
                        for s in lexeme.senses
                        for d in s.definitions
                        if d.lang_code == "sw"
                    ),
                    "",
                )
                print(f"  {lexeme.lemma:<22}{sw[:52]}")
            if len(selected) > args.sample:
                print(f"  ... and {len(selected) - args.sample} more")
            print()

        if not selected:
            print("Nothing to publish.")
            if blocked.get("no_visible_swahili_definition"):
                print()
                print("Most entries are waiting on the review queue: an unreviewed AI")
                print("Swahili definition is not visible to a reader, so publishing")
                print("would produce an empty-looking entry. Approve them first.")
            return 0

        if not args.apply:
            print(f"Dry run: nothing published. Re-run with --apply to commit.")
            return 0

        stamp = datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S")
        args.journal_dir.mkdir(parents=True, exist_ok=True)
        journal_path = args.journal_dir / f"bulk_publish-{stamp}.jsonl"

        published, failed = 0, 0
        with journal_path.open("w", encoding="utf-8") as journal:
            for index, lexeme in enumerate(selected, start=1):
                # Written before the change, and flushed with its batch: a
                # journal that lags the work cannot undo it.
                journal.write(
                    json.dumps(
                        {
                            "lexeme_id": str(lexeme.id),
                            "lemma": lexeme.lemma,
                            "previous_workflow": lexeme.workflow,
                            "previous_sense_workflows": {
                                str(s.id): s.workflow for s in lexeme.senses
                            },
                        },
                        ensure_ascii=False,
                    )
                    + "\n"
                )
                try:
                    publish_lexeme(db, lexeme.id, require_ready=True)
                    published += 1
                except NotReady as error:
                    # Screened already, so this means the row changed under us.
                    print(f"  skipped {lexeme.lemma}: {error}")
                    failed += 1
                if index % BATCH_SIZE == 0:
                    journal.flush()
                    print(f"  {index:>6,} / {len(selected):,}", flush=True)

        print()
        print(f"✅ Published {published} lexemes")
        if failed:
            print(f"   skipped {failed} that stopped being ready")
        print(f"   journal: {journal_path}")
        print("Undo with:")
        print(f"   python tools/maintenance/bulk_publish.py --undo {journal_path}")
        return 0
    finally:
        db.close()


if __name__ == "__main__":
    sys.exit(main())
