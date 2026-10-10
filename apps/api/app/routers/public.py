from datetime import date, datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import and_, case, func, or_, select, literal, text
from sqlalchemy.orm import Session

from app.core.config import settings
from app.db import get_db
from app.models import (
    Example,
    ExampleText,
    Expression,
    ExpressionMeaning,
    Lexeme,
    PartOfSpeech,
    SearchEntry,
    Sense,
    SenseDefinition,
)
from app.normalize import normalize_sw
from app.schemas import ExpressionPublic, LexemePublic, SearchResult, WordOfDayPublic

router = APIRouter()

# Rank floor for trigram matches. Strict ranks are 0-3, and a fuzzy hit scores
# FUZZY_RANK + (1 - similarity), so it lands in [10, 11] — always after every
# strict hit, and a closer spelling ahead of a looser one within the tier.
# `is_fuzzy` is then just `rank >= FUZZY_RANK`.
FUZZY_RANK = 10


@router.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}

def _resolved_entries(normalized: str, lang: str, match_clause, rank_expr):
    """Subquery resolving each matching index row to the record that owns it.

    `search_entry` stores one row per searchable string; the reader needs the
    lexeme or expression behind it. No limit is applied here — filtering has to
    happen before the window, or a request for N results silently returns
    fewer.
    """
    sense_id_for_definition = (
        select(SenseDefinition.sense_id)
        .where(SenseDefinition.id == SearchEntry.target_id)
        .scalar_subquery()
    )
    lexeme_id_for_definition = (
        select(Sense.lexeme_id)
        .join(SenseDefinition, SenseDefinition.sense_id == Sense.id)
        .where(SenseDefinition.id == SearchEntry.target_id)
        .scalar_subquery()
    )

    sense_id_for_example = (
        select(Example.sense_id)
        .join(ExampleText, ExampleText.example_id == Example.id)
        .where(ExampleText.id == SearchEntry.target_id)
        .scalar_subquery()
    )
    lexeme_id_for_example = (
        select(Sense.lexeme_id)
        .join(Example, Example.sense_id == Sense.id)
        .join(ExampleText, ExampleText.example_id == Example.id)
        .where(ExampleText.id == SearchEntry.target_id)
        .scalar_subquery()
    )

    expression_id_for_meaning = (
        select(ExpressionMeaning.expression_id)
        .where(ExpressionMeaning.id == SearchEntry.target_id)
        .scalar_subquery()
    )

    resolved_lexeme_id = case(
        (SearchEntry.target_type == "lexeme", SearchEntry.target_id),
        (SearchEntry.target_type == "definition", lexeme_id_for_definition),
        (SearchEntry.target_type == "example", lexeme_id_for_example),
        else_=None,
    ).label("lexeme_id")

    resolved_expression_id = case(
        (SearchEntry.target_type == "expression", SearchEntry.target_id),
        (SearchEntry.target_type == "expression_meaning", expression_id_for_meaning),
        else_=None,
    ).label("expression_id")

    # Only definition and example hits hang off a sense, whose own workflow
    # has to be checked independently of the lexeme's.
    resolved_sense_id = case(
        (SearchEntry.target_type == "definition", sense_id_for_definition),
        (SearchEntry.target_type == "example", sense_id_for_example),
        else_=None,
    ).label("sense_id")

    # Preference between hits on the *same* record: the headword itself, then
    # its meaning, then a usage example.
    kind_rank = case(
        (SearchEntry.target_type == "lexeme", 0),
        (SearchEntry.target_type == "expression", 0),
        (SearchEntry.target_type == "definition", 1),
        (SearchEntry.target_type == "expression_meaning", 1),
        (SearchEntry.target_type == "example", 2),
        else_=3,
    ).label("kind_rank")

    match_kind = case(
        (SearchEntry.target_type == "lexeme", literal("lemma")),
        (SearchEntry.target_type == "definition", literal("definition")),
        (SearchEntry.target_type == "example", literal("example")),
        (SearchEntry.target_type == "expression", literal("expression")),
        (SearchEntry.target_type == "expression_meaning", literal("meaning")),
        else_=literal("unknown"),
    ).label("match_kind")

    return (
        select(
            SearchEntry.id.label("search_id"),
            SearchEntry.target_type,
            SearchEntry.target_id,
            SearchEntry.lang_code,
            SearchEntry.text,
            SearchEntry.normalized,
            SearchEntry.popularity,
            resolved_lexeme_id,
            resolved_expression_id,
            resolved_sense_id,
            match_kind,
            kind_rank,
            rank_expr.label("rank"),
        )
        .select_from(SearchEntry)
        .where(SearchEntry.lang_code == lang)
        .where(match_clause)
        .subquery()
    )


