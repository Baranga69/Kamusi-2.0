"""record how far an import got, so it can resume

Revision ID: 0008_import_progress
Revises: 0007_import_run
Create Date: 2026-10-11 00:00:00.000000

Both importers committed exactly once, at the end. A 50,000-line file
therefore held a single transaction open from first row to last, and a failure
at row 49,999 threw away all of it. At the corpus sizes this project is aiming
for, that turns one bad line into a lost afternoon.

Committing in batches fixes the loss. Resuming needs a checkpoint, which is
what this adds: the number of input lines durably written so far.

`processed_lines` is updated *in the same transaction as the batch it
describes*, which is the only way it can be trusted. A checkpoint committed
separately drifts from the data the moment one of the two writes fails, and a
resume point that is wrong is worse than none.

Keep the revision identifier under 32 characters — Alembic stores it in
alembic_version.version_num, a varchar(32), and a longer value makes the whole
upgrade fail and roll back.
"""

from alembic import op
import sqlalchemy as sa

revision = "0008_import_progress"
down_revision = "0007_import_run"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "import_run",
        sa.Column("processed_lines", sa.Integer(), nullable=False, server_default="0"),
    )
    # Known only when the input has been counted up front; null otherwise, so
    # progress reporting can say "1,200" rather than inventing a denominator.
    op.add_column("import_run", sa.Column("total_lines", sa.Integer()))


def downgrade() -> None:
    op.drop_column("import_run", "total_lines")
    op.drop_column("import_run", "processed_lines")
