//
//  ProfileView.swift
//  Klimax
//

import PhotosUI
import SwiftUI
import AVFoundation

struct ProfileView: View {
    @AppStorage("profile.displayName") private var displayName = "Προσκυνητής"
    @AppStorage("profile.nickname") private var nickname = "στο μονοπάτι"
    @AppStorage("profile.joinedAt") private var joinedAt = 0.0
    @AppStorage("profile.favoriteSaying") private var favoriteSaying = "Μικρά βήματα. Σταθερή καρδιά."
    @AppStorage("profile.photoData") private var photoData = Data()

    @State private var showingEditor = false

    private var joinedDate: Date {
        joinedAt > 0 ? Date(timeIntervalSince1970: joinedAt) : Date()
    }

    var body: some View {
        ZStack(alignment: .top) {
            AppAtmosphere().ignoresSafeArea()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    ProfileIdentityCard(
                        displayName: displayName,
                        nickname: nickname,
                        joinedDate: joinedDate,
                        favoriteSaying: favoriteSaying,
                        photoData: photoData,
                        editProfile: { showingEditor = true }
                    )
                    profileSectionLabel("Ο προσωπικός σου χώρος")
                    NotebookSummaryCard()
                    VirtualIconostasisCard()
                    profileSectionLabel("Η πορεία σου")
                    StreakSummaryCard()
                    ProgressionSummaryCard()
                }
                .padding(.horizontal, KSpace.gutter)
                .padding(.top, 92)
                .padding(.bottom, 100)
            }
            .scrollIndicators(.hidden)

            profileHeader
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            if joinedAt <= 0 {
                joinedAt = Date().timeIntervalSince1970
            }
        }
        .sheet(isPresented: $showingEditor) {
            ProfileEditorSheet(
                displayName: $displayName,
                nickname: $nickname,
                favoriteSaying: $favoriteSaying,
                photoData: $photoData
            )
            .presentationDetents([.medium, .large])
        }
    }

    private func profileSectionLabel(_ title: String) -> some View {
        Text(title).font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Paper.inkMute)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4).padding(.top, 8)
            .accessibilityAddTraits(.isHeader)
    }

    private var profileHeader: some View {
        HStack(spacing: 14) {
            Text("Προφίλ")
                .font(.system(size: 25, weight: .bold, design: .serif))
                .foregroundStyle(Paper.ink)
                .padding(.leading, 12)

            Spacer()

            Image(systemName: "person.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Paper.gold)
                .frame(width: 42, height: 42)
                .logosSectionGlass()
        }
        .padding(.horizontal, KSpace.gutter)
        .frame(height: 76)
        .background { AppHeaderSurface(condensed: false) }
    }
}

private struct ProfileIdentityCard: View {
    let displayName: String
    let nickname: String
    let joinedDate: Date
    let favoriteSaying: String
    let photoData: Data
    let editProfile: () -> Void

    private var joinedLabel: String {
        joinedDate.formatted(.dateTime.month(.wide).year())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                ProfileAvatar(photoData: photoData, name: displayName, size: 60)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(displayName.isEmpty ? "Προσκυνητής" : displayName)
                                .font(.system(size: 23, weight: .semibold, design: .serif))
                                .foregroundStyle(Paper.ink)
                                .lineLimit(1)
                                .minimumScaleFactor(0.76)
                            Text("@\(nickname.isEmpty ? "στο μονοπάτι" : nickname)")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Gild.accentForeground)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 8)
                        Button(action: editProfile) {
                            Image(systemName: "pencil")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Paper.ink)
                                .frame(width: 44, height: 44)
                                .glassCircleFallback(shape: Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Επεξεργασία προφίλ")
                    }

                    HStack(spacing: 7) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Paper.gold)
                        Text("Μαζί από \(joinedLabel)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Paper.inkMute)
                    }
                }
            }

            if !favoriteSaying.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Text("“\(favoriteSaying)”")
                .font(.system(size: 16, weight: .regular, design: .serif))
                .foregroundStyle(Paper.ink)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(alignment: .leading) { Capsule().fill(Paper.gold.opacity(0.25)).frame(width: 2) }
            }

        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(YouCardSurface())
    }
}

private struct ProfileAvatar: View {
    let photoData: Data
    let name: String
    let size: CGFloat

    private var initials: String {
        let pieces = name.split(separator: " ")
        let letters = pieces.prefix(2).compactMap { $0.first }
        let result = String(letters).uppercased()
        return result.isEmpty ? "Κ" : result
    }

    var body: some View {
        ZStack {
            if let uiImage = UIImage(data: photoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                LinearGradient(
                    colors: [
                        Paper.gold.opacity(0.95),
                        Color.adaptive(Color(red: 0.55, green: 0.78, blue: 1.0), Color(red: 0.10, green: 0.25, blue: 0.42))
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Text(initials)
                    .font(.system(size: size * 0.34, weight: .black, design: .rounded))
                    .foregroundStyle(Color.white)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.white.opacity(0.42), lineWidth: 1.2))
        .shadow(color: Paper.gold.opacity(0.20), radius: 14, x: 0, y: 7)
    }
}

private struct ProfileEditorSheet: View {
    @Binding var displayName: String
    @Binding var nickname: String
    @Binding var favoriteSaying: String
    @Binding var photoData: Data

    @Environment(\.dismiss) private var dismiss
    @State private var selectedItem: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 16) {
                        ProfileAvatar(photoData: photoData, name: displayName, size: 70)
                        PhotosPicker(selection: $selectedItem, matching: .images) {
                            Label(photoData.isEmpty ? "Διάλεξε φωτογραφία" : "Άλλαξε φωτογραφία", systemImage: "photo")
                        }
                    }
                    if !photoData.isEmpty {
                        Button(role: .destructive) {
                            photoData = Data()
                        } label: {
                            Label("Αφαίρεση φωτογραφίας", systemImage: "trash")
                        }
                    }
                }

