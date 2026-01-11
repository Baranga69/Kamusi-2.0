import uuid
from datetime import datetime

from sqlalchemy import (
    Boolean,
    CheckConstraint,
    DateTime,
    Float,
    ForeignKey,
    Integer,
    JSON,
    String,
    Text,
    UniqueConstraint,
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.types import Enum as SqlEnum

from app.db import Base

workflow_status = SqlEnum(
    "draft",
    "reviewed",
    "published",
    "archived",
    name="workflow_status",
    native_enum=True,
    create_type=False,
)

lexeme_status = SqlEnum(
    "core",
    "slang",
    "regional",
    "deprecated",
    "neologism",
    name="lexeme_status",
    native_enum=True,
    create_type=False,
)

relation_type = SqlEnum(
    "spelling",
    "regional",
    "slang_equivalent",
    "synonym",
    "antonym",
    "derived",
    "related",
    name="relation_type",
    native_enum=True,
    create_type=False,
)

sense_relation_type = SqlEnum(
    "synonym",
    "antonym",
    "broader",
    "narrower",
    "related",
    name="sense_relation_type",
    native_enum=True,
    create_type=False,
)

ai_target_type = SqlEnum(
    "lexeme",
    "sense",
    "expression",
    name="ai_target_type",
    native_enum=True,
    create_type=False,
)

ai_mode = SqlEnum(
    "simple",
    "business",
    "youth",
    "polite_check",
    "examples",
    "usage_notes",
    name="ai_mode",
    native_enum=True,
    create_type=False,
)


class Language(Base):
    __tablename__ = "language"

    code: Mapped[str] = mapped_column(String, primary_key=True)
    name: Mapped[str] = mapped_column(String, nullable=False)


class PartOfSpeech(Base):
    __tablename__ = "part_of_speech"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    code: Mapped[str] = mapped_column(String, unique=True, nullable=False)
    label: Mapped[str] = mapped_column(String, nullable=False)


class Register(Base):
    __tablename__ = "register"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    code: Mapped[str] = mapped_column(String, unique=True, nullable=False)
    label: Mapped[str] = mapped_column(String, nullable=False)


class Domain(Base):
    __tablename__ = "domain"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    code: Mapped[str] = mapped_column(String, unique=True, nullable=False)
    label: Mapped[str] = mapped_column(String, nullable=False)


class Region(Base):
    __tablename__ = "region"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    code: Mapped[str] = mapped_column(String, unique=True, nullable=False)
    label: Mapped[str] = mapped_column(String, nullable=False)


class ExpressionType(Base):
    __tablename__ = "expression_type"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    code: Mapped[str] = mapped_column(String, unique=True, nullable=False)
    label: Mapped[str] = mapped_column(String, nullable=False)


class TagType(Base):
    __tablename__ = "tag_type"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    code: Mapped[str] = mapped_column(String, unique=True, nullable=False)
    label: Mapped[str] = mapped_column(String, nullable=False)


class License(Base):
    __tablename__ = "license"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name: Mapped[str] = mapped_column(String, unique=True, nullable=False)
    summary: Mapped[str | None] = mapped_column(Text)
    can_display: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    can_modify: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    can_commercialize: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)


class Source(Base):
    __tablename__ = "source"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    title: Mapped[str] = mapped_column(String, nullable=False)
    author: Mapped[str | None] = mapped_column(String)
    publisher: Mapped[str | None] = mapped_column(String)
    year: Mapped[int | None] = mapped_column(Integer)
    source_type: Mapped[str] = mapped_column(String, nullable=False)
    license_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("license.id"), nullable=False)
    url: Mapped[str | None] = mapped_column(String)
    notes: Mapped[str | None] = mapped_column(Text)


class Lexeme(Base):
    __tablename__ = "lexeme"
    __table_args__ = (UniqueConstraint("normalized_lemma", "pos_id", name="ux_lexeme_norm_pos"),)

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    lemma: Mapped[str] = mapped_column(String, nullable=False)
    normalized_lemma: Mapped[str] = mapped_column(String, nullable=False)
    pos_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("part_of_speech.id"), nullable=False)
    status: Mapped[str] = mapped_column(lexeme_status, nullable=False, default="core")
    default_language_code: Mapped[str] = mapped_column(String, ForeignKey("language.code"), nullable=False, default="sw")
    workflow: Mapped[str] = mapped_column(workflow_status, nullable=False, default="draft")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, default=datetime.utcnow)

    senses: Mapped[list["Sense"]] = relationship(back_populates="lexeme", cascade="all, delete-orphan")


class Sense(Base):
    __tablename__ = "sense"
    __table_args__ = (UniqueConstraint("lexeme_id", "sense_number", name="uq_sense_lexeme_number"),)

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    lexeme_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("lexeme.id", ondelete="CASCADE"), nullable=False)
    sense_number: Mapped[int] = mapped_column(Integer, nullable=False)
    domain_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), ForeignKey("domain.id"))
    register_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), ForeignKey("register.id"))
    usage_note: Mapped[str | None] = mapped_column(Text)
    workflow: Mapped[str] = mapped_column(workflow_status, nullable=False, default="draft")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, default=datetime.utcnow)

    lexeme: Mapped[Lexeme] = relationship(back_populates="senses")
    definitions: Mapped[list["SenseDefinition"]] = relationship(
        back_populates="sense", cascade="all, delete-orphan"
    )
    examples: Mapped[list["Example"]] = relationship(back_populates="sense", cascade="all, delete-orphan")


