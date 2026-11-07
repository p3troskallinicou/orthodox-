//
//  KlimaxShortStories.swift
//  Klimax, «Σύντομες Ἱστορίες» (Γεροντικόν)
//
//  «Κλίμαξ»  → διακόπτης: Τράπουλα (πρώτη κάρτα μπροστά, ἑπόμενες δεξιά) ἢ Πλέγμα
//  «Σήμερα»  → μιὰ καθαρὴ κάρτα στοίβα μὲ τὸ θέμα τῆς ἡμέρας
//  Πάτημα ὁπουδήποτε → πλήρης ὀθόνη (zoom): πάτα γιὰ τὸ νόημα, σύρε γιὰ ἑπόμενη.
//
//  Sanity type "patericStory" · παλέτα Paper/Gild. The complete corpus is
//  bundled in pateric-stories.json; Sanity is only an optional refresh.
//

import SwiftUI
import UIKit

// MARK: - Ρυθμίσεις Sanity

private enum SStore {
    static let projectId = "uqaka7yh"
    static let dataset = "production"
    static let apiVersion = "v2021-06-07"
    static let token: String? = "skK706jsv9XOGQcJz11BkV67duKyolNJwDRiGMnfGYRNifZsi7NgX12ThjJgUnCKwXRPYHtWau59pJMPiPwyfpI5Euv7c2jN1kfQiwbstCfzSoX9xSlOWMCpAeI2mLfPTNHUEvQtwNJ5m6TNFVlGFxUyHm0wcq0IfpGvsDkWkc7yRNeJrlGH"   // ἴδιο Viewer token μὲ τὸ LogosDidaches.swift

    static let query = """
    *[_type=="patericStory"]|order(order asc){
      _id, text, theme, meaning, source, father, reference, order
    }
    """
    static func url() -> URL {
        var c = URLComponents()
        c.scheme = "https"; c.host = "\(projectId).apicdn.sanity.io"
        c.path = "/\(apiVersion)/data/query/\(dataset)"
        c.queryItems = [URLQueryItem(name: "query", value: query)]
        return c.url!
    }
}

// MARK: - Μοντέλο

struct PatericStory: Identifiable, Codable, Equatable {
    let id: String
    let text: String
    let theme: String?
    let meaning: String?
    let source: String?
    let father: String?
    let reference: String?
    enum CodingKeys: String, CodingKey {
        case id = "_id", text, theme, meaning, source, father, reference
    }
    static func == (a: PatericStory, b: PatericStory) -> Bool { a.id == b.id }
}

private struct StoriesResult: Decodable { let result: [PatericStory] }
private struct BundledStories: Decodable { let stories: [PatericStory] }

private extension PatericStory {
    var shareText: String {
        var parts: [String] = ["«\(text)»"]
        if let theme, !theme.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append(theme)
        }
        if let reference, !reference.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append(reference)
        } else if let source, !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append(source)
        }
        return parts.joined(separator: "\n— ")
    }
}

@MainActor
private func saveStoryToNotebook(_ story: PatericStory, excerpt: String? = nil, body: String = "") {
    let title = story.theme?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        ? (story.theme ?? "Γεροντικόν")
        : "Γεροντικόν"
    let note = NotebookNote(
        title: title,
        body: body,
        category: .gerontikon,
        anchors: [
            NotebookAnchor(
                kind: .gerontikon,
                title: story.reference ?? story.source ?? "Γεροντικόν",
                excerpt: excerpt ?? story.text,
                routeValue: story.id,
                startTime: nil
            )
        ],
        createdAt: Date(),
        updatedAt: Date()
    )
    NotebookStore.shared.upsert(note)
}

// MARK: - Store

@MainActor
final class ShortStoriesStore: ObservableObject {
    static let shared = ShortStoriesStore()

    @Published var stories: [PatericStory] = []
    @Published var isLoading = false
    @Published var errorText: String?

