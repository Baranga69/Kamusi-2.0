from sqlalchemy import func, select
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.orm import Session

from app.models import Expression, ExpressionMeaning, Lexeme, SearchEntry
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


def publish_lexeme(db: Session, lexeme_id) -> Lexeme:
    lexeme = db.scalar(select(Lexeme).where(Lexeme.id == lexeme_id))
    if not lexeme:
        raise ValueError("Lexeme not found")

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
            upsert_search_entry(
                db,
                target_type="sense",
                target_id=definition.sense_id,
                lang_code=definition.lang_code,
                text=definition.definition,
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
        upsert_search_entry(
            db,
            target_type="expression",
            target_id=expression.id,
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
