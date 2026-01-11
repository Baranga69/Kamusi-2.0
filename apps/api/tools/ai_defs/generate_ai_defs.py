
import json
import os
import time
from pathlib import Path
from typing import Dict, Any, Optional

from openai import OpenAI
from prompts import SYSTEM, USER_TEMPLATE

client = OpenAI()

IN_PATH = Path(os.getenv("IN_PATH", "candidates.jsonl"))
OUT_PATH = Path(os.getenv("OUT_PATH", "ai_defs.jsonl"))
ERR_PATH = Path(os.getenv("ERR_PATH", "ai_defs_errors.jsonl"))

OPENAI_MODEL = os.getenv("OPENAI_MODEL", "gpt-4o-mini")
SLEEP = float(os.getenv("SLEEP", "0.2"))
MAX_ROWS = int(os.getenv("MAX_ROWS", "0"))  # 0 = all

print(">>> RUNNING generate_ai_defs.py <<<")
def require_env(name: str) -> str:
    v = os.getenv(name)
    if not v or not v.strip():
        raise RuntimeError(f"Missing required env var: {name}")
    return v


def call_llm(system: str, user: str) -> str:
    resp = client.responses.create(
        model=OPENAI_MODEL,
        input=[
            {"role": "system", "content": system},
            {"role": "user", "content": user},
        ],
        temperature=0.2,
    )
    return resp.output_text

def extract_json_object(text: str) -> str:
    """
    Extract the first JSON object from a model response.
    Handles ```json fences and any surrounding text.
    """
    if not text:
        return ""

    t = text.strip()

    # Remove common fenced code blocks
    if t.startswith("```"):
        # drop first line (``` or ```json)
        lines = t.splitlines()
        if lines:
            lines = lines[1:]
        # drop trailing ``` if present
        if lines and lines[-1].strip().startswith("```"):
            lines = lines[:-1]
        t = "\n".join(lines).strip()

    # If still has leading junk, find first '{' and last '}'
    start = t.find("{")
    end = t.rfind("}")
    if start != -1 and end != -1 and end > start:
        return t[start:end + 1].strip()

    return t


def main():
    # Fail fast if key missing
    require_env("OPENAI_API_KEY")

    if not IN_PATH.exists():
        raise FileNotFoundError(f"Missing input: {IN_PATH.resolve()}")

    OUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    ERR_PATH.parent.mkdir(parents=True, exist_ok=True)

    print("▶ AI definition generation starting")
    print(f"  IN_PATH:   {IN_PATH.resolve()}")
    print(f"  OUT_PATH:  {OUT_PATH.resolve()}")
    print(f"  ERR_PATH:  {ERR_PATH.resolve()}")
    print(f"  MODEL:     {OPENAI_MODEL}")

    ok = 0
    bad = 0
    total = 0

    with IN_PATH.open("r", encoding="utf-8") as fin, \
         OUT_PATH.open("w", encoding="utf-8") as fout, \
         ERR_PATH.open("w", encoding="utf-8") as ferr:

        for line in fin:
            line = line.strip()
            if not line:
                continue

            total += 1
            if MAX_ROWS and total > MAX_ROWS:
                break

            item = json.loads(line)

            user = USER_TEMPLATE.format(
                lemma=item["lemma"],
                pos_code=item["pos_code"],
                en_definition=item["en_definition"],
            )

            try:
                raw = call_llm(SYSTEM, user)

                # Parse JSON strictly
                json_text = extract_json_object(raw)
                data = json.loads(json_text)

                definition_sw = (data.get("definition_sw") or "").strip()
                if not definition_sw:
                    raise ValueError("Empty definition_sw")

                out = {
                    "sense_id": item["sense_id"],
                    "lemma": item["lemma"],
                    "pos_code": item["pos_code"],
                    "en_definition": item["en_definition"],
                    "definition_sw": definition_sw,
                    "gloss_sw": data.get("gloss_sw", None),
                    "confidence": float(data.get("confidence", 0.5)),
                    "notes": data.get("notes", None),
                    "model": OPENAI_MODEL,
                    "prompt_version": "v1",
                }

                fout.write(json.dumps(out, ensure_ascii=False) + "\n")
                ok += 1

            except Exception as e:
                bad += 1
                ferr.write(json.dumps({
                    "sense_id": item.get("sense_id"),
                    "lemma": item.get("lemma"),
                    "pos_code": item.get("pos_code"),
                    "en_definition": item.get("en_definition"),
                    "error": str(e),
                    "raw_response": raw if "raw" in locals() else None,
                }, ensure_ascii=False) + "\n")

            if SLEEP:
                time.sleep(SLEEP)

    print("✅ Done")
    print(f"  Read candidates: {total}")
    print(f"  OK rows:         {ok}")
    print(f"  Error rows:      {bad}")
    print(f"  OUT lines:       {ok}  (ai_defs.jsonl)")
    print(f"  ERR lines:       {bad} (ai_defs_errors.jsonl)")


if __name__ == "__main__":
    main()