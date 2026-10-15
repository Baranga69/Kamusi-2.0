from app.models import Language, Lexeme, PartOfSpeech, SearchEntry
from app.normalize import normalize_sw


def test_search_ranking(client, db_session):
    language = Language(code="sw", name="Swahili")
    pos = PartOfSpeech(code="NOUN", label="NOUN")
    db_session.add_all([language, pos])
    db_session.commit()

    # popularity deliberately runs opposite to the expected order so the
    # assertion proves match rank wins over popularity.
    fixtures = [("mti", 10), ("mtish", 20), ("samti", 30)]
    for lemma, popularity in fixtures:
        lexeme = Lexeme(
            lemma=lemma,
            normalized_lemma=normalize_sw(lemma),
            pos_id=pos.id,
            status="core",
            default_language_code="sw",
            workflow="published",
        )
        db_session.add(lexeme)
        db_session.commit()
        db_session.add(
            SearchEntry(
                target_type="lexeme",
                target_id=lexeme.id,
                lang_code="sw",
                text=lemma,
                normalized=normalize_sw(lemma),
                popularity=popularity,
            )
        )
    db_session.commit()

    response = client.get("/search", params={"q": "mti", "lang": "sw", "limit": 10})
    assert response.status_code == 200
    results = response.json()
    assert [result["text"] for result in results] == ["mti", "mtish", "samti"]
    assert [result["match_kind"] for result in results] == ["lemma", "lemma", "lemma"]
    assert results[0]["pos_code"] == "NOUN"


def test_search_matches_definition_text(client, db_session):
    """A published definition is reachable by its own text, not just the lemma."""
    from app.models import Sense, SenseDefinition

    language = Language(code="sw", name="Swahili")
    pos = PartOfSpeech(code="NOUN", label="NOUN")
    db_session.add_all([language, pos])
    db_session.commit()

    lexeme = Lexeme(
        lemma="mti",
        normalized_lemma=normalize_sw("mti"),
        pos_id=pos.id,
        status="core",
        default_language_code="sw",
        workflow="published",
    )
    db_session.add(lexeme)
    db_session.commit()

    sense = Sense(lexeme_id=lexeme.id, sense_number=1, workflow="published")
    db_session.add(sense)
    db_session.commit()

    definition = SenseDefinition(
        sense_id=sense.id,
        lang_code="sw",
        definition="mmea mkubwa wenye shina gumu",
        is_primary=True,
    )
    db_session.add(definition)
    db_session.commit()

    db_session.add(
        SearchEntry(
            target_type="definition",
            target_id=definition.id,
            lang_code="sw",
            text=definition.definition,
            normalized=normalize_sw(definition.definition),
        )
    )
    db_session.commit()

    response = client.get("/search", params={"q": "shina", "lang": "sw"})
    assert response.status_code == 200
    results = response.json()
    assert len(results) == 1
    assert results[0]["match_kind"] == "definition"
    assert results[0]["lexeme_id"] == str(lexeme.id)
    assert results[0]["lemma"] == "mti"
