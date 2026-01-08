from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.db import get_db
from app.deps import require_api_key
from app.models import (
    Example,
    ExampleText,
    Expression,
    ExpressionExample,
    ExpressionExampleText,
    ExpressionLink,
    ExpressionMeaning,
    Lexeme,
    LexemeTag,
    License,
    Sense,
    SenseDefinition,
    SenseTag,
    Source,
    Tag,
    Wordform,
)
from app.normalize import normalize_sw
from app.schemas import (
    ExampleCreate,
    ExampleRead,
    ExampleTextCreate,
    ExampleTextRead,
    ExampleTextUpdate,
    ExampleUpdate,
    ExpressionCreate,
    ExpressionExampleCreate,
    ExpressionExampleRead,
    ExpressionExampleTextCreate,
    ExpressionExampleTextRead,
    ExpressionExampleTextUpdate,
    ExpressionExampleUpdate,
    ExpressionLinkCreate,
    ExpressionLinkRead,
    ExpressionLinkUpdate,
    ExpressionMeaningCreate,
    ExpressionMeaningRead,
    ExpressionMeaningUpdate,
    ExpressionRead,
    ExpressionUpdate,
    LexemeCreate,
    LexemeRead,
    LexemeTagCreate,
    LexemeTagRead,
    LexemeTagUpdate,
    LexemeUpdate,
    LicenseCreate,
    LicenseRead,
    LicenseUpdate,
    SenseCreate,
    SenseDefinitionCreate,
    SenseDefinitionRead,
    SenseDefinitionUpdate,
    SenseRead,
    SenseTagCreate,
    SenseTagRead,
    SenseTagUpdate,
    SenseUpdate,
    SourceCreate,
    SourceRead,
    SourceUpdate,
    TagCreate,
    TagRead,
    TagUpdate,
    WordformCreate,
    WordformRead,
    WordformUpdate,
)
from app.services.publish import publish_expression, publish_lexeme, review_expression, review_lexeme

router = APIRouter(prefix="/admin", dependencies=[Depends(require_api_key)])


def get_or_404(db: Session, model, object_id):
    obj = db.get(model, object_id)
    if not obj:
        raise HTTPException(status_code=404, detail=f"{model.__name__} not found")
    return obj


@router.post("/licenses", response_model=LicenseRead)
def create_license(payload: LicenseCreate, db: Session = Depends(get_db)) -> LicenseRead:
    license_ = License(**payload.model_dump())
    db.add(license_)
    db.commit()
    db.refresh(license_)
    return LicenseRead(**license_.__dict__)


@router.get("/licenses/{license_id}", response_model=LicenseRead)
def get_license(license_id: str, db: Session = Depends(get_db)) -> LicenseRead:
    license_ = get_or_404(db, License, license_id)
    return LicenseRead(**license_.__dict__)


@router.put("/licenses/{license_id}", response_model=LicenseRead)
def update_license(license_id: str, payload: LicenseUpdate, db: Session = Depends(get_db)) -> LicenseRead:
    license_ = get_or_404(db, License, license_id)
    for key, value in payload.model_dump(exclude_unset=True).items():
        setattr(license_, key, value)
    db.commit()
    db.refresh(license_)
    return LicenseRead(**license_.__dict__)


@router.delete("/licenses/{license_id}")
def delete_license(license_id: str, db: Session = Depends(get_db)) -> dict[str, str]:
    license_ = get_or_404(db, License, license_id)
    db.delete(license_)
    db.commit()
    return {"status": "deleted"}


@router.post("/sources", response_model=SourceRead)
def create_source(payload: SourceCreate, db: Session = Depends(get_db)) -> SourceRead:
    source = Source(**payload.model_dump())
    db.add(source)
    db.commit()
    db.refresh(source)
    return SourceRead(**source.__dict__)


@router.get("/sources/{source_id}", response_model=SourceRead)
def get_source(source_id: str, db: Session = Depends(get_db)) -> SourceRead:
    source = get_or_404(db, Source, source_id)
    return SourceRead(**source.__dict__)


