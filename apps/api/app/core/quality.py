"""What makes a Swahili definition worth keeping.

One place for the checks, because they are applied in three: the importer
refuses the worst of them at the door, the review queue badges the rest for a
human, and the candidate exporter uses the same morphology list to decide what
is not worth asking a model about. Three copies of "what counts as English" is
three chances to disagree, and a reviewer seeing a badge the importer did not
act on has no way to tell which one is wrong.

Nothing here touches the database or the app settings — it is plain text
analysis, so the offline ingest tools can import it without pulling in a
FastAPI app or a connection pool.

The thresholds are deliberately forgiving. A definition that is merely odd
should reach a reviewer, who can judge it; only text that cannot be a Swahili
definition at all is worth refusing outright, because a false refusal is
silently lost content and the whole point is to grow the dictionary.
"""
from __future__ import annotations

import re
import unicodedata

# Wiktionary's English definitions for derived verb forms. "Applicative form
# of -penda" tells a reader nothing they wanted to know, and asking a model to
# translate it produces a Swahili sentence about grammar rather than a
# definition. The exporter skips them; the review queue flags any that landed
# before it did.
#
# The named ones, for documentation and for the admin console's morphology
# lane. This list is NOT how detection works — see MORPHOLOGY_PATTERN.
MORPHOLOGY_PREFIXES = (
    "Applicative form of",
    "Reciprocal form of",
    "Stative form of",
    "Causative form of",
    "Passive form of",
    "Conversive form of",
    "Augmentative form of",
    "Reduplicative form of",
)

# Detection matches the shape, not a list of names. An enumerated list was
# already wrong on the first real corpus: it named five forms while the data
# also held Conversive, Augmentative and Reduplicative, so 21 stubs passed the
# gate. Wiktionary will keep inventing these, and a definition that opens
# "<Word> form of" is a grammatical cross-reference whatever the word is.
#
# Case matters, and a leading determiner is excluded: Wiktionary writes these
# as a capitalised label ("Passive form of -ona"), whereas "a form of
# government that is elected" is an ordinary English definition that an
# unanchored pattern wrongly condemned.
MORPHOLOGY_PATTERN = re.compile(
    r"^(?!(?:A|An|The|Another|Any|Some|One|No)\b)"
    r"[A-Z][a-z]+(?:[- ][A-Za-z]+)? form of\b"
)

# Function words that are common in English and rare-to-absent in Swahili.
# Deliberately not content words: "radio" and "hoteli" are Swahili too.
ENGLISH_STOP_WORDS = frozenset(
    {
        "the", "a", "an", "and", "or", "of", "to", "in", "for", "on", "with",
        "without", "is", "are", "was", "were", "be", "as", "by", "from",
        "that", "this", "these", "those", "it", "its", "into", "at", "about",
    }
)

# Below this, it is a gloss or a fragment rather than a definition. Swahili is
# agglutinative, so real definitions are rarely this short.
MIN_DEFINITION_LENGTH = 12
# Above this, the model has written an essay. Generous: some definitions need
# a clause of context.
MAX_DEFINITION_LENGTH = 400

# Phrases distinctive enough to catch anywhere in the text: a definition
# containing "as an AI" is not a definition, wherever it says so.
REFUSAL_PHRASES = (
    "as an ai",
    "i cannot",
    "i can't",
    "i am unable",
    "siwezi kusaidia",
    "sina uhakika",
    "no definition",
    "lorem ipsum",
)

# Matched only as the *whole* text. "unknown" alone is a placeholder; a real
# definition may well contain the word, so a substring match would discard
# good content.
PLACEHOLDER_VALUES = frozenset(
    {"unknown", "not available", "none", "null", "n/a", "na", "todo", "tbd", "-", "?"}
)

WORD = re.compile(r"[a-z]+")


def collapse(text: str | None) -> str:
    """Trimmed, single-spaced, NFC. What every check below compares."""
    if not text:
        return ""
    return re.sub(r"\s+", " ", unicodedata.normalize("NFC", text)).strip()


def analyze_english(text: str) -> tuple[int, int, float]:
    """(stop-word hits, total words, ratio) for `text`.

    Returned rather than reduced to a boolean so a caller can explain *why*
    something was flagged. A reviewer told "3 of 7 words are English" can
    check the call; one told "englishy" cannot.
    """
    words = WORD.findall(text.lower())
    if not words:
        return 0, 0, 0.0
    hits = sum(1 for word in words if word in ENGLISH_STOP_WORDS)
    return hits, len(words), hits / len(words)


def looks_english(text: str) -> bool:
    """True when the text is probably English rather than Swahili.

    Needs several words before it will judge: "the" alone is a Swahili word in
    no language, but a two-word fragment is too little to be sure, and the
    cost of being wrong is discarding a real definition. Both an absolute
    count and a ratio must clear, so a long Swahili definition quoting an
    English phrase is not condemned by the quote.
    """
    hits, total, ratio = analyze_english(text)
    if total < 4:
        return False
    return hits >= 3 and ratio > 0.35


def looks_morphological(text: str) -> bool:
    """True for Wiktionary's "X form of Y" non-definitions."""
    return bool(MORPHOLOGY_PATTERN.match(collapse(text)))


def looks_like_refusal(text: str) -> bool:
    """True when the model declined, or filled the field with a placeholder."""
    lowered = collapse(text).casefold().rstrip(".")
    if not lowered:
        return False
    if lowered in PLACEHOLDER_VALUES:
        return True
    return any(phrase in lowered for phrase in REFUSAL_PHRASES)


def is_too_short(text: str, limit: int = MIN_DEFINITION_LENGTH) -> bool:
    return len(collapse(text)) < limit


def is_too_long(text: str, limit: int = MAX_DEFINITION_LENGTH) -> bool:
    return len(collapse(text)) > limit


def echoes(text: str, other: str | None) -> bool:
    """True when `text` just repeats `other` — the prompt, or the headword.

    A model that returns its input has not defined anything, and the result
    reads as a definition, so nothing downstream would catch it.
    """
    if not other:
        return False
    return collapse(text).casefold() == collapse(other).casefold()


def check_definition(
    text: str | None,
    *,
    lemma: str | None = None,
    source_definition: str | None = None,
    min_length: int = MIN_DEFINITION_LENGTH,
    max_length: int = MAX_DEFINITION_LENGTH,
) -> list[str]:
    """Everything wrong with a candidate Swahili definition, worst first.

    An empty list means it is worth keeping. Each problem is a short stable
    slug, so counts can be tallied by reason and a rejected row can say which
    rule caught it.
    """
    stripped = collapse(text)
    if not stripped:
        return ["empty"]

    problems: list[str] = []
    if looks_like_refusal(stripped):
        problems.append("refusal")
    if is_too_short(stripped, min_length):
        problems.append("too_short")
    if is_too_long(stripped, max_length):
        problems.append("too_long")
    if looks_english(stripped):
        problems.append("english")
    if looks_morphological(stripped):
        problems.append("morphology_only")
    if echoes(stripped, lemma):
        problems.append("echoes_lemma")
    if echoes(stripped, source_definition):
        problems.append("echoes_source")
    return problems
