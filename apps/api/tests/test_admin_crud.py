from app.models import Language, PartOfSpeech


def test_admin_crud_happy_path(client, db_session):
    language = Language(code="sw", name="Swahili")
    pos = PartOfSpeech(code="NOUN", label="NOUN")
    db_session.add_all([language, pos])
    db_session.commit()

    headers = {"X-API-Key": "dev-api-key"}

    lexeme_resp = client.post(
        "/admin/lexemes",
        json={
            "lemma": "Mti",
            "pos_id": str(pos.id),
            "status": "core",
            "default_language_code": "sw",
            "workflow": "draft",
        },
        headers=headers,
    )
    assert lexeme_resp.status_code == 200
    lexeme_id = lexeme_resp.json()["id"]

    sense_resp = client.post(
        "/admin/senses",
        json={
            "lexeme_id": lexeme_id,
            "sense_number": 1,
            "workflow": "draft",
        },
        headers=headers,
    )
    assert sense_resp.status_code == 200
    sense_id = sense_resp.json()["id"]

    definition_resp = client.post(
        "/admin/sense-definitions",
        json={
            "sense_id": sense_id,
            "lang_code": "sw",
            "definition": "mmea mkubwa",
            "is_primary": True,
        },
        headers=headers,
    )
    assert definition_resp.status_code == 200

    example_resp = client.post(
        "/admin/examples",
        json={
            "sense_id": sense_id,
            "is_attested": True,
        },
        headers=headers,
    )
    assert example_resp.status_code == 200
    example_id = example_resp.json()["id"]

    example_text_resp = client.post(
        "/admin/example-texts",
        json={
            "example_id": example_id,
            "lang_code": "sw",
            "text": "Mti mkubwa uko hapa.",
            "is_primary": True,
        },
        headers=headers,
    )
    assert example_text_resp.status_code == 200
