//
//  ChurchSearchService.swift
//  Klimax
//
//  Loads Orthodox churches & monasteries from a bundled local file
//  (orthodox_places.json), produced once by fetch_orthodox_places.py and
//  never fetched live. No network, no timeouts, no rate limits.
//
//  The file can be tens of thousands of entries now that Cyprus and Crete
//  are included, so it is read and decoded on a background thread — never
//  on the main thread — so opening the map never hangs the UI.
//

import Foundation
import CoreLocation
import MapKit

enum ChurchKind: String, Decodable {
    case church
    case monastery
}

struct ChurchPlace: Identifiable, Hashable, Decodable {
    let id: String
    let name: String
    let lat: Double
    let lon: Double
    let kind: ChurchKind
    let locality: String?
    // Photo identifiers copied straight from this church's OpenStreetMap
    // object (added by enrich_photos.py). Because they live on THIS exact
    // object, any photo they resolve to is guaranteed to be this church —
    // no confusion with the twenty other churches of the same saint.
    var wikidata: String? = nil   // e.g. "Q12345" → Wikidata image (P18)
    var commons: String? = nil    // e.g. "Category:…" or "File:….jpg"
    var image: String? = nil      // a direct image URL

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    static func == (lhs: ChurchPlace, rhs: ChurchPlace) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

enum SuggestionKind {
    case church
    case monastery
    case place
}

struct SearchSuggestion: Identifiable, Hashable {
    let id: String
    let name: String
    let locality: String?
    let coordinate: CLLocationCoordinate2D
    let kind: SuggestionKind

    static func == (lhs: SearchSuggestion, rhs: SearchSuggestion) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

@MainActor
@Observable
final class ChurchSearchService {

    private(set) var allPlaces: [ChurchPlace] = []
    private(set) var isDataLoaded = false
    var suggestions: [SearchSuggestion] = []
    var isLoading = false

    // Precomputed once: each place with separate search keys for its name and
    // its locality, so a query can be scored against each and a location word
    // can drive geographic ranking.
    private struct Indexed { let place: ChurchPlace; let nameKey: String; let locKey: String }
    private var searchIndex: [Indexed] = []

    init() {
        Task {
            let loaded = await Task.detached(priority: .userInitiated) {
                Self.loadBundledDataSync()
            }.value
            allPlaces = loaded
            searchIndex = loaded.map {
                Indexed(place: $0,
                        nameKey: Self.searchKey($0.name),
                        locKey: Self.searchKey($0.locality ?? ""))
            }
            isDataLoaded = true
        }
    }

    // Runs off the main actor on purpose — the file read and JSON decode
    // happen here, away from anything that draws the screen.
    nonisolated private static func loadBundledDataSync() -> [ChurchPlace] {
        guard let url = Bundle.main.url(forResource: "orthodox_places", withExtension: "json") else {
            print("⚠️ orthodox_places.json not found in the app bundle.")
            return []
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([ChurchPlace].self, from: data)
        } catch {
            print("⚠️ Failed to decode orthodox_places.json: \(error)")
            return []
        }
    }

    // MARK: - Regions gazetteer (city / district / country containment)

    // The name of a city, district or country is usually NOT stored as the
    // locality of each church (a church in Nicosia is tagged with its suburb,
    // e.g. "Ανθούπολη", not "Λευκωσία"). So when someone types "Λευκωσία",
    // "Nicosia", "Κύπρος" or "Cyprus", we match by whether the church falls
    // INSIDE that region's bounds — not by a locality string. Boxes are
    // (minLat, minLon, maxLat, maxLon). Every common spelling is included.
    private struct Region { let keys: [String]; let box: (Double, Double, Double, Double) }
    private static let gazetteer: [Region] = {
        func k(_ spellings: [String]) -> [String] { spellings.map { searchKey($0) } }
        return [
            Region(keys: k(["Κύπρος", "Κύπρου", "Cyprus", "Kypros", "Kibris"]),                 box: (34.50, 32.20, 35.75, 34.65)),
            Region(keys: k(["Λευκωσία", "Λευκωσίας", "Nicosia", "Lefkosia", "Lefkosa"]),         box: (34.85, 32.85, 35.45, 33.75)),
            Region(keys: k(["Λεμεσός", "Λεμεσού", "Limassol", "Lemesos"]),                       box: (34.55, 32.70, 35.02, 33.40)),
            Region(keys: k(["Λάρνακα", "Λάρνακας", "Larnaca", "Larnaka"]),                       box: (34.70, 33.30, 35.15, 33.80)),
            Region(keys: k(["Πάφος", "Πάφου", "Paphos", "Pafos"]),                               box: (34.55, 32.20, 35.20, 32.80)),
            Region(keys: k(["Αμμόχωστος", "Αμμοχώστου", "Famagusta", "Ammochostos"]),            box: (34.95, 33.60, 35.72, 34.65)),
            Region(keys: k(["Κερύνεια", "Κερύνειας", "Kyrenia", "Keryneia", "Girne"]),           box: (35.20, 32.85, 35.48, 33.55)),
            Region(keys: k(["Ελλάδα", "Ελλάδας", "Greece", "Hellas", "Ellada"]),                 box: (34.70, 19.30, 41.80, 29.80)),
            Region(keys: k(["Αθήνα", "Αθήνας", "Athens", "Athina"]),                             box: (37.80, 23.50, 38.15, 23.95)),
            Region(keys: k(["Θεσσαλονίκη", "Θεσσαλονίκης", "Thessaloniki", "Salonica"]),         box: (40.50, 22.80, 40.75, 23.10)),
        ]
    }()

