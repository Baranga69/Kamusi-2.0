"""What the ingest gate will and will not let through.

These checks decide what reaches a reviewer. The two failure modes pull in
opposite directions: too lax and a reviewer's time goes on obvious rubbish,
too strict and real definitions are silently discarded — which is worse, since
the point of the whole exercise is to grow the dictionary.

So the tests pin both sides. Every rejection case has a matching case that
looks similar and must survive.
"""
import pytest

from app.core.quality import (
    MORPHOLOGY_PREFIXES,
    is_bare_morphology_stub,
    analyze_english,
    check_definition,
    collapse,
    echoes,
    is_too_long,
    is_too_short,
    looks_english,
    looks_like_refusal,
    looks_morphological,
)

# Real Swahili definitions, the shape the model is asked to produce.
GOOD = [
    "chombo cha kuandikia chenye wino",
    "mnyama wa nyumbani anayefugwa kwa maziwa",
    "hali ya kuwa na furaha nyingi moyoni",
    "kitendo cha kuhamisha kitu kutoka mahali kimoja kwenda kingine",
]


@pytest.mark.parametrize("text", GOOD)
def test_a_real_definition_passes_every_check(text):
    assert check_definition(text, lemma="kalamu") == []


# --- English detection ----------------------------------------------------


def test_an_english_definition_is_caught():
    assert looks_english("a tool that is used for the writing of words")


def test_swahili_is_not_mistaken_for_english():
    for text in GOOD:
        assert not looks_english(text), text


def test_a_short_phrase_is_never_judged_english():
    """Too little evidence, and the cost of being wrong is losing content."""
    assert not looks_english("the")
    assert not looks_english("in na to")


def test_a_swahili_definition_quoting_english_survives():
    """An English phrase inside a Swahili definition is not an English one."""
    text = "mchezo wa kadi unaojulikana kwa Kiingereza kama the game of bridge"
    assert not looks_english(text)


def test_english_analysis_explains_itself():
    """A reviewer told the ratio can check the call; one told 'englishy' cannot."""
    hits, total, ratio = analyze_english("the writing of a word")
    assert (hits, total) == (3, 5)
    assert ratio == pytest.approx(0.6)


def test_analysis_of_wordless_text_does_not_divide_by_zero():
    assert analyze_english("123 ...") == (0, 0, 0.0)


# --- length ---------------------------------------------------------------


def test_a_one_word_gloss_is_too_short():
    assert is_too_short("kitu")


def test_a_definition_at_the_floor_is_kept():
    assert not is_too_short("a" * 12)


def test_an_essay_is_too_long():
    assert is_too_long("neno " * 200)


def test_length_is_measured_after_collapsing_whitespace():
    """Padding is not content; a definition of spaces is still too short."""
    assert is_too_short("   kitu   \n\n  ")


# --- refusals and placeholders -------------------------------------------


@pytest.mark.parametrize(
    "text", ["Siwezi kusaidia na hili", "As an AI, I cannot define this", "I am unable to help"]
)
def test_a_model_refusal_is_caught(text):
    assert looks_like_refusal(text)


@pytest.mark.parametrize("text", ["n/a", "N/A.", "unknown", "TODO", "-", "none"])
def test_a_placeholder_is_caught(text):
    assert looks_like_refusal(text)


def test_a_swahili_refusal_is_caught():
    """The model declines in the language it was asked to write in.

    This arrived as a real row: asked to define the proper noun "Panji" from
    the gloss "Dorado", the model wrote its apology into the definition
    field, where it reads as prose.
    """
    assert looks_like_refusal(
        "Samahani, neno hili halina maana inayojulikana katika Kiswahili."
    )
    assert looks_like_refusal("Hakuna maelezo ya kutosha kuhusu neno hili.")


def test_a_definition_about_meaninglessness_is_not_a_refusal():
    """Defining "nonsense" requires saying something has no meaning."""
    assert not looks_like_refusal("jambo lisilo na maana wala mpangilio")
    assert check_definition("jambo lisilo na maana wala mpangilio") == []


def test_a_definition_merely_containing_a_placeholder_word_survives():
    """'unknown' alone is a placeholder; inside a sentence it is a word."""
    text = "neno lenye asili isiyojulikana, unknown kwa Kiingereza"
    assert not looks_like_refusal(text)
    assert check_definition(text) == []


# --- morphology -----------------------------------------------------------


