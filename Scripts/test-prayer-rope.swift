// Run on macOS with the installed Xcode Swift toolchain (no packages):
// swiftc -parse-as-library Klimax/Diptycha.swift Klimax/PrayerRope.swift Scripts/test-prayer-rope.swift -o /tmp/klimax-rope-tests && /tmp/klimax-rope-tests
import Foundation
import CryptoKit

@main struct PrayerRopeChecks {
    struct NameCase: Decodable {
        let name: String
        let hint: String?
        let gender: String?
        let accusative: String?
        let genitive: String?
        let unresolved: Bool?
    }
    @MainActor static func main() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("session.json")
        let encoder = JSONEncoder(), decoder = JSONDecoder()
        encoder.dateEncodingStrategy = .iso8601; decoder.dateDecodingStrategy = .iso8601
        let id = UUID()
        let legacy = """
        {"id":"\(id.uuidString)","name":"Γεώργιος","category":"zontes","note":"existing note","createdAt":"2026-01-01T00:00:00Z"}
        """
        var man = try decoder.decode(DiptychaEntry.self, from: Data(legacy.utf8))
        precondition(man.id == id && man.prayerGrammar == nil && man.note == "existing note")
        var draft = PrayerRopeDraft(intention: .living, selectedIDs: [id])
        precondition(draft.prayer(using: [man]) == "Κύριε Ιησού Χριστέ, ελέησε τον δούλο Σου Γεώργιο.", "Known legacy names must start without confirmation")
        precondition(man.prayerGrammar == nil && man.prayerGender == nil, "Inference must not rewrite existing entries")
        let alexID = UUID()
        var alex = DiptychaEntry(id: alexID, name: "Alex", category: .zontes)
        let ambiguous = PrayerRopeDraft(intention: .living, selectedIDs: [alexID])
        precondition(ambiguous.prayer(using: [alex]) == nil)
        alex.prayerGender = .feminine
        precondition(ambiguous.prayer(using: [alex]) == "Κύριε Ιησού Χριστέ, ελέησε τη δούλη Σου Alex.")
        precondition(GreekPrayerNames.resolve("Αγαθόδωρος")?.genitive == "Αγαθοδώρου")
        precondition(GreekPrayerNames.resolve("Άννα-Μαρία")?.genitive == "Άννας-Μαρίας")
        precondition(GreekPrayerNames.resolve("Σάσα") == nil)
        precondition(GreekPrayerNames.resolve("Σάσα", gender: .masculine)?.genitive == "Σάσα")
        let oldFields = [[man.id.uuidString, man.name, man.category.rawValue, "", "", ""]]
        let oldHash = SHA256.hash(data: try JSONEncoder().encode(oldFields)).map { String(format: "%02x", $0) }.joined()
        precondition(draft.revision(using: [man]) == oldHash, "Do not invalidate old session revisions without a gender change")
        let fixtureURL = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("prayer-name-cases.json")
        let cases = try JSONDecoder().decode([NameCase].self, from: Data(contentsOf: fixtureURL))
        for item in cases {
            let hint: PrayerNameGrammar.Gender? = item.hint.map { $0 == "m" ? .masculine : .feminine }
            let result = GreekPrayerNames.resolve(item.name, gender: hint)
            if item.unresolved == true { precondition(result == nil, item.name) }
            else {
                precondition(result?.accusative == item.accusative && result?.genitive == item.genitive, item.name)
                precondition(result?.gender == (item.gender == "m" ? .masculine : .feminine), item.name)
            }
        }
        man.prayerGrammar = .init(gender: .masculine, accusative: "Γεώργιο", genitive: "Γεωργίου")
        let woman = DiptychaEntry(name: "Μαρία", category: .zontes,
            prayerGrammar: .init(gender: .feminine, accusative: "Μαρία", genitive: "Μαρίας"))
        precondition(draft.prayer(using: [man]) == "Κύριε Ιησού Χριστέ, ελέησε τον δούλο Σου Γεώργιο.")
        draft.selectedIDs.append(woman.id)
        precondition(draft.prayer(using: [man, woman]) == "Κύριε Ιησού Χριστέ, ελέησε τον δούλο Σου Γεώργιο και τη δούλη Σου Μαρία.")
        var men = man, women = woman; men.category = .kekoimimenoi; women.category = .kekoimimenoi
        draft.intention = .departed
        precondition(draft.prayer(using: [men, women]) == "Κύριε Ιησού Χριστέ, ανάπαυσε την ψυχή του δούλου Σου Γεωργίου και την ψυχή της δούλης Σου Μαρίας.")
        precondition(draft.prayer(using: [men]) == nil, "Missing selected name must not silently disappear")
        for length in PrayerRopeDraft.lengths {
            var store = PrayerRopeStore(storageURL: url)
            store.draft = .init(length: length)
            precondition(store.start(using: []))
            var midpoint = 0, completion = 0
            for count in 1...length {
                precondition(store.advance(using: [])); precondition(store.session?.count == count)
                let milestone = store.consumeMilestone()
                if milestone == .midpoint { midpoint += 1; precondition(count == (length + 1) / 2) }
                if milestone == .completion { completion += 1; precondition(count == length) }
                precondition(store.consumeMilestone() == nil, "Never repeat haptics")
                if count == length / 3 {
                    store.togglePrayer()
                    store = PrayerRopeStore(storageURL: url)
                    precondition(store.session?.count == count && store.session?.draft.showsPrayer == false && store.session?.focused == true)
                }
            }
            precondition(midpoint == 1 && completion == 1 && !store.advance(using: []))
            store.restart(using: []); precondition(store.session?.count == 0 && store.session?.focused == false)
            store.finish(); precondition(PrayerRopeStore(storageURL: url).session == nil)
        }
        let store = PrayerRopeStore(storageURL: url)
        store.draft = .init(intention: .living, selectedIDs: [man.id]); precondition(store.start(using: [man]))
        precondition(store.advance(using: [man]))
        var renamed = man; renamed.name = "Different name"
        precondition(!store.advance(using: [renamed]) && store.session?.count == 1 && store.session?.prayer.contains("Γεώργιο") == true)
        precondition(!store.advance(using: []), "Deleted names pause, preserving progress")
        let roundTrip = try decoder.decode(DiptychaEntry.self, from: encoder.encode(man))
        precondition(roundTrip.id == id && roundTrip.note == "existing note" && roundTrip.prayerGrammar == man.prayerGrammar)
        print("Automatic Greek forms, explicit gender for ambiguous names, legacy revisions, five complete cycles through 500, milestones, persistence, restart and stale-name protection passed.")
    }
}
