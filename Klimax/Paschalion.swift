//
//  Paschalion.swift  ·  Klimax — ὁ Πασχάλιος κύκλος (the moveable-feasts engine)
//  ───────────────────────────────────────────────────────────────────────────
//  ΒΗΜΑ 1 τοῦ ἑορτολογίου.
//
//  Οἱ κινητὲς ἑορτὲς (Τριώδιο + Πεντηκοστάριο) ΔΕΝ κάθονται σὲ σταθερὴ
//  ἡμερομηνία — μετακινοῦνται κάθε χρόνο μαζὶ μὲ τὸ Πάσχα. Αὐτὸ τὸ ἀρχεῖο
//  εἶναι καθαρὴ λογική (χωρὶς δεδομένα, χωρὶς δίκτυο):
//
//     • ὑπολογίζει τὸ ὀρθόδοξο Πάσχα κάθε χρονιᾶς  (Meeus/Julian computus),
//     • ὁρίζει ὅλο τὸν κύκλο ὡς «pday» — ἀκέραιη ἀπόσταση σὲ μέρες ἀπὸ τὸ
//       Πάσχα (Πάσχα = 0, Βαΐων = −7, Πεντηκοστὴ = +49),
//     • καὶ γιὰ ΟΠΟΙΑΔΗΠΟΤΕ ἡμερομηνία λέει ἂν πέφτει κινητὴ μνήμη.
//
//  Ὁ ἀλγόριθμος ἐλέγχθηκε ἀπέναντι στὰ πραγματικὰ Πάσχα 2023–2028 (ὅλα σωστά).
//
//  Ἡμερολόγιο: ΝΕΟ (πολιτικὸ Γρηγοριανό), ὅπως Ἐκκλησία Ἑλλάδος/Κύπρου.
//  Γιὰ Παλαιοημερολογῖτες, −13 ἡμέρες — δὲν ἀφορᾶ αὐτὸν τὸν ὑπολογισμό, ποὺ
//  ἤδη ἐπιστρέφει τὴν πολιτικὴ (Γρηγοριανὴ) ἡμερομηνία τοῦ Πάσχα.
//

import Foundation

// ===========================================================================
// MARK: - Μοντέλα
// ===========================================================================

/// Ἡ βαρύτητα μιᾶς ἑορτῆς — καθορίζει τί προβάλλεται πρῶτο ὅταν συμπέσουν.
enum FeastRank: Int, Comparable, Codable {
    case great = 3    // Δεσποτικὲς / μεγάλες (Πάσχα, Βαΐων, Ἀνάληψις, Πεντηκοστή)
    case major = 2    // σημαντικὲς Κυριακὲς & ἡμέρες
    case minor = 1
    static func < (l: FeastRank, r: FeastRank) -> Bool { l.rawValue < r.rawValue }
}

/// Μία κινητὴ μνήμη: τίτλος + ἀπόσταση σὲ μέρες ἀπὸ τὸ Πάσχα (pday).
struct MovableFeast: Identifiable, Hashable {
    let id: String
    let titleGreek: String
    let subtitle: String?      // π.χ. «Δ´ Κυριακὴ τῶν Νηστειῶν»
    let pday: Int              // Πάσχα = 0
    let rank: FeastRank
}

// ===========================================================================
// MARK: - Ὁ κύκλος (Τριώδιο → Πάσχα → Πεντηκοστάριο)
// ===========================================================================

