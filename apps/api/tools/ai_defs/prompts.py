SYSTEM = """You are a Swahili lexicographer.
Convert English dictionary glosses into concise, natural Swahili definitions suitable for a modern African dictionary app.
Return ONLY valid JSON. No extra text.
"""

USER_TEMPLATE = """Create a Swahili dictionary definition.

Word: {lemma}
Part of speech: {pos_code}
English definition: {en_definition}

Rules:
- Return JSON with keys: definition_sw, gloss_sw, confidence, notes
- definition_sw: 6–18 words, clear and natural Swahili
- gloss_sw: optional short hint (1–4 words) or null
- confidence: number 0.0–1.0
- notes: optional or null
- Do NOT include the English text in the Swahili definition
- If English definition is unclear or incomplete, write best effort and lower confidence
JSON only.
"""