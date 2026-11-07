import Foundation

/// Presentation policy only. The bundled rows, metadata and YouTube IDs stay intact.
struct AthosTVSeriesDefinition: Sendable {
    let id: String
    let title: String
    let sourceTitles: [String]
    let coverAssetName: String?
    var heroAssetName: String? = nil
    var isVisibleInAthosTV = true

    // Exact row keys from series_mapping.json, not the unreliable per-video `series` field.
    // To restore a hidden collection, change its visibility here. No data migration is needed.
    static let all: [Self] = [
        .init(id: "family-mirror", title: "Οικογενειακός Καθρέφτης",
              sourceTitles: ["Οικογενειακος Καθρεφτης"], coverAssetName: "AthosTVSeriesFamilyMirror", heroAssetName: "AthosTVHeroFamilyMirror"),
        .init(id: "saint-silouan", title: "Άγιος Σιλουανός",
              sourceTitles: ["Αγιος Σιλουανος"], coverAssetName: "AthosTVSeriesSaintSilouan", heroAssetName: "AthosTVHeroSaintSilouan"),
        .init(id: "healing-soul-body", title: "Εις ίασιν ψυχής τε και σώματος",
              sourceTitles: ["Εις ιασιν ψυχης τε και σωματος"], coverAssetName: "AthosTVSeriesHealingSoulBody", heroAssetName: "AthosTVHeroHealingSoulBody"),
        .init(id: "holy-figures", title: "Αγιασμένων Μορφών Νοσταλγία",
              sourceTitles: ["Αγιασμενων Μορφων Νοσταλγια"], coverAssetName: "AthosTVSeriesHolyFiguresNostalgia", heroAssetName: "AthosTVHeroHolyFiguresNostalgia"),
        .init(id: "marriage", title: "Το Μυστήριο του Γάμου",
              sourceTitles: ["Το Μυστηριο του Γαμου"], coverAssetName: "AthosTVSeriesMarriageSacrament", heroAssetName: "AthosTVHeroMarriageSacrament"),
        .init(id: "sunday-gospels", title: "Ευαγγέλια Κυριακών",
              sourceTitles: ["Ευαγγελια Κυριακων"], coverAssetName: "AthosTVSeriesSundayGospels", heroAssetName: "AthosTVHeroSundayGospels"),
        .init(id: "athanasios-sermons", title: "Κηρύγματα Μητροπολίτου Λεμεσού Αθανασίου",
              sourceTitles: ["Κηρυγματα Μητροπολιτου Λεμεσου Αθανασιου"], coverAssetName: "AthosTVSeriesMetropolitanAthanasios", heroAssetName: "AthosTVHeroMetropolitanAthanasios"),
        .init(id: "athanasios-talks", title: "Ομιλίες Μητροπολίτου Λεμεσού Αθανασίου",
              sourceTitles: ["Ζωντανες Αναπαραγωγες Ομιλιων", "Βιντεοσκοπημενες Ομιλιες"],
              coverAssetName: "AthosTVSeriesLiveRecordedTalks", heroAssetName: "AthosTVHeroLiveRecordedTalks"),
        .init(id: "gospel-interpretation", title: "Ερμηνεία των Ευαγγελίων",
              sourceTitles: ["Ερμηνεια των Ευαγγελιων"], coverAssetName: "AthosTVSeriesGospelInterpretation", heroAssetName: "AthosTVHeroGospelInterpretation"),
        .init(id: "ask-your-father", title: "Επερώτησον τον Πατέρα σου",
              sourceTitles: ["Επερωτησον τον Πατερα σου"], coverAssetName: "AthosTVSeriesAskYourFather", heroAssetName: "AthosTVHeroAskYourFather"),
        .init(id: "entrust-to-christ", title: "Χριστώ τω Θεώ Παραθώμεθα",
              sourceTitles: ["Χριστω τω Θεω Παραθωμεθα"], coverAssetName: "AthosTVSeriesEntrustToChrist", heroAssetName: "AthosTVHeroEntrustToChrist"),
        .init(id: "selected-talks", title: "Επιλεγμένες Ομιλίες",
              sourceTitles: ["Επιλεγμενες Ομιλιες"], coverAssetName: nil, isVisibleInAthosTV: false),
        .init(id: "faith-and-life", title: "Ορθόδοξη Πίστη και Ζωή",
              sourceTitles: ["Ορθοδοξη Πιστη και Ζωη"], coverAssetName: nil, isVisibleInAthosTV: false)
    ]
}

struct AthosTVCollection: Identifiable, Hashable, Sendable {
    let definition: AthosTVSeriesDefinition
    let videos: [AthosTVVideo]

    var id: String { definition.id }
    var title: String { definition.title }
    var coverAssetName: String? { definition.coverAssetName }
    var heroAssetName: String? { definition.heroAssetName }
    var episodeCountText: String { videos.count == 1 ? "1 επεισόδιο" : "\(videos.count) επεισόδια" }

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    func matches(_ query: String) -> Bool {
        ([title] + definition.sourceTitles).contains {
            $0.range(of: query, options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "el_GR")) != nil
        }
    }

    func limited(to videoIDs: Set<String>) -> Self {
        Self(definition: definition, videos: videos.filter { videoIDs.contains($0.videoId) })
    }
}

/// Built once when the catalogue loads, and shared by browse, search and speaker pages.
struct AthosTVPresentation: Sendable {
    let collections: [AthosTVCollection]
    let videos: [AthosTVVideo]
    let videoIDs: Set<String>

    init(page: AthosTVPage, definitions: [AthosTVSeriesDefinition] = AthosTVSeriesDefinition.all) {
        let allCollections = definitions.map { definition in
            let sourceTitles = Set(definition.sourceTitles)
            let ids = page.rows.filter { sourceTitles.contains($0.title) }.flatMap(\.videoIds)
            var seen = Set<String>()
            let episodes = ids.compactMap { id -> AthosTVVideo? in
                guard let video = page.videos[id], seen.insert(video.videoId).inserted else { return nil }
                return video
            }.sorted(by: Self.episodeOrder)
            return AthosTVCollection(definition: definition, videos: episodes)
        }
        collections = allCollections.filter { $0.definition.isVisibleInAthosTV && !$0.videos.isEmpty }

        // Hide exclusive episodes from discovery too, but retain a shared episode if
        // it also belongs to a visible collection. Favorites and source data are never erased.
        let visibleIDs = Set(collections.flatMap { $0.videos.map(\.videoId) })
        let hiddenIDs = Set(allCollections.filter { !$0.definition.isVisibleInAthosTV }
            .flatMap { $0.videos.map(\.videoId) }).subtracting(visibleIDs)
        videos = page.videos.values.filter { !hiddenIDs.contains($0.videoId) }.sorted {
            if $0.publishedAt != $1.publishedAt { return $0.publishedAt > $1.publishedAt }
            return $0.videoId < $1.videoId
        }
        videoIDs = Set(videos.map(\.videoId))
    }

    /// Preserve the existing detail-page chronology; ID breaks otherwise equal ties.
    static func episodeOrder(_ lhs: AthosTVVideo, _ rhs: AthosTVVideo) -> Bool {
        if lhs.publishedAt != rhs.publishedAt { return lhs.publishedAt < rhs.publishedAt }
        let comparison = lhs.title.localizedStandardCompare(rhs.title)
        return comparison == .orderedSame ? lhs.videoId < rhs.videoId : comparison == .orderedAscending
    }
}
