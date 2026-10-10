"""Regression tests for the five defects the /search query used to carry.

1. the limit was applied before resolution/filtering, so a request for N
   results could return fewer and drop good matches outside the window
2. the outer select had no ORDER BY, so rank/popularity order was not guaranteed
3. nothing checked `workflow`, so archived or draft entries stayed searchable
4. expressions were indexed on publish but could never be resolved, so they
   never appeared in results at all
5. publish_expression wrote meanings over the expression's own index entry
"""
import uuid

from app.models import (
    Expression,
    ExpressionMeaning,
    ExpressionType,
    Language,
    Lexeme,
    PartOfSpeech,
    SearchEntry,
    Sense,
    SenseDefinition,
)
from app.normalize import normalize_sw
from app.services.publish import publish_expression, publish_lexeme


def seed_lookups(db_session) -> PartOfSpeech:
    db_session.add_all([Language(code="sw", name="Swahili"), Language(code="en", name="English")])
    pos = PartOfSpeech(code="NOUN", label="Noun")
    db_session.add(pos)
    db_session.commit()
    return pos


def make_lexeme(db_session, pos, lemma: str, workflow: str = "published") -> Lexeme:
    lexeme = Lexeme(
        lemma=lemma,
        normalized_lemma=normalize_sw(lemma),
        pos_id=pos.id,
        status="core",
        default_language_code="sw",
        workflow=workflow,
    )
    db_session.add(lexeme)
    db_session.commit()
    return lexeme


def index(db_session, *, target_type: str, target_id, text: str, lang: str = "sw", popularity: int = 0) -> None:
    db_session.add(
        SearchEntry(
            target_type=target_type,
            target_id=target_id,
            lang_code=lang,
            text=text,
            normalized=normalize_sw(text),
            popularity=popularity,
        )
    )
    db_session.commit()


def test_archived_lexeme_is_not_searchable(client, db_session):
    pos = seed_lookups(db_session)
    live = make_lexeme(db_session, pos, "mti", workflow="published")
    archived = make_lexeme(db_session, pos, "mtima", workflow="archived")
    draft = make_lexeme(db_session, pos, "mtimu", workflow="draft")
    for lexeme in (live, archived, draft):
        index(db_session, target_type="lexeme", target_id=lexeme.id, text=lexeme.lemma)

    results = client.get("/search", params={"q": "mti", "lang": "sw"}).json()
    assert [r["lemma"] for r in results] == ["mti"]

    # include_drafts is the explicit opt-in for unpublished content.
    results = client.get("/search", params={"q": "mti", "lang": "sw", "include_drafts": True}).json()
    assert sorted(r["lemma"] for r in results) == ["mti", "mtima", "mtimu"]


def test_draft_sense_hides_its_definition_hit(client, db_session):
    pos = seed_lookups(db_session)
    lexeme = make_lexeme(db_session, pos, "mti")
    sense = Sense(lexeme_id=lexeme.id, sense_number=1, workflow="draft")
    db_session.add(sense)
    db_session.commit()
    definition = SenseDefinition(
        sense_id=sense.id, lang_code="sw", definition="mmea wenye shina gumu", is_primary=True
    )
    db_session.add(definition)
    db_session.commit()
    index(db_session, target_type="definition", target_id=definition.id, text=definition.definition)

    assert client.get("/search", params={"q": "shina", "lang": "sw"}).json() == []

    sense.workflow = "published"
    db_session.commit()
    results = client.get("/search", params={"q": "shina", "lang": "sw"}).json()
    assert [r["match_kind"] for r in results] == ["definition"]


def test_unreviewed_ai_definition_does_not_surface(client, db_session):
    pos = seed_lookups(db_session)
    lexeme = make_lexeme(db_session, pos, "mti")
    sense = Sense(lexeme_id=lexeme.id, sense_number=1, workflow="published")
    db_session.add(sense)
    db_session.commit()
    definition = SenseDefinition(
        sense_id=sense.id,
        lang_code="sw",
        definition="maelezo ya roboti yasiyopitiwa",
        is_primary=True,
        is_ai_generated=True,
        review_status="unreviewed",
    )
    db_session.add(definition)
    db_session.commit()
    index(db_session, target_type="definition", target_id=definition.id, text=definition.definition)

    assert client.get("/search", params={"q": "roboti", "lang": "sw"}).json() == []

    definition.review_status = "approved"
    db_session.commit()
    assert len(client.get("/search", params={"q": "roboti", "lang": "sw"}).json()) == 1