def _visible_hits(base, include_drafts: bool):
    """Join each resolved hit to its owner and drop what must not be shown."""
    stmt = (
        select(
            base.c.search_id,
            base.c.target_type,
            base.c.target_id,
            base.c.lang_code,
            base.c.text,
            base.c.normalized,
            base.c.popularity,
            base.c.lexeme_id,
            base.c.expression_id,
            base.c.match_kind,
            base.c.kind_rank,
            base.c.rank,
            Lexeme.lemma,
            PartOfSpeech.code.label("pos_code"),
            Expression.text.label("expression_text"),
        )
        .select_from(base)
        .outerjoin(Lexeme, Lexeme.id == base.c.lexeme_id)
        .outerjoin(PartOfSpeech, PartOfSpeech.id == Lexeme.pos_id)
        .outerjoin(Expression, Expression.id == base.c.expression_id)
        .outerjoin(Sense, Sense.id == base.c.sense_id)
        .outerjoin(
            SenseDefinition,
            and_(
                SenseDefinition.id == base.c.target_id,
                base.c.target_type == "definition",
            ),
        )
    )

    # An entry whose owning row has been deleted resolves to nothing; drop it
    # rather than returning a hit the reader cannot open.
    stmt = stmt.where(
        or_(
            and_(base.c.lexeme_id.isnot(None), Lexeme.id.isnot(None)),
            and_(base.c.expression_id.isnot(None), Expression.id.isnot(None)),
        )
    )

    # search_entry rows are written on publish but are not removed when an
    # entry is later archived or returned to draft, so visibility is enforced
    # here too rather than trusted to the index.
    if not include_drafts:
        stmt = stmt.where(
            or_(
                and_(base.c.lexeme_id.isnot(None), Lexeme.workflow == "published"),
                and_(base.c.expression_id.isnot(None), Expression.workflow == "published"),
            )
        )
        stmt = stmt.where(or_(base.c.sense_id.is_(None), Sense.workflow == "published"))

    # Mirrors the AI guard in the read path. Written as a positive allow-list
    # so that NULL columns on non-definition hits cannot make it NULL.
    return stmt.where(
        or_(
            base.c.target_type != "definition",
            SenseDefinition.lang_code != "sw",
            SenseDefinition.is_ai_generated.is_(False),
            SenseDefinition.review_status.in_(["approved", "edited"]),
        )
    )


def _best_per_record(stmt):
    """Collapse to one hit per lexeme or expression.

    A query can match a headword, one of its definitions and one of its
    examples, which are three index rows for a single dictionary entry. A
    reader wants the entry listed once, represented by its strongest match.
    """
    hits = stmt.subquery()
    owner = func.coalesce(hits.c.lexeme_id, hits.c.expression_id)
    best = (
        func.row_number()
        .over(partition_by=owner, order_by=_ordering(hits))
        .label("row_number")
    )
    ranked = select(hits, best).subquery()
    return select(ranked).where(ranked.c.row_number == 1)


def _ordering(columns):
    """Result order: match strength, then which part matched, then popularity."""
    return (
        columns.c.rank.asc(),
        columns.c.kind_rank.asc(),
        columns.c.popularity.desc(),
        columns.c.normalized.asc(),
        columns.c.search_id.asc(),
    )


def _to_result(row) -> SearchResult:
    return SearchResult(
        id=row.search_id,
        target_type=row.target_type,
        target_id=row.target_id,
        lang_code=row.lang_code,
        text=row.text,
        normalized=row.normalized,
        popularity=row.popularity or 0,
        lexeme_id=row.lexeme_id,
        lemma=row.lemma,
        pos_code=row.pos_code,
        expression_id=row.expression_id,
        expression_text=row.expression_text,
        match_kind=row.match_kind,
        is_fuzzy=row.rank >= FUZZY_RANK,
    )