extension MovableFeast {
    /// Ὅλος ὁ κινητὸς κύκλος, ταξινομημένος κατὰ pday.
    static let cycle: [MovableFeast] = [
        // ── Τριώδιο ──────────────────────────────────────────────────────
        .init(id: "telonou_farisaiou", titleGreek: "Κυριακὴ Τελώνου καὶ Φαρισαίου", subtitle: "Ἀρχὴ Τριωδίου", pday: -70, rank: .major),
        .init(id: "asotou",            titleGreek: "Κυριακὴ τοῦ Ἀσώτου",             subtitle: nil,          pday: -63, rank: .major),
        .init(id: "psychosabbato_a",   titleGreek: "Ψυχοσάββατο",                    subtitle: "Σάββατο πρὸ τῆς Ἀπόκρεω", pday: -57, rank: .minor),
        .init(id: "apokreo",           titleGreek: "Κυριακὴ τῆς Ἀπόκρεω",            subtitle: "τῆς Κρίσεως", pday: -56, rank: .major),
        .init(id: "tyrinis",           titleGreek: "Κυριακὴ τῆς Τυρινῆς",            subtitle: "τῆς Συγχωρήσεως", pday: -49, rank: .major),
        .init(id: "kathara_deftera",   titleGreek: "Καθαρὰ Δευτέρα",                 subtitle: "Ἀρχὴ Μεγ. Τεσσαρακοστῆς", pday: -48, rank: .major),
        .init(id: "orthodoxias",       titleGreek: "Κυριακὴ τῆς Ὀρθοδοξίας",         subtitle: "Α´ τῶν Νηστειῶν", pday: -42, rank: .major),
        .init(id: "palama",            titleGreek: "Γρηγορίου τοῦ Παλαμᾶ",           subtitle: "Β´ τῶν Νηστειῶν", pday: -35, rank: .major),
        .init(id: "stavroproskynisis", titleGreek: "τῆς Σταυροπροσκυνήσεως",         subtitle: "Γ´ τῶν Νηστειῶν", pday: -28, rank: .major),
        .init(id: "klimakos",          titleGreek: "Ἰωάννου τῆς Κλίμακος",           subtitle: "Δ´ τῶν Νηστειῶν", pday: -21, rank: .major),
        .init(id: "aigyptias",         titleGreek: "Μαρίας τῆς Αἰγυπτίας",           subtitle: "Ε´ τῶν Νηστειῶν", pday: -14, rank: .major),
        .init(id: "lazarou",           titleGreek: "Σάββατο τοῦ Λαζάρου",            subtitle: nil,          pday: -8,  rank: .major),
        .init(id: "vaion",             titleGreek: "Κυριακὴ τῶν Βαΐων",              subtitle: nil,          pday: -7,  rank: .great),
        // ── Μεγάλη Ἑβδομάδα ──────────────────────────────────────────────
        .init(id: "megali_deftera",    titleGreek: "Μεγάλη Δευτέρα",                 subtitle: nil,          pday: -6,  rank: .major),
        .init(id: "megali_triti",      titleGreek: "Μεγάλη Τρίτη",                   subtitle: nil,          pday: -5,  rank: .major),
        .init(id: "megali_tetarti",    titleGreek: "Μεγάλη Τετάρτη",                 subtitle: nil,          pday: -4,  rank: .major),
        .init(id: "megali_pempti",     titleGreek: "Μεγάλη Πέμπτη",                  subtitle: "ὁ Μυστικὸς Δεῖπνος", pday: -3, rank: .great),
        .init(id: "megali_paraskevi",  titleGreek: "Μεγάλη Παρασκευή",               subtitle: "τὰ Ἅγια Πάθη", pday: -2, rank: .great),
        .init(id: "megalo_savvato",    titleGreek: "Μέγα Σάββατο",                   subtitle: nil,          pday: -1,  rank: .great),
        // ── Πάσχα & Πεντηκοστάριο ────────────────────────────────────────
        .init(id: "pascha",            titleGreek: "ΑΓΙΟΝ ΠΑΣΧΑ",                     subtitle: "ἡ Ἀνάστασις τοῦ Κυρίου", pday: 0, rank: .great),
        .init(id: "thoma",             titleGreek: "Κυριακὴ τοῦ Θωμᾶ",               subtitle: "τοῦ Ἀντίπασχα", pday: 7, rank: .major),
        .init(id: "myroforon",         titleGreek: "Κυριακὴ τῶν Μυροφόρων",          subtitle: nil,          pday: 14,  rank: .major),
        .init(id: "paralytou",         titleGreek: "Κυριακὴ τοῦ Παραλύτου",          subtitle: nil,          pday: 21,  rank: .major),
        .init(id: "mesopentikostis",   titleGreek: "τῆς Μεσοπεντηκοστῆς",            subtitle: nil,          pday: 24,  rank: .major),
        .init(id: "samareitidos",      titleGreek: "Κυριακὴ τῆς Σαμαρείτιδος",       subtitle: nil,          pday: 28,  rank: .major),
        .init(id: "tyflou",            titleGreek: "Κυριακὴ τοῦ Τυφλοῦ",             subtitle: nil,          pday: 35,  rank: .major),
        .init(id: "analipsis",         titleGreek: "ἡ Ἀνάληψις τοῦ Κυρίου",          subtitle: nil,          pday: 39,  rank: .great),
        .init(id: "pateron_a",         titleGreek: "τῶν Ἁγίων 318 Πατέρων",          subtitle: "Α´ Οἰκ. Συνόδου", pday: 42, rank: .major),
        .init(id: "pentikostis",       titleGreek: "ἡ Πεντηκοστή",                   subtitle: nil,          pday: 49,  rank: .great),
        .init(id: "agiou_pnevmatos",   titleGreek: "τοῦ Ἁγίου Πνεύματος",            subtitle: "Δευτέρα τοῦ Πνεύματος", pday: 50, rank: .major),
        .init(id: "agion_panton",      titleGreek: "Κυριακὴ τῶν Ἁγίων Πάντων",       subtitle: nil,          pday: 56,  rank: .major),
    ]
}

// ===========================================================================
// MARK: - Ὁ ὑπολογιστής
// ===========================================================================

enum Paschalion {

