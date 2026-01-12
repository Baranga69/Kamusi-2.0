from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import and_, select, update
from sqlalchemy.orm import Session, aliased

from app.db import get_db
from app.deps import require_api_key
from app.models import Lexeme, PartOfSpeech, Sense, SenseDefinition, Source
from app.schemas import (
    ReviewActionResponse,
    ReviewApproveRequest,
    ReviewBulkRequest,
    ReviewBulkResponse,
    ReviewDefinitionReference,
    ReviewDetail,
    ReviewEditRequest,
    ReviewQueueItem,
    ReviewRejectRequest,
    ReviewSourceInfo,
)

router = APIRouter(prefix="/admin/review", dependencies=[Depends(require_api_key)])

MORPHOLOGY_PREFIXES = (
    "Applicative form of",
    "Reciprocal form of",
    "Stative form of",
    "Causative form of",
    "Passive form of",
)


def build_review_note(reason: str, note: str | None) -> str:
    if note:
        return f"{reason}: {note}"
    return reason


def resolve_status_filter(status: str) -> list[str]:
    if status == "reviewed":
        return ["approved", "edited"]
    allowed = {"unreviewed", "approved", "edited", "rejected"}
    if status not in allowed:
        raise HTTPException(status_code=400, detail="Invalid review status")
    return [status]


@router.get("/queue", response_model=list[ReviewQueueItem])
def get_review_queue(
    status: str = "unreviewed",
    q: str | None = None,
    pos_code: str | None = None,
    lexeme_status: str | None = None,
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    sort: str = "oldest",
    db: Session = Depends(get_db),
) -> list[ReviewQueueItem]:
    sw_definition = aliased(SenseDefinition)
    en_definition = aliased(SenseDefinition)

    stmt = (
        select(
            sw_definition.id.label("sense_definition_id"),
            sw_definition.sense_id,
            Lexeme.id.label("lexeme_id"),
            Lexeme.lemma,
            PartOfSpeech.code.label("pos_code"),
            sw_definition.definition.label("sw_definition_preview"),
            en_definition.definition.label("en_definition_preview"),
            sw_definition.created_at,
            sw_definition.review_status,
            sw_definition.is_ai_generated,
        )
        .join(Sense, sw_definition.sense_id == Sense.id)
        .join(Lexeme, Sense.lexeme_id == Lexeme.id)
        .join(PartOfSpeech, Lexeme.pos_id == PartOfSpeech.id)
        .outerjoin(
            en_definition,
            and_(en_definition.sense_id == Sense.id, en_definition.lang_code == "en"),
        )
        .where(sw_definition.lang_code == "sw", sw_definition.is_ai_generated.is_(True))
    )

    statuses = resolve_status_filter(status)
    if statuses:
        stmt = stmt.where(sw_definition.review_status.in_(statuses))

    if q:
        stmt = stmt.where(Lexeme.lemma.ilike(f"%{q}%"))
    if pos_code:
        stmt = stmt.where(PartOfSpeech.code == pos_code)
    if lexeme_status:
        stmt = stmt.where(Lexeme.status == lexeme_status)

    if sort == "oldest":
        stmt = stmt.order_by(sw_definition.created_at.asc())
    elif sort == "newest":
        stmt = stmt.order_by(sw_definition.created_at.desc())
    elif sort == "lemma":
        stmt = stmt.order_by(Lexeme.lemma.asc())
    else:
        raise HTTPException(status_code=400, detail="Invalid sort option")

    stmt = stmt.limit(limit).offset(offset)

    rows = db.execute(stmt).all()
    items: list[ReviewQueueItem] = []
    for row in rows:
        en_text = row.en_definition_preview or ""
        fallback_text = row.en_definition_preview or row.sw_definition_preview
        morphology_like = any(en_text.startswith(prefix) for prefix in MORPHOLOGY_PREFIXES)
        items.append(
            ReviewQueueItem(
                sense_definition_id=row.sense_definition_id,
                sense_id=row.sense_id,
                lexeme_id=row.lexeme_id,
                lemma=row.lemma,
                pos_code=row.pos_code,
                sw_definition_preview=row.sw_definition_preview,
                en_definition_preview=fallback_text,
                created_at=row.created_at,
                review_status=row.review_status,
                is_ai_generated=row.is_ai_generated,
                morphology_like=morphology_like,
            )
        )
    return items


