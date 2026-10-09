#!/usr/bin/env python3
"""Recompute every stored normalization key with the current ``normalize_sw``.

Why this exists
---------------
``normalize_sw`` used to turn dashes and apostrophes into spaces, so ``ng'ombe``
indexed as ``ng ombe`` and a reader typing ``ngombe`` found nothing. It now
drops them instead, which is what ``tests/test_normalize.py`` always specified.

That changes the key, so values already stored in the database are stale and
must be recomputed. Queries normalize at request time, so until this runs,
search misses any row whose lemma or text contains a dash or apostrophe.

Columns rebuilt
---------------
* ``search_entry.normalized``   — no uniqueness, always safe to rewrite
* ``expression.normalized_text`` — no uniqueness, always safe to rewrite
* ``wordform.normalized_form``   — no uniqueness, always safe to rewrite
* ``lexeme.normalized_lemma``    — part of ``ux_lexeme_norm_pos``
  (normalized_lemma, pos_id), so a rewrite can collide with a sibling row.
  Collisions are reported and skipped; nothing is merged or deleted
  automatically, because deciding which of two lexemes survives is an
  editorial call, not a mechanical one.

Safety
------
Dry run by default. Pass ``--apply`` to commit.

Usage
-----
    export KAMUSI_DB_URL="postgresql://kamusi:kamusi123@localhost:5433/kamusi"

    python tools/maintenance/reindex_normalized.py            # report only
    python tools/maintenance/reindex_normalized.py --apply    # commit
"""
from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

import psycopg
from psycopg.rows import dict_row

# Allow running the file directly from apps/api without installing the package.
sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from app.normalize import normalize_sw  # noqa: E402

DEFAULT_DB_URL = "postgresql://kamusi:kamusi123@localhost:5433/kamusi"

# table, id column, source text column, normalized column
SIMPLE_TARGETS = [
    ("search_entry", "id", "text", "normalized"),
    ("expression", "id", "text", "normalized_text"),
    ("wordform", "id", "form", "normalized_form"),
]


def reindex_simple(cur, table: str, id_col: str, text_col: str, norm_col: str, apply: bool) -> tuple[int, int]:
    cur.execute(f"SELECT {id_col} AS id, {text_col} AS text, {norm_col} AS norm FROM {table}")
    rows = cur.fetchall()
    stale = [row for row in rows if normalize_sw(row["text"] or "") != (row["norm"] or "")]

    if apply and stale:
        cur.executemany(
            f"UPDATE {table} SET {norm_col} = %s WHERE {id_col} = %s",
            [(normalize_sw(row["text"] or ""), row["id"]) for row in stale],
        )
    return len(rows), len(stale)


def reindex_lexemes(cur, apply: bool, show: int) -> tuple[int, int, list[dict]]:
    cur.execute("SELECT id, lemma, normalized_lemma, pos_id FROM lexeme")
    rows = cur.fetchall()

    # Existing keys, so we can spot a rewrite landing on an occupied slot.
    occupied: dict[tuple[str, str], str] = {}
    for row in rows:
        occupied[(row["normalized_lemma"], str(row["pos_id"]))] = str(row["id"])

    stale = []
    collisions = []
    for row in rows:
        new_norm = normalize_sw(row["lemma"] or "")
        if new_norm == row["normalized_lemma"]:
            continue
        key = (new_norm, str(row["pos_id"]))
        holder = occupied.get(key)
        if holder and holder != str(row["id"]):
            collisions.append(
                {
                    "id": str(row["id"]),
                    "lemma": row["lemma"],
                    "old": row["normalized_lemma"],
                    "new": new_norm,
                    "conflicts_with": holder,
                }
            )
            continue
        stale.append((new_norm, row["id"]))
        occupied[key] = str(row["id"])

    if apply and stale:
        cur.executemany("UPDATE lexeme SET normalized_lemma = %s WHERE id = %s", stale)

    if collisions:
        print(f"  ⚠️  {len(collisions)} lexeme(s) skipped: the new key is already taken")
        for row in collisions[:show]:
            print(
                f"     {row['lemma']:<20} {row['old']!r} -> {row['new']!r} "
                f"collides with lexeme {row['conflicts_with']}"
            )
        if len(collisions) > show:
            print(f"     ... and {len(collisions) - show} more")
        print("     These are duplicate entries under the new key. Merge or retire")
        print("     one of each pair in the admin portal, then re-run.")

    return len(rows), len(stale), collisions


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--apply", action="store_true", help="commit the changes (default: dry run)")
    parser.add_argument("--show", type=int, default=10, help="collisions to list")
    args = parser.parse_args()

    db_url = os.getenv("KAMUSI_DB_URL", DEFAULT_DB_URL)
    mode = "APPLY" if args.apply else "DRY RUN"
    print(f"Mode:     {mode}")
    print(f"Database: {db_url}")
    print()

    total_stale = 0
    with psycopg.connect(db_url, row_factory=dict_row) as conn:
        with conn.cursor() as cur:
            for table, id_col, text_col, norm_col in SIMPLE_TARGETS:
                seen, stale = reindex_simple(cur, table, id_col, text_col, norm_col, args.apply)
                total_stale += stale
                print(f"{table}.{norm_col}: {stale} stale of {seen}")

            print("lexeme.normalized_lemma:")
            seen, stale, collisions = reindex_lexemes(cur, args.apply, args.show)
            total_stale += stale
            print(f"  {stale} stale of {seen} rewritten, {len(collisions)} skipped")

            if args.apply:
                conn.commit()

    print()
    if total_stale == 0:
        print("Everything already matches the current normalizer.")
    elif args.apply:
        print(f"✅ Rewrote {total_stale} normalization keys.")
    else:
        print(f"Dry run: {total_stale} rows would change. Re-run with --apply to commit.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
