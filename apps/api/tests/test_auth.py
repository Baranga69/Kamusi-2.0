"""Accounts, roles, and the audit trail they exist to make trustworthy."""
import uuid

import pytest

from app.core.security import hash_password, issue_session
from app.models import AppUser

PASSWORD = "correct-horse-battery"
API_KEY_HEADER = {"X-API-Key": "dev-api-key"}


def make_user(db_session, email: str, role: str = "reviewer", active: bool = True) -> AppUser:
    user = AppUser(
        email=email,
        display_name=email.split("@")[0].title(),
        password_hash=hash_password(PASSWORD),
        role=role,
        is_active=active,
    )
    db_session.add(user)
    db_session.commit()
    return user


def bearer(user: AppUser) -> dict[str, str]:
    return {"Authorization": f"Bearer {issue_session(user.id)}"}


def login(client, email: str, password: str = PASSWORD):
    return client.post("/auth/login", json={"email": email, "password": password})


# --- signing in -----------------------------------------------------------


def test_login_returns_a_working_session(client, db_session):
    make_user(db_session, "ada@example.com", role="editor")

    response = login(client, "ada@example.com")
    assert response.status_code == 200
    body = response.json()
    assert body["user"]["email"] == "ada@example.com"
    assert body["user"]["role"] == "editor"
    assert "password" not in str(body)

    me = client.get("/auth/me", headers={"Authorization": f"Bearer {body['token']}"})
    assert me.status_code == 200
    assert me.json()["email"] == "ada@example.com"


def test_login_is_case_insensitive_on_email(client, db_session):
    make_user(db_session, "ada@example.com")
    assert login(client, "ADA@Example.com").status_code == 200


def test_wrong_password_and_unknown_email_are_indistinguishable(client, db_session):
    make_user(db_session, "ada@example.com")

    wrong = login(client, "ada@example.com", "not-the-password")
    unknown = login(client, "nobody@example.com")
    assert wrong.status_code == unknown.status_code == 401
    assert wrong.json() == unknown.json()


def test_disabled_account_cannot_sign_in_or_use_an_old_session(client, db_session):
    user = make_user(db_session, "ada@example.com", role="admin")
    headers = bearer(user)
    assert client.get("/auth/me", headers=headers).status_code == 200

    user.is_active = False
    db_session.commit()

    assert login(client, "ada@example.com").status_code == 403
    assert client.get("/auth/me", headers=headers).status_code == 401


def test_tampered_and_unsigned_tokens_are_rejected(client, db_session):
    user = make_user(db_session, "ada@example.com")
    good = issue_session(user.id)

    for token in [good[:-4] + "aaaa", "not-a-token", str(user.id), ""]:
        response = client.get("/auth/me", headers={"Authorization": f"Bearer {token}"})
        assert response.status_code == 401, token


def test_session_for_a_deleted_user_is_rejected(client, db_session):
    token = issue_session(uuid.uuid4())
    assert client.get("/auth/me", headers={"Authorization": f"Bearer {token}"}).status_code == 401


# --- the audit trail ------------------------------------------------------


def test_reviewer_is_taken_from_the_session_not_the_request(client, db_session):
    """The whole point: a client cannot choose whose name is recorded."""
    from tests.test_admin_review import seed_single_unreviewed_definition

    definition_id = seed_single_unreviewed_definition(db_session)
    reviewer = make_user(db_session, "ada@example.com", role="reviewer")

    response = client.post(
        f"/admin/review/item/{definition_id}/approve",
        headers=bearer(reviewer),
        # A forged reviewer in the body must be ignored.
        json={"reviewer": "someone-else@evil.example"},
    )
    assert response.status_code == 200
    assert response.json()["reviewed_by"] == "ada@example.com"


def test_api_key_cannot_review(client, db_session):
    """A shared key is not a person, so it cannot sign off on content."""
    from tests.test_admin_review import seed_single_unreviewed_definition

    definition_id = seed_single_unreviewed_definition(db_session)

    response = client.post(
        f"/admin/review/item/{definition_id}/approve",
        headers=API_KEY_HEADER,
        json={"reviewer": "whoever"},
    )
    assert response.status_code == 403
    assert "signed-in account" in response.json()["detail"]

    # Reading the queue with a key is still fine.
    assert client.get("/admin/review/queue", headers=API_KEY_HEADER).status_code == 200


# --- roles ----------------------------------------------------------------


def test_reviewer_cannot_write_content(client, db_session):
    reviewer = make_user(db_session, "rev@example.com", role="reviewer")
    headers = bearer(reviewer)

    assert client.get("/admin/review/queue", headers=headers).status_code == 200
    assert client.get("/admin/lexemes", headers=headers).status_code == 403
    assert client.get("/admin/users", headers=headers).status_code == 403


