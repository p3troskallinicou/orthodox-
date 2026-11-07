//
//  SaintsCatalog.swift  ·  Klimax — Ἅγιοι (the Saints catalogue)
//  ───────────────────────────────────────────────────────────────────────────
//  The "Ἅγιοι" side of the Ladder tab: the full body of Orthodox saints,
//  organised BY RANK (Apostles, Prophets, Hierarchs, Martyrs, Venerables…).
//
//      Ἅγιοι  →  tap a rank  →  saints in that rank  →  tap a saint  →  detail
//
//  Content lives in Sanity and in a bundled saints.json seed — the same
//  Sanity → cache → bundle pattern as Scripture and Prayer. So the list shows
//  immediately from the seed and upgrades to live Sanity content automatically.
//
//  Each saint carries an optional `icon` (an image name in Assets). When we have
//  a real public-domain icon we drop the image in and set that name; until then
//  the saint shows a tasteful symbol for its rank. Each saint also carries a
//  `bio` (filled in the next step) shown on the detail page beneath the image.
//

import SwiftUI
import Observation

func saintSearchKey(_ text: String) -> String {
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

private func saintSearchMatches(queryKey: String, in haystackKey: String) -> Bool {
    if haystackKey.contains(queryKey) { return true }

    let haystackTokens = haystackKey.split(separator: " ").map(String.init)
    let queryTokens = queryKey.split(separator: " ").map(String.init)
    guard !queryTokens.isEmpty else { return false }

    return queryTokens.allSatisfy { token in
        if haystackKey.contains(token) { return true }
        if isSaintHonorificToken(token) {
            return haystackTokens.contains(where: isSaintHonorificToken)
        }
        return false
    }
}

private func isSaintHonorificToken(_ token: String) -> Bool {
    [
        "αγιοσ", "αγιου", "αγια", "αγιασ", "αγιων",
        "οσιοσ", "οσιου", "οσια", "οσιασ", "οσιων",
        "αγ", "οσ",
        "agios", "agiou", "agia", "agias", "agion",
        "ayios", "ayiou", "ayia", "ayias",
        "osios", "osiou", "osia", "osias",
        "hosios", "hosiou", "hosia", "hosias",
        "saint", "st", "holy"
    ].contains(token)
}

// ===========================================================================
// MARK: - Models  (match saints.json and the Sanity result shape)
// ===========================================================================

struct SaintsData: Codable {
    let schemaVersion: Int?
    let language: String?
    let ranks: [SaintRank]
}

private struct SaintSearchResult: Identifiable {
    let saint: SaintEntry
    let rank: SaintRank
    var id: String { saint.id }
}

struct SaintRank: Codable, Identifiable, Hashable {
    let id: String
    let titleGreek: String
    let titleEnglish: String?
    let subtitle: String?
    let saints: [SaintEntry]
    static func == (l: Self, r: Self) -> Bool { l.id == r.id }
    func hash(into h: inout Hasher) { h.combine(id) }
}

struct SaintEntry: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let nameEnglish: String?
    let feast: String?
    let icon: String?          // image name in Assets, when we have a real icon
    let rankTitle: String?     // shown on the detail page
    let bio: [String]?         // our own composition, from the facts
    let apolytikion: Apolytikion?   // verbatim traditional hymn (public domain)
    let source: String?
    let sourceUrl: String?
    static func == (l: Self, r: Self) -> Bool { l.id == r.id }
    func hash(into h: inout Hasher) { h.combine(id) }

    var hasBio: Bool { (bio?.contains { !$0.isEmpty }) ?? false }

    /// The calendar/horologion may describe a whole commemoration in `name`.
    /// Cards represent a person, so they use a concise personal title while the
    /// complete liturgical wording remains available in `commemorationTitle`.
    var displayName: String { SaintPresentation.cardName(for: self) }

    var commemorationTitle: String? {
        let title = displayName
        return title == name ? nil : name
    }

    var effectiveBio: [String] {
        let written = (bio ?? []).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        return written.isEmpty ? SaintPresentation.fallbackBio(for: self) : written
    }

    var effectiveApolytikion: Apolytikion {
        if let apolytikion, !apolytikion.textEl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return apolytikion
        }
        return SaintPresentation.fallbackApolytikion(for: self)
    }
}

@MainActor
private final class SaintFavoritesStore: ObservableObject {
    static let shared = SaintFavoritesStore()

    @Published private(set) var favoriteIDs: Set<String>
    private let storageKey = "klimax.saints.favoriteIDs"

    private init() {
        favoriteIDs = Set(UserDefaults.standard.stringArray(forKey: storageKey) ?? [])
    }

    func contains(_ saint: SaintEntry) -> Bool {
        favoriteIDs.contains(saint.id)
    }

    func toggle(_ saint: SaintEntry) {
        if favoriteIDs.contains(saint.id) {
            favoriteIDs.remove(saint.id)
        } else {
            favoriteIDs.insert(saint.id)
        }
        UserDefaults.standard.set(Array(favoriteIDs).sorted(), forKey: storageKey)
    }

    func favoriteResults(in ranks: [SaintRank]) -> [SaintSearchResult] {
        ranks.flatMap { rank in
            rank.saints.compactMap { saint in
                favoriteIDs.contains(saint.id) ? SaintSearchResult(saint: saint, rank: rank) : nil
            }
        }
    }
}

// The saint's apolytikion. `textEl` is the traditional hymn verbatim (public
// domain); `echos` is its mode (e.g. «Ἦχος δ´»).
struct Apolytikion: Codable, Hashable {
    let echos: String?
    let textEl: String
    let sourceNote: String?
}

private enum SaintPresentation {
    private static let explicitCardNames: [String: String] = [
        "andreasstratilatis": "Ἅγιος Ἀνδρέας ὁ Στρατηλάτης"
    ]

