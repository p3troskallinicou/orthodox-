//
//  ScriptureLibraryView.swift
//  Klimax
//
//  The front door to Scripture, redesigned for fast navigation across 79 books:
//  a search field, a "Continue" card and "Recent" row for the 90% case, an
//  Old/New Testament selector, and books grouped under their traditional
//  sections as compact two-column rows — instead of one long scroll of cards.
//
//  Navigation contract is unchanged: tapping a book pushes `Book`
//  (→ BookChaptersView); the Continue card pushes a `ChapterRoute`
//  (→ ChapterReadingView). RootView needs no edits.
//

import SwiftUI

// MARK: - Tiny reading-history store (shared with the reader)
//
// Backed by UserDefaults so it survives launches and, being @AppStorage-keyed,
// refreshes the Library automatically when the reader records a new position.
// This becomes real per-chapter progress (SwiftData/CloudKit) later.
enum ReadingState {
    static let lastBookKey    = "rs.lastBookID"
    static let lastChapterKey = "rs.lastChapter"
    static let recentsKey     = "rs.recentBookIDs"   // comma-separated ids

    static func record(bookID: String, chapter: Int) {
        let d = UserDefaults.standard
        d.set(bookID, forKey: lastBookKey)
        d.set(chapter, forKey: lastChapterKey)
        var ids = (d.string(forKey: recentsKey) ?? "")
            .split(separator: ",").map(String.init)
            .filter { $0 != bookID }
        ids.insert(bookID, at: 0)
        d.set(ids.prefix(8).joined(separator: ","), forKey: recentsKey)
    }
}

struct ScriptureLibraryView: View {
    @Environment(ScriptureStore.self) private var store

    @AppStorage(ReadingState.lastBookKey)    private var lastBookID = ""
    @AppStorage(ReadingState.lastChapterKey) private var lastChapter = 0
    @AppStorage(ReadingState.recentsKey)     private var recentsCSV = ""

    @State private var testamentID = ""        // resolved on appear
    @State private var query = ""
    @State private var verseSearchIndex: [VerseSearchIndexEntry] = []
    @State private var verseSearchResults: [VerseSearchHit] = []
    @State private var isVerseSearchLoading = false
    @State private var isBuildingVerseIndex = false
    @State private var searchTask: Task<Void, Never>?
    @State private var indexTask: Task<Void, Never>?

    private let cols = [GridItem(.flexible(), spacing: 9), GridItem(.flexible(), spacing: 9)]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                header
                    .logosBlockRise(0)
                searchField
                    .logosBlockRise(1)

                if store.isLoading && store.testaments.isEmpty {
                    ProgressView().tint(Paper.gold)
                        .frame(maxWidth: .infinity).padding(.top, 60)
                } else if !query.isEmpty {
                    searchResults
                        .logosBlockRise(2)
                } else {
                    if let card = continueTarget {
                        continueCard(card.0, card.1)
                            .logosBlockRise(2)
                    }
                    recentsRow
                        .logosBlockRise(3)
                    testamentBar
                        .logosBlockRise(4)
                    sections
                }

