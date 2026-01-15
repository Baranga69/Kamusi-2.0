"use client";

import Link from "next/link";
import type { ReviewQueueItem } from "../../../../lib/api";

interface ReviewQueueTableProps {
  items: ReviewQueueItem[];
  selectedIds: Set<string>;
  onToggle: (id: string) => void;
  onApprove: (id: string) => void;
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
  onApprove,
  onReject,
}: ReviewQueueTableProps) {
  return (
    <div className="table review-table">
      <div className="table-row table-head review-row">
        <span></span>
        <span>Lemma</span>
        <span>POS</span>
        <span>English</span>
        <span>Swahili</span>
        <span>Created</span>
        <span>Tags</span>
        <span></span>
      </div>
      {items.map((item) => (
        <div key={item.sense_definition_id} className="table-row review-row">
          <span>
            <input
              type="checkbox"
              checked={selectedIds.has(item.sense_definition_id)}
              onChange={() => onToggle(item.sense_definition_id)}
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
