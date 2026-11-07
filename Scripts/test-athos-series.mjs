import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { spawnSync } from 'node:child_process';

const source = readFileSync('Klimax/AthosTVView.swift', 'utf8');
const models = source.slice(source.indexOf('struct AthosTVPage:'), source.indexOf('enum AthosTVCatalogue'));
const policy = readFileSync('Klimax/AthosTVCollections.swift', 'utf8');
const catalogue = readFileSync('Klimax/athos_tv_page.json');
assert.equal(createHash('sha256').update(catalogue).digest('hex'),
  '2b94cb37610615a9c26bff54f8e48d4091dcbbc5779f6bebe40ac16d52c19819',
  'This artwork-only change must preserve the complete original catalogue.');

const assets = [...policy.matchAll(/coverAssetName: "(AthosTVSeries[^"]+)"/g)].map(m => m[1]);
assert.equal(assets.length, 11);
assert.equal(new Set(assets).size, 11, 'The merged collection shares one image asset.');
assert.deepEqual(readdirSync('Klimax/Assets.xcassets').filter(n => n.startsWith('AthosTVSeries')).sort(),
  assets.map(a => a + '.imageset').sort());
for (const asset of assets) {
  const path = 'Klimax/Assets.xcassets/' + asset + '.imageset/';
  const metadata = JSON.parse(readFileSync(path + 'Contents.json'));
  assert.equal(metadata.images.length, 1);
  assert.equal(metadata.images[0].idiom, 'universal');
  const png = readFileSync(path + metadata.images[0].filename);
  assert.equal(png.subarray(1, 4).toString(), 'PNG');
  assert.equal(png.readUInt32BE(16), 1024);
  assert.equal(png.readUInt32BE(20), 1024);
}