    // The region boxes a query word refers to (exact, or a clear prefix match).
    private static func regionsMatching(_ token: String) -> [(Double, Double, Double, Double)] {
        guard token.count >= 3 else { return [] }
        var boxes: [(Double, Double, Double, Double)] = []
        for r in gazetteer where r.keys.contains(where: {
            $0 == token || ($0.count >= 4 && $0.hasPrefix(token)) || ($0.count >= 4 && token.hasPrefix($0))
        }) {
            boxes.append(r.box)
        }
        return boxes
    }

    private static func inBox(_ p: ChurchPlace, _ b: (Double, Double, Double, Double)) -> Bool {
        p.lat >= b.0 && p.lat <= b.2 && p.lon >= b.1 && p.lon <= b.3
    }

    private static func boxArea(_ b: (Double, Double, Double, Double)) -> Double {
        abs((b.2 - b.0) * (b.3 - b.1))
    }

    // MARK: - Search: local name match, with a place-name fallback via geocoding

    func search(_ text: String, near: CLLocationCoordinate2D?) async {
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= 2 else { suggestions = []; return }

        let qTokens = Self.searchKey(query).split(separator: " ").map(String.init).filter { $0.count >= 2 }
        guard !qTokens.isEmpty else { suggestions = []; return }

        let source = searchIndex.isEmpty
            ? allPlaces.map { Indexed(place: $0, nameKey: Self.searchKey($0.name), locKey: Self.searchKey($0.locality ?? "")) }
            : searchIndex
        let userOrigin = near.map { CLLocation(latitude: $0.latitude, longitude: $0.longitude) }

        // Which query words name a region (city / district / country). Region
        // words express geographic intent; they are not part of the church's
        // name and must never be treated as a fuzzy name-scoring bonus.
        var tokenBoxes: [String: [(Double, Double, Double, Double)]] = [:]
        for q in qTokens {
            let boxes = Self.regionsMatching(q)
            if !boxes.isEmpty { tokenBoxes[q] = boxes }
        }

        let regionTokens = Set(tokenBoxes.keys)
        let nameQueryTokens = qTokens.filter { !regionTokens.contains($0) }

        // Hard geographic filter. When both a country and a city are present,
        // choose the smallest (most specific) box. Broader matching boxes must
        // not re-admit global/country-wide results into a city search.
        let explicitRegionBoxes = tokenBoxes.values.flatMap { $0 }
        let primaryRegionBox = explicitRegionBoxes.min { Self.boxArea($0) < Self.boxArea($1) }
        let regionFilteredSource = primaryRegionBox.map { box in
            source.filter { Self.inBox($0.place, box) }
        } ?? []
        let sourceForScoring: [Indexed]
        if primaryRegionBox != nil, !regionFilteredSource.isEmpty {
            sourceForScoring = regionFilteredSource
        } else {
            // A stale/incorrect gazetteer box should not make search completely
            // empty. Keep this observable in DEBUG so the data can be fixed.
            sourceForScoring = source
        }

        struct Scored {
            let place: ChurchPlace
            let exactName: Bool
            let coverage: Double
            let strength: Double
            let userDist: Double
        }
        var scored: [Scored] = []
        var nameMatchedTokens = Set<String>()
        let normalizedNameQuery = nameQueryTokens.map(Self.greekInflectionStem)

        for entry in sourceForScoring {
            let nameToks = entry.nameKey.split(separator: " ").map(String.init)
            let locToks  = entry.locKey.split(separator: " ").map(String.init)
            var matched = 0
            var strength = 0.0
            let tokensToScore = primaryRegionBox == nil ? qTokens : nameQueryTokens
            for q in tokensToScore {
                let n = Self.tokenScore(q, nameToks)
                // Preserve locality matching for unknown villages only. A known
                // gazetteer location has already done its job via hard filtering.
                let l = primaryRegionBox == nil ? Self.tokenScore(q, locToks) : 0
                if n >= 0.6 { nameMatchedTokens.insert(q) }
                let best = Swift.max(n, l)
                if best > 0 { matched += 1 }
                strength += best
            }
            // A location-only query intentionally includes every church in the
            // filtered region; a named search includes only name/locality hits.
            guard tokensToScore.isEmpty || matched > 0 else { continue }
            let coverage = tokensToScore.isEmpty ? 0 : Double(matched) / Double(tokensToScore.count)
            let dist = userOrigin.map { CLLocation(latitude: entry.place.lat, longitude: entry.place.lon).distance(from: $0) } ?? 0
            scored.append(Scored(place: entry.place,
                                 exactName: !normalizedNameQuery.isEmpty
                                     && nameToks.map(Self.greekInflectionStem) == normalizedNameQuery,
                                 coverage: coverage,
                                 strength: strength,
                                 userDist: dist))
        }

        // Once geography has restricted the candidate set, rank by name first.
        // Region-centre distance precedes user distance, so a remote simulator
        // or traveller cannot override the location explicitly typed.
        func rank(_ items: [Scored], focus: CLLocationCoordinate2D?) -> [ChurchPlace] {
            let focusLoc = focus.map { CLLocation(latitude: $0.latitude, longitude: $0.longitude) }
            func focusDistance(_ s: Scored) -> Double {
                guard let focusLoc else { return 0 }
                return CLLocation(latitude: s.place.lat, longitude: s.place.lon).distance(from: focusLoc)
            }
            return items.sorted { a, b in
                if a.exactName != b.exactName { return a.exactName }
                if abs(a.coverage - b.coverage) > 0.0001 { return a.coverage > b.coverage }
                if abs(a.strength - b.strength) > 0.0001 { return a.strength > b.strength }
                let af = focusDistance(a), bf = focusDistance(b)
                if abs(af - bf) > 0.1 { return af < bf }
                return a.userDist < b.userDist
            }.map(\.place)
        }

        let locationTokens = qTokens.filter { !regionTokens.contains($0) && !nameMatchedTokens.contains($0) }
        let areaOnly = nameQueryTokens.isEmpty || nameMatchedTokens.isEmpty
        let bestCoverage = scored.map(\.coverage).max() ?? 0

        // A region named in the query gives us an offline focus (its centre),
        // so we can order in-region matches without any network call — and
        // never fall back to "distance from the user", which on a US simulator
        // put Greek results 10,000 km away above the Cyprus one.
        let regionFocus = primaryRegionBox.map {
            CLLocationCoordinate2D(latitude: ($0.0 + $0.2) / 2,
                                   longitude: ($0.1 + $0.3) / 2)
        }

        // Instant, local, no network — correct for name + locality AND for
        // name + city/country via the gazetteer.
        suggestions = makeSuggestions(rank(scored, focus: regionFocus))

        // TEMPORARY diagnostics — visible in Xcode's console. Safe to delete
        // once search is confirmed working; compiled out of Release builds.
        #if DEBUG
        let debugSearch = true
        if debugSearch {
            print("SEARCH QUERY:", query)
            print("TOKENS:", qTokens)
            print("REGION TOKENS:", Array(tokenBoxes.keys))
            print("PRIMARY REGION BOX:", String(describing: primaryRegionBox))
            print("SOURCE COUNT:", source.count)
            print("FILTERED SOURCE COUNT:", sourceForScoring.count)
            if primaryRegionBox != nil && regionFilteredSource.isEmpty {
                print("REGION FILTER WARNING: no local candidates; using global fallback")
            }
            print("TOP RESULTS:", suggestions.prefix(10).map {
                "\($0.name) | \($0.locality ?? "nil") | \($0.coordinate.latitude), \($0.coordinate.longitude)"
            })
        }
        #endif

        // Geocode only when the area word is NOT a known region and wasn't
        // resolved by a locality either (e.g. a small village name).
        if regionFocus == nil, !locationTokens.isEmpty, areaOnly || bestCoverage < 1.0 || scored.count < 5 {
            isLoading = true
            let focus = await geocodeFocus(locationTokens.joined(separator: " "), near: near) ?? focusFromData(locationTokens)
            isLoading = false
            if Task.isCancelled { return }

            if let focus {
                if areaOnly {
                    let origin = CLLocation(latitude: focus.latitude, longitude: focus.longitude)
                    let nearest = source.map(\.place)
                        .map { (p: $0, m: CLLocation(latitude: $0.lat, longitude: $0.lon).distance(from: origin)) }
                        .filter { $0.m < 30_000 }
                        .sorted { $0.m < $1.m }
                        .map(\.p)
                    var merged: [ChurchPlace] = []
                    var seen = Set<String>()
                    for p in rank(scored.filter { $0.coverage > 0 }, focus: focus) + nearest
                    where seen.insert(p.id).inserted { merged.append(p) }
                    suggestions = makeSuggestions(merged)
                } else {
                    suggestions = makeSuggestions(rank(scored, focus: focus))
                }
            } else if suggestions.isEmpty {
                await searchAsPlace(query, near: near)
                return
            }
        }

        // Append Apple's live results for churches OSM may be missing — but
        // never when the query named a region, since a live search biased to
        // the user's own (possibly foreign / simulator) location would drag in
        // exactly the far-away results we just filtered out.
        if primaryRegionBox == nil, scored.count < 8 || bestCoverage < 1.0 {
            isLoading = true
            let liveMatches = await liveChurchSearch(query, near: near)
            isLoading = false
            if Task.isCancelled { return }
            var seenKeys = Set(suggestions.map(dedupeKey))
            var appended: [SearchSuggestion] = []
            for match in liveMatches where !seenKeys.contains(dedupeKey(match)) {
                seenKeys.insert(dedupeKey(match))
                appended.append(match)
            }
            if !appended.isEmpty { suggestions += appended }
        }
    }