def test_orphaned_index_entry_is_dropped(client, db_session):
    seed_lookups(db_session)
    index(db_session, target_type="lexeme", target_id=uuid.uuid4(), text="mzimu")
    assert client.get("/search", params={"q": "mzimu", "lang": "sw"}).json() == []


def test_limit_is_applied_after_filtering(client, db_session):
    """A full window of hidden entries must not crowd out visible ones."""
    pos = seed_lookups(db_session)
    # 10 archived entries that sort ahead of the visible one on popularity.
    for i in range(10):
        hidden = make_lexeme(db_session, pos, f"paka{i}", workflow="archived")
        index(db_session, target_type="lexeme", target_id=hidden.id, text=hidden.lemma, popularity=100)
    visible = make_lexeme(db_session, pos, "pakaz", workflow="published")
    index(db_session, target_type="lexeme", target_id=visible.id, text=visible.lemma, popularity=1)

    results = client.get("/search", params={"q": "paka", "lang": "sw", "limit": 5}).json()
    assert [r["lemma"] for r in results] == ["pakaz"]


def test_ranking_is_deterministic_and_ordered(client, db_session):
    pos = seed_lookups(db_session)
    for lemma, popularity in [("samti", 30), ("mtish", 20), ("mti", 10)]:
        lexeme = make_lexeme(db_session, pos, lemma)
        index(db_session, target_type="lexeme", target_id=lexeme.id, text=lemma, popularity=popularity)

    # Exact match first, then prefix, then substring — rank beats popularity.
    for _ in range(3):
        results = client.get("/search", params={"q": "mti", "lang": "sw"}).json()
        assert [r["text"] for r in results] == ["mti", "mtish", "samti"]


def test_expressions_are_searchable(client, db_session):
    seed_lookups(db_session)
    methali = ExpressionType(code="methali", label="Methali")
    db_session.add(methali)
    db_session.commit()

    expression = Expression(
        text="Haraka haraka haina baraka",
        normalized_text=normalize_sw("Haraka haraka haina baraka"),
        expression_type_id=methali.id,
        workflow="draft",
    )
    db_session.add(expression)
    db_session.commit()
    meaning = ExpressionMeaning(
        expression_id=expression.id,
        lang_code="sw",
        meaning="Kufanya mambo kwa pupa huleta makosa",
        is_primary=True,
    )
    db_session.add(meaning)
    db_session.commit()

    publish_expression(db_session, expression.id)

    # The expression's own text is reachable...
    results = client.get("/search", params={"q": "baraka", "lang": "sw"}).json()
    assert [r["match_kind"] for r in results] == ["expression"]
    assert results[0]["expression_id"] == str(expression.id)
    assert results[0]["expression_text"] == "Haraka haraka haina baraka"
    assert results[0]["lexeme_id"] is None

    # ...and so is its meaning, resolved back to the same expression.
    results = client.get("/search", params={"q": "pupa", "lang": "sw"}).json()
    assert [r["match_kind"] for r in results] == ["meaning"]
    assert results[0]["expression_id"] == str(expression.id)
    assert results[0]["expression_text"] == "Haraka haraka haina baraka"


def test_publishing_an_expression_keeps_text_and_meaning_separate(db_session):
    """The sw meaning used to overwrite the sw entry for the expression text."""
    methali = ExpressionType(code="methali", label="Methali")
    db_session.add_all([Language(code="sw", name="Swahili"), methali])
    db_session.commit()

    expression = Expression(
        text="Polepole ndiyo mwendo",
        normalized_text=normalize_sw("Polepole ndiyo mwendo"),
        expression_type_id=methali.id,
        workflow="draft",
    )
    db_session.add(expression)
    db_session.commit()
    db_session.add(
        ExpressionMeaning(
            expression_id=expression.id,
            lang_code="sw",
            meaning="Uvumilivu huleta mafanikio",
            is_primary=True,
        )
    )
    db_session.commit()

    publish_expression(db_session, expression.id)

    entries = {(e.target_type, e.lang_code): e.text for e in db_session.query(SearchEntry).all()}
    assert entries[("expression", "sw")] == "Polepole ndiyo mwendo"
    assert entries[("expression_meaning", "sw")] == "Uvumilivu huleta mafanikio"


