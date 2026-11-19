#!/usr/bin/env python3
"""Portable CSV regeneration for ecclesiastical editorial QA. All new records stay pending."""
import argparse,csv,json,re
from pathlib import Path

def write(path,columns,rows):
 path.parent.mkdir(exist_ok=True,parents=True)
 with path.open('w',encoding='utf-8-sig',newline='') as f:
  w=csv.DictWriter(f,fieldnames=columns,extrasaction='ignore');w.writeheader();w.writerows(rows)
 print('CREATED',str(path),'records',len(rows))

def main():
 p=argparse.ArgumentParser(description=__doc__)
 p.add_argument('--root',type=Path,required=True,help='Your repository Klimax/ directory')
 p.add_argument('--year',type=int,default=2026)
 p.add_argument('--out',type=Path,required=True,help='Output directory (do not overwrite signed reviews)')
 a=p.parse_args();root=a.root;out=a.out
 x=json.loads((root/'prayers.json').read_text('utf8'))
 prayers=[dict(category=cat['titleGreek'],id=z['id'],title=z['titleGreek'],source_claim=z.get('source',''),source_url=z.get('sourceUrl',''),body_segments=len(z.get('body',[])),ecclesiastical_status='PENDING_WORD_BY_WORD_COLLATION',target_edition='',source_page='',reviewer_1='',reviewer_2='',review_date='',issue_notes='') for cat in x['categories'] for z in cat['prayers']]
 write(out/'prayers_and_psalter.csv',list(prayers[0]),prayers)
 o=json.loads((root/f'LiturgicalData/sunday-offices-{a.year}.json').read_text('utf8'));offices=[]
 for e in o['entries']:
  for kind,el in (('vespers','Εσπερινός'),('orthros','Όρθρος')):
   offices.append(dict(date=e['date'],service=el,body_snippets=len(e[kind]['body']),content_verified='NO',liturgical_day_at_vespers='NEEDS_VERIFICATION',feast_priority='NEEDS_VERIFICATION',source_edition='',source_pages='',reviewer_1='',reviewer_2='',reviewed_on='',issues=''))
 write(out/f'vespers_orthros_{a.year}.csv',list(offices[0]),offices)
 blocks=[]
 for filename,greek in [('chrysostom.el.json','Θεία Λειτουργία Ιωάννου Χρυσοστόμου'),('basil.el.json','Θεία Λειτουργία Μεγάλου Βασιλείου'),('presanctified.el.json','Λειτουργία Προηγιασμένων Δώρων')]:
  doc=json.loads((root/'LiturgicalData/BaseLiturgies'/filename).read_text('utf8'))
  for section in doc['sections']:
   for b in section['blocks']:
    blocks.append(dict(liturgy=greek,file=filename,section=section['id'],block_id=b['id'],kind=b['kind'],starts_with=b['text_el'][:90].replace('\n',' '),ecclesiastical_status='PENDING_PRIEST_RUBRIC_COLLATION',reference_edition='',source_page='',first_reviewer='',second_reviewer='',note=''))
 write(out/'three_liturgies_blocks.csv',list(blocks[0]),blocks)
if __name__=='__main__':main()