    private func makeSuggestions(_ places: [ChurchPlace]) -> [SearchSuggestion] {
        places.prefix(60).map {
            SearchSuggestion(id: $0.id, name: $0.name, locality: $0.locality, coordinate: $0.coordinate,
                             kind: $0.kind == .monastery ? .monastery : .church)
        }
    }

    private func sortByDistance(_ places: [ChurchPlace], to focus: CLLocationCoordinate2D?) -> [ChurchPlace] {
        guard let focus else { return places }
        let origin = CLLocation(latitude: focus.latitude, longitude: focus.longitude)
        return places.sorted {
            CLLocation(latitude: $0.lat, longitude: $0.lon).distance(from: origin) <
            CLLocation(latitude: $1.lat, longitude: $1.lon).distance(from: origin)
        }
    }

    // Turn a place phrase ("στρόβολος", "λευκωσία", "κύπρος") into a coordinate
    // via Apple's map, so we can rank churches by nearness to it.
    private func geocodeFocus(_ text: String, near: CLLocationCoordinate2D?) async -> CLLocationCoordinate2D? {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = text
        if let near {
            request.region = MKCoordinateRegion(center: near,
                                                span: MKCoordinateSpan(latitudeDelta: 6, longitudeDelta: 6))
        }
        guard let response = try? await MKLocalSearch(request: request).start(),
              let first = response.mapItems.first else { return nil }
        return first.placemark.coordinate
    }

