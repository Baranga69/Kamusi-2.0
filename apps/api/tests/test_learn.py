"""Question rounds for the Jifunze surface."""
from datetime import datetime

from app.models import (
    Expression,
    ExpressionMeaning,
    ExpressionType,
    Language,
    Lexeme,
    PartOfSpeech,
    Sense,
    SenseDefinition,
)
from app.normalize import normalize_sw

WORDS = [
    ("mti", "NOUN", "Mmea mkubwa wenye shina gumu na matawi."),
    ("kitabu", "NOUN", "Karatasi zilizofungwa pamoja kwa kusoma."),
    ("mwalimu", "NOUN", "Mtu anayefundisha wanafunzi shuleni."),
    ("shule", "NOUN", "Mahali ambapo watoto hujifunza."),
    ("chakula", "NOUN", "Kitu chochote kinacholiwa na watu."),
    ("maji", "NOUN", "Kiowevu kisicho na rangi tunakinywa."),
]

METHALI = [
    ("Haraka haraka haina baraka", "Kufanya mambo kwa pupa huleta makosa."),
    ("Polepole ndiyo mwendo wa busara", "Uvumilivu huleta mafanikio."),
    ("Mvumilivu hula mbivu za mtini", "Subira huzaa matunda mazuri."),
    ("Umoja ni nguvu utengano ni udhaifu", "Kushirikiana huleta nguvu."),
    ("Mtoto umleavyo ndivyo akuavyo", "Malezi huamua tabia ya mtoto."),
]


