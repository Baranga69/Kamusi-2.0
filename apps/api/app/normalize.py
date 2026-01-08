import re
import unicodedata

DASH_VARIANTS = "\u2010\u2011\u2012\u2013\u2014\u2015\u2212\u2043"
APOSTROPHE_VARIANTS = "\u2018\u2019\u201b\u2032\u2035"


def normalize_sw(text: str) -> str:
    if text is None:
        return ""
    normalized = unicodedata.normalize("NFKC", text).lower()
    normalized = normalized.translate(str.maketrans({ch: "-" for ch in DASH_VARIANTS}))
    normalized = normalized.translate(str.maketrans({ch: "'" for ch in APOSTROPHE_VARIANTS}))
    normalized = re.sub(r"[^\w\s'\-]", " ", normalized, flags=re.UNICODE)
    normalized = re.sub(r"\s+", " ", normalized).strip()
    normalized = normalized.replace("-", " ").replace("'", " ")
    normalized = re.sub(r"\s+", " ", normalized).strip()
    return normalized