@router.get("/search", response_model=list[SearchResult])
def search(
    q: str = Query(..., min_length=1),
    lang: str = "sw",
    limit: int = Query(20, ge=1, le=100),
    include_drafts: bool = Query(False),
    fuzzy: bool = Query(True, description="top up thin results with near spellings"),
    db: Session = Depends(get_db),
) -> list[SearchResult]:
    """Lookup over the search_entry index.

    Runs a strict pass first (exact, then prefix, then substring). If that
    leaves room under `limit` and the backend is Postgres, a second pass tops
    the list up with trigram-similar spellings, flagged `is_fuzzy` so a client
    can present them as "did you mean". Fuzzy hits always sort after strict
    ones, so adding them never reorders a good match.
    """
    normalized = normalize_sw(q)
    if not normalized:
        return []

    strict_rank = case(
        (SearchEntry.normalized == normalized, 0),
        (SearchEntry.normalized.like(f"{normalized}%"), 1),
        (SearchEntry.normalized.like(f"%{normalized}%"), 2),
        else_=3,
    )
    base = _resolved_entries(
        normalized, lang, SearchEntry.normalized.like(f"%{normalized}%"), strict_rank
    )
    strict = _best_per_record(_visible_hits(base, include_drafts)).subquery()
    rows = db.execute(
        select(strict).order_by(*_ordering(strict)).limit(limit)
    ).all()

    results = [_to_result(row) for row in rows]
    remaining = limit - len(results)
    if not fuzzy or remaining <= 0 or db.bind.dialect.name != "postgresql":
        return results

    # pg_trgm's `%` operator is index-backed; `similarity() >= x` is not, so
    # the threshold is set on the transaction rather than written into the
    # predicate.
    # set_config(..., is_local => true) is the parameterizable form of
    # SET LOCAL, which is a utility statement and takes no bind parameters.
    db.execute(
        text("SELECT set_config('pg_trgm.similarity_threshold', :threshold, true)"),
        {"threshold": str(settings.search_fuzzy_threshold)},
    )
    similarity = func.similarity(SearchEntry.normalized, normalized)
    fuzzy_base = _resolved_entries(
        normalized,
        lang,
        and_(
            SearchEntry.normalized.op("%")(normalized),
            SearchEntry.normalized.notlike(f"%{normalized}%"),
        ),
        literal(float(FUZZY_RANK)) + (literal(1.0) - similarity),
    )
    # Exclude records already listed, so the fuzzy pass tops the list up with
    # new entries rather than repeating one under a looser spelling.
    seen = {result.lexeme_id for result in results if result.lexeme_id}
    seen |= {result.expression_id for result in results if result.expression_id}
    fuzzy_stmt = _visible_hits(fuzzy_base, include_drafts)
    if seen:
        fuzzy_stmt = fuzzy_stmt.where(
            func.coalesce(fuzzy_base.c.lexeme_id, fuzzy_base.c.expression_id).notin_(seen)
        )
    fuzzy = _best_per_record(fuzzy_stmt).subquery()
    fuzzy_rows = db.execute(
        select(fuzzy).order_by(*_ordering(fuzzy)).limit(remaining)
    ).all()

    return results + [_to_result(row) for row in fuzzy_rows]


def _pick_definition(lexeme: Lexeme, lang: str) -> str | None:
    for sense in sorted(lexeme.senses, key=lambda s: s.sense_number):
        if sense.workflow != "published":
            continue
        definitions = [
            definition
            for definition in sense.definitions
            if definition.lang_code == lang
            and not (
                lang == "sw"
                and definition.is_ai_generated
                and definition.review_status not in {"approved", "edited"}
            )
        ]
        if not definitions:
            continue
        primary = next((definition for definition in definitions if definition.is_primary), definitions[0])
        return primary.definition
    return None


@router.get("/word-of-the-day", response_model=WordOfDayPublic)
def word_of_day(
    lang: str = "sw",
    db: Session = Depends(get_db),
) -> WordOfDayPublic:
    today = datetime.now(timezone.utc).date()
    day_index = (today - date(1970, 1, 1)).days

    filters = [
        Lexeme.workflow == "published",
        Sense.workflow == "published",
        SenseDefinition.lang_code == lang,
    ]
    if lang == "sw":
        filters.append(
            or_(
                SenseDefinition.is_ai_generated.is_(False),
                SenseDefinition.review_status.in_(["approved", "edited"]),
            )
        )

    eligible_stmt = (
        select(Lexeme.id, Lexeme.normalized_lemma)
        .join(Sense, Sense.lexeme_id == Lexeme.id)
        .join(SenseDefinition, SenseDefinition.sense_id == Sense.id)
        .where(*filters)
        .distinct()
    )
    total = db.execute(select(func.count()).select_from(eligible_stmt.subquery())).scalar_one()
    if total == 0:
        raise HTTPException(status_code=404, detail="No word of the day available")

    offset = day_index % total
    row = db.execute(
        eligible_stmt.order_by(Lexeme.normalized_lemma.asc(), Lexeme.id.asc())
        .offset(offset)
        .limit(1)
    ).first()
    if not row:
        raise HTTPException(status_code=404, detail="Word of the day not found")

    lexeme = db.scalar(select(Lexeme).where(Lexeme.id == row[0]))
    if not lexeme:
        raise HTTPException(status_code=404, detail="Lexeme not found")

    definition = _pick_definition(lexeme, lang)
    if not definition:
        raise HTTPException(status_code=404, detail="Definition not found")

    return WordOfDayPublic(
        date=today,
        lexeme_id=lexeme.id,
        lemma=lexeme.lemma,
        definition=definition,
        lang_code=lang,
    )