class SenseDefinition(Base):
    __tablename__ = "sense_definition"
    __table_args__ = (UniqueConstraint("sense_id", "lang_code", name="uq_sense_definition_lang"),)

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    sense_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("sense.id", ondelete="CASCADE"), nullable=False)
    lang_code: Mapped[str] = mapped_column(String, ForeignKey("language.code"), nullable=False)
    definition: Mapped[str] = mapped_column(Text, nullable=False)
    gloss: Mapped[str | None] = mapped_column(Text)
    is_primary: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    source_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), ForeignKey("source.id"))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, default=datetime.utcnow)
    is_ai_generated: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    review_status: Mapped[str | None] = mapped_column(String, default="unreviewed")
    reviewed_by: Mapped[str | None] = mapped_column(String)
    reviewed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    ai_model: Mapped[str | None] = mapped_column(String)
    ai_prompt_version: Mapped[str | None] = mapped_column(String)
    review_note: Mapped[str | None] = mapped_column(Text)

    sense: Mapped[Sense] = relationship(back_populates="definitions")


class Example(Base):
    __tablename__ = "example"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    sense_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("sense.id", ondelete="CASCADE"), nullable=False)
    is_attested: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    source_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), ForeignKey("source.id"))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, default=datetime.utcnow)

    sense: Mapped[Sense] = relationship(back_populates="examples")
    texts: Mapped[list["ExampleText"]] = relationship(back_populates="example", cascade="all, delete-orphan")


class ExampleText(Base):
    __tablename__ = "example_text"
    __table_args__ = (UniqueConstraint("example_id", "lang_code", name="uq_example_text_lang"),)

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    example_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("example.id", ondelete="CASCADE"), nullable=False)
    lang_code: Mapped[str] = mapped_column(String, ForeignKey("language.code"), nullable=False)
    text: Mapped[str] = mapped_column(Text, nullable=False)
    is_primary: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)

    example: Mapped[Example] = relationship(back_populates="texts")


class Pronunciation(Base):
    __tablename__ = "pronunciation"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    lexeme_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("lexeme.id", ondelete="CASCADE"), nullable=False)
    ipa: Mapped[str | None] = mapped_column(Text)
    syllabification: Mapped[str | None] = mapped_column(Text)
    audio_url: Mapped[str | None] = mapped_column(Text)
    region_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), ForeignKey("region.id"))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, default=datetime.utcnow)


class MorphProfile(Base):
    __tablename__ = "morph_profile"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    lexeme_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("lexeme.id", ondelete="CASCADE"), nullable=False, unique=True
    )
    noun_class: Mapped[str | None] = mapped_column(Text)
    plural_form: Mapped[str | None] = mapped_column(Text)
    verb_root: Mapped[str | None] = mapped_column(Text)
    extensions: Mapped[dict | None] = mapped_column(JSON)
    inflection_ruleset: Mapped[str | None] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, default=datetime.utcnow)


class Wordform(Base):
    __tablename__ = "wordform"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    lexeme_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("lexeme.id", ondelete="CASCADE"), nullable=False)
    form: Mapped[str] = mapped_column(String, nullable=False)
    normalized_form: Mapped[str] = mapped_column(String, nullable=False)
    features: Mapped[dict] = mapped_column(JSON, nullable=False, default=dict)
    generated: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)


class Tag(Base):
    __tablename__ = "tag"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name: Mapped[str] = mapped_column(String, unique=True, nullable=False)
    tag_type_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("tag_type.id"), nullable=False)
    description: Mapped[str | None] = mapped_column(Text)


class LexemeTag(Base):
    __tablename__ = "lexeme_tag"

    lexeme_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("lexeme.id", ondelete="CASCADE"), primary_key=True
    )
    tag_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("tag.id", ondelete="CASCADE"), primary_key=True)
    confidence: Mapped[int] = mapped_column(Integer, nullable=False, default=100)
    start_year: Mapped[int | None] = mapped_column(Integer)
    end_year: Mapped[int | None] = mapped_column(Integer)


class SenseTag(Base):
    __tablename__ = "sense_tag"

    sense_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("sense.id", ondelete="CASCADE"), primary_key=True
    )
    tag_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("tag.id", ondelete="CASCADE"), primary_key=True)
    confidence: Mapped[int] = mapped_column(Integer, nullable=False, default=100)
    start_year: Mapped[int | None] = mapped_column(Integer)
    end_year: Mapped[int | None] = mapped_column(Integer)


class LexemeRelation(Base):
    __tablename__ = "lexeme_relation"
    __table_args__ = (UniqueConstraint("from_lexeme_id", "to_lexeme_id", "type", name="uq_lexeme_relation"),)

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    from_lexeme_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("lexeme.id", ondelete="CASCADE"), nullable=False
    )
    to_lexeme_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("lexeme.id", ondelete="CASCADE"), nullable=False
    )
    type: Mapped[str] = mapped_column(relation_type, nullable=False, default="related")
    note: Mapped[str | None] = mapped_column(Text)