    static func cardName(for saint: SaintEntry) -> String {
        if let explicit = explicitCardNames[saint.id] { return explicit }

        let words = saint.name.split(whereSeparator: \.isWhitespace).map(String.init)
        let keys = words.map(key)
        guard !keys.isEmpty, isSingularSaint(keys[0]) else { return saint.name }

        for index in keys.indices where keys[index] == "και" {
            let tail = Array(keys.suffix(from: index + 1))
            guard marksCompanionGroup(tail) else { continue }
            let concise = words.prefix(index).joined(separator: " ")
            if !concise.isEmpty { return concise }
        }
        return saint.name
    }

    static func fallbackBio(for saint: SaintEntry) -> [String] {
        if saint.id == "andreasstratilatis" {
            return [
                "Ὁ Ἅγιος Ἀνδρέας ἦταν χριστιανὸς ἀξιωματικὸς καὶ στρατηλάτης. Ὅταν τὸ μικρὸ στράτευμα ποὺ διοικοῦσε βρέθηκε ἀπέναντι σὲ πολυάριθμο ἐχθρό, προέτρεψε τοὺς στρατιῶτες νὰ ἐπικαλεστοῦν μὲ πίστη τὸν Χριστό. Μετὰ τὴ νίκη τους, πολλοὶ ἀπὸ αὐτοὺς πίστεψαν καὶ βαπτίστηκαν.",
                "Ὅταν ὁ ἀρχιστράτηγος Ἀντίοχος πληροφορήθηκε τὴ μεταστροφὴ τους, ἔστειλε στρατιῶτες γιὰ νὰ τοὺς ἀφοπλίσουν. Ὁ Ἀνδρέας ὁδήγησε καὶ ἄλλους στὴν πίστη, καὶ τελικὰ ὁ ἴδιος καὶ οἱ 2.593 συναθλητές του μαρτύρησαν γιὰ τὸν Χριστό. Ἡ κοινὴ μνήμη τους τιμᾶται στὶς 19 Αὐγούστου."
            ]
        }

        let identity = key("\(saint.displayName) \(saint.rankTitle ?? "")")
        let article = grammaticalArticle(for: saint.displayName)
        let possessive = article == "Οἱ" ? "τους" : (article == "Ἡ" ? "της" : "του")
        let feastText = saint.feast.flatMap { $0.isEmpty ? nil : $0 }
            .map { " Ἡ μνήμη \(possessive) τιμᾶται στὶς \($0)." } ?? ""

        let service: String
        if identity.contains("αποστολ") {
            service = "τιμᾶται ἀνάμεσα στοὺς Ἀποστόλους καὶ τοὺς κήρυκες τοῦ Εὐαγγελίου."
        } else if identity.contains("προφητ") {
            service = "τιμᾶται ἀνάμεσα στοὺς Προφῆτες, ποὺ διακόνησαν τὸ θέλημα τοῦ Θεοῦ."
        } else if identity.contains("μαρτυρ") {
            service = "τιμᾶται γιὰ τὴ σταθερὴ ὁμολογία τοῦ Χριστοῦ καὶ τὸ μαρτυρικὸ του φρόνημα."
        } else if identity.contains("οσιο") || identity.contains("ασκητ") {
            service = "τιμᾶται γιὰ τὴν ἀσκητικὴ ζωή, τὴν προσευχὴ καὶ τὴν ἀφοσίωσή του στὸν Θεό."
        } else if identity.contains("επισκοπ") || identity.contains("πατριαρχ") || identity.contains("ιεραρχ") {
            service = "τιμᾶται ὡς ποιμένας τῆς Ἐκκλησίας καὶ διδάσκαλος τῆς Ὀρθόδοξης πίστης."
        } else if identity.contains("ομολογητ") {
            service = "τιμᾶται γιὰ τὴ σταθερὴ ὁμολογία καὶ τὴν πιστότητά του στὴν Ἐκκλησία."
        } else {
            service = "τιμᾶται στὸ Ἁγιολόγιο τῆς Ὀρθόδοξης Ἐκκλησίας."
        }

        var paragraphs = ["\(article) \(saint.displayName) \(service)\(feastText)"]
        if let commemoration = saint.commemorationTitle {
            paragraphs.append("Ἡ πλήρης κοινὴ μνήμη τοῦ Ὡρολογίου καταγράφεται ὡς: «\(commemoration)». Οἱ συναθλητὲς καὶ οἱ λοιποὶ τιμώμενοι διατηροῦνται ἔτσι στὴν ἐορτολογικὴ πληροφορία, χωρὶς νὰ μετατρέπονται σὲ ὄνομα τῆς προσωπικῆς κάρτας.")
        }
        return paragraphs
    }