    func load() async {
        guard stories.isEmpty, !isLoading else { return }
        isLoading = true; errorText = nil

        // Load the complete, preinstalled Gerontikon before awaiting Sanity.
        if let bundled = Self.loadBundled(), !bundled.isEmpty {
            stories = bundled
        }
        if let cached = Self.loadCache(), cached.count >= stories.count {
            stories = cached
        }

        do {
            var req = URLRequest(url: SStore.url())
            if let t = SStore.token { req.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization") }
            let (data, resp) = try await URLSession.shared.data(for: req)
            if let http = resp as? HTTPURLResponse, http.statusCode >= 300 {
                throw NSError(domain: "Sanity", code: http.statusCode,
                              userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode)"])
            }
            let live = try JSONDecoder().decode(StoriesResult.self, from: data).result
            // A partial CMS response must not replace the complete offline
            // corpus for this launch or become the next offline cache.
            if live.count >= stories.count {
                stories = live
                Self.saveCache(live)
            }
        } catch {
            if stories.isEmpty { errorText = error.localizedDescription }
        }
        isLoading = false
    }

    private static func loadBundled() -> [PatericStory]? {
        guard let url = Bundle.main.url(forResource: "pateric-stories", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(BundledStories.self, from: data).stories
    }

    private static var cacheURL: URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
            .first?.appendingPathComponent("klimax-pateric-stories-cache.json")
    }

    private static func saveCache(_ stories: [PatericStory]) {
        guard let url = cacheURL,
              let data = try? JSONEncoder().encode(stories) else { return }
        try? data.write(to: url, options: .atomic)
    }

    private static func loadCache() -> [PatericStory]? {
        guard let url = cacheURL,
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode([PatericStory].self, from: data)
    }

    func daily(count: Int = 3) -> [PatericStory] {
        guard !stories.isEmpty else { return [] }
        let day = Int(Date().timeIntervalSince1970 / 86400)
        let start = (day * count) % stories.count
        return (0..<min(count, stories.count)).map { stories[(start + $0) % stories.count] }
    }
}

@MainActor
final class ShortStoryFavoritesStore: ObservableObject {
    static let shared = ShortStoryFavoritesStore()

    @Published private(set) var favoriteIDs: Set<String>

    private let key = "patericStory.favoriteIDs"

    private init() {
        favoriteIDs = Set(UserDefaults.standard.stringArray(forKey: key) ?? [])
    }

    func contains(_ story: PatericStory) -> Bool {
        favoriteIDs.contains(story.id)
    }

    func toggle(_ story: PatericStory) {
        if favoriteIDs.contains(story.id) {
            favoriteIDs.remove(story.id)
        } else {
            favoriteIDs.insert(story.id)
        }
        UserDefaults.standard.set(Array(favoriteIDs).sorted(), forKey: key)
    }
}

// MARK: - Στοιχεῖα σχεδίασης

private let cardCorner: CGFloat = 24
private let flipAnim: Animation = .smooth(duration: 0.55)

private func cardShell() -> some View {
    let shape = RoundedRectangle(cornerRadius: cardCorner, style: .continuous)
    return shape
        .fill(Paper.card)
        .overlay(shape.stroke(Paper.hairline, lineWidth: 0.75))
        .shadow(color: Color.black.opacity(0.035), radius: 12, x: 0, y: 4)
}

private struct StoryCardActions: View {
    let story: PatericStory
    var compact = false
    @ObservedObject private var favorites = ShortStoryFavoritesStore.shared
    @State private var noteDraft: StoryNoteDraft?

    var body: some View {
        HStack(spacing: compact ? 5 : 7) {
            Button {
                favorites.toggle(story)
            } label: {
                actionIcon(favorites.contains(story) ? "heart.fill" : "heart",
                           selected: favorites.contains(story),
                           accessibility: favorites.contains(story) ? "Αφαίρεση από τα αγαπημένα" : "Προσθήκη στα αγαπημένα")
            }
            .buttonStyle(.plain)

            ShareLink(item: story.shareText) {
                actionIcon("square.and.arrow.up", selected: false, accessibility: "Κοινοποίηση")
            }

            Button {
                noteDraft = StoryNoteDraft(story: story, excerpt: story.text)
            } label: {
                actionIcon("note.text.badge.plus", selected: false, accessibility: "Προσθήκη στο σημειωματάριο")
            }
            .buttonStyle(.plain)
        }
        .sheet(item: $noteDraft) { draft in
            NotebookSourceNoteSheet(draft: draft.notebookDraft)
                .presentationDetents([.medium, .large])
        }
    }

    private func actionIcon(_ systemName: String, selected: Bool, accessibility: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: compact ? 11 : 13, weight: .semibold))
            .foregroundStyle(selected ? .white : Paper.gold)
            .frame(width: compact ? 28 : 32, height: compact ? 28 : 32)
            .background(Circle().fill(selected ? Paper.gold : Paper.card))
            .overlay(Circle().stroke(selected ? Color.clear : Paper.hairline, lineWidth: 1))
            .accessibilityLabel(accessibility)
    }
}

// Ἁπαλὸ 3D γύρισμα (μὲ σκίαση στὴν ἀκμή)
private struct FlipContainer<Front: View, Back: View>: View, Animatable {
    var angle: Double
    var animatableData: Double { get { angle } set { angle = newValue } }
    let front: Front
    let back: Back
    init(faceUp: Bool, @ViewBuilder front: () -> Front, @ViewBuilder back: () -> Back) {
        self.angle = faceUp ? 180 : 0
        self.front = front(); self.back = back()
    }
    var body: some View {
        let edge = 1 - abs(90 - angle) / 90
        Group { if angle < 90 { front } else { back.scaleEffect(x: -1, y: 1) } }
            .overlay(RoundedRectangle(cornerRadius: cardCorner, style: .continuous)
                .fill(Color.black.opacity(0.30 * max(0, edge))))
            .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
    }
}

