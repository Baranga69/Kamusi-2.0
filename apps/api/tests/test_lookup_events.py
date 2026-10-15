"""Recording which entries people open.

`search_entry.popularity` has always been part of result ordering and was
never written, so ranking ignored the one thing a dictionary uniquely knows:
what people actually look up.
"""
from sqlalchemy import func, select

from app.models import (
    Expression,
    ExpressionMeaning,
    ExpressionType,
    Language,
    Lexeme,
    LookupEvent,
    PartOfSpeech,
    Sense,
    SenseDefinition,
)
from app.normalize import normalize_sw


def make_lexeme(db_session, lemma: str = "mti") -> Lexeme:
    db_session.add(Language(code="sw", name="Swahili"))
    pos = PartOfSpeech(code="NOUN", label="Noun")
    db_session.add(pos)
    db_session.commit()

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

    sense = Sense(lexeme_id=lexeme.id, sense_number=1, workflow="published")
    db_session.add(sense)
    db_session.commit()
    db_session.add(
        SenseDefinition(
            sense_id=sense.id, lang_code="sw", definition="mmea mkubwa", is_primary=True
        )
    )
    db_session.commit()
    return lexeme


def event_count(db_session) -> int:
    return db_session.scalar(select(func.count()).select_from(LookupEvent))


def test_opening_an_entry_is_recorded(client, db_session):
    lexeme = make_lexeme(db_session)

    assert client.get(f"/lexemes/{lexeme.id}", params={"lang": "sw"}).status_code == 200

    event = db_session.scalars(select(LookupEvent)).one()
    assert event.target_type == "lexeme"
    assert event.target_id == lexeme.id
    assert event.lang_code == "sw"


def test_each_open_counts(client, db_session):
    lexeme = make_lexeme(db_session)
    for _ in range(3):
        client.get(f"/lexemes/{lexeme.id}", params={"lang": "sw"})

    assert event_count(db_session) == 3


def test_a_draft_preview_is_not_a_lookup(client, db_session):
    """An editor checking their own work says nothing about what readers want."""
    lexeme = make_lexeme(db_session)

    client.get(f"/lexemes/{lexeme.id}", params={"lang": "sw", "include_drafts": True})
    assert event_count(db_session) == 0


def test_looking_up_a_lemma_counts_once(client, db_session):
    lexeme = make_lexeme(db_session, "ng'ombe")

    response = client.get("/lookup/lemma", params={"lemma": "ngombe", "lang": "sw"})
    assert response.status_code == 200
    # The endpoint delegates to get_lexeme; that must not double-count.
    assert event_count(db_session) == 1


def test_a_missing_entry_records_nothing(client, db_session):
    make_lexeme(db_session)

    assert client.get("/lexemes/3f7c1a66-1b2e-4a9e-9a1f-2d6f4c8b0e11").status_code == 404
    assert event_count(db_session) == 0


def test_opening_an_expression_is_recorded(client, db_session):
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
            expression_id=expression.id, lang_code="sw", meaning="pupa huleta makosa", is_primary=True
        )
    )
    db_session.commit()

    assert client.get(f"/expressions/{expression.id}").status_code == 200

    event = db_session.scalars(select(LookupEvent)).one()
    assert event.target_type == "expression"
    assert event.target_id == expression.id


def test_searching_is_not_a_lookup(client, db_session):
    """A query may be a typo; opening an entry is the deliberate signal."""
    make_lexeme(db_session)

    client.get("/search", params={"q": "mti", "lang": "sw"})
    assert event_count(db_session) == 0
