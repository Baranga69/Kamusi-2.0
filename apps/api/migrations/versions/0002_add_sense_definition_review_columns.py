"""add sense definition review columns

Revision ID: 0002_add_sense_definition_review_columns
Revises: 0001_create_schema
Create Date: 2024-09-18 00:00:00.000000
"""

from alembic import op
import sqlalchemy as sa

revision = "0002_add_sense_definition_review_columns"
down_revision = "0001_create_schema"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "sense_definition",
        sa.Column("is_ai_generated", sa.Boolean(), nullable=False, server_default=sa.text("false")),
    )
    op.add_column("sense_definition", sa.Column("review_status", sa.Text(), server_default="unreviewed"))
    op.add_column("sense_definition", sa.Column("reviewed_by", sa.Text()))
    op.add_column("sense_definition", sa.Column("reviewed_at", sa.DateTime(timezone=True)))
    op.add_column("sense_definition", sa.Column("ai_model", sa.Text()))
    op.add_column("sense_definition", sa.Column("ai_prompt_version", sa.Text()))
    op.add_column("sense_definition", sa.Column("review_note", sa.Text()))

    op.create_index(
        "ix_sense_definition_ai_sw_unreviewed",
        "sense_definition",
        ["created_at"],
        postgresql_where=sa.text(
            "lang_code = 'sw' AND is_ai_generated = true AND review_status = 'unreviewed'"
        ),
    )

    op.alter_column("sense_definition", "is_ai_generated", server_default=None)
    op.alter_column("sense_definition", "review_status", server_default=None)


def downgrade() -> None:
    op.drop_index("ix_sense_definition_ai_sw_unreviewed", table_name="sense_definition")
    op.drop_column("sense_definition", "review_note")
    op.drop_column("sense_definition", "ai_prompt_version")
    op.drop_column("sense_definition", "ai_model")
    op.drop_column("sense_definition", "reviewed_at")
    op.drop_column("sense_definition", "reviewed_by")
    op.drop_column("sense_definition", "review_status")
    op.drop_column("sense_definition", "is_ai_generated")
