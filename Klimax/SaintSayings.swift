import Foundation

struct SaintSaying: Codable, Identifiable, Hashable {
    let id: String
    let saintID: String
    let categoryID: String
    let text: String
    let source: String
    let sourceNote: String
    let sourceStatus: String
    let sourceChecked: Bool
    let featured: Bool
    let photoID: String
}

struct SayingSaint: Codable, Identifiable {
    let id: String
    let name: String
    let shortName: String
    let subtitle: String
    let photoID: String
}

struct SayingCategory: Codable, Identifiable {
    let id: String
    let title: String
    let shortTitle: String
    let symbol: String
}

struct SayingPhoto: Codable, Identifiable {
    let id: String
    let asset: String
    /// Reviewed subject boundary. The full-bleed crop is top-aligned, so its
    /// vertical location remains predictable across tile and reader sizes.
    let subjectTop: Double
    let width: Double
    let height: Double
    /// Optional lower text region for portraits with no headroom. Measured in
    /// source-image coordinates below the faces, before the top-aligned crop.
    let textStart: Double?

    /// Gallery-only crop for a landscape photo sharing a taller portrait row.
    /// Existing photographs keep their natural aspect and text placement.
    let fillsCard: Bool?
    let cardFocusX: Double?
    /// Horizontal focus for the full-screen feed; older photos retain their crop.
    let reelFocusX: Double?

    var reelHorizontalFocus: Double {
        reelFocusX ?? (width > height ? 0.75 : 0.5)
    }

    func cardImageRect(in size: CGSize) -> CGRect {
        let scale = fillsCard == true
            ? max(size.width / width, size.height / height)
            : size.width / width
        let imageSize = CGSize(width: width * scale, height: height * scale)
        return CGRect(x: (size.width - imageSize.width) * (cardFocusX ?? 0.5),
                      y: 0, width: imageSize.width, height: imageSize.height)
    }

    func cardTextRegion(in size: CGSize) -> CGRect {
        let imageHeight = fillsCard == true ? size.height : size.width * height / width
        let start = min(size.height, imageHeight * (textStart ?? 0))
        let available = textStart == nil ? imageHeight * subjectTop : size.height - start
        return CGRect(x: 0, y: start, width: size.width, height: max(0, min(available, size.height - start)))
    }

    func textRegion(in size: CGSize) -> CGRect {
        guard let textStart else {
            return CGRect(x: 0, y: 0, width: size.width, height: textBoundary(in: size))
        }
        let scale = max(size.width / width, size.height / height)
        let start = min(size.height, height * scale * textStart)
        return CGRect(x: 0, y: start, width: size.width, height: max(0, size.height - start))
    }

    func textBoundary(in size: CGSize) -> CGFloat {
        let scale = max(size.width / width, size.height / height)
        return min(size.height, height * scale * subjectTop)
    }
}

struct SaintSayingsCatalog: Codable {
    let version: Int
    let saints: [SayingSaint]
    let categories: [SayingCategory]
    let photos: [SayingPhoto]
    let sayings: [SaintSaying]

    static let bundled: SaintSayingsCatalog? = {
        guard let url = Bundle.main.url(forResource: "saint-sayings", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let catalog = try? JSONDecoder().decode(Self.self, from: data),
              catalog.isValid else { return nil }
        return catalog
    }()

    var isValid: Bool {
        !saints.isEmpty && !categories.isEmpty && !photos.isEmpty &&
        Set(sayings.map(\.id)).count == sayings.count &&
        photos.allSatisfy {
            (0...0.8).contains($0.subjectTop) && $0.width > 0 && $0.height > 0 &&
            ($0.textStart.map { (0..<1).contains($0) } ?? true) &&
            ($0.cardFocusX.map { (0...1).contains($0) } ?? true) &&
            ($0.reelFocusX.map { (0...1).contains($0) } ?? true)
        } &&
        sayings.allSatisfy { saying in
            !saying.text.isEmpty && saints.contains { $0.id == saying.saintID } &&
            categories.contains { $0.id == saying.categoryID } && photos.contains { $0.id == saying.photoID }
        }
    }

    func categories(for saintID: String) -> [SayingCategory] {
        let ids = Set(sayings.filter { $0.saintID == saintID }.map(\.categoryID))
        return categories.filter { ids.contains($0.id) }
    }

    func filtered(saintID: String, categoryID: String?, query: String) -> [SaintSaying] {
        collection(saintID: saintID, categoryID: categoryID, query: query)
    }

    /// Filtering preserves the supplied shuffle order instead of grouping saints.
    func collection(saintID: String? = nil, categoryID: String? = nil, query: String = "", favoriteIDs: Set<String>? = nil, order: [String]? = nil) -> [SaintSaying] {
        let words = Self.searchKey(query).split(separator: " ")
        let positions = Dictionary((order ?? []).enumerated().map { ($0.element, $0.offset) }, uniquingKeysWith: { min($0, $1) })
        return sayings.filter { saying in
            (saintID == nil || saying.saintID == saintID) &&
            (favoriteIDs.map { $0.contains(saying.id) } ?? true) &&
            (categoryID == nil || saying.categoryID == categoryID) &&
            words.allSatisfy { Self.searchKey(saying.text).contains($0) }
        }.sorted { a, b in
            if order != nil {
                let left = positions[a.id] ?? Int.max, right = positions[b.id] ?? Int.max
                return left == right ? a.id < b.id : left < right
            }
            if a.featured != b.featured { return a.featured }
            return a.id < b.id
        }
    }

    private static func searchKey(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "el"))
            .replacingOccurrences(of: "ς", with: "σ")
    }

    func photo(for saying: SaintSaying) -> SayingPhoto { photos.first { $0.id == saying.photoID } ?? photos[0] }
    func saint(for saying: SaintSaying) -> SayingSaint { saints.first { $0.id == saying.saintID } ?? saints[0] }
    func category(for saying: SaintSaying) -> SayingCategory { categories.first { $0.id == saying.categoryID } ?? categories[0] }
}

/// Fits complete shorter quotes and reserves a bounded excerpt for long ones.
struct SaintSayingTextLayout {
    let naturalHeight: CGFloat
    let availableHeight: CGFloat
    let lineHeight: CGFloat

    var needsExpansion: Bool { naturalHeight > max(0, availableHeight) }
    func height(expanded: Bool) -> CGFloat {
        let full = max(0, min(naturalHeight, availableHeight))
        return needsExpansion && !expanded ? min(full, max(0, lineHeight) * 6) : full
    }
}

/// Local, versioned favourites. Unknown IDs are harmless and never alter content.
enum SaintSayingFavorites {
    static let storageKey = "klimax.saintSayings.favoriteIDs.v1"

    static func decode(_ data: Data) -> Set<String> {
        Set((try? JSONDecoder().decode([String].self, from: data)) ?? [])
    }

    static func encode(_ ids: Set<String>) -> Data {
        (try? JSONEncoder().encode(ids.sorted())) ?? Data()
    }
}
