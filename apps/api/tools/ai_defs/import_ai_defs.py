#!/usr/bin/env python3
"""Import generated Swahili definitions into sense_definition.

Every row written here is AI-generated and therefore untrusted until a human
reviews it. That stance only holds if the provenance columns are populated on
insert: the public API hides a Swahili definition when
``is_ai_generated = true AND review_status NOT IN ('approved','edited')``, and
the admin review queue selects on exactly the same two columns. A row imported
without them is both invisible to reviewers and served to readers as though a
lexicographer had written it.
"""
import json
import os
import sys
import uuid
from pathlib import Path

import psycopg
from psycopg.rows import dict_row

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from import_run import count_lines, import_run  # noqa: E402

from app.core.quality import (  # noqa: E402
    MAX_DEFINITION_LENGTH,
    MIN_DEFINITION_LENGTH,
    check_definition,
)


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

# Provenance defaults, used when a JSONL row predates these fields.
DEFAULT_MODEL = env("AI_MODEL", "unknown")
DEFAULT_PROMPT_VERSION = env("AI_PROMPT_VERSION", "unknown")

# Imported definitions always land unreviewed; the admin queue promotes them.
INITIAL_REVIEW_STATUS = "unreviewed"

# Rows per transaction. A failure loses at most this much work, and the run
# records how far it got so the rest can be resumed.
BATCH_SIZE = int(env("BATCH_SIZE", "500"))
# Continue an interrupted run instead of starting a new one.
RESUME = env("RESUME")
# Parse and report without writing anything.
DRY_RUN = (env("DRY_RUN", "false") or "").lower() in {"1", "true", "yes"}

# Quality gate. Growing the dictionary by a factor of ten also multiplies the
# bad rows by ten, and a reviewer's time is the scarce resource — text that
# cannot be a Swahili definition should not reach the queue at all.
MIN_LENGTH = int(env("MIN_LENGTH", str(MIN_DEFINITION_LENGTH)))
MAX_LENGTH = int(env("MAX_LENGTH", str(MAX_DEFINITION_LENGTH)))
# Refused rows are written here rather than dropped, so a bad prompt can be
# diagnosed from what it produced instead of guessed at.
REJECTS_PATH = Path(env("REJECTS_PATH") or f"{IN_PATH}.rejected.jsonl")
# Escape hatch for a corpus the heuristics judge badly. Off by default,
# because the failure it guards against is a reviewer's time.
SKIP_VALIDATION = (env("SKIP_VALIDATION", "false") or "").lower() in {"1", "true", "yes"}
# The model's own confidence is evidence. Asked not to invent, it reports 0.0
# on a word it cannot define — and sometimes writes that refusal into the
# definition field, where it reads like prose. Taking it at its word is
# cheaper than any heuristic that tries to detect the same thing in the text.
MIN_CONFIDENCE = float(env("MIN_CONFIDENCE", "0.1"))
# How many senses may share one definition text before it looks like filler
# rather than synonymy. A model with nothing to work from repeats itself —
# one phrase came back for six unrelated verbs in the bare-stub batch — but
# two or three shared definitions are normal in a language with this many
# synonyms, and rejecting those throws away correct work.
REUSED_TEXT_LIMIT = int(env("REUSED_TEXT_LIMIT", "3"))

INSERT_COLUMNS = """
  id, sense_id, lang_code, definition, gloss, is_primary, source_id, created_at,
  is_ai_generated, review_status, ai_model, ai_prompt_version, ai_confidence,
  import_run_id
"""

