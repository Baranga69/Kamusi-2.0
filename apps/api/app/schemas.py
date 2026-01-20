import uuid
from datetime import date, datetime

from pydantic import BaseModel, Field


class LanguageCreate(BaseModel):
    code: str
    name: str


class LanguageRead(LanguageCreate):
    pass


class PartOfSpeechCreate(BaseModel):
    code: str
    label: str


class PartOfSpeechRead(PartOfSpeechCreate):
    id: uuid.UUID


class RegisterCreate(BaseModel):
    code: str
    label: str


class RegisterRead(RegisterCreate):
    id: uuid.UUID


class DomainCreate(BaseModel):
    code: str
    label: str


class DomainRead(DomainCreate):
    id: uuid.UUID


class RegionCreate(BaseModel):
    code: str
    label: str


class RegionRead(RegionCreate):
    id: uuid.UUID


class ExpressionTypeCreate(BaseModel):
    code: str
    label: str


class ExpressionTypeRead(ExpressionTypeCreate):
    id: uuid.UUID


class TagTypeCreate(BaseModel):
    code: str
    label: str


class TagTypeRead(TagTypeCreate):
    id: uuid.UUID


class LicenseCreate(BaseModel):
    name: str
    summary: str | None = None
    can_display: bool = True
    can_modify: bool = False
    can_commercialize: bool = False


class LicenseUpdate(BaseModel):
    name: str | None = None
    summary: str | None = None
    can_display: bool | None = None
    can_modify: bool | None = None
    can_commercialize: bool | None = None


class LicenseRead(LicenseCreate):
    id: uuid.UUID


class SourceCreate(BaseModel):
    title: str
    author: str | None = None
    publisher: str | None = None
    year: int | None = None
    source_type: str
    license_id: uuid.UUID
    url: str | None = None
    notes: str | None = None


class SourceUpdate(BaseModel):
    title: str | None = None
    author: str | None = None
    publisher: str | None = None
    year: int | None = None
    source_type: str | None = None
    license_id: uuid.UUID | None = None
    url: str | None = None
    notes: str | None = None


class SourceRead(SourceCreate):
    id: uuid.UUID


class LexemeCreate(BaseModel):
    lemma: str
    pos_id: uuid.UUID
    status: str = "core"
    default_language_code: str = "sw"
    workflow: str = "draft"


class LexemeUpdate(BaseModel):
    lemma: str | None = None
    pos_id: uuid.UUID | None = None
    status: str | None = None
    default_language_code: str | None = None
    workflow: str | None = None


class LexemeRead(LexemeCreate):
    id: uuid.UUID
    normalized_lemma: str
    created_at: datetime
    updated_at: datetime


class SenseCreate(BaseModel):
    lexeme_id: uuid.UUID
    sense_number: int
    domain_id: uuid.UUID | None = None
    register_id: uuid.UUID | None = None
    usage_note: str | None = None
    workflow: str = "draft"


class SenseUpdate(BaseModel):
    sense_number: int | None = None
    domain_id: uuid.UUID | None = None
    register_id: uuid.UUID | None = None
    usage_note: str | None = None
    workflow: str | None = None


class SenseRead(SenseCreate):
    id: uuid.UUID
    created_at: datetime
    updated_at: datetime


class SenseDefinitionCreate(BaseModel):
    sense_id: uuid.UUID
    lang_code: str
    definition: str
    gloss: str | None = None
    is_primary: bool = False
    source_id: uuid.UUID | None = None


class SenseDefinitionUpdate(BaseModel):
    definition: str | None = None
    gloss: str | None = None
    is_primary: bool | None = None
    source_id: uuid.UUID | None = None


class SenseDefinitionRead(SenseDefinitionCreate):
    id: uuid.UUID
    created_at: datetime
    is_ai_generated: bool | None = None
    review_status: str | None = None
    reviewed_by: str | None = None
    reviewed_at: datetime | None = None
    ai_model: str | None = None
    ai_prompt_version: str | None = None
    review_note: str | None = None


class ExampleCreate(BaseModel):
    sense_id: uuid.UUID
    is_attested: bool = True
    source_id: uuid.UUID | None = None


