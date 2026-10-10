#!/usr/bin/env python3
"""Create or update an admin console account.

There is no open sign-up: accounts are made by an admin through
`POST /admin/users`, which leaves the first one to create. This script is that
bootstrap, and is also the way back in if every admin password is lost.

    cd apps/api
    poetry run python scripts/create_user.py --email you@example.com \
        --name "Your Name" --role admin

The password is prompted for, not passed as an argument, so it stays out of
shell history and the process list. `--password-stdin` is there for scripted
use.
"""
from __future__ import annotations

import argparse
import getpass
import sys
from pathlib import Path

from sqlalchemy import select

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.core.security import hash_password, password_problem  # noqa: E402
from app.db import SessionLocal  # noqa: E402
from app.models import USER_ROLES, AppUser  # noqa: E402


def read_password(from_stdin: bool) -> str:
    if from_stdin:
        password = sys.stdin.readline().rstrip("\n")
    else:
        password = getpass.getpass("Password: ")
        if password != getpass.getpass("Repeat password: "):
            print("❌ Passwords do not match")
            raise SystemExit(1)

    problem = password_problem(password)
    if problem:
        print(f"❌ {problem}")
        raise SystemExit(1)
    return password


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--email", required=True)
    parser.add_argument("--name", help="display name (defaults to the email's local part)")
    parser.add_argument("--role", default="admin", choices=USER_ROLES)
    parser.add_argument(
        "--password-stdin", action="store_true", help="read the password from stdin"
    )
    parser.add_argument(
        "--update",
        action="store_true",
        help="reset the password and role of an existing account instead of failing",
    )
    args = parser.parse_args()

    email = args.email.strip()
    if "@" not in email:
        print(f"❌ Not an email address: {email}")
        return 1
    display_name = (args.name or email.split("@", 1)[0]).strip()

    db = SessionLocal()
    try:
        from sqlalchemy import func

        existing = db.scalar(select(AppUser).where(func.lower(AppUser.email) == email.lower()))
        if existing and not args.update:
            print(f"❌ {email} already exists. Pass --update to reset it.")
            return 1

        password = read_password(args.password_stdin)

        if existing:
            existing.display_name = display_name
            existing.role = args.role
            existing.password_hash = hash_password(password)
            existing.is_active = True
            # Ends any session issued under the old password.
            existing.sessions_valid_from = func.now()
            db.commit()
            print(f"✅ Updated {email} ({args.role}); existing sessions revoked")
            return 0

        db.add(
            AppUser(
                email=email,
                display_name=display_name,
                password_hash=hash_password(password),
                role=args.role,
            )
        )
        db.commit()
        print(f"✅ Created {email} ({args.role})")
        print("   Sign in at the admin console; there is no open sign-up.")
        return 0
    finally:
        db.close()


if __name__ == "__main__":
    sys.exit(main())
