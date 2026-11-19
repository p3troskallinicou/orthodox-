from pathlib import Path
import datetime as dt, json, collections, re, sys
base=Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else Path(__file__).resolve().parents[2]/'Klimax'
def data(x):return json.loads((base/x).read_text('utf-8'))
checks={}
c=data('LiturgicalData/kanonion-2026.json')
dates=[r['date'] for r in c]
assert len(dates)==52 and len(set(dates))==52 and all(dt.date.fromisoformat(d).weekday()==6 for d in dates)
assert not next(r for r in c if r['date']=='2026-04-12')['echos']
checks['sundays_2026']='52 distinct Sundays; Pascha has no generic Octoechos echos'
o=data('LiturgicalData/sunday-offices-2026.json')
all_dates=[r['date'] for r in o['entries']]
assert len(all_dates)==365 and len(set(all_dates))==365
assert sorted(all_dates)==[(dt.date(2026,1,1)+dt.timedelta(days=i)).isoformat() for i in range(365)]
assert next(r for r in o['entries'] if r['date']=='2026-04-12')['echos'] is None
N=len(o['strings']); cnt=0
for entry in o['entries']:
 for office in ('vespers','orthros'):
  assert office in entry and entry[office]['body']
  body=entry[office]['body']
  assert all(isinstance(i,int) and 0<=i<N for i in body)
  cnt+=len(body)
checks['daily_offices_2026']=f'365 dates; 730 service bodies; {cnt} valid referenced snippets in {N} strings'
t=data('LiturgicalData/typikon-services-2026.json')
assert t['jurisdiction']=='Ἐκκλησία τῆς Κύπρου' and 'requires_greek_church_comparison' in t['status']
assert len(t['entries'])==94 and len(set(x['date'] for x in t['entries']))==94
assert set(x['date'] for x in t['entries'])<=set(all_dates)
checks['typikon_2026']='94 event dates; unchanged Cyprus jurisdiction; review flag active'
p=data('prayers.json');items=[z for cat in p['categories'] for z in cat['prayers']]
assert len(items)==64 and len({z['id'] for z in items})==64
assert all(z['body'] for z in items)
ps=[x for x in items if x['id'].startswith('orthodox-prayer-book-psaltirion-')]
assert len(ps)==20
headings=[]
for x in ps:
 headings.extend(int(z.group(1)) for line in x['body'] if (z:=re.search(r'^@h:Ψαλμός.*?(\d+)' ,line)))
assert collections.Counter(headings)==collections.Counter(range(1,152))
assert any('ἔξωθεν τοῦ ἀριθμοῦ' in str(z) for x in ps for z in x['body'])
checks['prayer_book_psalter']='64 unique prayers; 20 kathismata; 150 numbered psalms exactly once + labeled supplementary Psalm 151'
for fname in ['chrysostom.el.json','basil.el.json','presanctified.el.json']:
 d=data('LiturgicalData/BaseLiturgies/'+fname)
 assert d['source_status']=='transcription_requires_liturgical_review'
 ids=[b['id'] for s in d['sections'] for b in s['blocks']]
 assert len(ids)==len(set(ids))
 for s in d['sections']:
  for b in s['blocks']:
   assert b['kind'] in ('rubric','spoken','variable','heading','placeholder') , (fname,b['kind'])
   assert isinstance(b['text_el'],str) and b['text_el'].strip(), (fname,b['id'])
 checks[fname]=f'{len(ids)} uniquely identified nonblank blocks; approval removed'
assert next(e for e in data('LiturgicalData/apostle-date-overrides.json') if e['id']=='kirykoskai_07_15')['apostle']['ref']=='13:11-13,14:1-5'
checks['15_july_epistle']='corrected 1 Corinthians 13:11-13 and 14:1-5'
for name,result in checks.items():print('PASS',name,':',result)
print(f'ALL DATA CHECKS PASS: {len(checks)} groups')
