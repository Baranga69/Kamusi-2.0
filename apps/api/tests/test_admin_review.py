from datetime import datetime

from app.models import Language, Lexeme, PartOfSpeech, Sense, SenseDefinition


def seed_single_unreviewed_definition(db_session) -> str:
    """One unreviewed AI Swahili definition; returns its id."""
    language = Language(code="sw", name="Swahili")
    pos = PartOfSpeech(code="VERB", label="Verb")
    db_session.add_all([language, pos])
    db_session.commit()

    lexeme = Lexeme(
        lemma="Kula",
        normalized_lemma="kula",
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

    definition = SenseDefinition(
        sense_id=sense.id,
        lang_code="sw",
        definition="kula chakula",
        is_primary=True,
        is_ai_generated=True,
        review_status="unreviewed",
        created_at=datetime.utcnow(),
    )
    db_session.add(definition)
    db_session.commit()
    return str(definition.id)


def test_review_queue_filters(client, db_session):
    language_sw = Language(code="sw", name="Swahili")
    language_en = Language(code="en", name="English")
    pos_noun = PartOfSpeech(code="NOUN", label="NOUN")
    pos_verb = PartOfSpeech(code="VERB", label="VERB")
    db_session.add_all([language_sw, language_en, pos_noun, pos_verb])
    db_session.commit()

    lexeme_one = Lexeme(
        lemma="Kula",
        normalized_lemma="kula",
        pos_id=pos_verb.id,
        status="core",
        default_language_code="sw",
        workflow="draft",
    )
    lexeme_two = Lexeme(
        lemma="Kito",
        normalized_lemma="kito",
        pos_id=pos_noun.id,
        status="slang",
        default_language_code="sw",
        workflow="draft",
    )
    db_session.add_all([lexeme_one, lexeme_two])
    db_session.commit()

    sense_one = Sense(lexeme_id=lexeme_one.id, sense_number=1, workflow="draft")
    sense_two = Sense(lexeme_id=lexeme_two.id, sense_number=1, workflow="draft")
    db_session.add_all([sense_one, sense_two])
    db_session.commit()

    sw_definition_one = SenseDefinition(
        sense_id=sense_one.id,
        lang_code="sw",
        definition="kula chakula",
        is_primary=True,
        is_ai_generated=True,
        review_status="unreviewed",
        created_at=datetime.utcnow(),
    )
    en_definition_one = SenseDefinition(
        sense_id=sense_one.id,
        lang_code="en",
        definition="Passive form of to eat",
        is_primary=True,
        created_at=datetime.utcnow(),
    )
    sw_definition_two = SenseDefinition(
        sense_id=sense_two.id,
        lang_code="sw",
        definition="kito kidogo",
        is_primary=True,
        is_ai_generated=True,
        review_status="approved",
        created_at=datetime.utcnow(),
    )
    db_session.add_all([sw_definition_one, en_definition_one, sw_definition_two])
    db_session.commit()

    headers = {"X-API-Key": "dev-api-key"}

    resp = client.get("/admin/review/queue", headers=headers)
    assert resp.status_code == 200
    data = resp.json()
    assert len(data) == 1
    assert data[0]["lemma"] == "Kula"
    assert data[0]["morphology_like"] is True

    resp = client.get("/admin/review/queue", headers=headers, params={"status": "approved"})
    assert resp.status_code == 200
    data = resp.json()
    assert len(data) == 1
    assert data[0]["lemma"] == "Kito"

    resp = client.get(
        "/admin/review/queue",
        headers=headers,
        params={"status": "approved", "pos_code": "NOUN", "lexeme_status": "slang"},
    )
    assert resp.status_code == 200
    data = resp.json()
    assert len(data) == 1
    assert data[0]["pos_code"] == "NOUN"

    resp = client.get(
        "/admin/review/queue",
        headers=headers,
        params={"status": "approved", "q": "kul"},
    )
    assert resp.status_code == 200
    assert resp.json() == []


def test_review_queue_lexeme_status_filter(client, db_session):
    language_sw = Language(code="sw", name="Swahili")
    pos = PartOfSpeech(code="NOUN", label="NOUN")
    db_session.add_all([language_sw, pos])
    db_session.commit()

    lexeme = Lexeme(
        lemma="Kito",
        normalized_lemma="kito",
        pos_id=pos.id,
        status="slang",
        default_language_code="sw",
        workflow="draft",
    )
    db_session.add(lexeme)
    db_session.commit()

    sense = Sense(lexeme_id=lexeme.id, sense_number=1, workflow="draft")
    db_session.add(sense)
    db_session.commit()

    db_session.add(
        SenseDefinition(
            sense_id=sense.id,
            lang_code="sw",
            definition="kito kidogo",
            is_primary=True,
            is_ai_generated=True,
            review_status="unreviewed",
            created_at=datetime.utcnow(),
        )
    )
    db_session.commit()

    headers = {"X-API-Key": "dev-api-key"}

    resp = client.get("/admin/review/queue", headers=headers, params={"lexeme_status": "slang"})
    assert resp.status_code == 200
    assert len(resp.json()) == 1

    # The filter is honoured rather than silently ignored.
    resp = client.get("/admin/review/queue", headers=headers, params={"lexeme_status": "core"})
    assert resp.status_code == 200
    assert resp.json() == []

    resp = client.get("/admin/review/queue", headers=headers, params={"lexeme_status": "bogus"})
    assert resp.status_code == 400


def seed_definitions_with_confidence(db_session, values: list[float | None]) -> None:
    """One unreviewed AI definition per confidence value, lemma a/b/c/..."""
    language = Language(code="sw", name="Swahili")
    pos = PartOfSpeech(code="NOUN", label="Noun")
    db_session.add_all([language, pos])
    db_session.commit()

    for index, confidence in enumerate(values):
        lemma = chr(ord("a") + index)
        lexeme = Lexeme(
            lemma=lemma,
            normalized_lemma=lemma,
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
        db_session.add(
            SenseDefinition(
                sense_id=sense.id,
                lang_code="sw",
                definition=f"maelezo ya {lemma}",
                is_primary=True,
                is_ai_generated=True,
                review_status="unreviewed",
                ai_confidence=confidence,
                created_at=datetime.utcnow(),
            )
        )
    db_session.commit()


def test_queue_can_lead_with_the_least_confident(client, db_session):
    """Reviewer attention is scarce; spend it where the model was unsure."""
    seed_definitions_with_confidence(db_session, [0.9, 0.2, 0.55])

    resp = client.get(
        "/admin/review/queue",
        headers={"X-API-Key": "dev-api-key"},
        params={"sort": "confidence"},
    )
    assert resp.status_code == 200
    assert [item["ai_confidence"] for item in resp.json()] == [0.2, 0.55, 0.9]


def test_unknown_confidence_sorts_last_not_first(client, db_session):
    """Null is "we did not record it", not "this one is bad"."""
    seed_definitions_with_confidence(db_session, [0.8, None, 0.1])

    resp = client.get(
        "/admin/review/queue",
        headers={"X-API-Key": "dev-api-key"},
        params={"sort": "confidence"},
    )
    assert [item["ai_confidence"] for item in resp.json()] == [0.1, 0.8, None]


def test_confidence_is_reported_on_every_queue_item(client, db_session):
    seed_definitions_with_confidence(db_session, [0.42])

    item = client.get(
        "/admin/review/queue", headers={"X-API-Key": "dev-api-key"}
    ).json()[0]
    assert item["ai_confidence"] == 0.42


def test_an_invalid_sort_is_still_rejected(client, db_session):
    resp = client.get(
        "/admin/review/queue",
        headers={"X-API-Key": "dev-api-key"},
        params={"sort": "vibes"},
    )
    assert resp.status_code == 400
