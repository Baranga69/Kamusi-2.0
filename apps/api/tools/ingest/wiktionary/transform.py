import json
import re
import csv
from pathlib import Path
from typing import Any, Dict, List, Optional

POS_MAP = {
    # wiktwords pos strings -> your POS codes
    "noun": "NOUN",
    "proper noun": "PROPN",
    "verb": "VERB",
    "adjective": "ADJ",
    "adverb": "ADV",
    "pronoun": "PRON",
    "preposition": "PREP",
    "conjunction": "CONJ",
    "interjection": "INTJ",
    "numeral": "NUM",
    "ideophone": "IDEO",
    # sometimes seen:
    "name": "PROPN",
}

def normalize_lemma(s: str) -> str:
    s = s.strip()
    s = re.sub(r"\s+", " ", s)
    return s.lower()

def pick_pos_code(obj: Dict[str, Any]) -> Optional[str]:
    # Prefer head_templates args["2"] e.g. "proper noun"
    for ht in obj.get("head_templates", []) or []:
        args = (ht.get("args") or {})
        v2 = args.get("2")
        if isinstance(v2, str) and v2.strip():
            key = v2.strip().lower()
            if key in POS_MAP:
                return POS_MAP[key]

    pos = obj.get("pos")
    if isinstance(pos, str):
        key = pos.strip().lower()
        return POS_MAP.get(key)
    return None

def extract_def_texts(sense: Dict[str, Any]) -> List[str]:
    """
    wiktwords output varies. Capture the common shapes:
    - glosses/raw_glosses: list[str]
    - definitions: list[str] or list[dict]
    - definition/text/sense: str
    """
    out: List[str] = []

    # 1) glosses (most common)
    for k in ("glosses", "raw_glosses"):
        v = sense.get(k)
        if isinstance(v, list):
            for x in v:
                if isinstance(x, str) and x.strip():
                    out.append(x.strip())

    # 2) definitions can be list[str] or list[dict{text:..}]
    v = sense.get("definitions")
    if isinstance(v, list):
        for x in v:
            if isinstance(x, str) and x.strip():
                out.append(x.strip())
            elif isinstance(x, dict):
                txt = x.get("text") or x.get("definition") or x.get("gloss")
                if isinstance(txt, str) and txt.strip():
                    out.append(txt.strip())

    # 3) simple string fallbacks
    for k in ("definition", "text", "sense"):
        v = sense.get(k)
        if isinstance(v, str) and v.strip():
            out.append(v.strip())

    # de-dupe while preserving order
    seen = set()
    uniq = []
    for x in out:
        if x not in seen:
            seen.add(x)
            uniq.append(x)

    return uniq

def extract_examples(sense: Dict[str, Any]) -> List[Dict[str, Any]]:
    # wiktwords sometimes has examples in various shapes; start minimal.
    exs = []
    v = sense.get("examples")
    if isinstance(v, list):
        for e in v:
            if isinstance(e, dict):
                txt = e.get("text") or e.get("example")
                if isinstance(txt, str) and txt.strip():
                    exs.append({
                        "lang": "sw",  # if provided later, we can override
                        "text": txt.strip(),
                        "is_attested": True
                    })
            elif isinstance(e, str) and e.strip():
                exs.append({"lang": "sw", "text": e.strip(), "is_attested": True})
    return exs

def main(
    input_path: str,
    output_path: str,
    rejects_csv_path: str,
    source_id: str,
    dump_date: str,
) -> None:
    in_path = Path(input_path)
    out_path = Path(output_path)
    rej_path = Path(rejects_csv_path)

    out_path.parent.mkdir(parents=True, exist_ok=True)
    rej_path.parent.mkdir(parents=True, exist_ok=True)

    with in_path.open("r", encoding="utf-8") as fin, \
         out_path.open("w", encoding="utf-8") as fout, \
         rej_path.open("w", encoding="utf-8", newline="") as frej:

        writer = csv.DictWriter(frej, fieldnames=["word", "reason"])
        writer.writeheader()

        for line in fin:
            line = line.strip()
            if not line:
                continue
            try:
                obj = json.loads(line)
            except Exception:
                writer.writerow({"word": "", "reason": "invalid_json"})
                continue

            if obj.get("lang_code") != "sw":
                continue

            word = obj.get("word")
            if not isinstance(word, str) or len(word.strip()) < 2:
                writer.writerow({"word": str(word) if word else "", "reason": "missing_word"})
                continue

            lemma = word.strip()
            if ":" in lemma:
                writer.writerow({"word": lemma, "reason": "namespace_like_word"})
                continue

            pos_code = pick_pos_code(obj)
            if not pos_code:
                writer.writerow({"word": lemma, "reason": "unknown_pos"})
                continue

            senses_in = obj.get("senses") or []
            if not isinstance(senses_in, list) or not senses_in:
                writer.writerow({"word": lemma, "reason": "no_senses"})
                continue

            senses_out = []
            sense_no = 0
            for s in senses_in:
                if not isinstance(s, dict):
                    continue
                tags = s.get("tags") or []
                if isinstance(tags, list) and any(isinstance(t, str) and t == "no-senses" for t in tags):
                    continue

                defs = extract_def_texts(s)
                if not defs:
                    continue

                sense_no += 1
                # IMPORTANT: glosses are usually EN. We store as EN.
                defs_out = [{
                    "lang": "en",
                    "text": defs[0],
                    "gloss": None,
                    "is_primary": True
                }]

                examples_out = extract_examples(s)

                senses_out.append({
                    "sense_number": sense_no,
                    "definitions": defs_out,
                    "examples": examples_out
                })

            if not senses_out:
                writer.writerow({"word": lemma, "reason": "no_usable_definitions"})
                continue

            media_audio = []
            for snd in obj.get("sounds") or []:
                if isinstance(snd, dict):
                    if snd.get("mp3_url") or snd.get("ogg_url"):
                        media_audio.append({
                            "file": snd.get("audio"),
                            "ogg_url": snd.get("ogg_url"),
                            "mp3_url": snd.get("mp3_url"),
                        })

            contract = {
                "version": 1,
                "source": {
                    "source_id": source_id,
                    "dump_date": dump_date,
                    "page_title": lemma
                },
                "lexeme": {
                    "lemma": lemma,
                    "normalized": normalize_lemma(lemma),
                    "pos_code": pos_code,
                    "default_language_code": "sw",
                    "workflow": "draft"
                },
                "senses": senses_out,
                "media": {
                    "audio": media_audio
                }
            }

            fout.write(json.dumps(contract, ensure_ascii=False) + "\n")

if __name__ == "__main__":
    # example usage:
    # python transform.py enwiktionary-20260101-sw.jsonl kamusi_contract-20260101.jsonl rejects-20260101.csv <SOURCE_ID> 2026-01-01
    import sys
    if len(sys.argv) != 6:
        print("Usage: python transform.py <in.jsonl> <out.jsonl> <rejects.csv> <source_id> <dump_date>")
        sys.exit(1)
    main(sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5])