#!/usr/bin/env python3
"""Fail-closed yearly Sunday release gate for Greece (not a liturgical oracle).

No Gospel/Apostle gets inferred from Pascha, previous year, or US calendar.
For release, exact official editions and human checked evidence are required.
"""
from __future__ import annotations

import argparse
import csv
import datetime as dt
import json
import pathlib
import sys
from urllib.parse import urlparse

OFFICIAL = "Αποστολική Διακονία της Εκκλησίας της Ελλάδος"

def official_pdf(value):
    url = urlparse(value or "")
    return url.scheme == "https" and url.hostname == "apostoliki-diakonia.gr" and url.path.lower().endswith(".pdf")

PRIMARY_PREFIX = "https://apostoliki-diakonia.gr/"
PRIMARY_STATUS = "checked_primary_sunday_sheet"
DIPTYCHA_STATUS = "checked_primary_diptycha"
PENDING_STATUS = "not_yet_checked_against_greek_source"
ALLOWED = {PRIMARY_STATUS, DIPTYCHA_STATUS, "announced_in_previous_sunday_sheet", PENDING_STATUS}
CORRECTIONS_2026 = {
    "2026-08-23": {"gospel": ("Luke", "10:38-42,11:27-28"), "apostle": ("philippians", "2:5-11")},
    "2026-09-06": {"gospel": ("Matthew", "22:2-14"), "apostle": ("2corinthians", "1:21-2:4")},
    "2026-10-04": {"gospel": ("Luke", "6:31-36"), "apostle": ("2corinthians", "9:6-11")},
}


def year_sundays(year: int):
    day = dt.date(year, 1, 1)
    while day.year == year:
        if day.weekday() == 6:
            yield day
        day += dt.timedelta(days=1)


def audit(year: int, root: pathlib.Path):
    fname = root / "LiturgicalData" / f"kanonion-{year}.json"
    days = [x.isoformat() for x in year_sundays(year)]
    problems = []
    if not fname.exists():
        return {"year": year, "release_allowed": False,
                "expected_sundays": len(days), "source_checked": 0,
                "pending": len(days), "problems": [f"Δεν υπάρχει ετήσιο αρχείο {fname.name}· το {year} ΔΕΝ πρέπει να εμφανιστεί ως επαληθευμένο."]}
    rows = json.loads(fname.read_text(encoding="utf-8"))
    if not isinstance(rows, list):
        return {"year":year,"release_allowed":False,"problems":["Το ετήσιο JSON δεν είναι πίνακας."],"source_checked":0,"pending":len(days),"expected_sundays":len(days)}
    keys = [x.get("date") for x in rows]
    if len(keys) != len(set(keys)):
        problems.append("Υπάρχουν διπλές ημερομηνίες.")
    expected = set(days)
    got = set(keys)
    missing = sorted(expected - got)
    extra = sorted(got - expected)
    if missing: problems.append(f"Λείπουν {len(missing)} Κυριακές: {', '.join(missing)}")
    if extra: problems.append(f"Υπάρχουν {len(extra)} άσχετες ημερομηνίες: {', '.join(str(x) for x in extra)}")
    verified = 0
    preview = 0
    pending = 0
    for row in rows:
        date = row.get('date', '<χωρίς ημερομηνία>')
        status = row.get('readings_verification_status', '')
        if status not in ALLOWED:
            problems.append(f"{date}: άγνωστη/μη καταχωρισμένη κατάσταση πιστοποίησης: {status}")
        for kind in ("gospel", "apostle"):
            value = row.get(kind)
            if not isinstance(value,dict) or not value.get("ref") or not value.get("book") or not value.get("display_el"):
                problems.append(f"{date}: λείπει ή είναι άκυρη η παραπομπή {kind}.")
        if status in (PRIMARY_STATUS, DIPTYCHA_STATUS):
            if row.get('readings_source_organisation') != OFFICIAL:
                problems.append(f"{date}: λείπει η ελληνική εκκλησιαστική πηγή.")
            try:
                dt.date.fromisoformat(row.get('readings_review_date') or '')
            except ValueError:
                problems.append(f"{date}: άκυρη ημερομηνία ελέγχου.")
            for field, maximum in [('echos', 8), ('eothinon', 11)]:
                value = row.get(field)
                if value is not None and (type(value) is not int or not 1 <= value <= maximum):
                    problems.append(f"{date}: άκυρο {field}.")
        if status == PRIMARY_STATUS:
            verified += 1
            url = row.get("readings_source_url") or ""
            if not official_pdf(url):
                problems.append(f"{date}: το ελεγμένο φύλλο δεν έχει επίσημη διεύθυνση PDF.")
            if not row.get('readings_review_date') or not row.get('readings_source_issue'):
                problems.append(f"{date}: δεν υπάρχει αριθμός φύλλου/ημερομηνία ελέγχου.")
        elif status == DIPTYCHA_STATUS:
            verified += 1
            edition = row.get('readings_source_edition') or ''
            page = row.get('readings_source_page') or ''
            reviewer1 = row.get('readings_first_reviewer') or ''
            reviewer2 = row.get('readings_second_reviewer') or ''
            if 'Δίπτυχα' not in edition or str(year) not in edition or not page:
                problems.append(f"{date}: η ετήσια έντυπη πηγή απαιτεί ονομαστική έκδοση Διπτύχων {year} και αριθμό σελίδας.")
            if not reviewer1 or not reviewer2 or reviewer1 == reviewer2 or not row.get('readings_review_date'):
                problems.append(f"{date}: ετήσια πηγή χωρίς δύο ανεξάρτητους ελεγκτές και ημερομηνία ελέγχου.")
            if row.get('readings_source_organisation') != 'Αποστολική Διακονία της Εκκλησίας της Ελλάδος':
                problems.append(f"{date}: δεν δηλώνεται η αρμόδια ελληνική εκκλησιαστική πηγή.")
        elif status == "announced_in_previous_sunday_sheet":
            preview += 1
        else:
            pending += 1
        if year == 2026 and date in CORRECTIONS_2026:
            for kind, expected_val in CORRECTIONS_2026[date].items():
                val = row.get(kind) or {}
                if (val.get('book'), val.get('ref')) != expected_val:
                    problems.append(f"{date}: η διορθωμένη {kind} περικοπή άλλαξε ή επανήλθε σε εσφαλμένη τιμή.")
    if verified != len(days):
        problems.append(f"Ανεπαρκής επιβεβαίωση: {verified}/{len(days)} Κυριακές με προσωπικά ελεγμένη ελληνική εκκλησιαστική πηγή· {preview} σε προαναγγελία και {pending} ανεξέλεγκτες.")
    return {"year": year, "release_allowed": not problems,
            "expected_sundays": len(days), "source_checked": verified,
            "announced_previous_week_only": preview, "pending": pending,
            "problems": problems}


