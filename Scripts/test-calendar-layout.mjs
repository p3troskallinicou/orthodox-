import fs from 'node:fs';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';

const source = fs.readFileSync('Klimax/FastingCalendarView.swift', 'utf8');
const model = source.slice(source.indexOf('enum CalendarMonthLayout {'), source.indexOf('struct CalendarDayIndicator {'));
const tests = String.raw`
import Foundation
enum Paschalion {
    static let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()
}
${model}
var months = 0
for zone in ["UTC", "Europe/Nicosia"] {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: zone)!
    for year in 2020...2032 {
        for month in 1...12 {
            let anchor = calendar.date(from: DateComponents(year: year, month: month, day: 15))!
            let cells = CalendarMonthLayout.cells(for: anchor, calendar: calendar)
            let dates = cells.compactMap { $0 }
            let count = calendar.range(of: .day, in: .month, for: anchor)!.count
            precondition(cells.count % 7 == 0 && (28...42).contains(cells.count))
            precondition(dates.count == count && Set(dates).count == count)
            precondition(dates.map { calendar.component(.day, from: $0) } == Array(1...count))
            for (index, date) in cells.enumerated() {
                if let date {
                    precondition(index % 7 == (calendar.component(.weekday, from: date) + 5) % 7)
                    precondition(calendar.component(.month, from: date) == month)
                }
            }
            let last = dates.last!
            let next = calendar.date(byAdding: .month, value: 1, to: CalendarMonthLayout.start(of: anchor, calendar: calendar))!
            let chosen = CalendarMonthLayout.selection(in: next, preserving: last, calendar: calendar)
            precondition(calendar.isDate(chosen, equalTo: next, toGranularity: .month))
            precondition(calendar.component(.day, from: chosen) == min(count, calendar.range(of: .day, in: .month, for: next)!.count))
            precondition(CalendarMonthLayout.label(last, format: "d", calendar: calendar) == String(count))
            months += 1
        }
    }
    let leap = calendar.date(from: DateComponents(year: 2024, month: 2, day: 29))!
    precondition(CalendarMonthLayout.cells(for: leap, calendar: calendar).compactMap { $0 }.count == 29)
}
print("PASS: \(months) month layouts, Monday alignment, leap years, month-end selection and both calendar time zones.")
`;
const run = spawnSync('swift', ['-module-cache-path', '/tmp/klimax-interface-greek-module-cache', '-'], { input: tests, encoding: 'utf8' });
assert.equal(run.status, 0, run.stderr || run.stdout);
console.log(run.stdout.trim());
const feast = fs.readFileSync('Klimax/OrthodoxFeastCalendarView.swift', 'utf8');
for (const component of ['LiturgicalMonthCalendar(', 'CalendarDayAgenda(', 'CalendarAgendaRow(', 'CalendarTodayButton(', 'CalendarScreenStyle(']) {
    assert.ok(source.includes(component) && feast.includes(component), component);
}
assert.ok(feast.includes('selectedDate = date'));
assert.ok(!feast.includes('selectFirstUsefulDay'));
console.log('PASS: both calendars share all five visual components; search selection is not overwritten.');