    /// Σταθερὸ ἡμερολόγιο σὲ UTC — ὥστε οἱ ἡμερομηνίες νὰ μὴν «γλιστροῦν»
    /// μὲ τὶς ζῶνες ὥρας. Ἡ σύγκριση γίνεται πάντα σὲ ἐπίπεδο ἡμέρας.
    static let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    /// Πόσες ἡμέρες προστίθενται σὲ Ἰουλιανὴ ἡμερομηνία γιὰ νὰ γίνει Γρηγοριανή.
    /// (1900–2099 → 13. Ὁ γενικὸς τύπος τὸ κρατᾶ σωστὸ καὶ πέρα ἀπὸ τὸ 2100.)
    static func julianToGregorianOffset(year: Int) -> Int {
        year / 100 - year / 400 - 2
    }

    /// Τὸ ὀρθόδοξο Πάσχα τῆς χρονιᾶς, στὴν πολιτικὴ (Γρηγοριανὴ) ἡμερομηνία.
    static func pascha(year: Int) -> Date {
        let a = year % 4
        let b = year % 7
        let c = year % 19
        let d = (19 * c + 15) % 30
        let e = (2 * a + 4 * b - d + 34) % 7
        let julianMonth = (d + e + 114) / 31      // 3 = Μάρτιος, 4 = Ἀπρίλιος
        let julianDay   = (d + e + 114) % 31 + 1

        var comps = DateComponents()
        comps.year = year; comps.month = julianMonth; comps.day = julianDay
        let julianDate = cal.date(from: comps)!
        return cal.date(byAdding: .day, value: julianToGregorianOffset(year: year), to: julianDate)!
    }

    /// Ἡ ἡμερομηνία μιᾶς κινητῆς μνήμης γιὰ δεδομένη χρονιά.
    static func date(of feast: MovableFeast, year: Int) -> Date {
        cal.date(byAdding: .day, value: feast.pday, to: pascha(year: year))!
    }

    /// Ὅλες οἱ κινητὲς μνῆμες ποὺ πέφτουν σὲ μιὰ συγκεκριμένη ἡμερομηνία
    /// (κανονικὰ 0 ἢ 1· ἐπιστρέφεται λίστα γιὰ ἀσφάλεια). Ταξινομημένες κατὰ βαρύτητα.
    static func commemorations(on day: Date) -> [MovableFeast] {
        let y = cal.component(.year, from: day)
        // Ὁ κύκλος μιᾶς ἡμερομηνίας μπορεῖ ν᾿ ἀνήκει στὸ Πάσχα τοῦ ἴδιου ἢ
        // τοῦ ἑπόμενου ἔτους (Τριώδιο ξεκινᾶ ~70 μέρες πρὶν)· ἐλέγχουμε καὶ τὰ δύο.
        let target = cal.startOfDay(for: day)
        var hits: [MovableFeast] = []
        for yr in [y, y + 1] {
            let p = pascha(year: yr)
            for f in MovableFeast.cycle {
                let fd = cal.startOfDay(for: cal.date(byAdding: .day, value: f.pday, to: p)!)
                if fd == target { hits.append(f) }
            }
        }
        return hits.sorted { $0.rank > $1.rank }
    }

    /// Βοηθητικό: ὅλος ὁ κύκλος μιᾶς χρονιᾶς ὡς (ἡμερομηνία, μνήμη), ταξινομημένος.
    static func fullCycle(year: Int) -> [(date: Date, feast: MovableFeast)] {
        MovableFeast.cycle
            .map { (date(of: $0, year: year), $0) }
            .sorted { $0.0 < $1.0 }
    }
}

// ===========================================================================
// MARK: - Preview γιὰ ἔλεγχο (canvas)
// ===========================================================================
//  Δὲν ἀλλάζει τίποτα στὴν ἐφαρμογή — εἶναι μόνο γιὰ νὰ δεῖς μὲ τὰ μάτια σου
//  ὅτι ὁ κύκλος βγαίνει σωστά. Ἄνοιξε τὸ Canvas (⌥⌘↩) σ᾿ αὐτὸ τὸ ἀρχεῖο.

#if DEBUG
import SwiftUI

struct PaschalionDebugView: View {
    let year = Calendar.current.component(.year, from: Date())
    var body: some View {
        let fmt: DateFormatter = {
            let f = DateFormatter()
            f.locale = Locale(identifier: "el_GR")
            f.dateFormat = "EEE d MMM"
            f.timeZone = TimeZone(identifier: "UTC")
            return f
        }()
        return List {
            Section("Πάσχα \(year): \(fmt.string(from: Paschalion.pascha(year: year)))") {
                ForEach(Paschalion.fullCycle(year: year), id: \.feast.id) { item in
                    HStack {
                        Text(fmt.string(from: item.date)).monospacedDigit()
                            .foregroundStyle(.secondary).frame(width: 110, alignment: .leading)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(item.feast.titleGreek)
                            if let s = item.feast.subtitle {
                                Text(s).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        if item.feast.rank == .great {
                            Image(systemName: "flame.fill").foregroundStyle(.orange)
                        }
                    }
                }
            }
        }
    }
}

#Preview { PaschalionDebugView() }
#endif