class SenseRelation(Base):
    __tablename__ = "sense_relation"
    __table_args__ = (UniqueConstraint("from_sense_id", "to_sense_id", "type", name="uq_sense_relation"),)

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    from_sense_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("sense.id", ondelete="CASCADE"), nullable=False)
    to_sense_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("sense.id", ondelete="CASCADE"), nullable=False)
    type: Mapped[str] = mapped_column(sense_relation_type, nullable=False, default="related")
    weight: Mapped[float] = mapped_column(Float, nullable=False, default=1.0)


class Expression(Base):
    __tablename__ = "expression"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    text: Mapped[str] = mapped_column(Text, nullable=False)
    normalized_text: Mapped[str] = mapped_column(Text, nullable=False)
    expression_type_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("expression_type.id"), nullable=False)
    region_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), ForeignKey("region.id"))
    workflow: Mapped[str] = mapped_column(workflow_status, nullable=False, default="draft")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, default=datetime.utcnow)

    meanings: Mapped[list["ExpressionMeaning"]] = relationship(
        back_populates="expression", cascade="all, delete-orphan"
    )
    examples: Mapped[list["ExpressionExample"]] = relationship(
        back_populates="expression", cascade="all, delete-orphan"
    )


class ExpressionMeaning(Base):
    __tablename__ = "expression_meaning"
    __table_args__ = (UniqueConstraint("expression_id", "lang_code", name="uq_expression_meaning_lang"),)

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    expression_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("expression.id", ondelete="CASCADE"), nullable=False
    )
    lang_code: Mapped[str] = mapped_column(String, ForeignKey("language.code"), nullable=False)
    meaning: Mapped[str] = mapped_column(Text, nullable=False)
    usage_context: Mapped[str | None] = mapped_column(Text)
    is_primary: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    source_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), ForeignKey("source.id"))

    expression: Mapped[Expression] = relationship(back_populates="meanings")


class ExpressionExample(Base):
    __tablename__ = "expression_example"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    expression_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("expression.id", ondelete="CASCADE"), nullable=False
    )
    source_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), ForeignKey("source.id"))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, default=datetime.utcnow)

    expression: Mapped[Expression] = relationship(back_populates="examples")
    texts: Mapped[list["ExpressionExampleText"]] = relationship(
        back_populates="example", cascade="all, delete-orphan"
    )


class ExpressionExampleText(Base):
    __tablename__ = "expression_example_text"
    __table_args__ = (UniqueConstraint("expression_example_id", "lang_code", name="uq_expression_example_text_lang"),)

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    expression_example_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("expression_example.id", ondelete="CASCADE"), nullable=False
    )
    lang_code: Mapped[str] = mapped_column(String, ForeignKey("language.code"), nullable=False)
    text: Mapped[str] = mapped_column(Text, nullable=False)
    is_primary: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)

    example: Mapped[ExpressionExample] = relationship(back_populates="texts")


class ExpressionLink(Base):
    __tablename__ = "expression_link"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    expression_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("expression.id", ondelete="CASCADE"), nullable=False
    )
    lexeme_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), ForeignKey("lexeme.id", ondelete="CASCADE"))
    sense_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), ForeignKey("sense.id", ondelete="CASCADE"))
    note: Mapped[str | None] = mapped_column(Text)

    __table_args__ = (
        CheckConstraint(
            "(lexeme_id IS NOT NULL AND sense_id IS NULL) OR (lexeme_id IS NULL AND sense_id IS NOT NULL)",
            name="ck_expression_link_target",
        ),
    )


class AiExplanation(Base):
    __tablename__ = "ai_explanation"
    __table_args__ = (
        UniqueConstraint(
            "target_type",
            "target_id",
            "mode",
            "lang_code",
            "model_version",
            "prompt_version",
            name="uq_ai_explanation",
        ),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    target_type: Mapped[str] = mapped_column(ai_target_type, nullable=False)
    target_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False)
    mode: Mapped[str] = mapped_column(ai_mode, nullable=False)
    lang_code: Mapped[str] = mapped_column(String, ForeignKey("language.code"), nullable=False)
    text: Mapped[str] = mapped_column(Text, nullable=False)
    model_version: Mapped[str] = mapped_column(String, nullable=False)
    prompt_version: Mapped[str] = mapped_column(String, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, default=datetime.utcnow)


class SearchEntry(Base):
    __tablename__ = "search_entry"
    __table_args__ = (UniqueConstraint("target_type", "target_id", "lang_code", name="uq_search_entry"),)

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    target_type: Mapped[str] = mapped_column(String, nullable=False)
    target_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False)
    lang_code: Mapped[str] = mapped_column(String, ForeignKey("language.code"), nullable=False)
    text: Mapped[str] = mapped_column(Text, nullable=False)
    normalized: Mapped[str] = mapped_column(Text, nullable=False)
    popularity: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, default=datetime.utcnow)
