"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import Link from "next/link";
import { createAdminClient, type LookupOption, type Tag } from "../../lib/api";
import { useApiKey } from "../../lib/storage";

export default function TagsPage() {
  const { apiKey, loaded } = useApiKey();
  const [items, setItems] = useState<Tag[]>([]);
  const [tagTypes, setTagTypes] = useState<LookupOption[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [newName, setNewName] = useState("");
  const [newTagTypeId, setNewTagTypeId] = useState("");
  const [newDescription, setNewDescription] = useState("");

  const client = useMemo(() => (apiKey ? createAdminClient(apiKey) : null), [apiKey]);

  const loadTags = useCallback(async () => {
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
  }, [client]);

  useEffect(() => {
    loadTags();
  }, [loadTags]);

  // A tag needs a tag type, so the select has to be populated before we can create one.
  useEffect(() => {
    if (!client) {
      return;
    }
    let cancelled = false;
    client
      .getLookups()
      .then((lookups) => {
        if (cancelled) {
          return;
        }
        setTagTypes(lookups.tag_types);
        setNewTagTypeId((current) => current || lookups.tag_types[0]?.id || "");
      })
      .catch(() => {
        if (!cancelled) {
          setError("Failed to load tag types. Seed lookup tables first (scripts/seed.py).");
        }
      });
    return () => {
      cancelled = true;
    };
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

  const canCreate = Boolean(newName.trim() && newTagTypeId);

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
            <span>Type</span>
            <select value={newTagTypeId} onChange={(event) => setNewTagTypeId(event.target.value)}>
              {tagTypes.length === 0 && <option value="">No tag types seeded</option>}
              {tagTypes.map((option) => (
                <option key={option.id} value={option.id}>
                  {option.label}
                </option>
              ))}
            </select>
          </label>
          <label className="field">
            <span>Description</span>
            <input value={newDescription} onChange={(event) => setNewDescription(event.target.value)} />
          </label>
        </div>
        <button
          type="button"
          className="primary"
          disabled={!canCreate}
          onClick={async () => {
            if (!client || !canCreate) {
              return;
            }
            setError(null);
            try {
              await client.createTag({
                name: newName.trim(),
                tag_type_id: newTagTypeId,
                description: newDescription.trim() || null,
              });
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
          <span>Type</span>
          <span>Description</span>
          <span></span>
        </div>
        {loading && <p>Loading tags...</p>}
        {items.map((tag) => (
          <TagRow
            key={tag.id}
            tag={tag}
            tagTypes={tagTypes}
            onRefresh={loadTags}
            onError={setError}
          />
        ))}
        {!loading && items.length === 0 && <p className="muted">No tags yet.</p>}
      </div>
    </section>
  );
}

function TagRow({
  tag,
  tagTypes,
  onRefresh,
  onError,
}: {
  tag: Tag;
  tagTypes: LookupOption[];
  onRefresh: () => Promise<void>;
  onError: (message: string | null) => void;
}) {
  const { apiKey } = useApiKey();
  const client = useMemo(() => (apiKey ? createAdminClient(apiKey) : null), [apiKey]);
  const [name, setName] = useState(tag.name);
  const [tagTypeId, setTagTypeId] = useState(tag.tag_type_id);
  const [description, setDescription] = useState(tag.description ?? "");
  const [saving, setSaving] = useState(false);

  return (
    <div className="table-row">
      <input value={name} onChange={(event) => setName(event.target.value)} />
      <select value={tagTypeId} onChange={(event) => setTagTypeId(event.target.value)}>
        {tagTypes.map((option) => (
          <option key={option.id} value={option.id}>
            {option.label}
          </option>
        ))}
      </select>
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
            onError(null);
            try {
              await client.updateTag(tag.id, {
                name: name.trim(),
                tag_type_id: tagTypeId,
                description: description.trim() || null,
              });
              await onRefresh();
            } catch (err) {
              onError("Failed to save tag.");
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
              await client.deleteTag(tag.id);
              await onRefresh();
            } catch (err) {
              onError("Failed to delete tag.");
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
