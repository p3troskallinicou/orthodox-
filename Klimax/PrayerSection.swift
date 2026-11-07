//
//  PrayerSection.swift  ·  Klimax — Προσευχή / Prayer
//  ───────────────────────────────────────────────────────────────────────────
//  THE WHOLE PRAYER SCREEN, IN ONE FILE.
//
//  This is app CODE (the screen). You add it to the project ONCE and never
//  touch it again. The prayer CONTENT lives in Sanity — and in a bundled
//  prayers.json "seed" — exactly like Scripture. So from now on you update
//  prayers with the SAME Terminal/Sanity step you already use for the Bible,
//  never by editing code.
//
//  The bundled prayers.json is loaded first, so every prayer is available on a
//  clean installation with no connection. A newer cache and Sanity refresh may
//  then update that already-visible local corpus.
//
//  IN-TEXT LINKS (new): any paragraph in a prayer's body written as
//      @link:TARGET_ID|Visible label
//  is shown as a tappable gold panel that opens the prayer whose id is
//  TARGET_ID (e.g. @link:chairetismoi-theotokou|Χαιρετισμοὶ τῆς Θεοτόκου).
//  This is how the Μικρὸν Ἀπόδειπνον jumps to the Χαιρετισμοί and back.
//

import SwiftUI
import Observation

// ===========================================================================
// MARK: - Models  (match prayers.json and the Sanity result shape)
// ===========================================================================

struct PrayerData: Codable {
    let schemaVersion: Int?
    let language: String?
    let categories: [PrayerCategory]
}

struct PrayerCategory: Codable, Identifiable, Hashable {
    let id: String
    let titleGreek: String
    let titleEnglish: String?
    let subtitle: String?
    let prayers: [Prayer]
    static func == (l: Self, r: Self) -> Bool { l.id == r.id }
    func hash(into h: inout Hasher) { h.combine(id) }
}

struct Prayer: Codable, Identifiable, Hashable {
    let id: String
    let titleGreek: String
    let titleEnglish: String?
    let attribution: String?
    let rubric: String?
    let season: String?
    let source: String?
    let sourceUrl: String?
    let scriptureRef: String?
    let status: String?
    let body: [String]
    let anchors: [String: Int]?

    init(
        id: String,
        titleGreek: String,
        titleEnglish: String?,
        attribution: String?,
        rubric: String?,
        season: String?,
        source: String?,
        sourceUrl: String?,
        scriptureRef: String?,
        status: String?,
        body: [String],
        anchors: [String: Int]? = nil
    ) {
        self.id = id
        self.titleGreek = titleGreek
        self.titleEnglish = titleEnglish
        self.attribution = attribution
        self.rubric = rubric
        self.season = season
        self.source = source
        self.sourceUrl = sourceUrl
        self.scriptureRef = scriptureRef
        self.status = status
        self.body = body
        self.anchors = anchors
    }
    static func == (l: Self, r: Self) -> Bool { l.id == r.id }
    func hash(into h: inout Hasher) { h.combine(id) }

    var state: String { status ?? "complete" }
    var isReadable: Bool { state == "complete" && !body.isEmpty }
    var visibleAttribution: String? {
        guard let attribution, !attribution.isEmpty,
              !attribution.localizedCaseInsensitiveContains("orthodox-prayer-book.org") else {
            return nil
        }
        return attribution
    }
    var visibleSource: String? {
        guard let source, !source.isEmpty,
              !source.localizedCaseInsensitiveContains("orthodox-prayer-book.org") else {
            return nil
        }
        return source
    }
}

struct PrayerRoute: Hashable { let category: PrayerCategory; let prayer: Prayer }

private struct SundayOfficeCorpus: Decodable {
    let year: Int
    let strings: [String]
    let entries: [SundayOfficeEntry]

    static func loadAvailable() throws -> [Int: SundayOfficeCorpus] {
        let urls = Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: nil) ?? []
        let corpora = try urls
            .filter { $0.deletingPathExtension().lastPathComponent.hasPrefix("sunday-offices-") }
            .map { try JSONDecoder().decode(Self.self, from: Data(contentsOf: $0)) }
        guard !corpora.isEmpty else {
            throw NSError(domain: "Klimax", code: 22,
                userInfo: [NSLocalizedDescriptionKey: "Το ημερολόγιο Εσπερινού και Όρθρου δεν βρέθηκε."])
        }
        return Dictionary(uniqueKeysWithValues: corpora.map { ($0.year, $0) })
    }
}

private struct SundayOfficeEntry: Decodable, Identifiable {
    let date: String
    let echos: Int?
    let eothinon: Int?
    let vespers: DailyOfficeText
    let orthros: DailyOfficeText

    var id: String { date }
}

private struct DailyOfficeText: Decodable {
    let code: String
    let sourceDate: String
    let title: String
    let body: [Int]

    enum CodingKeys: String, CodingKey {
        case code, title, body
        case sourceDate = "source_date"
    }
}

private enum SundayOfficeKind {
    case vespers, orthros

    init?(prayerID: String) {
        switch prayerID {
        case "goarch-vespers-ordinary": self = .vespers
        case "goarch-matins-ordinary": self = .orthros
        default: return nil
        }
    }

    func service(from entry: SundayOfficeEntry) -> DailyOfficeText {
        switch self { case .vespers: entry.vespers; case .orthros: entry.orthros }
    }

    func body(from entry: SundayOfficeEntry, corpus: SundayOfficeCorpus) -> [String] {
        service(from: entry).body.compactMap { corpus.strings.indices.contains($0) ? corpus.strings[$0] : nil }
    }

    var scheduledKind: ScheduledServiceKind {
        switch self { case .vespers: .vespers; case .orthros: .orthros }
    }
}

private struct PrayerSearchResult: Identifiable, Hashable {
    let paragraphIndex: Int
    let startOffset: Int
    let endOffset: Int
    let ordinal: Int

    var id: String { "prayer-match-\(paragraphIndex)-\(startOffset)-\(ordinal)" }
}

// ===========================================================================
// MARK: - Store  (bundled seed → cache → optional Sanity refresh)
// ===========================================================================

@Observable
final class PrayerStore {
    private(set) var categories: [PrayerCategory] = []
    private(set) var isLoading = false
    private(set) var loadError: String?

