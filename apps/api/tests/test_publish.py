import pytest
from sqlalchemy import select

from app.models import Language, Lexeme, PartOfSpeech, SearchEntry, Sense, SenseDefinition
from app.normalize import normalize_sw
from app.services.publish import NotReady, publish_lexeme, readiness_problems


def build_lexeme(db_session) -> Lexeme:
    db_session.add(Language(code="sw", name="Swahili"))
    db_session.add(Language(code="en", name="English"))
    pos = PartOfSpeech(code="NOUN", label="Noun")
    db_session.add(pos)
    db_session.commit()

    lexeme = Lexeme(
        lemma="mti",
        normalized_lemma=normalize_sw("mti"),
        pos_id=pos.id,
        status="core",
        default_language_code="sw",
        workflow="draft",
    )
    db_session.add(lexeme)
    db_session.commit()

    sense = Sense(lexeme_id=lexeme.id, sense_number=1, workflow="draft")
    db_session.add(sense)
    db_session.commit()
    return lexeme


def entries(db_session) -> dict[str, SearchEntry]:
    rows = db_session.scalars(select(SearchEntry)).all()
    return {f"{row.target_type}:{row.target_id}": row for row in rows}


def test_publish_indexes_definitions_by_definition_id(db_session):
    lexeme = build_lexeme(db_session)
    sense = lexeme.senses[0]
    definition = SenseDefinition(
        sense_id=sense.id,
        lang_code="sw",
        definition="mmea mkubwa wenye shina gumu",
        is_primary=True,
    )
    db_session.add(definition)
    db_session.commit()

    publish_lexeme(db_session, lexeme.id)

    found = entries(db_session)
    assert f"lexeme:{lexeme.id}" in found
    # Keyed on the definition, which is what /search joins back to a lexeme.
    assert f"definition:{definition.id}" in found
    assert f"sense:{sense.id}" not in found


def test_publish_skips_unreviewed_ai_swahili_definitions(db_session):
    lexeme = build_lexeme(db_session)
    sense = lexeme.senses[0]

    unreviewed = SenseDefinition(
        sense_id=sense.id,
        lang_code="sw",
        definition="maelezo ya AI ambayo hayajapitiwa",
        is_primary=True,
        is_ai_generated=True,
        review_status="unreviewed",
    )
    english = SenseDefinition(
        sense_id=sense.id,
        lang_code="en",
        definition="a tree",
        is_primary=True,
    )
    db_session.add_all([unreviewed, english])
    db_session.commit()

    publish_lexeme(db_session, lexeme.id)

    found = entries(db_session)
    assert f"definition:{unreviewed.id}" not in found
    # English is unaffected by the Swahili AI guard.
    assert f"definition:{english.id}" in found


def test_publish_indexes_approved_ai_swahili_definitions(db_session):
    lexeme = build_lexeme(db_session)
    sense = lexeme.senses[0]
    approved = SenseDefinition(
        sense_id=sense.id,
        lang_code="sw",
        definition="maelezo yaliyoidhinishwa",
        is_primary=True,
        is_ai_generated=True,
        review_status="approved",
    )
    db_session.add(approved)
    db_session.commit()

    publish_lexeme(db_session, lexeme.id)

    assert f"definition:{approved.id}" in entries(db_session)


# --- readiness -------------------------------------------------------------
#
# These rules used to live only in the admin console, so the server would
# publish anything asked of it. The bulk tool screens against them, and
# nobody is watching a bulk run — a false pass there means a corpus of
# entries that look complete in the database and empty in the app.


def add_definition(db_session, sense, text, lang="sw", **kwargs):
    definition = SenseDefinition(
        sense_id=sense.id, lang_code=lang, definition=text, is_primary=True, **kwargs
    )
    db_session.add(definition)
    db_session.commit()
    return definition


def test_a_complete_entry_is_ready(db_session):
    lexeme = build_lexeme(db_session)
    add_definition(db_session, lexeme.senses[0], "aina ya mmea mkubwa wenye shina")
    db_session.refresh(lexeme)

    assert readiness_problems(lexeme) == []