private struct NotebookSelectableStoryText: UIViewRepresentable {
    let text: String
    let fontSize: CGFloat
    let alignment: NSTextAlignment
    let selectionEnabled: Bool
    let onNote: (String) -> Void
    var onSelectionChange: (String?) -> Void = { _ in }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> NotebookTextView {
        let view = NotebookTextView()
        view.isEditable = false
        view.isSelectable = selectionEnabled
        view.selectionEnabled = selectionEnabled
        view.isScrollEnabled = false
        view.backgroundColor = .clear
        view.textContainerInset = .zero
        view.textContainer.lineFragmentPadding = 0
        view.adjustsFontForContentSizeCategory = true
        view.onNote = onNote
        view.onSelectionChange = onSelectionChange
        view.delegate = context.coordinator
        return view
    }

    func updateUIView(_ uiView: NotebookTextView, context: Context) {
        context.coordinator.parent = self
        uiView.onNote = onNote
        uiView.onSelectionChange = onSelectionChange
        uiView.selectionEnabled = selectionEnabled
        uiView.isSelectable = selectionEnabled
        if !selectionEnabled {
            uiView.selectedRange = NSRange(location: 0, length: 0)
        }

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineSpacing = fontSize >= 20 ? 7 : 6

        let descriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: fontSize >= 20 ? .title2 : .body)
        let serifDescriptor = descriptor.withDesign(.serif) ?? descriptor
        let font = UIFont(descriptor: serifDescriptor, size: fontSize)

        uiView.attributedText = NSAttributedString(
            string: text,
            attributes: [
                .font: font,
                .foregroundColor: UIColor(Paper.ink),
                .paragraphStyle: paragraph
            ]
        )
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: NotebookTextView, context: Context) -> CGSize? {
        let width = proposal.width ?? UIScreen.main.bounds.width - 80
        let size = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: size.height)
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: NotebookSelectableStoryText

        init(_ parent: NotebookSelectableStoryText) {
            self.parent = parent
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            parent.onSelectionChange(parent.selectedText(in: textView))
        }
    }

    private func selectedText(in textView: UITextView) -> String? {
        let fullText = textView.text ?? ""
        guard textView.selectedRange.location != NSNotFound,
              textView.selectedRange.length > 0,
              let range = Range(textView.selectedRange, in: fullText)
        else { return nil }

        let selected = String(fullText[range]).trimmingCharacters(in: .whitespacesAndNewlines)
        return selected.isEmpty ? nil : selected
    }
}

private final class NotebookTextView: UITextView {
    var onNote: ((String) -> Void)?
    var onSelectionChange: ((String?) -> Void)?
    var selectionEnabled = false

    override var selectedRange: NSRange {
        didSet { reportSelection() }
    }

    @objc func createNoteFromSelection() {
        guard let selectedText else { return }
        onNote?(selectedText)
    }

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        false
    }

    private var selectedText: String? {
        let fullText = text ?? ""
        guard selectedRange.location != NSNotFound,
              selectedRange.length > 0,
              let range = Range(selectedRange, in: fullText)
        else { return nil }

        let selected = String(fullText[range]).trimmingCharacters(in: .whitespacesAndNewlines)
        return selected.isEmpty ? nil : selected
    }

    private func reportSelection() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.onSelectionChange?(self.selectedText)
        }
    }
}

// MARK: - Ὄψεις κάρτας (πλήρους ὀθόνης)

private struct StoryFront: View {
    let story: PatericStory
    let highlightMode: Bool
    var makeNote: (String) -> Void = { _ in }
    var selectionChanged: (String?) -> Void = { _ in }
    var body: some View {
        ZStack {
            cardShell()
            VStack(spacing: 16) {
                Image(systemName: "text.quote").font(.title2).foregroundStyle(Paper.gold.opacity(0.8))
                ScrollView(showsIndicators: false) {
                    NotebookSelectableStoryText(
                        text: story.text,
                        fontSize: 21,
                        alignment: .center,
                        selectionEnabled: highlightMode,
                        onNote: makeNote,
                        onSelectionChange: selectionChanged
                    )
                    .padding(.vertical, 6)
                }
                if let r = story.reference { Text(r).font(.footnote).foregroundStyle(Paper.inkMute) }
                Label("Πάτησε για το νόημα", systemImage: "hand.tap")
                    .font(.caption).foregroundStyle(Paper.gold.opacity(0.8))
            }.padding(28)
        }
    }
}

