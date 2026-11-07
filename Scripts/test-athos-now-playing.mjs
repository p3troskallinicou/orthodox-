import assert from 'node:assert/strict';
import { readFileSync, existsSync } from 'node:fs';

const read = name => readFileSync(`Klimax/${name}.swift`, 'utf8');
const player = read('LogosDidaches');
const metadata = player.slice(player.indexOf('private func updateNowPlaying()'), player.indexOf('// MARK: - Παλέτα'));
const design = read('AthosDesignKit');
const artwork = design.slice(design.indexOf('enum AthosNowPlayingArtwork'), design.indexOf('// MARK: - Podcast reference surfaces'));
const library = read('AthosAudioView').split('enum AthosAudioCoverLibrary {')[1].split('private struct AthosAudioSubjectView')[0];

assert.match(metadata, /MPMediaItemPropertyArtwork\] = AthosNowPlayingArtwork\.audio\(subject: h\.subject\)/);
assert.match(metadata, /MPMediaItemPropertyAlbumTitle: h\.subject/);
assert.match(metadata, /MPNowPlayingInfoPropertyExternalContentIdentifier: h\.id/);
assert.match(metadata, /MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime/);
assert.match(metadata, /MPNowPlayingInfoPropertyPlaybackRate: isPlaying \? rate : 0/);
assert.match(player, /func stop\(\)[\s\S]*?nowPlayingInfo = nil/);
for (const action of ['play', 'pause', 'seek', 'setRate']) {
  const body = player.split(`func ${action}(`)[1]?.split('\n    }')[0] ?? '';
  assert.match(body, /updateNowPlaying\(\)/, `${action} must retain artwork while updating transport metadata`);
}
assert.match(artwork, /NSCache<NSString, MPMediaItemArtwork>/);
assert.match(artwork, /cache\.countLimit = 8/);
assert.match(artwork, /cache\.object\(forKey:/);
assert.match(artwork, /CGSize\(width: 600, height: 600\)/);
assert.match(artwork, /format\.scale = 1/);
assert.match(artwork, /let scale = max\(size\.width \/ source\.size\.width, size\.height \/ source\.size\.height\)/);
assert.match(artwork, /MPMediaItemArtwork\(boundsSize: image\.size\)/);
assert.doesNotMatch(artwork, /URLSession|Data\(contentsOf:/, 'Lock Screen covers must work offline.');
assert.match(player, /AthosPodcastCover\(title: shownContext, fadesTop: true, artworkSubject: shown\.subject\)/,
  'The in-app player and Lock Screen must use the same subject artwork.');

const covers = [...new Set(library.match(/AthosAudioCover[A-Za-z]+/g))];
assert.equal(covers.length, 18);
for (const cover of covers) {
  const directory = `Klimax/Assets.xcassets/${cover}.imageset`;
  const contents = JSON.parse(readFileSync(`${directory}/Contents.json`, 'utf8'));
  const file = contents.images.find(image => image.filename)?.filename;
  assert.ok(file && existsSync(`${directory}/${file}`), `Missing bundled artwork: ${cover}`);
  const png = readFileSync(`${directory}/${file}`);
  assert.equal(png.subarray(1, 4).toString(), 'PNG');
  assert.ok(png.readUInt32BE(16) >= 600 && png.readUInt32BE(20) >= 600, `${cover} must have enough resolution`);
}

// Do not accidentally implement hidden/background YouTube playback while
// improving native audio metadata. TV currently has no direct audio sources.
const tv = read('AthosTVView');
assert.match(tv, /\.onChange\(of: scenePhase\) \{ _, phase in\s*guard phase != \.active else \{ return \}\s*pause\(\)/);
console.log('PASS: 18 bundled covers, matching player/Lock Screen artwork, bounded cache, transport metadata and YouTube foreground policy');