    // Offline fallback: if the location words match localities we already hold,
    // use the middle of those places as the focus. Works with no network for
    // any place that appears as a locality in our data (e.g. "Στρόβολος").
    private func focusFromData(_ tokens: [String]) -> CLLocationCoordinate2D? {
        guard !tokens.isEmpty else { return nil }
        let all = tokens.allSatisfy { t in searchIndex.contains { Self.wordHits($0.locKey, t) } }
        let matches = all
            ? searchIndex.filter { entry in tokens.allSatisfy { Self.wordHits(entry.locKey, $0) } }
            : searchIndex.filter { entry in tokens.contains { Self.wordHits(entry.locKey, $0) } }
        guard !matches.isEmpty else { return nil }
        let lats = matches.map(\.place.lat).sorted()
        let lons = matches.map(\.place.lon).sorted()
        return CLLocationCoordinate2D(latitude: lats[lats.count / 2], longitude: lons[lons.count / 2])
    }

    private func liveChurchSearch(_ query: String, near: CLLocationCoordinate2D?) async -> [SearchSuggestion] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.region = MKCoordinateRegion(
            center: near ?? CLLocationCoordinate2D(latitude: 35.1, longitude: 33.4),
            span: MKCoordinateSpan(latitudeDelta: 2.5, longitudeDelta: 2.5))

