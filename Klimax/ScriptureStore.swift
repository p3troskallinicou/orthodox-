//
//  ScriptureStore.swift
//  Klimax
//
//  The single source of Scripture for the app.
//
//  The complete Scripture corpus is bundled with the app and displayed first.
//  Sanity remains an optional editorial refresh; it is never required to open a
//  book or chapter on a clean installation.
//

import Foundation
import Observation

@Observable
final class ScriptureStore {
    private(set) var bible: Bible?
    private(set) var isLoading = false
    private(set) var loadError: String?

    var testaments: [Testament] { bible?.testaments ?? [] }

    // MARK: - Sanity project (Klimax)
    private static let projectID = "uqaka7yh"
    private static let dataset   = "production"

    // MARK: - Loading

    func load() async {
        guard bible == nil else { return }
        isLoading = true
        defer { isLoading = false }

        // 1) Publish the complete bundled Bible before awaiting the network.
        do {
            self.bible = try Self.loadBundled()
            self.loadError = nil
        } catch {
            self.loadError = "Could not load Scripture: \(error.localizedDescription)"
        }

        // 2) Prefer a previous editorial refresh only when it is at least as
        // complete as the bundled corpus. Old partial caches must never shrink
        // the offline library.
        if let cached = Self.loadCache(), Self.hasContent(cached),
           Self.contentScore(cached) >= Self.contentScore(bible) {
            self.bible = cached
            self.loadError = nil
        }

        // 3) Refresh opportunistically. Airplane mode leaves the local Bible
        // fully usable and does not produce an error state.
        do {
            let live = try await Self.fetchFromSanity()
            if Self.hasContent(live),
               Self.contentScore(live) >= Self.contentScore(bible) {
                self.bible = live
                self.loadError = nil
                Self.saveCache(live)
            }
        } catch {
            if bible == nil {
                self.loadError = "Could not load Scripture: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Sources

    /// One GROQ query that returns the whole Bible already shaped like `Bible`.
    private static func fetchFromSanity() async throws -> Bible {
        let groq = """
        {"version":"sanity-live","testaments":[\
        {"id":"ot","titleGreek":"Παλαιὰ Διαθήκη","titleEnglish":"Old Testament",\
        "books":*[_type=="book"&&testament=="ot"]|order(order){"id":bookId,titleGreek,titleEnglish,order,chapters}},\
        {"id":"nt","titleGreek":"Καινὴ Διαθήκη","titleEnglish":"New Testament",\
        "books":*[_type=="book"&&testament=="nt"]|order(order){"id":bookId,titleGreek,titleEnglish,order,chapters}}\
        ]}
        """
        let unreserved = CharacterSet(charactersIn:
            "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        let encoded = groq.addingPercentEncoding(withAllowedCharacters: unreserved) ?? ""
        guard let url = URL(string:
            "https://\(projectID).apicdn.sanity.io/v2021-06-07/data/query/\(dataset)?query=\(encoded)")
        else { throw URLError(.badURL) }

        var req = URLRequest(url: url)
        req.timeoutInterval = 30
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(SanityResponse.self, from: data).result
    }

    private struct SanityResponse: Decodable { let result: Bible }

    private static func loadBundled() throws -> Bible {
        guard let url = Bundle.main.url(forResource: "scripture", withExtension: "json") else {
            throw NSError(domain: "Klimax", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "scripture.json not found in bundle"])
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(Bible.self, from: data)
    }

    // MARK: - On-device cache (Caches directory)

    private static var cacheURL: URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
            .first?.appendingPathComponent("klimax-scripture-cache.json")
    }

    private static func saveCache(_ bible: Bible) {
        guard let url = cacheURL, let data = try? JSONEncoder().encode(bible) else { return }
        try? data.write(to: url, options: .atomic)
    }

    private static func loadCache() -> Bible? {
        guard let url = cacheURL, let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(Bible.self, from: data)
    }

    private static func hasContent(_ bible: Bible) -> Bool {
        bible.testaments.contains { !$0.books.isEmpty }
    }

    private static func contentScore(_ bible: Bible?) -> Int {
        guard let bible else { return 0 }
        return bible.testaments.reduce(0) { testamentTotal, testament in
            testamentTotal + testament.books.reduce(0) { bookTotal, book in
                bookTotal + book.chapters.reduce(0) { $0 + $1.verses.count }
            }
        }
    }

    // MARK: - Lookups (unchanged)

    func book(id: String) -> Book? {
        for t in testaments { if let b = t.books.first(where: { $0.id == id }) { return b } }
        return nil
    }

    func chapter(_ route: ChapterRoute) -> Chapter? {
        book(id: route.bookID)?.chapters.first { $0.number == route.chapterNumber }
    }

    /// A single verse to feature on the Today screen ("verse of the day").
    /// Stable for a given day so it doesn't flicker on every launch.
    func verseOfTheDay() -> (book: Book, chapter: Chapter, verse: Verse)? {
        let verseCount = Self.contentScore(bible)
        guard verseCount > 0 else { return nil }
        let day = Calendar.current.ordinality(of: .day, in: .era, for: Date()) ?? 0
        var remaining = day % verseCount
        // Skip whole chapters instead of allocating a tuple for every verse
        // each time a Today card or phone widget refreshes.
        for testament in testaments {
            for book in testament.books {
                for chapter in book.chapters {
                    if remaining < chapter.verses.count {
                        return (book, chapter, chapter.verses[remaining])
                    }
                    remaining -= chapter.verses.count
                }
            }
        }
        return nil
    }

    /// Where the reader should resume. Hardcoded to the opening of John for now;
    /// becomes real reading-position state (SwiftData/CloudKit) later.
    func continueReading() -> ChapterRoute? {
        if book(id: "john") != nil { return ChapterRoute(bookID: "john", chapterNumber: 1) }
        if let first = testaments.first?.books.first {
            return ChapterRoute(bookID: first.id, chapterNumber: first.chapters.first?.number ?? 1)
        }
        return nil
    }
}
