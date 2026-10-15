from app.models import (
    Expression,
    ExpressionMeaning,
    ExpressionType,
    Language,
    Lexeme,
    License,
    PartOfSpeech,
    Sense,
    SenseDefinition,
    Source,
    Tag,
    TagType,
)
from app.normalize import normalize_sw

HEADERS = {"X-API-Key": "dev-api-key"}


def test_list_lexemes(client, db_session):
    db_session.add_all([Language(code="sw", name="Swahili")])
    pos_noun = PartOfSpeech(code="NOUN", label="Noun")
    pos_verb = PartOfSpeech(code="VERB", label="Verb")
    db_session.add_all([pos_noun, pos_verb])
    db_session.commit()

    published = Lexeme(
        lemma="Mti",
        normalized_lemma=normalize_sw("Mti"),
        pos_id=pos_noun.id,
        status="core",
        default_language_code="sw",
        workflow="published",
    )
    draft = Lexeme(
        lemma="Kula",
        normalized_lemma=normalize_sw("Kula"),
        pos_id=pos_verb.id,
        status="core",
        default_language_code="sw",
        workflow="draft",
    )
    db_session.add_all([published, draft])
    db_session.commit()

    sense = Sense(lexeme_id=published.id, sense_number=1, workflow="published")
    db_session.add(sense)
    db_session.commit()
    db_session.add(
        SenseDefinition(sense_id=sense.id, lang_code="sw", definition="mmea", is_primary=True)
    )
    db_session.commit()

    resp = client.get("/admin/lexemes", headers=HEADERS)
    assert resp.status_code == 200
    data = resp.json()
    assert [item["lemma"] for item in data] == ["Kula", "Mti"]

    mti = next(item for item in data if item["lemma"] == "Mti")
    assert mti["pos_code"] == "NOUN"
    assert mti["sense_count"] == 1
    assert mti["sw_definition_count"] == 1
    assert mti["workflow"] == "published"

    kula = next(item for item in data if item["lemma"] == "Kula")
    assert kula["sense_count"] == 0
    assert kula["sw_definition_count"] == 0

    resp = client.get("/admin/lexemes", headers=HEADERS, params={"status": "published"})
    assert [item["lemma"] for item in resp.json()] == ["Mti"]

    resp = client.get("/admin/lexemes", headers=HEADERS, params={"pos_code": "VERB"})
    assert [item["lemma"] for item in resp.json()] == ["Kula"]

    resp = client.get("/admin/lexemes", headers=HEADERS, params={"query": "Mt"})
    assert [item["lemma"] for item in resp.json()] == ["Mti"]

    resp = client.get("/admin/lexemes", headers=HEADERS, params={"status": "bogus"})
    assert resp.status_code == 400


def test_list_lexemes_requires_api_key(client, db_session):
    assert client.get("/admin/lexemes").status_code == 401


def test_list_expressions(client, db_session):
    db_session.add(Language(code="sw", name="Swahili"))
    methali = ExpressionType(code="methali", label="Methali")
    db_session.add(methali)
    db_session.commit()

    expression = Expression(
        text="Haraka haraka haina baraka",
        normalized_text=normalize_sw("Haraka haraka haina baraka"),
        expression_type_id=methali.id,
        workflow="published",
    )
    db_session.add(expression)
    db_session.commit()
    db_session.add(
        ExpressionMeaning(
            expression_id=expression.id,
            lang_code="sw",
            meaning="Kufanya haraka huleta makosa",
            is_primary=True,
        )
    )
    db_session.commit()

    resp = client.get("/admin/expressions", headers=HEADERS)
    assert resp.status_code == 200
    data = resp.json()
    assert len(data) == 1
    assert data[0]["expression_type_code"] == "methali"
    assert data[0]["meaning_count"] == 1

    resp = client.get("/admin/expressions", headers=HEADERS, params={"query": "baraka"})
    assert len(resp.json()) == 1

    resp = client.get("/admin/expressions", headers=HEADERS, params={"status": "draft"})
    assert resp.json() == []


def test_list_tags_sources_licenses(client, db_session):
    tag_type = TagType(code="topic", label="Topic")
    license_ = License(name="CC BY-SA 4.0", summary="Share-alike", can_display=True)
    db_session.add_all([tag_type, license_])
    db_session.commit()

    db_session.add_all(
        [
            Tag(name="chakula", tag_type_id=tag_type.id, description="Food"),
            Tag(name="biashara", tag_type_id=tag_type.id),
        ]
    )
    db_session.add(
        Source(title="English Wiktionary", source_type="dump", license_id=license_.id)
    )
    db_session.commit()

    resp = client.get("/admin/tags", headers=HEADERS)
    assert resp.status_code == 200
    assert [tag["name"] for tag in resp.json()] == ["biashara", "chakula"]

    resp = client.get("/admin/tags", headers=HEADERS, params={"query": "chak"})
    assert [tag["name"] for tag in resp.json()] == ["chakula"]

    resp = client.get("/admin/sources", headers=HEADERS)
    assert resp.status_code == 200
    assert resp.json()[0]["title"] == "English Wiktionary"
    assert resp.json()[0]["license_id"] == str(license_.id)

    resp = client.get("/admin/licenses", headers=HEADERS)
    assert resp.status_code == 200
    assert resp.json()[0]["name"] == "CC BY-SA 4.0"


def test_lookups_bundle(client, db_session):
    db_session.add_all(
        [
            Language(code="sw", name="Swahili"),
            Language(code="en", name="English"),
            PartOfSpeech(code="NOUN", label="Noun"),
            PartOfSpeech(code="VERB", label="Verb"),
            ExpressionType(code="methali", label="Methali"),
            TagType(code="topic", label="Topic"),
        ]
    )
    db_session.commit()

    resp = client.get("/admin/lookups", headers=HEADERS)
    assert resp.status_code == 200
    data = resp.json()
    assert [item["code"] for item in data["languages"]] == ["en", "sw"]
    assert [item["code"] for item in data["parts_of_speech"]] == ["NOUN", "VERB"]
    assert data["tag_types"][0]["label"] == "Topic"
    assert data["expression_types"][0]["code"] == "methali"
    # Empty vocabularies still come back as lists, not null.
    assert data["registers"] == []
