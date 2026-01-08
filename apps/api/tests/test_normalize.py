from app.normalize import normalize_sw


def test_normalize_sw_basic():
    assert normalize_sw("  Habari  ") == "habari"


def test_normalize_sw_dashes_and_apostrophes():
    assert normalize_sw("ma–tatu") == "matatu"
    assert normalize_sw("ng’ombe") == "ngombe"


def test_normalize_sw_punctuation_spacing():
    assert normalize_sw("Mti, wa! uzazi?") == "mti wa uzazi"
