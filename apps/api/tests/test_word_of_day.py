from datetime import date, datetime, timezone

from app.models import Language, Lexeme, PartOfSpeech, Sense, SenseDefinition
from app.normalize import normalize_sw


def test_word_of_day_returns_lexeme_and_definition(client, db_session):
    today = datetime.now(timezone.utc).date()

    language = Language(code="sw", name="Swahili")
    pos = PartOfSpeech(code="NOUN", label="NOUN")
    db_session.add_all([language, pos])
    db_session.commit()

    lexeme_one = Lexeme(
        lemma="Alpha",
        normalized_lemma=normalize_sw("Alpha"),
        pos_id=pos.id,
        status="core",
        default_language_code="sw",
        workflow="published",
    )
    lexeme_two = Lexeme(
        lemma="Beta",
        normalized_lemma=normalize_sw("Beta"),
        pos_id=pos.id,
        status="core",
        default_language_code="sw",
        workflow="published",
    )
    db_session.add_all([lexeme_one, lexeme_two])
    db_session.commit()

    sense_one = Sense(
        lexeme_id=lexeme_one.id,
        sense_number=1,
        workflow="published",
    )
    sense_two = Sense(
        lexeme_id=lexeme_two.id,
        sense_number=1,
        workflow="published",
    )
    db_session.add_all([sense_one, sense_two])
    db_session.commit()

    definition_one = SenseDefinition(
        sense_id=sense_one.id,
        lang_code="sw",
        definition="Alpha definition",
        is_primary=True,
    )
    definition_two = SenseDefinition(
        sense_id=sense_two.id,
        lang_code="sw",
        definition="Beta definition",
        is_primary=True,
    )
    db_session.add_all([definition_one, definition_two])
    db_session.commit()

    response = client.get("/word-of-the-day", params={"lang": "sw"})
    assert response.status_code == 200
    payload = response.json()

    lexemes = sorted(
        [(lexeme_one, definition_one), (lexeme_two, definition_two)],
        key=lambda item: item[0].normalized_lemma,
    )
    day_index = (today - date(1970, 1, 1)).days
    expected_lexeme, expected_definition = lexemes[day_index % len(lexemes)]

    assert payload["date"] == today.isoformat()
    assert payload["lexeme_id"] == str(expected_lexeme.id)
    assert payload["lemma"] == expected_lexeme.lemma
    assert payload["definition"] == expected_definition.definition
    assert payload["lang_code"] == "sw"