    private static let projectID = "uqaka7yh"      // Klimax Sanity project
    private static let dataset   = "production"
    // Texts suppressed either for rights review or because they duplicate the
    // single Akathist text already included in the Salutations collection.
    private static let suppressedPrayerIDs: Set<String> = [
        "orthodox-prayer-book-paraklesis-agiou-demetriou",
        "orthodox-prayer-book-paraklesis-agiou-partheniou",
        "orthodox-prayer-book-xairetistirioi-oikoi-panagias-gorgoipikoou",
        "orthodox-prayer-book-staseis-xairetismwn"
    ]
    // These bundled records drive local calendar composition and must also
    // replace older readable copies that may remain in Sanity or the cache.
    private static let authoritativeBundledPrayerIDs: Set<String> = [
        "goarch-vespers-ordinary",
        "goarch-matins-ordinary"
    ]

    func load() async {
        guard categories.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }

        // 1) Always publish the app-bundled corpus before the first suspension
        // point. This is the clean-install, airplane-mode source of truth.
        do {
            let bundled = try Self.loadBundled()
            categories = bundled.categories
            loadError = nil
        } catch {
            loadError = "Δεν φορτώθηκαν οι προσευχές: \(error.localizedDescription)"
        }

        // 2) A previous refresh may contain editorial updates. The merge keeps
        // every bundled prayer, so a stale or partial cache cannot remove one.
        if let cached = Self.loadCache(), !cached.categories.isEmpty {
            let resolved = Self.withBundledMissingContent(cached)
            categories = resolved.categories
            loadError = nil
        }

        // 3) Refresh opportunistically. Failure never hides the local corpus.
        do {
            let live = try await Self.fetchFromSanity()
            if !live.categories.isEmpty {
                let resolved = Self.withBundledMissingContent(live)
                categories = resolved.categories
                loadError = nil
                Self.saveCache(resolved)
            }
        } catch {
            if categories.isEmpty {
                loadError = "Δεν φορτώθηκαν οι προσευχές: \(error.localizedDescription)"
            }
        }
    }

    // One GROQ query that returns prayers already shaped like PrayerData.
    private struct SanityResult: Codable { let result: PrayerData }
    private static func fetchFromSanity() async throws -> PrayerData {
        let groq = """
        {"schemaVersion":1,"language":"grc-polytonic","categories":\
        *[_type=="prayerCategory"]|order(order)\
        {"id":categoryId,titleGreek,titleEnglish,subtitle,prayers}}
        """
        let encoded = groq.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ""
        guard let url = URL(string:
            "https://\(projectID).apicdn.sanity.io/v2021-06-07/data/query/\(dataset)?query=\(encoded)")
        else { throw URLError(.badURL) }
        var req = URLRequest(url: url); req.timeoutInterval = 30
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200
        else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode(SanityResult.self, from: data).result
    }

    static func loadBundled() throws -> PrayerData {
        guard let url = Bundle.main.url(forResource: "prayers", withExtension: "json") else {
            throw NSError(domain: "Klimax", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "prayers.json not in the app bundle"])
        }
        return try JSONDecoder().decode(PrayerData.self, from: Data(contentsOf: url))
    }

    private static func withBundledMissingContent(_ data: PrayerData) -> PrayerData {
        guard let bundled = try? loadBundled() else { return data }
        let bundledByID = Dictionary(uniqueKeysWithValues: bundled.categories.map { ($0.id, $0) })
        var didChange = false
        var categories = data.categories.map { category in
            let permittedPrayers = category.prayers.filter {
                !suppressedPrayerIDs.contains($0.id)
            }
            if permittedPrayers.count != category.prayers.count { didChange = true }
            guard let bundledCategory = bundledByID[category.id] else {
                return PrayerCategory(
                    id: category.id,
                    titleGreek: category.titleGreek,
                    titleEnglish: category.titleEnglish,
                    subtitle: category.subtitle,
                    prayers: permittedPrayers
                )
            }
            let bundledPrayersByID = Dictionary(
                uniqueKeysWithValues: bundledCategory.prayers.map { ($0.id, $0) }
            )
            let upgradedPrayers = permittedPrayers.map { existing in
                guard let bundledPrayer = bundledPrayersByID[existing.id],
                      bundledPrayer.isReadable else {
                    return existing
                }
                if existing.id.hasPrefix("orthodox-prayer-book-")
                    || authoritativeBundledPrayerIDs.contains(existing.id) {
                    if existing.body != bundledPrayer.body ||
                        existing.attribution != bundledPrayer.attribution ||
                        existing.rubric != bundledPrayer.rubric ||
                        existing.source != bundledPrayer.source ||
                        existing.status != bundledPrayer.status {
                        didChange = true
                    }
                    return bundledPrayer
                }
                guard !existing.isReadable else { return existing }
                didChange = true
                return bundledPrayer
            }
            let existingPrayerIDs = Set(upgradedPrayers.map(\.id))
            let missingPrayers = bundledCategory.prayers.filter { !existingPrayerIDs.contains($0.id) }
            if !missingPrayers.isEmpty { didChange = true }
            let mergedPrayers = upgradedPrayers + missingPrayers
            let mergedByID = Dictionary(uniqueKeysWithValues: mergedPrayers.map { ($0.id, $0) })
            let bundledPrayerIDs = Set(bundledCategory.prayers.map(\.id))
            let orderedPrayers = bundledCategory.prayers.compactMap { mergedByID[$0.id] }
                + mergedPrayers.filter { !bundledPrayerIDs.contains($0.id) }
            if orderedPrayers.map(\.id) != mergedPrayers.map(\.id) { didChange = true }
            if category.titleGreek != bundledCategory.titleGreek ||
                category.titleEnglish != bundledCategory.titleEnglish ||
                category.subtitle != bundledCategory.subtitle {
                didChange = true
            }
            return PrayerCategory(
                id: category.id,
                titleGreek: bundledCategory.titleGreek,
                titleEnglish: bundledCategory.titleEnglish,
                subtitle: bundledCategory.subtitle,
                prayers: orderedPrayers
            )
        }

        let existingCategoryIDs = Set(categories.map(\.id))
        let missingCategories = bundled.categories.filter { !existingCategoryIDs.contains($0.id) }
        if !missingCategories.isEmpty {
            didChange = true
            categories.append(contentsOf: missingCategories)
        }

        guard didChange else { return data }
        return PrayerData(
            schemaVersion: data.schemaVersion ?? bundled.schemaVersion,
            language: data.language ?? bundled.language,
            categories: categories
        )
    }

    private static var cacheURL: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("prayers_cache.json")
    }
    private static func saveCache(_ d: PrayerData) {
        if let data = try? JSONEncoder().encode(d) { try? data.write(to: cacheURL) }
    }
    private static func loadCache() -> PrayerData? {
        guard let data = try? Data(contentsOf: cacheURL) else { return nil }
        return try? JSONDecoder().decode(PrayerData.self, from: data)
    }
}

