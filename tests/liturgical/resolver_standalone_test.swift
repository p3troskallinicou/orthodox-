import Foundation

enum GospelBook: String { case Matthew, Mark, Luke, John }
struct GospelRef { let book: GospelBook; let ref: String }
struct ApostleRef { let book: String; let ref: String }
enum ScripturePassageResolver {
    /// Γενικὴ ἀνάλυση περικοπῆς: δέχεται id βιβλίου (ὅπως στὸ scripture.json) + ref.
    static func text(forBookID bookID: String, ref: String, in bible: Bible) -> String? {
        let candidates = bookIDCandidates(bookID)
        guard let book = bible.testaments.flatMap(\.books)
                .first(where: { candidates.contains($0.id.lowercased()) }),
              let requests = parse(ref), !requests.isEmpty else { return nil }

        var output: [String] = []
        for request in requests {
            guard let chapter = book.chapters.first(where: { $0.number == request.chapter }) else { return nil }
            let verses = chapter.verses.filter { request.verses.contains($0.number) }
            let expectedCount = request.verses.upperBound == Int.max
                ? verses.count
                : request.verses.upperBound - request.verses.lowerBound + 1
            guard !verses.isEmpty, verses.count == expectedCount else { return nil }
            if requests.map(\.chapter).uniqued.count > 1 {
                output.append("\(book.titleGreek) \(request.chapter)")
            }
            output.append(contentsOf: verses.map { "\($0.number)  \($0.ancient)" })
        }
        return output.joined(separator: "\n")
    }

    /// Ἀνοχὴ στὸν τρόπο γραφῆς id ἀριθμημένων βιβλίων (π.χ. 1corinthians /
    /// firstcorinthians / icorinthians / 1_corinthians).
    private static func bookIDCandidates(_ id: String) -> Set<String> {
        let low = id.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        var out: Set<String> = [low]
        // Apostolic lectionaries may use long names, while scripture.json uses
        // compact canonical IDs. Keep short IDs and conventional aliases.
        let canonical: [String: String] = [
            "1corinthians": "1cor", "2corinthians": "2cor",
            "1timothy": "1tim", "2timothy": "2tim",
            "1thessalonians": "1thess", "2thessalonians": "2thess",
            "1chronicles": "1chron", "2chronicles": "2chron",
            "1maccabees": "1macc", "2maccabees": "2macc",
            "3maccabees": "3macc", "4maccabees": "4macc"
        ]
        let compact = low.replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: " ", with: "")
        let prefixes: [(String, [String])] = [
            ("1", ["first", "i", "a"]), ("2", ["second", "ii", "b"]),
            ("3", ["third", "iii", "c"])
        ]
        out.insert(compact)
        for (digit, words) in prefixes where compact.hasPrefix(digit) {
            let rest = String(compact.dropFirst())
            out.insert(digit + "_" + rest)
            for word in words {
                out.insert(word + rest)
                out.insert(word + "_" + rest)
            }
        }
        if let resolved = canonical[compact] { out.insert(resolved) }
        return out
    }

    static func text(for gospel: GospelRef, in bible: Bible) -> String? {
        let bookID: String
        switch gospel.book {
        case .Matthew: bookID = "matthew"
        case .Mark: bookID = "mark"
        case .Luke: bookID = "luke"
        case .John: bookID = "john"
        }
        // Greek ecclesiastical John 1:44–52 corresponds to the Bible corpus'
        // John 1:43–51; show the ecclesiastical verse numbers in the result.
        if gospel.book == .John && gospel.ref == "1:44-52" {
            guard let actual = text(forBookID: "john", ref: "1:43-51", in: bible) else { return nil }
            return actual.split(separator: "\n").enumerated().map { index, raw in
                guard let separator = raw.range(of: "  ") else { return String(raw) }
                return "\(44 + index)  \(raw[separator.upperBound...])"
            }.joined(separator: "\n")
        }
        return text(forBookID: bookID, ref: gospel.ref, in: bible)
    }

    static func text(for apostle: ApostleRef, in bible: Bible) -> String? {
        text(forBookID: apostle.book, ref: apostle.ref, in: bible)
    }

    private struct Request {
        let chapter: Int
        let verses: ClosedRange<Int>
    }

    private static func parse(_ raw: String) -> [Request]? {
        var requests: [Request] = []
        var currentChapter: Int?
        for group in raw.split(separator: ";") {
            for tokenValue in group.split(separator: ",") {
                let token = String(tokenValue).trimmingCharacters(in: .whitespaces)
                let sides = token.split(separator: "-", maxSplits: 1).map(String.init)
                let startParts = sides[0].split(separator: ":", maxSplits: 1).map(String.init)
                let startVerse: Int
                if startParts.count == 2 {
                    guard let chapter = Int(startParts[0]), let verse = Int(startParts[1]) else { return nil }
                    currentChapter = chapter; startVerse = verse
                } else {
                    guard currentChapter != nil, let verse = Int(startParts[0]) else { return nil }
                    startVerse = verse
                }
                guard let startChapter = currentChapter else { return nil }
                if sides.count == 1 {
                    requests.append(.init(chapter: startChapter, verses: startVerse...startVerse))
                    continue
                }
                let endParts = sides[1].split(separator: ":", maxSplits: 1).map(String.init)
                if endParts.count == 1 {
                    guard let endVerse = Int(endParts[0]), endVerse >= startVerse else { return nil }
                    requests.append(.init(chapter: startChapter, verses: startVerse...endVerse))
                } else {
                    guard let endChapter = Int(endParts[0]), let endVerse = Int(endParts[1]),
                          endChapter >= startChapter else { return nil }
                    for chapterNumber in startChapter...endChapter {
                        if chapterNumber == startChapter {
                            // A cross-chapter request needs the chapter's actual final verse;
                            // use a wide range and trim it against available data below.
                            requests.append(.init(chapter: chapterNumber, verses: startVerse...Int.max))
                        } else if chapterNumber == endChapter {
                            requests.append(.init(chapter: chapterNumber, verses: 1...endVerse))
                        } else {
                            requests.append(.init(chapter: chapterNumber, verses: 1...Int.max))
                        }
                    }
                    currentChapter = endChapter
                }
            }
        }
        return requests
    }
}

