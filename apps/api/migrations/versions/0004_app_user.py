"""add app_user for reviewer identity

Revision ID: 0004_app_user
Revises: 0003_trigram_search
Create Date: 2026-10-10 00:00:00.000000

Until now every `/admin/*` route was gated by one shared API key, and the
`reviewed_by` recorded against an approval was a string the client supplied.
Anyone holding the key could approve as anyone, so the audit trail could not
be relied on — which undermines the one guarantee the review pipeline exists
to provide.

This adds real accounts. `reviewed_by` is derived from the authenticated
session server-side, and roles gate what each person can do:

    reviewer  work the review queue (approve / edit / reject)
    editor    + create and edit entries, move them through the workflow
    admin     + manage accounts, licences and sources, delete anything

`role` is a plain text column with a CHECK rather than a Postgres enum:
adding a role later is then an ordinary constraint change rather than an
`ALTER TYPE`, which this project treats as high-risk.

`sessions_valid_from` is the revocation point. Session tokens carry their
issue time, and any token issued before this timestamp is rejected, so
deactivating an account or changing a password invalidates existing sessions
without needing a session table.

Keep the revision identifier under 32 characters — Alembic stores it in
alembic_version.version_num, a varchar(32), and a longer value makes the
whole upgrade fail and roll back.
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision = "0004_app_user"
down_revision = "0003_trigram_search"
branch_labels = None
depends_on = None

ROLES = ("reviewer", "editor", "admin")


def upgrade() -> None:
    op.create_table(
        "app_user",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()"),
        ),
        sa.Column("email", sa.Text(), nullable=False),
        sa.Column("display_name", sa.Text(), nullable=False),
        sa.Column("password_hash", sa.Text(), nullable=False),
        sa.Column("role", sa.Text(), nullable=False, server_default="reviewer"),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.text("true")),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("now()"),
        ),
        sa.Column(
            "sessions_valid_from",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("now()"),
        ),
        sa.Column("last_login_at", sa.DateTime(timezone=True)),
        sa.CheckConstraint(
            "role IN ('reviewer', 'editor', 'admin')", name="ck_app_user_role"
        ),
    )

    # Addresses are compared case-insensitively, so uniqueness has to be too:
    # otherwise Ada@example.com and ada@example.com are two accounts that both
    # answer to the same login.
    op.create_index(
        "ux_app_user_email_lower",
        "app_user",
        [sa.text("lower(email)")],
        unique=True,
    )


def downgrade() -> None:
    op.drop_index("ux_app_user_email_lower", table_name="app_user")
    op.drop_table("app_user")
