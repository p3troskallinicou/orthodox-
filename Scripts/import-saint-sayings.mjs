// Import only the approved Paisios edition; preserve every other saint and topic.
import {readFileSync, writeFileSync} from 'node:fs';
import assert from 'node:assert/strict';
const path = 'Klimax/saint-sayings.json';
const catalog = JSON.parse(readFileSync(path));
const source = JSON.parse(readFileSync('data/paisios-haidari-sayings.json'));
assert.equal(source.sayings.length, 116);
assert(source.sayings.every(s => s.saintID === 'paisios' && s.id.startsWith('paisios-haidari-')));
assert(source.sayings.every(s => catalog.categories.some(c => c.id === s.categoryID)));
catalog.sayings = [...catalog.sayings.filter(s => s.saintID !== 'paisios'), ...source.sayings];
const photos = new Map(source.photos.map(p => [p.id, p]));
catalog.photos = catalog.photos.map(p => photos.get(p.id) ?? p);
writeFileSync(path, JSON.stringify(catalog, null, 2) + '\n');
console.log('Imported 116 approved Paisios entries; other saints, categories and saved-ID storage are unchanged.');
