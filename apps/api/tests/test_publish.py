from sqlalchemy import select

from app.models import Language, Lexeme, PartOfSpeech, SearchEntry, Sense, SenseDefinition
from app.normalize import normalize_sw
from app.services.publish import publish_lexeme


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