const card = source.slice(source.indexOf('struct AthosTVSeriesCover:'), source.indexOf('private struct AthosReelsShelf:'));
assert.match(card, /scaledToFit\(\)/);
assert.match(card, /aspectRatio\(1, contentMode: \.fit\)/);
assert.doesNotMatch(card, /LinearGradient|Text\(collection\.title\)|scaledToFill|\.overlay/);
assert.match(source, /AthosSeriesLibrary\(collections: store\.presentation\.collections/);
assert.match(source, /catalogue: store\.presentation/);
assert.match(source, /ForEach\(collections\)/);
assert.doesNotMatch(source, /Set\(videos\.compactMap\(\\\.series\)\)/);
assert.match(source, /favorites\.videos\(in: page, presentation: store\.presentation\)/);
const speakers = readFileSync('Klimax/AthosAudioSpeakers.swift', 'utf8');
assert.match(speakers, /videos: \[AthosTVVideo\] = AthosTVCatalogue\.presentation\.videos/);
assert.match(speakers, /AthosTVCatalogue\.presentation\.collections/);
assert.match(speakers, /AthosSeriesDetailView\(collection: collection\)/);
const detail = source.slice(source.indexOf('struct AthosSeriesDetailView:'), source.indexOf('#if DEBUG\nstruct AthosVideoReferencePreview'));
assert.match(detail, /AthosTVPosterStage\(collection: collection\)/);
assert.match(detail, /\.ignoresSafeArea\(\.container, edges: \.top\)/);
assert.doesNotMatch(detail, /AthosTVPosterBackdrop|topClearance/);
assert.match(detail, /AthosPodcastPlayButton\(tone: \.black\)/,
  'Preserve the Apple Podcasts play capsule on the series header.');
assert.match(detail, /AthosSeriesGlassToolbar/);
assert.doesNotMatch(detail, /Text\(collection\.title\)|LinearGradient|AthosPalette\.gold/,
  'Keep custom artwork unobstructed, without a duplicate title or generic app CTA.');

// Run the real Swift presentation policy against the real bundled catalogue.
const program = ['import Foundation', models, policy, String.raw`
let data = try Data(contentsOf: URL(fileURLWithPath: "Klimax/athos_tv_page.json"))
let page = try JSONDecoder().decode(AthosTVPage.self, from: data)
let presentation = AthosTVPresentation(page: page)
let definitions = AthosTVSeriesDefinition.all
assert(page.rows.count == 14)
assert(page.videos.count == 2095)
assert(presentation.collections.count == 11)
assert(presentation.collections.map(\.id) == definitions.filter(\.isVisibleInAthosTV).map(\.id))
assert(Set(page.rows.map(\.title)) == Set(definitions.flatMap(\.sourceTitles)))
let hidden = definitions.filter { !$0.isVisibleInAthosTV }
assert(hidden.count == 2)
for definition in hidden {
    assert(page.rows.contains { definition.sourceTitles.contains($0.title) && !$0.videoIds.isEmpty })
    assert(!presentation.collections.contains { $0.id == definition.id })
}
let merged = presentation.collections.first { $0.id == "athanasios-talks" }!
let sources = page.rows.filter { merged.definition.sourceTitles.contains($0.title) }
assert(sources.count == 2)
let originalIDs = Set(sources.flatMap(\.videoIds).filter { page.videos[$0] != nil })
assert(Set(merged.videos.map(\.videoId)) == originalIDs)
assert(merged.videos.count == originalIDs.count)
assert(merged.videos.count == 279)
assert(merged.episodeCountText == "\(originalIDs.count) επεισόδια")
assert(merged.coverAssetName == "AthosTVSeriesLiveRecordedTalks")
assert(merged.matches("βιντεοσκοπημένες"))
assert(merged.matches("ΖΩΝΤΑΝΕΣ"))
assert(merged.matches("αθανασίου"))
let sermons = presentation.collections.first { $0.id == "athanasios-sermons" }!
assert(sermons.videos.count == 161)
assert(sermons.coverAssetName == "AthosTVSeriesMetropolitanAthanasios")
for collection in presentation.collections {
    let sourceIDs = Set(page.rows.filter { collection.definition.sourceTitles.contains($0.title) }
        .flatMap(\.videoIds).filter { page.videos[$0] != nil })
    assert(Set(collection.videos.map(\.videoId)) == sourceIDs)
    assert(collection.videos.count == sourceIDs.count)
    assert(collection.videos.sorted(by: AthosTVPresentation.episodeOrder).map(\.id) == collection.videos.map(\.id))
    for video in collection.videos {
        let original = page.videos[video.videoId]!
        assert(video.thumbnail == original.thumbnail)
        assert(video.watchUrl == original.watchUrl)
        assert(video.series == original.series)
        assert(video.playlists == original.playlists)
        assert(video.description == original.description)
    }
}
let visibleIDs = Set(presentation.collections.flatMap { $0.videos.map(\.videoId) })
let hiddenIDs = Set(page.rows.filter { row in hidden.contains { $0.sourceTitles.contains(row.title) } }.flatMap(\.videoIds))
assert(hiddenIDs.subtracting(visibleIDs).count == 409)
assert(presentation.videoIDs.isDisjoint(with: hiddenIDs.subtracting(visibleIDs)))
assert(hiddenIDs.intersection(visibleIDs).isSubset(of: presentation.videoIDs))
assert(Set(page.reels).isSubset(of: presentation.videoIDs))

// Reactivation is a visibility flag, not a migration or a data restore.
let restored = AthosTVPresentation(page: page, definitions: definitions.map {
    var definition = $0
    definition.isVisibleInAthosTV = true
    return definition
})
assert(restored.collections.count == 13)
assert(restored.videos.count == page.videos.count)

// Future repeated IDs and missing references cannot corrupt counts or ordering.
let repeatedRows = page.rows + [AthosTVRow(title: sources[0].title,
    videoIds: [merged.videos[0].videoId, merged.videos[0].videoId, "missing-reference"])]
let repeated = AthosTVPresentation(page: AthosTVPage(rows: repeatedRows, reels: page.reels, videos: page.videos))
assert(repeated.collections.first { $0.id == merged.id }!.videos.map(\.id) == merged.videos.map(\.id))
let subset = merged.limited(to: Set(merged.videos.prefix(3).map(\.id)))
assert(subset.videos.count == 3 && subset.coverAssetName == merged.coverAssetName)
print("PASS: 11 visible collections; 279 merged episodes; no lost/duplicate IDs; separate 161 sermons; hidden data reactivates; thumbnails/metadata unchanged")
`].join('\n');
const result = spawnSync('swift', ['-module-cache-path', '/tmp/klimax-athos-series-test-cache', '-'],
  { input: program, encoding: 'utf8' });
process.stdout.write(result.stdout ?? '');
process.stderr.write(result.stderr ?? '');
assert.equal(result.status, 0, 'Swift collection-policy tests');
console.log('PASS: 11 square 1024px assets; shared browse/search/speaker policy; artwork has no duplicate titles/overlays');