                Section("Ταυτότητα") {
                    TextField("Όνομα", text: $displayName)
                    TextField("Nickname", text: $nickname)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                Section("Αγαπημένη φράση") {
                    TextField("Μια μικρή φράση που σε κρατά", text: $favoriteSaying, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Paper.bg)
            .navigationTitle("Το προφίλ σου")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Τέλος") { dismiss() }
                }
            }
            .onChange(of: selectedItem) { _, item in
                Task {
                    if let data = try? await item?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data),
                       let compressed = image.jpegData(compressionQuality: 0.72) {
                        photoData = compressed
                    }
                }
            }
        }
        .tint(Paper.gold)
    }
}

private struct ProfileVersePickerSheet: View {
    let selectedID: String
    let choices: [ProfileVerseChoice]
    let select: (ProfileVerseChoice) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var visibleChoices: [ProfileVerseChoice] {
        let needle = query
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "el"))
            .lowercased()
        guard !needle.isEmpty else { return choices }
        return choices.filter {
            "\($0.reference) \($0.text)"
                .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "el"))
                .lowercased()
                .contains(needle)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(visibleChoices) { choice in
                        Button { select(choice) } label: {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: selectedID == choice.id ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(selectedID == choice.id ? Paper.gold : Paper.inkMute)
                                    .padding(.top, 1)
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(choice.reference)
                                        .font(.system(size: 12, weight: .bold))
                                        .tracking(1.1)
                                        .foregroundStyle(Paper.gold)
                                    Text(choice.text)
                                        .font(.system(size: 16, weight: .medium, design: .serif))
                                        .foregroundStyle(Paper.ink)
                                        .lineLimit(4)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(15)
                            .background(Paper.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Paper.hairline, lineWidth: 1))
                        }
                        .buttonStyle(CalmCardStyle())
                    }
                }
                .padding(20)
            }
            .searchable(text: $query, prompt: "Αναζήτηση σε χωρία")
            .background(Paper.bg.ignoresSafeArea())
            .navigationTitle("Διάλεξε χωρίο")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Άκυρο") { dismiss() }
                }
            }
        }
        .tint(Paper.gold)
    }
}

private struct ProfileVerseChoice: Identifiable, Equatable {
    let id: String
    let reference: String
    let text: String

    init(id: String, reference: String, text: String) {
        self.id = id
        self.reference = reference
        self.text = text
    }

    init(book: Book, chapter: Chapter, verse: Verse) {
        id = "\(book.id)-\(chapter.number)-\(verse.number)"
        reference = "\(book.titleGreek) \(chapter.number):\(verse.number)"
        text = verse.modern?.isEmpty == false ? (verse.modern ?? verse.ancient) : verse.ancient
    }

    var chapterRouteValue: String? {
        let pieces = id.split(separator: "-").map(String.init)
        guard pieces.count >= 3, let chapter = Int(pieces[pieces.count - 2]) else { return nil }
        let bookID = pieces.dropLast(2).joined(separator: "-")
        return "\(bookID):\(chapter)"
    }

    static let fallback = ProfileVerseChoice(
        id: "fallback",
        reference: "Κατὰ Ἰωάννην 1:5",
        text: "Καὶ τὸ φῶς ἐν τῇ σκοτίᾳ φαίνει."
    )

    static func choices(from store: ScriptureStore) -> [ProfileVerseChoice] {
        let all = store.testaments.flatMap { testament in
            testament.books.flatMap { book in
                book.chapters.flatMap { chapter in
                    chapter.verses.map { ProfileVerseChoice(book: book, chapter: chapter, verse: $0) }
                }
            }
        }
        guard !all.isEmpty else { return [fallback] }

        let featuredRefs = [
            "john-1-5", "john-3-16", "john-14-27", "matthew-5-8", "matthew-6-33",
            "luke-1-37", "romans-8-28", "1corinthians-13-4", "philippians-4-13",
            "psalms-22-1", "psalms-26-1", "psalms-50-12", "proverbs-3-5"
        ]
        let featured = featuredRefs.compactMap { id in all.first { $0.id == id } }
        let compact = all.filter { $0.text.count <= 190 }
        let every = max(1, compact.count / 90)
        let sampled = compact.enumerated().compactMap { index, choice in
            index % every == 0 ? choice : nil
        }
        var seen = Set<String>()
        return (featured + sampled).filter { seen.insert($0.id).inserted }.prefix(120).map { $0 }
    }

    static func allChoices(from store: ScriptureStore) -> [ProfileVerseChoice] {
        store.testaments.flatMap { testament in
            testament.books.flatMap { book in
                book.chapters.flatMap { chapter in
                    chapter.verses.map { ProfileVerseChoice(book: book, chapter: chapter, verse: $0) }
                }
            }
        }
    }
}

// MARK: - Notebook

enum NotebookCategory: String, Codable, CaseIterable, Identifiable {
    case confession
    case scripture
    case gerontikon
    case didaches
    case prayer
    case personal

    var id: String { rawValue }

    var title: String {
        switch self {
        case .confession: "Εξομολόγηση"
        case .scripture: "Αγία Γραφή"
        case .gerontikon: "Γεροντικόν"
        case .didaches: "Διδαχές"
        case .prayer: "Προσευχή"
        case .personal: "Προσωπικά"
        }
    }

    var icon: String {
        switch self {
        case .confession: "heart.text.square.fill"
        case .scripture: "book.closed.fill"
        case .gerontikon: "quote.bubble.fill"
        case .didaches: "waveform"
        case .prayer: "flame.fill"
        case .personal: "pencil.and.scribble"
        }
    }

    var tint: Color {
        switch self {
        case .confession: Color(red: 0.66, green: 0.35, blue: 0.78)
        case .scripture: Paper.gold
        case .gerontikon: Color(red: 0.74, green: 0.49, blue: 0.25)
        case .didaches: Color(red: 0.36, green: 0.62, blue: 0.93)
        case .prayer: Color(red: 0.95, green: 0.43, blue: 0.25)
        case .personal: Color(red: 0.34, green: 0.71, blue: 0.58)
        }
    }
}

enum NotebookAnchorKind: String, Codable, CaseIterable, Identifiable {
    case scripture
    case gerontikon
    case didaches
    case prayer
    case personal

    var id: String { rawValue }

    var title: String {
        switch self {
        case .scripture: "Αγία Γραφή"
        case .gerontikon: "Γεροντικόν"
        case .didaches: "Διδαχές"
        case .prayer: "Προσευχή"
        case .personal: "Προσωπικό"
        }
    }

