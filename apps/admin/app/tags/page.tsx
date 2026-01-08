"use client";

import { useEffect, useMemo, useState } from "react";
import Link from "next/link";
import { createAdminClient, type Tag } from "../../lib/api";
import { useApiKey } from "../../lib/storage";

export default function TagsPage() {
  const { apiKey, loaded } = useApiKey();
  const [items, setItems] = useState<Tag[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [newName, setNewName] = useState("");
  const [newDescription, setNewDescription] = useState("");

  const client = useMemo(() => (apiKey ? createAdminClient(apiKey) : null), [apiKey]);

  const loadTags = async () => {
    if (!client) {
      return;
    }
    setLoading(true);
    setError(null);
    try {
      const data = await client.listTags();
      setItems(data);
    } catch (err) {
      setError("Failed to load tags.");
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadTags();
  }, [client]);

  if (!loaded) {
    return <p>Loading...</p>;
  }

  if (!apiKey) {
    return (
      <div className="card">
        <p>
          API key missing. <Link href="/login">Add your API key</Link> to manage tags.
        </p>
      </div>
    );
  }

  return (
    <section className="stack">
      <div className="header-row">
        <div>
          <h1>Tags</h1>
          <p className="muted">Create and assign tags for lexemes and senses.</p>
        </div>
      </div>
      {error && <p className="error">{error}</p>}
      <div className="card stack">
        <h2>Create tag</h2>
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
              await client.createTag({ name: newName.trim(), description: newDescription.trim() || undefined });
              setNewName("");
              setNewDescription("");
              await loadTags();
            } catch (err) {
              setError("Failed to create tag.");
            }
          }}
        >
          Add tag
        </button>
      </div>
      <div className="table">
        <div className="table-row table-head">
          <span>Name</span>
          <span>Description</span>
          <span></span>
        </div>
        {loading && <p>Loading tags...</p>}
        {items.map((tag) => (
          <TagRow key={tag.id} tag={tag} onRefresh={loadTags} />
        ))}
        {!loading && items.length === 0 && <p className="muted">No tags yet.</p>}
      </div>
    </section>
  );
}

function TagRow({ tag, onRefresh }: { tag: Tag; onRefresh: () => Promise<void> }) {
  const { apiKey } = useApiKey();
  const client = useMemo(() => (apiKey ? createAdminClient(apiKey) : null), [apiKey]);
  const [name, setName] = useState(tag.name);
  const [description, setDescription] = useState(tag.description ?? "");
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
              await client.updateTag(tag.id, { name: name.trim(), description: description.trim() || undefined });
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
              await client.deleteTag(tag.id);
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
