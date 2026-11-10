import Foundation
import Observation
import CryptoKit

/// Optional, explicitly confirmed forms; legacy Diptycha entries decode unchanged.
struct PrayerNameGrammar: Codable, Hashable {
    enum Gender: String, Codable, CaseIterable { case masculine, feminine }
    var gender: Gender
    var accusative: String
    var genitive: String

    var isValid: Bool { !accusative.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !genitive.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}

enum PrayerRopeIntention: String, Codable, CaseIterable, Identifiable {
    case myself, living, sick, departed
    var id: String { rawValue }
    var title: String {
        switch self {
        case .myself: return "Για τον εαυτό μου"
        case .living: return "Για αγαπημένα πρόσωπα"
        case .sick: return "Για ασθενείς"
        case .departed: return "Για κεκοιμημένους"
        }
    }
    var category: DiptychaCategory? {
        switch self {
        case .myself: return nil
        case .living: return .zontes
        case .sick: return .astheneis
        case .departed: return .kekoimimenoi
        }
    }
}

struct PrayerRopeDraft: Codable, Equatable {
    static let lengths = [33, 100, 200, 300, 500]
    var intention: PrayerRopeIntention = .myself
    var length = 33
    var selectedIDs: [UUID] = []
    var showsPrayer = true

    func selected(from entries: [DiptychaEntry]) -> [DiptychaEntry] {
        entries.filter { selectedIDs.contains($0.id) && $0.category == intention.category }
    }

    func prayer(using entries: [DiptychaEntry]) -> String? {
        guard Self.lengths.contains(length) else { return nil }
        if intention == .myself { return "Κύριε Ιησού Χριστέ, ελέησόν με." }
        let people = selected(from: entries)
        guard !people.isEmpty, people.count == Set(selectedIDs).count,
              people.allSatisfy({ $0.resolvedPrayerGrammar != nil }) else { return nil }
        func names(_ list: [DiptychaEntry]) -> String {
            let forms = list.compactMap { intention == .departed ? $0.resolvedPrayerGrammar?.genitive : $0.resolvedPrayerGrammar?.accusative }
            return forms.count == 1 ? forms[0] : forms.dropLast().joined(separator: ", ") + " και " + (forms.last ?? "")
        }
        func phrase(_ list: [DiptychaEntry], male: Bool) -> String? {
            guard !list.isEmpty else { return nil }
            let singular = list.count == 1
            let prefix: String
            switch intention {
            case .departed:
                prefix = singular ? (male ? "την ψυχή του δούλου Σου " : "την ψυχή της δούλης Σου ") : (male ? "τις ψυχές των δούλων Σου " : "τις ψυχές των δουλών Σου ")
            case .sick:
                prefix = singular ? (male ? "τον ασθενούντα δούλο Σου " : "την ασθενούσα δούλη Σου ") : (male ? "τους ασθενούντες δούλους Σου " : "τις ασθενούσες δούλες Σου ")
            default:
                prefix = singular ? (male ? "τον δούλο Σου " : "τη δούλη Σου ") : (male ? "τους δούλους Σου " : "τις δούλες Σου ")
            }
            return prefix + names(list)
        }
        let men = people.filter { $0.resolvedPrayerGrammar?.gender == .masculine }
        let women = people.filter { $0.resolvedPrayerGrammar?.gender == .feminine }
        let clauses = [phrase(men, male: true), phrase(women, male: false)].compactMap { $0 }
        return "Κύριε Ιησού Χριστέ, " + (intention == .departed ? "ανάπαυσε " : "ελέησε ") + clauses.joined(separator: " και ") + "."
    }