        guard let response = try? await MKLocalSearch(request: request).start() else { return [] }

        var found: [SearchSuggestion] = []
        for item in response.mapItems {
            guard let name = item.name, looksOrthodoxByName(name) else { continue }
            let coordinate = item.placemark.coordinate
            let locality = item.placemark.subLocality ?? item.placemark.locality
            let isMonastery = fold(name).contains("μον") || fold(name).contains("monast")
            let id = "live|\(name)|\(coordinate.latitude)|\(coordinate.longitude)"

            found.append(SearchSuggestion(id: id, name: name, locality: locality, coordinate: coordinate,
                                          kind: isMonastery ? .monastery : .church))

            // So a pin appears on the map too, for the rest of this session.
            if !allPlaces.contains(where: { $0.id == id }) {
                allPlaces.append(ChurchPlace(id: id, name: name, lat: coordinate.latitude,
                                             lon: coordinate.longitude,
                                             kind: isMonastery ? .monastery : .church,
                                             locality: locality))
            }
        }
        return found
    }

    private func searchAsPlace(_ query: String, near: CLLocationCoordinate2D?) async {
        let geocoder = CLGeocoder()
        guard let placemarks = try? await geocoder.geocodeAddressString(query),
              let coordinate = placemarks.first?.location?.coordinate else {
            suggestions = []
            return
        }

        let origin = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let nearby = allPlaces
            .map { (place: $0, meters: CLLocation(latitude: $0.lat, longitude: $0.lon).distance(from: origin)) }
            .filter { $0.meters < 20_000 }
            .sorted { $0.meters < $1.meters }
            .prefix(20)

        if nearby.isEmpty {
            suggestions = [SearchSuggestion(
                id: "place|\(coordinate.latitude)|\(coordinate.longitude)",
                name: query, locality: nil, coordinate: coordinate, kind: .place)]
        } else {
            suggestions = nearby.map {
                SearchSuggestion(id: $0.place.id, name: $0.place.name, locality: $0.place.locality,
                                 coordinate: $0.place.coordinate,
                                 kind: $0.place.kind == .monastery ? .monastery : .church)
            }
        }
    }

    private func dedupeKey(_ s: SearchSuggestion) -> String {
        "\(fold(s.name))|\(Int(s.coordinate.latitude * 1000))|\(Int(s.coordinate.longitude * 1000))"
    }

    func clearSuggestions() {
        suggestions = []
    }

