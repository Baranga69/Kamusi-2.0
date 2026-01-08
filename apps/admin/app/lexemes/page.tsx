"use client";

import Link from "next/link";
import { useEffect, useMemo, useState } from "react";
import { createAdminClient, workflowStatuses, type LexemeInput, type WorkflowStatus } from "../../lib/api";
import { useApiKey } from "../../lib/storage";

export default function LexemeListPage() {
  const { apiKey, loaded } = useApiKey();
  const [query, setQuery] = useState("");
  const [status, setStatus] = useState<WorkflowStatus | "">("");
  const [items, setItems] = useState<LexemeInput[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const client = useMemo(() => (apiKey ? createAdminClient(apiKey) : null), [apiKey]);

  useEffect(() => {
    if (!client) {
      return;
    }
    let cancelled = false;
    const run = async () => {
      setLoading(true);
      setError(null);
      try {
        const data = await client.listLexemes(query || undefined, status || undefined);
        if (!cancelled) {
          setItems(data);
        }
      } catch (err) {
        if (!cancelled) {
          setError("Failed to load lexemes.");
        }
      } finally {
        if (!cancelled) {
          setLoading(false);
        }
      }
    };
    run();
    return () => {
      cancelled = true;
    };
  }, [client, query, status]);

  if (!loaded) {
    return <p>Loading...</p>;
  }

  if (!apiKey) {
    return (
      <div className="card">
        <p>
          API key missing. <Link href="/login">Add your API key</Link> to manage lexemes.
        </p>
      </div>
    );
  }

  return (
    <section className="stack">
      <div className="header-row">
        <div>
          <h1>Lexemes</h1>
          <p className="muted">Search by lemma, filter by workflow status.</p>
        </div>
        <Link className="button primary" href="/lexemes/new">
          New lexeme
        </Link>
      </div>
      <div className="filters">
        <label className="field">
          <span>Search</span>
          <input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Search lemma" />
        </label>
        <label className="field">
          <span>Status</span>
          <select value={status} onChange={(event) => setStatus(event.target.value as WorkflowStatus | "")}> 
            <option value="">All</option>
            {workflowStatuses.map((option) => (
              <option key={option} value={option}>
                {option}
              </option>
            ))}
          </select>
        </label>
      </div>
      {loading && <p>Loading lexemes...</p>}
      {error && <p className="error">{error}</p>}
      <div className="table">
        <div className="table-row table-head">
          <span>Lemma</span>
          <span>POS</span>
          <span>Status</span>
          <span>Senses</span>
          <span></span>
        </div>
        {items.map((lexeme) => (
          <div key={lexeme.id ?? lexeme.lemma} className="table-row">
            <span>{lexeme.lemma}</span>
            <span>{lexeme.part_of_speech || "-"}</span>
            <span className={`status ${lexeme.status}`}>{lexeme.status}</span>
            <span>{lexeme.senses?.length ?? 0}</span>
            <span>
              <Link href={`/lexemes/${lexeme.id}`}>Edit</Link>
            </span>
          </div>
        ))}
        {!loading && items.length === 0 && <p className="muted">No lexemes found.</p>}
      </div>
    </section>
  );
}
