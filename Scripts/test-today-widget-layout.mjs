import fs from 'node:fs';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';

const source = fs.readFileSync('Klimax/TodayView.swift', 'utf8');
const start = source.indexOf('private struct TodayWidgetMetrics {');
const end = source.indexOf('private struct TodayWidgetRowLayout:', start);
assert.ok(start >= 0 && end > start);
const model = source.slice(start, end);
const program = `import Foundation
${model}
let fixtures: [(Double, Double, Double, Double, Double, Double)] = [
 (320,568,141,292,141,311), (375,667,148,321,148,324),
 (375,812,155,329,155,345), (390,844,158,338,158,354),
 (393,852,158,338,158,354), (414,736,159,348,157,357),
 (414,896,169,360,169,379), (428,926,170,364,170,382),
 (430,932,170,364,170,382)
]
for f in fixtures {
 for landscape in [false, true] {
  let screen = CGSize(width: landscape ? f.1 : f.0, height: landscape ? f.0 : f.1)
  let m = TodayWidgetMetrics.resolve(screen: screen, availableWidth: f.0)
  precondition(m.small == f.2 && m.medium == f.3 && m.mediumHeight == f.4 && m.largeHeight == f.5)
  precondition(abs(2 * m.small + m.gap - m.medium) < 0.001)
  for width in [0.0, 200.0, 280.0, 600.0] {
   let scaled = TodayWidgetMetrics.resolve(screen: screen, availableWidth: width)
   precondition(scaled.medium <= width + 0.0001 && scaled.gap >= -0.0001)
   precondition(scaled.largeHeight >= scaled.mediumHeight)
  }
 }
}
print("PASS: 9 Apple iPhone profiles, rotation, constrained widths and large/medium geometry.")
`;
const result = spawnSync('swift', ['-module-cache-path', '/tmp/klimax-interface-greek-module-cache', '-'], {input: program, encoding: 'utf8'});
assert.equal(result.status, 0, result.stderr || result.stdout);
console.log(result.stdout.trim());
for (const token of ['@AppStorage("today.widgetLayout.v3")', 'case wide', 'player.toggle()', 'player.open(homily', 'FastingCalendarView(date: selectedDate)', 'startIndex: selectedIndex', '.allowsHitTesting(!isEditingDashboard)', '.frame(width: geometry.size.width, height: geometry.size.height)']) {
 assert.ok(source.includes(token), token);
}
console.log('PASS: saved-layout compatibility, isolated editing controls and interactive routes remain wired.');
const fasting = source.slice(source.indexOf('private func todayFastingWidget'), source.indexOf('private func fastingMiniDayButton'));
assert.ok(!fasting.includes('level.shortName'), 'Small fasting cards must state the rule, not a vague legend abbreviation.');
assert.ok(!fasting.includes('if size == .large { Spacer'), 'Large fasting cards must not stretch a blank spacer.');
assert.ok(fasting.includes('fastingMonthGrid(selectedDate: selectedDate)'));
assert.ok(fasting.includes('ForEach(0..<cells'), 'The large calendar must include the full month.');
assert.ok(source.includes('.sheet(isPresented: $showWidgetGallery)'), 'The gallery must be a separate modal.');
assert.ok(!source.includes('if isEditingDashboard { return true }'), 'Removed widgets must leave the editing board.');
assert.ok(source.includes('private struct WidgetResizeHandle'));
assert.ok(source.includes('widgets.append(TodayWidgetConfig(id: id, size: size))'));
for (const label of ['Χωρίς νηστεία', 'Χωρίς κρέας', 'Επιτρέπεται ψάρι', 'Λάδι και κρασί', 'Ξηροφαγία']) {
 assert.ok(fasting.includes(label), `Missing complete fasting label: ${label}`);
}
console.log('PASS: full-month fasting calendar, popup gallery, removal and corner resize wiring.');
const boardStart = source.indexOf('private struct TodayWidgetBoardLayout: Layout {');
const boardEnd = source.indexOf('    func sizeThatFits(', boardStart);
const board = source.slice(boardStart, boardEnd)
 .replace('private struct TodayWidgetBoardLayout: Layout {', 'struct TodayWidgetBoardLayout {')
 .replaceAll('UIScreen.main.bounds.size', 'CGSize(width: 393, height: 852)') + '\n}';
const boardProgram = `import Foundation
import CoreGraphics
enum TodayWidgetSize { case small, wide, large }
${model}
${board}
let choices: [TodayWidgetSize] = [.small, .wide, .large]
for pattern in 0..<729 {
 var code = pattern
 var sizes: [TodayWidgetSize] = []
 for _ in 0..<6 { sizes.append(choices[code % 3]); code /= 3 }
 let frames = TodayWidgetBoardLayout(sizes: sizes, spacing: 20).frames(width: 353)
 precondition(frames.count == sizes.count)
 for i in frames.indices {
  precondition(frames[i].minX >= 0 && frames[i].maxX <= 353)
  for j in frames.indices where j > i { precondition(!frames[i].intersects(frames[j])) }
 }
}
print("PASS: 729 mixed-size board layouts remain in bounds and do not overlap.")
`;
const boardResult = spawnSync('swift', ['-module-cache-path', '/tmp/klimax-interface-greek-module-cache', '-'], {input: boardProgram, encoding: 'utf8'});
assert.equal(boardResult.status, 0, boardResult.stderr || boardResult.stdout);
console.log(boardResult.stdout.trim());
assert.ok(source.includes('WidgetGalleryPreview(title: id.title'));
assert.ok(source.includes('.updating($swipe)'));
assert.ok(source.includes('switch startingSize ?? size'));
const reorder = source.slice(source.indexOf('private struct ReorderModifier:'), source.indexOf('private struct WidgetFramePreference:'));
assert.ok(reorder.indexOf('widgets.insert(moved') < reorder.indexOf('.onEnded'), 'Reorder must happen during the drag, not on release.');
console.log('PASS: swipe previews, stable resize origin and in-drag reorder wiring.');
assert.ok(reorder.includes('@Binding var boardFrame: CGRect'), 'Editing must read current geometry through a binding, not a frozen frame snapshot.');
assert.ok(source.includes('.onGeometryChange(for: CGRect.self)'), 'The board must measure its actual on-screen bounds.');
assert.ok(source.includes('Rectangle().fill(Color.clear).contentShape(Rectangle())'), 'Editing needs a touch surface independent of disabled widget links.');
assert.ok(!source.includes('NSLog("WIDGETDRAG'), 'Temporary drag diagnostics must not ship.');
console.log('PASS: live board geometry, independent edit touch surface and clean diagnostics.');