// ===========================================================================
// MARK: - Library (tab root)
// ===========================================================================

struct PrayerLibraryView: View {
    @State private var store = PrayerStore()
    @State private var selectedSection: PrayerRootSection = .prayers
    @State private var headerCondensed = false

    var body: some View {
        ZStack {
            AppAtmosphere().ignoresSafeArea()

            sectionContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea(.container, edges: .bottom)

            VStack {
                sectionMenu
                Spacer()
            }
            .zIndex(1)
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 8)
                .onChanged { value in
                    let shouldCondense = value.translation.height < -6
                    let shouldExpand = value.translation.height > 18
                    guard shouldCondense || shouldExpand else { return }
                    let nextValue = shouldCondense
                    guard headerCondensed != nextValue else { return }
                    withAnimation(.smooth(duration: 0.28)) {
                        headerCondensed = nextValue
                    }
                }
        )
        .background(Color.clear)
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(for: PrayerCategory.self) { PrayerCategoryView(category: $0) }
        // Pass the loaded categories so the reader can resolve in-text @link: jumps.
        .navigationDestination(for: PrayerRoute.self) {
            PrayerReadingView(route: $0, categories: store.categories)
        }
        .task { await store.load() }
    }

    @ViewBuilder
    private var sectionContent: some View {
        switch selectedSection {
        case .prayers:
            categoryLibrary(
                categories: categories(withIDs: [
                    "enarxi", "euches-trapezis", "akolouthiai",
                    "theia-metalipsi"
                ]),
                title: "Προσευχή",
                subtitle: "Ἀδιαλείπτως προσεύχεσθε",
                showsIllustration: true,
                includesDiptycha: true
            )
        case .services:
            categoryLibrary(
                categories: categories(withIDs: [
                    "orologion", "mystiria", "parakliseis",
                    "megali-evdomada", "theotokos"
                ]),
                title: "Ακολουθίες",
                subtitle: "Λατρευτικές ακολουθίες της Εκκλησίας",
                includesDivineLiturgy: true
            )
        case .psalter:
            categoryLibrary(
                categories: categories(withIDs: ["psaltirion"]),
                title: "Ψαλτήριον",
                subtitle: "Κ΄ Καθίσματα του κειμένου των Εβδομήκοντα"
            )
        }
    }

    private func categories(withIDs ids: Set<String>) -> [PrayerCategory] {
        store.categories.filter { ids.contains($0.id) }
    }

    private func categoryLibrary(
        categories: [PrayerCategory],
        title: String,
        subtitle: String,
        showsIllustration: Bool = false,
        includesDivineLiturgy: Bool = false,
        includesDiptycha: Bool = false
    ) -> some View {
        ZStack {
            Color.clear
            if store.categories.isEmpty && store.isLoading {
                ProgressView().tint(Paper.gold)
            } else if store.categories.isEmpty, let err = store.loadError {
                VStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 26)).foregroundStyle(Paper.gold)
                    Text(err).font(.system(size: 13)).foregroundStyle(Paper.inkMute)
                        .multilineTextAlignment(.center).padding(.horizontal, 40)
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 14) {
                        libraryHeader(title: title, subtitle: subtitle, showsIllustration: showsIllustration)

                        if includesDiptycha, let document = DeisisCatalog.document {
                            NavigationLink {
                                DiptychaView(document: document)
                            } label: {
                                DiptychaFeatureRow()
                            }
                            .buttonStyle(.plain)

                            prayerListDivider
                        }

                        if includesDivineLiturgy {
                            NavigationLink {
                                DivineLiturgyView(date: LiturgicalDate.nextSunday(from: Date()))
                            } label: {
                                PrayerFeatureRow(
                                    icon: "cross.fill",
                                    title: "Θεία Λειτουργία",
                                    subtitle: "Θεία Λειτουργία της Κυριακής"
                                )
                            }
                            .buttonStyle(.plain)
                        }

                        LazyVGrid(columns: categories.count == 1 ? [GridItem(.flexible())] : [GridItem(.adaptive(minimum: 145), spacing: 12)], spacing: 12) {
                        ForEach(categories) { category in
                            if category.prayers.count == 1, let first = category.prayers.first {
                                NavigationLink(value: PrayerRoute(category: category, prayer: first)) {
                                    PrayerCategoryRow(category: category)
                                }
                                .buttonStyle(.plain)
                            } else if !category.prayers.isEmpty {
                                NavigationLink(value: category) {
                                    PrayerCategoryRow(category: category)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        }
                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 82)
                }
            }
        }
    }

    private var sectionMenu: some View {
        HStack(spacing: 14) {
            Menu {
                ForEach(PrayerRootSection.allCases) { section in
                    Button {
                        withAnimation(.smooth(duration: 0.30)) {
                            selectedSection = section
                        }
                    } label: {
                        Label {
                            Text(section.title)
                        } icon: {
                            Image(systemName: selectedSection == section ? "checkmark" : section.icon)
                        }
                    }
                }
            } label: {
                HStack(spacing: 9) {
                    Text(selectedSection.title)
                        .font(.system(size: headerCondensed ? 21 : 25, weight: .bold, design: .serif))
                        .foregroundStyle(Paper.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Paper.inkMute)
                        .padding(.top, 3)
                }
                .padding(.leading, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Επιλογή ενότητας πνευματικής βιβλιοθήκης")
            .accessibilityValue(selectedSection.title)

            Spacer(minLength: 8)

            Image(systemName: selectedSection.icon)
                .font(.system(size: headerCondensed ? 14 : 16, weight: .semibold))
                .foregroundStyle(Paper.gold)
                .frame(width: headerCondensed ? 36 : 42, height: headerCondensed ? 36 : 42)
                .logosSectionGlass()
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 20)
        .frame(height: headerCondensed ? 58 : 76)
        .background { AppHeaderSurface(condensed: headerCondensed) }
        .animation(.smooth(duration: 0.28), value: headerCondensed)
    }

    private func libraryHeader(title: String, subtitle: String, showsIllustration: Bool) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 28, weight: .semibold, design: .serif))
                .foregroundStyle(Paper.ink)
            Text(subtitle)
                .font(.system(size: 14, design: .serif))
                .foregroundStyle(Paper.inkMute)
                .fixedSize(horizontal: false, vertical: true)
            }.frame(maxWidth: .infinity, alignment: .leading)
            if showsIllustration {
                Image("prayerHeader")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 86, height: 94)
                    .accessibilityHidden(true)
            } else {
                Image(systemName: selectedSection.icon)
                    .font(.system(size: 30, weight: .light))
                    .foregroundStyle(Gild.accentForeground.opacity(0.75))
                    .frame(width: 70, height: 78)
                    .background(Paper.gold.opacity(0.06), in: RoundedRectangle(cornerRadius: 22))
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity).padding(.vertical, 12)
        .padding(.bottom, 6)
    }

    private var prayerListDivider: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(Paper.hairline)
                .frame(height: 1)

            Text("Προσευχές")
                .font(.system(size: 11, weight: .heavy))
                .textCase(.uppercase)
                .tracking(1.5)
                .foregroundStyle(Paper.inkMute)
                .fixedSize()

            Rectangle()
                .fill(Paper.hairline)
                .frame(height: 1)
        }
        .padding(.top, 4)
        .accessibilityAddTraits(.isHeader)
    }
}

