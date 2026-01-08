from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import case, select
from sqlalchemy.orm import Session

from app.db import get_db
from app.models import Expression, Lexeme, SearchEntry
from app.normalize import normalize_sw
from app.schemas import ExpressionPublic, LexemePublic, SearchResult

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
    stmt = (
        select(SearchEntry)
        .where(SearchEntry.lang_code == lang)
        .where(SearchEntry.normalized.like(f"%{normalized}%"))
        .order_by(rank.asc(), SearchEntry.popularity.desc())
        .limit(limit)
    )
    results = db.scalars(stmt).all()
    return [
        SearchResult(
            id=row.id,
            target_type=row.target_type,
            target_id=row.target_id,
            lang_code=row.lang_code,
            text=row.text,
            normalized=row.normalized,
            popularity=row.popularity,
        )
        for row in results
    ]


@router.get("/lexemes/{lexeme_id}", response_model=LexemePublic)
def get_lexeme(lexeme_id: str, lang: str = "sw", db: Session = Depends(get_db)) -> LexemePublic:
    stmt = select(Lexeme).where(Lexeme.id == lexeme_id, Lexeme.workflow == "published")
    lexeme = db.scalar(stmt)
    if not lexeme:
        raise HTTPException(status_code=404, detail="Lexeme not found")
    senses = []
    for sense in lexeme.senses:
        if sense.workflow != "published":
            continue
        definitions = [
            {
                "id": definition.id,
                "lang_code": definition.lang_code,
                "definition": definition.definition,
                "gloss": definition.gloss,
                "is_primary": definition.is_primary,
            }
            for definition in sense.definitions
            if definition.lang_code == lang
        ]
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


@router.get("/lookup/{lemma}", response_model=LexemePublic)
def lookup_lemma(lemma: str, lang: str = "sw", db: Session = Depends(get_db)) -> LexemePublic:
    normalized = normalize_sw(lemma)
    stmt = select(Lexeme).where(
        Lexeme.normalized_lemma == normalized, Lexeme.workflow == "published"
    )
    lexeme = db.scalar(stmt)
    if not lexeme:
        raise HTTPException(status_code=404, detail="Lexeme not found")
    return get_lexeme(str(lexeme.id), lang=lang, db=db)


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
