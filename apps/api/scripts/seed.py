from sqlalchemy.dialects.postgresql import insert

from app.db import SessionLocal
from app.models import Domain, ExpressionType, Language, PartOfSpeech, Register, TagType

LANGUAGES = [
    {"code": "sw", "name": "Swahili"},
    {"code": "en", "name": "English"},
]

# (code, English label, Swahili name, Swahili explanation).
#
# The Swahili columns existed only in one developer's database until migration
# 0009; they live here now so every environment gets them. For a Swahili-first
# dictionary this is the part a reader should see — "Nomino", not "NOUN".
PARTS_OF_SPEECH = [
    ("NOUN", "NOUN", "Nomino", "Neno linalotaja jina la mtu, kitu, mahali, wazo au hali."),
    ("VERB", "VERB", "Kitenzi", "Neno linaloonyesha kitendo, tukio au hali (mf. kula, kwenda, kuwa)."),
    ("ADJ", "ADJ", "Kivumishi", "Neno linaloeleza sifa au hali ya nomino (mf. mzuri, nyingi)."),
    (
        "ADV",
        "ADV",
        "Kielezi",
        "Neno linaloeleza jinsi, wakati, mahali au kiwango cha kitendo/sifa"
        " (mf. haraka, jana, hapa).",
    ),
    ("PRON", "PRON", "Kiwakilishi", "Neno linalochukua nafasi ya nomino (mf. mimi, yeye, hiki)."),
    (
        "PREP",
        "PREP",
        "Kihusishi",
        "Neno linaloonyesha uhusiano wa nomino/kiwakilishi na maneno mengine"
        " (mf. kwa, kwenye, kuhusu).",
    ),
    (
        "CONJ",
        "CONJ",
        "Kiunganishi",
        "Neno linalounganisha maneno, vishazi au sentensi (mf. na, au, lakini).",
    ),
    ("INTJ", "INTJ", "Kihisishi", "Neno la hisia au mshangao (mf. ah!, lo!, jamani!)."),
    (
        "NUM",
        "NUM",
        "Kivumishi cha Idadi",
        "Neno linaloonyesha idadi au mpangilio (mf. tatu, wa kwanza).",
    ),
    (
        "IDEO",
        "IDEO",
        "Kiigizo",
        "Neno linaloiga sauti, mwendo au hisia kwa msisitizo (mf. chapu, du, puu).",
    ),
    (
        "PROPN",
        "PROPN",
        "Jina Maalum",
        "Nomino inayoitaja jina maalum la mtu, mahali, shirika au kitu"
        " (mf. Nairobi, Amina, Tappi).",
    ),
]

REGISTERS = [
    "formal",
    "neutral",
    "informal",
    "slang",
    "vulgar",
    "archaic",
    "respectful",
]

DOMAINS = [
    "kawaida",
    "biashara",
    "sheria",
    "afya",
    "teknolojia",
    "fedha",
    "dini",
    "siasa",
    "elimu",
]

EXPRESSION_TYPES = ["methali", "semi", "nahau", "msemo"]

TAG_TYPES = ["style", "domain", "region", "era", "topic"]


def upsert_simple(session, model, rows, unique_cols):
    for row in rows:
        stmt = insert(model).values(**row)
        stmt = stmt.on_conflict_do_nothing(index_elements=unique_cols)
        session.execute(stmt)


def main() -> None:
    session = SessionLocal()
    try:
        upsert_simple(session, Language, LANGUAGES, [Language.code])
        upsert_simple(
            session,
            PartOfSpeech,
            [
                {
                    "code": code,
                    "label": label,
                    "label_sw": label_sw,
                    "definition_sw": definition_sw,
                }
                for code, label, label_sw, definition_sw in PARTS_OF_SPEECH
            ],
            [PartOfSpeech.code],
        )
        upsert_simple(
            session,
            Register,
            [{"code": code, "label": code} for code in REGISTERS],
            [Register.code],
        )
        upsert_simple(
            session,
            Domain,
            [{"code": code, "label": code} for code in DOMAINS],
            [Domain.code],
        )
        upsert_simple(
            session,
            ExpressionType,
            [{"code": code, "label": code} for code in EXPRESSION_TYPES],
            [ExpressionType.code],
        )
        upsert_simple(
            session,
            TagType,
            [{"code": code, "label": code} for code in TAG_TYPES],
            [TagType.code],
        )
        session.commit()
    finally:
        session.close()


if __name__ == "__main__":
    main()
