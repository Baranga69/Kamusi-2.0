#!/usr/bin/env python3
import json
import os
import sys
import uuid
from pathlib import Path

import psycopg
from psycopg.rows import dict_row


def env(name: str, default: str | None = None) -> str | None:
    v = os.getenv(name)
    return v if v is not None and v.strip() != "" else default


DB_URL = env("KAMUSI_DB_URL", "postgresql://kamusi:kamusi123@localhost:5433/kamusi")
AI_SOURCE_ID = env("AI_SOURCE_ID")  # REQUIRED

# Where your generator wrote the output
IN_PATH = Path(env("IN_PATH", "ai_defs.jsonl"))

# Insert behavior
ON_CONFLICT = env("ON_CONFLICT", "skip")  # "skip" or "update"
IS_PRIMARY = env("IS_PRIMARY", "true").lower() == "true"


def is_uuid(s: str) -> bool:
    try:
        uuid.UUID(s)
        return True
    except Exception:
        return False


def main() -> None:
    if not AI_SOURCE_ID:
        print("❌ AI_SOURCE_ID is not set. Example:")
        print('   export AI_SOURCE_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"')
        sys.exit(1)

    if not is_uuid(AI_SOURCE_ID):
        print(f"❌ AI_SOURCE_ID is not a valid UUID: {AI_SOURCE_ID}")
        sys.exit(1)

    if not IN_PATH.exists():
        print(f"❌ Input file not found: {IN_PATH.resolve()}")
        print("Tip: set IN_PATH to the full path if you ran generation elsewhere, e.g.:")
        print('   export IN_PATH="apps/api/tools/ai_defs/ai_defs.jsonl"')
        sys.exit(1)

    inserted = 0
    skipped_conflict = 0
    updated = 0
    skipped_bad = 0
    total = 0

    # Build SQL depending on conflict strategy
    if ON_CONFLICT == "update":
        upsert_sql = """
        INSERT INTO sense_definition (
          id, sense_id, lang_code, definition, gloss, is_primary, source_id, created_at
        )
        VALUES (
          %s, %s, 'sw', %s, %s, %s, %s, now()
        )
        ON CONFLICT (sense_id, lang_code)
        DO UPDATE SET
          definition = EXCLUDED.definition,
          gloss = EXCLUDED.gloss,
          is_primary = EXCLUDED.is_primary,
          source_id = EXCLUDED.source_id
        """
    else:
        upsert_sql = """
        INSERT INTO sense_definition (
          id, sense_id, lang_code, definition, gloss, is_primary, source_id, created_at
        )
        VALUES (
          %s, %s, 'sw', %s, %s, %s, %s, now()
        )
        ON CONFLICT (sense_id, lang_code)
        DO NOTHING
        """

    with psycopg.connect(DB_URL, row_factory=dict_row) as conn:
        with conn.cursor() as cur:
            with IN_PATH.open("r", encoding="utf-8") as f:
                for line in f:
                    line = line.strip()
                    if not line:
                        continue
                    total += 1

                    obj = json.loads(line)

                    # generator writes error rows without definition_sw
                    definition_sw = (obj.get("definition_sw") or "").strip()
                    sense_id = obj.get("sense_id")

                    if not sense_id or not definition_sw:
                        skipped_bad += 1
                        continue

                    # sense_id might be string UUID; keep it as string for psycopg
                    gloss_sw = obj.get("gloss_sw", None)

                    new_id = str(uuid.uuid4())
                    cur.execute(
                        upsert_sql,
                        (new_id, sense_id, definition_sw, gloss_sw, IS_PRIMARY, AI_SOURCE_ID),
                    )

                    # rowcount meaning differs between DO NOTHING vs DO UPDATE
                    if ON_CONFLICT == "update":
                        # rowcount will usually be 1 whether insert or update
                        # We'll infer "insert vs update" by checking if the row already existed:
                        # (cheap approach: try insert-only first would be two queries, so we keep simple)
                        # We'll just count rowcount as "written".
                        updated += 1
                    else:
                        if cur.rowcount == 1:
                            inserted += 1
                        else:
                            skipped_conflict += 1

            conn.commit()

    print("✅ Import finished")
    print(f"Input lines read:           {total}")
    print(f"Inserted (new sw rows):     {inserted}")
    print(f"Skipped (conflict existing):{skipped_conflict}")
    print(f"Written (update mode):      {updated}")
    print(f"Skipped (bad/error rows):   {skipped_bad}")
    print(f"AI_SOURCE_ID:              {AI_SOURCE_ID}")
    print(f"IN_PATH:                   {IN_PATH.resolve()}")
    print(f"DB_URL:                    {DB_URL}")


if __name__ == "__main__":
    main()