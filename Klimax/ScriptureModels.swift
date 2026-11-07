//
//  ScriptureModels.swift
//  Klimax
//
//  The Bible as DATA. These types are deliberately shaped to match the shape
//  the content CMS will hand back later (Sanity / a JSON API), so when we move
//  from the bundled scripture.json to live content nothing here changes — only
//  where ScriptureStore fetches from.
//
//  Hierarchy:  Bible → Testament → Book → Chapter → Verse
//  A verse always has the original Greek (`ancient`); `modern` is optional,
//  because the modern translation arrives Testament-by-Testament (the New
//  Testament is bilingual now; the Old Testament is Ancient-only until the
//  modern Septuagint translation is licensed).
//

import Foundation

struct Bible: Codable, Hashable {
    var version: String
    var testaments: [Testament]
}

struct Testament: Codable, Hashable, Identifiable {
    var id: String          // "ot" | "nt"
    var titleGreek: String  // "Παλαιὰ Διαθήκη"
    var titleEnglish: String
    var books: [Book]
}

struct Book: Codable, Hashable, Identifiable {
    var id: String          // "john", "genesis"
    var titleGreek: String  // "Κατὰ Ἰωάννην"
    var titleEnglish: String
    var order: Int
    var chapters: [Chapter]

    /// How far through the book the reader is (0...1). Wired to real progress
    /// later (SwiftData/CloudKit); not part of the content payload.
    var progress: Double = 0

    private enum CodingKeys: String, CodingKey {
        case id, titleGreek, titleEnglish, order, chapters
    }
}

struct Chapter: Codable, Hashable, Identifiable {
    var number: Int
    var verses: [Verse]
    var id: Int { number }

    /// True when at least one verse carries a modern rendering — i.e. the
    /// Ancient↔Modern toggle has something to switch to.
    var hasModern: Bool { verses.contains { ($0.modern?.isEmpty == false) } }
}

struct Verse: Codable, Hashable, Identifiable {
    var number: Int
    var ancient: String     // original Greek (Patriarchal NT / Septuagint OT)
    var modern: String?     // modern Greek rendering, when available
    var id: Int { number }

    func text(in language: ScriptureLanguage) -> String {
        switch language {
        case .ancient: return ancient
        case .modern:  return modern ?? ancient
        }
    }
}

enum ScriptureLanguage: String, CaseIterable, Identifiable {
    case ancient
    case modern
    var id: String { rawValue }

    /// The label shown on the toggle, in Greek.
    var label: String {
        switch self {
        case .ancient: return "Αρχαία"
        case .modern:  return "Νέα"
        }
    }
}

/// A navigation value identifying one chapter inside a book.
struct ChapterRoute: Hashable {
    var bookID: String
    var chapterNumber: Int
}