    var icon: String {
        switch self {
        case .scripture: "book.closed.fill"
        case .gerontikon: "quote.bubble.fill"
        case .didaches: "waveform"
        case .prayer: "flame.fill"
        case .personal: "paperclip"
        }
    }

    var tint: Color {
        switch self {
        case .scripture: Paper.gold
        case .gerontikon: Color(red: 0.74, green: 0.49, blue: 0.25)
        case .didaches: Color(red: 0.36, green: 0.62, blue: 0.93)
        case .prayer: Color(red: 0.95, green: 0.43, blue: 0.25)
        case .personal: Color(red: 0.34, green: 0.71, blue: 0.58)
        }
    }
}

struct NotebookAnchor: Codable, Hashable, Identifiable {
    var id = UUID()
    var kind: NotebookAnchorKind
    var title: String
    var excerpt: String
    var routeValue: String?
    var startTime: TimeInterval?
    var endTime: TimeInterval? = nil
    var audioUrl: String? = nil
    var contextTitle: String? = nil

    var cleanTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? kind.title : title
    }

    var cleanExcerpt: String {
        excerpt.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var scriptureRoute: ChapterRoute? {
        guard kind == .scripture, let routeValue else { return nil }
        let pieces = routeValue.split(separator: ":").map(String.init)
        guard pieces.count == 2, let chapter = Int(pieces[1]) else { return nil }
        return ChapterRoute(bookID: pieces[0], chapterNumber: chapter)
    }
}

struct NotebookNote: Codable, Hashable, Identifiable {
    var id = UUID()
    var title: String
    var body: String
    var category: NotebookCategory?
    var anchors: [NotebookAnchor]
    var createdAt: Date
    var updatedAt: Date

    static func blank(category: NotebookCategory? = nil) -> NotebookNote {
        NotebookNote(
            title: "",
            body: "",
            category: category,
            anchors: [],
            createdAt: Date(),
            updatedAt: Date()
        )
    }
}

@MainActor
final class NotebookStore: ObservableObject {
    static let shared = NotebookStore()

    @Published private(set) var notes: [NotebookNote] = []

    private let key = "klimax.notebook.notes.v1"

    private init() {
        load()
    }

    func notes(in category: NotebookCategory?) -> [NotebookNote] {
        let base = category.map { selected in notes.filter { $0.category == selected } } ?? notes
        return base.sorted { $0.updatedAt > $1.updatedAt }
    }

    func count(in category: NotebookCategory) -> Int {
        notes.filter { $0.category == category }.count
    }

    func note(id: UUID) -> NotebookNote? {
        notes.first { $0.id == id }
    }

    func upsert(_ note: NotebookNote) {
        var next = note
        let cleanTitle = next.title.trimmingCharacters(in: .whitespacesAndNewlines)
        next.title = cleanTitle.isEmpty ? "Άτιτλη σελίδα" : cleanTitle
        next.updatedAt = Date()

        if let index = notes.firstIndex(where: { $0.id == next.id }) {
            notes[index] = next
        } else {
            notes.insert(next, at: 0)
        }
        save()
        NotebookNoticeCenter.shared.show("Η σημείωση αποθηκεύτηκε")
    }

    func delete(_ note: NotebookNote) {
        notes.removeAll { $0.id == note.id }
        save()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([NotebookNote].self, from: data)
        else { return }
        notes = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(notes) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}

struct NotebookNotice: Identifiable {
    let id = UUID()
    let title: String
}

@MainActor
final class NotebookNoticeCenter: ObservableObject {
    static let shared = NotebookNoticeCenter()
    @Published var notice: NotebookNotice?

    private init() {}

    func show(_ title: String) {
        notice = NotebookNotice(title: title)
    }
}

struct NotebookSourceNoteDraft: Identifiable {
    let id = UUID()
    var title: String
    var category: NotebookCategory
    var anchor: NotebookAnchor
    var body: String = ""
}

struct NotebookSourceNoteSheet: View {
    @Environment(\.dismiss) private var dismiss
    let draft: NotebookSourceNoteDraft
    @State private var excerpt: String
    @State private var bodyText: String

    init(draft: NotebookSourceNoteDraft) {
        self.draft = draft
        _excerpt = State(initialValue: draft.anchor.excerpt)
        _bodyText = State(initialValue: draft.body)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 9) {
                        Label(draft.category.title, systemImage: draft.category.icon)
                            .font(.system(size: 12, weight: .black))
                            .tracking(2.5)
                            .foregroundStyle(draft.category.tint)

                        Text(draft.anchor.cleanTitle)
                            .font(.system(size: 23, weight: .heavy, design: .rounded))
                            .foregroundStyle(Paper.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("ΠΗΓΗ")
                            .font(.system(size: 11, weight: .black))
                            .tracking(3)
                            .foregroundStyle(Paper.gold)
                        TextEditor(text: $excerpt)
                            .font(.system(size: 17, weight: .regular, design: .serif))
                            .foregroundStyle(Paper.ink)
                            .lineSpacing(6)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 120)
                            .padding(12)
                            .background(Paper.card.opacity(0.72), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Paper.hairline, lineWidth: 1))
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("ΣΚΕΨΕΙΣ")
                            .font(.system(size: 11, weight: .black))
                            .tracking(3)
                            .foregroundStyle(Paper.gold)
                        TextEditor(text: $bodyText)
                            .font(.system(size: 18, weight: .regular, design: .serif))
                            .foregroundStyle(Paper.ink)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 210)
                            .padding(12)
                            .background(Paper.card.opacity(0.72), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Paper.hairline, lineWidth: 1))
                    }

                    Button {
                        save(body: "")
                    } label: {
                        Label("Αποθήκευση για αργότερα", systemImage: "tray.and.arrow.down")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(draft.category.tint)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(draft.category.tint.opacity(0.12), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(20)
            }
            .background(Paper.bg.ignoresSafeArea())
            .navigationTitle("Νέα σημείωση")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Άκυρο") { dismiss() }
                        .tint(Paper.ink)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Αποθήκευση") {
                        save(body: bodyText)
                    }
                    .fontWeight(.bold)
                    .tint(Paper.gold)
                }
            }
        }
    }

    private func save(body: String) {
        var anchor = draft.anchor
        let cleanExcerpt = excerpt.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanExcerpt.isEmpty {
            anchor.excerpt = cleanExcerpt
        }

        let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? anchor.cleanTitle : draft.title
        let note = NotebookNote(
            title: title,
            body: body.trimmingCharacters(in: .whitespacesAndNewlines),
            category: draft.category,
            anchors: [anchor],
            createdAt: Date(),
            updatedAt: Date()
        )
        NotebookStore.shared.upsert(note)
        dismiss()
    }
}

