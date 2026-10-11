"""Question rounds for the Jifunze (learn) surface.

Reader-facing and unauthenticated, like `/search`. Questions are built from
published content only, and a Swahili definition still has to have cleared
review before it can appear — a game is a worse place than most to teach
somebody an unreviewed machine translation.

Rounds are assembled in Python from a pool fetched in one query rather than
with `ORDER BY random()` per question. That keeps it to a single round trip,
behaves identically on SQLite and Postgres, and lets the daily round be
reproducible from a seed.
"""
from __future__ import annotations

import random
import re
from datetime import date, datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import func, or_, select
from sqlalchemy.orm import Session

from app.db import get_db
from app.models import (
    Expression,
    ExpressionMeaning,
    Lexeme,
    PartOfSpeech,
    Sense,
    SenseDefinition,
)
from app.schemas import LearnQuestion, LearnRound, WordFindPuzzle, WordFindWord

router = APIRouter(prefix="/learn", tags=["learn"])

QUESTION_KINDS = ("definition", "meaning", "methali")
OPTION_COUNT = 4
POOL_LIMIT = 300

# Below this a "definition" is usually a stub or a cross-reference, which
# makes for a question with no answer worth learning.
MIN_DEFINITION_LENGTH = 12
# A proverb needs enough words to be worth splitting in half.
MIN_METHALI_WORDS = 4


class _Word:
    __slots__ = ("lexeme_id", "lemma", "pos_code", "definition")

    def __init__(self, lexeme_id, lemma: str, pos_code: str | None, definition: str):
        self.lexeme_id = lexeme_id
        self.lemma = lemma
        self.pos_code = pos_code
        self.definition = definition


class _Methali:
    __slots__ = ("expression_id", "opening", "ending", "meaning")

    def __init__(self, expression_id, opening: str, ending: str, meaning: str | None):
        self.expression_id = expression_id
        self.opening = opening
        self.ending = ending
        self.meaning = meaning


def word_pool(db: Session, lang: str) -> list[_Word]:
    """Published words whose definition in `lang` is fit to be quizzed."""
    stmt = (
        select(
            Lexeme.id,
            Lexeme.lemma,
            PartOfSpeech.code,
            SenseDefinition.definition,
        )
        .join(Sense, Sense.lexeme_id == Lexeme.id)
        .join(SenseDefinition, SenseDefinition.sense_id == Sense.id)
        .outerjoin(PartOfSpeech, PartOfSpeech.id == Lexeme.pos_id)
        .where(
            Lexeme.workflow == "published",
            Sense.workflow == "published",
            SenseDefinition.lang_code == lang,
            func.length(SenseDefinition.definition) >= MIN_DEFINITION_LENGTH,
        )
        # Same guard as the read path: an unreviewed machine definition is not
        # something to teach.
        .where(
            or_(
                SenseDefinition.lang_code != "sw",
                SenseDefinition.is_ai_generated.is_(False),
                SenseDefinition.review_status.in_(["approved", "edited"]),
            )
        )
        .order_by(Lexeme.normalized_lemma.asc(), Lexeme.id.asc())
        .limit(POOL_LIMIT)
    )

    # One question per headword, so the same word cannot be both the prompt
    # and a distractor.
    seen: set = set()
    pool: list[_Word] = []
    for lexeme_id, lemma, pos_code, definition in db.execute(stmt).all():
        if lexeme_id in seen:
            continue
        seen.add(lexeme_id)
        pool.append(_Word(lexeme_id, lemma, pos_code, definition.strip()))
    return pool


def methali_pool(db: Session, lang: str) -> list[_Methali]:
    """Published expressions long enough to split, with their meaning."""
    meaning = (
        select(ExpressionMeaning.meaning)
        .where(
            ExpressionMeaning.expression_id == Expression.id,
            ExpressionMeaning.lang_code == lang,
        )
        .order_by(ExpressionMeaning.is_primary.desc())
        .limit(1)
        .correlate(Expression)
        .scalar_subquery()
    )
    stmt = (
        select(Expression.id, Expression.text, meaning.label("meaning"))
        .where(Expression.workflow == "published")
        .order_by(Expression.normalized_text.asc(), Expression.id.asc())
        .limit(POOL_LIMIT)
    )

    pool: list[_Methali] = []
    for expression_id, text, meaning_text in db.execute(stmt).all():
        words = (text or "").split()
        if len(words) < MIN_METHALI_WORDS:
            continue
        # Split on a word boundary near the middle, so the opening is a
        # recognisable fragment rather than one word.
        pivot = len(words) // 2
        pool.append(
            _Methali(
                expression_id=expression_id,
                opening=" ".join(words[:pivot]),
                ending=" ".join(words[pivot:]),
                meaning=meaning_text,
            )
        )
    return pool