private struct StoryBack: View {
    let story: PatericStory
    let highlightMode: Bool
    var makeNote: (String) -> Void = { _ in }
    var selectionChanged: (String?) -> Void = { _ in }
    var body: some View {
        ZStack {
            cardShell()
            VStack(spacing: 18) {
                if let t = story.theme {
                    Text(t).font(.system(size: 24, weight: .semibold, design: .serif))
                        .foregroundStyle(Paper.gold).multilineTextAlignment(.center)
                }
                Rectangle().fill(Paper.gold.opacity(0.3)).frame(width: 52, height: 1)
                ScrollView(showsIndicators: false) {
                    NotebookSelectableStoryText(
                        text: story.meaning ?? "",
                        fontSize: 18,
                        alignment: .center,
                        selectionEnabled: highlightMode,
                        onNote: makeNote,
                        onSelectionChange: selectionChanged
                    )
                    .padding(.vertical, 4)
                }
                Label("Πάτησε για την ιστορία", systemImage: "arrow.uturn.backward")
                    .font(.caption).foregroundStyle(Paper.gold.opacity(0.8))
            }.padding(28)
        }
    }
}

private struct ReaderPage: View {
    let story: PatericStory
    let highlightMode: Bool
    var makeNote: (PatericStory, String) -> Void = { _, _ in }
    var selectionChanged: (PatericStory, String?) -> Void = { _, _ in }
    @State private var faceUp = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Label("ΓΕΡΟΝΤΙΚΟ", systemImage: "text.quote")
                    .font(.caption.weight(.semibold)).tracking(1.5)
                    .foregroundStyle(Gild.accentForeground)
                Spacer()
                Text("\(max(1, story.text.split(whereSeparator: \.isWhitespace).count / 180))′ ανάγνωση")
                    .font(.caption).foregroundStyle(Paper.inkMute)
            }
            Text((story.theme ?? story.father ?? "Μια ιστορία σοφίας").interfaceGreek)
                .font(.system(.title, design: .serif, weight: .semibold))
                .foregroundStyle(Paper.ink).fixedSize(horizontal: false, vertical: true)
            if let meaning = story.meaning, !meaning.isEmpty {
                Picker("Προβολή κειμένου", selection: $faceUp) {
                    Text("Ιστορία").tag(false)
                    Text("Νόημα").tag(true)
                }.pickerStyle(.segmented)
                    .disabled(highlightMode)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    NotebookSelectableStoryText(
                        text: faceUp ? (story.meaning ?? "") : story.text,
                        fontSize: 20,
                        alignment: .left,
                        selectionEnabled: highlightMode,
                        onNote: { makeNote(story, $0) },
                        onSelectionChange: { selectionChanged(story, $0) }
                    )
                    .id(faceUp)
                    .transition(.opacity)
                    if let reference = story.reference ?? story.source {
                        Text(reference).font(.footnote).foregroundStyle(Paper.inkMute)
                    }
                }.padding(.bottom, 20)
            }
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: faceUp)
        }
        .padding(24)
        .onChange(of: faceUp) { _, _ in selectionChanged(story, nil) }
    }
}

// MARK: - Reader πλήρους ὀθόνης

struct StoryReaderView: View {
    let stories: [PatericStory]
    let startIndex: Int
    var isOpen: Bool = true
    var onClose: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @StateObject private var favorites = ShortStoryFavoritesStore.shared
    @State private var index: Int
    @State private var noteDraft: StoryNoteDraft?
    @State private var selectedTextDraft: StoryNoteDraft?
    @State private var highlightMode = false

    init(stories: [PatericStory], startIndex: Int, isOpen: Bool = true, onClose: (() -> Void)? = nil) {
        self.stories = stories
        self.startIndex = startIndex
        self.isOpen = isOpen
        self.onClose = onClose
        _index = State(initialValue: max(0, min(startIndex, max(0, stories.count - 1))))
    }

    private func close() {
        if let onClose { onClose() } else { dismiss() }
    }

    private var currentStory: PatericStory? {
        guard stories.indices.contains(index) else { return nil }
        return stories[index]
    }