struct NotebookSummaryCard: View {
    @ObservedObject private var store = NotebookStore.shared

    private var latestNote: NotebookNote? {
        store.notes.sorted { $0.updatedAt > $1.updatedAt }.first
    }

    var body: some View {
        NavigationLink {
            NotebookView()
        } label: {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 15).fill(Paper.gold.opacity(0.09))
                        Image(systemName: "note.text")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(Gild.accentForeground)
                    }
                    .frame(width: 46, height: 46)

                    VStack(alignment: .leading, spacing: 5) {
                        Text("Σημειωματάριο")
                            .font(.system(size: 22, weight: .semibold, design: .serif))
                            .foregroundStyle(Paper.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                        Text("\(store.notes.count) \(store.notes.count == 1 ? "σελίδα" : "σελίδες")")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Paper.inkMute)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Paper.inkMute.opacity(0.75))
                }

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                        ForEach(NotebookCategory.allCases) { category in
                            NotebookMiniCategory(category: category, count: store.count(in: category))
                        }
                    }

                if let latestNote {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Τελευταία σημείωση")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Paper.inkMute)
                        Text(latestNote.title)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(Paper.ink)
                            .lineLimit(1)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Paper.card.opacity(0.62), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Paper.hairline, lineWidth: 1))
                }
            }
            .padding(20)
            .modifier(YouCardSurface())
            .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct NotebookMiniCategory: View {
    let category: NotebookCategory
    let count: Int

    var body: some View {
        VStack(spacing: 5) {
            HStack(spacing: 6) {
            Image(systemName: category.icon)
                .font(.system(size: 10, weight: .bold))
            Text("\(count)")
                .font(.system(size: 12, weight: .black))
            }
            Text(category.title).font(.system(size: 10, weight: .medium))
                .lineLimit(1).minimumScaleFactor(0.8)
        }
        .foregroundStyle(category.tint)
        .padding(.vertical, 7)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity)
        .background(category.tint.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }
}

struct NotebookView: View {
    var body: some View {
        NotebookHomeView()
    }
}

private struct NotebookCategoryFilterChip: View {
    let title: String
    let icon: String
    let tint: Color
    let count: Int
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                Text("\(count)")
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(selected ? tint : Paper.inkMute)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Paper.card.opacity(0.7), in: Capsule())
            }
            .foregroundStyle(selected ? .white : tint)
            .padding(.vertical, 10)
            .padding(.horizontal, 13)
            .background(selected ? tint : Paper.card.opacity(0.72), in: Capsule())
            .overlay(Capsule().stroke(selected ? Color.clear : Paper.hairline, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

private struct NotebookNoteCard: View {
    let note: NotebookNote

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .top, spacing: 12) {
                if let category = note.category {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(category.tint.opacity(0.14))
                        Image(systemName: category.icon)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(category.tint)
                    }
                    .frame(width: 45, height: 45)
                }

                VStack(alignment: .leading, spacing: 5) {
                    if let category = note.category {
                        Text(category.title)
                            .font(.system(size: 10, weight: .black))
                            .tracking(2.4)
                            .foregroundStyle(category.tint)
                    }
                    Text(note.title)
                        .font(.system(size: 21, weight: .heavy, design: .rounded))
                        .foregroundStyle(Paper.ink)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Paper.inkMute.opacity(0.72))
            }

            if !note.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(note.body)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Paper.inkMute)
                    .lineLimit(3)
            }

            if !note.anchors.isEmpty {
                HStack(spacing: 7) {
                    ForEach(note.anchors.prefix(3)) { anchor in
                        HStack(spacing: 5) {
                            Image(systemName: anchor.kind.icon)
                            Text(anchor.kind.title)
                        }
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(anchor.kind.tint)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 8)
                        .background(anchor.kind.tint.opacity(0.10), in: Capsule())
                    }
                }
            }
        }
        .padding(18)
        .profileLiquidGlass(cornerRadius: 24)
    }
}

private struct NotebookNoteDetailView: View {
    @ObservedObject private var store = NotebookStore.shared
    @Environment(\.dismiss) private var dismiss
    let noteID: UUID
    @State private var editingNote: NotebookNote?
    @State private var confirmingDelete = false

    private var note: NotebookNote? {
        store.note(id: noteID)
    }

    var body: some View {
        Group {
            if let note {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        VStack(alignment: .leading, spacing: 10) {
                            if let category = note.category {
                                Label(category.title, systemImage: category.icon)
                                    .font(.system(size: 12, weight: .black))
                                    .tracking(2.6)
                                    .foregroundStyle(category.tint)
                            }

                            Text(note.title)
                                .font(.system(size: 34, weight: .heavy, design: .rounded))
                                .foregroundStyle(Paper.ink)
                                .fixedSize(horizontal: false, vertical: true)

                            Text(note.updatedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(Paper.inkMute)
                        }
                        .padding(.horizontal, 4)

                        if !note.anchors.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("ΠΗΓΕΣ")
                                    .font(.system(size: 11, weight: .black))
                                    .tracking(3)
                                    .foregroundStyle(Paper.gold)

                                ForEach(note.anchors) { anchor in
                                    NotebookAnchorCard(anchor: anchor)
                                }
                            }
                        }

                        Text(note.body.isEmpty ? " " : note.body)
                            .font(.system(size: 18, weight: .regular, design: .serif))
                            .lineSpacing(7)
                            .foregroundStyle(Paper.ink)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(20)
                            .profileLiquidGlass(cornerRadius: 26)
                    }
                    .padding(.horizontal, KSpace.gutter)
                    .padding(.top, KSpace.lg)
                    .padding(.bottom, KSpace.xxl)
                }
                .background(Paper.bg.ignoresSafeArea())
                .navigationTitle("Σημείωση")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Button(role: .destructive) {
                            confirmingDelete = true
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 16, weight: .bold))
                        }
                        Button {
                            editingNote = note
                        } label: {
                            Image(systemName: "pencil")
                                .font(.system(size: 16, weight: .bold))
                        }
                        .tint(Paper.gold)
                    }
                }
                .alert("Διαγραφή σημείωσης;", isPresented: $confirmingDelete) {
                    Button("Άκυρο", role: .cancel) {}
                    Button("Διαγραφή", role: .destructive) {
                        store.delete(note)
                        dismiss()
                    }
                } message: {
                    Text("Η σελίδα θα αφαιρεθεί από το σημειωματάριο.")
                }
                .sheet(item: $editingNote) { note in
                    NotebookEditorSheet(note: note) { saved in
                        store.upsert(saved)
                    }
                    .presentationDetents([.large])
                }
            } else {
                ContentUnavailableView("Η σημείωση δεν υπάρχει", systemImage: "note.text")
                    .background(Paper.bg.ignoresSafeArea())
            }
        }
    }
}

