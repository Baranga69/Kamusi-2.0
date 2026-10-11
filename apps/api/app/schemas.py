import uuid
from datetime import date, datetime

from pydantic import BaseModel, Field

# A field called `date` with a default shadows the `date` type for annotations
# in that class body, so the type needs a second name.
DateOnly = date


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
    """One search hit, resolved back to the entry a reader can open.

    A hit resolves to either a lexeme or an expression, never both. The
    lexeme fields stay populated for every hit that previously existed
    (`lemma`, `definition`, `example`); they are null only on the expression
    hits, which `/search` could not return at all before.
    """

    id: uuid.UUID
    target_type: str
    target_id: uuid.UUID
    lang_code: str
    text: str
    normalized: str
    popularity: int

    # Populated when the hit resolves to a lexeme.
    lexeme_id: uuid.UUID | None = None
    lemma: str | None = None
    pos_code: str | None = None

    # Populated when the hit resolves to an expression (methali, semi, nahau).
    expression_id: uuid.UUID | None = None
    expression_text: str | None = None

    # "lemma" | "definition" | "example" | "expression" | "meaning"
    match_kind: str | None = None

    # True when the hit came from the trigram "did you mean" pass rather than
    # a literal match, so a client can present it differently.
    is_fuzzy: bool = False


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
    # How sure the model was, 0.0-1.0, or null for rows written before this was
    # captured. Null means "unknown", which is not the same as "poor".
    ai_confidence: float | None = None
    # What the ingest gate would object to, from app/core/quality.py. Empty
    # for a clean definition. Rows imported before the gate existed were never
    # checked, so this is how a reviewer finds the suspect ones; it is advice,
    # not a verdict, and nothing is hidden on account of it.
    quality_flags: list[str] = []


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


# None of these carry a `reviewer`. Who acted is read from the session and
# recorded server-side, so accepting it here would be at best redundant and at
# worst a way to forge an audit trail. Pydantic ignores unknown fields, so a
# client still sending one keeps working — the value is simply not used.


class ReviewApproveRequest(BaseModel):
    pass


class ReviewEditRequest(BaseModel):
    definition: str
    gloss: str | None = None


class ReviewRejectRequest(BaseModel):
    reason: str
    note: str | None = None


class ReviewBulkRequest(BaseModel):
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


class LexemeListItem(BaseModel):
    """Flat projection for the admin lexeme browser.

    Deliberately not the full nested aggregate: the list view only needs enough
    to render a row and link to the editor.
    """

    id: uuid.UUID
    lemma: str
    normalized_lemma: str
    pos_id: uuid.UUID
    pos_code: str | None = None
    status: str
    workflow: str
    default_language_code: str
    sense_count: int
    sw_definition_count: int
    created_at: datetime
    updated_at: datetime


class ExpressionListItem(BaseModel):
    id: uuid.UUID
    text: str
    normalized_text: str
    expression_type_id: uuid.UUID
    expression_type_code: str | None = None
    region_id: uuid.UUID | None = None
    workflow: str
    meaning_count: int
    created_at: datetime
    updated_at: datetime


class LookupOption(BaseModel):
    id: uuid.UUID
    code: str
    label: str


class LookupBundle(BaseModel):
    """Every seeded vocabulary the admin UI needs to populate its selects."""

    languages: list[LanguageRead]
    parts_of_speech: list[LookupOption]
    registers: list[LookupOption]
    domains: list[LookupOption]
    regions: list[LookupOption]
    expression_types: list[LookupOption]
    tag_types: list[LookupOption]


# --- accounts -------------------------------------------------------------


class LoginRequest(BaseModel):
    email: str
    password: str


class UserPublic(BaseModel):
    id: uuid.UUID
    email: str
    display_name: str
    role: str
    is_active: bool
    created_at: datetime
    last_login_at: datetime | None = None


class LoginResponse(BaseModel):
    """A session token plus who it belongs to.

    The token goes in `Authorization: Bearer`. The admin console keeps it in
    an httpOnly cookie on its own origin so it never reaches page scripts.
    """

    token: str
    expires_in_seconds: int
    user: UserPublic


class UserCreate(BaseModel):
    email: str
    display_name: str
    password: str
    role: str = "reviewer"


class UserUpdate(BaseModel):
    display_name: str | None = None
    role: str | None = None
    is_active: bool | None = None


class PasswordChange(BaseModel):
    current_password: str
    new_password: str


class PasswordReset(BaseModel):
    """An admin setting another account's password."""

    new_password: str


# --- learning rounds ------------------------------------------------------


class LearnQuestion(BaseModel):
    """One question in a round.

    `answer_index` is sent to the client on purpose. Nothing is at stake here —
    no score is submitted back, no leaderboard — and a round has to be fully
    playable offline from the cache, which rules out asking the server to mark
    it. Keeping it client-side also means instant feedback, which matters more
    for learning than it would for a test.
    """

    kind: str  # "definition" | "meaning" | "methali"
    prompt: str
    prompt_detail: str | None = None
    options: list[str]
    answer_index: int

    # Where to send a reader who wants the full entry afterwards. This is the
    # point of the games: they end in the dictionary.
    lexeme_id: uuid.UUID | None = None
    expression_id: uuid.UUID | None = None


class WordFindWord(BaseModel):
    """One word hidden in the grid, with the meaning to show once it is found.

    `cells` is the solution, and it is sent to the client for the same reason
    `LearnQuestion.answer_index` is: nothing is at stake, the puzzle has to be
    playable from the cache with no connection, and checking a drag locally is
    instant where a round trip per attempt would not be.
    """

    lexeme_id: uuid.UUID
    # The headword as it should be displayed, accents and capitals intact.
    word: str
    # The same word reduced to the letters that appear in the grid.
    letters: str
    definition: str
    pos_code: str | None = None
    # [[row, col], ...] in reading order, so the client can highlight the path.
    cells: list[list[int]]


class WordFindPuzzle(BaseModel):
    """A word-search grid built from published, reviewed vocabulary."""

    lang_code: str
    size: int
    # One string per row, `size` letters long. A list of strings rather than a
    # list of lists: it is a third of the JSON and trivial to index.
    rows: list[str]
    words: list[WordFindWord]


class WordBuildWord(BaseModel):
    """One word that can be spelled from the puzzle's letters."""

    lexeme_id: uuid.UUID
    word: str
    letters: str
    definition: str
    pos_code: str | None = None
    # True for the word that uses every letter in the ring. There is always
    # exactly one, and it is what makes the set of letters solvable rather
    # than arbitrary.
    is_pangram: bool = False


class WordBuildPuzzle(BaseModel):
    """A ring of letters and every published word they spell.

    The whole solution set is sent, as with the other rounds: nothing is at
    stake, and the puzzle has to be playable from the cache with no
    connection. It is also what lets the client offer definitions as hints in
    an easy mode without asking the server mid-game.
    """

    lang_code: str
    # The ring, already shuffled. One character each.
    letters: list[str]
    words: list[WordBuildWord]


class LearnRound(BaseModel):
    kind: str
    lang_code: str
    questions: list[LearnQuestion]

    # Set on the daily round: the UTC date it belongs to, so a client can tell
    # a cached round apart from today's.
    date: DateOnly | None = None