def test_archived_expression_is_not_searchable(client, db_session):
    seed_lookups(db_session)
    methali = ExpressionType(code="methali", label="Methali")
    db_session.add(methali)
    db_session.commit()
    expression = Expression(
        text="Mvumilivu hula mbivu",
        normalized_text=normalize_sw("Mvumilivu hula mbivu"),
        expression_type_id=methali.id,
        workflow="archived",
    )
    db_session.add(expression)
    db_session.commit()
    index(db_session, target_type="expression", target_id=expression.id, text=expression.text)

    assert client.get("/search", params={"q": "mbivu", "lang": "sw"}).json() == []


def test_blank_query_after_normalization_returns_nothing(client, db_session):
    pos = seed_lookups(db_session)
    lexeme = make_lexeme(db_session, pos, "mti")
    index(db_session, target_type="lexeme", target_id=lexeme.id, text="mti")

    # "!!!" normalizes to the empty string, which would otherwise LIKE '%%'
    # and match every row in the index.
    assert client.get("/search", params={"q": "!!!", "lang": "sw"}).json() == []


def test_published_examples_are_indexed_and_searchable(client, db_session):
    from app.models import Example, ExampleText

    pos = seed_lookups(db_session)
    lexeme = make_lexeme(db_session, pos, "mti", workflow="draft")
    sense = Sense(lexeme_id=lexeme.id, sense_number=1, workflow="draft")
    db_session.add(sense)
    db_session.commit()
    db_session.add(
        SenseDefinition(sense_id=sense.id, lang_code="sw", definition="mmea", is_primary=True)
    )
    example = Example(sense_id=sense.id, is_attested=True)
    db_session.add(example)
    db_session.commit()
    db_session.add(
        ExampleText(
            example_id=example.id,
            lang_code="sw",
            text="Nimepanda mti nyuma ya nyumba",
            is_primary=True,
        )
    )
    db_session.commit()

    publish_lexeme(db_session, lexeme.id)

    results = client.get("/search", params={"q": "nyumba", "lang": "sw"}).json()
    assert [r["match_kind"] for r in results] == ["example"]
    assert results[0]["lexeme_id"] == str(lexeme.id)
    assert results[0]["lemma"] == "mti"


def test_one_result_per_entry_preferring_the_headword(client, db_session):
    """A word matching on its lemma, definition and example is listed once."""
    from app.models import Example, ExampleText

    pos = seed_lookups(db_session)
    lexeme = make_lexeme(db_session, pos, "mti", workflow="draft")
    sense = Sense(lexeme_id=lexeme.id, sense_number=1, workflow="draft")
    db_session.add(sense)
    db_session.commit()
    db_session.add(
        SenseDefinition(
            sense_id=sense.id,
            lang_code="sw",
            definition="mti ni mmea mkubwa",
            is_primary=True,
        )
    )
    example = Example(sense_id=sense.id, is_attested=True)
    db_session.add(example)
    db_session.commit()
    db_session.add(
        ExampleText(example_id=example.id, lang_code="sw", text="Mti huu ni mrefu", is_primary=True)
    )
    db_session.commit()

    publish_lexeme(db_session, lexeme.id)

    # All three index rows contain "mti".
    assert db_session.query(SearchEntry).count() == 3

    results = client.get("/search", params={"q": "mti", "lang": "sw"}).json()
    assert len(results) == 1
    assert results[0]["match_kind"] == "lemma"
    assert results[0]["lexeme_id"] == str(lexeme.id)


def test_distinct_entries_are_all_returned(client, db_session):
    """Collapsing per entry must not collapse across entries."""
    pos = seed_lookups(db_session)
    for lemma in ["mti", "mtima", "mtimu"]:
        lexeme = make_lexeme(db_session, pos, lemma)
        index(db_session, target_type="lexeme", target_id=lexeme.id, text=lemma)

    results = client.get("/search", params={"q": "mti", "lang": "sw"}).json()
    assert sorted(r["lemma"] for r in results) == ["mti", "mtima", "mtimu"]
