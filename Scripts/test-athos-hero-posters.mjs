import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';
import { createHash } from 'node:crypto';

// The original package manifest is retained verbatim, including its SHA-256 hashes.
const manifest = JSON.parse(readFileSync('Documentation/athos-tv-hero-posters.json'));
const policy = readFileSync('Klimax/AthosTVCollections.swift', 'utf8');
const view = readFileSync('Klimax/AthosTVView.swift', 'utf8');
const assets = [...policy.matchAll(/heroAssetName: "(AthosTVHero[^"]+)"/g)].map(m => m[1]);
assert.equal(manifest.posters.length, 11);
assert.equal(new Set(assets).size, 11);
assert.deepEqual(assets, manifest.posters.map(p => p.xcode_suggested_asset));
assert.deepEqual(readdirSync('Klimax/Assets.xcassets').filter(n => n.startsWith('AthosTVHero')).sort(),
  assets.map(a => a + '.imageset').sort());
for (const poster of manifest.posters) {
  const dir = 'Klimax/Assets.xcassets/' + poster.xcode_suggested_asset + '.imageset/';
  const metadata = JSON.parse(readFileSync(dir + 'Contents.json'));
  assert.equal(metadata.images.length, 1);
  assert.equal(metadata.images[0].idiom, 'universal');
  assert.equal(metadata.images[0].filename, poster.poster_file.split('/').at(-1));
  const png = readFileSync(dir + metadata.images[0].filename);
  assert.equal(png.subarray(1, 4).toString(), 'PNG');
  assert.equal(png.readUInt32BE(16), 1024);
  assert.equal(png.readUInt32BE(20), 1536);
  assert.equal(createHash('sha256').update(png).digest('hex'), poster.sha256,
    poster.series_title + ': approved pixels must stay unchanged');
}
assert.match(view, /AthosTVHomeHero\(collections: store\.presentation\.collections,/,
  'All eleven visible collections must be reachable in the poster carousel.');
const home = view.slice(view.indexOf('private struct AthosTVHomeHero:'), view.indexOf('private struct AthosFeaturedCarousel:'));
assert.match(home, /AthosTVHeroPoster/);
assert.match(home, /scrollTargetBehavior\(\.paging\)/);
assert.match(home, /scrollPosition\(id: \$selection\)/);
assert.doesNotMatch(home, /background\(colour\)|Color\.clear\.frame\(height: 76\)/,
  'Do not restore the empty header or brown controls panel.');
const posterView = home.slice(home.indexOf('private struct AthosTVHeroPoster:'), home.indexOf('private struct AthosTVPosterStage'));
assert.match(posterView, /collection\.heroAssetName/);
assert.match(posterView, /scaledToFit\(\)/);
assert.match(posterView, /aspectRatio\(2\.0 \/ 3\.0, contentMode: \.fit\)/);
assert.doesNotMatch(posterView, /Text\(collection\.title\)|scaledToFill|LinearGradient/,
  'The main portrait must retain its full composition without duplicate titles.');
const stage = home.slice(home.indexOf('private struct AthosTVPosterStage'));
assert.match(stage, /overlay\(alignment: \.bottom\)/,
  'Playback controls belong over the lower poster, not in a separate panel.');
const detail = view.slice(view.indexOf('struct AthosSeriesDetailView:'), view.indexOf('#if DEBUG\nstruct AthosVideoReferencePreview'));
assert.match(detail, /AthosTVPosterStage/);
assert.match(detail, /AthosPodcastPlayButton/);
assert.match(detail, /AthosSeriesGlassToolbar/);
assert.doesNotMatch(view, /AthosTVPosterBackdrop|topClearance/,
  'Do not restore duplicated/blurred header strips or clearance above the actual poster.');
assert.match(home, /\.frame\(height: width \* 1\.5\)/,
  'The carousel must use only the actual 2:3 poster height.');
const catalogue = view.slice(view.indexOf('private func catalogue('), view.indexOf('private func present('));
for (const screen of [catalogue, detail]) {
  assert.match(screen, /\.contentMargins\(\.top, 0, for: \.scrollContent\)/);
  assert.match(screen, /\.ignoresSafeArea\(\.container, edges: \.top\)/,
    'The scrolling poster must reach the top of the display behind safe-area-aligned controls.');
  assert.doesNotMatch(screen, /\.background\(alignment: \.top\)/,
    'Do not add a separate image strip above the poster.');
}
assert.match(catalogue, /\.onScrollGeometryChange\(for: Bool\.self\)/);
assert.match(catalogue, /posterHeight - headerDepth/,
  'Reveal the catalogue header at the actual poster boundary, not at an arbitrary scroll offset.');
assert.match(catalogue, /Rectangle\(\)\.fill\(\.regularMaterial\)[\s\S]*?\.opacity\(headerCondensed \? 1 : 0\)/,
  'The blurred catalogue header must remain invisible while the poster is behind the controls.');
assert.match(detail, /overContent: toolbarOverEpisodes/);
assert.match(detail, /\.onScrollGeometryChange\(for: Bool\.self\)/);
assert.match(detail, /\.opacity\(toolbarOverEpisodes \? 1 : 0\)/,
  'Series controls also need a readable header after their poster scrolls away.');
const header = view.slice(view.indexOf('private func athosHeader('), view.indexOf('private enum AthosTVPalette'));
assert.match(header, /AthosMediaBrandMenu[\s\S]*?\.opacity\(headerCondensed \? 1 : 0\)[\s\S]*?\.allowsHitTesting\(headerCondensed\)[\s\S]*?\.accessibilityHidden\(!headerCondensed\)/,
  'The upper wordmark must not cover the embedded poster title or leave an invisible active menu.');
assert.match(home, /AthosMediaBrandMenu\(selection: \$mediaMode,/,
  'Keep TV/Audio switching available beside the hero playback controls.');
const pager = home.slice(home.indexOf('ScrollView(.horizontal)'), home.indexOf('.scrollPosition(id: $selection)'));
assert.doesNotMatch(pager, /AthosMediaBrandMenu|AthosPodcastPlayButton|episodeCountText/,
  'Only artwork pages horizontally; controls must be shared stationary overlays.');
assert.match(home, /Text\(selected\.episodeCountText\)[\s\S]*?\.contentTransition\(\.numericText\(\)\)/);
assert.match(home, /\.animation\(reduceMotion \? nil : \.smooth\(duration: 0\.32\), value: selection\)/,
  'Page indicators animate for swipes as well as direct taps, respecting Reduce Motion.');
console.log('PASS: all 11 original 1024×1536 posters, exact package hashes, independent hero mappings, full portrait rendering and shared home/detail stages');
