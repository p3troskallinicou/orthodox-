import { readFileSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import assert from 'node:assert/strict';

const shared = readFileSync('Widgets/WidgetSharedData.swift', 'utf8');
const model = shared.slice(0, shared.indexOf('enum WidgetSharedStore')).replace('import WidgetKit', '');
const checks = `
let original = KlimaxWidgetSnapshot.sample
let encoded = try JSONEncoder().encode(original)
var old = try JSONSerialization.jsonObject(with: encoded) as! [String: Any]
for key in ["fastingCalendar", "stories"] { old.removeValue(forKey: key) }
let legacy = try JSONDecoder().decode(KlimaxWidgetSnapshot.self, from: JSONSerialization.data(withJSONObject: old))
assert(legacy.todayCards == original.todayCards)
assert(legacy.fastingCalendar == nil && legacy.stories == nil)
var updated = legacy
updated.fastingCalendar = [PhoneWidgetCard(eyebrow: "ΝΗΣΤΕΙΑ", title: "Χωρίς νηστεία", detail: "", symbol: "fork.knife", themeKey: "free", date: Date())]
updated.stories = [PhoneWidgetCard(eyebrow: "ΓΕΡΟΝΤΙΚΟ", title: "Ιστορία", detail: "Αρχαίο κείμενο", symbol: "text.quote", reflection: "Σκέψη")]
let roundTrip = try JSONDecoder().decode(KlimaxWidgetSnapshot.self, from: JSONEncoder().encode(updated))
assert(updated == roundTrip)
assert(WidgetRefreshPlan.kinds(from: updated, to: updated).isEmpty)
var timestampOnly = updated
timestampOnly.day = updated.day.addingTimeInterval(0.001)
assert(WidgetRefreshPlan.kinds(from: updated, to: timestampOnly).isEmpty)
var goalOnly = updated
goalOnly.todayCards["streaks"]?.value = "99"
assert(WidgetRefreshPlan.kinds(from: updated, to: goalOnly) == ["Klimax.Today.streaks"])
var storyOnly = updated
storyOnly.stories?[0].title = "Άλλη ιστορία"
assert(WidgetRefreshPlan.kinds(from: updated, to: storyOnly) == ["Klimax.Today.dailyStories"])
var calendarOnly = updated
calendarOnly.fastingCalendar?[0].title = "Άλλη ημέρα"
assert(WidgetRefreshPlan.kinds(from: updated, to: calendarOnly) == ["Klimax.Today.fasting"])
var journeyOnly = updated
journeyOnly.scriptureJourney?.streak = 7
assert(WidgetRefreshPlan.kinds(from: updated, to: journeyOnly) == ["Klimax.ScriptureJourney"])
for zone in ["Europe/Athens", "Europe/London", "America/Los_Angeles"] {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: zone)!
    for month in 1...12 {
        let date = calendar.date(from: DateComponents(year: 2026, month: month, day: 1))!
        let days = calendar.range(of: .day, in: .month, for: date)!.count
        let leading = (calendar.component(.weekday, from: date) + 5) % 7
        let cells = ((leading + days + 6) / 7) * 7
        assert(cells % 7 == 0 && cells >= leading + days && cells <= 42)
        assert((0..<cells).filter { $0 >= leading && $0 < leading + days }.count == days)
    }
}
print("PASS: legacy snapshots, new payload round trip, 36 month/timezone grids")
`;
console.log(execFileSync('swift', ['-module-cache-path', '/private/tmp/klimax-widget-module-cache', '-'], { input: model + checks, encoding: 'utf8' }).trim());
const renderer = readFileSync('Widgets/HomeDashboardWidget.swift', 'utf8');
const registration = readFileSync('Widgets/TodayAndIconostasisWidgets.swift', 'utf8');
const app = readFileSync('Klimax/TodayView.swift', 'utf8');
assert(registration.includes('HomeDashboardWidget(entry: entry)'));
assert(registration.includes('"Klimax.Today.\\(kind.rawValue)"'));
assert(!renderer.includes('ScrollView') && !renderer.includes('DragGesture'));
for (const name of ['HomeSelectFastingDateIntent', 'HomeNextStoryIntent', 'mediumReading', 'mediumAudio', 'mediumStreak', 'monthGrid']) assert(renderer.includes(name));
assert(app.includes('fastingCalendar: calendarCards, stories: storyCards'));
assert(renderer.includes('0.106, green: 0.122, blue: 0.157'));
console.log('PASS: WidgetKit-safe layouts, stable widget identifiers, dated export and Today surface palette');
assert(!shared.includes('reloadAllTimelines()'));
assert(!renderer.slice(renderer.indexOf('struct HomeDashboardWidget:')).includes('WidgetSharedStore.'));
assert(!renderer.includes('reloadTimelines('));
assert(registration.includes('let card: PhoneWidgetCard'));
assert(renderer.includes('let days = monthDays'));
console.log('PASS: targeted reloads, no-op suppression, immutable rendering and single interaction reload');