def test_editor_can_write_content_but_not_manage_accounts(client, db_session):
    editor = make_user(db_session, "ed@example.com", role="editor")
    headers = bearer(editor)

    assert client.get("/admin/lexemes", headers=headers).status_code == 200
    assert client.get("/admin/lookups", headers=headers).status_code == 200
    assert client.get("/admin/users", headers=headers).status_code == 403
    # Licences and sources are the admin's catalogue to curate.
    assert client.post("/admin/licenses", headers=headers, json={"name": "X"}).status_code == 403


def test_admin_can_do_everything(client, db_session):
    admin = make_user(db_session, "boss@example.com", role="admin")
    headers = bearer(admin)

    assert client.get("/admin/lexemes", headers=headers).status_code == 200
    assert client.get("/admin/users", headers=headers).status_code == 200
    created = client.post("/admin/licenses", headers=headers, json={"name": "CC BY-SA 4.0"})
    assert created.status_code == 200


def test_unauthenticated_requests_are_rejected(client, db_session):
    for path in ["/admin/lexemes", "/admin/review/queue", "/admin/users", "/auth/me"]:
        assert client.get(path).status_code == 401, path


def test_public_endpoints_need_no_credentials(client, db_session):
    assert client.get("/health").status_code == 200
    assert client.get("/search", params={"q": "mti"}).status_code == 200


# --- account management ---------------------------------------------------


def test_admin_creates_an_account_that_can_sign_in(client, db_session):
    admin = make_user(db_session, "boss@example.com", role="admin")

    response = client.post(
        "/admin/users",
        headers=bearer(admin),
        json={
            "email": "new@example.com",
            "display_name": "New Reviewer",
            "password": "a-long-enough-password",
            "role": "reviewer",
        },
    )
    assert response.status_code == 201
    assert response.json()["role"] == "reviewer"
    assert login(client, "new@example.com", "a-long-enough-password").status_code == 200


def test_duplicate_email_is_rejected_regardless_of_case(client, db_session):
    admin = make_user(db_session, "boss@example.com", role="admin")
    make_user(db_session, "taken@example.com")

    response = client.post(
        "/admin/users",
        headers=bearer(admin),
        json={
            "email": "TAKEN@example.com",
            "display_name": "Imposter",
            "password": "a-long-enough-password",
        },
    )
    assert response.status_code == 409


def test_short_password_is_rejected(client, db_session):
    admin = make_user(db_session, "boss@example.com", role="admin")
    response = client.post(
        "/admin/users",
        headers=bearer(admin),
        json={"email": "new@example.com", "display_name": "New", "password": "short"},
    )
    assert response.status_code == 422


def test_invalid_role_is_rejected(client, db_session):
    admin = make_user(db_session, "boss@example.com", role="admin")
    response = client.post(
        "/admin/users",
        headers=bearer(admin),
        json={
            "email": "new@example.com",
            "display_name": "New",
            "password": "a-long-enough-password",
            "role": "superuser",
        },
    )
    assert response.status_code == 400


def test_admin_cannot_lock_themselves_out(client, db_session):
    admin = make_user(db_session, "boss@example.com", role="admin")
    headers = bearer(admin)

    assert client.put(f"/admin/users/{admin.id}", headers=headers, json={"is_active": False}).status_code == 400
    assert client.put(f"/admin/users/{admin.id}", headers=headers, json={"role": "reviewer"}).status_code == 400


def test_changing_a_password_revokes_existing_sessions(client, db_session):
    user = make_user(db_session, "ada@example.com", role="editor")
    headers = bearer(user)
    assert client.get("/auth/me", headers=headers).status_code == 200

    response = client.post(
        "/auth/password",
        headers=headers,
        json={"current_password": PASSWORD, "new_password": "a-brand-new-password"},
    )
    assert response.status_code == 204

    # The token used to make the change is itself no longer valid.
    assert client.get("/auth/me", headers=headers).status_code == 401
    assert login(client, "ada@example.com", "a-brand-new-password").status_code == 200
    assert login(client, "ada@example.com", PASSWORD).status_code == 401


def test_password_change_requires_the_current_password(client, db_session):
    user = make_user(db_session, "ada@example.com")
    response = client.post(
        "/auth/password",
        headers=bearer(user),
        json={"current_password": "wrong", "new_password": "a-brand-new-password"},
    )
    assert response.status_code == 403


def test_admin_reset_revokes_the_users_sessions(client, db_session):
    admin = make_user(db_session, "boss@example.com", role="admin")
    user = make_user(db_session, "ada@example.com")
    user_headers = bearer(user)

    response = client.post(
        f"/admin/users/{user.id}/password",
        headers=bearer(admin),
        json={"new_password": "reset-by-the-admin"},
    )
    assert response.status_code == 204
    assert client.get("/auth/me", headers=user_headers).status_code == 401
    assert login(client, "ada@example.com", "reset-by-the-admin").status_code == 200


def test_api_key_is_not_an_account(client, db_session):
    assert client.get("/auth/me", headers=API_KEY_HEADER).status_code == 403