struct NotebookAnchorCard: View {
    let anchor: NotebookAnchor

    var body: some View {
        switch anchor.kind {
        case .scripture:
            if let route = anchor.scriptureRoute {
                NavigationLink { ChapterReadingView(route: route) } label: { content }
                    .buttonStyle(.plain)
            } else {
                NavigationLink { ScriptureLibraryView() } label: { content }
                    .buttonStyle(.plain)
            }
        case .gerontikon:
            GerontikonAnchorButton(anchor: anchor) { content }
        case .didaches:
            didachesContent
        case .prayer:
            PrayerAnchorLink(anchor: anchor) { content }
        case .personal:
            content
        }
    }

    private var didachesContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            content

            HStack(spacing: 10) {
                NotebookClipPreviewButton(audioUrl: anchor.audioUrl, start: anchor.startTime ?? 0, end: anchor.endTime ?? ((anchor.startTime ?? 0) + 15))

                Button {
                    openFullHomily()
                } label: {
                    Label("Πλήρης ομιλία", systemImage: "arrow.up.forward")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(anchor.kind.tint, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(anchor.audioUrl.flatMap(URL.init(string:)) == nil)
                .opacity(anchor.audioUrl.flatMap(URL.init(string:)) == nil ? 0.5 : 1)
            }
            .padding(.horizontal, 2)
        }
    }

    private func openFullHomily() {
        guard let audioUrl = anchor.audioUrl else { return }
        let homily = Homily(
            id: anchor.routeValue ?? UUID().uuidString,
            title: anchor.cleanTitle,
            episodeNumber: nil,
            audioUrl: audioUrl,
            durationSeconds: anchor.endTime.map { Int($0) },
            hook: anchor.cleanExcerpt,
            isShort: nil,
            topic: anchor.contextTitle,
            youtubeVideoId: nil,
            mediaType: nil,
            seriesTitle: anchor.contextTitle
        )
        HomilyPlayer.shared.present(homily, context: anchor.contextTitle ?? "Διδαχές")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            HomilyPlayer.shared.seek(to: anchor.startTime ?? 0)
        }
    }

    private var content: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(anchor.kind.tint.opacity(0.14))
                Image(systemName: anchor.kind.icon)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(anchor.kind.tint)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(anchor.kind.title)
                        .font(.system(size: 10, weight: .black))
                        .tracking(2.4)
                        .foregroundStyle(anchor.kind.tint)
                    if let startTime = anchor.startTime {
                        Text(timeText(startTime))
                            .font(.system(size: 10, weight: .black))
                            .foregroundStyle(Paper.inkMute)
                    }
                }

                Text(anchor.cleanTitle)
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundStyle(Paper.ink)
                    .lineLimit(2)

                if !anchor.cleanExcerpt.isEmpty {
                    Text("«\(anchor.cleanExcerpt)»")
                        .font(.system(size: 15, design: .serif))
                        .foregroundStyle(Paper.inkMute)
                        .lineLimit(4)
                }
            }

            Spacer()

            if anchor.kind != .personal && anchor.kind != .didaches {
                Image(systemName: "arrow.up.forward")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(anchor.kind.tint)
            }
        }
        .padding(15)
        .background(Paper.card.opacity(0.64), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Paper.hairline, lineWidth: 1))
    }

    private func timeText(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}

private struct GerontikonAnchorButton<Label: View>: View {
    let anchor: NotebookAnchor
    let label: () -> Label
    @ObservedObject private var store = ShortStoriesStore.shared
    @State private var readerStories: [PatericStory] = []
    @State private var readerIndex = 0
    @State private var showingReader = false
    @State private var isOpening = false

