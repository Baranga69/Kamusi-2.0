import { expect, test } from "vitest";
import { render, screen } from "@testing-library/react";
import type { ReviewQueueItem } from "../../lib/api";
import ReviewQueueTable from "./ReviewQueueTable";

const sampleItems: ReviewQueueItem[] = [
  {
    sense_definition_id: "def-1",
    sense_id: "sense-1",
    lexeme_id: "lex-1",
    lemma: "kula",
    pos_code: "VERB",
    sw_definition_preview: "kula chakula",
    en_definition_preview: "to eat",
    created_at: "2024-01-01T00:00:00Z",
    review_status: "unreviewed",
    is_ai_generated: true,
    morphology_like: false,
  },
];

const renderQueue = (items: ReviewQueueItem[]) =>
  render(
    <ReviewQueueTable
      items={items}
      selectedIds={new Set()}
      onToggle={() => undefined}
      onToggleAll={() => undefined}
      allSelected={false}
      someSelected={false}
      onApprove={() => undefined}
      onEdit={() => undefined}
      onReject={() => undefined}
    />
  );

test("renders queue table rows", () => {
  renderQueue(sampleItems);

  expect(screen.getByText("kula")).toBeInTheDocument();
  expect(screen.getByText("kula chakula")).toBeInTheDocument();
  expect(screen.getByText("AI Draft")).toBeInTheDocument();
});

test("shows what the ingest gate objected to, in words", () => {
  renderQueue([{ ...sampleItems[0], quality_flags: ["english", "too_short"] }]);

  expect(screen.getByText("Looks English")).toBeInTheDocument();
  expect(screen.getByText("Too short")).toBeInTheDocument();
  // Flagged, still listed: a heuristic draws attention, it does not filter.
  expect(screen.getByText("kula")).toBeInTheDocument();
});

test("a flag the labels do not know still shows", () => {
  renderQueue([{ ...sampleItems[0], quality_flags: ["some_new_rule"] }]);

  expect(screen.getByText("some new rule")).toBeInTheDocument();
});

test("a clean definition gets no quality badges", () => {
  const { container } = renderQueue([{ ...sampleItems[0], quality_flags: [] }]);

  expect(container.querySelectorAll(".badge-quality")).toHaveLength(0);
});
