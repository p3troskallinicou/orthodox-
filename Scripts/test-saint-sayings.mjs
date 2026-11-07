import assert from 'node:assert/strict';
import {readFileSync, existsSync, statSync} from 'node:fs';
import {spawnSync} from 'node:child_process';

const catalog = JSON.parse(readFileSync('Klimax/saint-sayings.json'));
assert.equal(catalog.sayings.length, 41);
assert.equal(catalog.categories.length, 4);
assert.equal(catalog.photos.length, 8);
assert.equal(new Set(catalog.sayings.map(s => s.id)).size, catalog.sayings.length);
assert.equal(catalog.sayings.filter(s => s.featured).length, 5);
assert(catalog.categories.every(c => catalog.sayings.some(s => s.categoryID === c.id)));
assert(catalog.sayings.every(s => s.source && (s.sourceChecked || s.sourceStatus.includes('Εκκρεμεί'))));
// Supplied-source comparison is optional on another developer's machine.
const originalPath = process.argv[2] ?? '/Users/petroskallinicou/Downloads/agiologio_riton_master.json';
if (existsSync(originalPath)) {
  const original = JSON.parse(readFileSync(originalPath));
  const curated = new Map(original.curated_flashcards.map(s => [s.id, s]));
  for (const saying of catalog.sayings) {
    const record = curated.get(saying.id) ?? original.records.find(s => s.id === saying.id);
    assert.equal(saying.text, record.text, 'Never rewrite an attributed quotation');
    assert.equal(saying.source, record.source);
    assert(record.kind.startsWith('Αυτούσιο') || curated.has(saying.id));
  }
}
let imageBytes = 0;
for (const photo of catalog.photos) {
  const path = `Klimax/Assets.xcassets/${photo.asset}.imageset/`;
  const manifest = JSON.parse(readFileSync(path + 'Contents.json'));
  imageBytes += statSync(path + manifest.images[0].filename).size;
  for (const [width, height] of [[150, 168], [175, 262], [362, 319], [386, 685], [600, 800]]) {
    const scale = Math.max(width / photo.width, height / photo.height);
    assert(photo.width * scale >= width - 0.001 && photo.height * scale >= height - 0.001, 'Full-bleed artwork must cover the entire card');
  }
}
assert(imageBytes < 2_000_000);
const source = readFileSync('Klimax/SaintSayings.swift', 'utf8');
const tests = `
let data = try Data(contentsOf: URL(fileURLWithPath: "Klimax/saint-sayings.json"))
let catalog = try JSONDecoder().decode(SaintSayingsCatalog.self, from: data)
assert(catalog.isValid)
assert(catalog.filtered(saintID: "paisios", categoryID: nil, query: "").count == 41)
for category in catalog.categories {
    let results = catalog.filtered(saintID: "paisios", categoryID: category.id, query: "")
    assert(!results.isEmpty && results.allSatisfy { $0.categoryID == category.id })
}
assert(!catalog.filtered(saintID: "paisios", categoryID: nil, query: "ΑΓΑΠΗ").isEmpty)
assert(!catalog.filtered(saintID: "paisios", categoryID: nil, query: "μέλισσα καλό").isEmpty)
assert(catalog.filtered(saintID: "paisios", categoryID: nil, query: "ανύπαρκτηφράση").isEmpty)
assert(catalog.filtered(saintID: "another-saint", categoryID: nil, query: "").isEmpty)
let ordered = catalog.filtered(saintID: "paisios", categoryID: nil, query: "")
assert(ordered.prefix(5).allSatisfy { $0.featured })
for saying in ordered {
    let photo = catalog.photo(for: saying)
    for size in [CGSize(width: 175, height: 262), CGSize(width: 386, height: 685)] {
        let subjectY = photo.height * max(size.width / photo.width, size.height / photo.height) * photo.subjectTop
        assert(photo.textBoundary(in: size) <= subjectY)
    }
}
print("PASS: actual Swift catalog decoding, category/saint isolation, accent-insensitive search and editorial ordering")
`;
const result = spawnSync('swift', ['-module-cache-path', '/tmp/klimax-prayer-test-cache', '-'], {input: source + tests, encoding: 'utf8'});
process.stdout.write(result.stdout ?? '');
process.stderr.write(result.stderr ?? '');
assert.equal(result.status, 0);
const ui = readFileSync('Klimax/SaintSayingsView.swift', 'utf8');
assert(ui.includes('PrayerInvitationCardLayout(viewport:'));
assert(ui.includes('.presentationBackground(.clear)'));
assert(ui.includes('ForEach(sayings) { saying in'), 'Native left swipe must move forward in collection order');
assert(!ui.includes('sayings.reversed()'), 'Do not invert the page animation relative to the swipe');
assert(ui.includes('dragDown > 90'));
assert(ui.includes('.foregroundStyle(.primary)'));
assert(ui.includes('sourceDetails(saying)'));
const artwork = ui.split('private struct SayingArtwork: View')[1].split('private struct SaintSayingReader: View')[0];
assert(artwork.includes('.scaledToFill()'));
assert(!artwork.includes('.scaledToFit()') && !artwork.includes('.mask'), 'No partial-image panel or image fade into a solid fill');
assert(artwork.includes('height: geometry.size.height, alignment: .top'));
assert(readFileSync('Klimax/RootView.swift', 'utf8').includes('case .sayings:'));
const project = readFileSync('Klimax.xcodeproj/project.pbxproj', 'utf8');
assert(project.includes('SaintSayingsView.swift in Sources'));
assert(project.includes('saint-sayings.json in Resources'));
console.log(`PASS: 41 verbatim texts, four populated categories, 8 real photo assets (${Math.round(imageBytes / 1024)} KB), protected subject areas, popup geometry and navigation wiring`);