    static func fallbackApolytikion(for saint: SaintEntry) -> Apolytikion {
        if saint.id == "andreasstratilatis" {
            return Apolytikion(
                echos: "Ἦχος γ´. Θείας πίστεως.",
                textEl: "Θείας πίστεως, τῇ δυναστείᾳ, προσενήνοχας, ὡς στρατηγέτης, τῷ Παντάνακτι στρατὸν θεοσύλλεκτον· τύπος γὰρ τούτων Ἀνδρέα γενόμενος, μαρτυρικῶς σὺν αὐτοῖς ἠνδραγάθησας. Μεθ᾿ ὧν πρέσβευε, Κυρίῳ τῷ σὲ δοξάσαντι, δωρήσασθαι ἡμῖν τὸ μέγα ἔλεος.",
                sourceNote: "Ἰδιαίτερον ἀπολυτίκιον τῆς κοινῆς μνήμης (δημόσια κτῆσις)"
            )
        }

        let identity = key("\(saint.displayName) \(saint.rankTitle ?? "")")
        let plural = grammaticalArticle(for: saint.displayName) == "Οἱ" || saint.commemorationTitle != nil
        let female = identity.hasPrefix("αγια ")
            || identity.hasPrefix("οσια ")
            || identity.contains("παρθενομαρτυ")

        if identity.contains("αποστολ") {
            return common("Ἦχος γ´", "Ἀπόστολοι ἅγιοι, πρεσβεύσατε τῷ ἐλεήμονι Θεῷ, ἵνα πταισμάτων ἄφεσιν παράσχῃ ταῖς ψυχαῖς ἡμῶν.", "Κοινὸν Ἀποστόλων")
        }
        if identity.contains("προφητ") {
            return common("Ἦχος β´", "Τῶν Προφητῶν σου τὴν μνήμην, Κύριε, ἑορτάζοντες, δι᾿ αὐτῶν σε δυσωποῦμεν· σῶσον τὰς ψυχὰς ἡμῶν.", "Κοινὸν Προφητῶν")
        }
        if identity.contains("μαρτυρ") {
            if plural {
                return common("Ἦχος δ´", "Οἱ Μάρτυρές σου, Κύριε, ἐν τῇ ἀθλήσει αὐτῶν, στεφάνους ἐκομίσαντο τῆς ἀφθαρσίας, ἐκ σοῦ τοῦ Θεοῦ ἡμῶν· σχόντες γὰρ τὴν ἰσχύν σου, τοὺς τυράννους καθεῖλον, ἔθραυσαν καὶ δαιμόνων τὰ ἀνίσχυρα θράση. Αὐτῶν ταῖς ἱκεσίαις, Χριστὲ ὁ Θεός, σῶσον τὰς ψυχὰς ἡμῶν.", "Κοινὸν πλειόνων Μαρτύρων")
            }
            if female {
                return common("Ἦχος δ´", "Ἡ ἀμνάς σου Ἰησοῦ, κράζει μεγάλῃ τῇ φωνῇ· Σὲ Νυμφίε μου ποθῶ, καὶ σὲ ζητοῦσα ἀθλῶ, καὶ συσταυροῦμαι καὶ συνθάπτομαι τῷ βαπτισμῷ σου· καὶ πάσχω διὰ σέ, ὡς βασιλεύσω σὺν σοί, καὶ θνήσκω ὑπὲρ σοῦ, ἵνα καὶ ζήσω ἐν σοί. Αὐτῆς πρεσβείαις, ὡς ἐλεήμων, σῶσον τὰς ψυχὰς ἡμῶν.", "Κοινὸν Μάρτυρος γυναικός")
            }
            return common("Ἦχος δ´", "Ὁ Μάρτυς σου, Κύριε, ἐν τῇ ἀθλήσει αὐτοῦ, τὸ στέφος ἐκομίσατο τῆς ἀφθαρσίας, ἐκ σοῦ τοῦ Θεοῦ ἡμῶν· ἔχων γὰρ τὴν ἰσχύν σου, τοὺς τυράννους καθεῖλεν, ἔθραυσε καὶ δαιμόνων τὰ ἀνίσχυρα θράση. Αὐτοῦ ταῖς ἱκεσίαις, Χριστὲ ὁ Θεός, σῶσον τὰς ψυχὰς ἡμῶν.", "Κοινὸν ἑνὸς Μάρτυρος")
        }
        if identity.contains("οσιο") || identity.contains("ασκητ") {
            if female {
                return common("Ἦχος πλ. δ´", "Ἐν σοὶ Μῆτερ ἀκριβῶς διεσώθη τὸ κατ᾿ εἰκόνα· λαβοῦσα γὰρ τὸν σταυρόν, ἠκολούθησας τῷ Χριστῷ, καὶ πράττουσα ἐδίδασκες, ὑπερορᾶν μὲν σαρκός, παρέρχεται γάρ, ἐπιμελεῖσθαι δὲ ψυχῆς, πράγματος ἀθανάτου· διὸ καὶ μετὰ Ἀγγέλων συναγάλλεται, Ὁσία, τὸ πνεῦμά σου.", "Κοινὸν Ὁσίας")
            }
            return common("Ἦχος πλ. δ´", "Ἐν σοὶ Πάτερ ἀκριβῶς διεσώθη τὸ κατ᾿ εἰκόνα· λαβὼν γὰρ τὸν σταυρόν, ἠκολούθησας τῷ Χριστῷ, καὶ πράττων ἐδίδασκες, ὑπερορᾶν μὲν σαρκός, παρέρχεται γάρ, ἐπιμελεῖσθαι δὲ ψυχῆς, πράγματος ἀθανάτου· διὸ καὶ μετὰ Ἀγγέλων συναγάλλεται, Ὅσιε, τὸ πνεῦμά σου.", "Κοινὸν Ὁσίου")
        }
        if identity.contains("αναργυρ") {
            return common("Ἦχος πλ. δ´", "Ἅγιοι Ἀνάργυροι καὶ θαυματουργοί, ἐπισκέψασθε τὰς ἀσθενείας ἡμῶν· δωρεὰν ἐλάβετε, δωρεὰν δότε ἡμῖν.", "Κοινὸν Ἀναργύρων")
        }
        if identity.contains("αρχαγγελ") || identity.contains("ασωματ") {
            return common("Ἦχος δ´", "Τῶν οὐρανίων στρατιῶν Ἀρχιστράτηγοι, δυσωποῦμεν ὑμᾶς ἀεὶ ἡμεῖς οἱ ἀνάξιοι, ἵνα ταῖς ὑμῶν δεήσεσι τειχίσητε ἡμᾶς, σκέπῃ τῶν πτερύγων τῆς ἀΰλου ὑμῶν δόξης.", "Κοινὸν Ἀρχαγγέλων")
        }
        if identity.contains("επισκοπ") || identity.contains("πατριαρχ") || identity.contains("ιεραρχ") {
            return common("Ἦχος δ´", "Κανόνα πίστεως καὶ εἰκόνα πραότητος, ἐγκρατείας διδάσκαλον, ἀνέδειξέ σε τῇ ποίμνῃ σου ἡ τῶν πραγμάτων ἀλήθεια· διὰ τοῦτο ἐκτήσω τῇ ταπεινώσει τὰ ὑψηλά, τῇ πτωχείᾳ τὰ πλούσια. Πάτερ Ἱεράρχα, πρέσβευε Χριστῷ τῷ Θεῷ, σωθῆναι τὰς ψυχὰς ἡμῶν.", "Κοινὸν Ἱεράρχου")
        }
        return common("Ἦχος δ´", "Ὁ Θεὸς τῶν Πατέρων ἡμῶν, ὁ ποιῶν ἀεὶ μεθ᾿ ἡμῶν κατὰ τὴν σὴν ἐπιείκειαν, μὴ ἀποστήσῃς τὸ ἔλεός σου ἀφ᾿ ἡμῶν, ἀλλὰ ταῖς αὐτῶν ἱκεσίαις, ἐν εἰρήνῃ κυβέρνησον τὴν ζωὴν ἡμῶν.", "Κοινὸν Ἁγίων")
    }

