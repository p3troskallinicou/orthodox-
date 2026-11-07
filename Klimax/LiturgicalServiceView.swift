//
//  LiturgicalServiceView.swift
//  Klimax
//

import SwiftUI

private struct GospelDisplayLine: Identifiable {
    enum Kind { case header, chapter, verse, text }
    let id: Int
    let text: String
    let kind: Kind
    let startOffset: Int
    let contentOffset: Int
    var verseNumber: String? = nil
    var verseText: String? = nil
    var displayText: String { verseText ?? text }
}

struct LiturgicalServicesLibraryView: View {
    var topPadding: CGFloat = 8
    private var targetSunday: Date { LiturgicalDate.nextSunday(from: Date()) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Ακολουθίες")
                        .font(.system(size: 30, weight: .regular, design: .serif)).foregroundStyle(Paper.ink)
                    Text("Λατρευτικές ακολουθίες της Εκκλησίας")
                        .font(.system(size: 13, design: .serif)).italic().foregroundStyle(Paper.inkMute)
                }.padding(.vertical, 12)

                NavigationLink {
                    DivineLiturgyView(date: targetSunday)
                } label: {
                    serviceRow(icon: "cross.fill", title: "Θεία Λειτουργία",
                               subtitle: "Θεία Λειτουργία της Κυριακής", enabled: true)
                }.buttonStyle(.plain)

                serviceRow(icon: "sun.horizon.fill", title: "Όρθρος",
                           subtitle: "Χωριστό Εωθινό Ευαγγέλιο · κείμενο σε προετοιμασία", enabled: false)
                serviceRow(icon: "sunset.fill", title: "Εσπερινός",
                           subtitle: "Δομημένο placeholder για μελλοντική προσθήκη", enabled: false)
                serviceRow(icon: "book.closed.fill", title: "Προηγιασμένη",
                           subtitle: "Μελλοντική καθημερινή ακολουθία της Σαρακοστής", enabled: false)
            }
            .padding(.horizontal, 20).padding(.top, topPadding).padding(.bottom, 32)
        }
    }

    private func serviceRow(icon: String, title: String, subtitle: String, enabled: Bool) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(Paper.gold.opacity(0.12)).frame(width: 46, height: 46)
                Image(systemName: icon).font(.system(size: 18)).foregroundStyle(Paper.gold)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 19, design: .serif)).foregroundStyle(Paper.ink)
                Text(subtitle).font(.system(size: 12)).foregroundStyle(Paper.inkMute).lineLimit(2)
            }
            Spacer()
            if enabled {
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Paper.inkMute.opacity(0.6))
            } else {
                Text("ΣΥΝΤΟΜΑ").font(.system(size: 9, weight: .bold)).tracking(1).foregroundStyle(Paper.inkMute)
            }
        }
        .padding(16)
        .background(Paper.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Paper.hairline, lineWidth: 1))
    }
}

struct DivineLiturgyView: View {
    // Ἡ ἐπιλεγμένη προβλεπόμενη τέλεση τοῦ ἐτήσιου Τυπικοῦ.
    @State private var selectedDate: Date
    @State private var showDatePicker = false
    @State private var pickerDraft = Date()

    @Environment(ScriptureStore.self) private var scripture
    @State private var package: SundayServicePackage?
    @State private var schedules: [LiturgicalYearSchedule] = []
    @State private var loadError: String?
    @State private var isSearchExpanded = false
    @State private var query = ""
    @State private var searchResults: [ServiceSearchResult] = []
    @State private var currentMatchIndex: Int?
    @State private var selectedResult: ServiceSearchResult?
    @FocusState private var searchFieldFocused: Bool

    init(date: Date) {
        _selectedDate = State(initialValue: date)
    }

    private var liturgyDates: [Date] {
        schedules.flatMap { $0.entries(for: .divineLiturgy) }
            .compactMap { Self.keyFormatter.date(from: $0.date) }
            .sorted()
    }

    private var selectedScheduleEntry: LiturgicalYearEntry? {
        let key = Self.keyFormatter.string(from: selectedDate)
        return schedules.lazy.flatMap(\.entries).first { $0.date == key && $0.divineLiturgy }
    }