def _distractors(
    rng: random.Random,
    pool: list,
    answer,
    value,
    *,
    prefer=None,
) -> list[str] | None:
    """Pick OPTION_COUNT - 1 wrong answers, or None if there are too few.

    `prefer` narrows the candidates first — same part of speech makes a
    question that tests meaning rather than letting grammar give it away.
    """
    candidates = [item for item in pool if item is not answer]
    if prefer is not None:
        close = [item for item in candidates if prefer(item)]
        if len(close) >= OPTION_COUNT - 1:
            candidates = close

    texts: list[str] = []
    seen = {value(answer)}
    rng.shuffle(candidates)
    for item in candidates:
        text = value(item)
        if text in seen:
            continue
        seen.add(text)
        texts.append(text)
        if len(texts) == OPTION_COUNT - 1:
            return texts
    return None


def _as_question(rng: random.Random, kind: str, answer: str, wrong: list[str], **fields):
    options = [answer, *wrong]
    rng.shuffle(options)
    return LearnQuestion(
        kind=kind,
        options=options,
        answer_index=options.index(answer),
        **fields,
    )


def build_questions(
    rng: random.Random,
    kinds: list[str],
    count: int,
    words: list[_Word],
    methali: list[_Methali],
) -> list[LearnQuestion]:
    """Assemble up to `count` questions, cycling through `kinds`.

    Returns fewer than asked for — possibly none — when the corpus cannot
    support them. The client shows what it gets; a half-length round beats an
    error page.
    """
    usable = [
        kind
        for kind in kinds
        if (kind == "methali" and len(methali) >= OPTION_COUNT)
        or (kind in ("definition", "meaning") and len(words) >= OPTION_COUNT)
    ]
    if not usable:
        return []

    word_order = list(words)
    methali_order = list(methali)
    rng.shuffle(word_order)
    rng.shuffle(methali_order)

    questions: list[LearnQuestion] = []
    word_at = 0
    methali_at = 0

    while len(questions) < count:
        kind = usable[len(questions) % len(usable)]
        made = None

        if kind == "methali" and methali_at < len(methali_order):
            item = methali_order[methali_at]
            methali_at += 1
            wrong = _distractors(rng, methali_order, item, lambda m: m.ending)
            if wrong:
                made = _as_question(
                    rng,
                    "methali",
                    item.ending,
                    wrong,
                    prompt=item.opening,
                    prompt_detail=item.meaning,
                    expression_id=item.expression_id,
                )

        elif kind in ("definition", "meaning") and word_at < len(word_order):
            item = word_order[word_at]
            word_at += 1
            if kind == "definition":
                wrong = _distractors(
                    rng,
                    word_order,
                    item,
                    lambda w: w.definition,
                    prefer=lambda w: w.pos_code == item.pos_code,
                )
                if wrong:
                    made = _as_question(
                        rng,
                        "definition",
                        item.definition,
                        wrong,
                        prompt=item.lemma,
                        prompt_detail=item.pos_code,
                        lexeme_id=item.lexeme_id,
                    )
            else:
                wrong = _distractors(
                    rng,
                    word_order,
                    item,
                    lambda w: w.lemma,
                    prefer=lambda w: w.pos_code == item.pos_code,
                )
                if wrong:
                    made = _as_question(
                        rng,
                        "meaning",
                        item.lemma,
                        wrong,
                        prompt=item.definition,
                        prompt_detail=item.pos_code,
                        lexeme_id=item.lexeme_id,
                    )

        if made is not None:
            questions.append(made)
            continue

        # Nothing left of this kind; drop it and stop if none remain.
        usable = [other for other in usable if other != kind]
        if not usable:
            break

    return questions


@router.get("/daily", response_model=LearnRound)
def daily_round(
    lang: str = "sw",
    count: int = Query(5, ge=1, le=20),
    db: Session = Depends(get_db),
) -> LearnRound:
    """Today's round — the same questions for everyone, all day.

    A streak only means something if the day's challenge is fixed: reshuffling
    on every open would turn it into endless practice, which is a different
    thing. Seeded by the UTC date, so it is reproducible and cacheable.
    """
    today = datetime.now(timezone.utc).date()
    seed = (today - date(1970, 1, 1)).days
    rng = random.Random(seed)

    questions = build_questions(
        rng,
        ["definition", "methali", "meaning"],
        count,
        word_pool(db, lang),
        methali_pool(db, lang),
    )
    return LearnRound(kind="daily", lang_code=lang, questions=questions, date=today)


