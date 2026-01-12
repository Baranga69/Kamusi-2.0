import { render, screen } from "@testing-library/react";
import ReviewQueueTable from "./ReviewQueueTable";

const sampleItems = [
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

test("renders queue table rows", () => {
  render(
    <ReviewQueueTable
      items={sampleItems}
      selectedIds={new Set()}
      onToggle={() => undefined}
      onApprove={() => undefined}
      onReject={() => undefined}
    />
  );

  expect(screen.getByText("kula")).toBeInTheDocument();
  expect(screen.getByText("kula chakula")).toBeInTheDocument();
  expect(screen.getByText("AI Draft")).toBeInTheDocument();
});
