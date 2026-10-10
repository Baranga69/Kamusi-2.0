"use client";

import Link from "next/link";
import { useCallback, useEffect, useMemo, useState } from "react";
import { createAdminClient, type License, type Source } from "../../lib/api";
import { useApiKey } from "../../lib/storage";

const sourceTypes = ["dictionary", "dump", "corpus", "book", "web", "ai", "other"] as const;

export default function SourcesPage() {
  const { apiKey, loaded } = useApiKey();
  const [items, setItems] = useState<Source[]>([]);
  const [licenses, setLicenses] = useState<License[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [newTitle, setNewTitle] = useState("");
  const [newAuthor, setNewAuthor] = useState("");
  const [newYear, setNewYear] = useState("");
  const [newSourceType, setNewSourceType] = useState<string>("dictionary");
  const [newLicenseId, setNewLicenseId] = useState("");
  const [newUrl, setNewUrl] = useState("");

  const client = useMemo(() => (apiKey ? createAdminClient(apiKey) : null), [apiKey]);

  const loadSources = useCallback(async () => {
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
  }, [client]);

  useEffect(() => {
    loadSources();
  }, [loadSources]);

  // A source requires a license, so that select has to be filled first.
  useEffect(() => {
    if (!client) {
      return;
    }
    let cancelled = false;
    client
      .listLicenses()
      .then((data) => {
        if (cancelled) {
          return;
        }
        setLicenses(data);
        setNewLicenseId((current) => current || data[0]?.id || "");
      })
      .catch(() => {
        if (!cancelled) {
          setError("Failed to load licenses. Add a license before creating a source.");
        }
      });
    return () => {
      cancelled = true;
    };
  }, [client]);

  const licenseName = (id: string) => licenses.find((license) => license.id === id)?.name ?? id;

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

  const canCreate = Boolean(newTitle.trim() && newSourceType && newLicenseId);

  return (
    <section className="stack">
      <div className="header-row">
        <div>
          <h1>Sources</h1>
          <p className="muted">
            Provenance for every definition. Each source carries a license, which governs how
            its content may be reused.
          </p>
        </div>
      </div>
      {error && <p className="error">{error}</p>}
      {licenses.length === 0 && (
        <div className="alert">
          <strong>No licenses yet.</strong> <Link href="/licenses">Create one</Link> before adding
          a source.
        </div>
      )}
      <div className="card stack">
        <h2>Create source</h2>
        <div className="grid two">
          <label className="field">
            <span>Title</span>
            <input
              value={newTitle}
              onChange={(event) => setNewTitle(event.target.value)}
              placeholder="English Wiktionary"
            />
          </label>
          <label className="field">
            <span>Author</span>
            <input value={newAuthor} onChange={(event) => setNewAuthor(event.target.value)} />
          </label>
          <label className="field">
            <span>Year</span>
            <input
              value={newYear}
              onChange={(event) => setNewYear(event.target.value)}
              inputMode="numeric"
              placeholder="2026"
            />
          </label>
          <label className="field">
            <span>Type</span>
            <select value={newSourceType} onChange={(event) => setNewSourceType(event.target.value)}>
              {sourceTypes.map((option) => (
                <option key={option} value={option}>
                  {option}
                </option>
              ))}
            </select>
          </label>
          <label className="field">
            <span>License</span>
            <select value={newLicenseId} onChange={(event) => setNewLicenseId(event.target.value)}>
              {licenses.length === 0 && <option value="">No licenses available</option>}
              {licenses.map((license) => (
                <option key={license.id} value={license.id}>
                  {license.name}
                </option>
              ))}
            </select>
          </label>
          <label className="field">
            <span>URL</span>
            <input value={newUrl} onChange={(event) => setNewUrl(event.target.value)} />
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
            const parsedYear = Number.parseInt(newYear, 10);
            try {
              await client.createSource({
                title: newTitle.trim(),
                author: newAuthor.trim() || null,
                publisher: null,
                year: Number.isNaN(parsedYear) ? null : parsedYear,
                source_type: newSourceType,
                license_id: newLicenseId,
                url: newUrl.trim() || null,
                notes: null,
              });
              setNewTitle("");
              setNewAuthor("");
              setNewYear("");
              setNewUrl("");
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
          <span>Title</span>
          <span>Author</span>
          <span>Type</span>
          <span>License</span>
          <span></span>
        </div>
        {loading && <p>Loading sources...</p>}
        {items.map((source) => (
          <SourceRow
            key={source.id}
            source={source}
            licenses={licenses}
            licenseName={licenseName}
            onRefresh={loadSources}
            onError={setError}
          />
        ))}
        {!loading && items.length === 0 && <p className="muted">No sources yet.</p>}
      </div>
    </section>
  );
}

function SourceRow({
  source,
  licenses,
  licenseName,
  onRefresh,
  onError,
}: {
  source: Source;
  licenses: License[];
  licenseName: (id: string) => string;
  onRefresh: () => Promise<void>;
  onError: (message: string | null) => void;
}) {
  const { apiKey } = useApiKey();
  const client = useMemo(() => (apiKey ? createAdminClient(apiKey) : null), [apiKey]);
  const [title, setTitle] = useState(source.title);
  const [author, setAuthor] = useState(source.author ?? "");
  const [sourceType, setSourceType] = useState(source.source_type);
  const [licenseId, setLicenseId] = useState(source.license_id);
  const [saving, setSaving] = useState(false);

  return (
    <div className="table-row">
      <input value={title} onChange={(event) => setTitle(event.target.value)} />
      <input value={author} onChange={(event) => setAuthor(event.target.value)} />
      <select value={sourceType} onChange={(event) => setSourceType(event.target.value)}>
        {[...new Set([source.source_type, ...sourceTypes])].map((option) => (
          <option key={option} value={option}>
            {option}
          </option>
        ))}
      </select>
      <select value={licenseId} onChange={(event) => setLicenseId(event.target.value)}>
        {licenses.length === 0 && <option value={licenseId}>{licenseName(licenseId)}</option>}
        {licenses.map((license) => (
          <option key={license.id} value={license.id}>
            {license.name}
          </option>
        ))}
      </select>
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
              await client.updateSource(source.id, {
                title: title.trim(),
                author: author.trim() || null,
                source_type: sourceType,
                license_id: licenseId,
              });
              await onRefresh();
            } catch (err) {
              onError("Failed to save source.");
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
              await client.deleteSource(source.id);
              await onRefresh();
            } catch (err) {
              onError("Failed to delete source. It may still be referenced by a definition.");
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