@router.get("/round", response_model=LearnRound)
def practice_round(
    kind: str = Query("mixed"),
    lang: str = "sw",
    count: int = Query(5, ge=1, le=20),
    db: Session = Depends(get_db),
) -> LearnRound:
    """A fresh practice round. Unlike /daily, different every time."""
    if kind == "mixed":
        kinds = list(QUESTION_KINDS)
    elif kind in QUESTION_KINDS:
        kinds = [kind]
    else:
        raise HTTPException(
            status_code=400,
            detail=f"kind must be 'mixed' or one of {', '.join(QUESTION_KINDS)}",
        )

    rng = random.Random()
    needs_words = any(k in ("definition", "meaning") for k in kinds)
    questions = build_questions(
        rng,
        kinds,
        count,
        word_pool(db, lang) if needs_words else [],
        methali_pool(db, lang) if "methali" in kinds else [],
    )
    return LearnRound(kind=kind, lang_code=lang, questions=questions)

# --- word find -------------------------------------------------------------
#
# A grid of letters with vocabulary hidden in it. Finding a word reveals its
# meaning, which is the point: the puzzle is the way in, the definition is
# what you leave with.

# Only these four directions, all of which read left-to-right or top-to-bottom.
# A classic word search also hides words backwards, but reversed Swahili is a
# puzzle about letters rather than about the language, and a learner gets
# nothing from it.
WORDFIND_DIRECTIONS = (
    (0, 1),    # east
    (1, 0),    # south
    (1, 1),    # south-east
    (-1, 1),   # north-east
)

WORDFIND_MIN_WORD = 4
WORDFIND_MAX_WORD = 9
WORDFIND_DEFAULT_SIZE = 11
WORDFIND_DEFAULT_COUNT = 7
# Attempts to seat one word before giving up on it and trying the next.
WORDFIND_PLACEMENT_TRIES = 120

# Filler letters, weighted roughly to written Swahili so the grid does not
# read as obvious noise around the answers. No q or x: they do not occur in
# Swahili, and a learner scanning for real letters should not have to skip
# over them.
WORDFIND_FILLER = "aaaaaiiiiuuuunnnmmmkkkwwtttieeeoosslyybhrdgjpfvzc"

# Letters a word must consist of to be placeable. Apostrophes ("ng'ombe"),
# spaces and hyphens cannot go in a grid cell.
WORDFIND_ALPHABET = re.compile(r"^[a-z]+$")


def wordfind_pool(db: Session, lang: str) -> list[_Word]:
    """Published words shaped like something that fits in a grid.

    Deliberately not `word_pool`: that one takes the first POOL_LIMIT rows by
    lemma, which is fine for distractors but would mean every puzzle was built
    from words starting with "a". This filters on shape in SQL and returns the
    lot, so the caller can sample across the whole published vocabulary.
    """
    stmt = (
        select(
            Lexeme.id,
            Lexeme.lemma,
            PartOfSpeech.code,
            SenseDefinition.definition,
        )
        .join(Sense, Sense.lexeme_id == Lexeme.id)
        .join(SenseDefinition, SenseDefinition.sense_id == Sense.id)
        .outerjoin(PartOfSpeech, PartOfSpeech.id == Lexeme.pos_id)
        .where(
            Lexeme.workflow == "published",
            Sense.workflow == "published",
            SenseDefinition.lang_code == lang,
            func.length(SenseDefinition.definition) >= MIN_DEFINITION_LENGTH,
            func.length(Lexeme.lemma) >= WORDFIND_MIN_WORD,
            func.length(Lexeme.lemma) <= WORDFIND_MAX_WORD,
        )
        # The same review guard as every other read path. A game is a worse
        # place than most to teach an unreviewed machine translation.
        .where(
            or_(
                SenseDefinition.lang_code != "sw",
                SenseDefinition.is_ai_generated.is_(False),
                SenseDefinition.review_status.in_(["approved", "edited"]),
            )
        )
        .order_by(Lexeme.normalized_lemma.asc(), Lexeme.id.asc())
    )

    seen: set = set()
    pool: list[_Word] = []
    for lexeme_id, lemma, pos_code, definition in db.execute(stmt).all():
        if lexeme_id in seen:
            continue
        letters = lemma.strip().lower()
        if not WORDFIND_ALPHABET.match(letters):
            continue
        seen.add(lexeme_id)
        pool.append(_Word(lexeme_id, lemma.strip(), pos_code, definition.strip()))
    return pool