INSERT_VALUES = """
  %s, %s, 'sw', %s, %s, %s, %s, now(),
  true, %s, %s, %s, %s,
  %s
"""


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

    if ON_CONFLICT not in {"skip", "update"}:
        print(f"❌ ON_CONFLICT must be 'skip' or 'update', got: {ON_CONFLICT}")
        sys.exit(1)

    inserted = 0
    skipped_conflict = 0
    updated = 0
    skipped_bad = 0
    skipped_resume = 0
    total = 0
    rejected_rows = 0
    rejected_by_reason: dict[str, int] = {}
    # sense_ids already seen in this file. The database's conflict handling is
    # the authority on duplicates; this only catches the ones that would waste
    # a round trip, and reports them so a bad export can be fixed.
    seen_senses: set[str] = set()
    # How many senses each definition text has been used for. Reuse is not
    # automatically wrong: Swahili has plenty of synonyms, and a dictionary
    # properly gives "uhodari", "umahiri" and "umilisi" near-identical
    # definitions. On the first real batch every single repeat was a synonym
    # cluster like that, so only heavy reuse counts — see REUSED_TEXT_LIMIT.
    text_uses: dict[str, int] = {}
    rejects_file = None

    # Build SQL depending on conflict strategy
    if ON_CONFLICT == "update":
        # An existing row is replaced wholesale, which resets review state:
        # the text changed, so an earlier approval no longer applies to it.
        upsert_sql = f"""
        INSERT INTO sense_definition ({INSERT_COLUMNS})
        VALUES ({INSERT_VALUES})
        ON CONFLICT (sense_id, lang_code)
        DO UPDATE SET
          definition = EXCLUDED.definition,
          gloss = EXCLUDED.gloss,
          is_primary = EXCLUDED.is_primary,
          source_id = EXCLUDED.source_id,
          is_ai_generated = EXCLUDED.is_ai_generated,
          review_status = EXCLUDED.review_status,
          ai_model = EXCLUDED.ai_model,
          ai_prompt_version = EXCLUDED.ai_prompt_version,
          ai_confidence = EXCLUDED.ai_confidence,
          reviewed_by = NULL,
          reviewed_at = NULL,
          review_note = NULL
        """
    else:
        upsert_sql = f"""
        INSERT INTO sense_definition ({INSERT_COLUMNS})
        VALUES ({INSERT_VALUES})
        ON CONFLICT (sense_id, lang_code)
        DO NOTHING
        """

    run_id = None
    resumed_from = 0
    try:
        with psycopg.connect(DB_URL, row_factory=dict_row) as conn, import_run(
            conn,
            kind="ai_definitions",
            tool="import_ai_defs.py",
            source_id=AI_SOURCE_ID,
            input_path=str(IN_PATH.resolve()),
            parameters={
                "on_conflict": ON_CONFLICT,
                "is_primary": IS_PRIMARY,
                "batch_size": BATCH_SIZE,
                "min_length": MIN_LENGTH,
                "max_length": MAX_LENGTH,
                "validation": "skipped" if SKIP_VALIDATION else "enforced",
            },
            resume=RESUME,
            total_lines=count_lines(IN_PATH),
            dry_run=DRY_RUN,
        ) as run:
            run_id = run.id if run else None
            resumed_from = run.resume_from if run else 0
            if resumed_from:
                print(f"Resuming run {run_id} from line {resumed_from:,}")
            with conn.cursor() as cur:
                with IN_PATH.open("r", encoding="utf-8") as f:
                    for line in f:
                        line = line.strip()
                        if not line:
                            continue
                        total += 1

                        # Lines an earlier attempt already committed.
                        if run and run.should_skip(total):
                            skipped_resume += 1
                            continue

                        obj = json.loads(line)

                        # generator writes error rows without definition_sw
                        definition_sw = (obj.get("definition_sw") or "").strip()
                        sense_id = obj.get("sense_id")

                        if not sense_id or not definition_sw:
                            skipped_bad += 1
                            continue

                        # Parsed before the gate, which reads it. Kept so the
                        # review queue can also lead with the definitions the
                        # model was least sure about.
                        confidence = obj.get("confidence")
                        try:
                            confidence = None if confidence is None else float(confidence)
                        except (TypeError, ValueError):
                            confidence = None

                        # The gate. Text that cannot be a Swahili definition is
                        # refused here rather than left for a reviewer to find.
                        problems = (
                            []
                            if SKIP_VALIDATION
                            else check_definition(
                                definition_sw,
                                lemma=obj.get("lemma"),
                                source_definition=obj.get("en_definition"),
                                min_length=MIN_LENGTH,
                                max_length=MAX_LENGTH,
                            )
                        )
                        if (
                            not SKIP_VALIDATION
                            and confidence is not None
                            and confidence < MIN_CONFIDENCE
                        ):
                            problems.append("model_not_confident")

                        if sense_id in seen_senses:
                            problems.append("duplicate_in_file")
                        seen_senses.add(sense_id)

                        if not SKIP_VALIDATION:
                            fingerprint = " ".join(definition_sw.lower().split())
                            text_uses[fingerprint] = text_uses.get(fingerprint, 0) + 1
                            if text_uses[fingerprint] > REUSED_TEXT_LIMIT:
                                problems.append("reused_text")

                        if problems:
                            rejected_rows += 1
                            for reason in problems:
                                rejected_by_reason[reason] = rejected_by_reason.get(reason, 0) + 1
                            if rejects_file is None:
                                REJECTS_PATH.parent.mkdir(parents=True, exist_ok=True)
                                rejects_file = REJECTS_PATH.open("w", encoding="utf-8")
                            rejects_file.write(
                                json.dumps(
                                    {"line": total, "problems": problems, "row": obj},
                                    ensure_ascii=False,
                                )
                                + "\n"
                            )
                            continue

                        # sense_id might be string UUID; keep it as string for psycopg
                        gloss_sw = obj.get("gloss_sw", None)
                        ai_model = obj.get("model") or DEFAULT_MODEL
                        prompt_version = obj.get("prompt_version") or DEFAULT_PROMPT_VERSION

                        new_id = str(uuid.uuid4())
                        cur.execute(
                            upsert_sql,
                            (
                                new_id,
                                sense_id,
                                definition_sw,
                                gloss_sw,
                                IS_PRIMARY,
                                AI_SOURCE_ID,
                                INITIAL_REVIEW_STATUS,
                                ai_model,
                                prompt_version,
                                confidence,
                                run_id,
                            ),
                        )

                        # rowcount meaning differs between DO NOTHING vs DO UPDATE
                        if ON_CONFLICT == "update":
                            # rowcount is 1 for both insert and update paths here, so
                            # this counts rows written rather than rows created.
                            updated += 1
                        else:
                            if cur.rowcount == 1:
                                inserted += 1
                            else:
                                skipped_conflict += 1

                        if run:
                            run.counts["definitions_created"] = inserted + updated

                        # A bounded transaction: a failure costs at most one batch,
                        # and the checkpoint rides along with it.
                        if not DRY_RUN and total % BATCH_SIZE == 0:
                            if run:
                                run.commit_batch(total)
                                print(run.progress(total), flush=True)
                            else:
                                conn.commit()

                if DRY_RUN:
                    conn.rollback()
                elif run:
                    run.commit_batch(total)
                else:
                    conn.commit()

    finally:
        if rejects_file is not None:
            rejects_file.close()

    print("✅ Dry run finished — nothing written" if DRY_RUN else "✅ Import finished")
    print(f"Input lines read:           {total}")
    print(f"Inserted (new sw rows):     {inserted}")
    print(f"Skipped (conflict existing):{skipped_conflict}")
    print(f"Written (update mode):      {updated}")
    print(f"Skipped (bad/error rows):   {skipped_bad}")
    if skipped_resume:
        print(f"Skipped (already imported): {skipped_resume}")

    if SKIP_VALIDATION:
        print()
        print("⚠️  Validation was skipped (SKIP_VALIDATION): nothing was checked.")
    elif rejected_rows:
        print()
        # Reasons sum to more than rows: one definition can fail several checks.
        print(f"Refused by the quality gate: {rejected_rows} rows")
        for reason, count in sorted(
            rejected_by_reason.items(), key=lambda pair: (-pair[1], pair[0])
        ):
            print(f"  {reason:<20}{count}")
        print(f"Written to: {REJECTS_PATH}")
        print("Each line has the problems found and the original row, so a bad")
        print("prompt can be diagnosed from what it produced.")
    print(f"AI_SOURCE_ID:              {AI_SOURCE_ID}")
    print(f"IN_PATH:                   {IN_PATH.resolve()}")
    print(f"DB_URL:                    {DB_URL}")
    print()
    print("Imported rows are is_ai_generated=true, review_status='unreviewed':")
    print("hidden from the public API until approved in the admin review queue.")
    if run_id and not DRY_RUN:
        print()
        print(f"Import run:                {run_id}")
        print("Undo it with:")
        print(f"  python tools/maintenance/revert_import.py {run_id}")


if __name__ == "__main__":
    main()