@router.put("/sources/{source_id}", response_model=SourceRead)
def update_source(source_id: str, payload: SourceUpdate, db: Session = Depends(get_db)) -> SourceRead:
    source = get_or_404(db, Source, source_id)
    for key, value in payload.model_dump(exclude_unset=True).items():
        setattr(source, key, value)
    db.commit()
    db.refresh(source)
    return SourceRead(**source.__dict__)


@router.delete("/sources/{source_id}")
def delete_source(source_id: str, db: Session = Depends(get_db)) -> dict[str, str]:
    source = get_or_404(db, Source, source_id)
    db.delete(source)
    db.commit()
    return {"status": "deleted"}


@router.post("/lexemes", response_model=LexemeRead)
def create_lexeme(payload: LexemeCreate, db: Session = Depends(get_db)) -> LexemeRead:
    normalized = normalize_sw(payload.lemma)
    lexeme = Lexeme(**payload.model_dump(), normalized_lemma=normalized)
    db.add(lexeme)
    db.commit()
    db.refresh(lexeme)
    return LexemeRead(**lexeme.__dict__)


@router.get("/lexemes/{lexeme_id}", response_model=LexemeRead)
def get_lexeme(lexeme_id: str, db: Session = Depends(get_db)) -> LexemeRead:
    lexeme = get_or_404(db, Lexeme, lexeme_id)
    return LexemeRead(**lexeme.__dict__)


@router.put("/lexemes/{lexeme_id}", response_model=LexemeRead)
def update_lexeme(lexeme_id: str, payload: LexemeUpdate, db: Session = Depends(get_db)) -> LexemeRead:
    lexeme = get_or_404(db, Lexeme, lexeme_id)
    data = payload.model_dump(exclude_unset=True)
    if "lemma" in data:
        data["normalized_lemma"] = normalize_sw(data["lemma"])
    for key, value in data.items():
        setattr(lexeme, key, value)
    db.commit()
    db.refresh(lexeme)
    return LexemeRead(**lexeme.__dict__)


@router.delete("/lexemes/{lexeme_id}")
def delete_lexeme(lexeme_id: str, db: Session = Depends(get_db)) -> dict[str, str]:
    lexeme = get_or_404(db, Lexeme, lexeme_id)
    db.delete(lexeme)
    db.commit()
    return {"status": "deleted"}


@router.post("/lexemes/{lexeme_id}/review", response_model=LexemeRead)
def review_lexeme_endpoint(lexeme_id: str, db: Session = Depends(get_db)) -> LexemeRead:
    lexeme = review_lexeme(db, lexeme_id)
    return LexemeRead(**lexeme.__dict__)


@router.post("/lexemes/{lexeme_id}/publish", response_model=LexemeRead)
def publish_lexeme_endpoint(lexeme_id: str, db: Session = Depends(get_db)) -> LexemeRead:
    lexeme = publish_lexeme(db, lexeme_id)
    return LexemeRead(**lexeme.__dict__)


@router.post("/senses", response_model=SenseRead)
def create_sense(payload: SenseCreate, db: Session = Depends(get_db)) -> SenseRead:
    sense = Sense(**payload.model_dump())
    db.add(sense)
    db.commit()
    db.refresh(sense)
    return SenseRead(**sense.__dict__)


@router.get("/senses/{sense_id}", response_model=SenseRead)
def get_sense(sense_id: str, db: Session = Depends(get_db)) -> SenseRead:
    sense = get_or_404(db, Sense, sense_id)
    return SenseRead(**sense.__dict__)


@router.put("/senses/{sense_id}", response_model=SenseRead)
def update_sense(sense_id: str, payload: SenseUpdate, db: Session = Depends(get_db)) -> SenseRead:
    sense = get_or_404(db, Sense, sense_id)
    for key, value in payload.model_dump(exclude_unset=True).items():
        setattr(sense, key, value)
    db.commit()
    db.refresh(sense)
    return SenseRead(**sense.__dict__)


