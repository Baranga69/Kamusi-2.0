#!/usr/bin/env python3
"""A starter set of methali and nahau, with their meanings.

Why this is a script and not a database insert
----------------------------------------------
The Swahili part-of-speech labels in this project existed in exactly one
developer's database and nowhere in version control, and were nearly lost in
a rebuild. Content belongs in the repository, where it can be reviewed in a
diff, corrected in a commit, and loaded into every environment.

Provenance, honestly
--------------------
These came from a language model's knowledge of widely-cited Swahili
proverbs, not from a cited published collection. They are well known and the
renderings are careful, but **a native speaker should check them**, and the
English is a gloss of the sense rather than a literal translation.

`expression_meaning` has no `review_status` column, so unlike AI definitions
there is no review guard to hide these from readers. `workflow` is the only
gate, which is why everything here loads as **draft**: invisible to search
and to the public API until somebody publishes it deliberately.

Usage
-----
    cd apps/api
    export DATABASE_URL="postgresql+psycopg://kamusi:kamusi123@localhost:5433/kamusi"

    poetry run python scripts/seed_methali.py            # report what it would add
    poetry run python scripts/seed_methali.py --apply

Idempotent: matching is on the normalised text, so re-running adds nothing
and never duplicates an existing proverb.
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

from sqlalchemy import select

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.db import SessionLocal  # noqa: E402
from app.models import (  # noqa: E402
    Expression,
    ExpressionMeaning,
    ExpressionType,
    License,
    Source,
)
from app.normalize import normalize_sw  # noqa: E402

SOURCE_TITLE = "Methali na nahau za kawaida (zilizokusanywa)"

# (type_code, text, swahili meaning, english meaning, usage context or None)
#
# Kept to proverbs and idioms in common currency. A proverb nobody says is
# not worth a dictionary entry, and a half-remembered one is worse than none.
ENTRIES: list[tuple[str, str, str, str, str | None]] = [
    # --- methali: full proverbs ------------------------------------------
    (
        "methali",
        "Haraka haraka haina baraka.",
        "Kufanya jambo kwa pupa hakuleti mafanikio; upesi upesi huharibu kazi.",
        "Haste brings no blessing; work done in a rush turns out badly.",
        "Huambiwa mtu anayeharakisha kazi bila kuitendea haki.",
    ),
    (
        "methali",
        "Polepole ndio mwendo.",
        "Kwenda taratibu kwa uthabiti ni njia ya kufika; si mwendo wa kasi.",
        "Slow and steady is the way to arrive.",
        None,
    ),
    (
        "methali",
        "Mtoto umleavyo ndivyo akuavyo.",
        "Tabia ya mtu mzima hutokana na malezi aliyopata akiwa mdogo.",
        "A child becomes what you raise them to be.",
        "Hutumiwa kuhusu wajibu wa wazazi katika malezi.",
    ),
    (
        "methali",
        "Penye nia ipo njia.",
        "Mtu akiwa na nia ya kweli ya kufanya jambo, hupata njia ya kulifanya.",
        "Where there is a will, there is a way.",
        None,
    ),
    (
        "methali",
        "Haba na haba hujaza kibaba.",
        "Vitu vidogo vikikusanywa taratibu hatimaye hujaa na kuwa vingi.",
        "Little by little fills the measure; small amounts accumulate.",
        "Hutumiwa kuhimiza kuweka akiba kidogo kidogo.",
    ),
    (
        "methali",
        "Usipoziba ufa utajenga ukuta.",
        "Ukiacha tatizo dogo bila kulitatua, litakua tatizo kubwa linalogharimu zaidi.",
        "If you do not seal the crack, you will have to build a wall.",
        "Hutumiwa kuhusu kutatua matatizo mapema.",
    ),
    (
        "methali",
        "Mvumilivu hula mbivu.",
        "Anayesubiri kwa uvumilivu hupata kilicho bora mwishowe.",
        "The patient one eats the ripe fruit.",
        None,
    ),
    (
        "methali",
        "Umoja ni nguvu, utengano ni udhaifu.",
        "Watu wakishirikiana huwa na nguvu; wakitengana hudhoofika.",
        "Unity is strength; division is weakness.",
        None,
    ),
    (
        "methali",
        "Asiyesikia la mkuu huvunjika guu.",
        "Anayekataa shauri la mtu mwenye busara au mamlaka hupata madhara.",
        "One who will not heed an elder's word ends up with a broken leg.",
        None,
    ),
    (
        "methali",
        "Maji yakimwagika hayazoleki.",
        "Jambo likitendeka na kupita, haliwezi kurudishwa katika hali yake ya awali.",
        "Spilt water cannot be gathered up again.",
        "Hutumiwa kuhusu mambo yasiyoweza kurekebishwa.",
    ),
    (
        "methali",
        "Kuishi kwingi ni kuona mengi.",
        "Mtu anayeishi muda mrefu hupata kuona na kujifunza mambo mengi.",
        "To live long is to see much.",
        None,
    ),
    (
        "methali",
        "Ahadi ni deni.",
        "Ukimwahidi mtu jambo, unawajibika kulitimiza kama unavyolipa deni.",
        "A promise is a debt; what you pledge, you owe.",
        None,
    ),
    (
        "methali",
        "Baada ya dhiki faraja.",
        "Baada ya kipindi cha shida na taabu hufuata kipindi cha raha na utulivu.",
        "After hardship comes relief.",
        "Hutumiwa kumtia moyo mtu aliye katika shida.",
    ),
    (
        "methali",
        "Mkono mtupu haulambwi.",
        "Mtu asiye na kitu cha kutoa hapati msaada wala upendeleo kwa urahisi.",
        "An empty hand does not get licked.",
        None,
    ),
    (
        "methali",
        "Simba mwenda kimya ndiye mla nyama.",
        "Anayefanya kazi kwa utulivu bila kujitangaza ndiye anayefanikiwa.",
        "It is the silent-moving lion that eats the meat.",
        None,
    ),
    (
        "methali",
        "Dawa ya moto ni moto.",
        "Jambo gumu hukabiliwa kwa njia ya ugumu wa kadiri yake.",
        "The remedy for fire is fire; meet force with force.",
        None,
    ),
    (
        "methali",
        "Heri kufa macho kuliko kufa moyo.",
        "Ni bora kupoteza uwezo wa kuona kuliko kupoteza matumaini na ari ya kuendelea.",
        "Better to lose your eyes than to lose heart.",
        None,
    ),
    (
        "methali",
        "Mchagua jembe si mkulima.",
        "Anayechagua sana vifaa au kazi hafanyi kazi kwa dhati.",
        "One who is choosy about hoes is no farmer.",
        None,
    ),
    (
        "methali",
        "Akili ni mali.",
        "Busara na maarifa ni utajiri wa mtu, kuliko vitu anavyomiliki.",
        "Wits are wealth; sense is a man's true property.",
        None,
    ),
    (
        "methali",
        "Chovya chovya humaliza buyu la asali.",
        "Kuchukua kidogo mara nyingi hatimaye humaliza kiasi kikubwa.",
        "Dipping again and again empties the gourd of honey.",
        "Hutumiwa kuhusu matumizi madogo yanayomaliza akiba.",
    ),
    (
        "methali",
        "Mtaka cha mvunguni sharti ainame.",
        "Anayetaka kupata kitu cha thamani sharti ajishushe na kujitahidi.",
        "One who wants what is under the bed must bend down for it.",
        None,
    ),
    (
        "methali",
        "Kidole kimoja hakivunji chawa.",
        "Mtu mmoja peke yake hawezi kufanikisha jambo linalohitaji ushirikiano.",
        "A single finger cannot crush a louse.",
        None,
    ),
    (
        "methali",
        "Subira huvuta heri.",
        "Kuwa na uvumilivu huleta matokeo mema.",
        "Patience draws good fortune to itself.",
        None,
    ),
    (
        "methali",
        "Mpanda ngazi hushuka.",
        "Aliyepanda cheo au hadhi siku moja atashuka; hakuna anayebaki juu daima.",
        "Whoever climbs the ladder will come down again.",
        None,
    ),
    (
        "methali",
        "Fadhila ya punda ni mateke.",
        "Wakati mwingine wema unaofanya hulipwa kwa ubaya.",
        "The donkey repays kindness with a kick.",
        "Hutumiwa kuhusu kutokuwa na shukrani.",
    ),
    (
        "methali",
        "Kila ndege huruka na mbawa zake.",
        "Kila mtu hutegemea uwezo na juhudi zake mwenyewe.",
        "Every bird flies with its own wings.",
        None,
    ),
    (
        "methali",
        "Jifya moja haliinjiki chungu.",
        "Jiwe moja la jiko haliwezi kuhimili chungu; jambo kubwa linahitaji watu wengi.",
        "One hearthstone will not hold up the cooking pot.",
        None,
    ),
    # --- nahau: idiomatic phrases ----------------------------------------
    (
        "nahau",
        "Kupiga moyo konde",
        "Kujipa nguvu na ujasiri wa kuvumilia au kufanya jambo gumu.",
        "To steel one's heart; to brace oneself and take courage.",
        None,
    ),
    (
        "nahau",
        "Kula chumvi nyingi",
        "Kuishi miaka mingi; kuwa mtu mzima aliyeona mengi.",
        "To have eaten much salt, i.e. to have lived a long life.",
        None,
    ),
    (
        "nahau",
        "Kufa moyo",
        "Kukata tamaa na kupoteza ari ya kuendelea.",
        "To lose heart; to give up hope.",
        None,
    ),
    (
        "nahau",
        "Kuona cha mtema kuni",
        "Kupata mateso au shida kubwa isiyotarajiwa.",
        "To see what the woodcutter saw, i.e. to suffer badly.",
        None,
    ),
    (
        "nahau",
        "Kutia fora",
        "Kufanya vizuri kupita wengine; kushinda.",
        "To excel; to come out on top.",
        None,
    ),
    (
        "nahau",
        "Kushika tama",
        "Kukaa katika hali ya huzuni au mshangao, mkono shavuni.",
        "To sit with the chin in the hand, i.e. to be downcast.",
        None,
    ),
    (
        "nahau",
        "Kuwa na mkono mrefu",
        "Kuwa na tabia ya kuiba.",
        "To have a long hand, i.e. to be light-fingered.",
        None,
    ),
    (
        "nahau",
        "Kuvunja mbavu",
        "Kuchekesha sana.",
        "To break ribs, i.e. to make someone laugh a great deal.",
        None,
    ),
    (
        "nahau",
        "Kutoa mkono wa buriani",
        "Kuaga kwa mara ya mwisho.",
        "To give the hand of farewell; to say a final goodbye.",
        None,
    ),
    (
        "msemo",
        "Kutoa ni moyo, si utajiri.",
        "Ukarimu hutoka moyoni, si kwa sababu mtu ana mali nyingi.",
        "Giving comes from the heart, not from riches.",
        None,
    ),
]


def resolve_source(db) -> Source:
    source = db.scalar(select(Source).where(Source.title == SOURCE_TITLE))
    if source:
        return source
    license_ = db.scalar(select(License).limit(1))
    source = Source(
        title=SOURCE_TITLE,
        source_type="editorial",
        license_id=license_.id if license_ else None,
        notes=(
            "Common Swahili proverbs and idioms contributed from a language "
            "model's knowledge rather than a cited published collection. "
            "Needs checking by a native speaker; the English is a gloss of "
            "the sense, not a literal translation."
        ),
    )
    db.add(source)
    db.commit()
    return source


def main() -> int:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("--apply", action="store_true", help="commit (default: dry run)")
    parser.add_argument(
        "--workflow",
        default="draft",
        choices=["draft", "reviewed", "published"],
        help="state to load them in (default: draft, so nothing reaches readers unchecked)",
    )
    args = parser.parse_args()

    db = SessionLocal()
    try:
        types = {row.code: row.id for row in db.scalars(select(ExpressionType)).all()}
        missing_types = {code for code, *_ in ENTRIES} - types.keys()
        if missing_types:
            print(f"❌ Missing expression_type rows: {sorted(missing_types)}")
            print("   Run scripts/seed.py first.")
            return 1

        existing = {
            row.normalized_text for row in db.scalars(select(Expression)).all()
        }

        to_add = [e for e in ENTRIES if normalize_sw(e[1]) not in existing]
        already = len(ENTRIES) - len(to_add)

        print(f"Mode:      {'APPLY' if args.apply else 'DRY RUN'}")
        print(f"Workflow:  {args.workflow}")
        print(f"In file:   {len(ENTRIES)}")
        print(f"Already present: {already}")
        print(f"Would add: {len(to_add)}")
        print()
        by_type: dict[str, int] = {}
        for type_code, *_ in to_add:
            by_type[type_code] = by_type.get(type_code, 0) + 1
        for type_code, count in sorted(by_type.items()):
            print(f"  {type_code:<10}{count}")
        print()

        if to_add:
            print("Sample:")
            for type_code, text, sw, en, _ in to_add[:5]:
                print(f"  [{type_code}] {text}")
                print(f"     sw: {sw[:72]}")
                print(f"     en: {en[:72]}")
            if len(to_add) > 5:
                print(f"  ... and {len(to_add) - 5} more")
            print()

        if not to_add:
            print("Nothing to add.")
            return 0

        if not args.apply:
            print("Dry run: nothing written. Re-run with --apply to commit.")
            return 0

        source = resolve_source(db)
        added = 0
        for type_code, text, sw, en, context in to_add:
            expression = Expression(
                text=text,
                normalized_text=normalize_sw(text),
                expression_type_id=types[type_code],
                workflow=args.workflow,
            )
            db.add(expression)
            db.commit()
            db.add_all(
                [
                    ExpressionMeaning(
                        expression_id=expression.id,
                        lang_code="sw",
                        meaning=sw,
                        usage_context=context,
                        is_primary=True,
                        source_id=source.id,
                    ),
                    ExpressionMeaning(
                        expression_id=expression.id,
                        lang_code="en",
                        meaning=en,
                        is_primary=False,
                        source_id=source.id,
                    ),
                ]
            )
            db.commit()
            added += 1

        print(f"✅ Added {added} expressions as '{args.workflow}'")
        print(f"   source: {source.title}")
        if args.workflow != "published":
            print()
            print("They are not visible to readers yet. expression_meaning has no")
            print("review_status column, so workflow is the only gate — publish them")
            print("from the admin console, or re-run with --workflow published once a")
            print("native speaker has checked them.")
        return 0
    finally:
        db.close()


if __name__ == "__main__":
    sys.exit(main())
