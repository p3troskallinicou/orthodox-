import assert from 'node:assert/strict';
import {readFileSync, existsSync, statSync} from 'node:fs';
import {spawnSync} from 'node:child_process';

const catalog = JSON.parse(readFileSync('Klimax/saint-sayings.json'));
assert.equal(catalog.sayings.length, 74);
assert.equal(catalog.categories.length, 12);
assert.equal(catalog.photos.length, 15);
assert.equal(new Set(catalog.sayings.map(s => s.id)).size, catalog.sayings.length);
assert.equal(catalog.sayings.filter(s => s.featured).length, 5);
assert(catalog.categories.every(c => catalog.sayings.some(s => s.categoryID === c.id)));
assert(catalog.sayings.every(s => s.source && (s.sourceChecked || s.sourceStatus.includes('Εκκρεμεί'))));
// Supplied-source comparison is optional on another developer's machine.
const originalPath = process.argv[2] ?? '/Users/petroskallinicou/Downloads/agiologio_riton_master.json';
if (existsSync(originalPath)) {
  const original = JSON.parse(readFileSync(originalPath));
  const curated = new Map(original.curated_flashcards.map(s => [s.id, s]));
  for (const saying of catalog.sayings.filter(s => s.saintID === 'paisios')) {
    const record = curated.get(saying.id) ?? original.records.find(s => s.id === saying.id);
    assert.equal(saying.text, record.text, 'Never rewrite an attributed quotation');
    assert.equal(saying.source, record.source);
    assert(record.kind.startsWith('Αυτούσιο') || curated.has(saying.id));
  }
}
// Keep every supplied Porphyrios quote and category intact.
const supplied = JSON.parse(readFileSync('data/porfyrios-sayings.json'));
const porfyrios = catalog.sayings.filter(s => s.saintID === 'porfyrios');
assert.equal(porfyrios.length, 33);
assert.equal(catalog.sayings.filter(s => s.saintID === 'paisios').length, 41);
assert.deepEqual(porfyrios.map(({id, categoryID, text}) => ({id, categoryID, text})), supplied.sayings);
assert.deepEqual(catalog.categories.filter(c => c.id.startsWith('porfyrios-')), supplied.categories);
assert.deepEqual(supplied.categories.map(c => porfyrios.filter(s => s.categoryID === c.id).length), [5,4,6,4,3,5,4,2]);
assert(porfyrios.every(s => !s.sourceChecked && !s.featured && s.sourceStatus === supplied.sourceStatus));
assert(porfyrios.every(s => s.photoID.startsWith('porfyrios-')));
for (const saint of catalog.saints) assert(catalog.photos.some(p => p.id === saint.photoID));
for (const saying of catalog.sayings) {
  assert(catalog.saints.some(s => s.id === saying.saintID));
  assert(catalog.categories.some(c => c.id === saying.categoryID));
  assert(catalog.photos.some(p => p.id === saying.photoID));
}
const portraitIDs = new Set(porfyrios.map(s => s.photoID));
assert.equal(portraitIDs.size, 7, 'Use all seven supplied images');
for (const category of supplied.categories) {
  const rows = porfyrios.filter(s => s.categoryID === category.id);
  assert.equal(new Set(rows.map(s => s.photoID)).size, rows.length, 'No repeated photos inside a topic');
}
for (const id of portraitIDs) {
  const photo = catalog.photos.find(p => p.id === id);
  assert(photo && photo.textStart > 0 && photo.textStart < 1);
  for (const width of [150,175,362,386,600]) {
    const height = width * photo.height / photo.width;
    const start = height * photo.textStart;
    assert(height - start >= 25, 'Natural-aspect photos must leave room for a quote excerpt');
  }
  for (const height of [600,685,800]) {
    const imageHeight = Math.min(height * 0.48, 386 * photo.height / photo.width);
    assert(height - 70 - 82 - imageHeight >= 100, 'Reader retains a usable scroll area below the photo');
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
assert(imageBytes < 6_000_000);
const source = readFileSync('Klimax/SaintSayings.swift', 'utf8');
const tests = `
let data = try Data(contentsOf: URL(fileURLWithPath: "Klimax/saint-sayings.json"))
let catalog = try JSONDecoder().decode(SaintSayingsCatalog.self, from: data)
assert(catalog.isValid)
assert(catalog.collection().count == 74)
let savedIDs: Set<String> = ["PAI-001", "porfyrios-0001"]
let decoded = SaintSayingFavorites.decode(SaintSayingFavorites.encode(savedIDs))
assert(decoded == savedIDs)
assert(SaintSayingFavorites.decode(Data()).isEmpty)
assert(SaintSayingFavorites.decode(Data("invalid".utf8)).isEmpty)
assert(Set(catalog.collection(favoriteIDs: decoded).map(\\.id)) == savedIDs)
assert(catalog.collection(favoriteIDs: []).isEmpty)
assert(catalog.collection(favoriteIDs: ["missing"]).isEmpty)
let stored = UserDefaults(suiteName: "KlimaxSayingsTest-" + UUID().uuidString)!
stored.set(SaintSayingFavorites.encode(savedIDs), forKey: SaintSayingFavorites.storageKey)
assert(SaintSayingFavorites.decode(stored.data(forKey: SaintSayingFavorites.storageKey)!) == savedIDs)
stored.removeObject(forKey: SaintSayingFavorites.storageKey)
let shuffledIDs = Array(catalog.sayings.map(\\.id).reversed())
assert(catalog.collection(order: shuffledIDs).map(\\.id) == shuffledIDs)
let subset = catalog.collection(categoryID: "porfyrios-prayer-trust", order: shuffledIDs)
assert(subset.count == 4)
assert(subset.map(\\.id) == shuffledIDs.filter { id in subset.contains { $0.id == id } })
assert(!catalog.collection(query: "ΨΥΧΗ", order: shuffledIDs).isEmpty)
assert(catalog.collection(favoriteIDs: savedIDs, order: shuffledIDs).count == 2)

assert(catalog.filtered(saintID: "porfyrios", categoryID: nil, query: "").count == 33)
for saying in catalog.filtered(saintID: "porfyrios", categoryID: nil, query: "") {
    let photo = catalog.photo(for: saying)
    for width in [175.0, 386.0] {
        let size = CGSize(width: width, height: width * photo.height / photo.width)
        let region = photo.textRegion(in: size)
        assert(region.minY > 0 && region.maxY <= size.height)
        assert(region.height >= 25)
    }
}
assert(catalog.categories(for: "paisios").count == 4)
assert(catalog.categories(for: "porfyrios").count == 8)
for category in catalog.categories(for: "porfyrios") {
    let results = catalog.filtered(saintID: "porfyrios", categoryID: category.id, query: "")
    assert(!results.isEmpty && results.allSatisfy { $0.saintID == "porfyrios" && $0.categoryID == category.id })
    assert(catalog.filtered(saintID: "paisios", categoryID: category.id, query: "").isEmpty)
}
assert(!catalog.filtered(saintID: "porfyrios", categoryID: nil, query: "ΨΥΧΗ").isEmpty)
assert(catalog.filtered(saintID: "porfyrios", categoryID: nil, query: "ανύπαρκτηφράση").isEmpty)
assert(catalog.filtered(saintID: "paisios", categoryID: nil, query: "").count == 41)
for category in catalog.categories(for: "paisios") {
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
if (!process.argv.includes('--data-only')) {
const result = spawnSync('swift', ['-module-cache-path', '/tmp/klimax-prayer-test-cache', '-'], {input: source + tests, encoding: 'utf8'});
process.stdout.write(result.stdout ?? '');
process.stderr.write(result.stderr ?? '');
assert.equal(result.status, 0);
} else {
  console.log("SKIP: Swift runtime tests (--data-only); run full suite on a machine with Swift installed");
}
const ui = readFileSync('Klimax/SaintSayingsView.swift', 'utf8');
assert(ui.includes('PrayerInvitationCardLayout(viewport:'));
assert(ui.includes('Picker("Κατηγορία", selection: $categoryID)'));
assert(!ui.includes('if showCategory'));
assert(ui.includes('sayings.category.menu'));
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
console.log(`PASS: 74 texts, 12 populated categories, 15 image assets (${Math.round(imageBytes / 1024)} KB), protected subject areas, popup geometry and navigation wiring`);
