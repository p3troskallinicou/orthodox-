import fs from 'node:fs';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';

// Exercise the production display helper, not a second implementation.
const theme = fs.readFileSync('Klimax/Theme.swift', 'utf8');
const helper = theme.slice(theme.indexOf('extension String {'), theme.indexOf('extension Color {'));
const cases = [
  ['Ἁγία Γραφή', 'Αγία Γραφή'],
  ['Ἡ ἡμέρα σου', 'Η ημέρα σου'],
  ['Τὸ πρόγραμμά σου', 'Το πρόγραμμά σου'],
  ['Προσευχὴ καὶ μελέτη', 'Προσευχή και μελέτη'],
  ['Ἀποθήκευση ἀλλαγῶν', 'Αποθήκευση αλλαγών'],
  ['Ἡ κατηγορία παραμένει ἡ ἴδια', 'Η κατηγορία παραμένει η ίδια'],
  ['Χρῶμα', 'Χρώμα'],
  ['Βιβλίο ἢ φράση', 'Βιβλίο ή φράση'],
  ['Ποῦ; Πῶς;', 'Πού; Πώς;'],
  ['ἐκεῖ ποὺ ἔμεινες', 'εκεί που έμεινες'],
  ['Μωϋσῆς', 'Μωϋσής'],
  ['Οἰκογένεια', 'Οικογένεια'],
  ['ΑΛΗΘΕΣ Ἢ ΨΕΥΔΕΣ', 'ΑΛΗΘΕΣ Ή ΨΕΥΔΕΣ'],
  ['  Ἄκουσε\nτώρα! 🎧', '  Άκουσε\nτώρα! 🎧'],
  ['Athos Audio · 1×', 'Athos Audio · 1×']
];
const literal = s => JSON.stringify(s).replaceAll('\\n', '\\n');
const checks = cases.map(([input, expected]) =>
  `precondition(${literal(input)}.interfaceGreek == ${literal(expected)}, ${literal(input)})`
).join('\n');
const run = spawnSync('swift', ['-module-cache-path', '/tmp/klimax-interface-greek-module-cache', '-'], {
  input: `import Foundation\n${helper}\n${checks}\nprint("${cases.length} Greek display tests passed")\n`,
  encoding: 'utf8'
});
assert.equal(run.status, 0, run.stderr || run.stdout);
console.log(run.stdout.trim());

// Sacred passages and raw catalogue matching must remain outside the helper.
for (const file of ['ChapterReadingView', 'PrayerSection', 'LiturgicalServiceView']) {
  const source = fs.readFileSync(`Klimax/${file}.swift`, 'utf8');
  assert.ok(!/(?:ancient|textEl|cleanExcerpt|prayer\.text)\.interfaceGreek/.test(source), file);
}
console.log('Sacred-text display guards passed');
