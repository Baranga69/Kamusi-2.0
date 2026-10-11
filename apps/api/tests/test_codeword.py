"""The codeword board.

Every letter is a number, the same number everywhere it occurs, and cracking
one letter opens it in every word. The tests pin the properties that make that
possible: the key covers every letter used, it is a bijection, and the
alphabet stays small enough for numbers to repeat. A board where each number
appears once is a substitution with nothing to deduce.
"""
from collections import Counter
from datetime import datetime

from app.models import Language, Lexeme, PartOfSpeech, Sense, SenseDefinition
from app.normalize import normalize_sw

# Deliberately overlapping, so they share an alphabet the way a board needs.
WORDS = [
    ("nini", "Neno linalotumiwa kuuliza kuhusu kitu au jambo."),
    ("nuna", "Kuonyesha kutoridhika kwa uso au kimya."),
    ("unono", "Hali ya kuwa mnene au kunenepa vizuri."),
    ("inua", "Kuinua kitu juu kutoka mahali kilipo."),
    ("nunua", "Kutoa pesa ili kupata kitu kutoka kwa muuzaji."),
    ("anuani", "Mahali rasmi pa mtu au shirika kwa barua."),
]


def seed(db_session, words=None, *, workflow="published", **definition_kwargs):
    db_session.add_all([Language(code="sw", name="Swahili"), Language(code="en", name="English")])
    pos = PartOfSpeech(code="NOUN", label="Noun")
    db_session.add(pos)
    db_session.commit()

    for lemma, definition in words or WORDS:
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
    return client.get("/learn/codeword", params=params)


# --- the key works ---------------------------------------------------------


def test_every_letter_used_has_a_number(client, db_session):
    """A cell with no number in the key would be unfillable."""
    seed(db_session)

    body = fetch(client).json()

    used = set("".join(entry["letters"] for entry in body["entries"]))
    assert used.issubset(body["codes"].keys())


def test_no_two_letters_share_a_number(client, db_session):
    """Otherwise one number would have two right answers."""
    seed(db_session)

    body = fetch(client).json()
    numbers = list(body["codes"].values())

    assert len(numbers) == len(set(numbers))


def test_numbers_are_a_contiguous_run_from_one(client, db_session):
    """Players read them as a key to fill in, not as arbitrary labels."""
    seed(db_session)

    body = fetch(client).json()

    assert sorted(body["codes"].values()) == list(range(1, len(body["codes"]) + 1))


def test_the_alphabet_stays_small_enough_to_deduce(client, db_session):
    seed(db_session)

    body = fetch(client).json()

    assert len(body["codes"]) <= 13


def test_numbers_actually_repeat(client, db_session):
    """The whole game is that cracking a letter opens it everywhere."""
    seed(db_session)

    body = fetch(client).json()
    letters = Counter("".join(entry["letters"] for entry in body["entries"]))

    assert max(letters.values()) >= 2


# --- somewhere to start ----------------------------------------------------


def test_some_letters_are_given_away(client, db_session):
    seed(db_session)

    body = fetch(client).json()

    assert body["revealed"]
    assert all(letter in body["codes"] for letter in body["revealed"])


def test_the_given_letters_are_actually_used(client, db_session):
    """Revealing a letter that appears nowhere is not a head start."""
    seed(db_session)

    body = fetch(client).json()
    used = set("".join(entry["letters"] for entry in body["entries"]))

    assert all(letter in used for letter in body["revealed"])


def test_not_everything_is_given_away(client, db_session):
    seed(db_session)

    body = fetch(client).json()

    assert len(body["revealed"]) < len(body["codes"])


# --- the words themselves --------------------------------------------------


def test_every_entry_has_a_clue(client, db_session):
    seed(db_session)

    body = fetch(client).json()

    for entry in body["entries"]:
        assert entry["definition"].strip()
        assert entry["lexeme_id"]


def test_no_word_appears_twice(client, db_session):
    seed(db_session)

    body = fetch(client).json()
    spellings = [entry["letters"] for entry in body["entries"]]

    assert len(spellings) == len(set(spellings))


# --- what must never reach a learner --------------------------------------


def test_an_unreviewed_ai_definition_never_appears(client, db_session):
    seed(db_session, is_ai_generated=True, review_status="unreviewed")

    assert fetch(client).status_code == 404


def test_draft_words_are_never_used(client, db_session):
    seed(db_session, workflow="draft")

    assert fetch(client).status_code == 404


def test_too_few_words_explains_itself(client, db_session):
    seed(db_session, words=WORDS[:2])

    response = fetch(client)

    assert response.status_code == 404
    assert "codeword" in response.json()["detail"]
