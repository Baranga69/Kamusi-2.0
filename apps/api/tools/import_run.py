"""Bookkeeping for a bulk import, shared by the ingest tools.

Every row an import creates carries the id of the run that created it, so a
batch that turns out to be wrong can be found and undone without restoring the
whole database. See `tools/maintenance/revert_import.py`.

The ingest tools talk to Postgres through psycopg rather than SQLAlchemy, so
this is deliberately plain SQL with no ORM dependency.

Typical use:

    with import_run(conn, kind="ai_definitions", tool="import_ai_defs.py",
                    source_id=source_id, input_path=str(path),
                    parameters={"on_conflict": "skip"}) as run:
        ...
        run.counts["definitions_created"] += 1

The run is marked `completed` on a clean exit and `failed` if the block
raises — and a failed run is still recorded, because an import that died
half-way is exactly the kind you need to be able to find and undo.
"""
from __future__ import annotations

import json
import uuid
from contextlib import contextmanager
from dataclasses import dataclass, field


@dataclass
class RunHandle:
    """A live import run. Mutate `counts`; the context manager records them."""

    id: uuid.UUID
    counts: dict[str, int] = field(
        default_factory=lambda: {
            "lexemes_created": 0,
            "senses_created": 0,
            "definitions_created": 0,
        }
    )

    def __str__(self) -> str:  # so tools can print it without ceremony
        return str(self.id)


def table_has_import_tracking(conn) -> bool:
    """False on a database that has not reached migration 0007.

    The ingest tools stay usable against an older schema rather than refusing
    to run; they just cannot offer undo.
    """
    with conn.cursor() as cur:
        cur.execute(
            """
            SELECT 1
            FROM information_schema.columns
            WHERE table_name = 'sense_definition' AND column_name = 'import_run_id'
            """
        )
        return cur.fetchone() is not None


@contextmanager
def import_run(
    conn,
    *,
    kind: str,
    tool: str,
    source_id: str | None = None,
    input_path: str | None = None,
    parameters: dict | None = None,
    notes: str | None = None,
):
    """Record a run for the duration of the block.

    Yields a `RunHandle`, or `None` when the schema predates import tracking,
    so callers can write `run.id if run else None` and work either way.
    """
    if not table_has_import_tracking(conn):
        yield None
        return

    with conn.cursor() as cur:
        cur.execute(
            """
            INSERT INTO import_run (kind, tool, source_id, input_path, parameters, notes)
            VALUES (%s, %s, %s, %s, %s::jsonb, %s)
            RETURNING id
            """,
            (kind, tool, source_id, input_path, json.dumps(parameters or {}), notes),
        )
        run_id = cur.fetchone()["id"]
    # Committed immediately: if the import then dies hard, the run still
    # exists to be found, which is the whole point.
    conn.commit()

    handle = RunHandle(id=run_id)
    try:
        yield handle
    except BaseException:
        _finish(conn, handle, "failed")
        raise
    _finish(conn, handle, "completed")


def _finish(conn, handle: RunHandle, status: str) -> None:
    try:
        if status == "failed":
            # A failing import may have left the connection in an aborted
            # transaction; the bookkeeping write needs a clean one.
            conn.rollback()
        with conn.cursor() as cur:
            cur.execute(
                """
                UPDATE import_run
                SET status = %s,
                    finished_at = now(),
                    lexemes_created = %s,
                    senses_created = %s,
                    definitions_created = %s
                WHERE id = %s
                """,
                (
                    status,
                    handle.counts["lexemes_created"],
                    handle.counts["senses_created"],
                    handle.counts["definitions_created"],
                    handle.id,
                ),
            )
        conn.commit()
    except Exception as error:  # noqa: BLE001 - never mask the original failure
        print(f"⚠️  Could not record the end of import run {handle.id}: {error}")
