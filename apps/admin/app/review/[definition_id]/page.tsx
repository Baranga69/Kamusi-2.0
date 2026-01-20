"use client";

import { useEffect, useMemo, useState } from "react";
import Link from "next/link";
import { useParams } from "next/navigation";
import axios from "axios";

import { createAdminClient, type ReviewDetail } from "../../../lib/api";
import { useApiKey, useReviewerName } from "../../../lib/storage";

type DiffToken = { text: string; type: "same" | "added" | "removed" };

const hasConflict = (error: unknown) => axios.isAxiosError(error) && error.response?.status === 409;

const formatDate = (value?: string | null) => {
  if (!value) {
    return "N/A";
  }
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    return value;
  }
  return date.toLocaleString();
};

const tokenize = (value: string) => value.trim().split(/\s+/).filter(Boolean);

const buildDiff = (original: string, updated: string) => {
  // Simple word-level LCS diff to highlight changes without external deps.
  const a = tokenize(original);
  const b = tokenize(updated);
  const dp: number[][] = Array.from({ length: a.length + 1 }, () => Array(b.length + 1).fill(0));

  for (let i = 1; i <= a.length; i += 1) {
    for (let j = 1; j <= b.length; j += 1) {
      if (a[i - 1] === b[j - 1]) {
        dp[i][j] = dp[i - 1][j - 1] + 1;
      } else {
        dp[i][j] = Math.max(dp[i - 1][j], dp[i][j - 1]);
      }
    }
  }

  const originalTokens: DiffToken[] = [];
  const updatedTokens: DiffToken[] = [];
  let i = a.length;
  let j = b.length;

  while (i > 0 || j > 0) {
    if (i > 0 && j > 0 && a[i - 1] === b[j - 1]) {
      const token = a[i - 1];
      originalTokens.unshift({ text: token, type: "same" });
      updatedTokens.unshift({ text: token, type: "same" });
      i -= 1;
      j -= 1;
    } else if (j > 0 && (i === 0 || dp[i][j - 1] >= dp[i - 1][j])) {
      const token = b[j - 1];
      updatedTokens.unshift({ text: token, type: "added" });
      j -= 1;
    } else if (i > 0) {
      const token = a[i - 1];
      originalTokens.unshift({ text: token, type: "removed" });
      i -= 1;
    }
  }

  return { originalTokens, updatedTokens };
};

