#!/usr/bin/env node
// Exercise the actual planner persistence/scheduling code without an app build.
// Collaborating goal records are ID/title fixtures; no real preferences are used.
import { readFileSync, mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';

const source = readFileSync(new URL('../Klimax/TodayView.swift', import.meta.url), 'utf8');
const start = source.indexOf('private enum DayPlanKind:');
const end = source.indexOf('/// Gives every Today row an exact two-column geometry.');
if (start < 0 || end <= start) throw new Error('Planner model boundary changed; review this harness.');
const progression = readFileSync(new URL('../Klimax/ProgressionStore.swift', import.meta.url), 'utf8');
const cadenceStart = progression.indexOf('enum GoalCadenceType:');
const cadenceEnd = progression.indexOf('enum GoalSource:', cadenceStart);
if (cadenceStart < 0 || cadenceEnd <= cadenceStart) throw new Error('Goal cadence boundary changed; review this harness.');
const scaffolding = String.raw`
import Foundation
import SwiftUI
import Combine

enum Paper { static let gold = Color.red }
struct StreakGoal {
    let id: UUID
    let title: String
    let subtitle: String
}
final class VolatileDefaults: UserDefaults {
    private var values: [String: Any] = [:]
    var writes = 0
    override func data(forKey defaultName: String) -> Data? { values[defaultName] as? Data }
    override func set(_ value: Any?, forKey defaultName: String) {
        values[defaultName] = value
        writes += 1
    }
}
`;
const tests = String.raw`
MainActor.assumeIsolated {
    var checks = 0
    func expect(_ condition: @autoclosure () -> Bool, _ description: String) {
        guard condition() else { fatalError("FAIL: \(description)") }
        checks += 1
    }
    func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }
    let friday = date(2026, 10, 9)
    let thursday = date(2026, 10, 8)
    let saturday = date(2026, 10, 10)
    let monday = date(2026, 10, 12)
    let nextFriday = date(2026, 10, 16)
    let key = "today.dayPlan.v1"
    let decoder = JSONDecoder()

    let legacy = try! decoder.decode(DayPlanItem.self, from: Data(#"{"dayKey":20261009,"title":"Παλιό","detail":"σημείωση","kind":"prayer","isComplete":true}"#.utf8))
    expect(legacy.categoryID == nil && legacy.colorID == nil, "Legacy items decode without category and colour")
    expect(legacy.cadence.type == .once, "Legacy items retain once-only schedule")
    expect(legacy.completedDayKeys == [20261009], "Legacy completed flag migrates to its own date")
    expect(legacy.linkedGoalID == nil, "Legacy items do not invent a goal link")
    let uncompleted = try! decoder.decode(DayPlanItem.self, from: Data(#"{"dayKey":20261009,"title":"Παλιό","kind":"quiet"}"#.utf8))
    expect(uncompleted.completedDayKeys.isEmpty, "Uncompleted legacy item remains incomplete")

    let defaults = VolatileDefaults()
    let store = TodayDayPlanStore(defaults: defaults)
    let categoryID = UUID()
    store.add(title: "  Σημείωση  ", detail: "  Λεπτομέρεια  ", kind: .other, customKind: "  Σπίτι  ",
              cadence: DayPlanCadence(type: .daily), categoryID: categoryID, colorID: "sage", on: friday)
    let original = store.items[0]
    expect(original.title == "Σημείωση" && original.detail == "Λεπτομέρεια", "New item trims its text")
    expect(original.customKind == "Σπίτι", "Custom category fallback name is trimmed")
    expect(original.categoryID == categoryID && original.colorID == "sage", "Custom identity and override are stored")
    let loaded = TodayDayPlanStore(defaults: defaults)
    expect(loaded.items == store.items, "Planner reload preserves all encoded fields")
    expect(loaded.items[0].categoryID == categoryID && loaded.items[0].colorID == "sage", "Reload retains category UUID and override")

    @MainActor func add(_ title: String, _ cadence: DayPlanCadence) {
        store.add(title: title, detail: "", kind: .personal, customKind: "", cadence: cadence, on: friday)
    }
    add("once", DayPlanCadence())
    add("weekly", DayPlanCadence(type: .weekly))
    add("weekdays", DayPlanCadence(type: .weekdays, weekdays: [2, 6]))
    @MainActor func titles(_ date: Date) -> Set<String> { Set(store.items(on: date).map(\.title)) }
    expect(titles(thursday).isEmpty, "Schedules never appear before their start date")
    expect(titles(friday) == ["Σημείωση", "once", "weekly", "weekdays"], "All matching schedules appear on start day")
    expect(titles(saturday) == ["Σημείωση"], "Only daily item appears on Saturday")
    expect(titles(monday) == ["Σημείωση", "weekdays"], "Specific-weekday item appears on Monday")
    expect(titles(nextFriday) == ["Σημείωση", "weekly", "weekdays"], "Weekly returns on start weekday; once does not")
    let noWrite = defaults.writes
    store.add(title: "  \n", detail: "", kind: .personal, customKind: "", cadence: DayPlanCadence(), on: friday)
    expect(defaults.writes == noWrite && store.items.count == 4, "Blank additions cannot create or persist an item")

    store.toggle(original, on: friday)
    var current = store.items.first { $0.id == original.id }!
    expect(store.isComplete(current, on: friday), "Completion applies to selected date")
    expect(!store.isComplete(current, on: saturday), "Recurring completion does not leak to next date")
    store.toggle(current, on: saturday)
    current = store.items.first { $0.id == original.id }!
    expect(current.completedDayKeys == [20261009, 20261010], "Recurring item stores each completed date")
    store.toggle(current, on: friday)
    current = store.items.first { $0.id == original.id }!
    expect(!store.isComplete(current, on: friday) && store.isComplete(current, on: saturday), "Undo affects only its selected date")
    expect(!current.isComplete, "Legacy completed flag tracks start date only")

    let identity = current.id
    let order = current.order
    let created = current.createdAt
    let completion = current.completedDayKeys
    let changedCategory = UUID()
    store.update(current, title: "  Ἀλλαγή  ", detail: "  Νέο  ", kind: .other, customKind: "Σχολή",
                 cadence: DayPlanCadence(type: .weekdays, weekdays: [2, 6]), categoryID: changedCategory, colorID: "rose")
    current = store.items.first { $0.id == identity }!
    expect(current.id == identity && current.order == order && current.createdAt == created, "Edit retains identity, order and creation date")
    expect(current.completedDayKeys == completion, "Edit retains historical completion")
    expect(current.title == "Ἀλλαγή" && current.detail == "Νέο", "Edit trims revised text")
    expect(current.categoryID == changedCategory && current.colorID == "rose", "Edit replaces category and per-item colour")
    expect(current.cadence.type == .weekdays && current.cadence.weekdays == [2, 6], "Edit persists recurrence")
    expect(TodayDayPlanStore(defaults: defaults).items == store.items, "Edited identity, recurrence and completion survive reload")
    store.update(current, title: " ", detail: "", kind: .prayer, customKind: "", cadence: DayPlanCadence())
    expect(store.items.first { $0.id == identity } == current, "Blank edit cannot overwrite saved data")

    var publications = 0
    let subscription = store.$items.dropFirst().sink { _ in publications += 1 }
    let beforeMove = store.items(on: friday)
    let moving = beforeMove.last!
    let destination = beforeMove.first!
    let writeCount = defaults.writes
    store.move(moving.id, before: destination.id, on: friday)
    expect(publications == 1, "Reorder publishes exactly one new items array")
    expect(defaults.writes == writeCount + 1, "Reorder persists exactly once")
    expect(store.items(on: friday).first?.id == moving.id, "Reorder moves item to selected position")
    expect(Set(store.items.map(\.id)) == Set(beforeMove.map(\.id)), "Reorder neither loses nor duplicates items")
    expect(store.items.first { $0.id == identity }?.completedDayKeys == completion, "Reorder retains completion history")
    store.move(moving.id, before: moving.id, on: friday)
    expect(publications == 1, "No-op reorder does not publish")
    subscription.cancel()

    let goal = StreakGoal(id: UUID(), title: "Κοινός στόχος", subtitle: "Λεπτομέρειες")
    let beforeLink = store.items.first { $0.id == identity }!
    store.link(beforeLink, to: goal)
    let linked = store.items.first { $0.id == identity }!
    expect(linked.linkedGoalID == goal.id, "Promotion links to the existing goal identity")
    expect(linked.id == beforeLink.id && linked.order == beforeLink.order, "Promotion retains planner identity and position")
    expect(linked.completedDayKeys == completion && linked.cadence == beforeLink.cadence, "Promotion retains completion and schedule")
    expect(linked.categoryID == changedCategory && linked.colorID == "rose", "Promotion retains custom styling")

    let separate = TodayDayPlanStore(defaults: VolatileDefaults())
    separate.addLinkedGoal(goal, on: friday)
    separate.addLinkedGoal(goal, on: friday)
    expect(separate.items.count == 1, "Same goal cannot be linked twice on one date")
    separate.addLinkedGoal(goal, on: saturday)
    expect(separate.items.count == 2, "Same goal can be deliberately linked on another date")
    expect(separate.items.allSatisfy { $0.linkedGoalID == goal.id && $0.cadence.type == .once }, "Existing goals share their ID through date-specific planner entries")
    expect(separate.items(on: friday).count == 1 && separate.items(on: saturday).count == 1, "Goal link dates remain independent")
    separate.delete(separate.items[0])
    expect(separate.items.count == 1 && separate.items[0].linkedGoalID == goal.id, "Removing one link retains the other dated link")

    let corrupt = VolatileDefaults()
    corrupt.set(Data("not-json".utf8), forKey: key)
    expect(TodayDayPlanStore(defaults: corrupt).items.isEmpty, "Corrupt planner data fails safely")
    print("PASS: \(checks) day planner checks; no app preferences changed.")
}
`;

const cache = mkdtempSync(join(tmpdir(), 'klimax-day-planner-tests-'));
try {
    const result = spawnSync('xcrun', ['swift', '-module-cache-path', cache, '-'], {
        input: `${scaffolding}\n${progression.slice(cadenceStart, cadenceEnd)}\n${source.slice(start, end)}\n${tests}`,
        encoding: 'utf8',
        timeout: 120_000,
        maxBuffer: 2 * 1024 * 1024,
    });
    if (result.stdout) process.stdout.write(result.stdout);
    if (result.stderr) process.stderr.write(result.stderr);
    if (result.error) throw result.error;
    process.exitCode = result.status ?? 1;
} finally {
    rmSync(cache, { recursive: true, force: true });
}