def test_an_unreviewed_ai_definition_is_not_a_visible_one(db_session):
    """The rule a client cannot get right: the review guard hides this text.

    Publishing it yields a word that looks complete in the database and shows
    a reader nothing at all.
    """
    lexeme = build_lexeme(db_session)
    add_definition(
        db_session,
        lexeme.senses[0],
        "aina ya mmea mkubwa wenye shina",
        is_ai_generated=True,
        review_status="unreviewed",
    )
    db_session.refresh(lexeme)

    assert "no_visible_swahili_definition" in readiness_problems(lexeme)


def test_approving_that_definition_makes_it_ready(db_session):
    lexeme = build_lexeme(db_session)
    definition = add_definition(
        db_session,
        lexeme.senses[0],
        "aina ya mmea mkubwa wenye shina",
        is_ai_generated=True,
        review_status="unreviewed",
    )
    definition.review_status = "approved"
    db_session.commit()
    db_session.refresh(lexeme)

    assert readiness_problems(lexeme) == []


def test_an_english_only_entry_is_not_ready(db_session):
    """A Swahili dictionary entry with no Swahili is not a publishable entry."""
    lexeme = build_lexeme(db_session)
    add_definition(db_session, lexeme.senses[0], "a kind of tree", lang="en")
    db_session.refresh(lexeme)

    assert "no_visible_swahili_definition" in readiness_problems(lexeme)


def test_a_partly_covered_entry_is_reported_as_incomplete(db_session):
    """Usable but incomplete, and worth telling apart from having none."""
    lexeme = build_lexeme(db_session)
    add_definition(db_session, lexeme.senses[0], "aina ya mmea mkubwa wenye shina")
    second = Sense(lexeme_id=lexeme.id, sense_number=2, workflow="draft")
    db_session.add(second)
    db_session.commit()
    add_definition(db_session, second, "a wooden post", lang="en")
    db_session.refresh(lexeme)

    problems = readiness_problems(lexeme)
    assert "sense_without_visible_swahili" in problems
    assert "no_visible_swahili_definition" not in problems


def test_an_entry_with_no_senses_is_not_ready(db_session):
    lexeme = build_lexeme(db_session)
    db_session.delete(lexeme.senses[0])
    db_session.commit()
    db_session.refresh(lexeme)

    assert readiness_problems(lexeme) == ["no_senses"]


def test_a_blank_definition_is_caught(db_session):
    lexeme = build_lexeme(db_session)
    add_definition(db_session, lexeme.senses[0], "aina ya mmea mkubwa wenye shina")
    add_definition(db_session, lexeme.senses[0], "   ", lang="en")
    db_session.refresh(lexeme)

    assert "empty_definition" in readiness_problems(lexeme)


def test_a_one_character_lemma_is_not_ready(db_session):
    lexeme = build_lexeme(db_session)
    lexeme.lemma = "m"
    add_definition(db_session, lexeme.senses[0], "aina ya mmea mkubwa wenye shina")
    db_session.commit()
    db_session.refresh(lexeme)

    assert "lemma_too_short" in readiness_problems(lexeme)


def test_a_lemma_that_normalizes_to_nothing_is_not_ready(db_session):
    """It could never be found, so publishing it is pointless."""
    lexeme = build_lexeme(db_session)
    lexeme.lemma = "!!!"
    add_definition(db_session, lexeme.senses[0], "aina ya mmea mkubwa wenye shina")
    db_session.commit()
    db_session.refresh(lexeme)

    assert "lemma_not_searchable" in readiness_problems(lexeme)


def test_publish_refuses_an_unready_entry_when_asked_to_check(db_session):
    lexeme = build_lexeme(db_session)
    add_definition(db_session, lexeme.senses[0], "a kind of tree", lang="en")
    db_session.refresh(lexeme)

    with pytest.raises(NotReady) as caught:
        publish_lexeme(db_session, lexeme.id, require_ready=True)
    assert "no_visible_swahili_definition" in caught.value.problems
    db_session.rollback()
    assert db_session.scalar(select(Lexeme).where(Lexeme.id == lexeme.id)).workflow == "draft"


def test_publish_still_publishes_without_the_check(db_session):
    """The console's publish button must keep behaving as it does today."""
    lexeme = build_lexeme(db_session)
    add_definition(db_session, lexeme.senses[0], "a kind of tree", lang="en")
    db_session.refresh(lexeme)

    publish_lexeme(db_session, lexeme.id)

    assert db_session.scalar(select(Lexeme).where(Lexeme.id == lexeme.id)).workflow == "published"