class ExampleUpdate(BaseModel):
    is_attested: bool | None = None
    source_id: uuid.UUID | None = None


class ExampleRead(ExampleCreate):
    id: uuid.UUID
    created_at: datetime


class ExampleTextCreate(BaseModel):
    example_id: uuid.UUID
    lang_code: str
    text: str
    is_primary: bool = False


class ExampleTextUpdate(BaseModel):
    text: str | None = None
    is_primary: bool | None = None


class ExampleTextRead(ExampleTextCreate):
    id: uuid.UUID


class ExpressionCreate(BaseModel):
    text: str
    expression_type_id: uuid.UUID
    region_id: uuid.UUID | None = None
    workflow: str = "draft"


class ExpressionUpdate(BaseModel):
    text: str | None = None
    expression_type_id: uuid.UUID | None = None
    region_id: uuid.UUID | None = None
    workflow: str | None = None


class ExpressionRead(ExpressionCreate):
    id: uuid.UUID
    normalized_text: str
    created_at: datetime
    updated_at: datetime


class ExpressionMeaningCreate(BaseModel):
    expression_id: uuid.UUID
    lang_code: str
    meaning: str
    usage_context: str | None = None
    is_primary: bool = False
    source_id: uuid.UUID | None = None


class ExpressionMeaningUpdate(BaseModel):
    meaning: str | None = None
    usage_context: str | None = None
    is_primary: bool | None = None
    source_id: uuid.UUID | None = None


class ExpressionMeaningRead(ExpressionMeaningCreate):
    id: uuid.UUID


class ExpressionExampleCreate(BaseModel):
    expression_id: uuid.UUID
    source_id: uuid.UUID | None = None


class ExpressionExampleUpdate(BaseModel):
    source_id: uuid.UUID | None = None


class ExpressionExampleRead(ExpressionExampleCreate):
    id: uuid.UUID
    created_at: datetime


class ExpressionExampleTextCreate(BaseModel):
    expression_example_id: uuid.UUID
    lang_code: str
    text: str
    is_primary: bool = False


class ExpressionExampleTextUpdate(BaseModel):
    text: str | None = None
    is_primary: bool | None = None


class ExpressionExampleTextRead(ExpressionExampleTextCreate):
    id: uuid.UUID


class ExpressionLinkCreate(BaseModel):
    expression_id: uuid.UUID
    lexeme_id: uuid.UUID | None = None
    sense_id: uuid.UUID | None = None
    note: str | None = None


class ExpressionLinkUpdate(BaseModel):
    lexeme_id: uuid.UUID | None = None
    sense_id: uuid.UUID | None = None
    note: str | None = None


class ExpressionLinkRead(ExpressionLinkCreate):
    id: uuid.UUID


class TagCreate(BaseModel):
    name: str
    tag_type_id: uuid.UUID
    description: str | None = None


class TagUpdate(BaseModel):
    name: str | None = None
    tag_type_id: uuid.UUID | None = None
    description: str | None = None


class TagRead(TagCreate):
    id: uuid.UUID


class LexemeTagCreate(BaseModel):
    lexeme_id: uuid.UUID
    tag_id: uuid.UUID
    confidence: int = Field(default=100, ge=0, le=100)
    start_year: int | None = None
    end_year: int | None = None


class LexemeTagUpdate(BaseModel):
    confidence: int | None = Field(default=None, ge=0, le=100)
    start_year: int | None = None
    end_year: int | None = None


class LexemeTagRead(LexemeTagCreate):
    pass


class SenseTagCreate(BaseModel):
    sense_id: uuid.UUID
    tag_id: uuid.UUID
    confidence: int = Field(default=100, ge=0, le=100)
    start_year: int | None = None
    end_year: int | None = None


class SenseTagUpdate(BaseModel):
    confidence: int | None = Field(default=None, ge=0, le=100)
    start_year: int | None = None
    end_year: int | None = None


class SenseTagRead(SenseTagCreate):
    pass


class WordformCreate(BaseModel):
    lexeme_id: uuid.UUID
    form: str
    features: dict = Field(default_factory=dict)
    generated: bool = True


class WordformUpdate(BaseModel):
    form: str | None = None
    features: dict | None = None
    generated: bool | None = None


