"""The word-find grid.

The puzzle is only a way in; the definition revealed on finding a word is the
thing a learner leaves with. So the tests care about two things: that the grid
is internally consistent (a client validating a drag locally must get the same
answer the server intended), and that nothing reaches it which has not cleared
review — a game is a worse place than most to teach an unreviewed machine
translation.
"""
from datetime import datetime

from app.models import Language, Lexeme, PartOfSpeech, Sense, SenseDefinition
from app.normalize import normalize_sw

# Lengths 4-9, letters only, so every one is placeable in a default grid.
GRID_WORDS = [
    ("kalamu", "NOUN", "Chombo cha kuandikia chenye wino."),
    ("mlango", "NOUN", "Kitu kinachofunga njia ya kuingia."),
    ("kitabu", "NOUN", "Karatasi zilizofungwa pamoja kwa kusoma."),
    ("shule", "NOUN", "Mahali ambapo watoto hujifunza."),
    ("chakula", "NOUN", "Kitu chochote kinacholiwa na watu."),
    ("mwalimu", "NOUN", "Mtu anayefundisha wanafunzi shuleni."),
    ("bahari", "NOUN", "Eneo kubwa la maji ya chumvi."),
    ("safari", "NOUN", "Kwenda kutoka mahali pamoja kwenda pengine."),
]


def seed(db_session, words=None, *, workflow="published", **definition_kwargs):
    db_session.add_all([Language(code="sw", name="Swahili"), Language(code="en", name="English")])
    pos = PartOfSpeech(code="NOUN", label="Noun")
    db_session.add(pos)
    db_session.commit()

    for lemma, _, definition in words or GRID_WORDS:
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
    return client.get("/learn/wordfind", params=params)


# --- the grid holds together ----------------------------------------------


def test_the_grid_is_square_and_the_size_asked_for(client, db_session):
    seed(db_session)

    body = fetch(client, size=11).json()

    assert body["size"] == 11
    assert len(body["rows"]) == 11
    assert all(len(row) == 11 for row in body["rows"])


def test_every_path_spells_its_word_in_the_grid(client, db_session):
    """The client validates a drag against these cells; they must agree."""
    seed(db_session)

    body = fetch(client).json()

    assert body["words"], "a puzzle with no words is not a puzzle"
    for word in body["words"]:
        spelled = "".join(body["rows"][r][c] for r, c in word["cells"])
        assert spelled == word["letters"], word["word"]


def test_every_cell_is_inside_the_grid(client, db_session):
    seed(db_session)

    body = fetch(client).json()
    size = body["size"]

    for word in body["words"]:
        for row, col in word["cells"]:
            assert 0 <= row < size and 0 <= col < size


def test_a_path_is_a_straight_unbroken_line(client, db_session):
    """Anything else cannot be selected by one drag."""
    seed(db_session)

    body = fetch(client).json()

    for word in body["words"]:
        cells = word["cells"]
        assert len(cells) == len(word["letters"])
        steps = {
            (cells[i + 1][0] - cells[i][0], cells[i + 1][1] - cells[i][1])
            for i in range(len(cells) - 1)
        }
        assert len(steps) == 1, f"{word['word']} bends"
        (dr, dc), = steps
        assert (dr, dc) != (0, 0)
        assert abs(dr) <= 1 and abs(dc) <= 1


def test_the_grid_is_only_letters(client, db_session):
    seed(db_session)

    body = fetch(client).json()

    assert all(row.isalpha() and row.islower() for row in body["rows"])


def test_no_word_appears_twice(client, db_session):
    """Two identical spellings would be indistinguishable in the grid."""
    seed(db_session)

    body = fetch(client).json()
    letters = [word["letters"] for word in body["words"]]

    assert len(letters) == len(set(letters))


def test_every_word_carries_the_meaning_to_reveal(client, db_session):
    """Without the definition the puzzle teaches nothing."""
    seed(db_session)

    body = fetch(client).json()

    for word in body["words"]:
        assert word["definition"].strip()
        assert word["lexeme_id"], "has to link back to the entry"


def test_it_asks_for_no_more_words_than_requested(client, db_session):
    seed(db_session)

    body = fetch(client, count=3).json()

    assert len(body["words"]) <= 3


# --- what must never reach a learner --------------------------------------


def test_an_unreviewed_ai_definition_is_never_hidden_in_the_grid(client, db_session):
    """The same guard as every other read path."""
    seed(db_session, is_ai_generated=True, review_status="unreviewed")

    response = fetch(client)

    assert response.status_code == 404


def test_an_approved_ai_definition_is_allowed(client, db_session):
    seed(db_session, is_ai_generated=True, review_status="approved")

    body = fetch(client).json()

    assert body["words"]


def test_draft_words_are_never_used(client, db_session):
    seed(db_session, workflow="draft")

    assert fetch(client).status_code == 404


def test_a_word_with_an_apostrophe_is_skipped(client, db_session):
    """"ng'ombe" cannot be laid out one letter per cell."""
    seed(db_session, words=[("ng'ombe", "NOUN", "Mnyama wa nyumbani anayefugwa.")])

    assert fetch(client).status_code == 404


def test_a_multiword_headword_is_skipped(client, db_session):
    seed(db_session, words=[("afya ya akili", "NOUN", "Hali ya kuwa na akili nzuri.")])

    assert fetch(client).status_code == 404


def test_a_word_too_short_to_hunt_for_is_skipped(client, db_session):
    seed(db_session, words=[("mti", "NOUN", "Mmea mkubwa wenye shina gumu.")])

    assert fetch(client).status_code == 404


def test_an_empty_dictionary_explains_itself(client, db_session):
    response = fetch(client)

    assert response.status_code == 404
    assert "reviewed definition" in response.json()["detail"]


# --- shape of the request --------------------------------------------------


def test_an_absurd_grid_size_is_refused(client, db_session):
    seed(db_session)

    assert fetch(client, size=40).status_code == 422
    assert fetch(client, size=2).status_code == 422
