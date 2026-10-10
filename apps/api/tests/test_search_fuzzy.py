"""Trigram "did you mean" pass.

Needs real Postgres: pg_trgm supplies the `%` operator and `similarity()`,
and SQLite has no equivalent, so the endpoint skips the fuzzy pass there.
"""
import pytest

from app.models import Language, Lexeme, PartOfSpeech, SearchEntry
from app.normalize import normalize_sw

pytestmark = pytest.mark.postgres


def seed(db_session, lemmas: list[str]) -> dict[str, Lexeme]:
    db_session.add(Language(code="sw", name="Swahili"))
    pos = PartOfSpeech(code="NOUN", label="Noun")
    db_session.add(pos)
    db_session.commit()

    out = {}
    for lemma in lemmas:
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
            )
        )
        out[lemma] = lexeme
    db_session.commit()
    return out


def test_misspelling_finds_the_word(client, db_session):
    seed(db_session, ["ng'ombe", "kitabu", "mwalimu"])

    # No substring match for this typo, so the strict pass returns nothing.
    results = client.get("/search", params={"q": "ngombee", "lang": "sw"}).json()
    assert [r["lemma"] for r in results] == ["ng'ombe"]
    assert results[0]["is_fuzzy"] is True


def test_exact_matches_are_not_flagged_fuzzy_and_come_first(client, db_session):
    seed(db_session, ["kitabu", "kitabua", "vitabu"])

    results = client.get("/search", params={"q": "kitabu", "lang": "sw"}).json()
    # kitabu and kitabua both contain "kitabu", so both are strict hits;
    # "vitabu" can only arrive through similarity and must sort after them.
    strict = [r for r in results if not r["is_fuzzy"]]
    fuzzy = [r for r in results if r["is_fuzzy"]]
    assert [r["lemma"] for r in strict] == ["kitabu", "kitabua"]
    assert [r["lemma"] for r in fuzzy] == ["vitabu"]
    assert results.index(strict[-1]) < results.index(fuzzy[0])


def test_fuzzy_can_be_turned_off(client, db_session):
    seed(db_session, ["ng'ombe"])
    assert client.get("/search", params={"q": "ngombee", "lang": "sw", "fuzzy": False}).json() == []


def test_fuzzy_never_exceeds_the_limit(client, db_session):
    seed(db_session, ["kitabu", "kitaba", "kitabo", "kitabe", "kitabi"])

    results = client.get("/search", params={"q": "kitabu", "lang": "sw", "limit": 3}).json()
    assert len(results) == 3


def test_fuzzy_respects_visibility(client, db_session):
    lexemes = seed(db_session, ["ng'ombe"])
    lexemes["ng'ombe"].workflow = "archived"
    db_session.commit()

    # A near spelling must not be a way around the workflow filter.
    assert client.get("/search", params={"q": "ngombee", "lang": "sw"}).json() == []


def test_unrelated_word_is_not_returned(client, db_session):
    seed(db_session, ["ng'ombe", "kitabu"])
    assert client.get("/search", params={"q": "zzzzzzq", "lang": "sw"}).json() == []
