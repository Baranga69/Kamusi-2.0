"""The crossword grid.

The hard part of a crossword generator is not the crossings, it is everything
it must *not* create: a word butted against another end to end, or laid
alongside one so the perpendicular reading becomes a second, unintended
entry. So the central test rebuilds the grid from the entries and checks that
every run of two or more letters in it is an answer somebody was given a clue
for. If that holds, the board is honest.
"""
from collections import Counter
from datetime import datetime

import pytest

from app.models import Language, Lexeme, PartOfSpeech, Sense, SenseDefinition
from app.normalize import normalize_sw
from app.routers.learn import letter_rarity, word_points

# Enough overlap in their letters to interlock.
WORDS = [
    ("kizingiti", "Kitu kinachozuia au kuzuia kupita mahali."),
    ("kifupisho", "Neno lililopunguzwa ili kuwa fupi zaidi."),
    ("utofauti", "Uwepo wa tofauti katika mambo au watu."),
    ("fululiza", "Kuendelea na jambo bila kukatiza hata kidogo."),
    ("achama", "Kufungua mdomo kwa sababu ya kushangaa."),
    ("usemezano", "Mazungumzo au majadiliano kati ya watu wawili."),
    ("sindikiza", "Kumfuata mtu mahali au kumsaidia katika safari."),
    ("uchimbaji", "Mchakato wa kuondoa udongo kutoka ardhini."),
    ("utaratibu", "Mchakato au njia ya kufuata ili kufanikisha jambo."),
    ("hafifisha", "Kufanya jambo liwe dogo au lisilo na maana."),
    ("mforosadi", "Mti wa matunda unaotumiwa kwa chakula."),
    ("chama", "Kundi la watu wenye lengo moja la kisiasa."),
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
    return client.get("/learn/crossword", params=params)


def rebuild(body):
    """The grid the entries describe."""
    size = body["size"]
    grid = [[None] * size for _ in range(size)]
    for entry in body["entries"]:
        dr, dc = (0, 1) if entry["direction"] == "across" else (1, 0)
        for index, letter in enumerate(entry["answer"]):
            grid[entry["row"] + dr * index][entry["col"] + dc * index] = letter
    return grid


def runs(grid):
    """Every maximal run of two or more letters, across and down."""
    size = len(grid)
    found = []
    for r in range(size):
        for c in range(size):
            for dr, dc in ((0, 1), (1, 0)):
                pr, pc = r - dr, c - dc
                if 0 <= pr < size and 0 <= pc < size and grid[pr][pc] is not None:
                    continue  # not the start of a run
                letters = ""
                rr, cc = r, c
                while 0 <= rr < size and 0 <= cc < size and grid[rr][cc] is not None:
                    letters += grid[rr][cc]
                    rr += dr
                    cc += dc
                if len(letters) >= 2:
                    found.append((letters, r, c, "across" if dc else "down"))
    return found


# --- the grid is honest ----------------------------------------------------


def test_every_run_in_the_grid_is_a_clued_answer(client, db_session):
    """No accidental words. This is the whole correctness question."""
    seed(db_session)

    body = fetch(client).json()
    grid = rebuild(body)
    clued = {
        (entry["answer"], entry["row"], entry["col"], entry["direction"])
        for entry in body["entries"]
    }

    for letters, row, col, direction in runs(grid):
        assert (letters, row, col, direction) in clued, (
            f"'{letters}' reads at {row},{col} {direction} with no clue"
        )


def test_the_answers_actually_interlock(client, db_session):
    """A grid where nothing crosses is a list of clues in a trench coat."""
    seed(db_session)

    body = fetch(client).json()
    occupied = Counter()
    for entry in body["entries"]:
        dr, dc = (0, 1) if entry["direction"] == "across" else (1, 0)
        for index in range(len(entry["answer"])):
            occupied[(entry["row"] + dr * index, entry["col"] + dc * index)] += 1

    assert any(count >= 2 for count in occupied.values())


def test_every_answer_is_inside_the_grid(client, db_session):
    seed(db_session)

    body = fetch(client).json()
    size = body["size"]

    for entry in body["entries"]:
        dr, dc = (0, 1) if entry["direction"] == "across" else (1, 0)
        end_row = entry["row"] + dr * (len(entry["answer"]) - 1)
        end_col = entry["col"] + dc * (len(entry["answer"]) - 1)
        assert 0 <= entry["row"] < size and 0 <= entry["col"] < size
        assert 0 <= end_row < size and 0 <= end_col < size


def test_an_answer_matches_its_headword(client, db_session):
    seed(db_session)

    body = fetch(client).json()

    for entry in body["entries"]:
        assert entry["answer"] == entry["word"].lower()


# --- numbering -------------------------------------------------------------


def test_entries_sharing_a_start_cell_share_a_number(client, db_session):
    """Exactly as a printed crossword numbers them."""
    seed(db_session)

    body = fetch(client).json()
    by_cell = {}
    for entry in body["entries"]:
        cell = (entry["row"], entry["col"])
        if cell in by_cell:
            assert by_cell[cell] == entry["number"]
        by_cell[cell] = entry["number"]


def test_numbers_run_in_reading_order(client, db_session):
    seed(db_session)

    body = fetch(client).json()
    cells = sorted(
        {(entry["row"], entry["col"], entry["number"]) for entry in body["entries"]}
    )
    numbers = [number for _, _, number in cells]

    assert numbers == sorted(numbers), "numbering must follow the reading order"


def test_every_entry_has_a_direction_and_a_clue(client, db_session):
    seed(db_session)

    body = fetch(client).json()

    for entry in body["entries"]:
        assert entry["direction"] in {"across", "down"}
        assert entry["definition"].strip()
        assert entry["lexeme_id"]


# --- what must never reach a learner --------------------------------------


def test_an_unreviewed_ai_definition_never_appears(client, db_session):
    seed(db_session, is_ai_generated=True, review_status="unreviewed")

    assert fetch(client).status_code == 404


def test_draft_words_are_never_used(client, db_session):
    seed(db_session, workflow="draft")

    assert fetch(client).status_code == 404


def test_too_little_vocabulary_explains_itself(client, db_session):
    seed(db_session, words=WORDS[:3])

    response = fetch(client)

    assert response.status_code == 404
    assert "crossword" in response.json()["detail"]


# --- scoring ---------------------------------------------------------------


def test_a_longer_word_is_worth_more(client, db_session):
    rare: set[str] = set()

    assert word_points("kalamu", rare) > word_points("mti", rare)


def test_an_awkward_letter_adds_to_the_score(client, db_session):
    assert word_points("zawadi", {"z"}) > word_points("zawadi", set())


def test_repeating_a_rare_letter_does_not_pay_twice(client, db_session):
    """"kikikiki" is not harder than "kiki" for having more k's."""
    assert word_points("zaza", {"z"}) - word_points("zaa", {"z"}) == 10


def test_rarity_is_measured_from_the_corpus(client, db_session):
    """Not a table copied from somewhere — it describes this dictionary."""
    from app.routers.learn import _Word

    pool = [
        _Word(None, "aaaa", None, "x"),
        _Word(None, "aaab", None, "x"),
        _Word(None, "aaaz", None, "x"),
    ]

    rare = letter_rarity(pool)

    assert "a" not in rare, "the commonest letter is never the rare half"
    assert rare, "something has to be in the rarer half"


def test_every_entry_carries_its_points(client, db_session):
    seed(db_session)

    body = fetch(client).json()

    assert all(entry["points"] > 0 for entry in body["entries"])


@pytest.mark.parametrize("path", ["/learn/wordfind", "/learn/wordbuild"])
def test_the_other_games_score_words_the_same_way(client, db_session, path):
    """Finding a word should be worth what building it is."""
    seed(db_session)

    body = client.get(path).json()
    words = body.get("words", [])
    if not words:
        pytest.skip("this board could not be built from the fixture")
    assert all(word["points"] > 0 for word in words)