    // A story counts as read only after it stays on screen for a short dwell,
    // so fast swiping past cards does not count. Item id keeps it distinct.
    private func dwellRecordCurrentStory() async {
        guard isOpen, let story = currentStory else { return }
        try? await Task.sleep(for: .seconds(5))
        if Task.isCancelled { return }
        if isOpen, currentStory?.id == story.id {
            StreakStore.shared.record(.stories, itemID: story.id)
        }
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if isOpen {
                // Ἡ προηγούμενη ὀθόνη, θολωμένη (μπαίνει ἁπαλὰ μὲ fade).
                AppAtmosphere().ignoresSafeArea()
                    .transition(.opacity)

                // Ἡ κάρτα: μεγαλώνει μπροστά (χωρὶς fade στὸ ἄνοιγμα).
                VStack(spacing: 10) {
                    TabView(selection: $index) {
                        ForEach(Array(stories.enumerated()), id: \.element.id) { i, s in
                            ReaderPage(story: s, highlightMode: highlightMode) { story, excerpt in
                                noteDraft = StoryNoteDraft(story: story, excerpt: excerpt)
                            } selectionChanged: { story, excerpt in
                                if let excerpt {
                                    selectedTextDraft = StoryNoteDraft(story: story, excerpt: excerpt)
                                } else if selectedTextDraft?.story.id == story.id {
                                    selectedTextDraft = nil
                                }
                            }
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                                .padding(.horizontal, 20)
                                .tag(i)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    VStack(spacing: 4) {
                        Text("\(index + 1) / \(stories.count)").font(.footnote).foregroundStyle(Paper.inkMute)
                        Label("Σύρε για την επόμενη", systemImage: "hand.draw")
                            .font(.caption2).foregroundStyle(Paper.inkMute)
                        if let story = currentStory, !highlightMode {
                            readerActions(story)
                                .padding(.top, 8)
                        }
                    }.padding(.bottom, 10)
                }
                .padding(.top, 76)
                .transition(.opacity)

                HStack(spacing: 10) {
                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                            highlightMode.toggle()
                            selectedTextDraft = nil
                        }
                    } label: {
                        HStack(spacing: 7) {
                            Image(systemName: "highlighter")
                                .font(.system(size: 13, weight: .semibold))
                            Text(highlightMode ? "Τέλος" : "Επιλογή")
                                .font(.system(size: 13, weight: .bold))
                        }
                        .foregroundStyle(highlightMode ? Paper.gold : Paper.ink)
                        .padding(.vertical, 11)
                        .padding(.horizontal, 14)
                        .glassCircleFallback(shape: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(highlightMode ? "Τέλος επιλογής" : "Επιλογή αποσπάσματος")

                    Button(role: .cancel) {
                        close()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Paper.ink)
                            .frame(width: 46, height: 46)
                            .glassCircleFallback(shape: Circle())
                    }
                    .buttonStyle(.plain)
                    .contentShape(Circle())
                    .accessibilityLabel("Κλείσιμο")
                }
                .padding(.trailing, 20).padding(.top, 14)
                .transition(.opacity)
                .zIndex(5)
            }
        }
        .overlay(alignment: .top) {
            if highlightMode {
                Label("Highlight text", systemImage: "text.quote")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Paper.gold)
                    .padding(.vertical, 9)
                    .padding(.horizontal, 14)
                    .klimaxLiquidGlass(in: Capsule())
                    .padding(.top, 66)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .overlay(alignment: .bottom) {
            if highlightMode {
                selectionModeToolbar
                    .padding(.bottom, 92)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.82), value: isOpen)
        .animation(.spring(response: 0.28, dampingFraction: 0.86), value: selectedTextDraft?.id)
        .onChange(of: isOpen) { _, open in
            if open {
                index = max(0, min(startIndex, max(0, stories.count - 1)))
            }
        }
        .onChange(of: index) { _, _ in
            selectedTextDraft = nil
        }
        .task(id: isOpen ? index : -1) {
            await dwellRecordCurrentStory()
        }
        .onChange(of: highlightMode) { _, enabled in
            if !enabled {
                selectedTextDraft = nil
            }
        }
        .sheet(item: $noteDraft) { draft in
            NotebookSourceNoteSheet(draft: draft.notebookDraft)
                .presentationDetents([.medium, .large])
        }
    }

    private var selectionModeToolbar: some View {
        HStack(spacing: 10) {
            Button {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                    highlightMode = false
                    selectedTextDraft = nil
                }
            } label: {
                selectionActionLabel("Cancel", "xmark")
            }
            .buttonStyle(.plain)

            if let draft = selectedTextDraft {
                Button {
                    UIPasteboard.general.string = draft.excerpt
                } label: {
                    selectionActionLabel("Copy", "doc.on.doc")
                }
                .buttonStyle(.plain)

                ShareLink(item: draft.shareText) {
                    selectionActionLabel("Share", "square.and.arrow.up")
                }

                Button {
                    noteDraft = draft
                    selectedTextDraft = nil
                    highlightMode = false
                } label: {
                    selectionActionLabel("Note", "note.text.badge.plus", emphasized: true)
                }
                .buttonStyle(.plain)
            } else {
                Label("Select text", systemImage: "text.cursor")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Paper.inkMute)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .background(Paper.card.opacity(0.52), in: Capsule())
            }
        }
        .padding(8)
        .klimaxLiquidGlass(in: Capsule())
        .padding(.horizontal, 20)
    }

    private func selectionActionLabel(_ title: String, _ icon: String, emphasized: Bool = false) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .foregroundStyle(emphasized ? .white : Paper.gold)
        .padding(.vertical, 10)
        .padding(.horizontal, 10)
        .background(emphasized ? Paper.gold : Paper.card.opacity(0.72), in: Capsule())
    }

    private func readerActions(_ story: PatericStory) -> some View {
        HStack(spacing: 10) {
            Button {
                favorites.toggle(story)
            } label: {
                readerActionLabel(favorites.contains(story) ? "Στα αγαπημένα" : "Αγαπημένο",
                                  favorites.contains(story) ? "heart.fill" : "heart",
                                  selected: favorites.contains(story))
            }
            .buttonStyle(.plain)

            ShareLink(item: story.shareText) {
                readerActionLabel("Κοινοποίηση", "square.and.arrow.up", selected: false)
            }

            Button {
                noteDraft = StoryNoteDraft(story: story, excerpt: story.text)
            } label: {
                readerActionLabel("Σημείωση", "note.text.badge.plus", selected: false)
            }
            .buttonStyle(.plain)
        }
    }

    private func readerActionLabel(_ title: String, _ icon: String, selected: Bool) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon).font(.system(size: 12, weight: .semibold))
            Text(title).font(.system(size: 12, weight: .semibold))
        }
        .foregroundStyle(selected ? .white : Gild.accentForeground)
        .padding(.vertical, 8).padding(.horizontal, 13)
        .background(selected ? Paper.gold : Paper.card, in: Capsule())
        .overlay(Capsule().stroke(selected ? Color.clear : Paper.hairline, lineWidth: 1))
    }
}

