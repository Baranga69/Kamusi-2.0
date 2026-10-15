"""store the model's confidence on an AI definition

Revision ID: 0005_ai_confidence
Revises: 0004_app_user
Create Date: 2026-10-11 00:00:00.000000

The generator already asks the model how sure it is and writes a `confidence`
to its JSONL, and the importer threw it away — there was nowhere to put it.

Keeping it lets the review queue lead with the definitions most likely to be
wrong. Reviewer attention is the scarcest thing in this project, and spending
it in a random order wastes it.

Nullable because the column is new and every existing row predates it; the
queue has to cope with not knowing, which is different from knowing a
definition is poor.

Keep the revision identifier under 32 characters — Alembic stores it in
alembic_version.version_num, a varchar(32), and a longer value makes the whole
upgrade fail and roll back.
"""

from alembic import op
import sqlalchemy as sa

revision = "0005_ai_confidence"
down_revision = "0004_app_user"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "sense_definition",
        sa.Column("ai_confidence", sa.Float(), nullable=True),
    )
    # The queue's worst-first ordering reads this for unreviewed AI Swahili
    # rows only, which is a small slice of the table.
    op.create_index(
        "ix_sense_definition_ai_confidence",
        "sense_definition",
        ["ai_confidence"],
        postgresql_where=sa.text(
            "lang_code = 'sw' AND is_ai_generated = true AND review_status = 'unreviewed'"
        ),
    )


def downgrade() -> None:
    op.drop_index("ix_sense_definition_ai_confidence", table_name="sense_definition")
    op.drop_column("sense_definition", "ai_confidence")
