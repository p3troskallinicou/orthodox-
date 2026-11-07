//
//  ChapterReadingView.swift
//  Klimax
//
//  The reading surface — the most important screen in the app. A calm serif
//  column with a gilt versal numeral, quiet gold verse numbers, and a three-way
//  toggle: the original Greek (Ἀρχαῖα), the modern rendering (Νέα), or both at
//  once (Παράλληλα), with the modern line set beneath each verse for minimal
//  eye travel. Tap a verse to copy or share it. A bottom bar moves between
//  chapters or opens a jump grid. When a chapter has no modern text yet, the
//  toggle steps aside for a gentle note rather than a dead button.
//

import SwiftUI
import UIKit

private struct ScriptureScrollMetrics: Equatable {
    var offsetY: CGFloat
    var contentHeight: CGFloat
    var containerHeight: CGFloat
}

private func chapterSearchKey(_ text: String) -> String {
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

struct ChapterReadingView: View {
    @State private var route: ChapterRoute
    init(route: ChapterRoute) { _route = State(initialValue: route) }

    @Environment(ScriptureStore.self) private var store

    @AppStorage("scriptureReadModeRaw") private var modeRaw = ReadMode.ancient.rawValue
    @AppStorage("scriptureFontSize")    private var fontSize: Double = 21

    @State private var mode: ReadMode = .ancient
    @State private var selectedVerse: Int? = nil
    @State private var showChapters = false
    @State private var isSearchExpanded = false
    @State private var query = ""
    @State private var searchResults: [Int] = []
    @State private var currentSearchIndex: Int?
    @State private var activeSearchVerse: Int?
    @State private var noteDraft: NotebookSourceNoteDraft?
    @FocusState private var searchFieldFocused: Bool

    // Honest reading completion: reached the end after a short dwell, or dwelt on
    // a chapter short enough not to need scrolling.
    @State private var readStart = Date()
    @State private var readReachedBottom = false
    @State private var readContentFits = false
    @State private var readCounted = false

    private var book: Book?       { store.book(id: route.bookID) }
    private var chapter: Chapter? { store.chapter(route) }

    private enum ReadMode: String, CaseIterable, Identifiable {
        case ancient, modern, parallel
        var id: String { rawValue }
        var label: String {
            switch self { case .ancient: "Αρχαία"; case .modern: "Νέα"; case .parallel: "Παράλληλα" }
        }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Color.clear.frame(height: 1).id("top")
                    if let book, let chapter {
                        modeControl(chapter: chapter)
                        versalHeader(book: book, chapter: chapter)
                        VStack(alignment: .leading, spacing: 14) {
                            ForEach(chapter.verses) { verse in
                                verseBlock(verse, book: book, chapter: chapter)
                            }
                        }
                        .animation(.easeInOut(duration: 0.3), value: mode)
                    } else {
                        Text("Αυτό το κεφάλαιο δεν είναι ακόμη διαθέσιμο.")
                            .font(.system(size: 16, design: .serif))
                            .foregroundStyle(Paper.inkMute).padding(.top, 60)
                    }
                }
                .padding(.horizontal, 26)
                .padding(.top, 4)
                .padding(.bottom, 40)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .onChange(of: route) { _, _ in
                selectedVerse = nil
                collapseSearch()
                recordPosition()
                withAnimation(.easeInOut(duration: 0.2)) { proxy.scrollTo("top", anchor: .top) }
            }
            .onChange(of: activeSearchVerse) { _, verse in
                guard let verse else { return }
                withAnimation(.easeInOut(duration: 0.22)) {
                    proxy.scrollTo("verse-\(verse)", anchor: .center)
                }
            }
            .onScrollGeometryChange(for: ScriptureScrollMetrics.self) { geo in
                ScriptureScrollMetrics(
                    offsetY: geo.contentOffset.y,
                    contentHeight: geo.contentSize.height,
                    containerHeight: geo.containerSize.height
                )
            } action: { _, m in
                let distanceToBottom = m.contentHeight - (m.offsetY + m.containerHeight)
                readReachedBottom = distanceToBottom <= max(60, m.containerHeight * 0.10)
                readContentFits = m.contentHeight <= m.containerHeight + 1
            }
        }
        .background(Paper.bg.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                if let book {
                    Text(book.titleGreek.interfaceGreek)
                        .font(.system(size: 16, weight: .regular, design: .serif))
                        .foregroundStyle(Paper.ink)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 8) {
                    if !isSearchExpanded {
                        Button { expandSearch() } label: {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Paper.gold)
                                .frame(width: 38, height: 38)
                                .contentShape(Circle())
                                .klimaxLiquidGlass(in: Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Εύρεση στο κεφάλαιο")
                    }
                    sizeControl
                }
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if isSearchExpanded {
                inlineSearchBar
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.84), value: isSearchExpanded)
        .safeAreaInset(edge: .bottom) { chapterBar }
        .sheet(isPresented: $showChapters) { chapterJumpSheet }
        .sheet(item: $noteDraft) { draft in
            NotebookSourceNoteSheet(draft: draft)
                .presentationDetents([.medium, .large])
        }
        .onAppear {
            let stored = ReadMode(rawValue: modeRaw) ?? .ancient
            mode = (stored != .ancient && !(chapter?.hasModern ?? false)) ? .ancient : stored
            recordPosition()
        }
        .task(id: route) {
            readStart = Date()
            readReachedBottom = false
            readContentFits = false
            readCounted = false
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled || readCounted { break }
                let elapsed = Date().timeIntervalSince(readStart)
                let byScroll = readReachedBottom && elapsed >= 10
                let byDwell = readContentFits && elapsed >= 15
                if byScroll || byDwell {
                    readCounted = true
                    StreakStore.shared.record(.scripture, itemID: "\(route.bookID):\(route.chapterNumber)")
                    break
                }
            }
        }
        .onChange(of: mode) { _, _ in updateSearch() }
    }

    // MARK: - Mode control

    @ViewBuilder private func modeControl(chapter: Chapter) -> some View {
        if chapter.hasModern {
            HStack(spacing: 5) {
                ForEach(ReadMode.allCases) { m in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { mode = m }
                        modeRaw = m.rawValue
                    } label: {
                        Text(m.label)
                            .font(.system(size: 14, design: .serif))
                            .foregroundStyle(mode == m ? Paper.ink : Paper.inkMute)
                            .frame(maxWidth: .infinity).padding(.vertical, 7)
                            .background {
                                if mode == m {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(Paper.card)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
            .background(Paper.ink.opacity(0.05), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            .padding(.top, 6).padding(.bottom, 2)
        } else {
            HStack(spacing: 7) {
                Image(systemName: "hourglass").font(.system(size: 11, weight: .semibold))
                Text("Νεοελληνική μετάφραση — σύντομα")
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(Paper.inkMute)
            .padding(.vertical, 7).padding(.horizontal, 12)
            .klimaxLiquidGlass(in: Capsule(), interactive: false)
            .padding(.top, 6)
        }
    }

    // MARK: - Versal header

    private func versalHeader(book: Book, chapter: Chapter) -> some View {
        VStack(spacing: 6) {
            Text(book.titleEnglish.uppercased())
                .font(.system(size: 11, weight: .semibold)).tracking(3)
                .foregroundStyle(Paper.inkMute)
            Text("\(chapter.number)")
                .font(.system(size: 70, weight: .regular, design: .serif))
                .foregroundStyle(Paper.gold)
                .lineLimit(1)
            Capsule().fill(Paper.hairline).frame(width: 110, height: 1).padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 18).padding(.bottom, 18)
    }

    // MARK: - Verse

    @ViewBuilder private func verseBlock(_ verse: Verse, book: Book, chapter: Chapter) -> some View {
        let selected = selectedVerse == verse.number
        let searchSelected = activeSearchVerse == verse.number
        VStack(alignment: .leading, spacing: 5) {
            if mode == .modern {
                verseLine(number: verse.number, text: verse.modern ?? verse.ancient, primary: true)
            } else {
                verseLine(number: verse.number, text: verse.ancient, primary: true)
                if mode == .parallel, let m = verse.modern, !m.isEmpty {
                    verseLine(number: nil, text: m, primary: false)
                }
            }
            if selected { verseActions(verse, book: book, chapter: chapter) }
        }
        .padding(.vertical, 4).padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(selected ? Paper.gold.opacity(0.09) : (searchSelected ? Paper.gold.opacity(0.16) : .clear))
        )
        .contentShape(Rectangle())
        .id("verse-\(verse.number)")
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedVerse = selected ? nil : verse.number
            }
        }
    }

    private func verseLine(number: Int?, text: String, primary: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(number.map(String.init) ?? "")
                .font(.system(size: 12, weight: .semibold, design: .serif))
                .foregroundStyle(Paper.gold)
                .frame(minWidth: 18, alignment: .trailing)
                .baselineOffset(2)
            Text(text)
                .font(.system(size: primary ? fontSize : fontSize - 3,
                               weight: .regular, design: .serif))
                .italic(!primary)
                .foregroundStyle(primary ? Paper.ink : Paper.inkSoft)
                .lineSpacing(primary ? 7 : 5)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func verseActions(_ verse: Verse, book: Book, chapter: Chapter) -> some View {
        let primary = (mode == .modern) ? (verse.modern ?? verse.ancient) : verse.ancient
        let ref = "\(book.titleGreek) \(chapter.number):\(verse.number)"
        let share = "«\(primary)»\n— \(ref)"
        return HStack(spacing: 7) {
            Button {
                UIPasteboard.general.string = share
                withAnimation { selectedVerse = nil }
            } label: { actionLabel("Αντιγραφή", "doc.on.doc") }

            ShareLink(item: share) { actionLabel("Κοινοποίηση", "square.and.arrow.up") }

            Button {
                noteDraft = makeVerseNoteDraft(verse, book: book, chapter: chapter, text: primary)
                withAnimation { selectedVerse = nil }
            } label: { actionLabel("Σημείωση", "note.text.badge.plus") }
        }
        .padding(.top, 4)
        .padding(.leading, 22)
        .transition(.opacity)
    }

    private func makeVerseNoteDraft(_ verse: Verse, book: Book, chapter: Chapter, text: String) -> NotebookSourceNoteDraft {
        let reference = "\(book.titleGreek) \(chapter.number):\(verse.number)"
        return NotebookSourceNoteDraft(
            title: reference,
            category: .scripture,
            anchor: NotebookAnchor(
                kind: .scripture,
                title: reference,
                excerpt: text,
                routeValue: "\(book.id):\(chapter.number)",
                startTime: nil
            )
        )
    }

    private func actionLabel(_ title: String, _ icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 12, weight: .semibold))
            Text(title)
                .font(.system(size: 11.5, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.62)
        }
        .foregroundStyle(Paper.gold)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .padding(.horizontal, 8)
        .klimaxLiquidGlass(in: Capsule())
    }

    // MARK: - Find in chapter

    private var inlineSearchBar: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Paper.inkMute)

            TextField("Λέξη ή φράση", text: $query)
                .font(.system(size: 15))
                .foregroundStyle(Paper.ink)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($searchFieldFocused)
                .onChange(of: query) { _, _ in updateSearch() }

            if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(matchCounter)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(searchResults.isEmpty ? Paper.inkMute : Paper.inkSoft)
                    .fixedSize()

                Button { moveMatch(by: -1) } label: {
                    Image(systemName: "chevron.up")
                        .frame(width: 30, height: 30)
                        .contentShape(Rectangle())
                }
                .disabled(searchResults.isEmpty)

                Button { moveMatch(by: 1) } label: {
                    Image(systemName: "chevron.down")
                        .frame(width: 30, height: 30)
                        .contentShape(Rectangle())
                }
                .disabled(searchResults.isEmpty)
            }

            Button { collapseSearch() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .frame(width: 26, height: 26)
                    .contentShape(Circle())
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(Paper.inkSoft)
        .padding(.horizontal, 13)
        .frame(height: 44)
        .background(Paper.card, in: Capsule())
        .overlay(Capsule().stroke(Paper.hairline, lineWidth: 1))
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
    }

    private var matchCounter: String {
        guard !searchResults.isEmpty, let currentSearchIndex else { return "0 / 0" }
        return "\(currentSearchIndex + 1) / \(searchResults.count)"
    }

    private func expandSearch() {
        withAnimation { isSearchExpanded = true }
        DispatchQueue.main.async { searchFieldFocused = true }
    }

    private func collapseSearch() {
        searchFieldFocused = false
        query = ""
        searchResults = []
        currentSearchIndex = nil
        activeSearchVerse = nil
        withAnimation { isSearchExpanded = false }
    }

    private func updateSearch() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let chapter, !trimmed.isEmpty else {
            searchResults = []
            currentSearchIndex = nil
            activeSearchVerse = nil
            return
        }

        let needle = chapterSearchKey(trimmed)
        searchResults = chapter.verses.compactMap { verse in
            chapterSearchText(for: verse).contains(needle) ? verse.number : nil
        }
        currentSearchIndex = searchResults.isEmpty ? nil : 0
        activeSearchVerse = searchResults.first
    }

    private func moveMatch(by step: Int) {
        guard !searchResults.isEmpty else { return }
        let current = currentSearchIndex ?? 0
        let next = (current + step + searchResults.count) % searchResults.count
        currentSearchIndex = next
        activeSearchVerse = searchResults[next]
    }

    private func chapterSearchText(for verse: Verse) -> String {
        switch mode {
        case .ancient:
            return chapterSearchKey(verse.ancient)
        case .modern:
            return chapterSearchKey(verse.modern ?? verse.ancient)
        case .parallel:
            return chapterSearchKey("\(verse.ancient) \(verse.modern ?? "")")
        }
    }

    // MARK: - Bottom chapter bar

    private var chapterBar: some View {
        let count = book?.chapters.count ?? 0
        let n = route.chapterNumber
        return HStack {
            navButton(system: "chevron.left", enabled: n > 1) {
                route.chapterNumber = n - 1
            }
            Spacer()
            Button {
                showChapters = true
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "square.grid.2x2").font(.system(size: 13))
                    Text("Κεφάλαιο \(n)").font(.system(size: 15, design: .serif))
                }
                .foregroundStyle(Paper.ink)
            }
            Spacer()
            navButton(system: "chevron.right", enabled: n < count) {
                route.chapterNumber = n + 1
            }
        }
        .padding(.horizontal, 10).frame(height: 50)
        .klimaxLiquidGlass(in: RoundedRectangle(cornerRadius: 20, style: .continuous), interactive: false)
        .padding(.horizontal, 16).padding(.bottom, 6)
    }

    private func navButton(system: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(enabled ? Paper.ink : Paper.inkMute.opacity(0.3))
                .frame(width: 42, height: 42)
                .klimaxLiquidGlass(in: Circle(), selected: enabled)
        }
        .disabled(!enabled)
    }

    // MARK: - Chapter jump sheet

    private var chapterJumpSheet: some View {
        let cols = Array(repeating: GridItem(.flexible(), spacing: 10), count: 6)
        return VStack(spacing: 0) {
            Capsule().fill(Paper.ink.opacity(0.18)).frame(width: 38, height: 5).padding(.top, 10).padding(.bottom, 14)
            Text(book?.titleGreek ?? "")
                .font(.system(size: 21, weight: .regular, design: .serif))
                .foregroundStyle(Paper.ink)
            Text("ΜΕΤΑΒΑΣΗ ΣΕ ΚΕΦΑΛΑΙΟ")
                .font(.system(size: 10.5, weight: .semibold)).tracking(2)
                .foregroundStyle(Paper.inkMute).padding(.top, 2).padding(.bottom, 16)
            ScrollView {
                LazyVGrid(columns: cols, spacing: 10) {
                    ForEach(book?.chapters ?? []) { c in
                        let isCur = c.number == route.chapterNumber
                        let isRead = c.number < route.chapterNumber
                        Button {
                            route.chapterNumber = c.number
                            showChapters = false
                        } label: {
                            Text("\(c.number)")
                                .font(.system(size: 16, weight: .regular, design: .serif))
                                .foregroundStyle(isCur ? .white : (isRead ? Paper.gold : Paper.ink))
                                .minimumScaleFactor(0.6).lineLimit(1)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .aspectRatio(1, contentMode: .fit)
                                .background {
                                    if isCur {
                                        RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Paper.gold)
                                    } else if isRead {
                                        RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Paper.gold.opacity(0.11))
                                    }
                                }
                                .klimaxLiquidGlass(in: RoundedRectangle(cornerRadius: 14, style: .continuous), selected: isCur)
                        }
                        .buttonStyle(CalmCardStyle())
                    }
                }
                .padding(.horizontal, 20).padding(.bottom, 24)
            }
        }
        .background(Paper.bg)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
    }

    // MARK: - Helpers

    private var sizeControl: some View {
        HStack(spacing: 16) {
            Button { fontSize = max(15, fontSize - 2) } label: {
                Image(systemName: "textformat.size.smaller")
                    .frame(width: 34, height: 34)
                    .klimaxLiquidGlass(in: Circle())
            }
            Button { fontSize = min(30, fontSize + 2) } label: {
                Image(systemName: "textformat.size.larger")
                    .frame(width: 34, height: 34)
                    .klimaxLiquidGlass(in: Circle())
            }
        }
        .foregroundStyle(Paper.inkSoft)
    }

    private func recordPosition() {
        ReadingState.record(bookID: route.bookID, chapter: route.chapterNumber)
    }
}
