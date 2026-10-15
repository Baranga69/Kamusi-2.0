#!/usr/bin/env python3
"""Rebuild search_entry from the published content that should be in it.

Why this exists
---------------
``search_entry`` is a derived index, but nothing ever reconciled it with its
source. Entries were written on publish and never removed, so the table drifts:

* a lexeme or expression that is later archived or returned to draft keeps its
  rows, and used to stay searchable
* an AI Swahili definition that is still unreviewed may have been indexed by an
  older publish, exposing text the read path hides
* example texts and expression meanings were not indexed at all by older
  publishes, so those match kinds never produced hits
* a row whose owning record was deleted lingers as an orphan

``/search`` now filters on visibility at read time, so none of this leaks. This
script removes the drift from the table itself, which keeps the index small and
makes its contents mean what they say.

It computes the desired set of entries from truth and reconciles:
insert what is missing, refresh text that changed, delete what no longer
belongs. Running it twice in a row is a no-op.

Safety
------
Dry run by default. Pass ``--apply`` to commit.

Usage
-----
    cd apps/api
    export DATABASE_URL="postgresql+psycopg://kamusi:kamusi123@localhost:5433/kamusi"

    poetry run python tools/maintenance/rebuild_search_index.py            # report
    poetry run python tools/maintenance/rebuild_search_index.py --apply    # commit
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

from sqlalchemy import select

# Allow running the file directly from apps/api without installing the package.
sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from app.db import SessionLocal  # noqa: E402
from app.models import Expression, Lexeme, SearchEntry  # noqa: E402
from app.normalize import normalize_sw  # noqa: E402
from app.services.publish import is_publicly_visible  # noqa: E402

# (target_type, target_id, lang_code) -> text
DesiredIndex = dict[tuple[str, str, str], str]


def desired_entries(db) -> DesiredIndex:
    """Every entry a correct index would hold, derived from published content."""
    desired: DesiredIndex = {}

    lexemes = db.scalars(select(Lexeme).where(Lexeme.workflow == "published")).all()
    for lexeme in lexemes:
        desired[("lexeme", str(lexeme.id), lexeme.default_language_code)] = lexeme.lemma

        for sense in lexeme.senses:
            if sense.workflow != "published":
                continue
            for definition in sense.definitions:
                if not is_publicly_visible(definition):
                    continue
                desired[("definition", str(definition.id), definition.lang_code)] = (
                    definition.definition
                )
            for example in sense.examples:
                for text in example.texts:
                    desired[("example", str(text.id), text.lang_code)] = text.text

    expressions = db.scalars(select(Expression).where(Expression.workflow == "published")).all()
    for expression in expressions:
        desired[("expression", str(expression.id), "sw")] = expression.text
        for meaning in expression.meanings:
            desired[("expression_meaning", str(meaning.id), meaning.lang_code)] = meaning.meaning

    return desired


def main() -> int:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("--apply", action="store_true", help="commit the changes (default: dry run)")
    parser.add_argument("--show", type=int, default=10, help="examples to list per category")
    args = parser.parse_args()

    mode = "APPLY" if args.apply else "DRY RUN"
    print(f"Mode: {mode}")
    print()

    db = SessionLocal()
    try:
        desired = desired_entries(db)
        existing_rows = db.scalars(select(SearchEntry)).all()
        existing = {
            (row.target_type, str(row.target_id), row.lang_code): row for row in existing_rows
        }

        to_insert = sorted(set(desired) - set(existing))
        to_delete = sorted(set(existing) - set(desired))
        to_refresh = sorted(
            key
            for key in set(desired) & set(existing)
            if existing[key].text != desired[key]
            or existing[key].normalized != normalize_sw(desired[key])
        )

        print(f"Entries that should exist: {len(desired)}")
        print(f"Entries currently present: {len(existing)}")
        print()
        print(f"  insert  {len(to_insert)}")
        print(f"  refresh {len(to_refresh)}   (text or normalization key changed)")
        print(f"  delete  {len(to_delete)}   (unpublished, hidden, or orphaned)")
        print()

        for label, keys in (("insert", to_insert), ("delete", to_delete), ("refresh", to_refresh)):
            if not keys:
                continue
            print(f"{label} sample:")
            for target_type, target_id, lang in keys[: args.show]:
                text = desired.get((target_type, target_id, lang))
                if text is None:
                    text = existing[(target_type, target_id, lang)].text
                print(f"  {target_type:<18} {lang}  {text[:52]}")
            if len(keys) > args.show:
                print(f"  ... and {len(keys) - args.show} more")
            print()

        if not (to_insert or to_delete or to_refresh):
            print("Index already matches published content.")
            return 0

        if not args.apply:
            print("Dry run: nothing written. Re-run with --apply to commit.")
            return 0

        for key in to_delete:
            db.delete(existing[key])

        for key in to_refresh:
            row = existing[key]
            row.text = desired[key]
            row.normalized = normalize_sw(desired[key])

        for target_type, target_id, lang in to_insert:
            text = desired[(target_type, target_id, lang)]
            db.add(
                SearchEntry(
                    target_type=target_type,
                    target_id=target_id,
                    lang_code=lang,
                    text=text,
                    normalized=normalize_sw(text),
                )
            )

        db.commit()
    finally:
        db.close()

    print(
        f"✅ Rebuilt index: +{len(to_insert)} inserted, "
        f"~{len(to_refresh)} refreshed, -{len(to_delete)} removed."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