private struct StoryNoteDraft: Identifiable {
    let id = UUID()
    let story: PatericStory
    let excerpt: String

    var shareText: String {
        var parts = ["«\(excerpt)»"]
        if let reference = story.reference, !reference.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append(reference)
        } else if let source = story.source, !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append(source)
        } else {
            parts.append("Γεροντικόν")
        }
        return parts.joined(separator: "\n— ")
    }

    var notebookDraft: NotebookSourceNoteDraft {
        let title = story.theme?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? (story.theme ?? "Γεροντικόν")
            : "Γεροντικόν"
        return NotebookSourceNoteDraft(
            title: title,
            category: .gerontikon,
            anchor: NotebookAnchor(
                kind: .gerontikon,
                title: story.reference ?? story.source ?? "Γεροντικόν",
                excerpt: excerpt,
                routeValue: story.id,
                startTime: nil
            )
        )
    }
}

private struct StoryExcerptNoteSheet: View {
    @Environment(\.dismiss) private var dismiss
    let draft: StoryNoteDraft
    @State private var excerpt: String

    init(draft: StoryNoteDraft) {
        self.draft = draft
        _excerpt = State(initialValue: draft.excerpt)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text(draft.story.reference ?? draft.story.source ?? draft.story.theme ?? "Γεροντικόν")
                    .font(.system(size: 13, weight: .black))
                    .tracking(2.4)
                    .foregroundStyle(Paper.gold)

                TextEditor(text: $excerpt)
                    .font(.system(size: 18, weight: .regular, design: .serif))
                    .foregroundStyle(Paper.ink)
                    .scrollContentBackground(.hidden)
                    .padding(12)
                    .background(Paper.card.opacity(0.72), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Paper.hairline, lineWidth: 1))
            }
            .padding(20)
            .background(Paper.bg.ignoresSafeArea())
            .navigationTitle("Σημείωση")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Άκυρο") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Αποθήκευση") {
                        saveStoryToNotebook(draft.story, excerpt: excerpt)
                        dismiss()
                    }
                    .fontWeight(.bold)
                    .tint(Paper.gold)
                }
            }
        }
    }
}

// MARK: - Κάρτες ἐπισκόπησης

private struct ReaderStart: Identifiable {
    let index: Int
    let sourceID: String
    let stories: [PatericStory]
    var id: String { sourceID }
}

// Μεγάλη κάρτα τράπουλας (ὁριζόντια, μὲ προβολὴ τῆς ἑπόμενης δεξιά)
private struct DeckCard: View {
    let index: Int
    let story: PatericStory
    var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(String(format: "%02d", index + 1))
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .foregroundStyle(Paper.inkMute)
                    Text((story.father ?? "Γεροντικό").interfaceGreek)
                        .font(.caption.weight(.medium)).foregroundStyle(Paper.inkSoft).lineLimit(1)
                    Spacer()
                    StoryCardActions(story: story)
                }
                if let t = story.theme {
                    Text(t.interfaceGreek).font(.system(size: 23, weight: .semibold, design: .serif))
                        .foregroundStyle(Paper.ink).lineLimit(2)
                }
                Text(story.text).font(.system(size: 16, design: .serif)).foregroundStyle(Paper.ink)
                    .lineSpacing(4).multilineTextAlignment(.leading).lineLimit(3)
                HStack {
                    Text("Διάβασε την ιστορία")
                    Spacer()
                    Image(systemName: "arrow.right")
                }
                .font(.caption.weight(.semibold)).foregroundStyle(Gild.accentForeground)
                .padding(.top, 4)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardShell())
    }
}

// Τετράγωνο πλέγματος
private let gridCols = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

