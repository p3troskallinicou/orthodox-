#!/usr/bin/env python3
"""Compile manually verified annual Greek Sunday readings, or refuse to publish.

Usage:
 python publish_reviewed_year.py --year 2027 --csv 2027_...csv --output kanonion-2027.json

Requires exact references from annual Diptycha or own dated official Sunday sheet.
DO NOT fill an unverified annual calendar with guessed weekly liturgical cycles.
"""
from __future__ import annotations
import argparse
import csv
import datetime as dt
import json
import pathlib
import sys
from liturgical_release_gate import year_sundays, audit, PRIMARY_STATUS, DIPTYCHA_STATUS, PRIMARY_PREFIX, official_pdf

OFFICIAL = 'Αποστολική Διακονία της Εκκλησίας της Ελλάδος'

def parse_int(txt, label, date):
    if not txt: return None
    try: return int(txt)
    except ValueError: raise ValueError(f'{date}: {label} πρέπει να είναι ακέραιος αριθμός')

def compile_year(year, csv_file, output):
    with pathlib.Path(csv_file).open(encoding='utf-8-sig',newline='') as f:
        records=list(csv.DictReader(f))
    expected=[x.isoformat() for x in year_sundays(year)]
    if [r.get('date') for r in records]!=expected:
        raise ValueError('Το αρχείο πρέπει να έχει ακριβώς όλες τις Κυριακές του έτους, σε ημερολογιακή σειρά, χωρίς επαναλήψεις.')
    result=[]
    for r in records:
        d=r['date'];st=r.get('readings_verification_status')
        if st not in (PRIMARY_STATUS,DIPTYCHA_STATUS):
            raise ValueError(f'{d}: ΑΠΑΓΟΡΕΥΕΤΑΙ δημοσίευση χωρίς ετήσια ελληνική πηγή (status={st})')
        for field in ('gospel_book','gospel_ref','apostle_book','apostle_ref','first_reviewer','review_date'):
            if not (r.get(field) or '').strip(): raise ValueError(f'{d}: λείπει {field}')
        if st == PRIMARY_STATUS:
            if not official_pdf(r.get('source_url')):
                raise ValueError(f'{d}: απαιτείται σύνδεσμος στο ΕΠΙΣΗΜΟ φύλλο «Φωνή Κυρίου»')
            if not r.get('source_issue'): raise ValueError(f'{d}: λείπει ο αριθμός φύλλου')
        if st == DIPTYCHA_STATUS:
            if 'Δίπτυχα' not in (r.get('source_edition') or '') or str(year) not in r['source_edition']:
                raise ValueError(f'{d}: απαιτούνται τα Δίπτυχα {year}, όχι η Επετηρίδα ή περσινά Δίπτυχα')
            if not r.get('source_page'):raise ValueError(f'{d}: λείπει η ακριβής σελίδα Διπτύχων')
            if not r.get('second_reviewer') or r['second_reviewer']==r['first_reviewer']:
                raise ValueError(f'{d}: απαιτούνται δύο διαφορετικοί ελεγκτές για έντυπη πηγή')
        try: dt.date.fromisoformat(r['review_date'])
        except ValueError: raise ValueError(f'{d}: κακή ημερομηνία ελέγχου')
        gospel={'book':r['gospel_book'].strip(),'ref':r['gospel_ref'].strip(),'display_el':r.get('gospel_display_el','').strip()}
        apostle={'book':r['apostle_book'].strip(),'ref':r['apostle_ref'].strip(),'display_el':r.get('apostle_display_el','').strip()}
        # display_el must never be inferred incorrectly from English chapter numbering;
        # exact Greek display is mandatory.
        if not gospel['display_el'] or not apostle['display_el']:
            raise ValueError(f'{d}: απαιτούνται gospel_display_el και apostle_display_el από ελληνική πηγή')
        result.append({
            'date':d,'echos':parse_int(r.get('echos'),'echos',d),
            'eothinon':parse_int(r.get('eothinon'),'eothinon',d),
            'apostle':apostle,'gospel':gospel,
            'liturgical_occasion':r.get('liturgical_occasion') or None,
            'priority_of_feast':r.get('priority_of_feast') or None,
            'office_cycle_status':r.get('office_cycle_status') or 'not_reviewed',
            'readings_verification_status':st,
            'readings_source_organisation':OFFICIAL,
            'readings_source_url':r.get('source_url') or None,
            'readings_source_issue':parse_int(r.get('source_issue'),'source_issue',d),
            'readings_source_edition':r.get('source_edition') or None,
            'readings_source_page':r.get('source_page') or None,
            'readings_first_reviewer':r.get('first_reviewer'),
            'readings_second_reviewer':r.get('second_reviewer') or None,
            'readings_review_date':r.get('review_date'),
        })
    output=pathlib.Path(output)
    # audit in an isolated staging directory; never publish a partially verified pack
    import tempfile
    with tempfile.TemporaryDirectory() as t:
        tmp=pathlib.Path(t)/'LiturgicalData'
        tmp.mkdir()
        (tmp/f'kanonion-{year}.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
        report=audit(year,pathlib.Path(t))
        if not report['release_allowed']:
            raise ValueError('Ο τελικός έλεγχος απαγορεύει τη δημοσίευση: '+'; '.join(report['problems']))
    output.parent.mkdir(exist_ok=True,parents=True)
    with tempfile.NamedTemporaryFile(mode='w', encoding='utf-8', dir=output.parent, delete=False) as staged:
        staged.write(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
        staged_path = pathlib.Path(staged.name)
    try:
        staged_path.replace(output)
    finally:
        staged_path.unlink(missing_ok=True)
    return len(result)

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--year',type=int,required=True)
    p.add_argument('--csv',type=pathlib.Path,required=True)
    p.add_argument('--output',type=pathlib.Path,required=True)
    args=p.parse_args()
    try:
        count=compile_year(args.year,args.csv,args.output)
        print(f'Πέρασε ο έλεγχος μεταδεδομένων (δεν αποτελεί εκκλησιαστική πιστοποίηση): {count} Κυριακές — {args.output}')
        return 0
    except (ValueError,FileNotFoundError,KeyError) as e:
        print(f'ΑΠΟΡΡΙΦΘΗΚΕ: {e}',file=sys.stderr)
        return 2
if __name__=='__main__': sys.exit(main())