    private func fold(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "el"))
            .lowercased()
    }

    // A script-agnostic key so that "Άγιος Γεώργιος", "agios georgios" and
    // "αγιος γεωργιος" all reduce to the same string. Greek and Greeklish are
    // both mapped to a common latin skeleton, so search works whatever the
    // user types. Static + pure so it can build the index off the main actor.
    nonisolated static func searchKey(_ text: String) -> String {
        var s = text.folding(options: .diacriticInsensitive, locale: Locale(identifier: "el")).lowercased()
        // unify sounds that Greeklish writes many ways, on both scripts
        for (a, b) in [("ου", "u"), ("ou", "u"),
                       ("αυ", "av"), ("au", "av"), ("ευ", "ev"), ("eu", "ev"),
                       // Greek αι and Greeklish ai have the modern sound "e".
                       // This also makes Εφραίμ / Efraim / Efrem identical.
                       ("αι", "e"), ("ai", "e"),
                       ("ει", "i"), ("ei", "i"), ("οι", "i"), ("oi", "i"),
                       // χ: x / ch / kh / standalone h. Preserve th as θ
                       // before consuming a remaining h as the χ sound.
                       ("ch", "x"), ("kh", "x"), ("ph", "f"), ("gh", "g"),
                       ("th", "θ"), ("h", "x"),
                       ("mb", "mp"), ("ks", "x"),
                       // Greeklish "y" for γ before a vowel: ayios→agios,
                       // panayia→panagia, ayiou→agiou (then →agiu).
                       ("ya", "ga"), ("ye", "ge"), ("yi", "gi"), ("yo", "go"), ("yu", "gu")] {
            s = s.replacingOccurrences(of: a, with: b)
        }
        var out = ""
        for ch in s {
            switch ch {
            case "α": out += "a"; case "β": out += "v"; case "γ": out += "g"
            case "δ": out += "d"; case "ε": out += "e"; case "ζ": out += "z"
            case "η": out += "i"; case "θ": out += "th"; case "ι": out += "i"
            case "κ": out += "k"; case "λ": out += "l"; case "μ": out += "m"
            case "ν": out += "n"; case "ξ": out += "x"; case "ο": out += "o"
            case "π": out += "p"; case "ρ": out += "r"; case "σ", "ς": out += "s"
            case "τ": out += "t"; case "υ": out += "i"; case "φ": out += "f"
            case "χ": out += "x"; case "ψ": out += "ps"; case "ω": out += "o"
            case "y": out += "i"; case "w": out += "o"; case "b": out += "v"
            case "h": break // usually silent in Greeklish
            case "a", "c", "d", "e", "f", "g", "i", "j", "k", "l", "m",
                 "n", "o", "p", "q", "r", "s", "t", "u", "v", "x", "z", " ":
                out.append(ch)
            default:
                if ch.isNumber { out.append(ch) }
            }
        }
        // Run the vowel rules once more after transliteration. Greek letters
        // can create new Latin pairs (for example ε + η -> "ei") that did not
        // exist during the first pass. Applying the same rules to every word
        // removes the need for saint-specific spelling exceptions.
        for (a, b) in [("ou", "u"), ("au", "av"), ("eu", "ev"),
                       ("ai", "e"), ("ei", "i"), ("oi", "i")] {
            out = out.replacingOccurrences(of: a, with: b)
        }
        return out.trimmingCharacters(in: .whitespaces)
    }

    // Does this one query word find a stem match among a key's words? Endings
    // are tolerated (so "αγιος" matches "Αγίου", "maxairas" matches "Μαχαιρά").
    nonisolated static func wordHits(_ key: String, _ q: String) -> Bool {
        for w in key.split(separator: " ") {
            let m = min(w.count, q.count)
            if m >= 3 && (w.hasPrefix(q) || q.hasPrefix(w)
                          || w.commonPrefix(with: q).count >= max(3, m - 1)) { return true }
        }
        return false
    }

    // How many query words find a stem match among the key's words.
    nonisolated static func scoreWords(_ key: String, _ queryWords: [String]) -> Int {
        queryWords.reduce(0) { $0 + (wordHits(key, $1) ? 1 : 0) }
    }

    // Best match quality (0…1) of one query word against a set of field words
    // (a name's or a locality's words). Handles, in order of confidence:
    // exact, prefix either way (partial typing), close spelling (typos), and a
    // shared stem. This is what lets "georgiou", "georgio", "gewrgiou" and a
    // one-letter slip all still find "Γεώργιος".
    nonisolated static func tokenScore(_ q: String, _ toks: [String]) -> Double {
        var best = 0.0
        for w in toks where !w.isEmpty {
            if w == q { return 1.0 }
            // Check grammatical equivalence before prefix heuristics so a
            // genitive form is not accidentally downgraded to a partial match.
            let ws = greekInflectionStem(w)
            let qs = greekInflectionStem(q)
            if ws.count >= 3 && ws == qs { return 1.0 }
            let m = Swift.min(w.count, q.count)
            // What you typed is the start of a church's word ("ag"→"Άγιος",
            // "georg"→"Γεώργιος"): the natural partial-typing / abbreviation case.
            if q.count >= 2 && w.hasPrefix(q) { best = Swift.max(best, 0.92); continue }
            // A church's word is the start of what you typed — only for longer
            // words, so a two-letter "Αγ." can't soak up a long word like "aglantzia".
            if w.count >= 4 && q.hasPrefix(w) { best = Swift.max(best, 0.9); continue }
            if m >= 3 {
                let cp = w.commonPrefix(with: q).count
                if cp >= Swift.max(4, m - 1) { best = Swift.max(best, 0.75); continue }
            }
            // Greeklish vowels are highly variable: Εφραίμ is commonly typed
            // Efrem, Efraim or Efreim. If two sufficiently long words have the
            // same consonant skeleton, treat them as strong phonetic variants.
            // This is deliberately secondary to exact/prefix matches and needs
            // at least three consonants, preventing short noisy collisions.
            if m >= 4 {
                let wc = consonantSkeleton(w)
                let qc = consonantSkeleton(q)
                if wc.count >= 3 && wc == qc { best = Swift.max(best, 0.88); continue }
            }
            // A very common typo is swapping two neighbouring letters. Plain
            // Levenshtein counts that as two edits, so recognise it explicitly.
            if m >= 4 && isAdjacentTransposition(w, q) {
                best = Swift.max(best, 0.84)
                continue
            }
            // Typo tolerance, but only when the words are long enough and of
            // similar length, so it never invents spurious matches.
            if m >= 4 && abs(w.count - q.count) <= 2 {
                let d = levenshtein(w, q, max: 2)
                if d == 1 { best = Swift.max(best, 0.82) }
                else if d == 2 && m >= 6 { best = Swift.max(best, 0.66) }
            }
        }
        return best
    }

    nonisolated private static func consonantSkeleton(_ word: String) -> String {
        String(word.filter { !"aeiou".contains($0) })
    }

    nonisolated private static func greekInflectionStem(_ word: String) -> String {
        // Ordered longest-first. A suffix is removed only when a meaningful
        // three-character stem remains, keeping short words out of this rule.
        for suffix in ["os", "ou", "as", "es", "is", "us", "u", "a", "i"]
        where word.count - suffix.count >= 3 && word.hasSuffix(suffix) {
            return String(word.dropLast(suffix.count))
        }
        return word
    }

    nonisolated private static func isAdjacentTransposition(_ a: String, _ b: String) -> Bool {
        let x = Array(a), y = Array(b)
        guard x.count == y.count else { return false }
        let differences = x.indices.filter { x[$0] != y[$0] }
        guard differences.count == 2,
              differences[1] == differences[0] + 1 else { return false }
        let i = differences[0], j = differences[1]
        return x[i] == y[j] && x[j] == y[i]
    }

    // Bounded Levenshtein edit distance — returns early once it exceeds `maxD`,
    // so it stays cheap even across the whole dataset.
    nonisolated static func levenshtein(_ a: String, _ b: String, max maxD: Int) -> Int {
        let s = Array(a), t = Array(b)
        let n = s.count, m = t.count
        if n == 0 { return m }
        if m == 0 { return n }
        if abs(n - m) > maxD { return maxD + 1 }
        var prev = Array(0...m)
        var cur = Array(repeating: 0, count: m + 1)
        for i in 1...n {
            cur[0] = i
            var rowMin = cur[0]
            for j in 1...m {
                let cost = s[i - 1] == t[j - 1] ? 0 : 1
                cur[j] = Swift.min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + cost)
                rowMin = Swift.min(rowMin, cur[j])
            }
            if rowMin > maxD { return maxD + 1 }
            swap(&prev, &cur)
        }
        return prev[m]
    }

    // MARK: - Name-based Orthodox check (for live results that carry no
    // denomination tag, kept in sync with the same lists in the Python script)

    private func looksOrthodoxByName(_ name: String) -> Bool {
        let folded = fold(name)
        if nameNegative.contains(where: { folded.contains($0) }) { return false }
        if nameOrthodox.contains(where: { folded.contains($0) }) { return true }
        if nameGreekEcclesiastical.contains(where: { folded.contains($0) }) { return true }
        return false
    }

    private let nameOrthodox: [String] = [
        "orthodox", "ορθοδοξ", "ελληνορθοδοξ", "ortodox", "orthodoxe",
        "православ", "правосл",
    ]

    private let nameGreekEcclesiastical: [String] = [
        "ιερος ναος", "ι.ν.", "ιερα μητροπ", "ιερα μονη", "καθεδρικος ναος",
        "παναγια", "αγιος ", "αγια ", "αγιου ", "αγιων ", "τιμιου σταυρου",
        "μεταμορφωσ", "κοιμησεως", "ευαγγελισμ",
    ]

    private let nameNegative: [String] = [
        "catholic", "καθολικ", "roman catholic", "lutheran", "baptist",
        "methodist", "evangel", "anglican", "presbyterian", "pentecost",
        "reformed church", "kingdom hall", "latter-day", "latter day",
        "mormon", "adventist", "jehovah", "calvin", "quaker", "προτεσταντ",
    ]
}
