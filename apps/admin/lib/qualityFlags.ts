/**
 * Human labels for the backend's quality-gate slugs.
 *
 * The *rules* live in the API (`app/core/quality.py`) so the importer and this
 * queue cannot disagree about what counts as suspect — there used to be a
 * second, unused copy of them here, which is exactly how that drift starts.
 * All this file does is turn a slug into something a reviewer can read.
 */
export const QUALITY_FLAG_LABELS: Record<string, string> = {
  empty: "Empty",
  too_short: "Too short",
  too_long: "Too long",
  english: "Looks English",
  refusal: "Model refused",
  morphology_only: "Morphology only",
  echoes_lemma: "Repeats headword",
  echoes_source: "Repeats English",
  duplicate_in_file: "Duplicate",
};

/** An unknown slug still shows, rather than vanishing: the API knows more
 *  than this map does, and a silently dropped warning is worse than an ugly
 *  one. */
export const qualityFlagLabel = (flag: string) =>
  QUALITY_FLAG_LABELS[flag] ?? flag.replace(/_/g, " ");