    /// Compare only relevant fields, without duplicating the canonical names store.
    func revision(using entries: [DiptychaEntry]) -> String {
        let fields = selected(from: entries).sorted { $0.id.uuidString < $1.id.uuidString }.map {
            var fields = [$0.id.uuidString, $0.name, $0.category.rawValue, $0.prayerGrammar?.gender.rawValue ?? "",
                          $0.prayerGrammar?.accusative ?? "", $0.prayerGrammar?.genitive ?? ""]
            // Keep old revision hashes identical when the new optional field is absent.
            if let gender = $0.prayerGender { fields.append("gender:" + gender.rawValue) }
            return fields
        }
        let data = (try? JSONEncoder().encode(fields)) ?? Data()
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

struct PrayerRopeSession: Codable, Equatable {
    let id: UUID
    var draft: PrayerRopeDraft
    let prayer: String
    let namesRevision: String
    var count = 0
    var midpointNotified = false
    var completionNotified = false
    var focused = false
    var isComplete: Bool { count == draft.length }
    func needsReview(using entries: [DiptychaEntry]) -> Bool {
        draft.intention != .myself && (namesRevision != draft.revision(using: entries) || draft.prayer(using: entries) == nil)
    }
}

@MainActor @Observable
final class PrayerRopeStore {
    enum Milestone: Equatable { case midpoint, completion }
    private struct Archive: Codable {
        var version = 1
        var draft: PrayerRopeDraft
        var session: PrayerRopeSession?
    }
    var draft = PrayerRopeDraft()
    private(set) var session: PrayerRopeSession?
    private(set) var storageIssue: String?
    private let storageURL: URL

    init(storageURL: URL? = nil) {
        self.storageURL = storageURL ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Klimax/prayer-rope.json")
        guard FileManager.default.fileExists(atPath: self.storageURL.path) else { return }
        do {
            let archive = try JSONDecoder().decode(Archive.self, from: Data(contentsOf: self.storageURL))
            guard archive.version == 1, PrayerRopeDraft.lengths.contains(archive.draft.length),
                  archive.session.map({ PrayerRopeDraft.lengths.contains($0.draft.length) && (0...$0.draft.length).contains($0.count) }) ?? true else {
                storageIssue = "Δεν ήταν δυνατή η ανάκτηση της αποθηκευμένης προσευχής."; return
            }
            draft = archive.draft; session = archive.session
        } catch { storageIssue = "Δεν ήταν δυνατή η ανάκτηση της αποθηκευμένης προσευχής." }
    }

    func save() {
        do {
            try FileManager.default.createDirectory(at: storageURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(Archive(draft: draft, session: session))
            var options: Data.WritingOptions = [.atomic]
            #if os(iOS)
            options.insert(.completeFileProtectionUntilFirstUserAuthentication)
            #endif
            try data.write(to: storageURL, options: options)
            storageIssue = nil
        } catch { storageIssue = "Η πρόοδος παραμένει στην οθόνη, αλλά δεν αποθηκεύτηκε στη συσκευή. Προσπάθησε ξανά πριν φύγεις." }
    }

    @discardableResult func start(using entries: [DiptychaEntry]) -> Bool {
        guard let text = draft.prayer(using: entries) else { return false }
        session = .init(id: UUID(), draft: draft, prayer: text, namesRevision: draft.revision(using: entries))
        save(); return true
    }

    @discardableResult func advance(using entries: [DiptychaEntry]) -> Bool {
        guard let current = session, !current.isComplete, !current.needsReview(using: entries) else { return false }
        session?.count += 1; session?.focused = true; save(); return true
    }

    /// Consumed once, after movement; callers suppress physical feedback while inactive.
    func consumeMilestone() -> Milestone? {
        guard let current = session else { return nil }
        let result: Milestone?
        if current.isComplete && !current.completionNotified {
            session?.midpointNotified = true; session?.completionNotified = true; result = .completion
        } else if current.count >= (current.draft.length + 1) / 2 && !current.midpointNotified {
            session?.midpointNotified = true; result = .midpoint
        } else { result = nil }
        if result != nil { save() }
        return result
    }
    func setFocused(_ value: Bool) { session?.focused = value; save() }
    func togglePrayer() { session?.draft.showsPrayer.toggle(); save() }
    func edit() { if let session { draft = session.draft }; save() }
    func restart(using entries: [DiptychaEntry]) {
        guard let current = session, !current.needsReview(using: entries) else { return }
        session = .init(id: UUID(), draft: current.draft, prayer: current.prayer, namesRevision: current.namesRevision)
        save()
    }
    func finish() { session = nil; save() }
}

/// Local lexicon plus declension families. Unfamiliar forms are never fabricated.
enum GreekPrayerNames {
    typealias Gender = PrayerNameGrammar.Gender
    private struct Entry {
        let gender: Gender
        let nominative: String
        let accusative: String
        let genitive: String
        var grammar: PrayerNameGrammar { .init(gender: gender, accusative: accusative, genitive: genitive) }
    }
    private static let locale = Locale(identifier: "el_GR")
    private static func key(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: locale)
            .lowercased(with: locale).replacingOccurrences(of: "ς", with: "σ")
    }
    private static let ambiguous = Set("Άλεξ|Αλέξ|Αλέξις|Ανδρέα|Αντρέα|Σάσα|Ρενέ|Άριελ|Κιμ|Σαμ|Τζέιμι|Τζόρνταν|Άντι|Ντάνι|Τσάρλι|Ρόμπιν|Νόα|Ντάλας|Alex|Alexis|Andrea|Sasha|Rene|Ariel|Kim|Sam|Jamie|Jordan|Andy|Dani|Charlie|Robin|Noa|Dallas|Jean|Joan".split(separator: "|").map { key(String($0)) })
    private static let entries: [Entry] = lexicon.split(separator: "\n").compactMap { line in
        let fields = line.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
        guard fields.count == 4 else { return nil }
        return Entry(gender: fields[0] == "m" ? .masculine : .feminine,
                     nominative: fields[1], accusative: fields[2], genitive: fields[3])
    }

    private static let canonicalIndex = Dictionary(grouping: entries, by: { key($0.nominative) })
    private static let aliasIndex: [String: [Entry]] = {
        var result: [String: [Entry]] = [:]
        for entry in entries {
            for alias in Set([key(entry.accusative), key(entry.genitive)]) { result[alias, default: []].append(entry) }
        }
        return result
    }()

    static func resolve(_ name: String, gender: Gender? = nil, manual: PrayerNameGrammar? = nil) -> PrayerNameGrammar? {
        if let manual, manual.isValid, gender == nil || gender == manual.gender { return manual }
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines).precomposedStringWithCanonicalMapping
        guard !clean.isEmpty else { return nil }
        if let value = single(clean, gender: gender) { return value }
        let parts = clean.components(separatedBy: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "-‐‑"))).filter { !$0.isEmpty }
        if parts.count > 1, !clean.contains(","), !clean.contains(";") {
            let known = parts.compactMap { single($0, gender: gender)?.gender }
            let genders = Set(known)
            if let chosen = gender ?? (genders.count == 1 ? genders.first : nil) {
                let values = parts.map { single($0, gender: chosen) ?? unchanged($0, gender: chosen) }
                let separator = clean.contains("-") || clean.contains("‐") || clean.contains("‑") ? "-" : " "
                return .init(gender: chosen, accusative: values.map(\.accusative).joined(separator: separator),
                             genitive: values.map(\.genitive).joined(separator: separator))
            }
        }
        return gender.map { unchanged(clean, gender: $0) }
    }

