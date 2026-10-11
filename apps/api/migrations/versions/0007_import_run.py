"""track which import created which rows, so a bad batch can be undone

Revision ID: 0007_import_run
Revises: 0006_lookup_event
Create Date: 2026-10-11 00:00:00.000000

Growing the dictionary means importing in bulk, and importing in bulk means
sometimes discovering afterwards that a batch was wrong — a bad part-of-speech
mapping, a prompt that produced nonsense, a source that turned out to be
mislicensed.

`source_id` already records *where* a definition came from, but not *which
run* produced it. "Wiktionary" is not something you can undo; "the 12,000 rows
loaded on Tuesday from this file" is. Without that, recovery from a bad import
means restoring the whole database and losing every good edit made since.

So: a row per import, and a nullable `import_run_id` on each table an import
creates rows in (`lexeme`, `sense`, `sense_definition`). Nullable because
everything that already exists predates this, and because content created by
hand through the admin console belongs to no run.

`ON DELETE SET NULL` on the back-references: deleting the record of an import
should orphan its rows from that record, never delete the content. Removing
content is `revert_import.py`'s job, and it is deliberate about what it will
and will not touch.
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision = "0007_import_run"
down_revision = "0006_lookup_event"
branch_labels = None
depends_on = None

OWNED_TABLES = ("lexeme", "sense", "sense_definition")


def upgrade() -> None:
    op.create_table(
        "import_run",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()"),
        ),
        # What kind of import: "wiktionary", "ai_definitions", "demo", ...
        sa.Column("kind", sa.Text(), nullable=False),
        # Which script, so a run can be traced back to the code that made it.
        sa.Column("tool", sa.Text(), nullable=False),
        sa.Column("input_path", sa.Text()),
        sa.Column(
            "source_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("source.id", ondelete="SET NULL"),
        ),
        sa.Column(
            "status", sa.Text(), nullable=False, server_default="running"
        ),
        sa.Column(
            "started_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("now()"),
        ),
        sa.Column("finished_at", sa.DateTime(timezone=True)),
        sa.Column("lexemes_created", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("senses_created", sa.Integer(), nullable=False, server_default="0"),
        sa.Column(
            "definitions_created", sa.Integer(), nullable=False, server_default="0"
        ),
        # The settings the run was invoked with, so it can be reproduced or
        # explained months later without reading shell history.
        sa.Column(
            "parameters",
            postgresql.JSONB(),
            nullable=False,
            server_default=sa.text("'{}'::jsonb"),
        ),
        sa.Column("notes", sa.Text()),
        sa.CheckConstraint(
            "status IN ('running', 'completed', 'failed', 'reverted')",
            name="ck_import_run_status",
        ),
    )
    op.create_index("ix_import_run_started_at", "import_run", ["started_at"])

    for table in OWNED_TABLES:
        op.add_column(
            table,
            sa.Column(
                "import_run_id",
                postgresql.UUID(as_uuid=True),
                sa.ForeignKey("import_run.id", ondelete="SET NULL"),
                nullable=True,
            ),
        )
        # Reverting selects every row of one run; nothing else reads this.
        op.create_index(
            f"ix_{table}_import_run",
            table,
            ["import_run_id"],
            postgresql_where=sa.text("import_run_id IS NOT NULL"),
        )


def downgrade() -> None:
    for table in OWNED_TABLES:
        op.drop_index(f"ix_{table}_import_run", table_name=table)
        op.drop_column(table, "import_run_id")
    op.drop_index("ix_import_run_started_at", table_name="import_run")
    op.drop_table("import_run")