def _fits(rows: list[list[str]], letters: str, row: int, col: int, dr: int, dc: int) -> bool:
    size = len(rows)
    for index, letter in enumerate(letters):
        r, c = row + dr * index, col + dc * index
        if not (0 <= r < size and 0 <= c < size):
            return False
        occupant = rows[r][c]
        # An empty cell, or one that already holds this very letter — words
        # crossing on a shared letter is what makes a grid feel designed.
        if occupant and occupant != letter:
            return False
    return True


def _seat(rows: list[list[str]], letters: str, row: int, col: int, dr: int, dc: int):
    cells = []
    for index, letter in enumerate(letters):
        r, c = row + dr * index, col + dc * index
        rows[r][c] = letter
        cells.append([r, c])
    return cells


def build_wordfind(
    pool: list[_Word], *, size: int, count: int, rng: random.Random
) -> tuple[list[str], list[WordFindWord]]:
    """Seat as many words as will fit, then fill the gaps.

    Returns however many it managed rather than failing: a grid with five of
    the seven words asked for is still a puzzle, where an error is not.
    """
    rows: list[list[str]] = [["" for _ in range(size)] for _ in range(size)]
    placed: list[WordFindWord] = []

    eligible = [word for word in pool if len(word.lemma) <= size]
    rng.shuffle(eligible)

    # Choose a spread of lengths before choosing an order. Seating longest
    # first is the right placement strategy, but selecting that way too gave
    # a grid of seven nine-letter nouns — correct, and a dull puzzle. So:
    # round-robin over the available lengths to pick the set, then sort that
    # set longest-first to seat it.
    by_length: dict[int, list[_Word]] = {}
    for word in eligible:
        by_length.setdefault(len(word.lemma), []).append(word)

    chosen: list[_Word] = []
    lengths = sorted(by_length)
    # Twice what we need, so there are spares when one will not fit anywhere.
    while lengths and len(chosen) < count * 2:
        for length in list(lengths):
            bucket = by_length[length]
            if not bucket:
                lengths.remove(length)
                continue
            chosen.append(bucket.pop())
            if len(chosen) >= count * 2:
                break

    candidates = sorted(chosen, key=lambda word: len(word.lemma), reverse=True)

    used_letters: set[str] = set()
    for word in candidates:
        if len(placed) >= count:
            break
        letters = word.lemma.lower()
        # Two entries spelled the same would be indistinguishable in the grid.
        if letters in used_letters:
            continue
        for _ in range(WORDFIND_PLACEMENT_TRIES):
            dr, dc = rng.choice(WORDFIND_DIRECTIONS)
            row = rng.randrange(size)
            col = rng.randrange(size)
            if not _fits(rows, letters, row, col, dr, dc):
                continue
            cells = _seat(rows, letters, row, col, dr, dc)
            placed.append(
                WordFindWord(
                    lexeme_id=word.lexeme_id,
                    word=word.lemma,
                    letters=letters,
                    definition=word.definition,
                    pos_code=word.pos_code,
                    cells=cells,
                )
            )
            used_letters.add(letters)
            break

    for r in range(size):
        for c in range(size):
            if not rows[r][c]:
                rows[r][c] = rng.choice(WORDFIND_FILLER)

    return ["".join(row) for row in rows], placed


@router.get("/wordfind", response_model=WordFindPuzzle)
def word_find(
    size: int = Query(WORDFIND_DEFAULT_SIZE, ge=8, le=14),
    count: int = Query(WORDFIND_DEFAULT_COUNT, ge=3, le=10),
    lang: str = Query("sw", pattern="^(sw|en)$"),
    db: Session = Depends(get_db),
) -> WordFindPuzzle:
    pool = wordfind_pool(db, lang)
    if not pool:
        raise HTTPException(
            status_code=404,
            detail=(
                "No published words are shaped for a grid yet. A word needs a "
                "reviewed definition and a headword of "
                f"{WORDFIND_MIN_WORD}-{WORDFIND_MAX_WORD} letters, no spaces."
            ),
        )

    rows, words = build_wordfind(pool, size=size, count=count, rng=random.Random())
    if not words:
        raise HTTPException(
            status_code=404, detail="Could not fit any word into a grid that size."
        )
    return WordFindPuzzle(lang_code=lang, size=size, rows=rows, words=words)