@pytest.mark.parametrize("prefix", MORPHOLOGY_PREFIXES)
def test_every_morphology_prefix_is_recognised(prefix):
    assert looks_morphological(f"{prefix} -penda")


def test_a_form_the_list_does_not_name_is_still_caught():
    """Detection is by shape, not by an enumerated list.

    A five-name list was already wrong on the first real corpus, which also
    held Conversive, Augmentative and Reduplicative — 21 stubs through the
    gate. Wiktionary will keep inventing these.
    """
    assert looks_morphological("Contactive form of -gusa")
    assert looks_morphological("Double-object form of -pa")


@pytest.mark.parametrize(
    "text",
    [
        "a form of government that is elected by citizens",
        "A form of government that is elected by citizens",
        "the plural form of a noun already in use",
        "one form of payment accepted at the counter",
    ],
)
def test_an_english_definition_about_forms_is_not_condemned(text):
    """The cost of over-matching here is discarding a real definition."""
    assert not looks_morphological(text)


def test_a_definition_merely_mentioning_a_form_survives():
    """Only a leading "X form of Y" is the non-definition."""
    assert not looks_morphological("hali ya kupenda, ni passive form of -penda")


# --- echoes ---------------------------------------------------------------


def test_a_definition_that_is_just_the_headword_is_caught():
    assert echoes("kalamu", "kalamu")
    assert "echoes_lemma" in check_definition("kalamu", lemma="kalamu")


def test_an_echo_is_caught_despite_case_and_spacing():
    assert echoes("  Kalamu ", "kalamu")


def test_a_definition_containing_the_headword_is_not_an_echo():
    """Swahili definitions often repeat the word; only a bare copy is wrong."""
    assert not echoes("kalamu ni chombo cha kuandikia", "kalamu")


def test_a_definition_copied_from_the_english_prompt_is_caught():
    english = "a writing implement that uses ink"
    assert "echoes_source" in check_definition(english, source_definition=english)


def test_echoes_tolerates_a_missing_comparison():
    assert not echoes("kalamu", None)


# --- the whole gate -------------------------------------------------------


def test_empty_text_reports_one_problem_not_five():
    """A reviewer reading the rejects file wants the cause, not a pile-on."""
    assert check_definition("") == ["empty"]
    assert check_definition(None) == ["empty"]
    assert check_definition("   \n ") == ["empty"]


def test_a_row_can_fail_several_checks():
    problems = check_definition("x", lemma="x")
    assert "too_short" in problems
    assert "echoes_lemma" in problems


def test_the_length_floor_is_adjustable():
    """A corpus of terse definitions should not need the gate disabled."""
    assert check_definition("kitu kidogo", min_length=5) == []
    assert "too_short" in check_definition("kitu kidogo", min_length=50)


def test_collapse_normalises_for_comparison():
    assert collapse("  a\n\tb  ") == "a b"
    assert collapse(None) == ""


# --- what the model was given, not what it returned -----------------------
#
# The hardest bad definition to catch is a fluent one. If the English source
# was a bare "Stative form of" with no gloss, the model had no semantic input,
# so whatever came back is invention — and it reads like a definition, which
# is exactly why nothing downstream notices. Judge the input instead.


@pytest.mark.parametrize(
    "source", ["Stative form of", "Stative form of ", "Stative form of :", "Passive form of"]
)
def test_a_stub_with_no_gloss_is_recognised(source):
    assert is_bare_morphology_stub(source)


@pytest.mark.parametrize(
    "source",
    [
        "Stative form of : to be rare",
        "Passive form of -ona",
        "a form of government that is elected",
        "a writing implement that uses ink",
    ],
)
def test_a_source_the_model_could_work_from_is_not_a_bare_stub(source):
    assert not is_bare_morphology_stub(source)


def test_a_definition_invented_from_a_bare_stub_is_refused():
    """Fluent Swahili, and still not a definition of anything."""
    problems = check_definition(
        "Aina ya kitenzi inayoonyesha hali au mwelekeo.",
        source_definition="Stative form of",
    )
    assert problems == ["source_was_bare_stub"]


def test_a_definition_built_from_a_glossed_stub_is_kept():
    """The model had the meaning to work from, and used it."""
    assert (
        check_definition(
            "Kuwa nadra au kutopatikana kwa urahisi.",
            source_definition="Stative form of : to be rare",
        )
        == []
    )


def test_a_missing_source_is_not_held_against_a_definition():
    assert check_definition("chombo cha kuandikia chenye wino", source_definition=None) == []
