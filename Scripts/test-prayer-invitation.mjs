import assert from 'node:assert/strict';
import {readFileSync, readdirSync, statSync} from 'node:fs';
import {spawnSync} from 'node:child_process';

const source = readFileSync('Klimax/PrayerInvitationSchedule.swift', 'utf8');
const tests = `
let suite = "klimax.prayer-invitation.tests." + UUID().uuidString
let defaults = UserDefaults(suiteName: suite)!
defer { defaults.removePersistentDomain(forName: suite) }
var calendar = Calendar(identifier: .gregorian)
calendar.timeZone = TimeZone(identifier: "Europe/London")!
func date(_ day: Int = 26, _ hour: Int, _ minute: Int = 0) -> Date {
    calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))!
}
let schedule = PrayerInvitationSchedule(defaults: defaults)
assert(PrayerInvitationKind.current(at: date(26, 0), calendar: calendar) == .morning)
assert(schedule.pending(at: date(26, 11, 59), calendar: calendar) == .morning)
assert(schedule.pending(at: date(26, 12), calendar: calendar) == nil)
assert(schedule.pending(at: date(26, 18, 59), calendar: calendar) == nil)
assert(schedule.pending(at: date(26, 19), calendar: calendar) == .evening)
assert(schedule.pending(at: date(26, 23, 59), calendar: calendar) == .evening)
assert(schedule.pending(at: date(26, 9), calendar: calendar, allowFirstPresentation: false) == nil)
schedule.markPresented(.morning, at: date(26, 9), calendar: calendar)
assert(schedule.pending(at: date(26, 9, 1), calendar: calendar) == nil)
let relaunched = PrayerInvitationSchedule(defaults: defaults)
assert(relaunched.pending(at: date(26, 10), calendar: calendar) == nil)
assert(relaunched.pending(at: date(26, 19), calendar: calendar) == .evening)
assert(schedule.snooze(.morning, minutes: 30, at: date(26, 9), calendar: calendar))
assert(schedule.pending(at: date(26, 9, 29), calendar: calendar) == nil)
assert(schedule.pending(at: date(26, 9, 30), calendar: calendar, allowFirstPresentation: false) == .morning)
schedule.markPresented(.morning, at: date(26, 9, 30), calendar: calendar)
assert(schedule.nextReminder(at: date(26, 10), calendar: calendar) == nil)
assert(schedule.pending(at: date(26, 11), calendar: calendar) == nil)
assert(schedule.snooze(.morning, minutes: 30, at: date(26, 11, 45), calendar: calendar))
assert(schedule.pending(at: date(26, 12, 14), calendar: calendar) == nil)
assert(schedule.pending(at: date(26, 12, 15), calendar: calendar) == .morning)
schedule.markPresented(.morning, at: date(26, 12, 15), calendar: calendar)
assert(!schedule.snooze(.morning, minutes: 0, at: date(26, 9), calendar: calendar))
assert(!schedule.snooze(.morning, minutes: 1441, at: date(26, 9), calendar: calendar))
assert(schedule.pending(at: date(27, 9), calendar: calendar) == .morning)
schedule.markPresented(.evening, at: date(26, 19), calendar: calendar)
assert(schedule.pending(at: date(26, 22), calendar: calendar) == nil)
assert(schedule.pending(at: date(27, 19), calendar: calendar) == .evening)
assert(schedule.snooze(.morning, until: date(27, 10), at: date(26, 11), calendar: calendar))
assert(schedule.pending(at: date(27, 9), calendar: calendar) == nil)
assert(schedule.pending(at: date(27, 10), calendar: calendar) == .morning)
schedule.markPresented(.morning, at: date(27, 10), calendar: calendar)
assert(schedule.pending(at: date(27, 11), calendar: calendar) == nil)
assert(schedule.snooze(.evening, minutes: 30, at: date(26, 23, 50), calendar: calendar))
assert(schedule.pending(at: date(27, 0, 20), calendar: calendar) == .evening)
assert(schedule.pending(at: date(28, 0, 21), calendar: calendar) == .morning)
// DST ended October 25; local-hour windows and calendar dates still apply.
assert(PrayerInvitationKind.current(at: date(25, 11, 59), calendar: calendar) == .morning)
assert(PrayerInvitationKind.current(at: date(25, 12), calendar: calendar) == nil)
calendar.timeZone = TimeZone(identifier: "Europe/Athens")!
assert(PrayerInvitationKind.current(at: date(26, 19), calendar: calendar) == .evening)
for kind in PrayerInvitationKind.allCases {
    assert(kind.imageName(at: date(26, 9), calendar: calendar) == kind.imageName(at: date(26, 11), calendar: calendar))
    assert(kind.imageName(at: date(26, 9), calendar: calendar) != kind.imageName(at: date(27, 9), calendar: calendar))
}
print("PASS: local time boundaries, first-entry only, relaunch persistence, morning/evening independence, snooze consumption/expiry, DST, timezone and daily image rotation")
`;
const result = spawnSync('swift', ['-module-cache-path', '/tmp/klimax-prayer-test-cache', '-'], {input: source + '\n' + tests, encoding: 'utf8'});
process.stdout.write(result.stdout ?? '');
process.stderr.write(result.stderr ?? '');
assert.equal(result.status, 0);

