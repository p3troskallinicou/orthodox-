#!/usr/bin/env python3
"""Static acceptance checks for the bundled liturgical datasets."""

from __future__ import annotations
import datetime as dt
import json
import unicodedata
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "Klimax" / "LiturgicalData"


def pascha(year: int) -> dt.date:
    a, b, c = year % 4, year % 7, year % 19
    d = (19 * c + 15) % 30
    e = (2 * a + 4 * b - d + 34) % 7
    julian = dt.date(year, (d + e + 114) // 31, (d + e + 114) % 31 + 1)
    return julian + dt.timedelta(days=year // 100 - year // 400 - 2)


sundays = json.loads((ROOT / "sunday-gospels.json").read_text())
apostle_overrides = json.loads((ROOT / "apostle-date-overrides.json").read_text())
by_offset = {item.get("relative_to_pascha_days"): item for item in sundays if "relative_to_pascha_days" in item}
by_week = {item.get("pentecost_week"): item for item in sundays if "pentecost_week" in item}


def resolve(date: dt.date) -> dict | None:
    if date.weekday() != 6:
        return None
    p = pascha(date.year)
    offset = (date - p).days
    if offset in by_offset:
        return by_offset[offset]
    anchor = p if date >= p else pascha(date.year - 1)
    distance = (date - anchor).days
    if distance >= 56 and distance % 7 == 0:
        return by_week.get(distance // 7 - 7)
    return None


expected = {
    "2026-02-01": ("publican_pharisee", "chrysostom", "18:10-14"),
    "2026-03-01": ("sunday_of_orthodoxy", "basil", "1:43-51"),
    "2026-03-08": ("gregory_palamas", "basil", "2:1-12"),
    "2026-03-15": ("veneration_of_cross", "basil", "8:34-9:1"),
    "2026-03-22": ("john_climacus", "basil", "9:17-31"),
    "2026-03-29": ("mary_of_egypt", "basil", "10:32-45"),
    "2026-04-05": ("palm_sunday", "chrysostom", "12:1-18"),
    "2026-04-12": ("pascha", "chrysostom", "1:1-17"),
    "2026-05-31": ("pentecost", "chrysostom", "7:37-52;8:12"),
    "2026-06-07": ("all_saints", "chrysostom", "10:32-33,37-38;19:27-30"),
    "2026-06-28": ("matthew_04", "chrysostom", "8:5-13"),
}

assert pascha(2026) == dt.date(2026, 4, 12)
for raw, wanted in expected.items():
    item = resolve(dt.date.fromisoformat(raw))
    actual = (item["id"], item["default_liturgy"], item["divine_liturgy_gospel"]["ref"])
    assert actual == wanted, (raw, actual, wanted)

assert all(item.get("needs_yearly_calendar_verification") is True
           for item in sundays if item["cycle"] == "pentecost_luke")

today = resolve(dt.date(2026, 7, 5))
assert today["id"] == "matthew_05"
assert today["divine_liturgy_gospel"]["ref"] == "8:28-9:1"
today_apostle = next(item for item in apostle_overrides if item["date_new_calendar"] == "07-05")["apostle"]
assert (today_apostle["book"], today_apostle["ref"]) == ("galatians", "5:22-26,6:1-2")

for name in ("chrysostom", "basil", "presanctified"):
    base = json.loads((ROOT / "BaseLiturgies" / f"{name}.el.json").read_text())
    assert base["source_status"] == "approved_openbook_source"
    assert base["source"]["source_page_url"].startswith((
        "https://www.openbook.gr/", "https://dcs.goarch.org/"
    ))
    assert base["sections"]
    assert all(section.get("blocks") for section in base["sections"])
    readings = [section for section in base["sections"] if section.get("role") == "readings"]
    assert readings
    if name != "presanctified":
        service_text = "\n".join(
            section.get("text_el", "") + "\n" + "\n".join(
                block.get("text_el", "") for block in section.get("blocks", [])
            )
            for section in base["sections"]
        )
        assert "{{APOSTLE}}" in service_text
        assert "{{GOSPEL}}" in service_text

swift_view = (ROOT.parents[0] / "LiturgicalServiceView.swift").read_text()
assert "block.speaker" in swift_view and "gospelLines" in swift_view
assert all(color not in swift_view for color in (".blue", ".green", ".purple", ".orange"))
assert "inlineSearchBar" in swift_view and "currentMatchIndex" in swift_view
assert "proxy.scrollTo(result.id" in swift_view and "searchMatchAnchor" in swift_view
assert "ServiceSearchSheet" not in swift_view
swift_service = (ROOT.parents[0] / "LiturgicalServices.swift").read_text()
assert "base.placeholders.apostle, with: apostleBlock" in swift_service


def search_key(value: str) -> str:
    decomposed = unicodedata.normalize("NFD", value)
    return "".join(char for char in decomposed if unicodedata.category(char) != "Mn").lower().replace("ς", "σ")


office_corpus = json.loads((ROOT / "sunday-offices-2026.json").read_text())
office_entries = office_corpus["entries"]
assert office_corpus["year"] == 2026
assert office_corpus["schema_version"] == 2
office_strings = office_corpus["strings"]
assert len(office_entries) == 365
assert len({entry["date"] for entry in office_entries}) == 365
assert [entry["date"] for entry in office_entries] == sorted(entry["date"] for entry in office_entries)

typikon_files = sorted(ROOT.glob("typikon-services-*.json"))
assert typikon_files
for typikon_file in typikon_files:
    yearly = json.loads(typikon_file.read_text())
    assert yearly["schema_version"] == 1
    assert typikon_file.stem == f"typikon-services-{yearly['year']}"
    yearly_dates = [item["date"] for item in yearly["entries"]]
    assert len(yearly_dates) == len(set(yearly_dates))
    assert yearly_dates == sorted(yearly_dates)

typikon = json.loads((ROOT / "typikon-services-2026.json").read_text())
typikon_entries = typikon["entries"]
typikon_by_date = {item["date"]: item for item in typikon_entries}
assert typikon["year"] == 2026 and typikon["schema_version"] == 1
assert len(typikon_by_date) == len(typikon_entries)
assert [item["date"] for item in typikon_entries] == sorted(typikon_by_date)
assert len(typikon_entries) < len(office_entries)  # never expose all 365 corpus rows as a public schedule
for month in range(1, 13):
    first = dt.date(2026, month, 1)
    last = dt.date(2027, 1, 1) if month == 12 else dt.date(2026, month + 1, 1)
    day = first
    while day < last:
        if day.weekday() == 6:
            item = typikon_by_date[day.isoformat()]
            assert item["vespers"] and item["orthros"] and item["divine_liturgy"]
        day += dt.timedelta(days=1)
assert all(typikon_by_date["2026-08-15"][key] for key in ("vespers", "orthros", "divine_liturgy"))
assert "2026-08-17" not in typikon_by_date
assert typikon_by_date["2026-04-10"]["vespers"]
assert typikon_by_date["2026-04-10"]["orthros"]
assert not typikon_by_date["2026-04-10"]["divine_liturgy"]

for entry in office_entries:
    assert len(entry["vespers"]["body"]) >= (35 if entry["vespers"]["code"] == "ordinary" else 150), entry["date"]
    assert len(entry["orthros"]["body"]) >= 100, entry["date"]
    for service_name in ("vespers", "orthros"):
        assert entry[service_name]["source_date"]
        for paragraph_id in entry[service_name]["body"]:
            assert 0 <= paragraph_id < len(office_strings)
            paragraph = office_strings[paragraph_id]
            if paragraph.startswith("@s:"):
                response = paragraph.partition("|")[2].strip()
                assert not (response.startswith("(") and response.endswith(")")), (entry["date"], paragraph)
            assert not any(word in paragraph.upper() for word in ("PRIEST", "CHOIR", "READER", "THE SERVICE OF"))

    vespers_key = search_key("\n".join(office_strings[index] for index in entry["vespers"]["body"]))
    orthros_key = search_key("\n".join(office_strings[index] for index in entry["orthros"]["body"]))
    if entry["vespers"]["code"] != "ordinary":
        assert "φωσ ιλαρον" in vespers_key, entry["date"]
    assert len(orthros_key) > 1_000, entry["date"]

print(
    f"Liturgical validation passed: {len(sundays)} Sunday definitions, "
    f"{len(expected)} dated cases, {len(typikon_entries)} Typikon celebrations "
    f"filtering {len(office_entries)} underlying office-text packages"
)
