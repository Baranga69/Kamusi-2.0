"""create schema

Revision ID: 0001_create_schema
Revises: 
Create Date: 2024-03-19 00:00:00.000000
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision = "0001_create_schema"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute("CREATE EXTENSION IF NOT EXISTS pgcrypto")

    op.execute(
        """
        DO $$ BEGIN
          CREATE TYPE workflow_status AS ENUM ('draft', 'reviewed', 'published', 'archived');
        EXCEPTION WHEN duplicate_object THEN NULL; END $$;
        """
    )
    op.execute(
        """
        DO $$ BEGIN
          CREATE TYPE lexeme_status AS ENUM ('core', 'slang', 'regional', 'deprecated', 'neologism');
        EXCEPTION WHEN duplicate_object THEN NULL; END $$;
        """
    )
    op.execute(
        """
        DO $$ BEGIN
          CREATE TYPE relation_type AS ENUM ('spelling', 'regional', 'slang_equivalent', 'synonym', 'antonym', 'derived', 'related');
        EXCEPTION WHEN duplicate_object THEN NULL; END $$;
        """
    )
    op.execute(
        """
        DO $$ BEGIN
          CREATE TYPE sense_relation_type AS ENUM ('synonym', 'antonym', 'broader', 'narrower', 'related');
        EXCEPTION WHEN duplicate_object THEN NULL; END $$;
        """
    )
    op.execute(
        """
        DO $$ BEGIN
          CREATE TYPE ai_target_type AS ENUM ('lexeme', 'sense', 'expression');
        EXCEPTION WHEN duplicate_object THEN NULL; END $$;
        """
    )
    op.execute(
        """
        DO $$ BEGIN
          CREATE TYPE ai_mode AS ENUM ('simple', 'business', 'youth', 'polite_check', 'examples', 'usage_notes');
        EXCEPTION WHEN duplicate_object THEN NULL; END $$;
        """
    )

    workflow_status = postgresql.ENUM(
        "draft",
        "reviewed",
        "published",
        "archived",
        name="workflow_status",
        create_type=False,
    )
    lexeme_status = postgresql.ENUM(
        "core",
        "slang",
        "regional",
        "deprecated",
        "neologism",
        name="lexeme_status",
        create_type=False,
    )
    relation_type = postgresql.ENUM(
        "spelling",
        "regional",
        "slang_equivalent",
        "synonym",
        "antonym",
        "derived",
        "related",
        name="relation_type",
        create_type=False,
    )
    sense_relation_type = postgresql.ENUM(
        "synonym",
        "antonym",
        "broader",
        "narrower",
        "related",
        name="sense_relation_type",
        create_type=False,
    )
    ai_target_type = postgresql.ENUM(
        "lexeme",
        "sense",
        "expression",
        name="ai_target_type",
        create_type=False,
    )
    ai_mode = postgresql.ENUM(
        "simple",
        "business",
        "youth",
        "polite_check",
        "examples",
        "usage_notes",
        name="ai_mode",
        create_type=False,
    )

    op.create_table(
        "language",
        sa.Column("code", sa.Text(), primary_key=True),
        sa.Column("name", sa.Text(), nullable=False),
    )

    op.create_table(
        "part_of_speech",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("code", sa.Text(), nullable=False, unique=True),
        sa.Column("label", sa.Text(), nullable=False),
    )

    op.create_table(
        "register",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("code", sa.Text(), nullable=False, unique=True),
        sa.Column("label", sa.Text(), nullable=False),
    )

    op.create_table(
        "domain",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("code", sa.Text(), nullable=False, unique=True),
        sa.Column("label", sa.Text(), nullable=False),
    )

    op.create_table(
        "region",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("code", sa.Text(), nullable=False, unique=True),
        sa.Column("label", sa.Text(), nullable=False),
    )

    op.create_table(
        "expression_type",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("code", sa.Text(), nullable=False, unique=True),
        sa.Column("label", sa.Text(), nullable=False),
    )

    op.create_table(
        "tag_type",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("code", sa.Text(), nullable=False, unique=True),
        sa.Column("label", sa.Text(), nullable=False),
    )

    op.create_table(
        "license",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("name", sa.Text(), nullable=False, unique=True),
        sa.Column("summary", sa.Text()),
        sa.Column("can_display", sa.Boolean(), nullable=False, server_default=sa.text("true")),
        sa.Column("can_modify", sa.Boolean(), nullable=False, server_default=sa.text("false")),
        sa.Column("can_commercialize", sa.Boolean(), nullable=False, server_default=sa.text("false")),
    )

    op.create_table(
        "source",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("title", sa.Text(), nullable=False),
        sa.Column("author", sa.Text()),
        sa.Column("publisher", sa.Text()),
        sa.Column("year", sa.Integer()),
        sa.Column("source_type", sa.Text(), nullable=False),
        sa.Column("license_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("license.id"), nullable=False),
        sa.Column("url", sa.Text()),
        sa.Column("notes", sa.Text()),
    )

    op.create_table(
        "lexeme",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("lemma", sa.Text(), nullable=False),
        sa.Column("normalized_lemma", sa.Text(), nullable=False),
        sa.Column("pos_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("part_of_speech.id"), nullable=False),
        sa.Column("status", lexeme_status, nullable=False, server_default="core"),
        sa.Column(
            "default_language_code",
            sa.Text(),
            sa.ForeignKey("language.code"),
            nullable=False,
            server_default="sw",
        ),
        sa.Column("workflow", workflow_status, nullable=False, server_default="draft"),
        sa.Column("created_at", sa.TIMESTAMP(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.Column("updated_at", sa.TIMESTAMP(timezone=True), nullable=False, server_default=sa.text("now()")),
    )
    op.create_index("ux_lexeme_norm_pos", "lexeme", ["normalized_lemma", "pos_id"], unique=True)
    op.create_index("ix_lexeme_norm", "lexeme", ["normalized_lemma"], unique=False)

    op.create_table(
        "sense",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("lexeme_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("lexeme.id", ondelete="CASCADE"), nullable=False),
        sa.Column("sense_number", sa.Integer(), nullable=False),
        sa.Column("domain_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("domain.id")),
        sa.Column("register_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("register.id")),
        sa.Column("usage_note", sa.Text()),
        sa.Column("workflow", workflow_status, nullable=False, server_default="draft"),
        sa.Column("created_at", sa.TIMESTAMP(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.Column("updated_at", sa.TIMESTAMP(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.UniqueConstraint("lexeme_id", "sense_number"),
    )

    op.create_table(
        "sense_definition",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("sense_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("sense.id", ondelete="CASCADE"), nullable=False),
        sa.Column("lang_code", sa.Text(), sa.ForeignKey("language.code"), nullable=False),
        sa.Column("definition", sa.Text(), nullable=False),
        sa.Column("gloss", sa.Text()),
        sa.Column("is_primary", sa.Boolean(), nullable=False, server_default=sa.text("false")),
        sa.Column("source_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("source.id")),
        sa.Column("created_at", sa.TIMESTAMP(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.UniqueConstraint("sense_id", "lang_code"),
    )
    op.create_index("ix_sense_definition_sense", "sense_definition", ["sense_id"], unique=False)

    op.create_table(
        "example",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("sense_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("sense.id", ondelete="CASCADE"), nullable=False),
        sa.Column("is_attested", sa.Boolean(), nullable=False, server_default=sa.text("true")),
        sa.Column("source_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("source.id")),
        sa.Column("created_at", sa.TIMESTAMP(timezone=True), nullable=False, server_default=sa.text("now()")),
    )
    op.create_index("ix_example_sense", "example", ["sense_id"], unique=False)

    op.create_table(
        "example_text",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("example_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("example.id", ondelete="CASCADE"), nullable=False),
        sa.Column("lang_code", sa.Text(), sa.ForeignKey("language.code"), nullable=False),
        sa.Column("text", sa.Text(), nullable=False),
        sa.Column("is_primary", sa.Boolean(), nullable=False, server_default=sa.text("false")),
        sa.UniqueConstraint("example_id", "lang_code"),
    )
    op.create_index("ix_example_text_example", "example_text", ["example_id"], unique=False)

    op.create_table(
        "pronunciation",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("lexeme_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("lexeme.id", ondelete="CASCADE"), nullable=False),
        sa.Column("ipa", sa.Text()),
        sa.Column("syllabification", sa.Text()),
        sa.Column("audio_url", sa.Text()),
        sa.Column("region_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("region.id")),
        sa.Column("created_at", sa.TIMESTAMP(timezone=True), nullable=False, server_default=sa.text("now()")),
    )
    op.create_index("ix_pron_lexeme", "pronunciation", ["lexeme_id"], unique=False)

    op.create_table(
        "morph_profile",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("lexeme_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("lexeme.id", ondelete="CASCADE"), nullable=False, unique=True),
        sa.Column("noun_class", sa.Text()),
        sa.Column("plural_form", sa.Text()),
        sa.Column("verb_root", sa.Text()),
        sa.Column("extensions", postgresql.JSONB()),
        sa.Column("inflection_ruleset", sa.Text()),
        sa.Column("created_at", sa.TIMESTAMP(timezone=True), nullable=False, server_default=sa.text("now()")),
    )

    op.create_table(
        "wordform",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("lexeme_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("lexeme.id", ondelete="CASCADE"), nullable=False),
        sa.Column("form", sa.Text(), nullable=False),
        sa.Column("normalized_form", sa.Text(), nullable=False),
        sa.Column("features", postgresql.JSONB(), nullable=False, server_default=sa.text("'{}'::jsonb")),
        sa.Column("generated", sa.Boolean(), nullable=False, server_default=sa.text("true")),
    )
    op.create_index("ix_wordform_norm", "wordform", ["normalized_form"], unique=False)
    op.create_index("ix_wordform_lexeme", "wordform", ["lexeme_id"], unique=False)

    op.create_table(
        "tag",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("name", sa.Text(), nullable=False, unique=True),
        sa.Column("tag_type_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("tag_type.id"), nullable=False),
        sa.Column("description", sa.Text()),
    )

    op.create_table(
        "lexeme_tag",
        sa.Column("lexeme_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("lexeme.id", ondelete="CASCADE"), primary_key=True),
        sa.Column("tag_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("tag.id", ondelete="CASCADE"), primary_key=True),
        sa.Column("confidence", sa.SmallInteger(), nullable=False, server_default=sa.text("100")),
        sa.Column("start_year", sa.Integer()),
        sa.Column("end_year", sa.Integer()),
        sa.CheckConstraint("confidence BETWEEN 0 AND 100"),
    )

    op.create_table(
        "sense_tag",
        sa.Column("sense_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("sense.id", ondelete="CASCADE"), primary_key=True),
        sa.Column("tag_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("tag.id", ondelete="CASCADE"), primary_key=True),
        sa.Column("confidence", sa.SmallInteger(), nullable=False, server_default=sa.text("100")),
        sa.Column("start_year", sa.Integer()),
        sa.Column("end_year", sa.Integer()),
        sa.CheckConstraint("confidence BETWEEN 0 AND 100"),
    )

    op.create_table(
        "lexeme_relation",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("from_lexeme_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("lexeme.id", ondelete="CASCADE"), nullable=False),
        sa.Column("to_lexeme_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("lexeme.id", ondelete="CASCADE"), nullable=False),
        sa.Column("type", relation_type, nullable=False, server_default="related"),
        sa.Column("note", sa.Text()),
        sa.UniqueConstraint("from_lexeme_id", "to_lexeme_id", "type"),
    )

    op.create_table(
        "sense_relation",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("from_sense_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("sense.id", ondelete="CASCADE"), nullable=False),
        sa.Column("to_sense_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("sense.id", ondelete="CASCADE"), nullable=False),
        sa.Column("type", sense_relation_type, nullable=False, server_default="related"),
        sa.Column("weight", sa.Float(), nullable=False, server_default=sa.text("1.0")),
        sa.UniqueConstraint("from_sense_id", "to_sense_id", "type"),
    )

    op.create_table(
        "expression",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("text", sa.Text(), nullable=False),
        sa.Column("normalized_text", sa.Text(), nullable=False),
        sa.Column("expression_type_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("expression_type.id"), nullable=False),
        sa.Column("region_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("region.id")),
        sa.Column("workflow", workflow_status, nullable=False, server_default="draft"),
        sa.Column("created_at", sa.TIMESTAMP(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.Column("updated_at", sa.TIMESTAMP(timezone=True), nullable=False, server_default=sa.text("now()")),
    )
    op.create_index("ix_expression_norm", "expression", ["normalized_text"], unique=False)

    op.create_table(
        "expression_meaning",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("expression_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("expression.id", ondelete="CASCADE"), nullable=False),
        sa.Column("lang_code", sa.Text(), sa.ForeignKey("language.code"), nullable=False),
        sa.Column("meaning", sa.Text(), nullable=False),
        sa.Column("usage_context", sa.Text()),
        sa.Column("is_primary", sa.Boolean(), nullable=False, server_default=sa.text("false")),
        sa.Column("source_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("source.id")),
        sa.UniqueConstraint("expression_id", "lang_code"),
    )

    op.create_table(
        "expression_example",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("expression_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("expression.id", ondelete="CASCADE"), nullable=False),
        sa.Column("source_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("source.id")),
        sa.Column("created_at", sa.TIMESTAMP(timezone=True), nullable=False, server_default=sa.text("now()")),
    )

    op.create_table(
        "expression_example_text",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("expression_example_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("expression_example.id", ondelete="CASCADE"), nullable=False),
        sa.Column("lang_code", sa.Text(), sa.ForeignKey("language.code"), nullable=False),
        sa.Column("text", sa.Text(), nullable=False),
        sa.Column("is_primary", sa.Boolean(), nullable=False, server_default=sa.text("false")),
        sa.UniqueConstraint("expression_example_id", "lang_code"),
    )

    op.create_table(
        "expression_link",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("expression_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("expression.id", ondelete="CASCADE"), nullable=False),
        sa.Column("lexeme_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("lexeme.id", ondelete="CASCADE")),
        sa.Column("sense_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("sense.id", ondelete="CASCADE")),
        sa.Column("note", sa.Text()),
        sa.CheckConstraint(
            "(lexeme_id IS NOT NULL AND sense_id IS NULL) OR (lexeme_id IS NULL AND sense_id IS NOT NULL)",
            name="expression_link_check",
        ),
    )

    op.create_table(
        "ai_explanation",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("target_type", ai_target_type, nullable=False),
        sa.Column("target_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("mode", ai_mode, nullable=False),
        sa.Column("lang_code", sa.Text(), sa.ForeignKey("language.code"), nullable=False),
        sa.Column("text", sa.Text(), nullable=False),
        sa.Column("model_version", sa.Text(), nullable=False),
        sa.Column("prompt_version", sa.Text(), nullable=False),
        sa.Column("created_at", sa.TIMESTAMP(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.UniqueConstraint(
            "target_type",
            "target_id",
            "mode",
            "lang_code",
            "model_version",
            "prompt_version",
        ),
    )
    op.create_index("ix_ai_expl_target", "ai_explanation", ["target_type", "target_id"], unique=False)

    op.create_table(
        "search_entry",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("target_type", sa.Text(), nullable=False),
        sa.Column("target_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("lang_code", sa.Text(), sa.ForeignKey("language.code"), nullable=False),
        sa.Column("text", sa.Text(), nullable=False),
        sa.Column("normalized", sa.Text(), nullable=False),
        sa.Column("popularity", sa.Integer(), nullable=False, server_default=sa.text("0")),
        sa.Column("created_at", sa.TIMESTAMP(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.Column("updated_at", sa.TIMESTAMP(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.UniqueConstraint("target_type", "target_id", "lang_code"),
    )
    op.create_index("ix_search_entry_norm", "search_entry", ["normalized"], unique=False)


def downgrade() -> None:
    op.drop_index("ix_search_entry_norm", table_name="search_entry")
    op.drop_table("search_entry")
    op.drop_index("ix_ai_expl_target", table_name="ai_explanation")
    op.drop_table("ai_explanation")
    op.drop_table("expression_link")
    op.drop_table("expression_example_text")
    op.drop_table("expression_example")
    op.drop_table("expression_meaning")
    op.drop_index("ix_expression_norm", table_name="expression")
    op.drop_table("expression")
    op.drop_table("sense_relation")
    op.drop_table("lexeme_relation")
    op.drop_table("sense_tag")
    op.drop_table("lexeme_tag")
    op.drop_table("tag")
    op.drop_index("ix_wordform_lexeme", table_name="wordform")
    op.drop_index("ix_wordform_norm", table_name="wordform")
    op.drop_table("wordform")
    op.drop_table("morph_profile")
    op.drop_index("ix_pron_lexeme", table_name="pronunciation")
    op.drop_table("pronunciation")
    op.drop_index("ix_example_text_example", table_name="example_text")
    op.drop_table("example_text")
    op.drop_index("ix_example_sense", table_name="example")
    op.drop_table("example")
    op.drop_index("ix_sense_definition_sense", table_name="sense_definition")
    op.drop_table("sense_definition")
    op.drop_table("sense")
    op.drop_index("ix_lexeme_norm", table_name="lexeme")
    op.drop_index("ux_lexeme_norm_pos", table_name="lexeme")
    op.drop_table("lexeme")
    op.drop_table("source")
    op.drop_table("license")
    op.drop_table("tag_type")
    op.drop_table("expression_type")
    op.drop_table("region")
    op.drop_table("domain")
    op.drop_table("register")
    op.drop_table("part_of_speech")
    op.drop_table("language")

    op.execute("DROP TYPE IF EXISTS ai_mode")
    op.execute("DROP TYPE IF EXISTS ai_target_type")
    op.execute("DROP TYPE IF EXISTS sense_relation_type")
    op.execute("DROP TYPE IF EXISTS relation_type")
    op.execute("DROP TYPE IF EXISTS lexeme_status")
    op.execute("DROP TYPE IF EXISTS workflow_status")
