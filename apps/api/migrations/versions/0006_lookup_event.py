"""record which entries people open, to drive search popularity

Revision ID: 0006_lookup_event
Revises: 0005_ai_confidence
Create Date: 2026-10-11 00:00:00.000000

`search_entry.popularity` has been part of the result ordering since the
schema was written and nothing ever set it, so it was always 0 and ranking was
purely match shape. A dictionary knows something useful that no corpus does:
which words people actually look up.

This is an append-only log of entry opens, aggregated into `popularity` by
`tools/maintenance/aggregate_popularity.py`. A log rather than incrementing
`search_entry` directly: counting in place puts every reader in contention for
the same row, and keeping the events lets the window be recomputed, decayed or
reinterpreted later without having lost the raw signal.

Deliberately anonymous. No IP address, no user agent, no account — just what
was opened, in which language, and when. The useful question is "which words
do Swahili speakers look up", which needs none of that, and collecting it
would create an obligation this project has no reason to take on.
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision = "0006_lookup_event"
down_revision = "0005_ai_confidence"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "lookup_event",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()"),
        ),
        # Mirrors search_entry's addressing: "lexeme" or "expression".
        sa.Column("target_type", sa.Text(), nullable=False),
        sa.Column("target_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("lang_code", sa.Text(), nullable=False),
        sa.Column(
            "occurred_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("now()"),
        ),
        # No foreign key on purpose: an event is a historical fact, and
        # deleting a lexeme should not rewrite the record of it having been
        # looked up. The aggregator joins and ignores what no longer resolves.
    )

    # The aggregator counts a recent window grouped by target.
    op.create_index(
        "ix_lookup_event_target_time",
        "lookup_event",
        ["target_type", "target_id", "occurred_at"],
    )
    # Pruning old events scans by date alone.
    op.create_index("ix_lookup_event_occurred_at", "lookup_event", ["occurred_at"])


def downgrade() -> None:
    op.drop_index("ix_lookup_event_occurred_at", table_name="lookup_event")
    op.drop_index("ix_lookup_event_target_time", table_name="lookup_event")
    op.drop_table("lookup_event")