@router.delete("/senses/{sense_id}")
def delete_sense(sense_id: str, db: Session = Depends(get_db)) -> dict[str, str]:
    sense = get_or_404(db, Sense, sense_id)
    db.delete(sense)
    db.commit()
    return {"status": "deleted"}


@router.post("/sense-definitions", response_model=SenseDefinitionRead)
def create_sense_definition(
    payload: SenseDefinitionCreate, db: Session = Depends(get_db)
) -> SenseDefinitionRead:
    definition = SenseDefinition(**payload.model_dump())
    db.add(definition)
    db.commit()
    db.refresh(definition)
    return SenseDefinitionRead(**definition.__dict__)


@router.get("/sense-definitions/{definition_id}", response_model=SenseDefinitionRead)
def get_sense_definition(definition_id: str, db: Session = Depends(get_db)) -> SenseDefinitionRead:
    definition = get_or_404(db, SenseDefinition, definition_id)
    return SenseDefinitionRead(**definition.__dict__)


@router.put("/sense-definitions/{definition_id}", response_model=SenseDefinitionRead)
def update_sense_definition(
    definition_id: str, payload: SenseDefinitionUpdate, db: Session = Depends(get_db)
) -> SenseDefinitionRead:
    definition = get_or_404(db, SenseDefinition, definition_id)
    for key, value in payload.model_dump(exclude_unset=True).items():
        setattr(definition, key, value)
    db.commit()
    db.refresh(definition)
    return SenseDefinitionRead(**definition.__dict__)


@router.delete("/sense-definitions/{definition_id}")
def delete_sense_definition(definition_id: str, db: Session = Depends(get_db)) -> dict[str, str]:
    definition = get_or_404(db, SenseDefinition, definition_id)
    db.delete(definition)
    db.commit()
    return {"status": "deleted"}


@router.post("/examples", response_model=ExampleRead)
def create_example(payload: ExampleCreate, db: Session = Depends(get_db)) -> ExampleRead:
    example = Example(**payload.model_dump())
    db.add(example)
    db.commit()
    db.refresh(example)
    return ExampleRead(**example.__dict__)


@router.get("/examples/{example_id}", response_model=ExampleRead)
def get_example(example_id: str, db: Session = Depends(get_db)) -> ExampleRead:
    example = get_or_404(db, Example, example_id)
    return ExampleRead(**example.__dict__)


@router.put("/examples/{example_id}", response_model=ExampleRead)
def update_example(example_id: str, payload: ExampleUpdate, db: Session = Depends(get_db)) -> ExampleRead:
    example = get_or_404(db, Example, example_id)
    for key, value in payload.model_dump(exclude_unset=True).items():
        setattr(example, key, value)
    db.commit()
    db.refresh(example)
    return ExampleRead(**example.__dict__)


@router.delete("/examples/{example_id}")
def delete_example(example_id: str, db: Session = Depends(get_db)) -> dict[str, str]:
    example = get_or_404(db, Example, example_id)
    db.delete(example)
    db.commit()
    return {"status": "deleted"}


@router.post("/example-texts", response_model=ExampleTextRead)
def create_example_text(payload: ExampleTextCreate, db: Session = Depends(get_db)) -> ExampleTextRead:
    example_text = ExampleText(**payload.model_dump())
    db.add(example_text)
    db.commit()
    db.refresh(example_text)
    return ExampleTextRead(**example_text.__dict__)


@router.get("/example-texts/{example_text_id}", response_model=ExampleTextRead)
def get_example_text(example_text_id: str, db: Session = Depends(get_db)) -> ExampleTextRead:
    example_text = get_or_404(db, ExampleText, example_text_id)
    return ExampleTextRead(**example_text.__dict__)


@router.put("/example-texts/{example_text_id}", response_model=ExampleTextRead)
def update_example_text(
    example_text_id: str, payload: ExampleTextUpdate, db: Session = Depends(get_db)
) -> ExampleTextRead:
    example_text = get_or_404(db, ExampleText, example_text_id)
    for key, value in payload.model_dump(exclude_unset=True).items():
        setattr(example_text, key, value)
    db.commit()
    db.refresh(example_text)
    return ExampleTextRead(**example_text.__dict__)