export default function ReviewDetailPage() {
  const params = useParams<{ definition_id: string }>();
  const definitionId = params.definition_id;
  const { apiKey, loaded } = useApiKey();
  const { reviewer, setReviewer } = useReviewerName();
  const [detail, setDetail] = useState<ReviewDetail | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [toast, setToast] = useState<string | null>(null);
  const [editDefinition, setEditDefinition] = useState("");
  const [editGloss, setEditGloss] = useState("");
  const [editLoading, setEditLoading] = useState(false);
  const [rejecting, setRejecting] = useState(false);
  const [rejectReason, setRejectReason] = useState("");
  const [rejectNote, setRejectNote] = useState("");

  const client = useMemo(() => (apiKey ? createAdminClient(apiKey) : null), [apiKey]);

  useEffect(() => {
    if (!toast) {
      return;
    }
    const timer = window.setTimeout(() => setToast(null), 3200);
    return () => window.clearTimeout(timer);
  }, [toast]);

  const ensureReviewer = () => {
    if (!reviewer.trim()) {
      setToast("Add your reviewer name before taking action.");
      return false;
    }
    return true;
  };

  const resetReject = () => {
    setRejecting(false);
    setRejectReason("");
    setRejectNote("");
  };

  const fetchDetail = async () => {
    if (!client || !definitionId) {
      return;
    }
    setLoading(true);
    setError(null);
    try {
      const data = await client.getReviewItem(definitionId);
      setDetail(data);
      setEditDefinition(data.sw_definition);
      setEditGloss(data.sw_gloss ?? "");
    } catch (err) {
      setError("Failed to load review detail.");
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    void fetchDetail();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [client, definitionId]);

  const handleApprove = async () => {
    if (!client || !ensureReviewer()) {
      return;
    }
    try {
      await client.approveReviewItem(definitionId, reviewer.trim());
      setToast("Definition approved.");
      await fetchDetail();
    } catch (err) {
      if (hasConflict(err)) {
        setToast("Already reviewed elsewhere. Refreshing detail.");
        await fetchDetail();
        return;
      }
      setToast("Failed to approve definition.");
    }
  };

  const submitEdit = async () => {
    if (!client || !ensureReviewer()) {
      return;
    }
    if (!editDefinition.trim()) {
      setToast("Definition is required.");
      return;
    }
    setEditLoading(true);
    try {
      await client.editReviewItem(definitionId, {
        reviewer: reviewer.trim(),
        definition: editDefinition.trim(),
        gloss: editGloss.trim() ? editGloss.trim() : undefined,
      });
      setToast("Definition updated.");
      await fetchDetail();
    } catch (err) {
      if (hasConflict(err)) {
        setToast("Already reviewed elsewhere. Refreshing detail.");
        await fetchDetail();
        return;
      }
      setToast("Failed to update definition.");
    } finally {
      setEditLoading(false);
    }
  };

  const submitReject = async () => {
    if (!client || !ensureReviewer()) {
      return;
    }
    if (!rejectReason.trim()) {
      setToast("Select a reject reason.");
      return;
    }
    try {
      await client.rejectReviewItem(definitionId, {
        reviewer: reviewer.trim(),
        reason: rejectReason.trim(),
        note: rejectNote || undefined,
      });
      setToast("Definition rejected.");
      resetReject();
      await fetchDetail();
    } catch (err) {
      if (hasConflict(err)) {
        setToast("Already reviewed elsewhere. Refreshing detail.");
        await fetchDetail();
        resetReject();
        return;
      }
      setToast("Failed to reject definition.");
    }
  };

  const diff = useMemo(() => {
    if (!detail) {
      return null;
    }
    return buildDiff(detail.sw_definition, editDefinition);
  }, [detail, editDefinition]);

  if (!loaded) {
    return <p>Loading...</p>;
  }

  if (!apiKey) {
    return (
      <div className="card">
        <p>API key missing. Add your API key to review AI definitions.</p>
      </div>
    );
  }

  const reviewStatus = detail?.review_status ?? "unreviewed";
  const isEditable = reviewStatus === "unreviewed";

  return (
    <section className="stack">
      <div className="header-row">
        <div>
          <h1>{detail?.lemma ?? "Review detail"}</h1>
          <p className="muted">Sense definition review detail.</p>
        </div>
        <div className="actions">
          <Link className="button ghost" href="/review">
            Back to queue
          </Link>
        </div>
      </div>
      {toast && <div className="alert">{toast}</div>}
      {error && <p className="error">{error}</p>}
      {loading && <p>Loading detail...</p>}
      {detail && (
        <>
          <div className="review-detail-grid">
            <div className="card stack">
              <div className="status-row">
                {detail.is_ai_generated && <span className="badge badge-ai">AI Draft</span>}
                {detail.review_status && (
                  <span className={`badge badge-${detail.review_status}`}>{detail.review_status}</span>
                )}
              </div>
              <div className="grid two">
                <div>
                  <p className="muted">Lemma</p>
                  <strong>{detail.lemma}</strong>
                </div>
                <div>
                  <p className="muted">POS</p>
                  <strong>{detail.pos_code}</strong>
                </div>
                <div>
                  <p className="muted">Created</p>
                  <strong>{formatDate(detail.created_at)}</strong>
                </div>
                <div>
                  <p className="muted">Definition ID</p>
                  <strong>{detail.sense_definition_id}</strong>
                </div>
              </div>
              {detail.source && (
                <div className="stack">
                  <p className="muted">Source</p>
                  <strong>{detail.source.title}</strong>
                  {detail.source.author && <span className="muted">{detail.source.author}</span>}
                  {detail.source.url && (
                    <a className="link" href={detail.source.url} target="_blank" rel="noreferrer">
                      {detail.source.url}
                    </a>
                  )}
                </div>
              )}
            </div>
            <div className="card stack">
              <h3>Audit</h3>
              <div className="grid two">
                <div>
                  <p className="muted">Reviewed by</p>
                  <strong>{detail.reviewed_by || "N/A"}</strong>
                </div>
                <div>
                  <p className="muted">Reviewed at</p>
                  <strong>{formatDate(detail.reviewed_at)}</strong>
                </div>
                <div className="span-2">
                  <p className="muted">Review note</p>
                  <p>{detail.review_note || "N/A"}</p>
                </div>
              </div>
              <label className="field">
                <span>Reviewer name</span>
                <input value={reviewer} onChange={(event) => setReviewer(event.target.value)} placeholder="Reviewer" />
              </label>
              <div className="actions">
                <button className="primary" onClick={handleApprove} disabled={!isEditable}>
                  Approve
                </button>
                <button className="secondary" onClick={() => setRejecting(true)} disabled={!isEditable}>
                  Reject
                </button>
              </div>
            </div>
          </div>
          <div className="review-detail-grid">
            <div className="card stack">
              <h3>Current definition</h3>
              <p className="muted">Swahili</p>
              <p>{detail.sw_definition}</p>
              {detail.sw_gloss && (
                <>
                  <p className="muted">Gloss</p>
                  <p>{detail.sw_gloss}</p>
                </>
              )}
              <div className="stack">
                <h3>English references</h3>
                {detail.en_definitions.length === 0 ? (
                  <p className="muted">No English references.</p>
                ) : (
                  <ul>
                    {detail.en_definitions.map((entry) => (
                      <li key={entry.id}>{entry.definition}</li>
                    ))}
                  </ul>
                )}
              </div>
            </div>
            <div className="card stack">
              <h3>Edit draft</h3>
              <label className="field">
                <span>Swahili definition</span>
                <textarea
                  value={editDefinition}
                  onChange={(event) => setEditDefinition(event.target.value)}
                  disabled={!isEditable || editLoading}
                />
              </label>
              <label className="field">
                <span>Gloss (optional)</span>
                <input
                  value={editGloss}
                  onChange={(event) => setEditGloss(event.target.value)}
                  disabled={!isEditable || editLoading}
                />
              </label>
              <div className="actions">
                <button className="secondary" onClick={submitEdit} disabled={!isEditable || editLoading}>
                  Save edit
                </button>
              </div>
              {diff && (
                <div className="diff-panel">
                  <h3>Diff preview</h3>
                  <div className="review-detail-grid">
                    <div>
                      <p className="muted">Original</p>
                      <p className="diff-block">
                        {diff.originalTokens.length === 0 && <span className="muted">N/A</span>}
                        {diff.originalTokens.map((token, index) => (
                          <span key={`${token.text}-${index}`} className={`diff-token ${token.type}`}>
                            {token.text}{" "}
                          </span>
                        ))}
                      </p>
                    </div>
                    <div>
                      <p className="muted">Edited</p>
                      <p className="diff-block">
                        {diff.updatedTokens.length === 0 && <span className="muted">N/A</span>}
                        {diff.updatedTokens.map((token, index) => (
                          <span key={`${token.text}-${index}`} className={`diff-token ${token.type}`}>
                            {token.text}{" "}
                          </span>
                        ))}
                      </p>
                    </div>
                  </div>
                </div>
              )}
            </div>
          </div>
        </>
      )}
      {rejecting && (
        <div className="modal-backdrop">
          <div className="modal card">
            <h3>Reject definition</h3>
            <div className="stack">
              <label className="field">
                <span>Reason</span>
                <select value={rejectReason} onChange={(event) => setRejectReason(event.target.value)}>
                  <option value="">Select reason</option>
                  <option value="Not Swahili">Not Swahili</option>
                  <option value="Low quality">Low quality</option>
                  <option value="Incorrect meaning">Incorrect meaning</option>
                  <option value="Duplicate">Duplicate</option>
                  <option value="Other">Other</option>
                </select>
              </label>
              <label className="field">
                <span>Optional note</span>
                <textarea value={rejectNote} onChange={(event) => setRejectNote(event.target.value)} />
              </label>
              <div className="actions">
                <button className="secondary" onClick={submitReject}>
                  Confirm reject
                </button>
                <button className="ghost" onClick={resetReject}>
                  Cancel
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </section>
  );
}
