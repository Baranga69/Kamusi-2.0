"""Surviving a crash half-way through a large import.

A million-line import that commits once at the end is a million lines you
lose to one bad row at line 999,999. These tests pin the two things that make
a long import survivable: work is committed in batches, and a run that died
can be resumed from where it stopped without re-doing or skipping anything.

The resume point is the part worth being careful about. A checkpoint that
*understates* progress costs duplicate work, which the importers' conflict
handling absorbs. One that *overstates* it silently skips input, and silently
missing data is the failure you find months later.
"""
import importlib.util
import os
import sys
from pathlib import Path

import pytest

TOOLS = Path(__file__).resolve().parents[1] / "tools"


def load_import_run_module():
    """Import the helper the ingest tools use, so its SQL is under test."""
    spec = importlib.util.spec_from_file_location("import_run", TOOLS / "import_run.py")
    module = importlib.util.module_from_spec(spec)
    # Registered before executing: @dataclass looks its own module up in
    # sys.modules while the class body is being processed.
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


ir = load_import_run_module()


# --- counting and skipping, no database needed ----------------------------


def test_a_resumed_run_reports_the_whole_job_not_just_the_last_leg():
    """The first attempt wrote 30 rows; this one wrote 20. The run made 50."""
    handle = ir.RunHandle(
        id="r",
        baseline={"lexemes_created": 10, "senses_created": 10, "definitions_created": 30},
    )
    handle.counts["definitions_created"] = 20

    assert handle.totals()["definitions_created"] == 50
    assert handle.counts["definitions_created"] == 20, "this attempt's own work"


def test_a_fresh_run_has_nothing_behind_it():
    handle = ir.RunHandle(id="r")
    handle.counts["definitions_created"] = 7

    assert handle.totals() == {
        "lexemes_created": 0,
        "senses_created": 0,
        "definitions_created": 7,
    }


def test_resuming_skips_exactly_the_lines_already_committed():
    """Line 30 was the last one committed, so line 31 is where work restarts."""
    handle = ir.RunHandle(id="r", resume_from=30)

    assert handle.should_skip(1)
    assert handle.should_skip(30)
    assert not handle.should_skip(31)


def test_a_fresh_run_skips_nothing():
    handle = ir.RunHandle(id="r")

    assert not handle.should_skip(1)


def test_counting_lines_ignores_blanks(tmp_path):
    path = tmp_path / "in.jsonl"
    path.write_text("a\n\nb\n   \nc\n")

    assert ir.count_lines(path) == 3


def test_counting_lines_tolerates_an_unreadable_input(tmp_path):
    """Progress reporting is a nicety; it must never stop an import."""
    assert ir.count_lines(tmp_path / "missing.jsonl") is None


def test_progress_shows_a_share_when_the_total_is_known():
    handle = ir.RunHandle(id="r", total_lines=50)

    assert "40 / 50" in handle.progress(40)
    assert "80.0%" in handle.progress(40)


def test_progress_degrades_to_a_count_when_the_total_is_not():
    handle = ir.RunHandle(id="r")

    assert "40" in handle.progress(40)
    assert "%" not in handle.progress(40)


# --- the checkpoint, against the real schema ------------------------------

TEST_DATABASE_URL = os.getenv("TEST_DATABASE_URL")


@pytest.fixture()
def conn(request):
    """A psycopg connection, which is how the ingest tools talk to Postgres.

    They bypass SQLAlchemy, so the helper's SQL has to be exercised the same
    way. That means real commits outside the suite's rollback fixture, so
    this cleans up the runs it made.
    """
    if not TEST_DATABASE_URL:
        pytest.skip("needs Postgres; set TEST_DATABASE_URL to run")
    psycopg = pytest.importorskip("psycopg")
    from psycopg.rows import dict_row

    request.getfixturevalue("postgres_engine")  # ensure the schema exists
    dsn = TEST_DATABASE_URL.replace("postgresql+psycopg://", "postgresql://")
    with psycopg.connect(dsn, row_factory=dict_row) as connection:
        try:
            yield connection
        finally:
            connection.rollback()
            with connection.cursor() as cur:
                cur.execute("DELETE FROM import_run WHERE tool = 'test-batching'")
            connection.commit()


def run_row(conn, run_id) -> dict:
    with conn.cursor() as cur:
        cur.execute("SELECT * FROM import_run WHERE id = %s", (run_id,))
        return cur.fetchone()


def start(conn, **kwargs):
    return ir.import_run(conn, kind="test", tool="test-batching", **kwargs)