@router.delete("/example-texts/{example_text_id}")
def delete_example_text(example_text_id: str, db: Session = Depends(get_db)) -> dict[str, str]:
    example_text = get_or_404(db, ExampleText, example_text_id)
    db.delete(example_text)
    db.commit()
    return {"status": "deleted"}


@router.post("/expressions", response_model=ExpressionRead)
def create_expression(payload: ExpressionCreate, db: Session = Depends(get_db)) -> ExpressionRead:
    normalized = normalize_sw(payload.text)
    expression = Expression(**payload.model_dump(), normalized_text=normalized)
    db.add(expression)
    db.commit()
    db.refresh(expression)
    return ExpressionRead(**expression.__dict__)


@router.get("/expressions/{expression_id}", response_model=ExpressionRead)
def get_expression(expression_id: str, db: Session = Depends(get_db)) -> ExpressionRead:
    expression = get_or_404(db, Expression, expression_id)
    return ExpressionRead(**expression.__dict__)


@router.put("/expressions/{expression_id}", response_model=ExpressionRead)
def update_expression(expression_id: str, payload: ExpressionUpdate, db: Session = Depends(get_db)) -> ExpressionRead:
    expression = get_or_404(db, Expression, expression_id)
    data = payload.model_dump(exclude_unset=True)
    if "text" in data:
        data["normalized_text"] = normalize_sw(data["text"])
    for key, value in data.items():
        setattr(expression, key, value)
    db.commit()
    db.refresh(expression)
    return ExpressionRead(**expression.__dict__)


@router.delete("/expressions/{expression_id}")
def delete_expression(expression_id: str, db: Session = Depends(get_db)) -> dict[str, str]:
    expression = get_or_404(db, Expression, expression_id)
    db.delete(expression)
    db.commit()
    return {"status": "deleted"}


@router.post("/expressions/{expression_id}/review", response_model=ExpressionRead)
def review_expression_endpoint(expression_id: str, db: Session = Depends(get_db)) -> ExpressionRead:
    expression = review_expression(db, expression_id)
    return ExpressionRead(**expression.__dict__)


@router.post("/expressions/{expression_id}/publish", response_model=ExpressionRead)
def publish_expression_endpoint(expression_id: str, db: Session = Depends(get_db)) -> ExpressionRead:
    expression = publish_expression(db, expression_id)
    return ExpressionRead(**expression.__dict__)


@router.post("/expression-meanings", response_model=ExpressionMeaningRead)
def create_expression_meaning(
    payload: ExpressionMeaningCreate, db: Session = Depends(get_db)
) -> ExpressionMeaningRead:
    meaning = ExpressionMeaning(**payload.model_dump())
    db.add(meaning)
    db.commit()
    db.refresh(meaning)
    return ExpressionMeaningRead(**meaning.__dict__)


@router.get("/expression-meanings/{meaning_id}", response_model=ExpressionMeaningRead)
def get_expression_meaning(meaning_id: str, db: Session = Depends(get_db)) -> ExpressionMeaningRead:
    meaning = get_or_404(db, ExpressionMeaning, meaning_id)
    return ExpressionMeaningRead(**meaning.__dict__)


@router.put("/expression-meanings/{meaning_id}", response_model=ExpressionMeaningRead)
def update_expression_meaning(
    meaning_id: str, payload: ExpressionMeaningUpdate, db: Session = Depends(get_db)
) -> ExpressionMeaningRead:
    meaning = get_or_404(db, ExpressionMeaning, meaning_id)
    for key, value in payload.model_dump(exclude_unset=True).items():
        setattr(meaning, key, value)
    db.commit()
    db.refresh(meaning)
    return ExpressionMeaningRead(**meaning.__dict__)


