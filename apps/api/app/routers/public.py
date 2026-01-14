from datetime import date, datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import case, func, or_, select, literal
from sqlalchemy.orm import Session

from app.db import get_db
from app.models import Expression, Lexeme, SearchEntry, Sense, SenseDefinition, Example, ExampleText, PartOfSpeech
from app.normalize import normalize_sw
from app.schemas import ExpressionPublic, LexemePublic, SearchResult, WordOfDayPublic

router = APIRouter()


@router.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}

@router.get("/search", response_model=list[SearchResult])
def search(
    q: str = Query(..., min_length=1),
    lang: str = "sw",
    limit: int = Query(20, ge=1, le=100),
    db: Session = Depends(get_db),
) -> list[SearchResult]:
    normalized = normalize_sw(q)

    rank = case(
        (SearchEntry.normalized == normalized, 0),
        (SearchEntry.normalized.like(f"{normalized}%"), 1),
        (SearchEntry.normalized.like(f"%{normalized}%"), 2),
        else_=3,
    )

    # ---- subqueries to resolve lexeme_id for non-lexeme hits ----
    lexeme_id_for_definition = (
        select(Sense.lexeme_id)
        .join(SenseDefinition, SenseDefinition.sense_id == Sense.id)
        .where(SenseDefinition.id == SearchEntry.target_id)
        .scalar_subquery()
    )

    lexeme_id_for_example = (
        select(Sense.lexeme_id)
        .join(Example, Example.sense_id == Sense.id)
        .join(ExampleText, ExampleText.example_id == Example.id)
        .where(ExampleText.id == SearchEntry.target_id)
        .scalar_subquery()
    )

    resolved_lexeme_id = case(
        (SearchEntry.target_type == "lexeme", SearchEntry.target_id),
        (SearchEntry.target_type == "definition", lexeme_id_for_definition),
        (SearchEntry.target_type == "example", lexeme_id_for_example),
        else_=None,
    ).label("lexeme_id")

    match_kind = case(
        (SearchEntry.target_type == "lexeme", literal("lemma")),
        (SearchEntry.target_type == "definition", literal("definition")),
        (SearchEntry.target_type == "example", literal("example")),
        else_=literal("unknown"),
    ).label("match_kind")

    # ---- build a subquery FIRST to remove join ambiguity ----
    base = (
        select(
            SearchEntry.id.label("search_id"),
            SearchEntry.target_type,
            SearchEntry.target_id,
            SearchEntry.lang_code,
            SearchEntry.text,
            SearchEntry.normalized,
            SearchEntry.popularity,
            resolved_lexeme_id,
            match_kind,
        )
        .select_from(SearchEntry) 
        .where(SearchEntry.lang_code == lang)
        .where(SearchEntry.normalized.like(f"%{normalized}%"))
        .order_by(rank.asc(), SearchEntry.popularity.desc())
        .limit(limit)
        .subquery()
    )

    # ---- now join Lexeme using the subquery column (no ambiguity) ----
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
            Lexeme.lemma,
            PartOfSpeech.code.label("pos_code"),
            base.c.match_kind,
        )
        .select_from(base)
        .join(Lexeme, Lexeme.id == base.c.lexeme_id)
        .outerjoin(PartOfSpeech, PartOfSpeech.id == Lexeme.pos_id)
        .where(base.c.lexeme_id.isnot(None))
    )

    rows = db.execute(stmt).all()

    out: list[SearchResult] = []
    for r in rows:
        out.append(
            SearchResult(
                id=r.search_id,
                target_type=r.target_type,
                target_id=r.target_id,
                lang_code=r.lang_code,
                text=r.text,
                normalized=r.normalized,
                popularity=r.popularity or 0,
                lexeme_id=r.lexeme_id,
                lemma=r.lemma,
                pos_code=r.pos_code,
                match_kind=r.match_kind,
            )
        )
    return out


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