private struct GridCard: View {
    let index: Int
    let story: PatericStory
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "text.quote").font(.caption).foregroundStyle(Paper.gold.opacity(0.7))
                Spacer()
                StoryCardActions(story: story, compact: true)
                Text("\(index + 1)").font(.system(size: 11, design: .serif)).foregroundStyle(Paper.inkMute)
            }
            if let t = story.theme {
                    Text(t.interfaceGreek).font(.system(size: 18, weight: .semibold, design: .serif))
                    .foregroundStyle(Paper.ink).lineLimit(2)
            }
            Text(story.text).font(.system(size: 14, design: .serif)).foregroundStyle(Paper.inkSoft)
                .lineLimit(3).multilineTextAlignment(.leading).lineSpacing(3)
            Spacer(minLength: 0)
        }
        .padding(14).frame(height: 186, alignment: .top).frame(maxWidth: .infinity)
        .background(cardShell())
    }
}

// MARK: - Ἐνσωματώσιμη ἑνότητα «Κλίμαξ» (Τράπουλα / Πλέγμα)

final class ReaderPresenter: ObservableObject {
    static let shared = ReaderPresenter()
    @Published var stories: [PatericStory] = []
    @Published var startIndex: Int = 0
    @Published var isOpen: Bool = false

    func open(_ stories: [PatericStory], at index: Int) {
        self.stories = stories
        self.startIndex = index
        isOpen = true
    }
    func close() {
        isOpen = false
    }
}

struct ShortStoriesSectionView: View {
    var topInset: CGFloat = 72
    @ObservedObject private var store = ShortStoriesStore.shared
    @StateObject private var favorites = ShortStoryFavoritesStore.shared
    @State private var layout: Layout = .deck
    @State private var showFavorites = false
    @State private var readerStart: ReaderStart?
    @Namespace private var zoom

    enum Layout { case deck, grid }

    private var displayedStories: [PatericStory] {
        guard showFavorites else { return store.stories }
        return store.stories.filter { favorites.favoriteIDs.contains($0.id) }
    }

    var body: some View {
        Group {
            if store.isLoading && store.stories.isEmpty {
                ProgressView("Φόρτωση…").tint(Paper.gold).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let err = store.errorText, store.stories.isEmpty {
                errorState(err)
            } else if store.stories.isEmpty {
                Text("Δεν υπάρχουν ακόμα ιστορίες.").foregroundStyle(Paper.inkMute)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 10) {
                    switcher
                        .logosBlockRise(0)
                    if showFavorites && displayedStories.isEmpty {
                        favoritesEmptyState
                            .logosBlockRise(1)
                    } else if layout == .deck {
                        deckCarousel
                            .logosBlockRise(1)
                    } else {
                        grid
                            .logosBlockRise(1)
                    }
                }
                .padding(.top, topInset)
            }
        }
        .background(Color.clear)
        .task { await store.load() }
        .fullScreenCover(item: $readerStart) { start in
            StoryReaderView(stories: start.stories, startIndex: start.index)
        }
    }

    private var switcher: some View {
        HStack(spacing: 6) {
            favoriteFilterButton
            Spacer()
            switchButton(.deck, "rectangle.grid.1x2")
            switchButton(.grid, "square.grid.2x2")
        }
        .padding(.horizontal, 20).padding(.top, 4)
    }

    private func switchButton(_ value: Layout, _ icon: String) -> some View {
        let on = (layout == value)
        return Button { withAnimation(.easeInOut(duration: 0.2)) { layout = value } } label: {
            Image(systemName: icon).font(.system(size: 14, weight: .semibold))
                .foregroundStyle(on ? .white : Paper.inkMute)
                .padding(8)
                .background(Circle().fill(on ? Paper.gold : Color.clear))
                .overlay(Circle().stroke(on ? Color.clear : Paper.hairline, lineWidth: 1))
        }.buttonStyle(.plain)
            .accessibilityLabel(value == .deck ? "Λίστα ιστοριών" : "Πλέγμα ιστοριών")
            .accessibilityAddTraits(on ? .isSelected : [])
    }

