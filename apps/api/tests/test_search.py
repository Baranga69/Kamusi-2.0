import uuid

from app.models import SearchEntry
from app.normalize import normalize_sw


def test_search_ranking(client, db_session):
    entries = [
        SearchEntry(
            target_type="lexeme",
            target_id=uuid.UUID("00000000-0000-0000-0000-000000000001"),
            lang_code="sw",
            text="mti",
            normalized=normalize_sw("mti"),
            popularity=10,
        ),
        SearchEntry(
            target_type="lexeme",
            target_id=uuid.UUID("00000000-0000-0000-0000-000000000002"),
            lang_code="sw",
            text="mtish",
            normalized=normalize_sw("mtish"),
            popularity=20,
        ),
        SearchEntry(
            target_type="lexeme",
            target_id=uuid.UUID("00000000-0000-0000-0000-000000000003"),
            lang_code="sw",
            text="samti",
            normalized=normalize_sw("samti"),
            popularity=30,
        ),
    ]
    db_session.add_all(entries)
    db_session.commit()

    response = client.get("/search", params={"q": "mti", "lang": "sw", "limit": 10})
    assert response.status_code == 200
    results = response.json()
    assert [result["text"] for result in results] == ["mti", "mtish", "samti"]
