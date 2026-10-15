"use client";

import Link from "next/link";
import { useCallback, useEffect, useMemo, useState } from "react";
import { adminClient, type License } from "../../lib/api";
import { useSession } from "../../lib/session";

export default function LicensesPage() {
  const { user, loading: sessionLoading } = useSession();
  const [items, setItems] = useState<License[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [newName, setNewName] = useState("");
  const [newSummary, setNewSummary] = useState("");
  const [newCanDisplay, setNewCanDisplay] = useState(true);
  const [newCanModify, setNewCanModify] = useState(false);
  const [newCanCommercialize, setNewCanCommercialize] = useState(false);

  const client = adminClient;

  const loadLicenses = useCallback(async () => {
    if (!client) {
      return;
    }
    setLoading(true);
    setError(null);
    try {
      const data = await client.listLicenses();
      setItems(data);
    } catch (err) {
      setError("Failed to load licenses.");
    } finally {
      setLoading(false);
    }
  }, [client]);

  useEffect(() => {
    loadLicenses();
  }, [loadLicenses]);

  if (sessionLoading) {
    return <p>Loading...</p>;
  }

  if (!user) {
    return (
      <div className="card">
        <p>
          Not signed in. <Link href="/login">Sign in</Link> to manage licenses.
        </p>
      </div>
    );
  }

  return (
    <section className="stack">
      <div className="header-row">
        <div>
          <h1>Licenses</h1>
          <p className="muted">
            Maintain the license catalog for sources. The permission flags record what Kamusi
            may do with content attributed to each license.
          </p>
        </div>
      </div>
      {error && <p className="error">{error}</p>}
      <div className="card stack">
        <h2>Create license</h2>
        <div className="grid two">
          <label className="field">
            <span>Name</span>
            <input
              value={newName}
              onChange={(event) => setNewName(event.target.value)}
              placeholder="CC BY-SA 4.0"
            />
          </label>
          <label className="field">
            <span>Summary</span>
            <input
              value={newSummary}
              onChange={(event) => setNewSummary(event.target.value)}
              placeholder="Attribution, share-alike"
            />
          </label>
        </div>
        <div className="filters">
          <label className="checkbox">
            <input
              type="checkbox"
              checked={newCanDisplay}
              onChange={(event) => setNewCanDisplay(event.target.checked)}
            />
            Can display
          </label>
          <label className="checkbox">
            <input
              type="checkbox"
              checked={newCanModify}
              onChange={(event) => setNewCanModify(event.target.checked)}
            />
            Can modify
          </label>
          <label className="checkbox">
            <input
              type="checkbox"
              checked={newCanCommercialize}
              onChange={(event) => setNewCanCommercialize(event.target.checked)}
            />
            Can commercialize
          </label>
        </div>
        <button
          type="button"
          className="primary"
          disabled={!newName.trim()}
          onClick={async () => {
            if (!client || !newName.trim()) {
              return;
            }
            setError(null);
            try {
              await client.createLicense({
                name: newName.trim(),
                summary: newSummary.trim() || null,
                can_display: newCanDisplay,
                can_modify: newCanModify,
                can_commercialize: newCanCommercialize,
              });
              setNewName("");
              setNewSummary("");
              setNewCanDisplay(true);
              setNewCanModify(false);
              setNewCanCommercialize(false);
              await loadLicenses();
            } catch (err) {
              setError("Failed to create license.");
            }
          }}
        >
          Add license
        </button>
      </div>
      <div className="table">
        <div className="table-row table-head">
          <span>Name</span>
          <span>Summary</span>
          <span>Permissions</span>
          <span></span>
        </div>
        {loading && <p>Loading licenses...</p>}
        {items.map((license) => (
          <LicenseRow
            key={license.id}
            license={license}
            onRefresh={loadLicenses}
            onError={setError}
          />
        ))}
        {!loading && items.length === 0 && <p className="muted">No licenses yet.</p>}
      </div>
    </section>
  );
}

function LicenseRow({
  license,
  onRefresh,
  onError,
}: {
  license: License;
  onRefresh: () => Promise<void>;
  onError: (message: string | null) => void;
}) {
  const { user } = useSession();
  const client = adminClient;
  const [name, setName] = useState(license.name);
  const [summary, setSummary] = useState(license.summary ?? "");
  const [canDisplay, setCanDisplay] = useState(license.can_display);
  const [canModify, setCanModify] = useState(license.can_modify);
  const [canCommercialize, setCanCommercialize] = useState(license.can_commercialize);
  const [saving, setSaving] = useState(false);

  return (
    <div className="table-row">
      <input value={name} onChange={(event) => setName(event.target.value)} />
      <input value={summary} onChange={(event) => setSummary(event.target.value)} />
      <div className="actions">
        <label className="checkbox">
          <input
            type="checkbox"
            checked={canDisplay}
            onChange={(event) => setCanDisplay(event.target.checked)}
          />
          Display
        </label>
        <label className="checkbox">
          <input
            type="checkbox"
            checked={canModify}
            onChange={(event) => setCanModify(event.target.checked)}
          />
          Modify
        </label>
        <label className="checkbox">
          <input
            type="checkbox"
            checked={canCommercialize}
            onChange={(event) => setCanCommercialize(event.target.checked)}
          />
          Commercial
        </label>
      </div>
      <div className="actions">
        <button
          type="button"
          className="ghost"
          disabled={saving}
          onClick={async () => {
            if (!client) {
              return;
            }
            setSaving(true);
            onError(null);
            try {
              await client.updateLicense(license.id, {
                name: name.trim(),
                summary: summary.trim() || null,
                can_display: canDisplay,
                can_modify: canModify,
                can_commercialize: canCommercialize,
              });
              await onRefresh();
            } catch (err) {
              onError("Failed to save license.");
            } finally {
              setSaving(false);
            }
          }}
        >
          Save
        </button>
        <button
          type="button"
          className="ghost"
          disabled={saving}
          onClick={async () => {
            if (!client) {
              return;
            }
            setSaving(true);
            onError(null);
            try {
              await client.deleteLicense(license.id);
              await onRefresh();
            } catch (err) {
              onError("Failed to delete license. It may still be referenced by a source.");
            } finally {
              setSaving(false);
            }
          }}
        >
          Delete
        </button>
      </div>
    </div>
  );
}