    private static func common(_ echos: String, _ text: String, _ label: String) -> Apolytikion {
        Apolytikion(echos: echos, textEl: text, sourceNote: "\(label) (δημόσια κτῆσις)")
    }

    private static func grammaticalArticle(for name: String) -> String {
        let first = key(name.split(whereSeparator: \.isWhitespace).first.map(String.init) ?? "")
        if ["αγιοι", "αγιες", "οσιοι", "οσιες"].contains(first) { return "Οἱ" }
        if ["αγια", "οσια", "δικαια", "προφητις"].contains(first) { return "Ἡ" }
        return "Ὁ"
    }

    private static func isSingularSaint(_ first: String) -> Bool {
        ["αγιος", "αγια", "οσιος", "οσια", "δικαιος", "δικαια", "προφητης", "προφητις"].contains(first)
    }

    private static func marksCompanionGroup(_ tail: [String]) -> Bool {
        guard !tail.isEmpty else { return false }
        if tail.starts(with: ["των", "συν"]) || tail.starts(with: ["οι", "συν"]) || tail.starts(with: ["οι", "μαζι"]) { return true }
        if tail.starts(with: ["η", "συνοδεια"]) || tail.starts(with: ["τα", "παιδια"]) || tail.starts(with: ["τα", "τεκνα"]) { return true }
        guard tail[0] == "οι" || tail[0] == "τα" else { return false }
        guard tail.count > 1 else { return false }
        let groupWords: Set<String> = ["δυο", "τρεις", "τρια", "τεσσερις", "πεντε", "εξι", "επτα", "οκτω", "εννεα", "δεκα", "σαραντα", "σαρανταπεντε", "εκατον", "διακοσιοι", "τριακοσιοι", "χιλιοι", "μαρτυρησαντες"]
        return groupWords.contains(tail[1]) || Int(tail[1]) != nil
    }