    private var favoriteFilterButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { showFavorites.toggle() }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: showFavorites ? "heart.fill" : "heart")
                    .font(.system(size: 13, weight: .semibold))
                Text("Αγαπημένα")
                    .font(.system(size: 12, weight: .semibold))
                if !favorites.favoriteIDs.isEmpty {
                    Text("\(favorites.favoriteIDs.count)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(showFavorites ? Paper.gold : Paper.inkMute)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(showFavorites ? Color.white.opacity(0.88) : Paper.card, in: Capsule())
                }
            }
            .foregroundStyle(showFavorites ? .white : Paper.gold)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Capsule().fill(showFavorites ? Paper.gold : Color.clear))
            .overlay(Capsule().stroke(showFavorites ? Color.clear : Paper.hairline, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var deckCarousel: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 14) {
                ForEach(Array(displayedStories.enumerated()), id: \.element.id) { i, s in
                    DeckCard(index: i, story: s)
                        .matchedTransitionSource(id: s.id, in: zoom)
                        .onTapGesture { readerStart = ReaderStart(index: i, sourceID: s.id, stories: displayedStories) }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 110)
        }
        .frame(maxHeight: .infinity)
    }

    private var grid: some View {
        ScrollView(showsIndicators: false) {
            LazyVGrid(columns: gridCols, spacing: 12) {
                ForEach(Array(displayedStories.enumerated()), id: \.element.id) { i, s in
                    GridCard(index: i, story: s)
                        .matchedTransitionSource(id: s.id, in: zoom)
                        .onTapGesture { readerStart = ReaderStart(index: i, sourceID: s.id, stories: displayedStories) }
                }
            }
            .padding(.horizontal, 16).padding(.top, 4).padding(.bottom, 16)
        }
    }

    private var favoritesEmptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "heart")
                .font(.largeTitle)
                .foregroundStyle(Paper.gold)
            Text("Δεν έχεις αγαπημένες ιστορίες ακόμα.")
                .font(.headline)
                .foregroundStyle(Paper.ink)
                .multilineTextAlignment(.center)
            Text("Πάτησε την καρδιά σε μία κάρτα για να την κρατήσεις.")
                .font(.footnote)
                .foregroundStyle(Paper.inkMute)
                .multilineTextAlignment(.center)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorState(_ err: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "wifi.exclamationmark").font(.largeTitle).foregroundStyle(Paper.gold)
            Text("Δεν φορτώθηκαν οι ιστορίες").font(.headline).foregroundStyle(Paper.ink)
            Text(err).font(.footnote).foregroundStyle(Paper.inkMute).multilineTextAlignment(.center)
            Button("Δοκίμασε ξανά") { Task { await store.load() } }.buttonStyle(.borderedProminent).tint(Paper.gold)
        }.padding().frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - «Σήμερα»: καθαρὴ κάρτα στοίβα → πλήρης ὀθόνη

private struct DailyStack: View {
    let stories: [PatericStory]
    var body: some View {
        ZStack {
            // βάθος: δύο ἀκμὲς πίσω
            ForEach([2, 1], id: \.self) { k in
                RoundedRectangle(cornerRadius: cardCorner, style: .continuous)
                    .fill(Paper.card)
                    .overlay(RoundedRectangle(cornerRadius: cardCorner, style: .continuous).stroke(Paper.gold.opacity(0.20), lineWidth: 1))
                    .shadow(color: .black.opacity(0.04), radius: 5, x: 0, y: 3)
                    .scaleEffect(1 - CGFloat(k) * 0.05)
                    .offset(y: CGFloat(k) * 10)
            }
            // μπροστινὴ κάρτα
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "text.quote").font(.title3).foregroundStyle(Paper.gold.opacity(0.8))
                    Spacer()
                    Image(systemName: "arrow.up.left.and.arrow.down.right").font(.caption)
                        .foregroundStyle(Paper.inkMute.opacity(0.7))
                }
                Text(stories.first?.theme ?? "Γεροντικόν")
                    .font(.system(size: 26, weight: .semibold, design: .serif))
                    .foregroundStyle(Paper.gold).lineLimit(1).minimumScaleFactor(0.7)
                Text(stories.first?.text ?? "")
                    .font(.system(size: 15, design: .serif)).foregroundStyle(Paper.ink)
                    .lineLimit(2).lineSpacing(4)
                HStack(spacing: 6) {
                    ForEach(0..<stories.count, id: \.self) { i in
                        Circle().fill(i == 0 ? Paper.gold : Paper.gold.opacity(0.25)).frame(width: 6, height: 6)
                    }
                    Text("\(stories.count) ιστορίες σήμερα").font(.caption2).foregroundStyle(Paper.inkMute)
                        .padding(.leading, 4)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardShell())
        }
        .frame(maxWidth: .infinity)
    }
}

struct DailyStoriesView: View {
    @ObservedObject private var store = ShortStoriesStore.shared
    @State private var todays: [PatericStory] = []
    @State private var open = false
    @Namespace private var zoom

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ΙΣΤΟΡΙΕΣ ΤΗΣ ΗΜΕΡΑΣ")
                .font(.system(size: 12, weight: .semibold)).tracking(2).foregroundStyle(Paper.gold)
            if todays.isEmpty {
                RoundedRectangle(cornerRadius: cardCorner).fill(Paper.card).frame(height: 150)
                    .overlay(ProgressView().tint(Paper.gold))
            } else {
                Button { open = true } label: { DailyStack(stories: todays) }
                    .buttonStyle(CalmCardStyle())
                    .matchedTransitionSource(id: "dailyStories", in: zoom)
            }
        }
        .task { await store.load(); todays = store.daily() }
        .fullScreenCover(isPresented: $open) {
            StoryReaderView(stories: todays, startIndex: 0) {
                open = false
            }
                .navigationTransition(.zoom(sourceID: "dailyStories", in: zoom))
        }
    }
}

// MARK: - Standalone (preview)

struct ShortStoriesDeckView: View {
    var body: some View {
        NavigationStack { ShortStoriesSectionView().navigationTitle("Σύντομες Ιστορίες") }
            .tint(Paper.gold)
    }
}

#Preview { ShortStoriesDeckView() }