@router.delete("/expression-meanings/{meaning_id}")
def delete_expression_meaning(meaning_id: str, db: Session = Depends(get_db)) -> dict[str, str]:
    meaning = get_or_404(db, ExpressionMeaning, meaning_id)
    db.delete(meaning)
    db.commit()
    return {"status": "deleted"}


@router.post("/expression-examples", response_model=ExpressionExampleRead)
def create_expression_example(
    payload: ExpressionExampleCreate, db: Session = Depends(get_db)
) -> ExpressionExampleRead:
    example = ExpressionExample(**payload.model_dump())
    db.add(example)
    db.commit()
    db.refresh(example)
    return ExpressionExampleRead(**example.__dict__)


@router.get("/expression-examples/{example_id}", response_model=ExpressionExampleRead)
def get_expression_example(example_id: str, db: Session = Depends(get_db)) -> ExpressionExampleRead:
    example = get_or_404(db, ExpressionExample, example_id)
    return ExpressionExampleRead(**example.__dict__)


@router.put("/expression-examples/{example_id}", response_model=ExpressionExampleRead)
def update_expression_example(
    example_id: str, payload: ExpressionExampleUpdate, db: Session = Depends(get_db)
) -> ExpressionExampleRead:
    example = get_or_404(db, ExpressionExample, example_id)
    for key, value in payload.model_dump(exclude_unset=True).items():
        setattr(example, key, value)
    db.commit()
    db.refresh(example)
    return ExpressionExampleRead(**example.__dict__)


@router.delete("/expression-examples/{example_id}")
def delete_expression_example(example_id: str, db: Session = Depends(get_db)) -> dict[str, str]:
    example = get_or_404(db, ExpressionExample, example_id)
    db.delete(example)
    db.commit()
    return {"status": "deleted"}


@router.post("/expression-example-texts", response_model=ExpressionExampleTextRead)
def create_expression_example_text(
    payload: ExpressionExampleTextCreate, db: Session = Depends(get_db)
) -> ExpressionExampleTextRead:
    example_text = ExpressionExampleText(**payload.model_dump())
    db.add(example_text)
    db.commit()
    db.refresh(example_text)
    return ExpressionExampleTextRead(**example_text.__dict__)


@router.get("/expression-example-texts/{example_text_id}", response_model=ExpressionExampleTextRead)
def get_expression_example_text(
    example_text_id: str, db: Session = Depends(get_db)
) -> ExpressionExampleTextRead:
    example_text = get_or_404(db, ExpressionExampleText, example_text_id)
    return ExpressionExampleTextRead(**example_text.__dict__)


@router.put("/expression-example-texts/{example_text_id}", response_model=ExpressionExampleTextRead)
def update_expression_example_text(
    example_text_id: str, payload: ExpressionExampleTextUpdate, db: Session = Depends(get_db)
) -> ExpressionExampleTextRead:
    example_text = get_or_404(db, ExpressionExampleText, example_text_id)
    for key, value in payload.model_dump(exclude_unset=True).items():
        setattr(example_text, key, value)
    db.commit()
    db.refresh(example_text)
    return ExpressionExampleTextRead(**example_text.__dict__)


@router.delete("/expression-example-texts/{example_text_id}")
def delete_expression_example_text(example_text_id: str, db: Session = Depends(get_db)) -> dict[str, str]:
    example_text = get_or_404(db, ExpressionExampleText, example_text_id)
    db.delete(example_text)
    db.commit()
    return {"status": "deleted"}


@router.post("/expression-links", response_model=ExpressionLinkRead)
def create_expression_link(
    payload: ExpressionLinkCreate, db: Session = Depends(get_db)
) -> ExpressionLinkRead:
    link = ExpressionLink(**payload.model_dump())
    db.add(link)
    db.commit()
    db.refresh(link)
    return ExpressionLinkRead(**link.__dict__)


@router.get("/expression-links/{link_id}", response_model=ExpressionLinkRead)
def get_expression_link(link_id: str, db: Session = Depends(get_db)) -> ExpressionLinkRead:
    link = get_or_404(db, ExpressionLink, link_id)
    return ExpressionLinkRead(**link.__dict__)