private enum PrayerRootSection: String, CaseIterable, Identifiable {
    case prayers, services, psalter
    var id: String { rawValue }
    var title: String {
        switch self {
        case .prayers: return "Προσευχές"
        case .services: return "Ακολουθίες"
        case .psalter: return "Ψαλτήριον"
        }
    }
    var icon: String {
        switch self {
        case .prayers: return "flame.fill"
        case .services: return "books.vertical.fill"
        case .psalter: return "book.closed.fill"
        }
    }
}

/// Quiet, static surfaces shared by all three libraries. No per-card blur or
/// live glass compositor; the existing floating header remains unchanged.
private struct PrayerLibrarySurface: ViewModifier {
    var featured = false
    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Paper.card)
                    .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(LinearGradient(colors: [Paper.gold.opacity(featured ? 0.065 : 0.025), .clear],
                                             startPoint: .topLeading, endPoint: .bottomTrailing)))
            }
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(featured ? Paper.gold.opacity(0.16) : Paper.hairline, lineWidth: 0.8))
    }
}

private struct PrayerFeatureRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 15).fill(Paper.gold.opacity(0.09)).frame(width: 48, height: 48)
                Image(systemName: icon).font(.system(size: 20)).foregroundStyle(Gild.accentForeground)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 19, weight: .regular, design: .serif)).foregroundStyle(Paper.ink)
                Text(subtitle).font(.system(size: 12)).foregroundStyle(Paper.inkMute).lineLimit(2)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Paper.inkMute.opacity(0.6))
        }
        .padding(18)
        .modifier(PrayerLibrarySurface(featured: true))
    }
}

private struct DiptychaFeatureRow: View {
    var body: some View {
        HStack(spacing: 15) {
            ZStack {
                RoundedRectangle(cornerRadius: 17)
                    .fill(Paper.gold.opacity(0.09))
                    .frame(width: 52, height: 52)

                Image(systemName: "person.2.fill")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(Gild.accentForeground)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Προσωπική μνημόνευση")
                    .font(.system(size: 10, weight: .heavy))
                    .textCase(.uppercase)
                    .tracking(1.1)
                    .foregroundStyle(Gild.accentForeground)

                Text("Δίπτυχα")
                    .font(.system(size: 20, weight: .semibold, design: .serif))
                    .foregroundStyle(Paper.ink)

                Text("Τα ονόματα που μνημονεύεις στην προσευχή")
                    .font(.system(size: 12))
                    .foregroundStyle(Paper.inkMute)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(Gild.accentForeground)
        }
        .padding(.horizontal, 17)
        .padding(.vertical, 16)
        .modifier(PrayerLibrarySurface(featured: true))
        .accessibilityElement(children: .combine)
    }
}

private struct PrayerCategoryRow: View {
    let category: PrayerCategory
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: glyph(category.id)).font(.system(size: 20, weight: .regular))
                    .foregroundStyle(Gild.accentForeground)
                    .frame(width: 44, height: 44)
                    .background(Paper.gold.opacity(0.075), in: RoundedRectangle(cornerRadius: 14))
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.right").font(.system(size: 11, weight: .semibold)).foregroundStyle(Paper.inkMute)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(category.titleGreek)
                    .font(.system(size: 19, weight: .semibold, design: .serif)).foregroundStyle(Paper.ink)
                    .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                if let s = category.subtitle, !s.isEmpty {
                    Text(s).font(.system(size: 12)).foregroundStyle(Paper.inkMute)
                        .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 116, alignment: .topLeading)
        .padding(17)
        .modifier(PrayerLibrarySurface())
    }
    private func glyph(_ id: String) -> String {
        switch id {
        case "enarxi": return "door.left.hand.open"
        case "proinai": return "sunrise.fill"
        case "esperinai": return "moon.stars.fill"
        case "symbolon": return "scroll.fill"
        case "theotokos": return "sparkles"
        case "katanyktikai": return "drop.fill"
        case "ymnoi": return "music.note"
        case "trapeza": return "fork.knife"
        case "euches-trapezis": return "fork.knife"
        case "akolouthiai": return "books.vertical.fill"
        case "orologion": return "clock.fill"
        case "mystiria": return "cross.vial.fill"
        case "theia-metalipsi": return "cross.fill"
        case "parakliseis": return "hands.sparkles.fill"
        case "megali-evdomada": return "cross.case.fill"
        case "psaltirion": return "book.closed.fill"
        default: return "flame.fill"
        }
    }
}

// ===========================================================================
// MARK: - Category (prayers inside one category)
// ===========================================================================