def template(year: int, output: pathlib.Path):
    output.parent.mkdir(parents=True,exist_ok=True)
    with output.open('w',encoding='utf-8-sig',newline='') as f:
        w = csv.DictWriter(f, fieldnames=["date","gospel_book","gospel_ref","gospel_display_el","apostle_book","apostle_ref","apostle_display_el",
            "echos","eothinon","liturgical_occasion","priority_of_feast",
            "source_edition","source_page","source_issue","source_url","first_reviewer","second_reviewer","review_date",
            "readings_verification_status","office_cycle_status","notes"])
        w.writeheader()
        for sunday in year_sundays(year):
            w.writerow({"date":sunday.isoformat(),
                "readings_verification_status":"awaiting_annual_greek_official_sources",
                "office_cycle_status":"not_reviewed", "notes":"Μην μεταφέρετε περικοπές προηγούμενου έτους"})
    return len(list(year_sundays(year)))


def main():
    p=argparse.ArgumentParser(description=__doc__)
    sub=p.add_subparsers(dest="cmd",required=True)
    a=sub.add_parser("audit");a.add_argument("--year",type=int,required=True);a.add_argument("--root",type=pathlib.Path,required=True)
    t=sub.add_parser("template");t.add_argument("--year",type=int,required=True);t.add_argument("--output",type=pathlib.Path,required=True)
    opts=p.parse_args()
    if opts.cmd=="audit":
        d=audit(opts.year,opts.root)
        print(json.dumps(d,ensure_ascii=False,indent=2))
        # A missing source is an intentional failure, not a software test crash.
        return 0 if d['release_allowed'] else 2
    if opts.cmd=="template":
        print(f"Δημιουργήθηκαν {template(opts.year,opts.output)} Κυριακές χωρίς εικαζόμενες περικοπές: {opts.output}")
        return 0

if __name__=="__main__":sys.exit(main())
