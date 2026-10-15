
import json
import os
import time
from pathlib import Path
from typing import Dict, Any, Optional

from openai import OpenAI
from prompts import SYSTEM, USER_TEMPLATE

# An explicit per-request timeout, and no SDK-level retries because this
# module does its own with backoff.
#
# Without a timeout a single stalled request hangs the whole run silently:
# the first real run sat on one open connection for 35 minutes, 1,624 rows
# in, using no CPU and writing nothing. Retries cannot rescue a call that
# never returns, so the timeout is the part that matters.
REQUEST_TIMEOUT = float(os.getenv("REQUEST_TIMEOUT", "45"))

client = OpenAI(timeout=REQUEST_TIMEOUT, max_retries=0)

IN_PATH = Path(os.getenv("IN_PATH", "candidates.jsonl"))
OUT_PATH = Path(os.getenv("OUT_PATH", "ai_defs.jsonl"))
ERR_PATH = Path(os.getenv("ERR_PATH", "ai_defs_errors.jsonl"))

OPENAI_MODEL = os.getenv("OPENAI_MODEL", "gpt-4o-mini")
SLEEP = float(os.getenv("SLEEP", "0.2"))
MAX_ROWS = int(os.getenv("MAX_ROWS", "0"))  # 0 = all
# Continue an interrupted run instead of starting over. Every row is a paid
# API call, so re-generating work already on disk costs real money as well as
# time.
RESUME = (os.getenv("RESUME", "false") or "").lower() in {"1", "true", "yes"}
# How often to report progress, in rows.
PROGRESS_EVERY = int(os.getenv("PROGRESS_EVERY", "25"))
# Attempts per row, and the base delay between them in seconds.
RETRIES = int(os.getenv("RETRIES", "4"))
RETRY_BACKOFF = float(os.getenv("RETRY_BACKOFF", "1.5"))

print(">>> RUNNING generate_ai_defs.py <<<")
def require_env(name: str) -> str:
    v = os.getenv(name)
    if not v or not v.strip():
        raise RuntimeError(f"Missing required env var: {name}")
    return v


def call_llm(system: str, user: str) -> str:
    """One definition, retrying transient failures.

    A dropped connection is not a bad row: the candidate is fine and the
    model never saw it. Without a retry those rows land in the error file and
    need a whole second pass, and a burst of them mid-run looks like a corpus
    problem when it is just the network. 46 rows went that way on the first
    real run.
    """
    last_error: Exception | None = None
    for attempt in range(RETRIES):
        try:
            resp = client.responses.create(
                model=OPENAI_MODEL,
                input=[
                    {"role": "system", "content": system},
                    {"role": "user", "content": user},
                ],
                temperature=0.2,
            )
            return resp.output_text
        except Exception as error:  # noqa: BLE001 - re-raised below
            last_error = error
            if attempt == RETRIES - 1:
                break
            # Exponential backoff: a rate limit or a flaky link both want
            # the next try to be later, not immediate.
            time.sleep(RETRY_BACKOFF * (2 ** attempt))
    raise last_error

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


def already_done(path: Path) -> set:
    """sense_ids a previous run already wrote, so a resume can skip them."""
    if not path.exists():
        return set()
    done = set()
    with path.open("r", encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            if not line:
                continue
            try:
                done.add(json.loads(line)["sense_id"])
            except (ValueError, KeyError):
                # A partial final line from a run that was killed mid-write.
                continue
    return done


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
    print(f"  TIMEOUT:   {REQUEST_TIMEOUT}s, {RETRIES} attempts per row")

    ok = 0
    bad = 0
    total = 0
    skipped = 0

    done = already_done(OUT_PATH) if RESUME else set()
    if RESUME:
        print(f"  RESUME:    {len(done)} rows already generated, skipping those")
    elif OUT_PATH.exists() and OUT_PATH.stat().st_size:
        # Truncating paid work without warning is not a thing to do quietly.
        print(f"  ⚠️  {OUT_PATH} already has output and will be overwritten.")
        print(f"      Pass RESUME=true to continue it instead.")

    mode = "a" if RESUME else "w"
    with IN_PATH.open("r", encoding="utf-8") as fin, \
         OUT_PATH.open(mode, encoding="utf-8") as fout, \
         ERR_PATH.open(mode, encoding="utf-8") as ferr:

        for line in fin:
            line = line.strip()
            if not line:
                continue

            total += 1
            if MAX_ROWS and total > MAX_ROWS:
                break

            item = json.loads(line)

            if item["sense_id"] in done:
                skipped += 1
                continue

            if total % PROGRESS_EVERY == 0:
                print(f"  {total:>6,}  ok={ok} bad={bad} skipped={skipped}", flush=True)

            user = USER_TEMPLATE.format(
                lemma=item["lemma"],
                pos_code=item["pos_code"],
                en_definition=item["en_definition"],
            )

            # Cleared per row: this used to leak from `locals()`, so every
            # error row recorded the last *successful* row's response and
            # looked like the model had answered about the wrong word.
            raw = None
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
                # Flushed per row: these are paid API calls, and anything
                # still in the buffer when the process dies is paid twice.
                fout.flush()
                ok += 1

            except Exception as e:
                bad += 1
                ferr.write(json.dumps({
                    "sense_id": item.get("sense_id"),
                    "lemma": item.get("lemma"),
                    "pos_code": item.get("pos_code"),
                    "en_definition": item.get("en_definition"),
                    "error": str(e),
                    "raw_response": raw,
                }, ensure_ascii=False) + "\n")
                ferr.flush()

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