@router.put("/expression-links/{link_id}", response_model=ExpressionLinkRead)
def update_expression_link(
    link_id: str, payload: ExpressionLinkUpdate, db: Session = Depends(get_db)
) -> ExpressionLinkRead:
    link = get_or_404(db, ExpressionLink, link_id)
    for key, value in payload.model_dump(exclude_unset=True).items():
        setattr(link, key, value)
    db.commit()
    db.refresh(link)
    return ExpressionLinkRead(**link.__dict__)


@router.delete("/expression-links/{link_id}")
def delete_expression_link(link_id: str, db: Session = Depends(get_db)) -> dict[str, str]:
    link = get_or_404(db, ExpressionLink, link_id)
    db.delete(link)
    db.commit()
    return {"status": "deleted"}


@router.post("/tags", response_model=TagRead)
def create_tag(payload: TagCreate, db: Session = Depends(get_db)) -> TagRead:
    tag = Tag(**payload.model_dump())
    db.add(tag)
    db.commit()
    db.refresh(tag)
    return TagRead(**tag.__dict__)


@router.get("/tags/{tag_id}", response_model=TagRead)
def get_tag(tag_id: str, db: Session = Depends(get_db)) -> TagRead:
    tag = get_or_404(db, Tag, tag_id)
    return TagRead(**tag.__dict__)


@router.put("/tags/{tag_id}", response_model=TagRead)
def update_tag(tag_id: str, payload: TagUpdate, db: Session = Depends(get_db)) -> TagRead:
    tag = get_or_404(db, Tag, tag_id)
    for key, value in payload.model_dump(exclude_unset=True).items():
        setattr(tag, key, value)
    db.commit()
    db.refresh(tag)
    return TagRead(**tag.__dict__)


@router.delete("/tags/{tag_id}")
def delete_tag(tag_id: str, db: Session = Depends(get_db)) -> dict[str, str]:
    tag = get_or_404(db, Tag, tag_id)
    db.delete(tag)
    db.commit()
    return {"status": "deleted"}


@router.post("/lexeme-tags", response_model=LexemeTagRead)
def create_lexeme_tag(payload: LexemeTagCreate, db: Session = Depends(get_db)) -> LexemeTagRead:
    lexeme_tag = LexemeTag(**payload.model_dump())
    db.add(lexeme_tag)
    db.commit()
    return LexemeTagRead(**lexeme_tag.__dict__)


@router.get("/lexeme-tags/{lexeme_id}/{tag_id}", response_model=LexemeTagRead)
def get_lexeme_tag(lexeme_id: str, tag_id: str, db: Session = Depends(get_db)) -> LexemeTagRead:
    stmt = select(LexemeTag).where(LexemeTag.lexeme_id == lexeme_id, LexemeTag.tag_id == tag_id)
    lexeme_tag = db.scalar(stmt)
    if not lexeme_tag:
        raise HTTPException(status_code=404, detail="LexemeTag not found")
    return LexemeTagRead(**lexeme_tag.__dict__)


@router.put("/lexeme-tags/{lexeme_id}/{tag_id}", response_model=LexemeTagRead)
def update_lexeme_tag(
    lexeme_id: str, tag_id: str, payload: LexemeTagUpdate, db: Session = Depends(get_db)
) -> LexemeTagRead:
    stmt = select(LexemeTag).where(LexemeTag.lexeme_id == lexeme_id, LexemeTag.tag_id == tag_id)
    lexeme_tag = db.scalar(stmt)
    if not lexeme_tag:
        raise HTTPException(status_code=404, detail="LexemeTag not found")
    for key, value in payload.model_dump(exclude_unset=True).items():
        setattr(lexeme_tag, key, value)
    db.commit()
    return LexemeTagRead(**lexeme_tag.__dict__)


