# apps/api/tools/ingest/wiktionary/load_contract.py
import json
import os
import sys
import uuid
from typing import Any, Dict, Optional

import psycopg
from psycopg.rows import dict_row

DB_URL = os.getenv("KAMUSI_DB_URL", "postgresql://kamusi:kamusi123@localhost:5433/kamusi")
INPUT_JSONL = sys.argv[1] if len(sys.argv) > 1 else "kamusi_contract-20260101.jsonl"

# IMPORTANT: your lexeme_status enum is classification: core/slang/regional/...
DEFAULT_STATUS = os.getenv("KAMUSI_STATUS", "core")

# IMPORTANT: your workflow_status enum is draft/reviewed/published/archived
DEFAULT_WORKFLOW = os.getenv("KAMUSI_WORKFLOW", "draft")


def get_pos_map(cur) -> Dict[str, str]:
    cur.execute("SELECT code, id FROM part_of_speech")
    return {r["code"]: r["id"] for r in cur.fetchall()}


def select_lexeme_id(cur, normalized_lemma: str, pos_id: str, default_language_code: str) -> Optional[str]:
    cur.execute(
        """
        SELECT id
        FROM lexeme
        WHERE normalized_lemma = %s
          AND pos_id = %s
          AND default_language_code = %s
        LIMIT 1
        """,
        (normalized_lemma, pos_id, default_language_code),
    )
    row = cur.fetchone()
    return row["id"] if row else None


def insert_lexeme(
    cur,
    lemma: str,
    normalized_lemma: str,
    pos_id: str,
    default_language_code: str,
    status: str,
    workflow: str,
) -> str:
    new_id = str(uuid.uuid4())
    cur.execute(
        """
        INSERT INTO lexeme (
            id, lemma, normalized_lemma, pos_id,
            status, default_language_code, workflow,
            created_at, updated_at
        )
        VALUES (
            %s, %s, %s, %s,
            %s, %s, %s,
            now(), now()
        )
        """,
        (new_id, lemma, normalized_lemma, pos_id, status, default_language_code, workflow),
    )
    return new_id


def select_sense_id(cur, lexeme_id: str, sense_number: int) -> Optional[str]:
    cur.execute(
        """
        SELECT id
        FROM sense
        WHERE lexeme_id = %s
          AND sense_number = %s
        LIMIT 1
        """,
        (lexeme_id, sense_number),
    )
    row = cur.fetchone()
    return row["id"] if row else None


def insert_sense(cur, lexeme_id: str, sense_number: int, workflow: str) -> str:
    new_id = str(uuid.uuid4())
    cur.execute(
        """
        INSERT INTO sense (
            id, lexeme_id, sense_number,
            domain_id, register_id, usage_note,
            workflow, created_at, updated_at
        )
        VALUES (
            %s, %s, %s,
            NULL, NULL, NULL,
            %s,
            now(), now()
        )
        """,
        (new_id, lexeme_id, sense_number, workflow),
    )
    return new_id


def upsert_definition_one_per_lang(
    cur,
    sense_id: str,
    lang_code: str,
    definition: str,
    gloss: Optional[str],
    is_primary: bool,
    source_id: str,
) -> None:
    """
    Your DB enforces UNIQUE(sense_id, lang_code).
    So we UPSERT: if exists, do nothing (or update if you prefer).
    """
    cur.execute(
        """
        INSERT INTO sense_definition (
            id, sense_id, lang_code, definition, gloss,
            is_primary, source_id, created_at
        )
        VALUES (
            %s, %s, %s, %s, %s,
            %s, %s, now()
        )
        ON CONFLICT (sense_id, lang_code)
        DO NOTHING
        """,
        (
            str(uuid.uuid4()),
            sense_id,
            lang_code,
            definition,
            gloss,
            is_primary,
            source_id,
        ),
    )


def main() -> None:
    inserted_lexemes = 0
    inserted_senses = 0
    attempted_definitions = 0
    skipped_unknown_pos = 0
    skipped_missing_source = 0

    print(f"DB_URL: {DB_URL}")
    print(f"DEFAULT_STATUS (lexeme.status): {DEFAULT_STATUS}")
    print(f"DEFAULT_WORKFLOW (lexeme/sense.workflow): {DEFAULT_WORKFLOW}")
    print(f"INPUT: {INPUT_JSONL}")

    with psycopg.connect(DB_URL, row_factory=dict_row) as conn:
        with conn.cursor() as cur:
            pos_map = get_pos_map(cur)

            with open(INPUT_JSONL, "r", encoding="utf-8") as f:
                for line in f:
                    line = line.strip()
                    if not line:
                        continue
                    obj: Dict[str, Any] = json.loads(line)

                    source = obj.get("source") or {}
                    source_id = source.get("source_id")
                    if not source_id:
                        skipped_missing_source += 1
                        continue

                    lex = obj["lexeme"]
                    lemma = lex["lemma"]
                    normalized = (lex.get("normalized") or lemma).strip().lower()
                    pos_code = lex["pos_code"]
                    default_lang = lex.get("default_language_code", "sw")

                    pos_id = pos_map.get(pos_code)
                    if not pos_id:
                        skipped_unknown_pos += 1
                        continue

                    # Force correct enum meanings
                    status = DEFAULT_STATUS
                    workflow = DEFAULT_WORKFLOW

                    lexeme_id = select_lexeme_id(cur, normalized, pos_id, default_lang)
                    if not lexeme_id:
                        lexeme_id = insert_lexeme(
                            cur, lemma, normalized, pos_id, default_lang, status, workflow
                        )
                        inserted_lexemes += 1

                    for s in obj.get("senses", []) or []:
                        sense_number = int(s["sense_number"])

                        sense_id = select_sense_id(cur, lexeme_id, sense_number)
                        if not sense_id:
                            sense_id = insert_sense(cur, lexeme_id, sense_number, workflow)
                            inserted_senses += 1

                        # Your schema allows only 1 definition per language per sense.
                        # We'll take the first definition per language from the contract.
                        seen_langs = set()
                        for d in s.get("definitions", []) or []:
                            lang_code = (d.get("lang") or "en").strip()
                            if lang_code in seen_langs:
                                continue
                            definition_text = (d.get("text") or "").strip()
                            if not definition_text:
                                continue

                            seen_langs.add(lang_code)
                            attempted_definitions += 1

                            upsert_definition_one_per_lang(
                                cur=cur,
                                sense_id=sense_id,
                                lang_code=lang_code,
                                definition=definition_text,
                                gloss=d.get("gloss"),
                                is_primary=bool(d.get("is_primary", False)),
                                source_id=source_id,
                            )

            conn.commit()

    print("Done.")
    print("Inserted lexemes:", inserted_lexemes)
    print("Inserted senses:", inserted_senses)
    print("Attempted definitions:", attempted_definitions)
    print("Skipped (unknown pos):", skipped_unknown_pos)
    print("Skipped (missing source_id):", skipped_missing_source)


if __name__ == "__main__":
    main()