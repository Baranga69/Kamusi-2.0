"""add pg_trgm trigram indexes for search

Revision ID: 0003_trigram_search
Revises: 0002_sense_def_review_cols
Create Date: 2026-10-10 00:00:00.000000

`/search` matches with ``normalized LIKE '%term%'``. A leading wildcard cannot
use a btree index, so ``ix_search_entry_norm`` was dead weight for the main
query and every search was a sequential scan over the whole index table. At
~3,800 lexemes that is invisible; it degrades linearly from there.

A GIN index with ``gin_trgm_ops`` can answer leading-wildcard LIKE directly,
so the planner gains an index path for the existing query with no change to
the SQL (at small row counts it will still prefer a scan, which is correct —
the index earns its place as the table grows). The same operator class is
what makes the ``%`` similarity operator indexable, which is how search
tolerates a misspelled lemma.

The btree index on ``normalized`` is kept: it still serves the exact-match
branch of the rank expression and any ordering by that column.

Keep the revision identifier under 32 characters — Alembic stores it in
alembic_version.version_num, a varchar(32), and a longer value makes the whole
upgrade fail and roll back.
"""

from alembic import op

revision = "0003_trigram_search"
down_revision = "0002_sense_def_review_cols"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Requires privileges to create an extension. On a managed instance where
    # the app role cannot, a superuser runs this once and the rest applies.
    op.execute("CREATE EXTENSION IF NOT EXISTS pg_trgm")

    op.execute(
        "CREATE INDEX IF NOT EXISTS ix_search_entry_norm_trgm "
        "ON search_entry USING gin (normalized gin_trgm_ops)"
    )
    # /lookup/lemma and the admin lexeme browser both match on this column.
    op.execute(
        "CREATE INDEX IF NOT EXISTS ix_lexeme_norm_lemma_trgm "
        "ON lexeme USING gin (normalized_lemma gin_trgm_ops)"
    )
    op.execute(
        "CREATE INDEX IF NOT EXISTS ix_expression_norm_text_trgm "
        "ON expression USING gin (normalized_text gin_trgm_ops)"
    )


def downgrade() -> None:
    op.execute("DROP INDEX IF EXISTS ix_expression_norm_text_trgm")
    op.execute("DROP INDEX IF EXISTS ix_lexeme_norm_lemma_trgm")
    op.execute("DROP INDEX IF EXISTS ix_search_entry_norm_trgm")
    # The extension is left in place: other objects may depend on it, and
    # dropping it is not this migration's call to make.
