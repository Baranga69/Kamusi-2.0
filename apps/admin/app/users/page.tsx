"use client";

import Link from "next/link";
import { useCallback, useEffect, useState } from "react";
import { adminClient, type SessionUserLike } from "../../lib/api";
import { useSession } from "../../lib/session";

const roles = ["reviewer", "editor", "admin"] as const;

const roleHelp: Record<string, string> = {
  reviewer: "Works the review queue",
  editor: "Also writes entries and publishes",
  admin: "Also manages accounts, licences and sources",
};

export default function UsersPage() {
  const { user, loading: sessionLoading } = useSession();
  const [items, setItems] = useState<SessionUserLike[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);

  const [newEmail, setNewEmail] = useState("");
  const [newName, setNewName] = useState("");
  const [newPassword, setNewPassword] = useState("");
  const [newRole, setNewRole] = useState<string>("reviewer");

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      setItems(await adminClient.listUsers());
    } catch {
      setError("Failed to load accounts.");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  if (sessionLoading) {
    return <p>Loading...</p>;
  }

  if (!user) {
    return (
      <div className="card">
        <p>
          Not signed in. <Link href="/login">Sign in</Link> to manage accounts.
        </p>
      </div>
    );
  }

  if (user.role !== "admin") {
    return (
      <div className="card">
        <p>Managing accounts requires the admin role.</p>
      </div>
    );
  }

  const canCreate = Boolean(newEmail.trim() && newName.trim() && newPassword.length >= 12);

  return (
    <section className="stack">
      <div className="header-row">
        <div>
          <h1>Accounts</h1>
          <p className="muted">
            Review decisions are recorded against the account that made them, so give
            each reviewer their own. Disabling an account ends its sessions immediately.
          </p>
        </div>
      </div>
      {error && <p className="error">{error}</p>}
      {notice && <p className="muted">{notice}</p>}

      <div className="card stack">
        <h2>Add an account</h2>
        <div className="grid two">
          <label className="field">
            <span>Email</span>
            <input
              type="email"
              value={newEmail}
              onChange={(event) => setNewEmail(event.target.value)}
            />
          </label>
          <label className="field">
            <span>Display name</span>
            <input value={newName} onChange={(event) => setNewName(event.target.value)} />
          </label>
          <label className="field">
            <span>Temporary password</span>
            <input
              type="password"
              value={newPassword}
              onChange={(event) => setNewPassword(event.target.value)}
              placeholder="at least 12 characters"
            />
          </label>
          <label className="field">
            <span>Role</span>
            <select value={newRole} onChange={(event) => setNewRole(event.target.value)}>
              {roles.map((role) => (
                <option key={role} value={role}>
                  {role} — {roleHelp[role]}
                </option>
              ))}
            </select>
          </label>
        </div>
        <button
          type="button"
          className="primary"
          disabled={!canCreate}
          onClick={async () => {
            setError(null);
            setNotice(null);
            try {
              await adminClient.createUser({
                email: newEmail.trim(),
                display_name: newName.trim(),
                password: newPassword,
                role: newRole,
              });
              setNotice(`Created ${newEmail.trim()}. Ask them to change the password after signing in.`);
              setNewEmail("");
              setNewName("");
              setNewPassword("");
              await load();
            } catch (err: unknown) {
              const detail =
                typeof err === "object" && err && "response" in err
                  ? // eslint-disable-next-line @typescript-eslint/no-explicit-any
                    (err as any).response?.data?.detail
                  : null;
              setError(detail ?? "Failed to create the account.");
            }
          }}
        >
          Create account
        </button>
      </div>

      <div className="table">
        <div className="table-row table-head">
          <span>Email</span>
          <span>Name</span>
          <span>Role</span>
          <span>Status</span>
          <span>Last signed in</span>
          <span></span>
        </div>
        {loading && <p>Loading accounts...</p>}
        {items.map((account) => (
          <UserRow
            key={account.id}
            account={account}
            isSelf={account.id === user.id}
            onRefresh={load}
            onError={setError}
            onNotice={setNotice}
          />
        ))}
        {!loading && items.length === 0 && <p className="muted">No accounts yet.</p>}
      </div>
    </section>
  );
}

function UserRow({
  account,
  isSelf,
  onRefresh,
  onError,
  onNotice,
}: {
  account: SessionUserLike;
  isSelf: boolean;
  onRefresh: () => Promise<void>;
  onError: (message: string | null) => void;
  onNotice: (message: string | null) => void;
}) {
  const [role, setRole] = useState(account.role);
  const [saving, setSaving] = useState(false);

  const act = async (run: () => Promise<unknown>, success: string) => {
    setSaving(true);
    onError(null);
    onNotice(null);
    try {
      await run();
      onNotice(success);
      await onRefresh();
    } catch (err: unknown) {
      const detail =
        typeof err === "object" && err && "response" in err
          ? // eslint-disable-next-line @typescript-eslint/no-explicit-any
            (err as any).response?.data?.detail
          : null;
      onError(detail ?? "That did not work.");
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="table-row">
      <span>
        {account.email}
        {isSelf && <span className="muted"> (you)</span>}
      </span>
      <span>{account.display_name}</span>
      <select
        value={role}
        disabled={isSelf || saving}
        onChange={(event) => {
          const next = event.target.value;
          setRole(next);
          act(
            () => adminClient.updateUser(account.id, { role: next }),
            `${account.email} is now ${next}.`
          );
        }}
      >
        {roles.map((option) => (
          <option key={option} value={option}>
            {option}
          </option>
        ))}
      </select>
      <span className={account.is_active ? "status published" : "status archived"}>
        {account.is_active ? "active" : "disabled"}
      </span>
      <span className="muted">
        {account.last_login_at ? new Date(account.last_login_at).toLocaleDateString() : "never"}
      </span>
      <div className="actions">
        <button
          type="button"
          className="ghost"
          disabled={isSelf || saving}
          onClick={() =>
            act(
              () => adminClient.updateUser(account.id, { is_active: !account.is_active }),
              account.is_active
                ? `${account.email} disabled; their sessions have ended.`
                : `${account.email} re-enabled.`
            )
          }
        >
          {account.is_active ? "Disable" : "Enable"}
        </button>
        <button
          type="button"
          className="ghost"
          disabled={saving}
          onClick={() => {
            const next = window.prompt(
              `New password for ${account.email} (at least 12 characters). This ends their current sessions.`
            );
            if (!next) {
              return;
            }
            act(
              () => adminClient.resetUserPassword(account.id, next),
              `Password reset for ${account.email}; their sessions have ended.`
            );
          }}
        >
          Reset password
        </button>
      </div>
    </div>
  );
}
