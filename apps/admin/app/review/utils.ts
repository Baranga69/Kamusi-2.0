const englishStopWords = new Set([
  "the",
  "a",
  "an",
  "and",
  "or",
  "of",
  "to",
  "in",
  "for",
  "on",
  "with",
  "without",
  "is",
  "are",
  "was",
  "were",
  "be",
  "as",
  "by",
  "from",
  "that",
  "this",
  "these",
  "those",
  "it",
  "its",
  "into",
  "at",
  "about",
]);

export const analyzeEnglishyText = (text: string) => {
  const matches = text.toLowerCase().match(/[a-z]+/g) ?? [];
  if (matches.length === 0) {
    return { englishHits: 0, totalWords: 0, ratio: 0 };
  }
  const englishHits = matches.filter((word) => englishStopWords.has(word)).length;
  const ratio = englishHits / matches.length;
  return { englishHits, totalWords: matches.length, ratio };
};

export const isEnglishy = (text: string) => {
  const analysis = analyzeEnglishyText(text);
  if (analysis.totalWords < 4) {
    return false;
  }
  return analysis.englishHits >= 3 && analysis.ratio > 0.35;
};

export const isTooLong = (text: string, limit = 180) => text.trim().length > limit;