private extension Array where Element: Hashable {
    var uniqued: [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}


struct Check: Decodable { let kind: String; let book: String; let ref: String }
@main struct Main {
 static func main() throws {
  let root = URL(fileURLWithPath: CommandLine.arguments[1])
  let bible = try JSONDecoder().decode(Bible.self, from: Data(contentsOf: root.appendingPathComponent("scripture.json")))
  let all = try JSONDecoder().decode([Check].self, from: Data(contentsOf: root.appendingPathComponent("readings_test_input.json")))
  var failures: [String] = []
  for (i,r) in all.enumerated() {
   let text: String?
   if r.kind == "gospel" {
    guard let book = GospelBook(rawValue: r.book) else { fatalError("bad gospel book") }
    text = ScripturePassageResolver.text(for: GospelRef(book: book, ref: r.ref), in: bible)
   } else {text = ScripturePassageResolver.text(for: ApostleRef(book: r.book, ref: r.ref), in: bible)}
   if text == nil || text!.isEmpty { failures.append("\(i): \(r.book) \(r.ref)") }
   if r.kind == "gospel" && r.ref == "1:44-52" && r.book == "John" {
     guard let text, text.hasPrefix("44  "), text.contains("\n52  ") else {
       failures.append("Greek John verse numbering failed")
       continue
     }
   }
  }
  print("SWIFT RESOLVER: \(all.count - failures.count)/\(all.count) PASS")
  if !failures.isEmpty { for f in failures {print("ERROR \(f)")}; exit(1) }
 }
}
