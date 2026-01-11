import json
import os
from pathlib import Path

import psycopg
from psycopg.rows import dict_row

DB_URL = os.getenv("KAMUSI_DB_URL", "postgresql://kamusi:kamusi123@localhost:5433/kamusi")
OUT_PATH = Path(os.getenv("OUT_PATH", "candidates.jsonl"))

WIKT_SOURCE_ID = os.getenv("WIKTIONARY_SOURCE_ID", "d3c1400d-67ee-407d-a54b-1c1966b2a847")
LIMIT = int(os.getenv("LIMIT", "1000"))

# Skip morphological-only “definitions” (you can expand this list later)
EXCLUDE_PREFIXES = (
    "Applicative form of",
    "Reciprocal form of",
    "Causative form of",
    "Passive form of",
    "Stative form of"
)

SQL = """
SELECT
  sd.sense_id,
  l.lemma,
  l.normalized_lemma,
  p.code AS pos_code,
  sd.definition AS en_definition
FROM sense_definition sd
JOIN sense s ON s.id = sd.sense_id
JOIN lexeme l ON l.id = s.lexeme_id
JOIN part_of_speech p ON p.id = l.pos_id
WHERE sd.lang_code = 'en'
  AND sd.source_id = %s
  AND NOT EXISTS (
    SELECT 1
    FROM sense_definition sd2
    WHERE sd2.sense_id = sd.sense_id
      AND sd2.lang_code = 'sw'
  )
ORDER BY l.normalized_lemma
LIMIT %s;
"""

def main():
    OUT_PATH.parent.mkdir(parents=True, exist_ok=True)

    with psycopg.connect(DB_URL, row_factory=dict_row) as conn, conn.cursor() as cur:
        cur.execute(SQL, (WIKT_SOURCE_ID, LIMIT))
        rows = cur.fetchall()

    filtered = []
    for r in rows:
        en = (r["en_definition"] or "").strip()
        if any(en.startswith(pfx) for pfx in EXCLUDE_PREFIXES):
            continue
        filtered.append(r)

    with OUT_PATH.open("w", encoding="utf-8") as f:
        for r in filtered:
            f.write(json.dumps({
            "sense_id": str(r["sense_id"]),
            "lemma": r["lemma"],
            "normalized_lemma": r["normalized_lemma"],
            "pos_code": r["pos_code"],
            "en_definition": r["en_definition"],
        }, ensure_ascii=False) + "\n")

    print(f"Wrote {len(filtered)} candidates to {OUT_PATH}")

if __name__ == "__main__":
    main()