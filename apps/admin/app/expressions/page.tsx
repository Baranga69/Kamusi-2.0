"use client";

import Link from "next/link";
import { useEffect, useMemo, useState } from "react";
import {
  createAdminClient,
  workflowStatuses,
  type ExpressionInput,
  type WorkflowStatus,
} from "../../lib/api";
import { useApiKey } from "../../lib/storage";

export default function ExpressionListPage() {
  const { apiKey, loaded } = useApiKey();
  const [query, setQuery] = useState("");
  const [status, setStatus] = useState<WorkflowStatus | "">("");
  const [items, setItems] = useState<ExpressionInput[]>([]);
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
        const data = await client.listExpressions(query || undefined, status || undefined);
        if (!cancelled) {
          setItems(data);
        }
      } catch (err) {
        if (!cancelled) {
          setError("Failed to load expressions.");
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
          API key missing. <Link href="/login">Add your API key</Link> to manage expressions.
        </p>
      </div>
    );
  }

  return (
    <section className="stack">
      <div className="header-row">
        <div>
          <h1>Expressions</h1>
          <p className="muted">Methali, semi, and nahau entries.</p>
        </div>
        <Link className="button primary" href="/expressions/new">
          New expression
        </Link>
      </div>
      <div className="filters">
        <label className="field">
          <span>Search</span>
          <input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Search text" />
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
      {loading && <p>Loading expressions...</p>}
      {error && <p className="error">{error}</p>}
      <div className="table">
        <div className="table-row table-head">
          <span>Text</span>
          <span>Type</span>
          <span>Status</span>
          <span></span>
        </div>
        {items.map((expression) => (
          <div key={expression.id ?? expression.text} className="table-row">
            <span>{expression.text}</span>
            <span>{expression.expression_type || "-"}</span>
            <span className={`status ${expression.status}`}>{expression.status}</span>
            <span>
              <Link href={`/expressions/${expression.id}`}>Edit</Link>
            </span>
          </div>
        ))}
        {!loading && items.length === 0 && <p className="muted">No expressions found.</p>}
      </div>
    </section>
  );
}
