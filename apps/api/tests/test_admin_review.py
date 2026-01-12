from datetime import datetime

from app.models import Language, Lexeme, PartOfSpeech, Sense, SenseDefinition


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