    private static func unchanged(_ name: String, gender: Gender) -> PrayerNameGrammar {
        .init(gender: gender, accusative: name, genitive: name)
    }

    private static func single(_ name: String, gender: Gender?) -> PrayerNameGrammar? {
        let normalized = key(name)
        if ambiguous.contains(normalized) { return gender.map { unchanged(name, gender: $0) } }
        if let exact = canonicalIndex[normalized]?.first(where: { gender == nil || $0.gender == gender }) { return exact.grammar }
        let aliases = (aliasIndex[normalized] ?? []).filter { gender == nil || $0.gender == gender }
        if aliases.count == 1 { return aliases[0].grammar }
        guard !normalized.isEmpty, normalized.allSatisfy({ ("α"..."ω").contains($0) }) else { return nil }
        let inferred: Gender?
        if normalized.hasSuffix("οσ") || normalized.hasSuffix("ησ") || normalized.hasSuffix("ασ") { inferred = .masculine }
        else if normalized.hasSuffix("α") || normalized.hasSuffix("η") { inferred = .feminine }
        else { inferred = nil }
        guard let chosen = gender ?? inferred else { return nil }
        func ending(_ value: String) -> String { name == name.uppercased(with: locale) ? value.uppercased(with: locale) : value }
        if chosen == .masculine && normalized.hasSuffix("οσ") {
            let accusative = String(name.dropLast())
            var genitive = String(name.dropLast(2)) + ending("ου")
            let vowels = nuclei(Array(name))
            if let stress = vowels.lastIndex(where: { hasTonos(Array(name)[$0]) }), vowels.count - stress >= 3 {
                genitive = penultimateStress(genitive)
            }
            return .init(gender: chosen, accusative: accusative, genitive: genitive)
        }
        if chosen == .masculine && (normalized.hasSuffix("ησ") || normalized.hasSuffix("ασ")) {
            return .init(gender: chosen, accusative: String(name.dropLast()), genitive: String(name.dropLast()))
        }
        if chosen == .feminine && (normalized.hasSuffix("α") || normalized.hasSuffix("η")) {
            return .init(gender: chosen, accusative: name, genitive: name + ending("ς"))
        }
        return gender.map { unchanged(name, gender: $0) }
    }