@router.delete("/lexeme-tags/{lexeme_id}/{tag_id}")
def delete_lexeme_tag(lexeme_id: str, tag_id: str, db: Session = Depends(get_db)) -> dict[str, str]:
    stmt = select(LexemeTag).where(LexemeTag.lexeme_id == lexeme_id, LexemeTag.tag_id == tag_id)
    lexeme_tag = db.scalar(stmt)
    if not lexeme_tag:
        raise HTTPException(status_code=404, detail="LexemeTag not found")
    db.delete(lexeme_tag)
    db.commit()
    return {"status": "deleted"}


@router.post("/sense-tags", response_model=SenseTagRead)
def create_sense_tag(payload: SenseTagCreate, db: Session = Depends(get_db)) -> SenseTagRead:
    sense_tag = SenseTag(**payload.model_dump())
    db.add(sense_tag)
    db.commit()
    return SenseTagRead(**sense_tag.__dict__)


@router.get("/sense-tags/{sense_id}/{tag_id}", response_model=SenseTagRead)
def get_sense_tag(sense_id: str, tag_id: str, db: Session = Depends(get_db)) -> SenseTagRead:
    stmt = select(SenseTag).where(SenseTag.sense_id == sense_id, SenseTag.tag_id == tag_id)
    sense_tag = db.scalar(stmt)
    if not sense_tag:
        raise HTTPException(status_code=404, detail="SenseTag not found")
    return SenseTagRead(**sense_tag.__dict__)


@router.put("/sense-tags/{sense_id}/{tag_id}", response_model=SenseTagRead)
def update_sense_tag(
    sense_id: str, tag_id: str, payload: SenseTagUpdate, db: Session = Depends(get_db)
) -> SenseTagRead:
    stmt = select(SenseTag).where(SenseTag.sense_id == sense_id, SenseTag.tag_id == tag_id)
    sense_tag = db.scalar(stmt)
    if not sense_tag:
        raise HTTPException(status_code=404, detail="SenseTag not found")
    for key, value in payload.model_dump(exclude_unset=True).items():
        setattr(sense_tag, key, value)
    db.commit()
    return SenseTagRead(**sense_tag.__dict__)


@router.delete("/sense-tags/{sense_id}/{tag_id}")
def delete_sense_tag(sense_id: str, tag_id: str, db: Session = Depends(get_db)) -> dict[str, str]:
    stmt = select(SenseTag).where(SenseTag.sense_id == sense_id, SenseTag.tag_id == tag_id)
    sense_tag = db.scalar(stmt)
    if not sense_tag:
        raise HTTPException(status_code=404, detail="SenseTag not found")
    db.delete(sense_tag)
    db.commit()
    return {"status": "deleted"}


@router.post("/wordforms", response_model=WordformRead)
def create_wordform(payload: WordformCreate, db: Session = Depends(get_db)) -> WordformRead:
    wordform = Wordform(
        **payload.model_dump(), normalized_form=normalize_sw(payload.form)
    )
    db.add(wordform)
    db.commit()
    db.refresh(wordform)
    return WordformRead(**wordform.__dict__)


@router.get("/wordforms/{wordform_id}", response_model=WordformRead)
def get_wordform(wordform_id: str, db: Session = Depends(get_db)) -> WordformRead:
    wordform = get_or_404(db, Wordform, wordform_id)
    return WordformRead(**wordform.__dict__)


@router.put("/wordforms/{wordform_id}", response_model=WordformRead)
def update_wordform(wordform_id: str, payload: WordformUpdate, db: Session = Depends(get_db)) -> WordformRead:
    wordform = get_or_404(db, Wordform, wordform_id)
    data = payload.model_dump(exclude_unset=True)
    if "form" in data:
        data["normalized_form"] = normalize_sw(data["form"])
    for key, value in data.items():
        setattr(wordform, key, value)
    db.commit()
    db.refresh(wordform)
    return WordformRead(**wordform.__dict__)


@router.delete("/wordforms/{wordform_id}")
def delete_wordform(wordform_id: str, db: Session = Depends(get_db)) -> dict[str, str]:
    wordform = get_or_404(db, Wordform, wordform_id)
    db.delete(wordform)
    db.commit()
    return {"status": "deleted"}
