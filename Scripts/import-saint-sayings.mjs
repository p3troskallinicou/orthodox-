// Deterministic content import. Supplied text is preserved verbatim; research
// notes and interpretive paraphrases are not presented as words of the saint.
import {readFileSync, writeFileSync, existsSync} from 'node:fs';
const sourcePath = process.argv[2] ?? '/Users/petroskallinicou/Downloads/agiologio_riton_master.json';
const source = JSON.parse(readFileSync(sourcePath, 'utf8'));
const categories = [
  {id: 'love', title: 'Αγάπη και καλοσύνη', shortTitle: 'Αγάπη', symbol: 'heart'},
  {id: 'humility', title: 'Ταπείνωση και εγωισμός', shortTitle: 'Ταπείνωση', symbol: 'leaf'},
  {id: 'forgiveness', title: 'Συγχώρεση και κατάκριση', shortTitle: 'Συγχώρεση', symbol: 'hands.sparkles'},
  {id: 'thoughts', title: 'Λογισμοί και εσωτερική ειρήνη', shortTitle: 'Λογισμοί', symbol: 'sun.horizon'}
];
const selected = new Map((source.curated_flashcards ?? []).map(r => [r.id, r]));
const records = source.records.filter(r => categories.some(c => c.title === r.category) && (r.kind.startsWith('Αυτούσιο') || selected.has(r.id)));
const photos = [
  {id: 'paisios-01', asset: 'SaintSayingPaisios01', subjectTop: 0.05, width: 511, height: 444},
  {id: 'paisios-02', asset: 'SaintSayingPaisios02', subjectTop: 0.28, width: 356, height: 544},
  {id: 'paisios-03', asset: 'SaintSayingPaisios03', subjectTop: 0.02, width: 609, height: 503},
  {id: 'paisios-04', asset: 'SaintSayingPaisios04', subjectTop: 0.0, width: 181, height: 278},
  {id: 'paisios-05', asset: 'SaintSayingPaisios05', subjectTop: 0.04, width: 510, height: 601},
  {id: 'paisios-06', asset: 'SaintSayingPaisios06', subjectTop: 0.18, width: 403, height: 496},
  {id: 'paisios-07', asset: 'SaintSayingPaisios07', subjectTop: 0.38, width: 595, height: 711},
  {id: 'paisios-08', asset: 'SaintSayingPaisios08', subjectTop: 0.04, width: 1029, height: 1440}
];
const sayings = records.map((record, index) => {
  const r = selected.get(record.id) ?? record;
  return {
    id: r.id, saintID: 'paisios', categoryID: categories.find(c => c.title === r.category).id,
    text: r.text, source: r.source, sourceNote: r.note ?? '',
    sourceStatus: selected.has(r.id) ? 'Σημειωμένο ως ελεγμένο στη συλλογή' : 'Εκκρεμεί έλεγχος πρωτοτύπου',
    sourceChecked: selected.has(r.id), featured: selected.has(r.id),
    // Reuse photographs with genuine negative space instead of putting words
    // over the saint or filling the rest of the card with a solid panel.
    photoID: r.text.length <= 60 && index % 3 === 0 ? 'paisios-06'
      : r.text.length <= 105 && index % 2 === 0 ? 'paisios-02' : 'paisios-07'
  };
});
const output = {
  version: 1, sourceVersion: source.version,
  saints: [{id: 'paisios', name: source.saint, shortName: 'Άγιος Παΐσιος', subtitle: 'Ο Αγιορείτης', photoID: 'paisios-07'}],
  categories, photos, sayings
};
// This importer owns Paisios only. Preserve saints added from other sources.
const existingPath = 'Klimax/saint-sayings.json';
if (existsSync(existingPath)) {
  const existing = JSON.parse(readFileSync(existingPath, 'utf8'));
  const others = existing.sayings.filter(s => s.saintID !== 'paisios');
  const otherSaints = existing.saints.filter(s => s.id !== 'paisios');
  const categoryIDs = new Set(others.map(s => s.categoryID));
  const photoIDs = new Set([...others.map(s => s.photoID), ...otherSaints.map(s => s.photoID)]);
  output.saints.push(...otherSaints);
  output.sayings.push(...others);
  output.categories.push(...existing.categories.filter(c => categoryIDs.has(c.id) && !output.categories.some(o => o.id === c.id)));
  output.photos.push(...existing.photos.filter(p => photoIDs.has(p.id) && !output.photos.some(o => o.id === p.id)));
}
writeFileSync('Klimax/saint-sayings.json', JSON.stringify(output, null, 2) + '\n');
console.log(`Imported ${sayings.length} verbatim excerpts in ${categories.length} categories; original file unchanged.`);