struct PrayerCategoryView: View {
    let category: PrayerCategory
    var body: some View {
        ZStack {
            AppAtmosphere().ignoresSafeArea()
            ScrollView {
                LazyVStack(spacing: 12) {
                    if let s = category.subtitle, !s.isEmpty {
                        Text(s).font(.system(size: 16, design: .serif))
                            .foregroundStyle(Paper.inkMute).frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 10).padding(.bottom, 12)
                    }
                    LazyVGrid(columns: category.id == "psaltirion" ? [GridItem(.adaptive(minimum: 145), spacing: 12)] : [GridItem(.flexible())], spacing: 12) {
                    ForEach(Array(category.prayers.enumerated()), id: \.element.id) { index, prayer in
                        NavigationLink(value: PrayerRoute(category: category, prayer: prayer)) {
                            if category.id == "psaltirion" {
                                VStack(alignment: .leading, spacing: 16) {
                                    HStack {
                                        Text(String(format: "%02d", index + 1))
                                            .font(.system(size: 27, weight: .light, design: .rounded))
                                            .foregroundStyle(Gild.accentForeground)
                                        Spacer(minLength: 0)
                                        Image(systemName: "book.closed").font(.system(size: 16)).foregroundStyle(Paper.inkMute)
                                    }
                                    Text(prayer.titleGreek).font(.system(size: 17, weight: .semibold, design: .serif))
                                        .foregroundStyle(Paper.ink).multilineTextAlignment(.leading)
                                        .fixedSize(horizontal: false, vertical: true)
                                }.frame(maxWidth: .infinity, minHeight: 100, alignment: .topLeading)
                                    .padding(17).modifier(PrayerLibrarySurface())
                            } else {
                                PrayerRow(prayer: prayer)
                            }
                        }.buttonStyle(.plain)
                    }
                    }
                    Spacer(minLength: 80)
                }
                .padding(.horizontal, 20).padding(.top, 6)
            }
        }
        .navigationTitle(category.titleGreek)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct PrayerRow: View {
    let prayer: Prayer
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(prayer.titleGreek)
                    .font(.system(size: 17, weight: .regular, design: .serif))
                    .foregroundStyle(Paper.ink).multilineTextAlignment(.leading)
                if let a = prayer.visibleAttribution {
                    Text(a).font(.system(size: 12)).foregroundStyle(Paper.inkMute)
                }
            }
            Spacer()
            if prayer.state == "linked" {
                Image(systemName: "book.closed.fill").font(.system(size: 12)).foregroundStyle(Paper.gold)
            } else if prayer.state == "external" {
                HStack(spacing: 4) {
                    Text("πηγή")
                    Image(systemName: "arrow.up.right")
                }
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.4)
                .foregroundStyle(Paper.gold)
            } else if prayer.state == "tosource" {
                Text("σύντομα").font(.system(size: 10, weight: .semibold)).tracking(0.5)
                    .foregroundStyle(Paper.inkMute.opacity(0.7))
            }
            Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Paper.inkMute.opacity(0.6))
        }
        .padding(.horizontal, 18).padding(.vertical, 17)
        .modifier(PrayerLibrarySurface())
    }
}

// ===========================================================================
// MARK: - Reader
// ===========================================================================

struct PrayerReadingView: View {
    let route: PrayerRoute
    // All loaded categories — used only to resolve in-text @link: jumps.
    // Has a default so older call sites still compile.
    var categories: [PrayerCategory] = []
    @State private var prayed = false
    @State private var isSearchExpanded = false
    @State private var query = ""
    @State private var searchResults: [PrayerSearchResult] = []
    @State private var currentMatchIndex: Int?
    @State private var selectedResult: PrayerSearchResult?
    @State private var officeCorpora: [Int: SundayOfficeCorpus] = [:]
    @State private var officeSchedules: [LiturgicalYearSchedule] = []
    @State private var selectedOfficeDate = Date()
    @State private var officeDateDraft = Date()
    @State private var showOfficeDatePicker = false
    @State private var officeLoadError: String?
    @FocusState private var searchFieldFocused: Bool
    private var officeKind: SundayOfficeKind? { SundayOfficeKind(prayerID: route.prayer.id) }
    private var availableOfficeEntries: [SundayOfficeEntry] {
        guard let officeKind else { return [] }
        let allowedDates = Set(officeSchedules.flatMap { $0.entries(for: officeKind.scheduledKind).map(\.date) })
        return officeCorpora.values.flatMap(\.entries).filter { allowedDates.contains($0.date) }.sorted { $0.date < $1.date }
    }
    private var selectedOfficeEntry: SundayOfficeEntry? {
        let key = Self.officeKeyFormatter.string(from: selectedOfficeDate)
        return availableOfficeEntries.first { $0.date == key }
    }
    private var selectedOfficeCorpus: SundayOfficeCorpus? {
        let year = Calendar(identifier: .gregorian).component(.year, from: selectedOfficeDate)
        return officeCorpora[year]
    }
    private var prayer: Prayer {
        guard let officeKind, let selectedOfficeEntry, let selectedOfficeCorpus else { return route.prayer }
        return Prayer(
            id: route.prayer.id,
            titleGreek: route.prayer.titleGreek,
            titleEnglish: route.prayer.titleEnglish,
            attribution: route.prayer.attribution,
            rubric: route.prayer.rubric,
            season: route.prayer.season,
            source: route.prayer.source,
            sourceUrl: route.prayer.sourceUrl,
            scriptureRef: route.prayer.scriptureRef,
            status: route.prayer.status,
            body: officeKind.body(from: selectedOfficeEntry, corpus: selectedOfficeCorpus),
            anchors: route.prayer.anchors
        )
    }

    private var deisisInsertion: DeisisInsertion? {
        guard let document = DeisisCatalog.document else { return nil }
        return DeisisPlacementEngine.insertion(
            anchors: prayer.anchors,
            document: document,
            bodyCount: prayer.body.count
        )
    }

