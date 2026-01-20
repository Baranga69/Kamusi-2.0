"use client";

import { useEffect, useRef } from "react";
import Link from "next/link";
import type { ReviewQueueItem } from "../../../../lib/api";

interface ReviewQueueTableProps {
  items: ReviewQueueItem[];
  selectedIds: Set<string>;
  onToggle: (id: string) => void;
  onToggleAll: () => void;
  allSelected: boolean;
  someSelected: boolean;
  onApprove: (id: string) => void;
  onEdit: (item: ReviewQueueItem) => void;
  onReject: (id: string) => void;
}

const formatDate = (value: string) => {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    return value;
  }
  return date.toLocaleString();
};

export default function ReviewQueueTable({
  items,
  selectedIds,
  onToggle,
  onToggleAll,
  allSelected,
  someSelected,
  onApprove,
  onEdit,
  onReject,
}: ReviewQueueTableProps) {
  const selectAllRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    if (selectAllRef.current) {
      selectAllRef.current.indeterminate = someSelected;
    }
  }, [someSelected]);

  return (
    <div className="table review-table">
      <div className="table-row table-head review-row">
        <span>
          <input
            ref={selectAllRef}
            type="checkbox"
            checked={allSelected}
            onChange={onToggleAll}
            aria-label="Select all visible"
          />
        </span>
        <span>Lemma</span>
        <span>POS</span>
        <span>English</span>
        <span>Swahili</span>
        <span>Created</span>
        <span>Tags</span>
        <span></span>
      </div>
      {items.map((item) => (
        <div
          key={item.sense_definition_id}
          className={`table-row review-row${selectedIds.has(item.sense_definition_id) ? " selected" : ""}`}
        >
          <span>
            <input
              type="checkbox"
              checked={selectedIds.has(item.sense_definition_id)}
              onChange={() => onToggle(item.sense_definition_id)}
              aria-label={`Select ${item.lemma}`}
            />
          </span>
          <span>
            <Link href={`/review/${item.sense_definition_id}`} className="link">
              {item.lemma}
            </Link>
          </span>
          <span>{item.pos_code}</span>
          <span className="preview">{item.en_definition_preview || "-"}</span>
          <span className="preview">{item.sw_definition_preview}</span>
          <span>{formatDate(item.created_at)}</span>
          <span className="review-badges">
            {item.is_ai_generated && <span className="badge badge-ai">AI Draft</span>}
            {item.review_status && <span className={`badge badge-${item.review_status}`}>{item.review_status}</span>}
            {item.morphology_like && <span className="badge badge-morph">Morphology</span>}
          </span>
          <span className="inline-actions">
            <button
              className="ghost"
              onClick={() => onApprove(item.sense_definition_id)}
              disabled={item.review_status && item.review_status !== "unreviewed"}
            >
              Approve
            </button>
            <button
              className="ghost"
              onClick={() => onEdit(item)}
              disabled={item.review_status && item.review_status !== "unreviewed"}
            >
              Edit
            </button>
            <button
              className="ghost"
              onClick={() => onReject(item.sense_definition_id)}
              disabled={item.review_status && item.review_status !== "unreviewed"}
            >
              Reject
            </button>
          </span>
        </div>
      ))}
      {items.length === 0 && <p className="muted">No review items found.</p>}
    </div>
  );
}
