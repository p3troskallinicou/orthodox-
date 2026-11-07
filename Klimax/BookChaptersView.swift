//
//  BookChaptersView.swift
//  Klimax
//
//  A book opens to a proper "book screen", not a wall of identical numbers:
//  a header that places the book, a one-tap Continue, and the chapters as a
//  table of contents — each row carries the chapter's opening words, so every
//  chapter has an identity. A Grid view stays one tap away for fast jumps in
//  long books (Psalms). Read chapters are tinted; the current one is marked.
//
//  Navigation contract is unchanged: each chapter pushes a `ChapterRoute`.
//

import SwiftUI

private enum ChapterState { case unread, read, current }

private func scriptureChapterSearchKey(_ text: String) -> String {
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

struct BookChaptersView: View {
    let book: Book
    @Environment(ScriptureStore.self) private var store

    @AppStorage(ReadingState.lastBookKey)        private var lastBookID = ""
    @AppStorage(ReadingState.lastChapterKey)     private var lastChapter = 0
    @AppStorage("scriptureChapterViewMode")      private var viewMode = "list"   // "list" | "grid"
    @State private var query = ""

    private let gridCols = Array(repeating: GridItem(.flexible(), spacing: 11), count: 6)

    private var isCurrentBook: Bool { lastBookID == book.id }
    private var firstChapter: Int { book.chapters.first?.number ?? 1 }
    private var visibleChapters: [Chapter] {
        let needle = scriptureChapterSearchKey(query)
        guard !needle.isEmpty else { return book.chapters }
        return book.chapters.filter { chapter in
            if "\(chapter.number)".contains(needle) { return true }
            let chapterText = chapter.verses.map { "\($0.ancient) \($0.modern ?? "")" }.joined(separator: " ")
            return scriptureChapterSearchKey(chapterText).contains(needle)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                continueCard
                searchField
                modePicker
                if visibleChapters.isEmpty {
                    emptySearchState
                } else if viewMode == "grid" {
                    chapterGrid
                } else {
                    chapterList
                }
                Spacer(minLength: 28)
            }
            .padding(.horizontal, 22)
            .padding(.top, 4)
        }
        .background(Paper.bg.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(sectionTitle)
                .font(.system(size: 11, weight: .semibold)).tracking(3)
                .foregroundStyle(Paper.gold)
            Text(book.titleGreek.interfaceGreek)
                .font(.system(size: 33, weight: .regular, design: .serif))
                .foregroundStyle(Paper.ink)
                .lineLimit(2).minimumScaleFactor(0.7)
            Text("\(testamentGreek) · \(book.chapters.count) κεφάλαια")
                .font(.system(size: 13)).foregroundStyle(Paper.inkMute)
        }
        .padding(.top, 6).padding(.bottom, 2)
    }

    // MARK: Continue / Read primary action

    private var continueCard: some View {
        let target = (isCurrentBook && lastChapter > 0) ? lastChapter : firstChapter
        let resuming = isCurrentBook && lastChapter > 0
        return NavigationLink(value: ChapterRoute(bookID: book.id, chapterNumber: target)) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(resuming ? "ΣΥΝΕΧΕΙΑ" : "ΑΝΑΓΝΩΣΗ")
                        .font(.system(size: 10, weight: .semibold)).tracking(2.5)
                        .foregroundStyle(Paper.gold)
                    Text(resuming ? "Κεφάλαιο \(target)" : "Από την αρχή")
                        .font(.system(size: 21, weight: .regular, design: .serif))
                        .foregroundStyle(Paper.ink)
                }
                Spacer()
                ZStack {
                    Circle().fill(Paper.gold)
                    Image(systemName: "play.fill").font(.system(size: 14)).foregroundStyle(.white)
                }
                .frame(width: 40, height: 40)
                .shadow(color: Paper.gold.opacity(0.4), radius: 8, y: 3)
            }
            .padding(15)
            .klimaxLiquidGlass(in: RoundedRectangle(cornerRadius: 18, style: .continuous), selected: true)
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2).fill(Paper.gold)
                    .frame(width: 4).padding(.vertical, 12)
            }
        }
        .buttonStyle(CalmCardStyle())
        .padding(.top, 16)
    }

    // MARK: Search

    private var searchField: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Paper.inkMute.opacity(0.8))
            TextField("Εύρεση στο βιβλίο…", text: $query)
                .font(.system(size: 15))
                .foregroundStyle(Paper.ink)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Paper.inkMute.opacity(0.5))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 12).padding(.horizontal, 14)
        .background(Paper.card, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).stroke(Paper.hairline, lineWidth: 1))
        .padding(.top, 14)
    }

    private var emptySearchState: some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 26))
                .foregroundStyle(Paper.gold.opacity(0.75))
            Text("Δεν βρέθηκε κεφάλαιο")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Paper.ink)
            Text("Δοκίμασε άλλη λέξη ή φράση.")
                .font(.footnote)
                .foregroundStyle(Paper.inkMute)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 34)
    }

    // MARK: List / Grid switch

    private var modePicker: some View {
        HStack(spacing: 5) {
            modeButton("Λίστα", "list")
            modeButton("Πλέγμα", "grid")
        }
        .padding(4)
        .background(Paper.ink.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.top, 18).padding(.bottom, 6)
    }

    private func modeButton(_ title: String, _ value: String) -> some View {
        Button { withAnimation(.easeInOut(duration: 0.18)) { viewMode = value } } label: {
            Text(title)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(viewMode == value ? Paper.ink : Paper.inkMute)
                .frame(maxWidth: .infinity).padding(.vertical, 8)
                .background {
                    if viewMode == value {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(Paper.card)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    // MARK: Table of contents (list)

    private var chapterList: some View {
        LazyVStack(spacing: 2) {
            ForEach(visibleChapters) { chapter in
                NavigationLink(value: ChapterRoute(bookID: book.id, chapterNumber: chapter.number)) {
                    TOCRow(number: chapter.number,
                           incipit: chapter.verses.first?.ancient ?? "",
                           state: state(chapter.number))
                }
                .buttonStyle(CalmCardStyle())
            }
        }
    }

    // MARK: Grid

    private var chapterGrid: some View {
        LazyVGrid(columns: gridCols, spacing: 11) {
            ForEach(visibleChapters) { chapter in
                NavigationLink(value: ChapterRoute(bookID: book.id, chapterNumber: chapter.number)) {
                    GridCell(number: chapter.number, state: state(chapter.number))
                }
                .buttonStyle(CalmCardStyle())
            }
        }
        .padding(.top, 2)
    }

    // MARK: Helpers

    private func state(_ n: Int) -> ChapterState {
        guard isCurrentBook else { return .unread }
        if n == lastChapter { return .current }
        if n < lastChapter  { return .read }
        return .unread
    }

    private var testament: Testament? {
        store.testaments.first { $0.books.contains { $0.id == book.id } }
    }
    private var testamentGreek: String { testament?.titleGreek ?? "" }

    private var sectionTitle: String {
        let t = testament?.id ?? "ot"
        if t == "ot" {
            switch book.order {
            case 1...5:   return "ΠΕΝΤΑΤΕΥΧΟΣ"
            case 6...23:  return "ΙΣΤΟΡΙΚΑ"
            case 24...31: return "ΠΟΙΗΤΙΚΑ & ΣΟΦΙΑΣ"
            default:      return "ΠΡΟΦΗΤΕΣ"
            }
        } else {
            switch book.order {
            case 1...4:   return "ΕΥΑΓΓΕΛΙΑ"
            case 5:       return "ΠΡΑΞΕΙΣ"
            case 6...26:  return "ΕΠΙΣΤΟΛΕΣ"
            default:      return "ΑΠΟΚΑΛΥΨΙΣ"
            }
        }
    }
}

// MARK: - Table-of-contents row

private struct TOCRow: View {
    let number: Int
    let incipit: String
    let state: ChapterState

    var body: some View {
        HStack(spacing: 13) {
            Text("\(number)")
                .font(.system(size: 15, weight: .regular, design: .serif))
                .foregroundStyle(markFg)
                .frame(width: 34, height: 34)
                .background(Circle().fill(markBg))
                .overlay(Circle().stroke(state == .unread ? Paper.hairline : .clear, lineWidth: 1))
            Text(incipit)
                .font(.system(size: 16.5, weight: .regular, design: .serif))
                .foregroundStyle(state == .read ? Paper.inkSoft : Paper.ink)
                .lineLimit(1).truncationMode(.tail)
            Spacer(minLength: 6)
            if state == .current {
                Text("ΤΩΡΑ")
                    .font(.system(size: 9, weight: .bold)).tracking(1.5)
                    .foregroundStyle(Paper.gold)
            }
        }
        .padding(.vertical, 9).padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(state == .current ? Paper.gold.opacity(0.10) : .clear)
        )
        .contentShape(Rectangle())
    }

    private var markFg: Color {
        switch state { case .current: return .white; case .read: return Paper.gold; case .unread: return Paper.ink }
    }
    private var markBg: Color {
        switch state { case .current: return Paper.gold; case .read: return Paper.gold.opacity(0.14); case .unread: return Paper.card }
    }
}

// MARK: - Grid cell

private struct GridCell: View {
    let number: Int
    let state: ChapterState

    var body: some View {
        Text("\(number)")
            .font(.system(size: 17, weight: .regular, design: .serif))
            .foregroundStyle(fg)
            .minimumScaleFactor(0.6)
            .lineLimit(1)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .background {
                if state == .current {
                    RoundedRectangle(cornerRadius: 15, style: .continuous).fill(Paper.gold)
                } else if state == .read {
                    RoundedRectangle(cornerRadius: 15, style: .continuous).fill(Paper.gold.opacity(0.11))
                }
            }
            .klimaxLiquidGlass(in: RoundedRectangle(cornerRadius: 15, style: .continuous), selected: state == .current)
            .contentShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
    }

    private var fg: Color {
        switch state { case .current: return .white; case .read: return Paper.gold; case .unread: return Paper.ink }
    }
}