    var body: some View {
        ZStack {
            Paper.bg.ignoresSafeArea()
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        titleBlock
                        if officeKind != nil && (officeCorpora.isEmpty || officeSchedules.isEmpty) && officeLoadError == nil {
                            ProgressView().tint(Paper.gold).frame(maxWidth: .infinity).padding(.top, 60)
                        } else if let officeLoadError, officeKind != nil {
                            ContentUnavailableView("Η ακολουθία δεν φορτώθηκε",
                                systemImage: "exclamationmark.triangle",
                                description: Text(officeLoadError))
                        } else {
                            switch prayer.state {
                            case "linked":   linkedBody
                            case "external": externalSourceBody
                            case "tosource": toSourceBody
                            default:         readableBody
                            }
                        }
                    }
                    .padding(.horizontal, 24).padding(.bottom, 40)
                }
                .onChange(of: selectedResult) { _, result in
                    guard let result else { return }
                    DispatchQueue.main.async {
                        withAnimation(.easeInOut(duration: 0.24)) {
                            proxy.scrollTo(result.id, anchor: .center)
                        }
                    }
                }
            }
        }
        .navigationTitle(prayer.titleGreek)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if prayer.isReadable && !isSearchExpanded {
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
                    .accessibilityLabel("Αναζήτηση στο κείμενο")
                }
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if prayer.isReadable && isSearchExpanded {
                inlineSearchBar
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.84), value: isSearchExpanded)
        .sheet(isPresented: $showOfficeDatePicker) { officeDatePickerSheet }
        .task { await loadOfficeCorpusIfNeeded() }
        .onChange(of: selectedOfficeDate) { _, _ in collapseSearch() }
        .onAppear {
            prayed = PrayerPracticeMemory.didPray(prayerID: prayer.id)
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            if officeKind != nil, !officeCorpora.isEmpty, !officeSchedules.isEmpty {
                officeDateNavigationBar.padding(.bottom, 10)
            }
            Text(prayer.titleGreek)
                .font(.system(size: 26, weight: .regular, design: .serif)).foregroundStyle(Paper.ink)
            if let a = prayer.visibleAttribution {
                Text(a).font(.system(size: 13, design: .serif)).italic().foregroundStyle(Paper.inkMute)
            }
            if let r = prayer.rubric, !r.isEmpty {
                Text(r).font(.system(size: 12)).foregroundStyle(Paper.gold).padding(.top, 2)
            }
            if let entry = selectedOfficeEntry, let officeKind {
                Text(officeSubtitle(kind: officeKind, entry: entry))
                    .font(.system(size: 12, design: .serif))
                    .foregroundStyle(Paper.inkMute)
                HStack(spacing: 10) {
                    if let echos = entry.echos { Text("Ήχος \(Self.greekNumber(echos))") }
                    if officeKind == .orthros, let eothinon = entry.eothinon {
                        Text("Εωθινόν \(Self.greekNumber(eothinon))")
                    }
                }
                .font(.system(size: 12, weight: .semibold, design: .serif))
                .foregroundStyle(Paper.gold)
                Text("Τυπική Διάταξη \(Calendar(identifier: .gregorian).component(.year, from: selectedOfficeDate)) · δεν αποτελεί ωρολόγιο συγκεκριμένου ναού")
                    .font(.system(size: 11, design: .serif))
                    .foregroundStyle(Paper.inkMute)
            }
            Rectangle().fill(Paper.gold.opacity(0.5)).frame(width: 48, height: 1.5).padding(.top, 14)
        }
        .padding(.top, 12).padding(.bottom, 20)
    }

    private var officeDateNavigationBar: some View {
        HStack(spacing: 10) {
            officeStepButton(systemName: "chevron.left", offset: -1)
            Button {
                officeDateDraft = selectedOfficeDate
                showOfficeDatePicker = true
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "calendar")
                        .font(.system(size: 13, weight: .semibold)).foregroundStyle(Paper.gold)
                    Text(Self.officeGreekFormatter.string(from: selectedOfficeDate))
                        .font(.system(size: 14, weight: .medium, design: .serif))
                        .foregroundStyle(Paper.ink).lineLimit(1).minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity).frame(height: 40).padding(.horizontal, 14)
                .background(Paper.card, in: Capsule())
                .overlay(Capsule().stroke(Paper.hairline, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Επιλογή ημερομηνίας")
            officeStepButton(systemName: "chevron.right", offset: 1)
        }
    }

    private func officeStepButton(systemName: String, offset: Int) -> some View {
        let enabled = officeEntry(offsetFromSelection: offset) != nil
        return Button {
            if let entry = officeEntry(offsetFromSelection: offset), let date = Self.officeDate(entry.date) {
                selectedOfficeDate = date
            }
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .semibold)).foregroundStyle(Paper.gold)
                .frame(width: 40, height: 40)
                .background(Paper.card, in: Circle())
                .overlay(Circle().stroke(Paper.hairline, lineWidth: 1))
        }
        .buttonStyle(.plain).disabled(!enabled).opacity(enabled ? 1 : 0.35)
    }

    private var officeDatePickerSheet: some View {
        NavigationStack {
            VStack(spacing: 18) {
                DatePicker("Ημερομηνία", selection: $officeDateDraft,
                    in: officeDateRange,
                    displayedComponents: .date)
                    .datePickerStyle(.graphical).tint(Paper.gold).padding(.horizontal, 8)
                Text("Θα εμφανιστεί η πλησιέστερη προβλεπόμενη τέλεση του Τυπικού:\n\(Self.officeGreekFormatter.string(from: closestOfficeDate(to: officeDateDraft) ?? officeDateDraft))")
                    .font(.system(size: 12, design: .serif)).foregroundStyle(Paper.inkMute)
                    .multilineTextAlignment(.center).padding(.horizontal, 20)
                Spacer()
            }
            .padding(.top, 12).background(Paper.bg.ignoresSafeArea())
            .navigationTitle("Επιλογή ημερομηνίας").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Άκυρο") { showOfficeDatePicker = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Τέλος") {
                        selectClosestOffice(to: officeDateDraft)
                        showOfficeDatePicker = false
                    }.fontWeight(.semibold)
                }
            }
        }
    }

    private func officeEntry(offsetFromSelection offset: Int) -> SundayOfficeEntry? {
        let entries = availableOfficeEntries
        guard let index = entries.firstIndex(where: { $0.date == Self.officeKeyFormatter.string(from: selectedOfficeDate) })
        else { return nil }
        let target = index + offset
        return entries.indices.contains(target) ? entries[target] : nil
    }

    private func selectClosestOffice(to date: Date) {
        guard let resolved = closestOfficeDate(to: date) else { return }
        selectedOfficeDate = resolved
    }

    private func closestOfficeDate(to date: Date) -> Date? {
        availableOfficeEntries.compactMap { Self.officeDate($0.date) }.min {
            abs($0.timeIntervalSince(date)) < abs($1.timeIntervalSince(date))
        }
    }

    private var officeDateRange: ClosedRange<Date> {
        let dates = availableOfficeEntries.compactMap { Self.officeDate($0.date) }
        return (dates.first ?? Self.officeDate("2026-01-01")!)...(dates.last ?? Self.officeDate("2026-12-31")!)
    }

    private func officeSubtitle(kind: SundayOfficeKind, entry: SundayOfficeEntry) -> String {
        let service = kind.service(from: entry)
        switch service.code {
        case "ordinary": return "Εσπερινός — σταθερός κορμός"
        case "pl1": return "Εσπερινός μετά Προηγιασμένης Θείας Λειτουργίας"
        case "vl", "vl2": return "Εσπερινός μετά Θείας Λειτουργίας"
        case "co7": return "Αγρυπνία: Μέγα Απόδειπνον, Λιτή, τέλος Εσπερινού"
        case "em3": return "Όρθρος Μεγάλου Σαββάτου — Εγκώμια (το προηγούμενο εσπέρας)"
        case "em": return "Όρθρος — τελείται το προηγούμενο εσπέρας"
        default:
            return kind == .vespers
                ? "Εσπερινός της ημέρας"
                : "Όρθρος της ημέρας"
        }
    }

    private func loadOfficeCorpusIfNeeded() async {
        guard officeKind != nil, officeCorpora.isEmpty || officeSchedules.isEmpty else { return }
        do {
            let (corpora, schedules) = try await Task.detached {
                (try SundayOfficeCorpus.loadAvailable(), try LiturgicalYearSchedule.loadAvailable())
            }.value
            officeCorpora = corpora
            officeSchedules = schedules
            selectClosestOffice(to: selectedOfficeDate)
            officeLoadError = nil
        } catch {
            officeLoadError = error.localizedDescription
        }
    }

    private static let officeKeyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let officeGreekFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "el_GR")
        formatter.setLocalizedDateFormatFromTemplate("EEEEdMMMMyyyy")
        return formatter
    }()

    private static func officeDate(_ value: String) -> Date? { officeKeyFormatter.date(from: value) }

    private static func greekNumber(_ value: Int) -> String {
        [1: "αʹ", 2: "βʹ", 3: "γʹ", 4: "δʹ", 5: "εʹ", 6: "ϛʹ", 7: "ζʹ", 8: "ηʹ", 9: "θʹ", 10: "ιʹ", 11: "ιαʹ"][value] ?? "\(value)"
    }

    private var readableBody: some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(Array(prayer.body.enumerated()), id: \.offset) { index, para in
                let activeResult = selectedResult?.paragraphIndex == index ? selectedResult : nil
                Group {
                    if let link = linkTarget(in: para) {
                        NavigationLink(value: link.route) {
                            PrayerInlineLink(label: link.label)
                        }
                        .buttonStyle(.plain)
                    } else if let h = marker("@h:", in: para) {
                        // Section title — gold, centred, spaced; clearly not prayer text.
                        highlightedText(h, result: activeResult)
                            .font(.system(size: 14, weight: .semibold, design: .serif))
                            .tracking(1.5)
                            .foregroundStyle(Paper.gold)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 12).padding(.bottom, 2)
                            .fixedSize(horizontal: false, vertical: true)
                    } else if let m = marker("@m:", in: para) {
                        // Mode / ἦχος label — small gold italic, its own quiet style.
                        highlightedText(m, result: activeResult)
                            .font(.system(size: 12.5, weight: .medium, design: .serif)).italic()
                            .tracking(1)
                            .foregroundStyle(Paper.gold.opacity(0.8))
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.bottom, 2)
                            .fixedSize(horizontal: false, vertical: true)
                    } else if let r = marker("@r:", in: para) {
                        // Rubric / instruction — italic, muted, centred.
                        highlightedText(r, result: activeResult)
                            .font(.system(size: 14, design: .serif)).italic()
                            .foregroundStyle(Paper.inkMute)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .fixedSize(horizontal: false, vertical: true)
                    } else if let spoken = spokenLine(in: para) {
                        // Same speaker hierarchy used by the Divine Liturgy reader.
                        VStack(alignment: .leading, spacing: 6) {
                            Text(spoken.speaker.uppercased())
                                .font(.system(size: 10, weight: .semibold, design: .serif))
                                .tracking(1.2)
                                .foregroundStyle(Paper.gold)
                            highlightedText(spoken.text, result: activeResult)
                                .font(.system(size: 19, design: .serif))
                                .foregroundStyle(Paper.ink)
                                .lineSpacing(8)
                                .textSelection(.enabled)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 5)
                    } else {
                        highlightedText(para, result: activeResult)
                            .font(.system(size: 19, weight: .regular, design: .serif))
                            .foregroundStyle(Paper.ink).lineSpacing(8)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .id("prayer-paragraph-\(index)")
                .overlay(alignment: .topLeading) {
                    if let activeResult {
                        searchMatchAnchor(activeResult, textLength: visibleText(in: para)?.count ?? 0)
                    }
                }

                if let insertion = deisisInsertion,
                   insertion.index == index + 1,
                   let document = DeisisCatalog.document {
                    DeisisSection(document: document, placement: insertion.placement)
                        .padding(.vertical, 8)
                        .id("deisis-section-\(insertion.placement.service)")
                }
            }
            if let s = prayer.visibleSource {
                Text(s).font(.system(size: 11)).foregroundStyle(Paper.inkMute.opacity(0.7)).padding(.top, 10)
            }
            markAsPrayed
        }
    }

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
        .glassCircleFallback(shape: Capsule(), interactive: false)
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
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

    private func updateSearch() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            searchResults = []
            currentMatchIndex = nil
            selectedResult = nil
            return
        }

        var results: [PrayerSearchResult] = []
        for (paragraphIndex, paragraph) in prayer.body.enumerated() {
            guard let text = visibleText(in: paragraph), !text.isEmpty else { continue }
            var searchStart = text.startIndex
            var ordinal = 0
            while searchStart < text.endIndex,
                  let range = text.range(
                    of: trimmed,
                    options: [.caseInsensitive, .diacriticInsensitive],
                    range: searchStart..<text.endIndex
                  ) {
                results.append(.init(
                    paragraphIndex: paragraphIndex,
                    startOffset: text.distance(from: text.startIndex, to: range.lowerBound),
                    endOffset: text.distance(from: text.startIndex, to: range.upperBound),
                    ordinal: ordinal
                ))
                ordinal += 1
                searchStart = range.upperBound
            }
        }
        searchResults = results
        currentMatchIndex = results.isEmpty ? nil : 0
        selectedResult = results.first
    }

    private func moveMatch(by step: Int) {
        guard !searchResults.isEmpty else { return }
        let current = currentMatchIndex ?? 0
        let next = (current + step + searchResults.count) % searchResults.count
        currentMatchIndex = next
        selectedResult = searchResults[next]
    }

    private func visibleText(in paragraph: String) -> String? {
        if let spoken = spokenLine(in: paragraph) { return spoken.text }
        for markerKey in ["@h:", "@m:", "@r:"] {
            if let marked = marker(markerKey, in: paragraph) { return marked }
        }
        if paragraph.hasPrefix("@link:") { return nil }
        return paragraph
    }

    private func highlightedText(_ text: String, result: PrayerSearchResult?) -> Text {
        guard let result,
              result.startOffset >= 0,
              result.endOffset <= text.count,
              result.startOffset < result.endOffset else {
            return Text(text)
        }
        let start = text.index(text.startIndex, offsetBy: result.startOffset)
        let end = text.index(text.startIndex, offsetBy: result.endOffset)
        return Text(String(text[..<start]))
            + Text(String(text[start..<end]))
                .bold()
                .foregroundColor(Paper.gold)
                .underline(true, color: Paper.gold)
            + Text(String(text[end...]))
    }

    private func searchMatchAnchor(_ result: PrayerSearchResult, textLength: Int) -> some View {
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

    // Strips a leading marker like "@h:" or "@r:" and returns the rest, or nil.
    private func marker(_ key: String, in para: String) -> String? {
        guard para.hasPrefix(key) else { return nil }
        return String(para.dropFirst(key.count)).trimmingCharacters(in: .whitespaces)
    }

    // A spoken block is encoded as @s:SPEAKER|TEXT so the content keeps the
    // same visual language as the structured Divine Liturgy.
    private func spokenLine(in para: String) -> (speaker: String, text: String)? {
        let prefix = "@s:"
        guard para.hasPrefix(prefix) else { return nil }
        let payload = String(para.dropFirst(prefix.count))
        let parts = payload.split(separator: "|", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2 else { return nil }
        let speaker = parts[0].trimmingCharacters(in: .whitespaces)
        let text = parts[1].trimmingCharacters(in: .whitespaces)
        guard !speaker.isEmpty, !text.isEmpty else { return nil }
        return (speaker, text)
    }

    // Recognises a body paragraph of the form  @link:TARGET_ID|Visible label
    // and resolves it to a real route by finding TARGET_ID among all prayers.
    private func linkTarget(in para: String) -> (label: String, route: PrayerRoute)? {
        let prefix = "@link:"
        guard para.hasPrefix(prefix) else { return nil }
        let payload = String(para.dropFirst(prefix.count))
        let parts = payload.split(separator: "|", maxSplits: 1, omittingEmptySubsequences: false)
        let targetId = parts[0].trimmingCharacters(in: .whitespaces)
        let label = parts.count > 1
            ? parts[1].trimmingCharacters(in: .whitespaces)
            : targetId
        for cat in categories {
            if let p = cat.prayers.first(where: { $0.id == targetId }) {
                return (label, PrayerRoute(category: cat, prayer: p))
            }
        }
        return nil   // unknown id → caller shows nothing odd; line is simply hidden
    }

    private var linkedBody: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Αυτή η προσευχή είναι Γραφή.")
                .font(.system(size: 17, design: .serif)).foregroundStyle(Paper.ink)
            if let ref = prayer.scriptureRef {
                Text(ref).font(.system(size: 15, design: .serif)).italic().foregroundStyle(Paper.inkMute)
            }
        }.padding(.top, 4)
    }

    private var toSourceBody: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Μεγάλη ακολουθία.").font(.system(size: 17, design: .serif)).foregroundStyle(Paper.ink)
            Text("Το πλήρες κείμενο προστίθεται σύντομα.")
                .font(.system(size: 14)).foregroundStyle(Paper.inkMute)
        }.padding(.top, 4)
    }

    private var externalSourceBody: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Το πλήρες κείμενο βρίσκεται στην καταγεγραμμένη εξωτερική πηγή.")
                .font(.system(size: 17, design: .serif))
                .foregroundStyle(Paper.ink)

            Text("Η εφαρμογή δεν αντιγράφει το κείμενο χωρίς τεκμηριωμένη άδεια επαναχρησιμοποίησης.")
                .font(.system(size: 14))
                .foregroundStyle(Paper.inkMute)

            if let rawURL = prayer.sourceUrl, let url = URL(string: rawURL) {
                Link(destination: url) {
                    HStack(spacing: 9) {
                        Image(systemName: "safari.fill")
                        Text("Άνοιγμα πλήρους κειμένου")
                        Spacer(minLength: 0)
                        Image(systemName: "arrow.up.right")
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Paper.gold)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Paper.gold.opacity(0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Paper.gold.opacity(0.35), lineWidth: 1)
                            )
                    )
                }
            }

            if let source = prayer.visibleSource {
                Text(source)
                    .font(.system(size: 11))
                    .foregroundStyle(Paper.inkMute.opacity(0.7))
                    .padding(.top, 4)
            }
        }
        .padding(.top, 4)
    }

    private var markAsPrayed: some View {
        Button {
            guard !prayed else { return }
            PrayerPracticeMemory.markPrayed(prayerID: prayer.id)
            StreakStore.shared.record(.prayer, itemID: prayer.id)
            withAnimation(.easeOut(duration: 0.25)) { prayed = true }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: prayed ? "flame.fill" : "flame")
                Text(prayed ? "Προσευχήθηκα" : "Σημείωση προσευχής").font(.system(size: 15, weight: .medium))
            }
            .foregroundStyle(prayed ? Paper.gold : Paper.inkMute)
            .padding(.horizontal, 18).padding(.vertical, 12)
            .background(Capsule().fill(prayed ? Paper.gold.opacity(0.12) : Paper.card)
                .overlay(Capsule().stroke(Paper.hairline, lineWidth: 1)))
        }
        .buttonStyle(.plain).frame(maxWidth: .infinity).padding(.top, 24)
    }
}

enum PrayerPracticeMemory {
    private static let key = "klimax.prayer.practice.days.v1"

    static func didPray(prayerID: String, date: Date = Date()) -> Bool {
        entries().contains(entry(prayerID: prayerID, date: date))
    }

    static func markPrayed(prayerID: String, date: Date = Date()) {
        var saved = entries()
        saved.insert(entry(prayerID: prayerID, date: date))
        UserDefaults.standard.set(Array(saved), forKey: key)
    }

    private static func entries() -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: key) ?? [])
    }

    private static func entry(prayerID: String, date: Date) -> String {
        "\(dayKey(date))|\(prayerID)"
    }

    private static func dayKey(_ date: Date) -> String {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
    }
}

// A tappable gold panel shown in place of an @link: paragraph.
private struct PrayerInlineLink: View {
    let label: String
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.up.right.circle.fill")
                .font(.system(size: 18)).foregroundStyle(Paper.gold)
            Text(label)
                .font(.system(size: 18, weight: .medium, design: .serif))
                .foregroundStyle(Paper.gold)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Paper.gold.opacity(0.7))
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Paper.gold.opacity(0.08))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Paper.gold.opacity(0.35), lineWidth: 1)))
    }
}