@router.get("/lexemes/{lexeme_id}", response_model=LexemePublic)
def get_lexeme(
    lexeme_id: str,
    lang: str = "sw",
    include_drafts: bool = Query(False),
    db: Session = Depends(get_db),
) -> LexemePublic:
    # Base query: by ID
    stmt = select(Lexeme).where(Lexeme.id == lexeme_id)

    # Default behavior: published only
    if not include_drafts:
        stmt = stmt.where(Lexeme.workflow == "published")

    # In dev mode: allow any workflow (draft/reviewed/published/archived)
    lexeme = db.scalars(stmt).first()
    if not lexeme:
        raise HTTPException(status_code=404, detail="Lexeme not found")

    senses = []
    for sense in lexeme.senses:
        # Default: published senses only
        if not include_drafts and sense.workflow != "published":
            continue

        definitions = []
        for definition in sense.definitions:
            if definition.lang_code != lang:
                continue

            # Keep your guardrail: don't show unreviewed AI Swahili defs
            if (
                lang == "sw"
                and getattr(definition, "is_ai_generated", False)
                and getattr(definition, "review_status", None) not in {"approved", "edited"}
            ):
                continue

            definitions.append(
                {
                    "id": definition.id,
                    "lang_code": definition.lang_code,
                    "definition": definition.definition,
                    "gloss": definition.gloss,
                    "is_primary": definition.is_primary,
                    "is_ai_generated": getattr(definition, "is_ai_generated", False),
                    "review_status": getattr(definition, "review_status", None),
                }
            )

        examples = []
        for example in sense.examples:
            texts = [
                {
                    "id": text.id,
                    "lang_code": text.lang_code,
                    "text": text.text,
                    "is_primary": text.is_primary,
                }
                for text in example.texts
                if text.lang_code == lang
            ]
            examples.append(
                {
                    "id": example.id,
                    "is_attested": example.is_attested,
                    "texts": texts,
                }
            )

        senses.append(
            {
                "id": sense.id,
                "sense_number": sense.sense_number,
                "domain_id": sense.domain_id,
                "register_id": sense.register_id,
                "usage_note": sense.usage_note,
                "definitions": definitions,
                "examples": examples,
            }
        )

    return LexemePublic(
        id=lexeme.id,
        lemma=lexeme.lemma,
        pos_id=lexeme.pos_id,
        status=lexeme.status,
        default_language_code=lexeme.default_language_code,
        senses=senses,
    )

@router.get("/lookup/lemma", response_model=LexemePublic)
def lookup_lemma(
    lemma: str,
    lang: str = "sw",
    include_drafts: bool = Query(False),
    db: Session = Depends(get_db),
) -> LexemePublic:
    normalized = normalize_sw(lemma)

    stmt = select(Lexeme).where(Lexeme.normalized_lemma == normalized)
    if not include_drafts:
        stmt = stmt.where(Lexeme.workflow == "published")

    lexeme = db.scalars(stmt).first()
    if not lexeme:
        raise HTTPException(status_code=404, detail="Lexeme not found")

    # Reuse the same rendering logic as /lexemes/{id}
    return get_lexeme(str(lexeme.id), lang=lang, include_drafts=include_drafts, db=db)


@router.get("/expressions/{expression_id}", response_model=ExpressionPublic)
def get_expression(expression_id: str, lang: str = "sw", db: Session = Depends(get_db)) -> ExpressionPublic:
    expression = db.scalar(
        select(Expression).where(Expression.id == expression_id, Expression.workflow == "published")
    )
    if not expression:
        raise HTTPException(status_code=404, detail="Expression not found")

    meanings = [
        {
            "id": meaning.id,
            "lang_code": meaning.lang_code,
            "meaning": meaning.meaning,
            "usage_context": meaning.usage_context,
            "is_primary": meaning.is_primary,
        }
        for meaning in expression.meanings
        if meaning.lang_code == lang
    ]
    examples = []
    for example in expression.examples:
        texts = [
            {
                "id": text.id,
                "lang_code": text.lang_code,
                "text": text.text,
                "is_primary": text.is_primary,
            }
            for text in example.texts
            if text.lang_code == lang
        ]
        examples.append({"id": example.id, "texts": texts})

    return ExpressionPublic(
        id=expression.id,
        text=expression.text,
        expression_type_id=expression.expression_type_id,
        region_id=expression.region_id,
        meanings=meanings,
        examples=examples,
    )