    var body: some View {
        ZStack {
            Paper.bg.ignoresSafeArea()
            if let package {
                serviceContent(package)
            } else if let loadError {
                ContentUnavailableView("Η ακολουθία δεν φορτώθηκε", systemImage: "exclamationmark.triangle",
                                       description: Text(loadError))
            } else {
                ProgressView().tint(Paper.gold)
            }
        }
        .navigationTitle("Θεία Λειτουργία")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if package != nil && !isSearchExpanded {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { expandSearch() } label: {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Paper.gold)
                            .frame(width: 38, height: 38)
                            .contentShape(Circle())
                            .glassCircleFallback(shape: Circle())
                    }
                    .buttonStyle(.plain)
                        .accessibilityLabel("Αναζήτηση στη Θεία Λειτουργία")
                }
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if isSearchExpanded, let service = package?.services.divineLiturgy {
                inlineSearchBar(service)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.84), value: isSearchExpanded)
        .sheet(isPresented: $showDatePicker) { datePickerSheet }
        .task(id: scripture.bible?.version) { load() }
        .onChange(of: selectedDate) { _, _ in
            collapseSearch()
            load()
        }
    }

    // MARK: - Ἐπιλογέας ἡμερομηνίας

    private var dateNavigationBar: some View {
        HStack(spacing: 10) {
            stepButton(systemName: "chevron.left") { step(by: -1) }
            Button { openDatePicker() } label: {
                HStack(spacing: 7) {
                    Image(systemName: "calendar")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Paper.gold)
                    Text(Self.greekDate(selectedDate))
                        .font(.system(size: 14, weight: .medium, design: .serif))
                        .foregroundStyle(Paper.ink)
                        .lineLimit(1).minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .padding(.horizontal, 14)
                .background(Paper.card, in: Capsule())
                .overlay(Capsule().stroke(Paper.hairline, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Επιλογή ημερομηνίας")
            stepButton(systemName: "chevron.right") { step(by: 1) }
        }
    }

    private func stepButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Paper.gold)
                .frame(width: 40, height: 40)
                .background(Paper.card, in: Circle())
                .overlay(Circle().stroke(Paper.hairline, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var datePickerSheet: some View {
        NavigationStack {
            VStack(spacing: 18) {
                DatePicker("Ημερομηνία", selection: $pickerDraft, in: liturgyDateRange, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .tint(Paper.gold)
                    .padding(.horizontal, 8)

                Text("Θα εμφανιστεί η πλησιέστερη Θεία Λειτουργία που προβλέπει το Τυπικό:\n\(Self.greekDate(closestLiturgyDate(to: pickerDraft) ?? pickerDraft))")
                    .font(.system(size: 12, design: .serif))
                    .foregroundStyle(Paper.inkMute)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)

                Button { pickerDraft = closestLiturgyDate(to: Date()) ?? selectedDate } label: {
                    Text("Πλησιέστερη τέλεση")
                        .font(.system(size: 14, weight: .medium, design: .serif))
                        .foregroundStyle(Paper.gold)
                }
                Spacer()
            }
            .padding(.top, 12)
            .background(Paper.bg.ignoresSafeArea())
            .navigationTitle("Επιλογή ημερομηνίας")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Άκυρο") { showDatePicker = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Τέλος") {
                        selectedDate = closestLiturgyDate(to: pickerDraft) ?? selectedDate
                        showDatePicker = false
                    }.fontWeight(.semibold)
                }
            }
            .presentationDetents([.large])
        }
    }

    private func openDatePicker() {
        pickerDraft = selectedDate
        showDatePicker = true
    }

    private func step(by offset: Int) {
        guard let index = liturgyDates.firstIndex(where: { Calendar.current.isDate($0, inSameDayAs: selectedDate) }) else { return }
        let target = index + offset
        guard liturgyDates.indices.contains(target) else { return }
        selectedDate = liturgyDates[target]
    }

    private func closestLiturgyDate(to date: Date) -> Date? {
        liturgyDates.min { abs($0.timeIntervalSince(date)) < abs($1.timeIntervalSince(date)) }
    }

    private var liturgyDateRange: ClosedRange<Date> {
        let first = liturgyDates.first ?? Self.keyFormatter.date(from: "2026-01-01")!
        let last = liturgyDates.last ?? Self.keyFormatter.date(from: "2026-12-31")!
        return first...last
    }

    private static let greekFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "el_GR")
        f.setLocalizedDateFormatFromTemplate("EEEEdMMMMyyyy")
        return f
    }()

    private static func greekDate(_ date: Date) -> String {
        greekFormatter.string(from: date)
    }

    private static let keyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private func serviceContent(_ package: SundayServicePackage) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    dateNavigationBar

                    VStack(alignment: .leading, spacing: 7) {
                        Text(package.sunday.titleEl)
                            .font(.system(size: 27, design: .serif)).foregroundStyle(Paper.ink)
                        Text(package.services.divineLiturgy.titleEl)
                            .font(.system(size: 14, design: .serif)).foregroundStyle(Paper.inkMute)
                        if let selectedScheduleEntry {
                            Text("Τυπική Διάταξη \(String(selectedScheduleEntry.date.prefix(4))) · \(selectedScheduleEntry.title)")
                                .font(.system(size: 12, design: .serif)).foregroundStyle(Paper.inkMute)
                        }
                        Text("Ευαγγέλιον: \(package.services.divineLiturgy.gospel.displayEl)")
                            .font(.system(size: 13, weight: .semibold)).foregroundStyle(Paper.gold)
                    }
                    Rectangle().fill(Paper.gold.opacity(0.45)).frame(width: 52, height: 1.5)

                    ForEach(package.warnings, id: \.self) { warning in
                        Label(warning, systemImage: "info.circle")
                            .font(.system(size: 12)).foregroundStyle(Paper.inkMute)
                            .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                            .background(Paper.gold.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                    }

                    ForEach(package.services.divineLiturgy.sections) { section in
                        VStack(alignment: .leading, spacing: 14) {
                            Text(section.titleEl.uppercased())
                                .font(.system(size: 12, weight: .semibold, design: .serif))
                                .tracking(1.5).foregroundStyle(Paper.gold)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.top, 12).padding(.bottom, 2)
                            ForEach(section.blocks) { block in
                                let activeResult = selectedResult?.blockId == block.id ? selectedResult : nil
                                liturgyBlock(
                                    block,
                                    result: activeResult
                                )
                                .id(block.id)
                                .overlay(alignment: .topLeading) {
                                    if let activeResult {
                                        searchMatchAnchor(activeResult, textLength: block.textEl.count)
                                    }
                                }
                            }
                        }
                        .id(section.id)
                    }
                }
                .padding(.horizontal, 24).padding(.top, 14).padding(.bottom, 48)
            }
            .onChange(of: selectedResult) { _, result in
                guard let result else { return }
                // The match anchor is inserted by the same state update. Wait
                // one run-loop turn so ScrollViewReader can discover its ID.
                DispatchQueue.main.async {
                    withAnimation(.easeInOut(duration: 0.24)) {
                        proxy.scrollTo(result.id, anchor: .center)
                    }
                }
            }
        }
    }

    private func inlineSearchBar(
        _ service: SundayServicePackage.DivineLiturgyService
    ) -> some View {
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
                .onChange(of: query) { _, _ in updateSearch(in: service) }

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
                .accessibilityLabel("Προηγούμενο αποτέλεσμα")

                Button { moveMatch(by: 1) } label: {
                    Image(systemName: "chevron.down")
                        .frame(width: 30, height: 30)
                        .contentShape(Rectangle())
                }
                .disabled(searchResults.isEmpty)
                .accessibilityLabel("Επόμενο αποτέλεσμα")
            }

            Button { collapseSearch() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .frame(width: 26, height: 26)
                    .contentShape(Circle())
            }
            .accessibilityLabel("Κλείσιμο αναζήτησης")
        }
        .buttonStyle(.plain)
        .foregroundStyle(Paper.inkSoft)
        .padding(.horizontal, 13)
        .frame(height: 44)
        // This is a container with its own controls; the glass surface itself
        // must not consume taps intended for the arrow buttons or text field.
        .glassCircleFallback(shape: Capsule(), interactive: false)
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
    }

    private func searchMatchAnchor(_ result: ServiceSearchResult, textLength: Int) -> some View {
        GeometryReader { geometry in
            let fraction = textLength > 0
                ? min(1, max(0, Double(result.startOffset) / Double(textLength)))
                : 0
            VStack(spacing: 0) {
                Color.clear.frame(height: max(0, geometry.size.height * fraction - 1))
                Color.clear.frame(width: 1, height: 1).id(result.id)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .allowsHitTesting(false)
    }

    private var matchCounter: String {
        guard !searchResults.isEmpty, let currentMatchIndex else { return "0 / 0" }
        return "\(currentMatchIndex + 1) / \(searchResults.count)"
    }

    private func expandSearch() {
        withAnimation { isSearchExpanded = true }
        DispatchQueue.main.async { searchFieldFocused = true }
    }

    private func collapseSearch() {
        searchFieldFocused = false
        query = ""
        searchResults = []
        currentMatchIndex = nil
        selectedResult = nil
        withAnimation { isSearchExpanded = false }
    }

    private func updateSearch(in service: SundayServicePackage.DivineLiturgyService) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            searchResults = []
            currentMatchIndex = nil
            selectedResult = nil
            return
        }
        searchResults = ServiceSearch.search(service, query: trimmed)
        currentMatchIndex = searchResults.isEmpty ? nil : 0
        selectedResult = searchResults.first
    }

    private func moveMatch(by step: Int) {
        guard !searchResults.isEmpty else { return }
        let current = currentMatchIndex ?? 0
        let next = (current + step + searchResults.count) % searchResults.count
        currentMatchIndex = next
        selectedResult = searchResults[next]
    }

    @ViewBuilder
    private func liturgyBlock(_ block: AssembledServiceBlock, result: ServiceSearchResult?) -> some View {
        if block.id.hasSuffix("-gospel") || block.textEl.hasPrefix("Εὐαγγέλιον:") {
            gospelBlock(block.textEl, result: result)
        } else if block.kind == .rubric {
            highlightedText(block.textEl, result: result)
                .font(.system(size: 14, design: .serif)).italic()
                .foregroundStyle(Paper.inkMute)
                .lineSpacing(5)
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)
                .padding(.vertical, 5)
                .textSelection(.enabled)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                if let speaker = block.speaker {
                    Text(speaker.uppercased())
                        .font(.system(size: 10, weight: .semibold, design: .serif)).tracking(1.2)
                        .foregroundStyle(Paper.gold)
                }
                highlightedText(block.textEl, result: result)
                    .font(.system(size: 19, design: .serif))
                    .foregroundStyle(Paper.ink).lineSpacing(8)
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 5)
        }
    }

    private func gospelBlock(_ text: String, result: ServiceSearchResult?) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            ForEach(gospelLines(text)) { line in
                switch line.kind {
                case .header:
                    if let offsets = localOffsets(for: result, line: line) {
                        highlightedText(line.text, offsets: offsets)
                            .font(.system(size: 18, weight: .medium, design: .serif))
                            .foregroundStyle(Paper.ink)
                    } else {
                        let prefix = "Εὐαγγέλιον:"
                        let reference = line.text.dropFirst(min(prefix.count, line.text.count))
                            .trimmingCharacters(in: .whitespaces)
                        (Text("Ευαγγέλιον: ").foregroundColor(Paper.gold) + Text(reference))
                            .font(.system(size: 18, weight: .medium, design: .serif))
                            .foregroundStyle(Paper.ink)
                    }
                case .chapter:
                    highlightedText(line.text, offsets: localOffsets(for: result, line: line))
                        .font(.system(size: 14, weight: .medium, design: .serif))
                        .foregroundStyle(Paper.inkMute)
                        .padding(.top, 5)
                case .verse:
                    HStack(alignment: .firstTextBaseline, spacing: 11) {
                        Text(line.verseNumber ?? "")
                            .font(.system(size: 11, weight: .semibold, design: .serif))
                            .foregroundStyle(Paper.gold)
                            .frame(width: 24, alignment: .trailing)
                        highlightedText(
                            line.verseText ?? "",
                            offsets: localOffsets(for: result, line: line)
                        )
                        .font(.system(size: 19, design: .serif))
                        .foregroundStyle(Paper.ink).lineSpacing(8)
                    }
                case .text:
                    highlightedText(line.text, offsets: localOffsets(for: result, line: line))
                        .font(.system(size: 19, design: .serif))
                        .foregroundStyle(Paper.ink).lineSpacing(8)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 5)
        .textSelection(.enabled)
    }

    private func highlightedText(_ text: String, result: ServiceSearchResult?) -> Text {
        highlightedText(text, offsets: result.map { ($0.startOffset, $0.endOffset) })
    }

    private func highlightedText(_ text: String, offsets: (Int, Int)?) -> Text {
        guard let offsets, offsets.0 >= 0, offsets.1 <= text.count, offsets.0 < offsets.1 else {
            return Text(text)
        }
        let start = text.index(text.startIndex, offsetBy: offsets.0)
        let end = text.index(text.startIndex, offsetBy: offsets.1)
        return Text(String(text[..<start]))
            + Text(String(text[start..<end])).bold().foregroundColor(Paper.gold)
                .underline(true, color: Paper.gold)
            + Text(String(text[end...]))
    }

    private func localOffsets(for result: ServiceSearchResult?, line: GospelDisplayLine) -> (Int, Int)? {
        guard let result else { return nil }
        let start = result.startOffset - line.startOffset - line.contentOffset
        let end = result.endOffset - line.startOffset - line.contentOffset
        guard start >= 0, end <= line.displayText.count else { return nil }
        return (start, end)
    }

    private func gospelLines(_ text: String) -> [GospelDisplayLine] {
        var output: [GospelDisplayLine] = []
        var offset = 0
        for (index, rawPart) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
            let raw = String(rawPart)
            defer { offset += raw.count + 1 }
            guard !raw.trimmingCharacters(in: .whitespaces).isEmpty else { continue }
            if raw.hasPrefix("Εὐαγγέλιον:") {
                output.append(.init(id: index, text: raw, kind: .header,
                                    startOffset: offset, contentOffset: 0))
            } else if raw.hasPrefix("Κατὰ ") {
                output.append(.init(id: index, text: raw, kind: .chapter,
                                    startOffset: offset, contentOffset: 0))
            } else {
                let parts = raw.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
                if parts.count == 2, Int(parts[0]) != nil,
                   let contentRange = raw.range(of: String(parts[1])) {
                    output.append(.init(
                        id: index, text: raw, kind: .verse, startOffset: offset,
                        contentOffset: raw.distance(from: raw.startIndex, to: contentRange.lowerBound),
                        verseNumber: String(parts[0]), verseText: String(parts[1])
                    ))
                } else {
                    output.append(.init(id: index, text: raw, kind: .text,
                                        startOffset: offset, contentOffset: 0))
                }
            }
        }
        return output
    }

    private func load() {
        loadError = nil
        do {
            let loadedSchedules = try LiturgicalYearSchedule.loadAvailable()
            schedules = loadedSchedules
            let key = Self.keyFormatter.string(from: selectedDate)
            if !loadedSchedules.lazy.flatMap(\.entries).contains(where: { $0.date == key && $0.divineLiturgy }),
               let closest = loadedSchedules.flatMap({ $0.entries(for: .divineLiturgy) })
                .compactMap({ Self.keyFormatter.date(from: $0.date) })
                .min(by: { abs($0.timeIntervalSince(selectedDate)) < abs($1.timeIntervalSince(selectedDate)) }) {
                selectedDate = closest
                return
            }
            let repository = try LiturgicalRepository.load()
            package = try ServiceAssembler.assemble(
                selectedDate, repository: repository, bible: scripture.bible,
                scheduledEntry: selectedScheduleEntry
            )
            if package == nil {
                loadError = "Η Θεία Λειτουργία προβλέπεται από το Τυπικό, αλλά τα μεταβαλλόμενα αναγνώσματα της ημέρας δεν έχουν ακόμη ενσωματωθεί."
            }
        } catch { loadError = error.localizedDescription }
    }
}

enum LiturgicalDate {
    static func nextSunday(from date: Date, calendar: Calendar = .current) -> Date {
        if calendar.component(.weekday, from: date) == 1 { return date }
        return calendar.nextDate(after: date, matching: DateComponents(weekday: 1),
                                 matchingPolicy: .nextTimePreservingSmallerComponents) ?? date
    }
}
