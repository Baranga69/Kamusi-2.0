"use client";

import { useEffect, useMemo, useState } from "react";
import { useParams, useRouter } from "next/navigation";
import axios from "axios";
import {
  createAdminClient,
  type ReviewDetail,
  type ReviewStatus,
} from "../../../lib/api";
import { useApiKey, useReviewerName } from "../../../lib/storage";
import { isEnglishy, isTooLong } from "../utils";

const hasConflict = (error: unknown) => axios.isAxiosError(error) && error.response?.status === 409;

export default function ReviewDetailPage() {
  const params = useParams<{ sense_definition_id: string }>();
  const router = useRouter();
  const { apiKey, loaded } = useApiKey();
  const { reviewer, setReviewer } = useReviewerName();
  const [item, setItem] = useState<ReviewDetail | null>(null);
  const [definition, setDefinition] = useState("");
  const [gloss, setGloss] = useState("");
  const [loading, setLoading] = useState(false);
  const [saving, setSaving] = useState(false);
  const [toast, setToast] = useState<string | null>(null);
  const [rejecting, setRejecting] = useState(false);
  const [rejectReason, setRejectReason] = useState("");
  const [rejectNote, setRejectNote] = useState("");

  const client = useMemo(() => (apiKey ? createAdminClient(apiKey) : null), [apiKey]);
  const definitionId = params?.sense_definition_id;

  useEffect(() => {
    if (!toast) {
      return;
    }
    const timer = window.setTimeout(() => setToast(null), 3200);
    return () => window.clearTimeout(timer);
  }, [toast]);

  const fetchItem = async () => {
    if (!client || !definitionId) {
      return;
    }
    setLoading(true);
    try {
      const data = await client.getReviewItem(definitionId);
      setItem(data);
      setDefinition(data.sw_definition ?? "");
      setGloss(data.sw_gloss ?? "");
    } catch (err) {
      setToast("Failed to load review item.");
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    void fetchItem();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [client, definitionId]);

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

  const ensureReviewer = () => {
    if (!reviewer.trim()) {
      setToast("Add your reviewer name before taking action.");
      return false;
    }
    return true;
  };

  const handleApprove = async () => {
    if (!client || !item || !ensureReviewer()) {
      return;
    }
    setSaving(true);
    try {
      await client.approveReviewItem(item.sense_definition_id, reviewer.trim());
      setToast("Definition approved.");
      await fetchItem();
    } catch (err) {
      if (hasConflict(err)) {
        setToast("Already reviewed elsewhere. Refreshing item.");
        await fetchItem();
        return;
      }
      setToast("Failed to approve definition.");
    } finally {
      setSaving(false);
    }
  };

  const handleEditApprove = async () => {
    if (!client || !item || !ensureReviewer()) {
      return;
    }
    const trimmedDefinition = definition.trim();
    if (!trimmedDefinition) {
      setToast("Swahili definition cannot be empty.");
      return;
    }
    setSaving(true);
    try {
      await client.editReviewItem(item.sense_definition_id, {
        reviewer: reviewer.trim(),
        definition: trimmedDefinition,
        gloss: gloss.trim() || undefined,
      });
      setToast("Edits saved and approved.");
      await fetchItem();
    } catch (err) {
      if (hasConflict(err)) {
        setToast("Already reviewed elsewhere. Refreshing item.");
        await fetchItem();
        return;
      }
      setToast("Failed to save edits.");
    } finally {
      setSaving(false);
    }
  };

  const handleReject = async () => {
    if (!client || !item || !ensureReviewer()) {
      return;
    }
    if (!rejectReason.trim()) {
      setToast("Select a reject reason.");
      return;
    }
    setSaving(true);
    try {
      await client.rejectReviewItem(item.sense_definition_id, {
        reviewer: reviewer.trim(),
        reason: rejectReason.trim(),
        note: rejectNote || undefined,
      });
      setToast("Definition rejected.");
      setRejecting(false);
      await fetchItem();
    } catch (err) {
      if (hasConflict(err)) {
        setToast("Already reviewed elsewhere. Refreshing item.");
        await fetchItem();
        setRejecting(false);
        return;
      }
      setToast("Failed to reject definition.");
    } finally {
      setSaving(false);
    }
  };

  const handleNext = async () => {
    if (!client) {
      return;
    }
    try {
      const queue = await client.listReviewQueue({ status: "unreviewed" as ReviewStatus, limit: 1, sort: "oldest" });
      if (queue.length === 0) {
        setToast("No more unreviewed items.");
        return;
      }
      router.push(`/review/${queue[0].sense_definition_id}`);
    } catch (err) {
      setToast("Failed to load next item.");
    }
  };

  const status = item?.review_status ?? "unreviewed";
  const englishWarning = isEnglishy(definition);
  const lengthWarning = isTooLong(definition);

  return (
    <section className="stack">
      <div className="header-row">
        <div>
          <h1>Review detail</h1>
          <p className="muted">Swahili AI definition review and editing workflow.</p>
        </div>
        <div className="status-row">
          {item?.is_ai_generated && <span className="badge badge-ai">AI Draft</span>}
          <span className={`badge badge-${status}`}>{status}</span>
        </div>
      </div>
      <label className="field">
        <span>Reviewer name</span>
        <input value={reviewer} onChange={(event) => setReviewer(event.target.value)} placeholder="Reviewer" />
      </label>
      {toast && <div className="alert">{toast}</div>}
      {loading && <p>Loading item...</p>}
      {item && (
        <div className="review-detail-grid">
          <div className="card stack">
            <div>
              <h2>{item.lemma}</h2>
              <p className="muted">{item.pos_code}</p>
            </div>
            <div className="stack">
              <h3>English reference</h3>
              {item.en_definitions.length === 0 && <p className="muted">No English definition available.</p>}
              {item.en_definitions.map((definition) => (
                <div key={definition.id} className="card nested">
                  <p>{definition.definition}</p>
                  {definition.gloss && <p className="muted">Gloss: {definition.gloss}</p>}
                </div>
              ))}
            </div>
            {item.source && (
              <div className="card nested">
                <h3>Source</h3>
                <p>{item.source.title}</p>
                <p className="muted">
                  {item.source.author || "Unknown author"}
                  {item.source.year ? ` · ${item.source.year}` : ""}
                </p>
                {item.source.url && (
                  <a href={item.source.url} target="_blank" rel="noreferrer" className="link">
                    Open source
                  </a>
                )}
              </div>
            )}
          </div>
          <div className="card stack">
            <div>
              <h3>Swahili definition</h3>
              <p className="muted">Edit the Swahili definition and gloss before approval.</p>
            </div>
            <label className="field">
              <span>Definition (required)</span>
              <textarea value={definition} onChange={(event) => setDefinition(event.target.value)} />
            </label>
            <label className="field">
              <span>Gloss</span>
              <input value={gloss} onChange={(event) => setGloss(event.target.value)} />
            </label>
            {lengthWarning && <p className="warning">Definition is longer than 180 characters.</p>}
            {englishWarning && <p className="warning">Definition looks English-heavy. Please verify.</p>}
            <div className="actions">
              <button className="primary" onClick={handleApprove} disabled={saving || status !== "unreviewed"}>
                Approve
              </button>
              <button className="secondary" onClick={handleEditApprove} disabled={saving || status !== "unreviewed"}>
                Save edits & approve
              </button>
              <button className="ghost" onClick={() => setRejecting(true)} disabled={saving || status !== "unreviewed"}>
                Reject
              </button>
              <button className="ghost" onClick={handleNext}>
                Next
              </button>
            </div>
          </div>
        </div>
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
                <button className="secondary" onClick={handleReject} disabled={saving}>
                  Confirm reject
                </button>
                <button className="ghost" onClick={() => setRejecting(false)} disabled={saving}>
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