    private static func hasTonos(_ value: Character) -> Bool {
        String(value).decomposedStringWithCanonicalMapping.unicodeScalars.contains { $0.value == 0x301 }
    }
    private static func hasDiaeresis(_ value: Character) -> Bool {
        String(value).decomposedStringWithCanonicalMapping.unicodeScalars.contains { $0.value == 0x308 }
    }
    private static func nuclei(_ word: [Character]) -> [Int] {
        var result: [Int] = [], index = 0
        let vowels = Set("αεηιουω"), pairs: Set<String> = ["αι", "ει", "οι", "υι", "ου", "αυ", "ευ", "ηυ"]
        while index < word.count {
            let current = key(String(word[index]))
            if current.count == 1, let letter = current.first, vowels.contains(letter) {
                if index + 1 < word.count, pairs.contains(current + key(String(word[index + 1]))),
                   !hasDiaeresis(word[index + 1]), !hasTonos(word[index]) {
                    result.append(index + 1); index += 2; continue
                }
                result.append(index)
            }
            index += 1
        }
        return result
    }
    private static func penultimateStress(_ value: String) -> String {
        let scalars = value.decomposedStringWithCanonicalMapping.unicodeScalars.filter { $0.value != 0x301 }
        var word = Array(String(String.UnicodeScalarView(scalars)).precomposedStringWithCanonicalMapping)
        let vowels = nuclei(word)
        guard vowels.count >= 2 else { return value }
        let target = vowels[vowels.count - 2]
        word[target] = Character((String(word[target]) + "\u{301}").precomposedStringWithCanonicalMapping)
        return String(word)
    }

