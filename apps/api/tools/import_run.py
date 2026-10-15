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
    conn: object = None
    counts: dict[str, int] = field(
        default_factory=lambda: {
            "lexemes_created": 0,
            "senses_created": 0,
            "definitions_created": 0,
        }
    )
    # What an earlier attempt at this run already created. Tools report what
    # *this* attempt did, so the totals are baseline plus current — otherwise
    # a resumed run would report only its last leg.
    baseline: dict[str, int] = field(
        default_factory=lambda: {
            "lexemes_created": 0,
            "senses_created": 0,
            "definitions_created": 0,
        }
    )
    # Lines already written by an earlier attempt at this run. A resumed
    # import skips them.
    resume_from: int = 0
    processed_lines: int = 0
    total_lines: int | None = None

    def __str__(self) -> str:  # so tools can print it without ceremony
        return str(self.id)

    def totals(self) -> dict[str, int]:
        """Everything this run has created, across every attempt."""
        return {key: self.baseline[key] + value for key, value in self.counts.items()}

    def should_skip(self, line_number: int) -> bool:
        """True for lines an earlier attempt already committed."""
        return line_number <= self.resume_from

    def commit_batch(self, line_number: int) -> None:
        """Commit the work so far and record how far the input was read.

        The checkpoint is written in the *same transaction* as the rows it
        describes. Committing it separately would let the two drift apart the
        moment one failed, and a resume point that overstates progress silently
        skips data.
        """
        self.processed_lines = line_number
        totals = self.totals()
        with self.conn.cursor() as cur:
            cur.execute(
                """
                UPDATE import_run
                SET processed_lines = %s,
                    lexemes_created = %s,
                    senses_created = %s,
                    definitions_created = %s
                WHERE id = %s
                """,
                (
                    line_number,
                    totals["lexemes_created"],
                    totals["senses_created"],
                    totals["definitions_created"],
                    self.id,
                ),
            )
        self.conn.commit()

    def progress(self, line_number: int) -> str:
        if self.total_lines:
            share = line_number / self.total_lines * 100
            return f"  {line_number:>8,} / {self.total_lines:,} ({share:5.1f}%)"
        return f"  {line_number:>8,} lines"


def count_lines(path) -> int | None:
    """Lines in the input, for progress reporting. None if it cannot be read."""
    try:
        with open(path, "r", encoding="utf-8") as handle:
            return sum(1 for line in handle if line.strip())
    except OSError:
        return None


def resumable_runs(conn, kind: str | None = None) -> list[dict]:
    """Runs that stopped part-way and could be continued."""
    with conn.cursor() as cur:
        cur.execute(
            """
            SELECT id, kind, tool, input_path, status, processed_lines,
                   total_lines, started_at
            FROM import_run
            WHERE status IN ('running', 'failed')
              AND (%s::text IS NULL OR kind = %s::text)
            ORDER BY started_at DESC
            """,
            (kind, kind),
        )
        return list(cur.fetchall())


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
    resume: str | None = None,
    total_lines: int | None = None,
    dry_run: bool = False,
):
    """Record a run for the duration of the block.

    Yields a `RunHandle`, or `None` when the schema predates import tracking,
    so callers can write `run.id if run else None` and work either way.

    With `resume`, continues an existing run rather than starting one: its
    counts carry forward and `should_skip` covers the lines it already
    committed.

    With `dry_run`, the bookkeeping is written but never committed, so the
    caller's closing rollback discards the run record along with the content
    it describes. A dry run that left a run claiming rows it did not write
    would put a lie in the audit trail this exists to make trustworthy.
    """
    if not table_has_import_tracking(conn):
        yield None
        return

    if resume:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT id, status, processed_lines, lexemes_created,
                       senses_created, definitions_created
                FROM import_run WHERE id = %s
                """,
                (resume,),
            )
            existing = cur.fetchone()
        if not existing:
            raise SystemExit(f"No import run {resume} to resume.")
        if existing["status"] in ("completed", "reverted"):
            raise SystemExit(
                f"Import run {resume} is {existing['status']}; there is nothing to resume."
            )
        with conn.cursor() as cur:
            cur.execute(
                "UPDATE import_run SET status = 'running', total_lines = coalesce(%s, total_lines) WHERE id = %s",
                (total_lines, resume),
            )
        if not dry_run:
            conn.commit()
        handle = RunHandle(
            id=existing["id"],
            conn=conn,
            baseline={
                "lexemes_created": existing["lexemes_created"],
                "senses_created": existing["senses_created"],
                "definitions_created": existing["definitions_created"],
            },
            resume_from=existing["processed_lines"],
            processed_lines=existing["processed_lines"],
            total_lines=total_lines,
        )
        try:
            yield handle
        except BaseException:
            if not dry_run:
                _finish(conn, handle, "failed")
            raise
        if not dry_run:
            _finish(conn, handle, "completed")
        return

    with conn.cursor() as cur:
        cur.execute(
            """
            INSERT INTO import_run (kind, tool, source_id, input_path, parameters, notes, total_lines)
            VALUES (%s, %s, %s, %s, %s::jsonb, %s, %s)
            RETURNING id
            """,
            (
                kind,
                tool,
                source_id,
                input_path,
                json.dumps(parameters or {}),
                notes,
                total_lines,
            ),
        )
        run_id = cur.fetchone()["id"]
    # Committed immediately: if the import then dies hard, the run still
    # exists to be found, which is the whole point. A dry run leaves it
    # uncommitted so the caller's rollback takes it away again.
    if not dry_run:
        conn.commit()

    handle = RunHandle(id=run_id, conn=conn, total_lines=total_lines)
    try:
        yield handle
    except BaseException:
        if not dry_run:
            _finish(conn, handle, "failed")
        raise
    if not dry_run:
        _finish(conn, handle, "completed")


def _finish(conn, handle: RunHandle, status: str) -> None:
    totals = handle.totals()
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
                    processed_lines = greatest(processed_lines, %s),
                    lexemes_created = %s,
                    senses_created = %s,
                    definitions_created = %s
                WHERE id = %s
                """,
                (
                    status,
                    handle.processed_lines,
                    totals["lexemes_created"],
                    totals["senses_created"],
                    totals["definitions_created"],
                    handle.id,
                ),
            )
        conn.commit()
    except Exception as error:  # noqa: BLE001 - never mask the original failure
        print(f"⚠️  Could not record the end of import run {handle.id}: {error}")