def test_a_committed_batch_records_how_far_the_input_was_read(conn):
    with start(conn, total_lines=50) as run:
        run.counts["definitions_created"] = 10
        run.commit_batch(10)
        checkpoint = run_row(conn, run.id)

    assert checkpoint["processed_lines"] == 10
    assert checkpoint["definitions_created"] == 10, "counts travel with the checkpoint"


def test_work_committed_before_a_crash_survives_it(conn):
    """The point of batching: a bad row late in the file costs one batch."""
    with pytest.raises(ValueError):
        with start(conn, total_lines=50) as run:
            run_id = run.id
            run.counts["definitions_created"] = 30
            run.commit_batch(30)
            raise ValueError("line 31 is malformed")

    row = run_row(conn, run_id)
    assert row["status"] == "failed", "a failed run is still recorded, to be found"
    assert row["processed_lines"] == 30
    assert row["definitions_created"] == 30


def test_a_failed_run_resumes_from_its_checkpoint(conn):
    with pytest.raises(ValueError):
        with start(conn, total_lines=50) as run:
            run_id = run.id
            run.counts["definitions_created"] = 30
            run.commit_batch(30)
            raise ValueError("boom")

    with start(conn, resume=str(run_id), total_lines=50) as resumed:
        assert resumed.id == run_id, "the same run, continued — not a new one"
        assert resumed.resume_from == 30
        assert resumed.should_skip(30)
        assert not resumed.should_skip(31)
        resumed.counts["definitions_created"] = 20
        resumed.commit_batch(50)

    row = run_row(conn, run_id)
    assert row["status"] == "completed"
    assert row["definitions_created"] == 50, "both legs, not just the second"
    assert row["processed_lines"] == 50


def test_a_completed_run_cannot_be_resumed(conn):
    """Resuming a finished import would duplicate the whole thing."""
    with start(conn) as run:
        run_id = run.id

    assert run_row(conn, run_id)["status"] == "completed"
    with pytest.raises(SystemExit, match="nothing to resume"):
        with start(conn, resume=str(run_id)):
            pass


def test_a_reverted_run_cannot_be_resumed(conn):
    """Its rows were deliberately removed; refilling them is not a resume."""
    with start(conn) as run:
        run_id = run.id
    with conn.cursor() as cur:
        cur.execute("UPDATE import_run SET status = 'reverted' WHERE id = %s", (run_id,))
    conn.commit()

    with pytest.raises(SystemExit, match="nothing to resume"):
        with start(conn, resume=str(run_id)):
            pass


def test_resuming_a_run_that_does_not_exist_says_so(conn):
    with pytest.raises(SystemExit, match="No import run"):
        with start(conn, resume="00000000-0000-0000-0000-000000000000"):
            pass


def test_a_run_is_recorded_before_any_work_happens(conn):
    """If the import dies hard, the run still exists to be found and undone."""
    with start(conn, input_path="/tmp/in.jsonl") as run:
        row = run_row(conn, run.id)
        assert row is not None, "committed up front, not at the end"
        assert row["status"] == "running"
        assert row["input_path"] == "/tmp/in.jsonl"


def test_resumable_runs_lists_the_ones_worth_continuing(conn):
    with start(conn) as finished:
        completed_id = finished.id
    with pytest.raises(ValueError):
        with start(conn) as failed:
            failed_id = failed.id
            raise ValueError("boom")

    ids = {row["id"] for row in ir.resumable_runs(conn, kind="test")}

    assert failed_id in ids
    assert completed_id not in ids, "nothing left to do"

# --- dry runs leave no trace ----------------------------------------------


def test_a_dry_run_records_no_import(conn):
    """A run claiming rows it never wrote would be a lie in the audit trail."""
    with start(conn, dry_run=True) as run:
        run_id = run.id
        assert run_row(conn, run_id) is not None, "visible inside the transaction"
        run.counts["definitions_created"] = 50
    conn.rollback()  # the importer's closing rollback

    assert run_row(conn, run_id) is None


def test_a_dry_run_still_knows_where_a_resume_would_start(conn):
    """Dry-running a resume has to skip the same lines the real one would."""
    with pytest.raises(ValueError):
        with start(conn, total_lines=50) as run:
            run_id = run.id
            run.counts["definitions_created"] = 30
            run.commit_batch(30)
            raise ValueError("boom")

    with start(conn, resume=str(run_id), dry_run=True) as resumed:
        assert resumed.resume_from == 30
        assert resumed.should_skip(30)
        assert not resumed.should_skip(31)
    conn.rollback()

    row = run_row(conn, run_id)
    assert row["status"] == "failed", "the dry run did not touch the real run"
    assert row["processed_lines"] == 30