def seed_words(db_session, words=None, workflow="published", **definition_kwargs):
    db_session.add(Language(code="sw", name="Swahili"))
    db_session.add(Language(code="en", name="English"))
    pos_codes = {code for _, code, _ in (words or WORDS)}
    pos_by_code = {}
    for code in sorted(pos_codes):
        pos = PartOfSpeech(code=code, label=code.title())
        db_session.add(pos)
        pos_by_code[code] = pos
    db_session.commit()

    for lemma, pos_code, definition in words or WORDS:
        lexeme = Lexeme(
            lemma=lemma,
            normalized_lemma=normalize_sw(lemma),
            pos_id=pos_by_code[pos_code].id,
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


def seed_methali(db_session, workflow="published"):
    if not db_session.query(Language).filter_by(code="sw").first():
        db_session.add(Language(code="sw", name="Swahili"))
    expression_type = ExpressionType(code="methali", label="Methali")
    db_session.add(expression_type)
    db_session.commit()

    for text, meaning in METHALI:
        expression = Expression(
            text=text,
            normalized_text=normalize_sw(text),
            expression_type_id=expression_type.id,
            workflow=workflow,
        )
        db_session.add(expression)
        db_session.commit()
        db_session.add(
            ExpressionMeaning(
                expression_id=expression.id,
                lang_code="sw",
                meaning=meaning,
                is_primary=True,
            )
        )
    db_session.commit()


def assert_well_formed(question: dict) -> None:
    """Every question has to be answerable and have exactly one answer."""
    options = question["options"]
    assert len(options) == 4, options
    assert len(set(options)) == 4, f"duplicate options make it ambiguous: {options}"
    assert 0 <= question["answer_index"] < 4
    assert question["prompt"].strip()
    assert all(option.strip() for option in options)
    # The prompt must not give the answer away.
    assert question["prompt"] not in options


# --- definition and meaning ----------------------------------------------


def test_definition_round_is_answerable(client, db_session):
    seed_words(db_session)

    body = client.get("/learn/round", params={"kind": "definition", "count": 4}).json()
    assert body["kind"] == "definition"
    assert len(body["questions"]) == 4

    definitions = {definition for _, _, definition in WORDS}
    for question in body["questions"]:
        assert_well_formed(question)
        assert question["kind"] == "definition"
        # Prompt is the headword, options are definitions.
        assert question["prompt"] in {lemma for lemma, _, _ in WORDS}
        assert question["options"][question["answer_index"]] in definitions
        # So the app can open the entry afterwards.
        assert question["lexeme_id"] is not None


def test_definition_question_pairs_the_right_word_with_its_meaning(client, db_session):
    seed_words(db_session)
    expected = {lemma: definition for lemma, _, definition in WORDS}

    body = client.get("/learn/round", params={"kind": "definition", "count": 6}).json()
    for question in body["questions"]:
        answer = question["options"][question["answer_index"]]
        assert answer == expected[question["prompt"]], question["prompt"]


def test_meaning_round_flips_the_question(client, db_session):
    seed_words(db_session)
    expected = {definition: lemma for lemma, _, definition in WORDS}

    body = client.get("/learn/round", params={"kind": "meaning", "count": 4}).json()
    for question in body["questions"]:
        assert_well_formed(question)
        assert question["kind"] == "meaning"
        answer = question["options"][question["answer_index"]]
        assert answer == expected[question["prompt"]]


# --- methali --------------------------------------------------------------


def test_methali_round_completes_the_proverb(client, db_session):
    seed_methali(db_session)
    endings = {text.split()[len(text.split()) // 2:][0] for text, _ in METHALI}

    body = client.get("/learn/round", params={"kind": "methali", "count": 4}).json()
    assert len(body["questions"]) == 4

    for question in body["questions"]:
        assert_well_formed(question)
        assert question["kind"] == "methali"
        assert question["expression_id"] is not None
        # The opening plus the right ending reconstructs a real proverb.
        reassembled = f"{question['prompt']} {question['options'][question['answer_index']]}"
        assert reassembled in {text for text, _ in METHALI}
        assert question["options"][question["answer_index"]].split()[0] in endings


def test_methali_prompt_carries_the_meaning_as_a_hint(client, db_session):
    seed_methali(db_session)
    meanings = {meaning for _, meaning in METHALI}

    body = client.get("/learn/round", params={"kind": "methali", "count": 3}).json()
    for question in body["questions"]:
        assert question["prompt_detail"] in meanings


# --- visibility -----------------------------------------------------------


def test_unpublished_words_are_never_quizzed(client, db_session):
    seed_words(db_session, workflow="draft")
    assert client.get("/learn/round", params={"kind": "definition"}).json()["questions"] == []


def test_unreviewed_ai_definitions_are_never_quizzed(client, db_session):
    """A game is the worst place to teach an unreviewed machine translation."""
    seed_words(db_session, is_ai_generated=True, review_status="unreviewed")
    assert client.get("/learn/round", params={"kind": "definition"}).json()["questions"] == []


def test_approved_ai_definitions_are_fine(client, db_session):
    seed_words(db_session, is_ai_generated=True, review_status="approved")
    body = client.get("/learn/round", params={"kind": "definition", "count": 3}).json()
    assert len(body["questions"]) == 3


def test_unpublished_methali_are_never_quizzed(client, db_session):
    seed_methali(db_session, workflow="draft")
    assert client.get("/learn/round", params={"kind": "methali"}).json()["questions"] == []


# --- degrading gracefully -------------------------------------------------


def test_too_little_content_yields_an_empty_round_not_an_error(client, db_session):
    # Three words cannot make a four-option question.
    seed_words(db_session, words=WORDS[:3])
    response = client.get("/learn/round", params={"kind": "definition"})
    assert response.status_code == 200
    assert response.json()["questions"] == []


def test_a_short_corpus_yields_a_short_round(client, db_session):
    seed_words(db_session, words=WORDS[:4])
    body = client.get("/learn/round", params={"kind": "definition", "count": 10}).json()
    # Four words, one question each, rather than repeats or an error.
    assert 0 < len(body["questions"]) <= 4


def test_stub_definitions_are_excluded(client, db_session):
    seed_words(
        db_session,
        words=[(lemma, pos, "see X") for lemma, pos, _ in WORDS],
    )
    assert client.get("/learn/round", params={"kind": "definition"}).json()["questions"] == []


def test_empty_corpus_yields_an_empty_round(client, db_session):
    db_session.add(Language(code="sw", name="Swahili"))
    db_session.commit()
    assert client.get("/learn/round").json()["questions"] == []


def test_invalid_kind_is_rejected(client, db_session):
    assert client.get("/learn/round", params={"kind": "wordle"}).status_code == 400


# --- mixed and daily ------------------------------------------------------


def test_mixed_round_draws_on_both_kinds(client, db_session):
    seed_words(db_session)
    seed_methali(db_session)

    body = client.get("/learn/round", params={"kind": "mixed", "count": 6}).json()
    kinds = {question["kind"] for question in body["questions"]}
    assert len(kinds) > 1, f"expected a mix, got {kinds}"
    for question in body["questions"]:
        assert_well_formed(question)


def test_daily_round_is_the_same_all_day(client, db_session):
    """A streak means nothing if the day's challenge reshuffles on each open."""
    seed_words(db_session)
    seed_methali(db_session)

    first = client.get("/learn/daily").json()
    second = client.get("/learn/daily").json()

    assert first == second
    assert first["date"] is not None
    assert first["kind"] == "daily"
    assert len(first["questions"]) == 5


def test_practice_rounds_do_vary(client, db_session):
    seed_words(db_session)
    seed_methali(db_session)

    rounds = [
        client.get("/learn/round", params={"kind": "mixed", "count": 5}).json()["questions"]
        for _ in range(6)
    ]
    assert any(a != b for a, b in zip(rounds, rounds[1:])), "practice should not be fixed"