    // Explicit forms cover common names, nicknames, indeclinables and irregular genitives.
    private static let lexicon = """
m|Γεώργιος|Γεώργιο|Γεωργίου
m|Γιώργος|Γιώργο|Γιώργου
m|Ιωάννης|Ιωάννη|Ιωάννη
m|Γιάννης|Γιάννη|Γιάννη
m|Δημήτριος|Δημήτριο|Δημητρίου
m|Δημήτρης|Δημήτρη|Δημήτρη
m|Κωνσταντίνος|Κωνσταντίνο|Κωνσταντίνου
m|Κώστας|Κώστα|Κώστα
m|Νικόλαος|Νικόλαο|Νικολάου
m|Νίκος|Νίκο|Νίκου
m|Παναγιώτης|Παναγιώτη|Παναγιώτη
m|Βασίλειος|Βασίλειο|Βασιλείου
m|Βασίλης|Βασίλη|Βασίλη
m|Χρήστος|Χρήστο|Χρήστου
m|Χριστόφορος|Χριστόφορο|Χριστοφόρου
m|Αθανάσιος|Αθανάσιο|Αθανασίου
m|Θανάσης|Θανάση|Θανάση
m|Μιχαήλ|Μιχαήλ|Μιχαήλ
m|Μιχάλης|Μιχάλη|Μιχάλη
m|Εμμανουήλ|Εμμανουήλ|Εμμανουήλ
m|Μανώλης|Μανώλη|Μανώλη
m|Μανόλης|Μανόλη|Μανόλη
m|Στέφανος|Στέφανο|Στεφάνου
m|Αλέξανδρος|Αλέξανδρο|Αλεξάνδρου
m|Αλέξιος|Αλέξιο|Αλεξίου
m|Αλέξης|Αλέξη|Αλέξη
m|Ανδρέας|Ανδρέα|Ανδρέα
m|Αντρέας|Αντρέα|Αντρέα
m|Αντώνιος|Αντώνιο|Αντωνίου
m|Αντώνης|Αντώνη|Αντώνη
m|Θεόδωρος|Θεόδωρο|Θεοδώρου
m|Θοδωρής|Θοδωρή|Θοδωρή
m|Θωμάς|Θωμά|Θωμά
m|Σπυρίδων|Σπυρίδωνα|Σπυρίδωνα
m|Σπύρος|Σπύρο|Σπύρου
m|Πέτρος|Πέτρο|Πέτρου
m|Παύλος|Παύλο|Παύλου
m|Απόστολος|Απόστολο|Αποστόλου
m|Φίλιππος|Φίλιππο|Φιλίππου
m|Ευάγγελος|Ευάγγελο|Ευαγγέλου
m|Βαγγέλης|Βαγγέλη|Βαγγέλη
m|Άγγελος|Άγγελο|Αγγέλου
m|Σταύρος|Σταύρο|Σταύρου
m|Στυλιανός|Στυλιανό|Στυλιανού
m|Στέλιος|Στέλιο|Στέλιου
m|Ελευθέριος|Ελευθέριο|Ελευθερίου
m|Λευτέρης|Λευτέρη|Λευτέρη
m|Χαράλαμπος|Χαράλαμπο|Χαραλάμπους
m|Μπάμπης|Μπάμπη|Μπάμπη
m|Παντελεήμων|Παντελεήμονα|Παντελεήμονα
m|Παντελής|Παντελή|Παντελή
m|Ιάκωβος|Ιάκωβο|Ιακώβου
m|Ισαάκ|Ισαάκ|Ισαάκ
m|Ιακώβ|Ιακώβ|Ιακώβ
m|Αβραάμ|Αβραάμ|Αβραάμ
m|Αδάμ|Αδάμ|Αδάμ
m|Δαβίδ|Δαβίδ|Δαβίδ
m|Δανιήλ|Δανιήλ|Δανιήλ
m|Σαμουήλ|Σαμουήλ|Σαμουήλ
m|Ραφαήλ|Ραφαήλ|Ραφαήλ
m|Γαβριήλ|Γαβριήλ|Γαβριήλ
m|Μωυσής|Μωυσή|Μωυσή
m|Ηλίας|Ηλία|Ηλία
m|Ησαΐας|Ησαΐα|Ησαΐα
m|Ιερεμίας|Ιερεμία|Ιερεμία
m|Σάββας|Σάββα|Σάββα
m|Νικήτας|Νικήτα|Νικήτα
m|Σωτήριος|Σωτήριο|Σωτηρίου
m|Σωτήρης|Σωτήρη|Σωτήρη
m|Διονύσιος|Διονύσιο|Διονυσίου
m|Διονύσης|Διονύση|Διονύση
m|Γρηγόριος|Γρηγόριο|Γρηγορίου
m|Γρηγόρης|Γρηγόρη|Γρηγόρη
m|Κυριάκος|Κυριάκο|Κυριάκου
m|Ευστάθιος|Ευστάθιο|Ευσταθίου
m|Στάθης|Στάθη|Στάθη
m|Λουκάς|Λουκά|Λουκά
m|Ματθαίος|Ματθαίο|Ματθαίου
m|Μάρκος|Μάρκο|Μάρκου
m|Ισίδωρος|Ισίδωρο|Ισιδώρου
m|Λεωνίδας|Λεωνίδα|Λεωνίδα
m|Νεκτάριος|Νεκτάριο|Νεκταρίου
m|Παΐσιος|Παΐσιο|Παϊσίου
m|Πορφύριος|Πορφύριο|Πορφυρίου
m|Ευμένιος|Ευμένιο|Ευμενίου
m|Αρσένιος|Αρσένιο|Αρσενίου
m|Σεραφείμ|Σεραφείμ|Σεραφείμ
m|Χρυσόστομος|Χρυσόστομο|Χρυσοστόμου
m|Σωκράτης|Σωκράτη|Σωκράτους
m|Αριστοτέλης|Αριστοτέλη|Αριστοτέλους
m|Περικλής|Περικλή|Περικλέους
m|Ηρακλής|Ηρακλή|Ηρακλέους
m|Σοφοκλής|Σοφοκλή|Σοφοκλέους
f|Μαρία|Μαρία|Μαρίας
f|Μαίρη|Μαίρη|Μαίρης
f|Μαριάννα|Μαριάννα|Μαριάννας
f|Ελένη|Ελένη|Ελένης
f|Άννα|Άννα|Άννας
f|Αναστασία|Αναστασία|Αναστασίας
f|Βασιλική|Βασιλική|Βασιλικής
f|Γεωργία|Γεωργία|Γεωργίας
f|Δήμητρα|Δήμητρα|Δήμητρας
f|Κατερίνα|Κατερίνα|Κατερίνας
f|Αικατερίνη|Αικατερίνη|Αικατερίνης
f|Σοφία|Σοφία|Σοφίας
f|Παρασκευή|Παρασκευή|Παρασκευής
f|Ευαγγελία|Ευαγγελία|Ευαγγελίας
f|Αγγελική|Αγγελική|Αγγελικής
f|Αλεξάνδρα|Αλεξάνδρα|Αλεξάνδρας
f|Αλεξία|Αλεξία|Αλεξίας
f|Ιωάννα|Ιωάννα|Ιωάννας
f|Ιουλία|Ιουλία|Ιουλίας
f|Κωνσταντίνα|Κωνσταντίνα|Κωνσταντίνας
f|Χριστίνα|Χριστίνα|Χριστίνας
f|Χρυσούλα|Χρυσούλα|Χρυσούλας
f|Χαρά|Χαρά|Χαράς
f|Χαρίκλεια|Χαρίκλεια|Χαρικλείας
f|Φωτεινή|Φωτεινή|Φωτεινής
f|Παναγιώτα|Παναγιώτα|Παναγιώτας
f|Ευγενία|Ευγενία|Ευγενίας
f|Ευτυχία|Ευτυχία|Ευτυχίας
f|Ειρήνη|Ειρήνη|Ειρήνης
f|Κυριακή|Κυριακή|Κυριακής
f|Σταυρούλα|Σταυρούλα|Σταυρούλας
f|Στυλιανή|Στυλιανή|Στυλιανής
f|Θεοδώρα|Θεοδώρα|Θεοδώρας
f|Δέσποινα|Δέσποινα|Δέσποινας
f|Ελισάβετ|Ελισάβετ|Ελισάβετ
f|Ζωή|Ζωή|Ζωής
f|Ευδοκία|Ευδοκία|Ευδοκίας
f|Θεοφανία|Θεοφανία|Θεοφανίας
f|Αθηνά|Αθηνά|Αθηνάς
f|Αγάπη|Αγάπη|Αγάπης
f|Ελπίδα|Ελπίδα|Ελπίδας
f|Ανθούλα|Ανθούλα|Ανθούλας
f|Αντιγόνη|Αντιγόνη|Αντιγόνης
f|Αγνή|Αγνή|Αγνής
f|Ανδρονίκη|Ανδρονίκη|Ανδρονίκης
f|Ευφροσύνη|Ευφροσύνη|Ευφροσύνης
f|Βαρβάρα|Βαρβάρα|Βαρβάρας
f|Μαρίνα|Μαρίνα|Μαρίνας
f|Μαγδαληνή|Μαγδαληνή|Μαγδαληνής
f|Μελπομένη|Μελπομένη|Μελπομένης
f|Δανάη|Δανάη|Δανάης
f|Δάφνη|Δάφνη|Δάφνης
f|Δωροθέα|Δωροθέα|Δωροθέας
f|Νίκη|Νίκη|Νίκης
f|Νικολέτα|Νικολέτα|Νικολέτας
f|Χριστιάνα|Χριστιάνα|Χριστιάνας
f|Σεραφειμία|Σεραφειμία|Σεραφειμίας
f|Αθανασία|Αθανασία|Αθανασίας
f|Πηνελόπη|Πηνελόπη|Πηνελόπης
f|Ολυμπία|Ολυμπία|Ολυμπίας
f|Σαλώμη|Σαλώμη|Σαλώμης
f|Ραχήλ|Ραχήλ|Ραχήλ
f|Ρεβέκκα|Ρεβέκκα|Ρεβέκκας
f|Σάρα|Σάρα|Σάρας
f|Εύα|Εύα|Εύας
f|Ευρυδίκη|Ευρυδίκη|Ευρυδίκης
f|Χλόη|Χλόη|Χλόης
f|Μυρτώ|Μυρτώ|Μυρτώς
f|Κλειώ|Κλειώ|Κλειώς
f|Σαπφώ|Σαπφώ|Σαπφούς
f|Λητώ|Λητώ|Λητώς
f|Ερατώ|Ερατώ|Ερατώς
f|Καλυψώ|Καλυψώ|Καλυψούς
f|Δρόσος|Δρόσο|Δρόσου
"""
}