    var body: some View {
        Button {
            Task { await openStory() }
        } label: {
            ZStack(alignment: .trailing) {
                label()
                if isOpening {
                    ProgressView()
                        .controlSize(.small)
                        .tint(anchor.kind.tint)
                        .padding(.trailing, 16)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isOpening)
        .task { await store.load() }
        .fullScreenCover(isPresented: $showingReader) {
            StoryReaderView(stories: readerStories, startIndex: readerIndex) {
                showingReader = false
            }
        }
    }

    private func openStory() async {
        guard !isOpening else { return }
        isOpening = true
        defer { isOpening = false }

        if store.stories.isEmpty {
            await store.load()
        }

        guard !store.stories.isEmpty else {
            NotebookNoticeCenter.shared.show("Δεν φορτώθηκε το Γεροντικόν")
            return
        }

        readerStories = store.stories
        if let id = anchor.routeValue,
           let index = store.stories.firstIndex(where: { $0.id == id }) {
            readerIndex = index
        } else {
            readerIndex = 0
        }
        showingReader = true
    }
}

private struct PrayerAnchorLink<Label: View>: View {
    let anchor: NotebookAnchor
    let label: () -> Label
    @State private var store = PrayerStore()

    private var route: PrayerRoute? {
        guard let routeValue = anchor.routeValue else { return nil }
        let pieces = routeValue.split(separator: ":").map(String.init)
        guard pieces.count == 2 else { return nil }
        guard let category = store.categories.first(where: { $0.id == pieces[0] }),
              let prayer = category.prayers.first(where: { $0.id == pieces[1] })
        else { return nil }
        return PrayerRoute(category: category, prayer: prayer)
    }

    var body: some View {
        Group {
            if let route {
                NavigationLink {
                    PrayerReadingView(route: route, categories: store.categories)
                } label: {
                    label()
                }
                .buttonStyle(.plain)
            } else {
                NavigationLink {
                    PrayerLibraryView()
                } label: {
                    label()
                }
                .buttonStyle(.plain)
            }
        }
        .task { await store.load() }
    }
}

private struct NotebookEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: NotebookNote
    @State private var showingAnchorComposer = false
    let onSave: (NotebookNote) -> Void

    init(note: NotebookNote, onSave: @escaping (NotebookNote) -> Void) {
        _draft = State(initialValue: note)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("ΤΙΤΛΟΣ")
                            .font(.system(size: 11, weight: .black))
                            .tracking(3)
                            .foregroundStyle(Paper.gold)
                        TextField("Τίτλος σημείωσης", text: $draft.title, axis: .vertical)
                            .font(.system(size: 24, weight: .heavy, design: .rounded))
                            .foregroundStyle(Paper.ink)
                            .padding(16)
                            .background(Paper.card.opacity(0.70), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("ΚΑΤΗΓΟΡΙΑ · ΠΡΟΑΙΡΕΤΙΚΗ")
                            .font(.system(size: 11, weight: .black))
                            .tracking(3)
                            .foregroundStyle(Paper.gold)
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            ForEach(NotebookCategory.allCases) { category in
                                Button {
                                    withAnimation(.easeInOut(duration: 0.18)) {
                                        draft.category = draft.category == category ? nil : category
                                    }
                                } label: {
                                    HStack(spacing: 9) {
                                        Image(systemName: category.icon)
                                        Text(category.title)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.78)
                                    }
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(draft.category == category ? .white : category.tint)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(draft.category == category ? category.tint : Paper.card.opacity(0.72), in: Capsule())
                                    .overlay(Capsule().stroke(draft.category == category ? Color.clear : Paper.hairline, lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("ΠΗΓΕΣ")
                                .font(.system(size: 11, weight: .black))
                                .tracking(3)
                                .foregroundStyle(Paper.gold)
                            Spacer()
                            Button {
                                showingAnchorComposer = true
                            } label: {
                                Label("Πηγή", systemImage: "plus")
                                    .font(.system(size: 13, weight: .bold))
                            }
                            .tint(Paper.gold)
                        }

                        if draft.anchors.isEmpty {
                            Text("Καμία πηγή")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Paper.inkMute)
                                .padding(16)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Paper.card.opacity(0.58), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        } else {
                            VStack(spacing: 9) {
                                ForEach(draft.anchors) { anchor in
                                    HStack(spacing: 10) {
                                        Image(systemName: anchor.kind.icon)
                                            .foregroundStyle(anchor.kind.tint)
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(anchor.cleanTitle)
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundStyle(Paper.ink)
                                                .lineLimit(1)
                                            Text(anchor.kind.title)
                                                .font(.system(size: 11, weight: .bold))
                                                .foregroundStyle(Paper.inkMute)
                                        }
                                        Spacer()
                                        Button(role: .destructive) {
                                            draft.anchors.removeAll { $0.id == anchor.id }
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                        }
                                    }
                                    .padding(13)
                                    .background(Paper.card.opacity(0.58), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("ΣΗΜΕΙΩΣΕΙΣ")
                            .font(.system(size: 11, weight: .black))
                            .tracking(3)
                            .foregroundStyle(Paper.gold)
                        TextEditor(text: $draft.body)
                            .font(.system(size: 18, weight: .regular, design: .serif))
                            .foregroundStyle(Paper.ink)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 230)
                            .padding(12)
                            .background(Paper.card.opacity(0.70), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    }
                }
                .padding(20)
            }
            .background(Paper.bg.ignoresSafeArea())
            .navigationTitle("Σελίδα")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Άκυρο") { dismiss() }
                        .tint(Paper.ink)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Αποθήκευση") {
                        onSave(draft)
                        dismiss()
                    }
                    .fontWeight(.bold)
                    .tint(Paper.gold)
                }
            }
            .sheet(isPresented: $showingAnchorComposer) {
                AnchorComposerSheet { anchor in
                    draft.anchors.append(anchor)
                }
                .presentationDetents([.medium, .large])
            }
        }
    }
}

struct AnchorComposerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ScriptureStore.self) private var scripture
    @State private var kind: NotebookAnchorKind = .scripture
    @State private var title = ""
    @State private var excerpt = ""
    let onAdd: (NotebookAnchor) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("ΕΙΔΟΣ")
                            .font(.system(size: 11, weight: .black))
                            .tracking(3)
                            .foregroundStyle(Paper.gold)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 9) {
                                ForEach(NotebookAnchorKind.allCases) { item in
                                    Button {
                                        withAnimation(.easeInOut(duration: 0.18)) { kind = item }
                                    } label: {
                                        HStack(spacing: 7) {
                                            Image(systemName: item.icon)
                                            Text(item.title)
                                        }
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(kind == item ? .white : item.tint)
                                        .padding(.vertical, 10)
                                        .padding(.horizontal, 13)
                                        .background(kind == item ? item.tint : Paper.card.opacity(0.72), in: Capsule())
                                        .overlay(Capsule().stroke(kind == item ? Color.clear : Paper.hairline, lineWidth: 1))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    switch kind {
                    case .scripture:
                        ScriptureSourcePicker(choices: ProfileVerseChoice.allChoices(from: scripture)) { choice in
                            onAdd(
                                NotebookAnchor(
                                    kind: .scripture,
                                    title: choice.reference,
                                    excerpt: choice.text,
                                    routeValue: choice.chapterRouteValue
                                )
                            )
                            dismiss()
                        }
                    case .gerontikon:
                        GerontikonSourcePicker { story in
                            onAdd(
                                NotebookAnchor(
                                    kind: .gerontikon,
                                    title: story.reference ?? story.source ?? story.theme ?? "Γεροντικόν",
                                    excerpt: story.text,
                                    routeValue: story.id
                                )
                            )
                            dismiss()
                        }
                    case .didaches:
                        DidachesSourcePicker { homily, start, end in
                            onAdd(
                                NotebookAnchor(
                                    kind: .didaches,
                                    title: homily.title,
                                    excerpt: homily.hook ?? "Απόσπασμα \(timeLabel(start)) έως \(timeLabel(end))",
                                    routeValue: homily.id,
                                    startTime: start,
                                    endTime: end,
                                    audioUrl: homily.audioUrl,
                                    contextTitle: homily.subject
                                )
                            )
                            dismiss()
                        }
                    case .prayer:
                        PrayerSourcePicker { category, prayer in
                            onAdd(
                                NotebookAnchor(
                                    kind: .prayer,
                                    title: prayer.titleGreek,
                                    excerpt: prayer.body.first ?? category.titleGreek,
                                    routeValue: "\(category.id):\(prayer.id)"
                                )
                            )
                            dismiss()
                        }
                    case .personal:
                        PersonalSourceComposer(title: $title, excerpt: $excerpt) {
                            onAdd(
                                NotebookAnchor(
                                    kind: .personal,
                                    title: title,
                                    excerpt: excerpt
                                )
                            )
                            dismiss()
                        }
                    }
                }
                .padding(20)
            }
            .background(Paper.bg.ignoresSafeArea())
            .navigationTitle("Νέα πηγή")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Άκυρο") { dismiss() }
                }
            }
        }
    }
}