const corpus = JSON.parse(readFileSync('Klimax/prayers.json', 'utf8'));
for (const id of ['prooimiaki', 'mikron-apodeipnon']) {
  const prayer = corpus.categories.flatMap(c => c.prayers).find(p => p.id === id);
  assert.equal(prayer.status, 'complete');
  assert(prayer.body.length > 20);
  for (const line of prayer.body.filter(p => p.startsWith('@link:'))) {
    assert(corpus.categories.flatMap(c => c.prayers).some(p => p.id === line.slice(6).split('|')[0]));
  }
}
let bytes = 0;
for (const [prefix, count] of [['Morning', 10], ['Evening', 8]]) {
  for (let n = 1; n <= count; n++) {
    const dir = 'Klimax/Assets.xcassets/Prayer' + prefix + n + '.imageset/';
    const file = JSON.parse(readFileSync(dir + 'Contents.json')).images[0].filename;
    assert(readdirSync(dir).includes(file));
    bytes += statSync(dir + file).size;
  }
}
assert(bytes < 8_000_000, 'Do not ship the 58 MB source photos.');
const ui = readFileSync('Klimax/PrayerInvitationView.swift', 'utf8');
assert(ui.includes('.clipShape(RoundedRectangle(cornerRadius: 34'));
assert(ui.includes('.fullScreenCover(item: $invitation'), 'Do not reintroduce a second native sheet behind the photo.');
assert(ui.includes('.presentationBackground(.clear)'), 'The gap below the card must show the app.');
const closeButton = ui.slice(ui.indexOf('.overlay(alignment: .topTrailing)'), ui.indexOf('.sensoryFeedback(.success'));
assert(closeButton.includes('.foregroundStyle(.primary)'), 'The close glyph must adapt with the glass, not force white over a light background.');
assert(closeButton.includes('.glassCircleFallback(shape: Circle())'));
const layout = ui.slice(ui.indexOf('struct PrayerInvitationCardLayout {'), ui.indexOf('/// App entry only'));
const layoutTests = `
// Measured against the old native sheet on iPhone 17 Pro, after animation.
let baseline = PrayerInvitationCardLayout(viewport: CGSize(width: 402, height: 874), safeAreaTop: 62, safeAreaBottom: 34, isLiquidGlass: true).frame
assert(abs(baseline.minY - 131.1277) < 0.1, "The top must not move")
assert(baseline.width == 386, "Use the former outer sheet's width")
assert(abs(baseline.height - 685.5) < 0.1, "Grow down proportionally, not from the centre")
assert(baseline.maxY < 874 - 24, "Keep a visible gap beneath the rounded bottom")
for size in [CGSize(width: 375, height: 667), CGSize(width: 390, height: 844), CGSize(width: 430, height: 932), CGSize(width: 874, height: 402), CGSize(width: 820, height: 1180)] {
    for glass in [false, true] {
        let frame = PrayerInvitationCardLayout(viewport: size, safeAreaTop: 62, safeAreaBottom: 34, isLiquidGlass: glass).frame
        assert(frame.width > 0 && frame.height > 0)
        assert(abs(frame.midX - size.width / 2) < 0.01)
        assert(frame.minY > 0 && frame.maxY <= size.height - 24)
    }
}
print("PASS: original top, wider single card, proportional downward growth, visible bottom gap and adaptive bounds")
`;
const layoutResult = spawnSync('swift', ['-module-cache-path', '/tmp/klimax-prayer-test-cache', '-'], {input: 'import Foundation\nimport CoreGraphics\n' + layout + layoutTests, encoding: 'utf8'});
process.stdout.write(layoutResult.stdout ?? '');
process.stderr.write(layoutResult.stderr ?? '');
assert.equal(layoutResult.status, 0);
assert(ui.includes('Button("Άλλο…")'));
assert(ui.includes('PrayerPracticeMemory.markPrayed'));
assert(ui.includes('StreakStore.shared.record(.prayer'));
assert(ui.includes('onScrollGeometryChange(for: Bool.self)'));
assert(ui.includes('DeisisSection(document:'));
assert(ui.includes('root.presentedViewController == nil'));
assert(!ui.includes('UNUserNotificationCenter'), 'In-app reminders must not request notification permission.');
console.log('PASS: complete bundled texts, linked prayers, shared completion, presentation guards and 18 optimized images (' + Math.round(bytes / 1024) + ' KB)');
