import re
import unicodedata

DASH_VARIANTS = "‐‑‒–—―−⁃"
APOSTROPHE_VARIANTS = "‘’‛′‵"


def normalize_sw(text: str) -> str:
    """Fold a Swahili string into its search key.

    Dashes and apostrophes are dropped rather than turned into spaces so that
    ``ng'ombe`` and ``ngombe`` collapse to the same key, and so that a verb
    root written ``-pika`` matches ``pika``. Every other punctuation mark
    becomes a space.
    """
    if text is None:
        return ""
    normalized = unicodedata.normalize("NFKC", text).lower()
    normalized = normalized.translate(str.maketrans({ch: "-" for ch in DASH_VARIANTS}))
    normalized = normalized.translate(str.maketrans({ch: "'" for ch in APOSTROPHE_VARIANTS}))
    normalized = re.sub(r"[^\w\s'\-]", " ", normalized, flags=re.UNICODE)
    normalized = normalized.replace("-", "").replace("'", "")
    normalized = re.sub(r"\s+", " ", normalized).strip()
    return normalized
