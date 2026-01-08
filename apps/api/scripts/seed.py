from sqlalchemy.dialects.postgresql import insert

from app.db import SessionLocal
from app.models import Domain, ExpressionType, Language, PartOfSpeech, Register, TagType

LANGUAGES = [
    {"code": "sw", "name": "Swahili"},
    {"code": "en", "name": "English"},
]

PARTS_OF_SPEECH = [
    "NOUN",
    "VERB",
    "ADJ",
    "ADV",
    "PRON",
    "PREP",
    "CONJ",
    "INTJ",
    "NUM",
    "IDEO",
    "PROPN",
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
            [{"code": code, "label": code} for code in PARTS_OF_SPEECH],
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
