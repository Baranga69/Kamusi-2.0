#!/usr/bin/env python3
"""Fill an empty database with enough content to actually use the app.

`seed.py` creates the lookup tables — languages, parts of speech, tag types —
but leaves the dictionary empty, so a fresh checkout gives you a search box
that finds nothing, no word of the day, an empty review queue and a Jifunze
tab that correctly reports there is nothing to quiz. That is accurate and
unhelpful.

This seeds a small, real Swahili corpus so every surface has something to
show:

* published words with Swahili definitions and usage examples — search,
  lexeme detail, word of the day, and the word→meaning games
* published methali with their meanings — expression search and the proverb
  game
* a few AI-generated Swahili definitions left **unreviewed** — these are
  hidden from readers and waiting in the admin review queue, which is the
  one loop worth seeing end to end: approve one, then watch it appear in the
  public API and in search

Idempotent: re-running adds nothing, so it is safe against a database that is
already partly seeded.

Usage
-----
    cd apps/api
    poetry run alembic upgrade head
    poetry run python scripts/seed.py        # lookup tables first
    poetry run python scripts/seed_demo.py

    poetry run python scripts/seed_demo.py --skip-review-queue
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

from sqlalchemy import func, select

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.db import SessionLocal  # noqa: E402
from app.models import (  # noqa: E402
    Example,
    ExampleText,
    Expression,
    ExpressionMeaning,
    ExpressionType,
    Lexeme,
    License,
    PartOfSpeech,
    Sense,
    SenseDefinition,
    Source,
)
from app.normalize import normalize_sw  # noqa: E402
from app.services.publish import publish_expression, publish_lexeme  # noqa: E402

# lemma, part of speech, Swahili definition, example sentence
WORDS = [
    ("mti", "NOUN", "Mmea mkubwa wenye shina gumu na matawi mengi.", "Nimepanda mti nyuma ya nyumba."),
    ("kitabu", "NOUN", "Karatasi zilizofungwa pamoja zenye maandishi ya kusoma.", "Nilisoma kitabu kizuri jana."),
    ("mwalimu", "NOUN", "Mtu anayefundisha wanafunzi shuleni.", "Mwalimu wetu ni mpole sana."),
    ("shule", "NOUN", "Mahali ambapo watoto hujifunza masomo mbalimbali.", "Watoto wameenda shule asubuhi."),
    ("chakula", "NOUN", "Kitu chochote kinacholiwa na watu au wanyama.", "Chakula cha jioni kimeiva."),
    ("maji", "NOUN", "Kiowevu kisicho na rangi ambacho tunakinywa.", "Tafadhali nipe maji ya kunywa."),
    ("ng'ombe", "NOUN", "Mnyama wa kufugwa anayetoa maziwa na nyama.", "Ng'ombe wanalisha shambani."),
    ("nyumba", "NOUN", "Jengo ambalo watu hukaa na kulala.", "Nyumba yao ni kubwa na nzuri."),
    ("rafiki", "NOUN", "Mtu unayempenda na kumwaminia sana.", "Rafiki yangu amefika mjini."),
    ("jua", "NOUN", "Nyota inayotoa mwanga na joto duniani.", "Jua linawaka kwa nguvu leo."),
    ("barabara", "NOUN", "Njia pana inayotumiwa na magari na watu.", "Barabara hii inaelekea mjini."),
    ("samaki", "NOUN", "Mnyama anayeishi majini na huliwa kama chakula.", "Tumevua samaki wengi baharini."),
    ("mvua", "NOUN", "Maji yanayoanguka kutoka mawinguni.", "Mvua imenyesha usiku kucha."),
    ("kupika", "VERB", "Kutayarisha chakula kwa kutumia moto.", "Mama anapika wali jikoni."),
    ("kusoma", "VERB", "Kutazama maandishi na kuyafahamu maana yake.", "Napenda kusoma vitabu vya hadithi."),
    ("kucheza", "VERB", "Kufanya mchezo kwa furaha na burudani.", "Watoto wanacheza uwanjani."),
    ("kulala", "VERB", "Kupumzika kwa kufumba macho usingizini.", "Analala mapema kila siku."),
    ("kuimba", "VERB", "Kutoa sauti ya muziki kwa maneno.", "Kwaya inaimba kanisani."),
]

METHALI = [
    ("Haraka haraka haina baraka", "Kufanya mambo kwa pupa huleta makosa."),
    ("Polepole ndiyo mwendo wa busara", "Utulivu na uvumilivu huleta mafanikio."),
    ("Mvumilivu hula mbivu za mtini", "Mtu anayesubiri hupata kilicho bora."),
    ("Umoja ni nguvu utengano ni udhaifu", "Kushirikiana huleta nguvu, kutengana huleta udhaifu."),
    ("Mtoto umleavyo ndivyo akuavyo", "Malezi ya mtoto huamua tabia yake akiwa mkubwa."),
    ("Penye nia ipo njia", "Mtu akiwa na nia thabiti atapata njia ya kufanikiwa."),
    ("Asiyesikia la mkuu huvunjika guu", "Asiyekubali shauri la mkubwa hupata matatizo."),
    ("Mgaagaa na upwa hali wali mkavu", "Mtu anayejitahidi hupata riziki nzuri."),
]

# lemma, POS, English definition, machine-generated Swahili definition.
# These land unreviewed, so they are hidden from readers and sit in the queue.
AWAITING_REVIEW = [
    ("kalamu", "NOUN", "a pen or pencil", "Kifaa kinachotumika kuandika."),
    ("mlango", "NOUN", "a door", "Sehemu ya kuingia na kutoka katika jengo."),
    ("kiti", "NOUN", "a chair", "Kitu cha kukalia chenye miguu."),
    ("dirisha", "NOUN", "a window", "Nafasi ukutani inayoruhusu mwanga kuingia."),
    ("kununua", "VERB", "to buy", "Kuchukua kitu kwa kulipa pesa."),
    ("kuandika", "VERB", "to write", "Kuweka maneno kwenye karatasi."),
]


def get_or_create_source(db, *, title: str, source_type: str, license_id) -> Source:
    source = db.scalar(select(Source).where(Source.title == title))
    if source:
        return source
    source = Source(title=title, source_type=source_type, license_id=license_id)
    db.add(source)
    db.commit()
    return source


def existing_lemma(db, lemma: str, pos_id) -> Lexeme | None:
    return db.scalar(
        select(Lexeme).where(
            Lexeme.normalized_lemma == normalize_sw(lemma), Lexeme.pos_id == pos_id
        )
    )


def add_word(db, lemma, pos, definition, example_text) -> bool:
    """Returns False when the word is already there."""
    if existing_lemma(db, lemma, pos.id):
        return False

    lexeme = Lexeme(
        lemma=lemma,
        normalized_lemma=normalize_sw(lemma),
        pos_id=pos.id,
        status="core",
        default_language_code="sw",
        workflow="draft",
    )
    db.add(lexeme)
    db.commit()

    sense = Sense(lexeme_id=lexeme.id, sense_number=1, workflow="draft")
    db.add(sense)
    db.commit()

    db.add(
        SenseDefinition(
            sense_id=sense.id, lang_code="sw", definition=definition, is_primary=True
        )
    )
    example = Example(sense_id=sense.id, is_attested=True)
    db.add(example)
    db.commit()
    db.add(
        ExampleText(
            example_id=example.id, lang_code="sw", text=example_text, is_primary=True
        )
    )
    db.commit()

    publish_lexeme(db, lexeme.id)
    return True


def add_word_awaiting_review(db, lemma, pos, english, swahili, ai_source) -> bool:
    """A published word whose Swahili definition is machine-made and unreviewed.

    The English definition is visible immediately; the Swahili one is hidden
    from readers and from search until someone approves it in the admin queue.
    That asymmetry is the whole point of the review pipeline, and it is hard to
    appreciate without an example in front of you.
    """
    if existing_lemma(db, lemma, pos.id):
        return False

    lexeme = Lexeme(
        lemma=lemma,
        normalized_lemma=normalize_sw(lemma),
        pos_id=pos.id,
        status="core",
        default_language_code="sw",
        workflow="draft",
    )
    db.add(lexeme)
    db.commit()

    sense = Sense(lexeme_id=lexeme.id, sense_number=1, workflow="draft")
    db.add(sense)
    db.commit()

    db.add(
        SenseDefinition(
            sense_id=sense.id, lang_code="en", definition=english, is_primary=True
        )
    )
    db.add(
        SenseDefinition(
            sense_id=sense.id,
            lang_code="sw",
            definition=swahili,
            is_primary=True,
            source_id=ai_source.id,
            is_ai_generated=True,
            review_status="unreviewed",
            ai_model="gpt-4o-mini",
            ai_prompt_version="v1",
        )
    )
    db.commit()

    publish_lexeme(db, lexeme.id)
    return True


def add_methali(db, text, meaning, expression_type) -> bool:
    normalized = normalize_sw(text)
    if db.scalar(select(Expression).where(Expression.normalized_text == normalized)):
        return False

    expression = Expression(
        text=text,
        normalized_text=normalized,
        expression_type_id=expression_type.id,
        workflow="draft",
    )
    db.add(expression)
    db.commit()
    db.add(
        ExpressionMeaning(
            expression_id=expression.id, lang_code="sw", meaning=meaning, is_primary=True
        )
    )
    db.commit()

    publish_expression(db, expression.id)
    return True


def main() -> int:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument(
        "--skip-review-queue",
        action="store_true",
        help="do not create the unreviewed AI definitions",
    )
    args = parser.parse_args()

    db = SessionLocal()
    try:
        pos_by_code = {pos.code: pos for pos in db.scalars(select(PartOfSpeech)).all()}
        expression_type = db.scalar(
            select(ExpressionType).where(ExpressionType.code == "methali")
        )
        if not pos_by_code or expression_type is None:
            print("❌ Lookup tables are empty. Run scripts/seed.py first.")
            return 1

        needed = {pos for _, pos, _, _ in WORDS} | {pos for _, pos, _, _ in AWAITING_REVIEW}
        missing = needed - set(pos_by_code)
        if missing:
            print(f"❌ Missing parts of speech: {', '.join(sorted(missing))}")
            return 1

        license_ = db.scalar(select(License).where(License.name == "CC BY-SA 4.0"))
        if not license_:
            license_ = License(
                name="CC BY-SA 4.0",
                summary="Attribution, share-alike",
                can_display=True,
                can_modify=True,
            )
            db.add(license_)
            db.commit()

        ai_source = get_or_create_source(
            db, title="AI draft (demo)", source_type="ai", license_id=license_.id
        )

        words = sum(
            add_word(db, lemma, pos_by_code[pos], definition, example)
            for lemma, pos, definition, example in WORDS
        )
        methali = sum(
            add_methali(db, text, meaning, expression_type) for text, meaning in METHALI
        )
        queued = 0
        if not args.skip_review_queue:
            queued = sum(
                add_word_awaiting_review(
                    db, lemma, pos_by_code[pos], english, swahili, ai_source
                )
                for lemma, pos, english, swahili in AWAITING_REVIEW
            )

        total_lexemes = db.scalar(select(func.count()).select_from(Lexeme))
        total_expressions = db.scalar(select(func.count()).select_from(Expression))
    finally:
        db.close()

    print("✅ Demo content ready")
    print(f"   words added:            {words}")
    print(f"   methali added:          {methali}")
    print(f"   awaiting review:        {queued}")
    print(f"   lexemes in database:    {total_lexemes}")
    print(f"   expressions in database:{total_expressions}")
    if words == 0 and methali == 0 and queued == 0:
        print("   (nothing new — this script is idempotent)")
    print()
    print("Try it:")
    print('  curl "http://localhost:8000/search?q=ngombe&lang=sw"')
    print('  curl "http://localhost:8000/learn/daily?lang=sw"')
    if queued:
        print("  Admin → Review: approve one, then search for it. It was hidden until then.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