class WordformRead(WordformCreate):
    id: uuid.UUID
    normalized_form: str


class SearchResult(BaseModel):
    id: uuid.UUID
    target_type: str
    target_id: uuid.UUID
    lang_code: str
    text: str
    normalized: str
    popularity: int
    lexeme_id: uuid.UUID
    lemma: str
    pos_code: str | None = None
    match_kind: str | None = None  # "lemma" | "definition" | "example"


class WordOfDayPublic(BaseModel):
    date: date
    lexeme_id: uuid.UUID
    lemma: str
    definition: str
    lang_code: str


class ExampleTextPublic(BaseModel):
    id: uuid.UUID
    lang_code: str
    text: str
    is_primary: bool


class ExamplePublic(BaseModel):
    id: uuid.UUID
    is_attested: bool
    texts: list[ExampleTextPublic]


class SenseDefinitionPublic(BaseModel):
    id: uuid.UUID
    lang_code: str
    definition: str
    gloss: str | None
    is_primary: bool
    is_ai_generated: bool | None = None
    review_status: str | None = None


class SensePublic(BaseModel):
    id: uuid.UUID
    sense_number: int
    domain_id: uuid.UUID | None
    register_id: uuid.UUID | None
    usage_note: str | None
    definitions: list[SenseDefinitionPublic]
    examples: list[ExamplePublic]


class LexemePublic(BaseModel):
    id: uuid.UUID
    lemma: str
    pos_id: uuid.UUID
    status: str
    default_language_code: str
    senses: list[SensePublic]


class ReviewQueueItem(BaseModel):
    sense_definition_id: uuid.UUID
    sense_id: uuid.UUID
    lexeme_id: uuid.UUID
    lemma: str
    pos_code: str
    sw_definition_preview: str
    en_definition_preview: str | None
    created_at: datetime
    review_status: str | None
    is_ai_generated: bool
    morphology_like: bool


class ReviewDefinitionReference(BaseModel):
    id: uuid.UUID
    definition: str
    gloss: str | None
    source_id: uuid.UUID | None


class ReviewSourceInfo(BaseModel):
    id: uuid.UUID
    title: str
    author: str | None
    year: int | None
    source_type: str
    url: str | None


class ReviewDetail(BaseModel):
    sense_definition_id: uuid.UUID
    sense_id: uuid.UUID
    lexeme_id: uuid.UUID
    lemma: str
    pos_code: str
    sw_definition: str
    sw_gloss: str | None
    en_definitions: list[ReviewDefinitionReference]
    source: ReviewSourceInfo | None
    review_status: str | None
    is_ai_generated: bool
    created_at: datetime
    reviewed_by: str | None = None
    reviewed_at: datetime | None = None
    review_note: str | None = None


class ReviewApproveRequest(BaseModel):
    reviewer: str


class ReviewEditRequest(BaseModel):
    reviewer: str
    definition: str
    gloss: str | None = None


class ReviewRejectRequest(BaseModel):
    reviewer: str
    reason: str
    note: str | None = None


class ReviewBulkRequest(BaseModel):
    reviewer: str
    action: str
    ids: list[uuid.UUID]
    reason: str | None = None
    note: str | None = None


class ReviewActionResponse(BaseModel):
    sense_definition_id: uuid.UUID
    review_status: str
    reviewed_by: str
    reviewed_at: datetime


class ReviewBulkResponse(BaseModel):
    updated_count: int
    skipped_count: int


class ExpressionMeaningPublic(BaseModel):
    id: uuid.UUID
    lang_code: str
    meaning: str
    usage_context: str | None
    is_primary: bool


class ExpressionExampleTextPublic(BaseModel):
    id: uuid.UUID
    lang_code: str
    text: str
    is_primary: bool


class ExpressionExamplePublic(BaseModel):
    id: uuid.UUID
    texts: list[ExpressionExampleTextPublic]


class ExpressionPublic(BaseModel):
    id: uuid.UUID
    text: str
    expression_type_id: uuid.UUID
    region_id: uuid.UUID | None
    meanings: list[ExpressionMeaningPublic]
    examples: list[ExpressionExamplePublic]