                Spacer(minLength: 24)
            }
            .padding(.horizontal, 20)
            .padding(.top, 82)
        }
        .background(Color.clear)
        .onAppear {
            resolveTestament()
        }
        .onChange(of: store.testaments.count) { _, _ in
            resolveTestament()
            if !query.isEmpty {
                rebuildVerseSearchIndex()
            }
        }
        .onChange(of: query) { _, newValue in
            if newValue.isEmpty {
                scheduleVerseSearch(newValue)
            } else if verseSearchIndex.isEmpty {
                rebuildVerseSearchIndex()
            } else {
                scheduleVerseSearch(newValue)
            }
        }
    }

    // MARK: Header + search

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("ΑΓΙΑ ΓΡΑΦΗ")
                .font(.system(size: 12, weight: .semibold)).tracking(4)
                .foregroundStyle(Paper.gold)
            Text("Αγία Γραφή")
                .font(.system(size: 34, weight: .regular, design: .serif))
                .foregroundStyle(Paper.ink)
        }
        .padding(.top, 14)
        .padding(.horizontal, 4)
    }

    private var searchField: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Paper.inkMute.opacity(0.8))
            TextField("Βιβλίο ή φράση…  π.χ. Ψαλμοί, αγάπη", text: $query)
                .font(.system(size: 15))
                .foregroundStyle(Paper.ink)
                .autocorrectionDisabled()
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Paper.inkMute.opacity(0.5))
                }
            }
        }
        .padding(.vertical, 12).padding(.horizontal, 14)
        .background(Paper.card, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).stroke(Paper.hairline, lineWidth: 1))
    }

    // MARK: Continue + recents

    /// Last position the reader recorded, else the store's default.
    private var continueTarget: (Book, ChapterRoute)? {
        if !lastBookID.isEmpty, let b = store.book(id: lastBookID) {
            return (b, ChapterRoute(bookID: lastBookID, chapterNumber: max(1, lastChapter)))
        }
        if let r = store.continueReading(), let b = store.book(id: r.bookID) { return (b, r) }
        return nil
    }

    private func continueCard(_ book: Book, _ route: ChapterRoute) -> some View {
        NavigationLink(value: route) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("ΣΥΝΕΧΕΙΑ")
                        .font(.system(size: 10, weight: .semibold)).tracking(2.5)
                        .foregroundStyle(Paper.gold)
                    Text("\(book.titleGreek.interfaceGreek) \(route.chapterNumber)")
                        .font(.system(size: 23, weight: .regular, design: .serif))
                        .foregroundStyle(Paper.ink)
                    Text(book.titleEnglish)
                        .font(.system(size: 12)).foregroundStyle(Paper.inkMute)
                    if book.progress > 0 {
                        ProgressBar(fraction: book.progress).frame(height: 4).padding(.top, 6)
                    }
                }
                Spacer()
                ZStack {
                    Circle().fill(Paper.gold)
                    Image(systemName: "play.fill").font(.system(size: 14)).foregroundStyle(.white)
                }
                .frame(width: 40, height: 40)
                .shadow(color: Paper.gold.opacity(0.4), radius: 8, y: 3)
            }
            .padding(16)
            .klimaxLiquidGlass(in: RoundedRectangle(cornerRadius: 20, style: .continuous), selected: true)
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Paper.gold).frame(width: 4)
                    .padding(.vertical, 14)
            }
        }
        .buttonStyle(CalmCardStyle())
    }

    @ViewBuilder private var recentsRow: some View {
        let recents = recentsCSV.split(separator: ",").map(String.init).compactMap { store.book(id: $0) }
        if !recents.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("ΠΡΟΣΦΑΤΑ")
                    .font(.system(size: 10.5, weight: .semibold)).tracking(3)
                    .foregroundStyle(Paper.inkMute).padding(.horizontal, 4)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 9) {
                        ForEach(recents) { book in
                            NavigationLink(value: book) {
                                Text(book.titleGreek.interfaceGreek)
                                    .font(.system(size: 15, design: .serif))
                                    .foregroundStyle(Paper.ink)
                                    .padding(.vertical, 7).padding(.horizontal, 15)
                                    .background(Paper.card, in: Capsule())
                                    .overlay(Capsule().stroke(Paper.hairline, lineWidth: 1))
                                    .contentShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
            .padding(.top, 2)
        }
    }

    // MARK: Testament selector + sections

    private var testamentBar: some View {
        HStack(spacing: 0) {
            ForEach(store.testaments) { t in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { testamentID = t.id }
                } label: {
                    Text(t.titleGreek.interfaceGreek)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(testamentID == t.id ? Paper.ink : Paper.inkMute)
                        .frame(maxWidth: .infinity).padding(.vertical, 9)
                        .background {
                            if testamentID == t.id {
                                RoundedRectangle(cornerRadius: 11, style: .continuous)
                                    .fill(Paper.card)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Paper.ink.opacity(0.055), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.top, 4)
    }

    private struct BookSection: Identifiable { let id: String; let books: [Book] }

    @ViewBuilder private var sections: some View {
        if let testament = store.testaments.first(where: { $0.id == testamentID }) {
            ForEach(groupedSections(testament)) { section in
                VStack(alignment: .leading, spacing: 9) {
                    Text(section.id)
                        .font(.system(size: 10.5, weight: .semibold)).tracking(3)
                        .foregroundStyle(Paper.gold)
                        .padding(.horizontal, 4).padding(.top, 16)
                    LazyVGrid(columns: cols, spacing: 9) {
                        ForEach(section.books) { book in
                            NavigationLink(value: book) { BookCell(book: book) }
                                .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    // MARK: Search

    @ViewBuilder private var searchResults: some View {
        let bookResults = store.testaments.flatMap(\.books).filter { bookMatches($0, query) }
        if bookResults.isEmpty && verseSearchResults.isEmpty && !isVerseSearchLoading {
            Text("Κανένα βιβλίο ή χωρίο δεν ταιριάζει με «\(query)».")
                .font(.system(size: 15, design: .serif))
                .foregroundStyle(Paper.inkMute)
                .frame(maxWidth: .infinity, alignment: .center).padding(.top, 50)
        } else {
            VStack(alignment: .leading, spacing: 18) {
                if !bookResults.isEmpty {
                    VStack(alignment: .leading, spacing: 9) {
                        Text("ΒΙΒΛΙΑ")
                            .font(.system(size: 10.5, weight: .semibold)).tracking(3)
                            .foregroundStyle(Paper.gold)
                            .padding(.horizontal, 4)
                        LazyVGrid(columns: cols, spacing: 9) {
                            ForEach(bookResults) { book in
                                NavigationLink(value: book) { BookCell(book: book) }
                                    .buttonStyle(.plain)
                            }
                        }
                    }
                }

                if isVerseSearchLoading && verseSearchResults.isEmpty {
                    ProgressView()
                        .tint(Paper.gold)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 16)
                }

                if !verseSearchResults.isEmpty {
                    VStack(alignment: .leading, spacing: 9) {
                        Text("ΣΤΙΧΟΙ")
                            .font(.system(size: 10.5, weight: .semibold)).tracking(3)
                            .foregroundStyle(Paper.gold)
                            .padding(.horizontal, 4)
                        LazyVStack(spacing: 9) {
                            ForEach(verseSearchResults) { hit in
                                NavigationLink(value: hit.route) { VerseHitCell(hit: hit) }
                                    .buttonStyle(CalmCardStyle())
                            }
                        }
                    }
                }
            }
            .padding(.top, 6)
        }
    }

    // MARK: Helpers

    private func resolveTestament() {
        guard testamentID.isEmpty || !store.testaments.contains(where: { $0.id == testamentID }) else { return }
        if !lastBookID.isEmpty,
           let t = store.testaments.first(where: { $0.books.contains { $0.id == lastBookID } }) {
            testamentID = t.id
        } else {
            testamentID = store.testaments.first?.id ?? "ot"
        }
    }

    private func bookMatches(_ book: Book, _ q: String) -> Bool {
        let needle = scriptureSearchKey(q)
        guard !needle.isEmpty else { return false }
        return scriptureSearchKey(book.titleGreek).contains(needle)
            || scriptureSearchKey(book.titleEnglish).contains(needle)
    }

    private func rebuildVerseSearchIndex() {
        guard !isBuildingVerseIndex, !store.testaments.isEmpty else { return }
        indexTask?.cancel()
        isBuildingVerseIndex = true
        isVerseSearchLoading = true
        let snapshot: [VerseSearchSnapshot] = store.testaments.flatMap { testament in
            testament.books.flatMap { book in
                book.chapters.flatMap { chapter in
                    chapter.verses.map { verse in
                        VerseSearchSnapshot(
                            bookID: book.id,
                            bookTitle: book.titleGreek,
                            chapter: chapter.number,
                            verse: verse.number,
                            ancient: verse.ancient,
                            modern: verse.modern ?? ""
                        )
                    }
                }
            }
        }

        indexTask = Task {
            let index = await Task.detached(priority: .utility) {
                snapshot.map { item in
                    VerseSearchIndexEntry(
                        hit: VerseSearchHit(
                            id: "\(item.bookID)-\(item.chapter)-\(item.verse)",
                            bookID: item.bookID,
                            bookTitle: item.bookTitle,
                            chapter: item.chapter,
                            verse: item.verse,
                            text: item.ancient
                        ),
                        ancientText: item.ancient,
                        modernText: item.modern,
                        ancientKey: scriptureSearchKey(item.ancient),
                        modernKey: scriptureSearchKey(item.modern)
                    )
                }
            }.value

            guard !Task.isCancelled else {
                isBuildingVerseIndex = false
                return
            }
            verseSearchIndex = index
            isBuildingVerseIndex = false
            scheduleVerseSearch(query)
        }
    }

    private func scheduleVerseSearch(_ q: String) {
        searchTask?.cancel()
        let needle = scriptureSearchKey(q)
        guard !needle.isEmpty else {
            verseSearchResults = []
            isVerseSearchLoading = false
            return
        }

        let index = verseSearchIndex
        isVerseSearchLoading = true

        searchTask = Task {
            try? await Task.sleep(nanoseconds: 160_000_000)
            guard !Task.isCancelled else { return }

            let results = await Task.detached(priority: .userInitiated) {
                var hits: [VerseSearchHit] = []
                for entry in index {
                    let ancientMatches = entry.ancientKey.contains(needle)
                    let modernMatches = entry.modernKey.contains(needle)
                    guard ancientMatches || modernMatches else { continue }

                    let displayText = modernMatches && !ancientMatches ? entry.modernText : entry.ancientText
                    hits.append(entry.hit.withText(displayText))
                    if hits.count >= 80 { return hits }
                }
                return hits
            }.value

            guard !Task.isCancelled else { return }
            verseSearchResults = results
            isVerseSearchLoading = false
        }
    }

    /// Walks a testament's (already-ordered) books and splits them into the
    /// traditional sections by canonical order.
    private func groupedSections(_ testament: Testament) -> [BookSection] {
        var out: [BookSection] = []
        var current = ""
        var bucket: [Book] = []
        func flush() { if !bucket.isEmpty { out.append(BookSection(id: current, books: bucket)) } }
        for b in testament.books {
            let s = sectionTitle(order: b.order, testament: testament.id)
            if s != current { flush(); current = s; bucket = [b] }
            else { bucket.append(b) }
        }
        flush()
        return out
    }

    private func sectionTitle(order: Int, testament: String) -> String {
        if testament == "ot" {
            switch order {
            case 1...5:   return "ΠΕΝΤΑΤΕΥΧΟΣ"
            case 6...23:  return "ΙΣΤΟΡΙΚΑ"
            case 24...31: return "ΠΟΙΗΤΙΚΑ & ΣΟΦΙΑΣ"
            default:      return "ΠΡΟΦΗΤΕΣ"
            }
        } else {
            switch order {
            case 1...4:   return "ΕΥΑΓΓΕΛΙΑ"
            case 5:       return "ΠΡΑΞΕΙΣ"
            case 6...26:  return "ΕΠΙΣΤΟΛΕΣ"
            default:      return "ΑΠΟΚΑΛΥΨΙΣ"
            }
        }
    }
}

// MARK: - Compact book cell (two-column grid)

private struct VerseSearchHit: Identifiable, Sendable {
    let id: String
    let bookID: String
    let bookTitle: String
    let chapter: Int
    let verse: Int
    let text: String

    var route: ChapterRoute { ChapterRoute(bookID: bookID, chapterNumber: chapter) }
    var reference: String { "\(bookTitle) \(chapter):\(verse)" }

    func withText(_ text: String) -> VerseSearchHit {
        VerseSearchHit(id: id, bookID: bookID, bookTitle: bookTitle, chapter: chapter, verse: verse, text: text)
    }
}

private struct VerseSearchSnapshot: Sendable {
    let bookID: String
    let bookTitle: String
    let chapter: Int
    let verse: Int
    let ancient: String
    let modern: String
}

private struct VerseSearchIndexEntry: Sendable {
    let hit: VerseSearchHit
    let ancientText: String
    let modernText: String
    let ancientKey: String
    let modernKey: String
}

private func scriptureSearchKey(_ text: String) -> String {
    let folded = text
        .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "el"))
        .lowercased()
        .replacingOccurrences(of: "ς", with: "σ")

    var out = ""
    var lastWasSpace = false
    for ch in folded {
        if ch.isLetter || ch.isNumber {
            out.append(ch)
            lastWasSpace = false
        } else if !lastWasSpace {
            out.append(" ")
            lastWasSpace = true
        }
    }
    return out.trimmingCharacters(in: .whitespacesAndNewlines)
}

private struct BookCell: View {
    let book: Book
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(book.titleGreek.interfaceGreek)
                .font(.system(size: 16, weight: .regular, design: .serif))
                .foregroundStyle(Paper.ink)
                .lineLimit(2).minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
            Text("\(book.chapters.count) κεφ.")
                .font(.system(size: 11)).foregroundStyle(Paper.inkMute)
        }
        .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
        .padding(.vertical, 11).padding(.horizontal, 13)
        .scriptureStaticSurface(cornerRadius: 14)
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct VerseHitCell: View {
    let hit: VerseSearchHit

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "quote.opening")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Paper.gold)
                .frame(width: 24, height: 24)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 5) {
                Text(hit.reference)
                    .font(.system(size: 11, weight: .semibold)).tracking(1.2)
                    .foregroundStyle(Paper.gold)
                Text(hit.text)
                    .font(.system(size: 15, design: .serif))
                    .foregroundStyle(Paper.ink)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 4)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Paper.inkMute.opacity(0.65))
                .padding(.top, 6)
        }
        .padding(14)
        .scriptureStaticSurface(cornerRadius: 15)
    }
}

private extension View {
    func scriptureStaticSurface(cornerRadius: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return background(
            shape.fill(
                LinearGradient(
                    colors: [
                        Paper.card,
                        Paper.card.opacity(0.82)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        )
        .overlay(shape.stroke(Paper.hairline, lineWidth: 1))
    }
}