@router.get("/item/{sense_definition_id}", response_model=ReviewDetail)
def get_review_item(sense_definition_id: str, db: Session = Depends(get_db)) -> ReviewDetail:
    stmt = (
        select(SenseDefinition, Sense, Lexeme, PartOfSpeech, Source)
        .join(Sense, SenseDefinition.sense_id == Sense.id)
        .join(Lexeme, Sense.lexeme_id == Lexeme.id)
        .join(PartOfSpeech, Lexeme.pos_id == PartOfSpeech.id)
        .outerjoin(Source, SenseDefinition.source_id == Source.id)
        .where(SenseDefinition.id == sense_definition_id)
    )
    row = db.execute(stmt).first()
    if not row:
        raise HTTPException(status_code=404, detail="Sense definition not found")

    definition, sense, lexeme, pos, source = row

    en_definitions = db.scalars(
        select(SenseDefinition).where(
            SenseDefinition.sense_id == sense.id,
            SenseDefinition.lang_code == "en",
        )
    ).all()

    source_info = None
    if source:
        source_info = ReviewSourceInfo(
            id=source.id,
            title=source.title,
            author=source.author,
            year=source.year,
            source_type=source.source_type,
            url=source.url,
        )

    return ReviewDetail(
        sense_definition_id=definition.id,
        sense_id=sense.id,
        lexeme_id=lexeme.id,
        lemma=lexeme.lemma,
        pos_code=pos.code,
        sw_definition=definition.definition,
        sw_gloss=definition.gloss,
        en_definitions=[
            ReviewDefinitionReference(
                id=entry.id,
                definition=entry.definition,
                gloss=entry.gloss,
                source_id=entry.source_id,
            )
            for entry in en_definitions
        ],
        source=source_info,
        review_status=definition.review_status,
        is_ai_generated=definition.is_ai_generated,
        created_at=definition.created_at,
    )


def require_unreviewed_update(db: Session, definition_id: str, values: dict) -> ReviewActionResponse:
    stmt = (
        update(SenseDefinition)
        .where(SenseDefinition.id == definition_id, SenseDefinition.review_status == "unreviewed")
        .values(**values)
    )
    result = db.execute(stmt)
    if result.rowcount == 0:
        existing = db.get(SenseDefinition, definition_id)
        if not existing:
            raise HTTPException(status_code=404, detail="Sense definition not found")
        raise HTTPException(status_code=409, detail="Sense definition already reviewed")
    db.commit()
    updated = db.get(SenseDefinition, definition_id)
    if not updated:
        raise HTTPException(status_code=404, detail="Sense definition not found")
    return ReviewActionResponse(
        sense_definition_id=updated.id,
        review_status=updated.review_status or "",
        reviewed_by=updated.reviewed_by or "",
        reviewed_at=updated.reviewed_at or datetime.utcnow(),
    )


@router.post("/item/{definition_id}/approve", response_model=ReviewActionResponse)
def approve_review_item(
    definition_id: str, payload: ReviewApproveRequest, db: Session = Depends(get_db)
) -> ReviewActionResponse:
    values = {
        "review_status": "approved",
        "reviewed_by": payload.reviewer,
        "reviewed_at": datetime.utcnow(),
    }
    return require_unreviewed_update(db, definition_id, values)


@router.post("/item/{definition_id}/edit", response_model=ReviewActionResponse)
def edit_review_item(
    definition_id: str, payload: ReviewEditRequest, db: Session = Depends(get_db)
) -> ReviewActionResponse:
    definition_text = payload.definition.strip()
    if not definition_text:
        raise HTTPException(status_code=422, detail="Definition is required")
    values = {
        "definition": definition_text,
        "gloss": payload.gloss,
        "review_status": "edited",
        "reviewed_by": payload.reviewer,
        "reviewed_at": datetime.utcnow(),
    }
    return require_unreviewed_update(db, definition_id, values)


@router.post("/item/{definition_id}/reject", response_model=ReviewActionResponse)
def reject_review_item(
    definition_id: str, payload: ReviewRejectRequest, db: Session = Depends(get_db)
) -> ReviewActionResponse:
    if not payload.reason.strip():
        raise HTTPException(status_code=422, detail="Reject reason is required")
    values = {
        "review_status": "rejected",
        "review_note": build_review_note(payload.reason.strip(), payload.note),
        "reviewed_by": payload.reviewer,
        "reviewed_at": datetime.utcnow(),
    }
    return require_unreviewed_update(db, definition_id, values)


@router.post("/bulk", response_model=ReviewBulkResponse)
def bulk_review_action(payload: ReviewBulkRequest, db: Session = Depends(get_db)) -> ReviewBulkResponse:
    if not payload.ids:
        raise HTTPException(status_code=422, detail="At least one id is required")
    if payload.action not in {"approve", "reject"}:
        raise HTTPException(status_code=400, detail="Invalid bulk action")
    if payload.action == "reject" and not (payload.reason and payload.reason.strip()):
        raise HTTPException(status_code=422, detail="Reject reason is required")

    now = datetime.utcnow()
    review_note = None
    if payload.action == "reject":
        review_note = build_review_note(payload.reason.strip(), payload.note)

    values = {
        "review_status": "approved" if payload.action == "approve" else "rejected",
        "reviewed_by": payload.reviewer,
        "reviewed_at": now,
    }
    if review_note:
        values["review_note"] = review_note

    stmt = (
        update(SenseDefinition)
        .where(
            SenseDefinition.id.in_(payload.ids),
            SenseDefinition.review_status == "unreviewed",
        )
        .values(**values)
    )

    with db.begin():
        result = db.execute(stmt)

    updated = result.rowcount or 0
    skipped = len(payload.ids) - updated
    return ReviewBulkResponse(updated_count=updated, skipped_count=skipped)
