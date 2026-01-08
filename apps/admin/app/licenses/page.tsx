"use client";

import Link from "next/link";
import { useEffect, useMemo, useState } from "react";
import { createAdminClient, type License } from "../../lib/api";
import { useApiKey } from "../../lib/storage";

export default function LicensesPage() {
  const { apiKey, loaded } = useApiKey();
  const [items, setItems] = useState<License[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [newName, setNewName] = useState("");
  const [newUrl, setNewUrl] = useState("");

  const client = useMemo(() => (apiKey ? createAdminClient(apiKey) : null), [apiKey]);

  const loadLicenses = async () => {
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
  };

  useEffect(() => {
    loadLicenses();
  }, [client]);

  if (!loaded) {
    return <p>Loading...</p>;
  }

  if (!apiKey) {
    return (
      <div className="card">
        <p>
          API key missing. <Link href="/login">Add your API key</Link> to manage licenses.
        </p>
      </div>
    );
  }

  return (
    <section className="stack">
      <div className="header-row">
        <div>
          <h1>Licenses</h1>
          <p className="muted">Maintain license catalog for sources.</p>
        </div>
      </div>
      {error && <p className="error">{error}</p>}
      <div className="card stack">
        <h2>Create license</h2>
        <div className="grid two">
          <label className="field">
            <span>Name</span>
            <input value={newName} onChange={(event) => setNewName(event.target.value)} />
          </label>
          <label className="field">
            <span>URL</span>
            <input value={newUrl} onChange={(event) => setNewUrl(event.target.value)} />
          </label>
        </div>
        <button
          type="button"
          className="primary"
          onClick={async () => {
            if (!client || !newName.trim()) {
              return;
            }
            try {
              await client.createLicense({ name: newName.trim(), url: newUrl.trim() || undefined });
              setNewName("");
              setNewUrl("");
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
          <span>URL</span>
          <span></span>
        </div>
        {loading && <p>Loading licenses...</p>}
        {items.map((license) => (
          <LicenseRow key={license.id} license={license} onRefresh={loadLicenses} />
        ))}
        {!loading && items.length === 0 && <p className="muted">No licenses yet.</p>}
      </div>
    </section>
  );
}

function LicenseRow({ license, onRefresh }: { license: License; onRefresh: () => Promise<void> }) {
  const { apiKey } = useApiKey();
  const client = useMemo(() => (apiKey ? createAdminClient(apiKey) : null), [apiKey]);
  const [name, setName] = useState(license.name);
  const [url, setUrl] = useState(license.url ?? "");
  const [saving, setSaving] = useState(false);

  return (
    <div className="table-row">
      <input value={name} onChange={(event) => setName(event.target.value)} />
      <input value={url} onChange={(event) => setUrl(event.target.value)} />
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
            try {
              await client.updateLicense(license.id, { name: name.trim(), url: url.trim() || undefined });
              await onRefresh();
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
            try {
              await client.deleteLicense(license.id);
              await onRefresh();
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
