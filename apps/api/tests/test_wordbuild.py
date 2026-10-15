"""The ring of letters.

Nothing is hidden in this one: every word is spellable from the letters on
screen, and the challenge is knowing enough Swahili to see them. So the tests
care that the ring is honest — every answer really is spellable, exactly one
word uses the whole ring — and that nothing unreviewed reaches a learner.
"""
from collections import Counter
from datetime import datetime

from app.models import Language, Lexeme, PartOfSpeech, Sense, SenseDefinition
from app.normalize import normalize_sw

# "momonyoa" is the eight-letter base; the rest are spellable from its letters.
RING = [
    ("momonyoa", "Kuondoa ardhi kwa taratibu kwa maji au upepo."),
    ("maono", "Picha au taswira inayoweza kuonekana akilini."),
    ("nyoa", "Kukata nywele au kuondoa nywele kwenye ngozi."),
    ("onya", "Kutoa tahadhari au ushauri kwa mtu fulani."),
    ("onyo", "Tahadhari inayotolewa kwa mtu kabla ya jambo."),
    ("mno", "Kwa kiwango kikubwa au sana kupita kiasi."),
    ("noa", "Kunoa kitu ili kiwe kikali zaidi kwa matumizi."),
]


def seed(db_session, words=None, *, workflow="published", **definition_kwargs):
    db_session.add_all([Language(code="sw", name="Swahili"), Language(code="en", name="English")])
    pos = PartOfSpeech(code="VERB", label="Verb")
    db_session.add(pos)
    db_session.commit()

    for lemma, definition in words or RING:
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
        sense = Sense(lexeme_id=lexeme.id, sense_number=1, workflow=workflow)
        db_session.add(sense)
        db_session.commit()
        db_session.add(
            SenseDefinition(
                sense_id=sense.id,
                lang_code="sw",
                definition=definition,
                is_primary=True,
                created_at=datetime.utcnow(),
                **definition_kwargs,
            )
        )
        db_session.commit()


def fetch(client, **params):
    return client.get("/learn/wordbuild", params=params)


# --- the ring is honest ----------------------------------------------------


def test_the_ring_has_eight_letters(client, db_session):
    seed(db_session)

    body = fetch(client).json()

    assert len(body["letters"]) == 8
    assert all(len(letter) == 1 for letter in body["letters"])


def test_every_word_is_spellable_from_the_ring(client, db_session):
    """Otherwise the puzzle is unwinnable and the player cannot know why."""
    seed(db_session)

    body = fetch(client).json()
    available = Counter(body["letters"])

    assert body["words"]
    for word in body["words"]:
        needed = Counter(word["letters"])
        for letter, count in needed.items():
            assert count <= available[letter], f"{word['word']} needs more {letter}"


def test_exactly_one_word_uses_the_whole_ring(client, db_session):
    """The pangram is what makes the letters a set rather than a jumble."""
    seed(db_session)

    body = fetch(client).json()
    pangrams = [word for word in body["words"] if word["is_pangram"]]

    assert len(pangrams) == 1
    assert len(pangrams[0]["letters"]) == len(body["letters"])
    assert Counter(pangrams[0]["letters"]) == Counter(body["letters"])


def test_no_spelling_appears_twice(client, db_session):
    """Two entries spelled the same are one answer to a player."""
    seed(db_session)

    body = fetch(client).json()
    spellings = [word["letters"] for word in body["words"]]

    assert len(spellings) == len(set(spellings))


def test_every_word_carries_its_meaning(client, db_session):
    """The definitions are the hints in easy mode and the reward in hard."""
    seed(db_session)

    body = fetch(client).json()

    for word in body["words"]:
        assert word["definition"].strip()
        assert word["lexeme_id"]


def test_words_are_long_enough_to_be_words(client, db_session):
    seed(db_session)

    body = fetch(client).json()

    assert all(len(word["letters"]) >= 3 for word in body["words"])


# --- what must never reach a learner --------------------------------------


def test_an_unreviewed_ai_definition_never_appears(client, db_session):
    seed(db_session, is_ai_generated=True, review_status="unreviewed")

    assert fetch(client).status_code == 404


def test_an_approved_ai_definition_is_allowed(client, db_session):
    seed(db_session, is_ai_generated=True, review_status="approved")

    assert fetch(client).json()["words"]


def test_draft_words_are_never_used(client, db_session):
    seed(db_session, workflow="draft")

    assert fetch(client).status_code == 404


# --- when the corpus cannot support it ------------------------------------


def test_a_base_with_too_few_sub_words_is_not_offered(client, db_session):
    """A ring you solve in one move is not a puzzle."""
    seed(
        db_session,
        words=[
            ("momonyoa", "Kuondoa ardhi kwa taratibu kwa maji au upepo."),
            ("nyoa", "Kukata nywele au kuondoa nywele kwenye ngozi."),
        ],
    )

    assert fetch(client).status_code == 404


def test_an_empty_dictionary_explains_itself(client, db_session):
    response = fetch(client)

    assert response.status_code == 404
    assert "8-letter" in response.json()["detail"]
