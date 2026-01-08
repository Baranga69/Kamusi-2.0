"use client";

import Link from "next/link";
import { useEffect, useMemo, useState } from "react";
import { createAdminClient, type Source } from "../../lib/api";
import { useApiKey } from "../../lib/storage";

export default function SourcesPage() {
  const { apiKey, loaded } = useApiKey();
  const [items, setItems] = useState<Source[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [newName, setNewName] = useState("");
  const [newDescription, setNewDescription] = useState("");

  const client = useMemo(() => (apiKey ? createAdminClient(apiKey) : null), [apiKey]);

  const loadSources = async () => {
    if (!client) {
      return;
    }
    setLoading(true);
    setError(null);
    try {
      const data = await client.listSources();
      setItems(data);
    } catch (err) {
      setError("Failed to load sources.");
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadSources();
  }, [client]);

  if (!loaded) {
    return <p>Loading...</p>;
  }

  if (!apiKey) {
    return (
      <div className="card">
        <p>
          API key missing. <Link href="/login">Add your API key</Link> to manage sources.
        </p>
      </div>
    );
  }

  return (
    <section className="stack">
      <div className="header-row">
        <div>
          <h1>Sources</h1>
          <p className="muted">Maintain content sources for citations.</p>
        </div>
      </div>
      {error && <p className="error">{error}</p>}
      <div className="card stack">
        <h2>Create source</h2>
        <div className="grid two">
          <label className="field">
            <span>Name</span>
            <input value={newName} onChange={(event) => setNewName(event.target.value)} />
          </label>
          <label className="field">
            <span>Description</span>
            <input value={newDescription} onChange={(event) => setNewDescription(event.target.value)} />
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
              await client.createSource({ name: newName.trim(), description: newDescription.trim() || undefined });
              setNewName("");
              setNewDescription("");
              await loadSources();
            } catch (err) {
              setError("Failed to create source.");
            }
          }}
        >
          Add source
        </button>
      </div>
      <div className="table">
        <div className="table-row table-head">
          <span>Name</span>
          <span>Description</span>
          <span></span>
        </div>
        {loading && <p>Loading sources...</p>}
        {items.map((source) => (
          <SourceRow key={source.id} source={source} onRefresh={loadSources} />
        ))}
        {!loading && items.length === 0 && <p className="muted">No sources yet.</p>}
      </div>
    </section>
  );
}

function SourceRow({ source, onRefresh }: { source: Source; onRefresh: () => Promise<void> }) {
  const { apiKey } = useApiKey();
  const client = useMemo(() => (apiKey ? createAdminClient(apiKey) : null), [apiKey]);
  const [name, setName] = useState(source.name);
  const [description, setDescription] = useState(source.description ?? "");
  const [saving, setSaving] = useState(false);

  return (
    <div className="table-row">
      <input value={name} onChange={(event) => setName(event.target.value)} />
      <input value={description} onChange={(event) => setDescription(event.target.value)} />
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
              await client.updateSource(source.id, { name: name.trim(), description: description.trim() || undefined });
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
              await client.deleteSource(source.id);
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
