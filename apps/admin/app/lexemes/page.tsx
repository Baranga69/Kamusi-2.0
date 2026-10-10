"use client";

import Link from "next/link";
import { useEffect, useMemo, useState } from "react";
import {
  adminClient,
  workflowStatuses,
  type LexemeListItem,
  type WorkflowStatus,
} from "../../lib/api";
import { useSession } from "../../lib/session";

/**
 * Publication readiness, judged from the list projection alone.
 *
 * The list endpoint returns counts rather than nested senses, so this is a
 * coarse screen: it catches entries that cannot be published yet. The full
 * readiness checks live on the editor page, which has the whole aggregate.
 */
const readinessIssue = (lexeme: LexemeListItem): string | null => {
  if (!lexeme.lemma || lexeme.lemma.trim().length < 2) {
    return "Lemma too short";
  }
  if (!lexeme.pos_code) {
    return "No part of speech";
  }
  if (lexeme.sense_count === 0) {
    return "No senses";
  }
  if (lexeme.sw_definition_count === 0) {
    return "No Swahili definition";
  }
  return null;
};

export default function LexemeListPage() {
  const { user, loading: sessionLoading } = useSession();
  const [query, setQuery] = useState("");
  const [status, setStatus] = useState<WorkflowStatus | "">("");
  const [partOfSpeech, setPartOfSpeech] = useState("");
  const [hasIssues, setHasIssues] = useState(false);
  const [items, setItems] = useState<LexemeListItem[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const client = adminClient;

  useEffect(() => {
    if (!client) {
      return;
    }
    let cancelled = false;
    // Debounce so typing in the search box does not fire a request per keystroke.
    const timer = window.setTimeout(async () => {
      setLoading(true);
      setError(null);
      try {
        const data = await client.listLexemes(
          query || undefined,
          status || undefined,
          partOfSpeech || undefined
        );
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
    }, 250);
    return () => {
      cancelled = true;
      window.clearTimeout(timer);
    };
  }, [client, query, status, partOfSpeech]);

  const posOptions = useMemo(
    () => [...new Set(items.map((item) => item.pos_code).filter(Boolean))] as string[],
    [items]
  );

  const visible = useMemo(
    () => (hasIssues ? items.filter((item) => readinessIssue(item) !== null) : items),
    [items, hasIssues]
  );

  if (sessionLoading) {
    return <p>Loading...</p>;
  }

  if (!user) {
    return (
      <div className="card">
        <p>
          Not signed in. <Link href="/login">Sign in</Link> to manage lexemes.
        </p>
      </div>
    );
  }

  return (
    <section className="stack">
      <div className="header-row">
        <div>
          <h1>Lexemes</h1>
          <p className="muted">Search by lemma, filter by workflow status, POS, and issues.</p>
        </div>
        <Link className="button primary" href="/lexemes/new">
          Create lexeme
        </Link>
      </div>
      <div className="filters">
        <label className="field">
          <span>Search</span>
          <input
            value={query}
            onChange={(event) => setQuery(event.target.value)}
            placeholder="Search lemma"
          />
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
        <label className="field">
          <span>Part of speech</span>
          <select value={partOfSpeech} onChange={(event) => setPartOfSpeech(event.target.value)}>
            <option value="">All</option>
            {posOptions.map((pos) => (
              <option key={pos} value={pos}>
                {pos}
              </option>
            ))}
          </select>
        </label>
        <label className="checkbox">
          <input
            type="checkbox"
            checked={hasIssues}
            onChange={(event) => setHasIssues(event.target.checked)}
          />
          Has issues
        </label>
      </div>
      {loading && <p>Loading lexemes...</p>}
      {error && <p className="error">{error}</p>}
      <div className="table">
        <div className="table-row table-head">
          <span>Lemma</span>
          <span>POS</span>
          <span>Workflow</span>
          <span>Senses</span>
          <span>Readiness</span>
          <span></span>
        </div>
        {visible.map((lexeme) => {
          const issue = readinessIssue(lexeme);
          return (
            <div key={lexeme.id} className="table-row">
              <span>{lexeme.lemma}</span>
              <span>{lexeme.pos_code || "-"}</span>
              <span className={`status ${lexeme.workflow}`}>{lexeme.workflow}</span>
              <span>
                {lexeme.sense_count} ({lexeme.sw_definition_count} sw)
              </span>
              <span>{issue ? `⚠️ ${issue}` : "✓ Ready"}</span>
              <span>
                <Link href={`/lexemes/${lexeme.id}`}>Edit</Link>
              </span>
            </div>
          );
        })}
        {!loading && visible.length === 0 && <p className="muted">No lexemes found.</p>}
      </div>
    </section>
  );
}
