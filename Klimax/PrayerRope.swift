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
              people.allSatisfy({ $0.prayerGrammar?.isValid == true }) else { return nil }
        func names(_ list: [DiptychaEntry]) -> String {
            let forms = list.compactMap { intention == .departed ? $0.prayerGrammar?.genitive : $0.prayerGrammar?.accusative }
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
        let men = people.filter { $0.prayerGrammar?.gender == .masculine }
        let women = people.filter { $0.prayerGrammar?.gender == .feminine }
        let clauses = [phrase(men, male: true), phrase(women, male: false)].compactMap { $0 }
        return "Κύριε Ιησού Χριστέ, " + (intention == .departed ? "ανάπαυσε " : "ελέησε ") + clauses.joined(separator: " και ") + "."
    }

    /// Compare only relevant fields, without duplicating the canonical names store.
    func revision(using entries: [DiptychaEntry]) -> String {
        let fields = selected(from: entries).sorted { $0.id.uuidString < $1.id.uuidString }.map {
            [$0.id.uuidString, $0.name, $0.category.rawValue, $0.prayerGrammar?.gender.rawValue ?? "",
             $0.prayerGrammar?.accusative ?? "", $0.prayerGrammar?.genitive ?? ""]
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
