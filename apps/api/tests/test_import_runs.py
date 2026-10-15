"""Undoing a bad import without destroying the good work around it.

Growing the dictionary means importing in bulk, and bulk imports sometimes
turn out to be wrong. These tests pin what revert will and will not delete —
the safety rules matter more than the deletion itself, because the failure
mode is losing a reviewer's judgement.
"""
import importlib.util
from datetime import datetime, timezone
from pathlib import Path

import pytest
from sqlalchemy import func, select, text

from app.models import (
    Example,
    Language,
    ImportRun,
    Lexeme,
    License,
    PartOfSpeech,
    SearchEntry,
    Sense,
    SenseDefinition,
    Source,
)


def load_revert_module():
    """Import the maintenance script so its SQL is the thing under test."""
    path = Path(__file__).resolve().parents[1] / "tools" / "maintenance" / "revert_import.py"
    spec = importlib.util.spec_from_file_location("revert_import", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


revert = load_revert_module()

# The maintenance script is written against Postgres — native uuid comparison,
# `left()` — which is what it will run against. SQLite would be testing
# different SQL from the one that ships.
pytestmark = pytest.mark.postgres


def make_run(db_session, kind: str = "ai_definitions") -> ImportRun:
    run = ImportRun(kind=kind, tool="test", status="completed")
    db_session.add(run)
    db_session.commit()
    return run


def make_entry(
    db_session,
    run: ImportRun | None,
    lemma: str,
    *,
    review_status: str | None = "unreviewed",
    owns_lexeme: bool = True,
):
    """A lexeme + sense + definition, owned by `run` where `owns_lexeme`."""
    # Postgres enforces the language foreign key that SQLite leaves off.
    if db_session.scalar(select(Language).where(Language.code == "sw")) is None:
        db_session.add_all(
            [Language(code="sw", name="Swahili"), Language(code="en", name="English")]
        )
        db_session.commit()

    pos = db_session.scalar(select(PartOfSpeech).where(PartOfSpeech.code == "NOUN"))
    if pos is None:
        pos = PartOfSpeech(code="NOUN", label="Noun")
        db_session.add(pos)
        db_session.commit()

    run_id = run.id if run else None
    lexeme = Lexeme(
        lemma=lemma,
        normalized_lemma=lemma,
        pos_id=pos.id,
        status="core",
        default_language_code="sw",
        workflow="published",
        import_run_id=run_id if owns_lexeme else None,
    )
    db_session.add(lexeme)
    db_session.commit()

    sense = Sense(
        lexeme_id=lexeme.id,
        sense_number=1,
        workflow="published",
        import_run_id=run_id if owns_lexeme else None,
    )
    db_session.add(sense)
    db_session.commit()

    definition = SenseDefinition(
        sense_id=sense.id,
        lang_code="sw",
        definition=f"maelezo ya {lemma}",
        is_primary=True,
        is_ai_generated=True,
        review_status=review_status,
        import_run_id=run_id,
        created_at=datetime.now(timezone.utc),
    )
    db_session.add(definition)
    db_session.commit()
    return lexeme, sense, definition


def do_revert(db_session, run: ImportRun) -> dict[str, int]:
    removed = {
        "definitions": db_session.execute(
            text(revert.DELETE_DEFINITIONS), {"run_id": str(run.id)}
        ).rowcount,
        "senses": db_session.execute(
            text(revert.DELETE_SENSES), {"run_id": str(run.id)}
        ).rowcount,
        "lexemes": db_session.execute(
            text(revert.DELETE_LEXEMES), {"run_id": str(run.id)}
        ).rowcount,
    }
    removed["index"] = db_session.execute(text(revert.PRUNE_INDEX)).rowcount
    db_session.commit()
    return removed


def count(db_session, model) -> int:
    return db_session.scalar(select(func.count()).select_from(model))


# --- the whole batch ------------------------------------------------------


def test_an_untouched_import_is_fully_undone(db_session):
    run = make_run(db_session)
    for lemma in ["kalamu", "mlango", "kiti"]:
        make_entry(db_session, run, lemma)

    removed = do_revert(db_session, run)

    assert removed["definitions"] == 3
    assert removed["senses"] == 3
    assert removed["lexemes"] == 3
    assert count(db_session, SenseDefinition) == 0
    assert count(db_session, Lexeme) == 0


# --- what it refuses to touch --------------------------------------------


def test_a_reviewed_definition_survives(db_session):
    """Reviewing something is also a decision that it should exist."""
    run = make_run(db_session)
    make_entry(db_session, run, "kalamu", review_status="approved")
    make_entry(db_session, run, "mlango", review_status="unreviewed")

    do_revert(db_session, run)

    survivors = db_session.scalars(select(SenseDefinition)).all()
    assert [d.definition for d in survivors] == ["maelezo ya kalamu"]


def test_edited_and_rejected_also_survive(db_session):
    run = make_run(db_session)
    for lemma, status in [
        ("kalamu", "edited"),
        ("mlango", "rejected"),
        ("kiti", "unreviewed"),
    ]:
        make_entry(db_session, run, lemma, review_status=status)

    do_revert(db_session, run)

    assert {d.review_status for d in db_session.scalars(select(SenseDefinition)).all()} == {
        "edited",
        "rejected",
    }


def test_a_lexeme_keeping_a_reviewed_definition_is_kept(db_session):
    """Deleting the lexeme would orphan the reviewer's work."""
    run = make_run(db_session)
    make_entry(db_session, run, "kalamu", review_status="approved")

    removed = do_revert(db_session, run)

    assert removed["definitions"] == 0
    assert removed["senses"] == 0
    assert removed["lexemes"] == 0
    assert count(db_session, Lexeme) == 1


def test_a_sense_with_an_example_is_kept(db_session):
    """Someone added a usage example; the sense is no longer only ours."""
    run = make_run(db_session)
    _, sense, _ = make_entry(db_session, run, "kalamu")
    db_session.add(Example(sense_id=sense.id, is_attested=True))
    db_session.commit()

    removed = do_revert(db_session, run)

    assert removed["definitions"] == 1
    assert removed["senses"] == 0, "the example would have been orphaned"
    assert removed["lexemes"] == 0


def test_a_definition_added_later_keeps_its_sense(db_session):
    """A second import built on the first one's sense."""
    first = make_run(db_session)
    second = make_run(db_session, kind="wiktionary")
    _, sense, _ = make_entry(db_session, first, "kalamu")
    db_session.add(
        SenseDefinition(
            sense_id=sense.id,
            lang_code="en",
            definition="a pen",
            is_primary=True,
            import_run_id=second.id,
        )
    )
    db_session.commit()

    do_revert(db_session, first)

    remaining = db_session.scalars(select(SenseDefinition)).all()
    assert [d.lang_code for d in remaining] == ["en"]
    assert count(db_session, Sense) == 1
    assert count(db_session, Lexeme) == 1


def test_content_from_another_run_is_untouched(db_session):
    run = make_run(db_session)
    other = make_run(db_session, kind="wiktionary")
    make_entry(db_session, run, "kalamu")
    make_entry(db_session, other, "mlango")

    do_revert(db_session, run)

    survivors = db_session.scalars(select(Lexeme)).all()
    assert [l.lemma for l in survivors] == ["mlango"]


def test_hand_authored_content_has_no_run_and_is_untouched(db_session):
    run = make_run(db_session)
    make_entry(db_session, run, "kalamu")
    make_entry(db_session, None, "mlango")  # created in the admin console

    do_revert(db_session, run)

    survivors = db_session.scalars(select(Lexeme)).all()
    assert [l.lemma for l in survivors] == ["mlango"]


# --- the search index -----------------------------------------------------


def test_search_entries_for_deleted_content_are_cleaned_up(db_session):
    """search_entry has no foreign keys, so revert has to tidy it itself."""
    run = make_run(db_session)
    lexeme, _, definition = make_entry(db_session, run, "kalamu")
    db_session.add_all(
        [
            SearchEntry(
                target_type="lexeme",
                target_id=lexeme.id,
                lang_code="sw",
                text="kalamu",
                normalized="kalamu",
            ),
            SearchEntry(
                target_type="definition",
                target_id=definition.id,
                lang_code="sw",
                text="maelezo ya kalamu",
                normalized="maelezo ya kalamu",
            ),
        ]
    )
    db_session.commit()

    removed = do_revert(db_session, run)

    assert removed["index"] == 2
    assert count(db_session, SearchEntry) == 0


def test_search_entries_for_surviving_content_are_left_alone(db_session):
    run = make_run(db_session)
    lexeme, _, _ = make_entry(db_session, run, "kalamu", review_status="approved")
    db_session.add(
        SearchEntry(
            target_type="lexeme",
            target_id=lexeme.id,
            lang_code="sw",
            text="kalamu",
            normalized="kalamu",
        )
    )
    db_session.commit()

    removed = do_revert(db_session, run)

    assert removed["index"] == 0
    assert count(db_session, SearchEntry) == 1


# --- the run record -------------------------------------------------------


def test_a_run_records_what_it_was(db_session):
    source = None
    license_ = License(name="CC BY-SA 4.0", can_display=True)
    db_session.add(license_)
    db_session.commit()
    source = Source(title="AI draft", source_type="ai", license_id=license_.id)
    db_session.add(source)
    db_session.commit()

    run = ImportRun(
        kind="ai_definitions",
        tool="import_ai_defs.py",
        input_path="/tmp/ai_defs.jsonl",
        source_id=source.id,
        status="completed",
        parameters={"on_conflict": "skip"},
        definitions_created=531,
    )
    db_session.add(run)
    db_session.commit()

    stored = db_session.scalar(select(ImportRun).where(ImportRun.id == run.id))
    assert stored.parameters == {"on_conflict": "skip"}
    assert stored.input_path.endswith("ai_defs.jsonl")
    assert stored.definitions_created == 531


def test_deleting_a_run_record_orphans_rather_than_deletes(db_session):
    """Losing the paperwork must never take the content with it."""
    run = make_run(db_session)
    make_entry(db_session, run, "kalamu")

    db_session.execute(
        text("DELETE FROM import_run WHERE id = :id"), {"id": str(run.id)}
    )
    db_session.commit()

    assert count(db_session, Lexeme) == 1
    assert db_session.scalars(select(SenseDefinition)).one().import_run_id is None