private func notebookSearchKey(_ text: String) -> String {
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

private struct ScriptureSourcePicker: View {
    let choices: [ProfileVerseChoice]
    let onPick: (ProfileVerseChoice) -> Void
    @State private var query = ""

    private var visibleChoices: [ProfileVerseChoice] {
        let needle = notebookSearchKey(query)
        guard !needle.isEmpty else { return Array(choices.prefix(40)) }
        return choices.filter { notebookSearchKey("\($0.reference) \($0.text)").contains(needle) }.prefix(80).map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            NotebookPickerSearchField(text: $query, placeholder: "Αναζήτηση σε χωρία")
            LazyVStack(spacing: 10) {
                ForEach(visibleChoices) { choice in
                    Button { onPick(choice) } label: {
                        NotebookSourceRow(
                            icon: "book.closed.fill",
                            tint: Paper.gold,
                            title: choice.reference,
                            subtitle: choice.text
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct GerontikonSourcePicker: View {
    @ObservedObject private var store = ShortStoriesStore.shared
    @State private var query = ""
    let onPick: (PatericStory) -> Void

    private var visibleStories: [PatericStory] {
        let needle = notebookSearchKey(query)
        guard !needle.isEmpty else { return Array(store.stories.prefix(40)) }
        return store.stories.filter {
            notebookSearchKey("\($0.theme ?? "") \($0.text) \($0.reference ?? "")").contains(needle)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            NotebookPickerSearchField(text: $query, placeholder: "Αναζήτηση στο Γεροντικόν")
            if store.isLoading && store.stories.isEmpty {
                ProgressView("Φόρτωση…")
                    .tint(Paper.gold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(visibleStories) { story in
                        Button { onPick(story) } label: {
                            NotebookSourceRow(
                                icon: "quote.bubble.fill",
                                tint: NotebookAnchorKind.gerontikon.tint,
                                title: story.reference ?? story.source ?? story.theme ?? "Γεροντικόν",
                                subtitle: story.text
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .task { await store.load() }
    }
}

private struct DidachesSourcePicker: View {
    @ObservedObject private var store = HomilyStore.shared
    @State private var query = ""
    @State private var selectedHomily: Homily?
    @State private var start: Double = 0
    @State private var length: Double = 15
    let onPick: (Homily, Double, Double) -> Void

    private var allHomilies: [Homily] {
        store.subjects.flatMap(\.episodes).filter { !$0.isVideo && $0.audioUrl != nil }
    }

    private var visibleHomilies: [Homily] {
        let needle = notebookSearchKey(query)
        guard !needle.isEmpty else { return Array(allHomilies.prefix(50)) }
        return allHomilies.filter { notebookSearchKey("\($0.title) \($0.subject) \($0.hook ?? "")").contains(needle) }
    }

    private var duration: Double {
        Double(selectedHomily?.durationSeconds ?? 0)
    }

    private var end: Double {
        min(duration > 0 ? duration : start + length, start + length)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            NotebookPickerSearchField(text: $query, placeholder: "Αναζήτηση στις Διδαχές")

            if let selectedHomily {
                VStack(alignment: .leading, spacing: 14) {
                    NotebookSourceRow(
                        icon: "waveform",
                        tint: NotebookAnchorKind.didaches.tint,
                        title: selectedHomily.title,
                        subtitle: selectedHomily.subject
                    )

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Αρχή")
                            Spacer()
                            Text(timeLabel(start))
                        }
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Paper.inkMute)
                        Slider(value: $start, in: 0...max(1, max(duration - 5, 1)), step: 1)
                            .tint(NotebookAnchorKind.didaches.tint)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Διάρκεια")
                            Spacer()
                            Text("\(timeLabel(start)) έως \(timeLabel(end))")
                        }
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Paper.inkMute)
                        Slider(value: $length, in: 5...max(5, min(60, max(duration - start, 5))), step: 1)
                            .tint(NotebookAnchorKind.didaches.tint)
                    }

                    HStack(spacing: 10) {
                        NotebookClipPreviewButton(audioUrl: selectedHomily.audioUrl, start: start, end: end)
                        Button {
                            onPick(selectedHomily, start, end)
                        } label: {
                            Label("Προσθήκη", systemImage: "plus")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                                .background(NotebookAnchorKind.didaches.tint, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(15)
                .profileLiquidGlass(cornerRadius: 22)

                Button {
                    withAnimation(.easeInOut(duration: 0.18)) { self.selectedHomily = nil }
                } label: {
                    Label("Άλλη ομιλία", systemImage: "chevron.left")
                        .font(.system(size: 13, weight: .bold))
                }
                .tint(Paper.gold)
            } else if store.isLoading && store.subjects.isEmpty {
                ProgressView("Φόρτωση…")
                    .tint(Paper.gold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(visibleHomilies) { homily in
                        Button {
                            let duration = Double(homily.durationSeconds ?? 0)
                            start = min(PlaybackProgress.seconds(for: homily.id), max(0, duration - 15))
                            length = 15
                            withAnimation(.easeInOut(duration: 0.18)) { selectedHomily = homily }
                        } label: {
                            NotebookSourceRow(
                                icon: "waveform",
                                tint: NotebookAnchorKind.didaches.tint,
                                title: homily.title,
                                subtitle: "\(homily.subject)  \(timeLabel(Double(homily.durationSeconds ?? 0)))"
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .task { if store.subjects.isEmpty { await store.load() } }
    }
}

private struct PrayerSourcePicker: View {
    @State private var store = PrayerStore()
    @State private var query = ""
    let onPick: (PrayerCategory, Prayer) -> Void

    private var visiblePairs: [(PrayerCategory, Prayer)] {
        let pairs = store.categories.flatMap { category in
            category.prayers.map { (category, $0) }
        }
        let needle = notebookSearchKey(query)
        guard !needle.isEmpty else { return Array(pairs.prefix(50)) }
        return pairs.filter { category, prayer in
            notebookSearchKey("\(category.titleGreek) \(prayer.titleGreek) \(prayer.body.joined(separator: " "))").contains(needle)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            NotebookPickerSearchField(text: $query, placeholder: "Αναζήτηση στις Προσευχές")
            if store.isLoading && store.categories.isEmpty {
                ProgressView("Φόρτωση…")
                    .tint(Paper.gold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(Array(visiblePairs.enumerated()), id: \.element.1.id) { _, pair in
                        let category = pair.0
                        let prayer = pair.1
                        Button { onPick(category, prayer) } label: {
                            NotebookSourceRow(
                                icon: "flame.fill",
                                tint: NotebookAnchorKind.prayer.tint,
                                title: prayer.titleGreek,
                                subtitle: category.titleGreek
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .task { await store.load() }
    }
}

private struct PersonalSourceComposer: View {
    @Binding var title: String
    @Binding var excerpt: String
    let onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Τίτλος", text: $title)
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(Paper.ink)
                .padding(15)
                .background(Paper.card.opacity(0.70), in: RoundedRectangle(cornerRadius: 18, style: .continuous))

            TextField("Απόσπασμα", text: $excerpt, axis: .vertical)
                .lineLimit(4...8)
                .font(.system(size: 16, design: .serif))
                .foregroundStyle(Paper.ink)
                .padding(15)
                .background(Paper.card.opacity(0.70), in: RoundedRectangle(cornerRadius: 18, style: .continuous))

            Button(action: onAdd) {
                Label("Προσθήκη", systemImage: "plus")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(NotebookAnchorKind.personal.tint, in: Capsule())
            }
            .buttonStyle(.plain)
        }
    }
}

private struct NotebookPickerSearchField: View {
    @Binding var text: String
    let placeholder: String

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Paper.inkMute)
            TextField(placeholder, text: $text)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Paper.ink)
                .autocorrectionDisabled()
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Paper.inkMute.opacity(0.75))
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(Paper.card.opacity(0.70), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 17, style: .continuous).stroke(Paper.hairline, lineWidth: 1))
    }
}

private struct NotebookSourceRow: View {
    let icon: String
    let tint: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(tint.opacity(0.14))
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(tint)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundStyle(Paper.ink)
                    .lineLimit(2)
                Text(subtitle)
                    .font(.system(size: 14, weight: .semibold, design: .serif))
                    .foregroundStyle(Paper.inkMute)
                    .lineLimit(3)
            }

            Spacer(minLength: 0)
        }
        .padding(15)
        .background(Paper.card.opacity(0.64), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Paper.hairline, lineWidth: 1))
    }
}

private struct NotebookClipPreviewButton: View {
    let audioUrl: String?
    let start: Double
    let end: Double
    @State private var player: AVPlayer?
    @State private var isPlaying = false
    @State private var stopTask: Task<Void, Never>?

    var body: some View {
        Button {
            isPlaying ? stop() : play()
        } label: {
            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(NotebookAnchorKind.didaches.tint, in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(audioUrl.flatMap(URL.init(string:)) == nil)
        .opacity(audioUrl.flatMap(URL.init(string:)) == nil ? 0.45 : 1)
        .onDisappear { stop() }
    }

    private func play() {
        guard let audioUrl, let url = URL(string: audioUrl) else { return }
        stop()
        let player = AVPlayer(url: url)
        self.player = player
        player.seek(to: CMTime(seconds: start, preferredTimescale: 600))
        player.play()
        isPlaying = true
        let duration = max(1, end - start)
        stopTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            await MainActor.run { stop() }
        }
    }

    private func stop() {
        stopTask?.cancel()
        stopTask = nil
        player?.pause()
        player = nil
        isPlaying = false
    }
}

/// Static shared surface for the personal library, with the app's adaptive
/// palette. Keeps large scrolling collections free of per-card glass effects.
struct YouCardSurface: ViewModifier {
    var cornerRadius: CGFloat = 24
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .background(shape.fill(Paper.card)
                .overlay(shape.fill(LinearGradient(colors: [Paper.gold.opacity(0.025), .clear],
                    startPoint: .topLeading, endPoint: .bottomTrailing))))
            .overlay(shape.stroke(Paper.hairline, lineWidth: 0.8))
    }
}

extension View {
    func profileLiquidGlass(cornerRadius: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return self
            .background(
                shape.fill(
                    LinearGradient(
                        colors: [
                            Color.adaptive(Color(red: 0.80, green: 0.91, blue: 1.0).opacity(0.24),
                                           Color(red: 0.10, green: 0.15, blue: 0.23).opacity(0.72)),
                            Paper.card,
                            Paper.gold.opacity(0.07)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            )
            .overlay(
                shape.stroke(
                    LinearGradient(
                        colors: [
                            Color.adaptive(.white.opacity(0.72), Color(red: 0.50, green: 0.66, blue: 0.88).opacity(0.28)),
                            Paper.hairline.opacity(0.72),
                            Paper.gold.opacity(0.16)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
            )
    }
}

#Preview("Profile") {
    NavigationStack {
        ProfileView()
            .environment(ScriptureStore())
    }
}
