from sqlalchemy import func, select
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.orm import Session

from app.models import Expression, ExpressionMeaning, Lexeme, SearchEntry, SenseDefinition
from app.normalize import normalize_sw


def upsert_search_entry(db: Session, *, target_type: str, target_id, lang_code: str, text: str) -> None:
    normalized = normalize_sw(text)
    stmt = insert(SearchEntry).values(
        target_type=target_type,
        target_id=target_id,
        lang_code=lang_code,
        text=text,
        normalized=normalized,
    )
    stmt = stmt.on_conflict_do_update(
        index_elements=[SearchEntry.target_type, SearchEntry.target_id, SearchEntry.lang_code],
        set_={
            "text": text,
            "normalized": normalized,
            "updated_at": func.now(),
        },
    )
    db.execute(stmt)


def is_publicly_visible(definition: SenseDefinition) -> bool:
    """Mirror the public read filter in routers/public.py.

    An AI-generated Swahili definition stays out of the search index until a
    reviewer approves or edits it, otherwise its text would leak through
    /search even though /lexemes/{id} hides it.
    """
    if definition.lang_code != "sw":
        return True
    if not definition.is_ai_generated:
        return True
    return definition.review_status in {"approved", "edited"}


class NotReady(Exception):
    """A lexeme was asked to publish while it still has problems."""

    def __init__(self, problems: list[str]) -> None:
        self.problems = problems
        super().__init__(", ".join(problems))


# Minimum lemma length. One character is a typo or a stray letter, not a
# headword.
MIN_LEMMA_LENGTH = 2


def readiness_problems(lexeme: Lexeme) -> list[str]:
    """Everything stopping this lexeme from being published, worst first.

    An empty list means it is ready. These rules lived only in the admin
    console, which meant the server would publish anything asked of it and a
    bulk job had nothing to screen against. The backend owns data rules, so
    they live here now and the console can ask rather than decide.

    The Swahili rule is the one that matters and the one a client cannot get
    right alone: a sense whose only Swahili definition is unreviewed AI has
    no *visible* Swahili definition, because `is_publicly_visible` will keep
    it out of the index and the public reader hides it. Publishing such an
    entry produces a word that looks complete in the database and empty to a
    reader.
    """
    problems: list[str] = []

    lemma = (lexeme.lemma or "").strip()
    if len(lemma) < MIN_LEMMA_LENGTH:
        problems.append("lemma_too_short")
    elif not normalize_sw(lemma):
        # Nothing survives normalisation, so the entry could never be found.
        problems.append("lemma_not_searchable")

    if lexeme.pos_id is None:
        problems.append("no_part_of_speech")

    senses = list(lexeme.senses)
    if not senses:
        problems.append("no_senses")
        return problems

    if any(not (d.definition or "").strip() for s in senses for d in s.definitions):
        problems.append("empty_definition")

    if not any(
        is_publicly_visible(d) and d.lang_code == "sw"
        for s in senses
        for d in s.definitions
    ):
        problems.append("no_visible_swahili_definition")
    elif not all(
        any(is_publicly_visible(d) and d.lang_code == "sw" for d in s.definitions)
        for s in senses
    ):
        # Some senses are covered and some are not. Worth distinguishing: the
        # entry is usable, just incomplete.
        problems.append("sense_without_visible_swahili")

    return problems


def publish_lexeme(db: Session, lexeme_id, *, require_ready: bool = False) -> Lexeme:
    lexeme = db.scalar(select(Lexeme).where(Lexeme.id == lexeme_id))
    if not lexeme:
        raise ValueError("Lexeme not found")

    # Off by default so the admin console's publish button keeps behaving as
    # it does today; the bulk tool opts in, because nobody is watching it.
    if require_ready:
        problems = readiness_problems(lexeme)
        if problems:
            raise NotReady(problems)

    lexeme.workflow = "published"
    for sense in lexeme.senses:
        sense.workflow = "published"

    upsert_search_entry(
        db,
        target_type="lexeme",
        target_id=lexeme.id,
        lang_code=lexeme.default_language_code,
        text=lexeme.lemma,
    )

    for sense in lexeme.senses:
        for definition in sense.definitions:
            if not is_publicly_visible(definition):
                continue
            # /search resolves a definition hit back to its lexeme via
            # sense_definition.id, so the entry must be keyed on the
            # definition, not the sense.
            upsert_search_entry(
                db,
                target_type="definition",
                target_id=definition.id,
                lang_code=definition.lang_code,
                text=definition.definition,
            )

        # /search resolves an example hit through example_text.id, and the
        # mobile app offers an "example" filter, so usage examples belong in
        # the index too.
        for example in sense.examples:
            for text in example.texts:
                upsert_search_entry(
                    db,
                    target_type="example",
                    target_id=text.id,
                    lang_code=text.lang_code,
                    text=text.text,
                )

    db.commit()
    db.refresh(lexeme)
    return lexeme


def review_lexeme(db: Session, lexeme_id) -> Lexeme:
    lexeme = db.scalar(select(Lexeme).where(Lexeme.id == lexeme_id))
    if not lexeme:
        raise ValueError("Lexeme not found")
    lexeme.workflow = "reviewed"
    for sense in lexeme.senses:
        sense.workflow = "reviewed"
    db.commit()
    db.refresh(lexeme)
    return lexeme


def publish_expression(db: Session, expression_id) -> Expression:
    expression = db.scalar(select(Expression).where(Expression.id == expression_id))
    if not expression:
        raise ValueError("Expression not found")

    expression.workflow = "published"
    upsert_search_entry(
        db,
        target_type="expression",
        target_id=expression.id,
        lang_code="sw",
        text=expression.text,
    )
    meanings = db.scalars(
        select(ExpressionMeaning).where(ExpressionMeaning.expression_id == expression.id)
    ).all()
    for meaning in meanings:
        # Keyed on the meaning, under its own target_type. Writing these as
        # ("expression", expression.id) would collide with the entry above on
        # (target_type, target_id, lang_code) and overwrite the expression's
        # own text, making the proverb unsearchable in that language.
        upsert_search_entry(
            db,
            target_type="expression_meaning",
            target_id=meaning.id,
            lang_code=meaning.lang_code,
            text=meaning.meaning,
        )

    db.commit()
    db.refresh(expression)
    return expression


def review_expression(db: Session, expression_id) -> Expression:
    expression = db.scalar(select(Expression).where(Expression.id == expression_id))
    if not expression:
        raise ValueError("Expression not found")
    expression.workflow = "reviewed"
    db.commit()
    db.refresh(expression)
    return expression
