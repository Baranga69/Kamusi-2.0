"use client";

import { useEffect, useMemo, useState } from "react";
import axios from "axios";

import ReviewQueueTable from "../api/review/components/ReviewQueueTable";
import { createAdminClient, type ReviewQueueItem, type ReviewStatus } from "../../lib/api";
import { useApiKey, useReviewerName } from "../../lib/storage";

const tabs = [
  { key: "unreviewed", label: "Needs Review" },
  { key: "reviewed", label: "Reviewed" },
  { key: "rejected", label: "Rejected" },
  { key: "morphology", label: "Morphology lane" },
] as const;

type TabKey = (typeof tabs)[number]["key"];

const lexemeStatuses = ["core", "slang", "regional", "deprecated", "neologism"] as const;

const hasConflict = (error: unknown) => axios.isAxiosError(error) && error.response?.status === 409;

export default function ReviewQueuePage() {
  const { apiKey, loaded } = useApiKey();
  const { reviewer, setReviewer } = useReviewerName();
  const [activeTab, setActiveTab] = useState<TabKey>("unreviewed");
  const [query, setQuery] = useState("");
  const [posCode, setPosCode] = useState("");
  const [lexemeStatus, setLexemeStatus] = useState("");
  const [aiOnly, setAiOnly] = useState(false);
  const [languageFilter, setLanguageFilter] = useState<"all" | "has_en" | "sw_only">("all");
  const [sort, setSort] = useState<"oldest" | "newest" | "lemma">("oldest");
  const [limit, setLimit] = useState(20);
  const [offset, setOffset] = useState(0);
  const [items, setItems] = useState<ReviewQueueItem[]>([]);
  const [selectedIds, setSelectedIds] = useState<Set<string>>(new Set());
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [toast, setToast] = useState<string | null>(null);
  const [rejectingIds, setRejectingIds] = useState<string[] | null>(null);
  const [rejectReason, setRejectReason] = useState("");
  const [rejectNote, setRejectNote] = useState("");
  const [rejectSingle, setRejectSingle] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [editDefinition, setEditDefinition] = useState("");
  const [editGloss, setEditGloss] = useState("");
  const [editLoading, setEditLoading] = useState(false);

  const client = useMemo(() => (apiKey ? createAdminClient(apiKey) : null), [apiKey]);

  const filteredItems = useMemo(() => {
    return items.filter((item) => {
      if (aiOnly && !item.is_ai_generated) {
        return false;
      }
      const hasEnglish = Boolean(item.en_definition_preview?.trim());
      if (languageFilter === "has_en" && !hasEnglish) {
        return false;
      }
      if (languageFilter === "sw_only" && hasEnglish) {
        return false;
      }
      return true;
    });
  }, [items, aiOnly, languageFilter]);

  useEffect(() => {
    if (!toast) {
      return;
    }
    const timer = window.setTimeout(() => setToast(null), 3200);
    return () => window.clearTimeout(timer);
  }, [toast]);

  const resetReject = () => {
    setRejectingIds(null);
    setRejectReason("");
    setRejectNote("");
    setRejectSingle(false);
  };

  const resetEdit = () => {
    setEditingId(null);
    setEditDefinition("");
    setEditGloss("");
    setEditLoading(false);
  };

  const ensureReviewer = () => {
    if (!reviewer.trim()) {
      setToast("Add your reviewer name before taking action.");
      return false;
    }
    return true;
  };

  const fetchQueue = async () => {
    if (!client) {
      return;
    }
    setLoading(true);
    setError(null);
    const status: ReviewStatus | undefined =
      activeTab === "morphology" ? "unreviewed" : (activeTab as ReviewStatus);
    try {
      const data = await client.listReviewQueue({
        status,
        q: query || undefined,
        pos_code: posCode || undefined,
        lexeme_status: lexemeStatus || undefined,
        sort,
        limit,
        offset,
      });
      const filtered = activeTab === "morphology" ? data.filter((item) => item.morphology_like) : data;
      setItems(filtered);
      setSelectedIds(new Set());
    } catch (err) {
      setError("Failed to load review queue.");
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    void fetchQueue();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [client, activeTab, query, posCode, lexemeStatus, sort, limit, offset]);

  const toggleSelection = (id: string) => {
    setSelectedIds((prev) => {
      const next = new Set(prev);
      if (next.has(id)) {
        next.delete(id);
      } else {
        next.add(id);
      }
      return next;
    });
  };

  const handleApprove = async (id: string) => {
    if (!client || !ensureReviewer()) {
      return;
    }
    try {
      await client.approveReviewItem(id, reviewer.trim());
      setToast("Definition approved.");
      await fetchQueue();
    } catch (err) {
      if (hasConflict(err)) {
        setToast("Already reviewed elsewhere. Refreshing queue.");
        await fetchQueue();
        return;
      }
      setToast("Failed to approve definition.");
    }
  };

  const handleBulkApprove = async () => {
    if (!client || !ensureReviewer()) {
      return;
    }
    const ids = filteredItems
      .filter((item) => selectedIds.has(item.sense_definition_id))
      .map((item) => item.sense_definition_id);
    if (ids.length === 0) {
      setToast("Select items to approve.");
      return;
    }
    try {
      const result = await client.bulkReview({ reviewer: reviewer.trim(), action: "approve", ids });
      setToast(`Approved ${result.updated_count}. Skipped ${result.skipped_count}.`);
      await fetchQueue();
    } catch (err) {
      setToast("Failed to approve selected items.");
    }
  };

  const startReject = (ids: string[], single: boolean) => {
    if (!ensureReviewer()) {
      return;
    }
    setRejectingIds(ids);
    setRejectSingle(single);
  };

  const submitReject = async () => {
    if (!client || !rejectingIds) {
      return;
    }
    if (!rejectReason.trim()) {
      setToast("Select a reject reason.");
      return;
    }
    try {
      if (rejectSingle && rejectingIds.length === 1) {
        await client.rejectReviewItem(rejectingIds[0], {
          reviewer: reviewer.trim(),
          reason: rejectReason.trim(),
          note: rejectNote || undefined,
        });
      } else {
        const result = await client.bulkReview({
          reviewer: reviewer.trim(),
          action: "reject",
          ids: rejectingIds,
          reason: rejectReason.trim(),
          note: rejectNote || undefined,
        });
        setToast(`Rejected ${result.updated_count}. Skipped ${result.skipped_count}.`);
      }
      resetReject();
      await fetchQueue();
    } catch (err) {
      if (hasConflict(err)) {
        setToast("Already reviewed elsewhere. Refreshing queue.");
        await fetchQueue();
        resetReject();
        return;
      }
      setToast("Failed to reject definitions.");
    }
  };

  const startEdit = async (item: ReviewQueueItem) => {
    if (!client || !ensureReviewer()) {
      return;
    }
    setEditingId(item.sense_definition_id);
    setEditDefinition(item.sw_definition_preview);
    setEditGloss("");
    setEditLoading(true);
    try {
      const detail = await client.getReviewItem(item.sense_definition_id);
      setEditDefinition(detail.sw_definition);
      setEditGloss(detail.sw_gloss ?? "");
    } catch (err) {
      setToast("Failed to load definition details. Editing preview instead.");
    } finally {
      setEditLoading(false);
    }
  };

  const submitEdit = async () => {
    if (!client || !editingId) {
      return;
    }
    if (!editDefinition.trim()) {
      setToast("Definition is required.");
      return;
    }
    setEditLoading(true);
    try {
      await client.editReviewItem(editingId, {
        reviewer: reviewer.trim(),
        definition: editDefinition.trim(),
        gloss: editGloss.trim() ? editGloss.trim() : undefined,
      });
      setToast("Definition updated.");
      resetEdit();
      await fetchQueue();
    } catch (err) {
      if (hasConflict(err)) {
        setToast("Already reviewed elsewhere. Refreshing queue.");
        await fetchQueue();
        resetEdit();
        return;
      }
      setToast("Failed to update definition.");
    } finally {
      setEditLoading(false);
    }
  };

  const visibleSelectedIds = filteredItems
    .filter((item) => selectedIds.has(item.sense_definition_id))
    .map((item) => item.sense_definition_id);
  const visibleSelectedCount = visibleSelectedIds.length;
  const allVisibleSelected = filteredItems.length > 0 && visibleSelectedCount === filteredItems.length;
  const someVisibleSelected = visibleSelectedCount > 0 && !allVisibleSelected;
  const aiCount = items.filter((item) => item.is_ai_generated).length;

  const toggleSelectAllVisible = () => {
    setSelectedIds((prev) => {
      const next = new Set(prev);
      if (allVisibleSelected) {
        filteredItems.forEach((item) => next.delete(item.sense_definition_id));
        return next;
      }
      filteredItems.forEach((item) => next.add(item.sense_definition_id));
      return next;
    });
  };

  useEffect(() => {
    const handler = (event: KeyboardEvent) => {
      if (rejectingIds || editingId) {
        return;
      }
      if (event.metaKey || event.ctrlKey || event.altKey) {
        return;
      }
      const target = event.target as HTMLElement | null;
      if (target) {
        const tag = target.tagName.toLowerCase();
        if (tag === "input" || tag === "textarea" || tag === "select" || target.isContentEditable) {
          return;
        }
      }
      const key = event.key.toLowerCase();
      if (!["a", "e", "r"].includes(key)) {
        return;
      }
      event.preventDefault();
      if (visibleSelectedIds.length === 0) {
        setToast("Select items to use shortcuts.");
        return;
      }
      if (key === "a") {
        if (visibleSelectedIds.length === 1) {
          const id = visibleSelectedIds[0];
          void handleApprove(id);
        } else {
          void handleBulkApprove();
        }
        return;
      }
      if (key === "e") {
        if (visibleSelectedIds.length !== 1) {
          setToast("Select a single item to edit.");
          return;
        }
        const id = visibleSelectedIds[0];
        const item = items.find((entry) => entry.sense_definition_id === id);
        if (!item) {
          setToast("Selected item is not on this page.");
          return;
        }
        void startEdit(item);
        return;
      }
      if (key === "r") {
        startReject(visibleSelectedIds, visibleSelectedIds.length === 1);
      }
    };
    window.addEventListener("keydown", handler);
    return () => window.removeEventListener("keydown", handler);
  }, [
    visibleSelectedIds,
    items,
    rejectingIds,
    editingId,
    handleApprove,
    handleBulkApprove,
    startEdit,
    startReject,
  ]);

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

  return (
    <section className="stack">
      <div className="review-header">
        <div className="header-row">
          <div>
            <h1>AI Definition Review Queue</h1>
            <p className="muted">Focus on Swahili AI drafts awaiting lexicography review.</p>
          </div>
          <div className="review-counts">
            <span className="chip">Loaded {items.length}</span>
            <span className="chip">Visible {filteredItems.length}</span>
          <span className="chip">Selected {visibleSelectedCount}</span>
            <span className="chip">AI {aiCount}</span>
          </div>
        </div>
        <div className="review-toolbar">
          <label className="field">
            <span>Reviewer name</span>
            <input value={reviewer} onChange={(event) => setReviewer(event.target.value)} placeholder="Reviewer" />
          </label>
          <div className="tabs">
            {tabs.map((tab) => (
              <button
                key={tab.key}
                className={activeTab === tab.key ? "tab active" : "tab"}
                onClick={() => {
                  setActiveTab(tab.key);
                  setOffset(0);
                }}
              >
                {tab.label}
              </button>
            ))}
          </div>
        </div>
        <div className="filters">
          <label className="field">
            <span>Search lemma</span>
            <input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="e.g. kula" />
          </label>
          <label className="field">
            <span>POS code</span>
            <input value={posCode} onChange={(event) => setPosCode(event.target.value)} placeholder="NOUN" />
          </label>
          <label className="field">
            <span>Lexeme status</span>
            <select value={lexemeStatus} onChange={(event) => setLexemeStatus(event.target.value)}>
              <option value="">All</option>
              {lexemeStatuses.map((status) => (
                <option key={status} value={status}>
                  {status}
                </option>
              ))}
            </select>
          </label>
          <label className="field">
            <span>Definition language</span>
            <select value={languageFilter} onChange={(event) => setLanguageFilter(event.target.value as typeof languageFilter)}>
              <option value="all">All</option>
              <option value="has_en">Has English</option>
              <option value="sw_only">Swahili only</option>
            </select>
          </label>
          <label className="field">
            <span>Sort</span>
            <select value={sort} onChange={(event) => setSort(event.target.value as typeof sort)}>
              <option value="oldest">Oldest</option>
              <option value="newest">Newest</option>
              <option value="lemma">Lemma</option>
            </select>
          </label>
          <label className="field">
            <span>Page size</span>
            <select value={limit} onChange={(event) => setLimit(Number(event.target.value))}>
              {[10, 20, 50].map((value) => (
                <option key={value} value={value}>
                  {value}
                </option>
              ))}
            </select>
          </label>
        </div>
        <div className="review-quick-filters">
          <label className="checkbox">
            <input type="checkbox" checked={aiOnly} onChange={(event) => setAiOnly(event.target.checked)} />
            AI only
          </label>
          <span className="muted">Shortcuts: A approve, E edit, R reject</span>
        </div>
        <div className="actions">
          <button className="primary" onClick={handleBulkApprove} disabled={visibleSelectedCount === 0}>
            Bulk approve ({visibleSelectedCount})
          </button>
          <button
            className="secondary"
            onClick={() => startReject(visibleSelectedIds, false)}
            disabled={visibleSelectedCount === 0}
          >
            Bulk reject ({visibleSelectedCount})
          </button>
        </div>
      </div>
      {toast && <div className="alert">{toast}</div>}
      {error && <p className="error">{error}</p>}
      {loading && <p>Loading queue...</p>}
      {!loading && (
        <ReviewQueueTable
          items={filteredItems}
          selectedIds={selectedIds}
          onToggle={toggleSelection}
          onToggleAll={toggleSelectAllVisible}
          allSelected={allVisibleSelected}
          someSelected={someVisibleSelected}
          onApprove={handleApprove}
          onEdit={startEdit}
          onReject={(id) => startReject([id], true)}
        />
      )}
      <div className="pagination">
        <button className="ghost" onClick={() => setOffset(Math.max(0, offset - limit))} disabled={offset === 0}>
          Previous
        </button>
        <span className="muted">Showing {offset + 1} - {offset + items.length} ({filteredItems.length} visible)</span>
        <button className="ghost" onClick={() => setOffset(offset + limit)} disabled={items.length < limit}>
          Next
        </button>
      </div>
      {rejectingIds && (
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
      {editingId && (
        <div className="modal-backdrop">
          <div className="modal card">
            <h3>Edit definition</h3>
            <div className="stack">
              <label className="field">
                <span>Swahili definition</span>
                <textarea
                  value={editDefinition}
                  onChange={(event) => setEditDefinition(event.target.value)}
                  disabled={editLoading}
                />
              </label>
              <label className="field">
                <span>Gloss (optional)</span>
                <input
                  value={editGloss}
                  onChange={(event) => setEditGloss(event.target.value)}
                  disabled={editLoading}
                />
              </label>
              <div className="actions">
                <button className="secondary" onClick={submitEdit} disabled={editLoading}>
                  Confirm edit
                </button>
                <button className="ghost" onClick={resetEdit} disabled={editLoading}>
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
