import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

// Source-level regression guards. Runtime playback/navigation is also checked
// in Simulator; these prevent reintroducing the original identity mistake.
const read = name => readFileSync(`Klimax/${name}.swift`, 'utf8');
const root = read('RootView');
const base = root.slice(root.indexOf('@ViewBuilder private var base'), root.indexOf('private var tabView:'));
assert.match(base, /tabViewBottomAccessory\(isEnabled: hasCurrentAudio\)/);
assert.doesNotMatch(base, /if hasCurrentAudio\s*\{\s*tabView/,
  'Playback state must not replace the TabView and destroy navigation stacks.');
assert.match(root, /\.fullScreenCover\(item: \$presentedHomily/);
assert.doesNotMatch(root, /\.sheet\(item: \$presentedHomily/);
assert.match(root, /guard let homily else\s*\{\s*presentedHomily = nil/);

const today = read('TodayView');
const widget = today.slice(today.indexOf('private struct DidachesTodayWidget'), today.indexOf('private struct DailyStoriesTodayWidget'));
assert.match(widget, /player\.present\(homily, context: context\)/);
assert.doesNotMatch(widget, /\.sheet\(|HomilyPlayerView\(/,
  'Today must share the stable full-screen presenter, not own a second sheet.');

const audio = read('AthosAudioView');
const video = read('AthosTVView');
const catalogue = video.slice(video.indexOf('struct AthosTVView:'), video.indexOf('private func catalogue('));
assert.match(catalogue, /@State private var isShowingEntryIntro = true/);
assert.doesNotMatch(catalogue, /\.onAppear\s*\{\s*isShowingEntryIntro = true/,
  'Returning from a series must not replay the Athos entry intro.');
assert.match(video, /\.navigationDestination\(item: \$seriesPresentation/);
assert.doesNotMatch(video, /\.fullScreenCover\(item: \$seriesPresentation/,
  'A TV series must remain on the navigation stack underneath the video player.');
const audioRow = audio.slice(audio.indexOf('private struct AthosAudioEpisodeRow'), audio.indexOf('private struct AthosAudioSearchView'));
const videoRow = video.slice(video.indexOf('private struct AthosEpisodeRow'), video.indexOf('private struct AthosSearchPresentation'));
assert.match(videoRow, /HStack\(alignment: \.top, spacing: 6\)[\s\S]*?Text\(video\.title\)[\s\S]*?AthosFavoriteButton/,
  'Episode favourites belong beside the title, not on their own bottom row.');
assert.doesNotMatch(videoRow, /Spacer\(minLength: 0\)[\s\S]*?AthosFavoriteButton/);
assert.match(videoRow, /AthosRemoteThumbnail\(video: video/);
assert.match(videoRow, /frame\(width: thumbnailWidth, height: thumbnailWidth \* 9 \/ 16\)/,
  'Keep episode artwork in its 16:9 aspect ratio.');
assert.match(videoRow, /VStack\(alignment: \.leading, spacing: 4\)[\s\S]*AthosRemoteThumbnail[\s\S]*AthosPlaybackPill[^\n]*compact: true/,
  'Anchor duration directly beneath the artwork, independently of the text height.');
for (const row of [audioRow, videoRow]) {
  assert.match(row, /AthosPlaybackPill\(/);
  assert.doesNotMatch(row, /AthosPlaybackStatus\(/, 'No separate progress track outside the play pill.');
  assert.match(row, /size: 18, weight: \.semibold/);
  assert.match(row, /padding\(\.horizontal, 20\)\.padding\(\.vertical, 14\)/);
}
const pill = read('MediaProgress');
assert.match(pill, /if started, !finished/);
assert.match(pill, /finished \? "checkmark" : "play.fill"/);
assert.match(pill, /finished \? AthosPlaybackStatus.green/);
assert.match(pill, /accessibilityReduceMotion/);
assert.match(read('LogosDidaches'), /accessibilityIdentifier\("athos.player.close"\)/);
console.log('PASS: stable playback navigation, full-screen presentation, shared episode pills and layout');
