import { readFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';

// Exercise the production store using isolated preferences, never app data.
const source = readFileSync('Klimax/MediaProgress.swift', 'utf8');
const store = source.slice(source.indexOf('@Observable'), source.indexOf('/// A visible'))
  .replaceAll('UserDefaults.standard', 'testDefaults');
const design = readFileSync('Klimax/AthosDesignKit.swift', 'utf8');
const filters = design.slice(design.indexOf('enum AthosEpisodeFilter:'), design.indexOf('struct AthosSeriesGlassToolbar:'));
const program = `import Foundation
import Observation
let suite = "klimax.media.tests." + UUID().uuidString
let testDefaults = UserDefaults(suiteName: suite)!
defer { testDefaults.removePersistentDomain(forName: suite) }
testDefaults.set(Data(#"{"legacy":{"seconds":25,"finished":false}}"#.utf8), forKey: "klimax.mediaprogress.v1")
${store}
${filters}
let store = MediaProgress.shared
assert(store.fraction(for: "legacy", duration: 100) == 0.25)
assert(store.fraction(for: "new", duration: 100) == 0)
store.update(id: "audio", seconds: 30, duration: 120)
assert(store.fraction(for: "audio", duration: 0) == 0.25)
store.update(id: "audio", seconds: 12, duration: 120)
assert(store.fraction(for: "audio", duration: 0) == 0.1)
store.update(id: "audio", seconds: .nan, duration: 120)
assert(store.resumeSeconds(for: "audio") == 12)
store.update(id: "audio", seconds: 108, duration: 120)
assert(store.isFinished("audio"))
assert(store.resumeSeconds(for: "audio") == 0)
assert(store.fraction(for: "audio", duration: 0) == 1)
store.update(id: "audio", seconds: 5, duration: 120)
assert(store.isFinished("audio"))
store.markFinished("ended")
assert(store.isFinished("ended"))
store.update(id: "unknown", seconds: 20, duration: 0)
assert(!store.isFinished("unknown"))
assert(AthosEpisodeFilter.all.includes(id: "new"))
assert(AthosEpisodeFilter.unplayed.includes(id: "new"))
assert(!AthosEpisodeFilter.inProgress.includes(id: "new"))
assert(AthosEpisodeFilter.inProgress.includes(id: "unknown"))
assert(!AthosEpisodeFilter.unplayed.includes(id: "unknown"))
assert(AthosEpisodeFilter.completed.includes(id: "audio"))
assert(!AthosEpisodeFilter.inProgress.includes(id: "audio"))
assert(!AthosEpisodeFilter.unplayed.includes(id: "audio"))
store.flush()
let data = testDefaults.data(forKey: "klimax.mediaprogress.v1")!
let saved = try! JSONSerialization.jsonObject(with: data) as! [String: [String: Any]]
assert(saved["unknown"]?["seconds"] as? Double == 20)
assert(saved["audio"]?["duration"] as? Double == 120)
print("PASS: media progress migration, seeking, completion, duration, persistence and episode filters (including unknown duration)")
`;
const result = spawnSync('swift', ['-module-cache-path', '/tmp/klimax-media-test-cache', '-'], { input: program, encoding: 'utf8' });
process.stdout.write(result.stdout ?? '');
process.stderr.write(result.stderr ?? '');
process.exit(result.status ?? 1);