    private static func key(_ value: String) -> String {
        value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "el"))
            .lowercased()
            .replacingOccurrences(of: #"[^a-zα-ω0-9]+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// Shared symbol for a rank — used as the placeholder until a real icon exists.
enum SaintGlyph {
    static func forRank(_ id: String) -> String {
        switch id {
        case "theotokos":    return "star.circle.fill"
        case "apostoloi":   return "scroll.fill"
        case "profitai":    return "flame.fill"
        case "ierarchai":   return "cross.fill"
        case "martyres":    return "crown.fill"
        case "osioi":       return "leaf.fill"
        case "omologitai":  return "hand.raised.fill"
        case "anargyroi":   return "cross.case.fill"
        case "neomartyres": return "star.fill"
        case "dikaioi":     return "figure.stand"
        case "myroforoi":   return "drop.fill"
        case "synaxeis":    return "person.3.fill"
        default:            return "person.fill"
        }
    }
}

// ===========================================================================
// MARK: - Store  (bundled seed → cache → optional Sanity refresh)
// ===========================================================================

@Observable
final class SaintsStore {
    static let shared = SaintsStore()

    private(set) var ranks: [SaintRank] = []
    private(set) var isLoading = false
    private(set) var loadError: String?

    private static let projectID = "uqaka7yh"
    private static let dataset   = "production"

    func load() async {
        guard ranks.isEmpty, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        let bundled = try? Self.loadBundled()

        // The entire catalogue is available immediately on a clean, offline
        // installation. A network refresh only enriches this local baseline.
        if let bundled {
            ranks = bundled.ranks
            loadError = nil
        }

        if let cached = Self.loadCache(), !cached.ranks.isEmpty {
            ranks = bundled.map { Self.enrich(cached, with: $0).ranks } ?? cached.ranks
            loadError = nil
        }

        do {
            let live = try await Self.fetchFromSanity()
            if !live.ranks.isEmpty {
                let resolved = bundled.map { Self.enrich(live, with: $0) } ?? live
                ranks = resolved.ranks
                loadError = nil
                Self.saveCache(resolved)
                return
            }
        } catch { /* the bundled catalogue remains active */ }

        if ranks.isEmpty {
            loadError = "Δὲν φορτώθηκαν οἱ Ἅγιοι."
        }
    }

    // Flat lookup across every rank — lets the eortologio resolve a day's
    // `saintId` to the saint's catalogue entry and navigate to its page.
    func saint(byId id: String) -> SaintEntry? {
        for rank in ranks {
            if let match = rank.saints.first(where: { $0.id == id }) { return match }
        }
        return nil
    }

    private struct SanityResult: Codable { let result: SaintsData }
    private static func fetchFromSanity() async throws -> SaintsData {
        let groq = """
        {"schemaVersion":1,"language":"grc-polytonic","ranks":\
        *[_type=="saintRank"]|order(order)\
        {"id":rankId,titleGreek,titleEnglish,subtitle,saints}}
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

    private static func loadBundled() throws -> SaintsData {
        guard let url = Bundle.main.url(forResource: "saints", withExtension: "json") else {
            throw NSError(domain: "Klimax", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "saints.json not in the app bundle"])
        }
        return try JSONDecoder().decode(SaintsData.self, from: Data(contentsOf: url))
    }

    /// Sanity controls ordering and editorial updates, while the bundled
    /// catalogue guarantees that a stale live document cannot erase a life,
    /// hymn, or newly imported saint from the application.
    private static func enrich(_ primary: SaintsData, with bundled: SaintsData) -> SaintsData {
        let bundledRanks = Dictionary(uniqueKeysWithValues: bundled.ranks.map { ($0.id, $0) })
        var includedRankIDs = Set<String>()

        var mergedRanks = primary.ranks.map { liveRank -> SaintRank in
            includedRankIDs.insert(liveRank.id)
            guard let seedRank = bundledRanks[liveRank.id] else { return liveRank }

            let seedSaints = Dictionary(uniqueKeysWithValues: seedRank.saints.map { ($0.id, $0) })
            var includedSaintIDs = Set<String>()
            var saints = liveRank.saints.map { liveSaint -> SaintEntry in
                includedSaintIDs.insert(liveSaint.id)
                guard let seed = seedSaints[liveSaint.id] else { return liveSaint }
                return merge(liveSaint, with: seed)
            }
            saints.append(contentsOf: seedRank.saints.filter { !includedSaintIDs.contains($0.id) })

            return SaintRank(
                id: liveRank.id,
                titleGreek: liveRank.titleGreek,
                titleEnglish: liveRank.titleEnglish ?? seedRank.titleEnglish,
                subtitle: liveRank.subtitle ?? seedRank.subtitle,
                saints: saints
            )
        }
        mergedRanks.append(contentsOf: bundled.ranks.filter { !includedRankIDs.contains($0.id) })
        return SaintsData(
            schemaVersion: primary.schemaVersion ?? bundled.schemaVersion,
            language: primary.language ?? bundled.language,
            ranks: mergedRanks
        )
    }

    private static func merge(_ primary: SaintEntry, with bundled: SaintEntry) -> SaintEntry {
        let primaryBio = (primary.bio ?? []).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let bundledBio = (bundled.bio ?? []).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let primaryHymn = primary.apolytikion.flatMap {
            $0.textEl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0
        }
        let directBundledSource = bundled.sourceUrl.flatMap { value in
            value == "https://www.saint.gr" || value == "https://saint.gr" ? nil : value
        }
        let primaryIsKlimaxComposition = primary.source?.localizedCaseInsensitiveContains("Klimax") == true
            || primary.source?.localizedCaseInsensitiveContains("Σύνθεση") == true
            || primary.source?.localizedCaseInsensitiveContains("Σημείωση") == true
        let useBundledBio = primaryBio.isEmpty
            || (primaryIsKlimaxComposition
                && directBundledSource != nil
                && bundledBio.joined(separator: " ").count > primaryBio.joined(separator: " ").count)

        return SaintEntry(
            id: primary.id,
            name: primary.name.isEmpty ? bundled.name : primary.name,
            nameEnglish: primary.nameEnglish ?? bundled.nameEnglish,
            feast: primary.feast ?? bundled.feast,
            icon: primary.icon ?? bundled.icon,
            rankTitle: primary.rankTitle ?? bundled.rankTitle,
            bio: useBundledBio ? bundledBio : primaryBio,
            apolytikion: primaryHymn ?? bundled.apolytikion,
            source: useBundledBio ? (bundled.source ?? primary.source) : (primary.source ?? bundled.source),
            sourceUrl: directBundledSource ?? primary.sourceUrl ?? bundled.sourceUrl
        )
    }

    private static var cacheURL: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("saints_cache.json")
    }
    private static func saveCache(_ d: SaintsData) {
        if let data = try? JSONEncoder().encode(d) { try? data.write(to: cacheURL) }
    }
    private static func loadCache() -> SaintsData? {
        guard let data = try? Data(contentsOf: cacheURL) else { return nil }
        return try? JSONDecoder().decode(SaintsData.self, from: data)
    }
}

// ===========================================================================
// MARK: - Catalogue (the "Ἅγιοι" root — list of ranks)
// ===========================================================================

struct SaintsCatalogView: View {
    @State private var store = SaintsStore.shared
    @State private var query = ""
    @State private var showingCollection = false
    @ObservedObject private var favorites = SaintFavoritesStore.shared
    @ObservedObject private var collection = SaintCollectionStore.shared

    private var searchResults: [SaintSearchResult] {
        let queryKey = saintSearchKey(query)
        guard !queryKey.isEmpty else { return [] }

        return store.ranks.flatMap { rank in
            rank.saints.compactMap { saint in
                let haystack = saintSearchKey([
                    saint.name,
                    saint.nameEnglish ?? "",
                    saint.feast ?? "",
                    saint.rankTitle ?? "",
                    rank.titleGreek,
                    rank.titleEnglish ?? ""
                ].joined(separator: " "))
                return saintSearchMatches(queryKey: queryKey, in: haystack) ? SaintSearchResult(saint: saint, rank: rank) : nil
            }
        }
    }

    private var favoriteResults: [SaintSearchResult] {
        favorites.favoriteResults(in: store.ranks)
    }

    var body: some View {
        ZStack {
            Color.clear
            if store.ranks.isEmpty && store.isLoading {
                ProgressView().tint(Paper.gold)
            } else if store.ranks.isEmpty, let err = store.loadError {
                VStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 26)).foregroundStyle(Paper.gold)
                    Text(err).font(.system(size: 13)).foregroundStyle(Paper.inkMute)
                        .multilineTextAlignment(.center).padding(.horizontal, 40)
                }
            } else {
                VStack(spacing: 0) {
                    sectionPicker
                        .padding(.horizontal, 20).padding(.top, 82).padding(.bottom, 12)
                    if showingCollection {
                        SaintCollectionView(ranks: store.ranks, embedded: true)
                    } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        searchField
                            .padding(.bottom, 2)
                            .logosBlockRise(0)

                        if saintSearchKey(query).isEmpty {
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Γνώρισε τους Αγίους")
                                    .font(.system(size: 26, weight: .semibold, design: .serif)).foregroundStyle(Paper.ink)
                                Text("Βίοι, λόγοι και μνήμες. Διάλεξε μια κατηγορία για να ξεκινήσεις.")
                                    .font(.subheadline).foregroundStyle(Paper.inkMute)
                            }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 10)

                            if !favoriteResults.isEmpty {
                                NavigationLink {
                                    SaintFavoritesView(ranks: store.ranks)
                                } label: {
                                    SaintFavoritesRow(count: favoriteResults.count)
                                }
                                .buttonStyle(.plain)
                                .logosBlockRise(2)
                            }

                            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                                ForEach(store.ranks) { rank in
                                    NavigationLink(value: rank) {
                                        SaintRankRow(rank: rank)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .logosBlockRise(3)
                        } else if searchResults.isEmpty {
                            emptySearchState
                                .padding(.top, 28)
                                .logosBlockRise(1)
                        } else {
                            searchResultsLabel
                                .logosBlockRise(1)
                            LazyVStack(spacing: 12) {
                                ForEach(searchResults) { result in
                                    NavigationLink(value: result.saint) {
                                        SaintSearchRow(result: result)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .logosBlockRise(2)
                        }
                        Spacer(minLength: 24)
                    }
                    .padding(.horizontal, 20).padding(.top, 4)
                }
                    }
                }
            }
        }
        .task { await store.load() }
    }

    private var sectionPicker: some View {
        HStack(spacing: 5) {
            sectionButton("Βίοι Αγίων", symbol: "book.closed", collection: false)
            sectionButton("Η συλλογή μου", symbol: "rectangle.stack", collection: true)
        }
        .padding(4)
        .background(Paper.ink.opacity(0.045), in: RoundedRectangle(cornerRadius: 18))
    }

    private func sectionButton(_ title: String, symbol: String, collection: Bool) -> some View {
        let selected = showingCollection == collection
        return Button { showingCollection = collection } label: {
            Label(title, systemImage: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(selected ? Gild.accentForeground : Paper.inkMute)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(selected ? Paper.card : .clear, in: RoundedRectangle(cornerRadius: 14))
        }.buttonStyle(.plain)
            .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var searchField: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Paper.inkMute.opacity(0.8))
            TextField("Αναζήτηση αγίου…", text: $query)
                .font(.system(size: 15))
                .foregroundStyle(Paper.ink)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Paper.inkMute.opacity(0.55))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 13)
        .background(Paper.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Paper.hairline, lineWidth: 1))
        .shadow(color: .black.opacity(0.035), radius: 8, x: 0, y: 4)
    }

    private var searchResultsLabel: some View {
        Text("ΑΠΟΤΕΛΕΣΜΑΤΑ")
            .font(.system(size: 10, weight: .semibold)).tracking(2.5)
            .foregroundStyle(Paper.gold)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
            .padding(.top, 4)
    }

    private var emptySearchState: some View {
        VStack(spacing: 9) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Paper.gold.opacity(0.9))
            Text("Δὲν βρέθηκε ἅγιος")
                .font(.system(size: 18, weight: .regular, design: .serif))
                .foregroundStyle(Paper.ink)
            Text("Δοκίμασε μὲ λιγότερες λέξεις ἢ χωρὶς τόνους.")
                .font(.system(size: 12))
                .foregroundStyle(Paper.inkMute)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 26)
    }
}

private struct SaintCollectionEntryRow: View {
    let hasCollectedCards: Bool

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Paper.gold.opacity(0.11))
                    .frame(width: 31, height: 43)
                    .rotationEffect(.degrees(-8))
                    .offset(x: -5)

                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Paper.gold.opacity(0.78),
                                Paper.gold.opacity(0.34)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 31, height: 43)
                    .rotationEffect(.degrees(5))
                    .offset(x: 5)

                Image(systemName: "cross.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Paper.card)
                    .offset(x: 5)
            }
            .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 3) {
                Text("Συλλογὴ Ἁγίων")
                    .font(.system(size: 19, weight: .regular, design: .serif))
                    .foregroundStyle(Paper.ink)

                Text(
                    hasCollectedCards
                        ? "Οἱ κάρτες μνήμης ποὺ κράτησες."
                        : "Γνώρισε τοὺς Ἁγίους μέσα ἀπὸ κάρτες μνήμης."
                )
                .font(.system(size: 12, design: .serif))
                .foregroundStyle(Paper.inkMute)
                .lineLimit(2)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Paper.inkMute.opacity(0.6))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Paper.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Paper.gold.opacity(0.30), lineWidth: 1)
                )
        )
    }
}

private struct SaintFavoritesRow: View {
    let count: Int

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(Paper.gold.opacity(0.16)).frame(width: 44, height: 44)
                Image(systemName: "star.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Paper.gold)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("Αγαπημένοι")
                    .font(.system(size: 19, weight: .regular, design: .serif))
                    .foregroundStyle(Paper.ink)
                Text("\(count) \(count == 1 ? "ἅγιος" : "ἅγιοι")")
                    .font(.system(size: 12))
                    .foregroundStyle(Paper.inkMute)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Paper.inkMute.opacity(0.6))
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Paper.card)
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Paper.gold.opacity(0.30), lineWidth: 1)))
    }
}

private struct SaintRankRow: View {
    let rank: SaintRank
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                ZStack {
                RoundedRectangle(cornerRadius: 13).fill(Paper.gold.opacity(0.09)).frame(width: 42, height: 42)
                Image(systemName: SaintGlyph.forRank(rank.id))
                    .font(.system(size: 18)).foregroundStyle(Gild.accentForeground)
                }
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.right").font(.system(size: 11, weight: .semibold)).foregroundStyle(Paper.inkMute)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(rank.titleGreek.interfaceGreek)
                    .font(.system(size: 18, weight: .semibold, design: .serif))
                    .foregroundStyle(Paper.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text("\(rank.saints.count) Άγιοι")
                    .font(.system(size: 12)).foregroundStyle(Paper.inkMute)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 114, alignment: .topLeading)
        .padding(.horizontal, 16).padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Paper.card)
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Paper.hairline, lineWidth: 1)))
    }
}

private struct SaintFavoritesView: View {
    let ranks: [SaintRank]
    @ObservedObject private var favorites = SaintFavoritesStore.shared

    private var results: [SaintSearchResult] {
        favorites.favoriteResults(in: ranks)
    }

    var body: some View {
        ZStack {
            Paper.bg.ignoresSafeArea()
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(results) { result in
                        NavigationLink(value: result.saint) {
                            SaintSearchRow(result: result)
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer(minLength: 24)
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
            }
        }
        .navigationTitle("Αγαπημένοι")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct SaintSearchRow: View {
    let result: SaintSearchResult

    var body: some View {
        HStack(spacing: 14) {
            SaintAvatar(icon: result.saint.icon, rankID: result.rank.id, size: 44)
            VStack(alignment: .leading, spacing: 3) {
                Text(result.saint.displayName)
                    .font(.system(size: 17, weight: .regular, design: .serif))
                    .foregroundStyle(Paper.ink)
                    .multilineTextAlignment(.leading)
                Text(result.saint.feast ?? result.rank.titleGreek)
                    .font(.system(size: 12))
                    .foregroundStyle(Paper.inkMute)
                    .lineLimit(1)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Paper.inkMute.opacity(0.6))
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Paper.card)
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Paper.hairline, lineWidth: 1)))
    }
}

// ===========================================================================
// MARK: - Category (saints inside one rank)
// ===========================================================================

struct SaintCategoryView: View {
    let rank: SaintRank
    var body: some View {
        ZStack {
            Paper.bg.ignoresSafeArea()
            ScrollView {
                LazyVStack(spacing: 12) {
                    if let s = rank.subtitle, !s.isEmpty {
                        Text(s).font(.system(size: 13, design: .serif)).italic()
                            .foregroundStyle(Paper.inkMute).frame(maxWidth: .infinity)
                            .padding(.top, 6).padding(.bottom, 2)
                    }
                    ForEach(rank.saints) { saint in
                        NavigationLink(value: saint) {
                            SaintRow(saint: saint, rankID: rank.id)
                        }.buttonStyle(.plain)
                    }
                    Spacer(minLength: 24)
                }
                .padding(.horizontal, 20).padding(.top, 6)
            }
        }
        .navigationTitle(rank.titleGreek)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct SaintRow: View {
    let saint: SaintEntry
    let rankID: String
    var body: some View {
        HStack(spacing: 14) {
            SaintAvatar(icon: saint.icon, rankID: rankID, size: 44)
            VStack(alignment: .leading, spacing: 3) {
                Text(saint.displayName)
                    .font(.system(size: 17, weight: .regular, design: .serif))
                    .foregroundStyle(Paper.ink).multilineTextAlignment(.leading)
                if let f = saint.feast, !f.isEmpty {
                    Text(f).font(.system(size: 12)).foregroundStyle(Paper.inkMute)
                }
            }
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Paper.inkMute.opacity(0.6))
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Paper.card)
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Paper.hairline, lineWidth: 1)))
    }
}

// Round icon: real image if we have one, otherwise the rank symbol.
private struct SaintAvatar: View {
    let icon: String?
    let rankID: String
    let size: CGFloat
    var body: some View {
        ZStack {
            Circle().fill(Paper.gold.opacity(0.12)).frame(width: size, height: size)
            if let icon, !icon.isEmpty, UIImage(named: icon) != nil {
                Image(icon).resizable().scaledToFill()
                    .frame(width: size, height: size).clipShape(Circle())
            } else {
                Image(systemName: SaintGlyph.forRank(rankID))
                    .font(.system(size: size * 0.4)).foregroundStyle(Paper.gold)
            }
        }
    }
}

// ===========================================================================
// MARK: - Detail (icon on top + life beneath — life filled next step)
// ===========================================================================

struct SaintDetailView: View {
    let saint: SaintEntry

    private enum Panel: String, CaseIterable {
        case bios = "Βίος"
        case apolytikion = "Ἀπολυτίκιον"
    }
    @State private var panel: Panel = .bios
    @State private var saintsStore = SaintsStore.shared
    @ObservedObject private var favorites = SaintFavoritesStore.shared
    @ObservedObject private var collection = SaintCollectionStore.shared

    private var collectionItems: [SaintCollectionItem] {
        saintsStore.ranks.saintCollectionItems
    }

    private var collectionItem: SaintCollectionItem? {
        collectionItems.first(where: { $0.saint.id == saint.id })
    }

    var body: some View {
        ZStack {
            Paper.bg.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 0) {
                    SaintIconPanel(icon: saint.icon)
                        .padding(.top, 16)

                    Text(saint.displayName)
                        .font(.system(size: 24, weight: .regular, design: .serif))
                        .foregroundStyle(Paper.ink)
                        .multilineTextAlignment(.center)
                        .padding(.top, 18).padding(.horizontal, 24)

                    if let r = saint.rankTitle, !r.isEmpty {
                        Text(r)
                            .font(.system(size: 13, weight: .medium, design: .serif))
                            .foregroundStyle(Paper.gold)
                            .multilineTextAlignment(.center)
                            .padding(.top, 5).padding(.horizontal, 24)
                    }

                    if let f = saint.feast, !f.isEmpty {
                        Text("Μνήμη " + f)
                            .font(.system(size: 12, design: .serif)).italic()
                            .foregroundStyle(Paper.inkMute).padding(.top, 3)
                    }

                    if let commemoration = saint.commemorationTitle {
                        VStack(spacing: 4) {
                            Text("ΚΟΙΝΗ ΜΝΗΜΗ")
                                .font(.system(size: 10, weight: .bold))
                                .tracking(1.8)
                                .foregroundStyle(Paper.gold)
                            Text(commemoration)
                                .font(.system(size: 12, design: .serif))
                                .foregroundStyle(Paper.inkMute)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 10)
                        .padding(.horizontal, 24)
                    }

                    Rectangle().fill(Paper.gold.opacity(0.5)).frame(width: 48, height: 1.5)
                        .padding(.top, 18).padding(.bottom, 16)

                    if let collectionItem {
                        NavigationLink {
                            SaintCollectibleCardView(
                                item: collectionItem,
                                allItems: collectionItems,
                                showsCatalogLink: false
                            )
                        } label: {
                            HStack(spacing: 11) {
                                Image(
                                    systemName: collection.contains(saint)
                                        ? "rectangle.portrait.fill"
                                        : "rectangle.portrait"
                                )
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(Paper.gold)

                                Text(
                                    collection.contains(saint)
                                        ? "Δες τὴν κάρτα μνήμης"
                                        : "Γνώρισε καὶ κράτησε τὴν κάρτα"
                                )
                                .font(.system(size: 14, weight: .semibold, design: .serif))
                                .foregroundStyle(Paper.ink)
                                .lineLimit(2)

                                Spacer(minLength: 6)

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Paper.inkMute.opacity(0.65))
                            }
                            .padding(.horizontal, 15)
                            .frame(minHeight: 50)
                            .klimaxLiquidGlass(
                                in: RoundedRectangle(cornerRadius: 17, style: .continuous)
                            )
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 16)
                    }

                    // Two pills under the icon — choose Βίος or Ἀπολυτίκιον.
                    HStack(spacing: 8) {
                        ForEach(Panel.allCases, id: \.self) { p in
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) { panel = p }
                            } label: {
                                Text(p.rawValue)
                                    .font(.system(size: 14, weight: .semibold, design: .serif))
                                    .foregroundStyle(panel == p ? .white : Paper.inkMute)
                                    .padding(.horizontal, 20).padding(.vertical, 8)
                                    .background(Capsule().fill(panel == p ? Paper.gold : Color.clear))
                                    .overlay(Capsule().stroke(panel == p ? Color.clear : Paper.hairline, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.bottom, 22)

                    Group {
                        switch panel {
                        case .bios:        bioContent
                        case .apolytikion: apolytikionContent
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.bottom, 40)
            }
        }
        .task { await saintsStore.load() }
        .navigationTitle(saint.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    favorites.toggle(saint)
                } label: {
                    Image(systemName: favorites.contains(saint) ? "star.fill" : "star")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Paper.gold)
                }
                .accessibilityLabel(favorites.contains(saint) ? "Αφαίρεση από αγαπημένους" : "Προσθήκη στους αγαπημένους")
            }
        }
    }

    @ViewBuilder private var bioContent: some View {
        let bio = saint.effectiveBio
        if !bio.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(Array(bio.enumerated()), id: \.offset) { _, para in
                    Text(para)
                        .font(.system(size: 18, weight: .regular, design: .serif))
                        .foregroundStyle(Paper.ink).lineSpacing(7)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let s = saint.source, !s.isEmpty {
                    Text(s).font(.system(size: 11))
                        .foregroundStyle(Paper.inkMute.opacity(0.7)).padding(.top, 8)
                }
            }
            .padding(.horizontal, 24)
        } else {
            Text("Ὁ βίος προστίθεται σύντομα.")
                .font(.system(size: 14)).foregroundStyle(Paper.inkMute)
                .padding(.horizontal, 24).padding(.top, 8)
        }
    }

    @ViewBuilder private var apolytikionContent: some View {
        let apo = saint.effectiveApolytikion
        if !apo.textEl.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                if let e = apo.echos, !e.isEmpty {
                    Text(e)
                        .font(.system(size: 12, weight: .semibold, design: .serif))
                        .tracking(1.5).foregroundStyle(Paper.gold)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                Text(apo.textEl)
                    .font(.system(size: 18, design: .serif)).italic()
                    .foregroundStyle(Paper.ink).lineSpacing(7)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 24)
        } else {
            Text("Τὸ ἀπολυτίκιο προστίθεται σύντομα.")
                .font(.system(size: 14)).foregroundStyle(Paper.inkMute)
                .padding(.horizontal, 24).padding(.top, 8)
        }
    }
}

// Large icon on the detail page: the real icon shown big and fully (not cropped),
// framed like an icon with a thin gold border and a soft shadow.
private struct SaintIconPanel: View {
    let icon: String?
    var body: some View {
        Group {
            if let icon, !icon.isEmpty, UIImage(named: icon) != nil {
                SaintPortraitCanvas(icon: icon)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Paper.gold.opacity(0.10))
                    Image(systemName: "sparkles")
                        .font(.system(size: 52)).foregroundStyle(Paper.gold)
                }
            }
        }
        .aspectRatio(3.0 / 4.0, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Paper.gold.opacity(0.45), lineWidth: 1.5)
        )
        .shadow(color: Color.black.opacity(0.18), radius: 14, x: 0, y: 8)
        .padding(.horizontal, 36)
    }
}

struct SaintPortraitCanvas: View {
    let icon: String

    var body: some View {
        ZStack {
            Image(icon)
                .resizable()
                .interpolation(.high)
                .scaledToFill()
                .scaleEffect(1.08)
                .blur(radius: 22)
                .opacity(0.72)

            Image(icon)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
        }
        .clipped()
    }
}
