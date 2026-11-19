// Exercise the actual Codable models and source factory without app preferences.
import {readFileSync, writeFileSync, mkdtempSync, rmSync} from 'node:fs';
import {spawnSync} from 'node:child_process';
import {tmpdir} from 'node:os';
import {join, resolve} from 'node:path';

const profile = readFileSync('Klimax/ProfileView.swift', 'utf8');
const library = readFileSync('Klimax/NotebookLibrary.swift', 'utf8');
const models = profile.slice(profile.indexOf('enum NotebookCategory:'), profile.indexOf('@MainActor\nfinal class NotebookStore:'));
const factory = library.slice(library.indexOf('extension NotebookAnchor {'), library.indexOf('/// A source keeps'));
const catalog = readFileSync('Klimax/SaintSayings.swift', 'utf8');
const temp = mkdtempSync(join(tmpdir(), 'klimax-notebook-tests-'));
const source = `import SwiftUI
import Foundation
enum Paper { static let gold = Color.brown }
enum Gild { static let accentForeground = Color.brown }
struct ChapterRoute { let bookID: String; let chapterNumber: Int }
${models}
${catalog}
${factory}
` + String.raw`
func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else { fatalError(message) }
}
let decoder = JSONDecoder()
let encoder = JSONEncoder()
let originalKinds = ["scripture", "gerontikon", "didaches", "prayer", "personal"]
for kind in originalKinds {
    let id = UUID().uuidString, anchorID = UUID().uuidString
    // Legacy notes predate endTime, audioUrl and contextTitle; all must still load.
    let fixture: [String: Any] = ["id": id, "title": "Παλιά σημείωση", "body": "Η δική μου σκέψη",
        "category": kind, "createdAt": 100, "updatedAt": 200,
        "anchors": [["id": anchorID, "kind": kind, "title": "Πηγή", "excerpt": "Αυτούσιο απόσπασμα", "routeValue": "john:3"]]]
    let data = try JSONSerialization.data(withJSONObject: fixture)
    let note = try decoder.decode(NotebookNote.self, from: data)
    expect(note.id.uuidString == id, "Legacy note identity changed")
    expect(note.anchors[0].id.uuidString == anchorID, "Legacy source identity changed")
    expect(note.body == "Η δική μου σκέψη", "Legacy text changed")
    expect(note.anchors[0].audioUrl == nil, "Missing optional field must stay nil")
    expect(try! decoder.decode(NotebookNote.self, from: encoder.encode(note)) == note, "Legacy round trip lost data")
    if kind == "scripture" {
        expect(note.anchors[0].scriptureRoute?.bookID == "john", "Scripture book lost")
        expect(note.anchors[0].scriptureRoute?.chapterNumber == 3, "Scripture chapter lost")
    }
}
let catalog = try decoder.decode(SaintSayingsCatalog.self, from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])))
for saying in catalog.sayings {
    let anchor = NotebookAnchor.saintSaying(saying, catalog: catalog)
    var note = NotebookNote.blank(category: .saintSayings)
    note.title = anchor.cleanTitle
    note.body = "Η σκέψη μου"
    note.anchors = [anchor]
    let restored = try decoder.decode(NotebookNote.self, from: encoder.encode(note))
    expect(restored == note, "New source round trip lost data")
    expect(restored.anchors[0].excerpt == saying.text, "Quote text changed")
    let destination = catalog.collection(saintID: saying.saintID).first { $0.id == restored.anchors[0].routeValue }
    expect(destination?.id == saying.id, "Source opens a different quote")
    expect(restored.anchors[0].title == catalog.saint(for: saying).shortName, "Saint attribution lost")
}
var removed = NotebookAnchor(kind: .saintSayings, title: "Άγιος", excerpt: "Αποθηκευμένο κείμενο", routeValue: "retired-quote")
expect(!catalog.sayings.contains { $0.id == removed.routeValue }, "Retired ID unexpectedly resolves")
expect(try! decoder.decode(NotebookAnchor.self, from: encoder.encode(removed)).excerpt == removed.excerpt, "Unavailable source must keep its text")
let homily = NotebookAnchor(kind: .didaches, title: "Ομιλία", excerpt: "Απόσπασμα", routeValue: "homily-1", startTime: 43, endTime: 58, audioUrl: "https://example.com/audio.mp3", contextTitle: "Προσευχή")
expect(try! decoder.decode(NotebookAnchor.self, from: encoder.encode(homily)) == homily, "Audio clip timing or URL lost")
print("PASS: legacy note compatibility, \(catalog.sayings.count) exact saying destinations, saved excerpts and audio clip round trips")
`;
try {
    const file = join(temp, 'main.swift');
    writeFileSync(file, source);
    const result = spawnSync('swift', ['-module-cache-path', join(temp, 'cache'), file, resolve('Klimax/saint-sayings.json')], {encoding: 'utf8'});
    process.stdout.write(result.stdout || '');
    process.stderr.write(result.stderr || '');
    if (result.status !== 0) process.exitCode = result.status || 1;
} finally { rmSync(temp, {recursive: true, force: true}); }
