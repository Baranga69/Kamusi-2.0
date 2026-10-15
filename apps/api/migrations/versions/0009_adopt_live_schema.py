"""adopt schema that existed in the database but not in the migrations

Revision ID: 0009_adopt_live_schema
Revises: 0008_import_progress
Create Date: 2026-10-11 00:00:00.000000

The running database had been patched by hand. Four things existed there that
no migration created, so `alembic upgrade head` on a fresh machine produced a
*different* database from the one actually serving — which is the bug class
that bites hardest exactly when you start loading data at volume.

Two of them held real content and would have been destroyed by rebuilding
from the migrations:

* `part_of_speech.label_sw` / `definition_sw` — all eleven parts of speech
  had hand-authored Swahili names and explanations ("Nomino", "Kivumishi").
  For a Swahili-first dictionary that is the part a reader should see, and it
  existed nowhere in version control.
* `sense.is_morphology` — set on 1,626 of 3,902 senses. That is a real
  classification of nearly half the corpus, and it is what a future
  "downgrade morphology-only entries" rule would be built on.

Two were empty, and are adopted as schema only:

* `morph_relation`, with its own `morph_relation_type` enum — derived-form
  links between lexemes.
* five morphology values appended to the shared `relation_type` enum.

Nullability note: the hand-made `label_sw` and `definition_sw` were NOT NULL.
They are added nullable here, because `seed.py` must be able to create the
lookup rows on a fresh database and not every part of speech will always have
a Swahili gloss ready. The content itself moves into `seed.py` in the same
change, so a new environment gets it too.

Adding to a Postgres enum cannot be undone, so the downgrade leaves
`relation_type` alone and says so rather than pretending.
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision = "0009_adopt_live_schema"
down_revision = "0008_import_progress"
branch_labels = None
depends_on = None

# Wiktionary's derived-verb relations, as the database already had them.
MORPH_RELATION_VALUES = (
    "APPLICATIVE_OF",
    "RECIPROCAL_OF",
    "STATIVE_OF",
    "CAUSATIVE_OF",
    "PASSIVE_OF",
)


def upgrade() -> None:
    # --- Swahili names for the parts of speech ---------------------------
    op.add_column("part_of_speech", sa.Column("label_sw", sa.Text()))
    op.add_column("part_of_speech", sa.Column("definition_sw", sa.Text()))

    # --- morphology flag on senses ---------------------------------------
    op.add_column(
        "sense",
        sa.Column(
            "is_morphology", sa.Boolean(), nullable=False, server_default=sa.false()
        ),
    )
    # Kept as a column default rather than dropped: rows are created by the
    # ingest tools and by hand in the admin console, and neither should have
    # to remember to say "not morphology".

    # --- derived-form links ----------------------------------------------
    morph_relation_type = postgresql.ENUM(
        *MORPH_RELATION_VALUES, name="morph_relation_type"
    )
    morph_relation_type.create(op.get_bind(), checkfirst=True)

    op.create_table(
        "morph_relation",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()"),
        ),
        sa.Column(
            "from_lexeme_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("lexeme.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "to_lexeme_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("lexeme.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "relation_type",
            postgresql.ENUM(
                *MORPH_RELATION_VALUES, name="morph_relation_type", create_type=False
            ),
            nullable=False,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("now()"),
        ),
        sa.UniqueConstraint(
            "from_lexeme_id",
            "to_lexeme_id",
            "relation_type",
            name="morph_relation_from_lexeme_id_to_lexeme_id_relation_type_key",
        ),
    )

    # --- the same values on the shared lexeme relation enum --------------
    # The live database had these appended. ADD VALUE cannot run inside a
    # transaction block on older Postgres, and IF NOT EXISTS makes re-running
    # harmless.
    for value in MORPH_RELATION_VALUES:
        op.execute(f"ALTER TYPE relation_type ADD VALUE IF NOT EXISTS '{value}'")


def downgrade() -> None:
    op.drop_table("morph_relation")
    postgresql.ENUM(name="morph_relation_type").drop(op.get_bind(), checkfirst=True)
    op.drop_column("sense", "is_morphology")
    op.drop_column("part_of_speech", "definition_sw")
    op.drop_column("part_of_speech", "label_sw")
    # `relation_type` keeps its added values: Postgres cannot remove an enum
    # value, and recreating the type would mean rewriting every column that
    # uses it. Harmless to leave — nothing requires them to be absent.
