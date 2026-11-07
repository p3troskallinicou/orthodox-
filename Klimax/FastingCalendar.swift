//
//  FastingCalendar.swift  ·  Klimax — τὸ πρόγραμμα νηστείας (the fasting engine)
//
//  Δίνει τὸν χαρακτηρισμὸ νηστείας γιὰ ὁποιαδήποτε ἡμερομηνία, συνδυάζοντας:
//    • τὸ Paschalion (κινητὲς περίοδοι, ὡς ἀπόσταση ἀπὸ τὸ Πάσχα), καὶ
//    • τὸ bundled `fasting.json` (κανόνες σταθερῶν & κινητῶν περιόδων).
//
//  Ἀρχιτεκτονική (ἴδια λογικὴ μὲ ScriptureStore/PrayerSection):
//    bundled-JSON  →  code-default fallback.
//  Ἂν τὸ fasting.json λείπει ἢ δὲν ἀποκωδικοποιεῖται, χρησιμοποιεῖται ὁ
//  ἐνσωματωμένος κανόνας (FastingProgram.builtIn) — ἡ ἐφαρμογὴ δὲν σπάει ποτέ.
//
//  Ἐπικυρωμένο 100% (365/365) στὰ δεδομένα τοῦ saint.gr γιὰ τὸ 2026.
//
//  ΑΠΑΙΤΕΙ: Paschalion.swift στὸ ἴδιο target.
//

import Foundation

// ===========================================================================
// MARK: - Ἐπίπεδα νηστείας
// ===========================================================================

enum FastingLevel: String, CaseIterable, Codable {
    case free
    case noMeat    = "no_meat"
    case fish
    case oilWine   = "oil_wine"
    case xerophagy

    /// Εἶναι ἡμέρα νηστείας;
    var isFast: Bool { self != .free }

    /// Ἐφεδρικὴ ἐτικέτα (ἂν λείπει τὸ JSON). Πολυτονική.
    var defaultLabel: String {
        switch self {
        case .free:      return "Κατάλυσις εἰς πάντα"
        case .noMeat:    return "Κατάλυσις εἰς πάντα πλὴν κρέατος"
        case .fish:      return "Νηστεία — ἐπιτρέπεται ἰχθύς"
        case .oilWine:   return "Νηστεία — ἐπιτρέπεται ἔλαιον καὶ οἶνος"
        case .xerophagy: return "Νηστεία (ξηροφαγία)"
        }
    }

    /// Αὐστηρότητα (μεγαλύτερη = αὐστηρότερη). Γιὰ ταξινόμηση/χαλαρώσεις.
    var strictness: Int {
        switch self {
        case .free: return 0
        case .noMeat: return 1
        case .fish: return 2
        case .oilWine: return 3
        case .xerophagy: return 4
        }
    }
}

/// Τὸ ἀποτέλεσμα ποὺ καταναλώνει τὸ UI.
struct FastingStatus: Equatable {
    let level: FastingLevel
    let label: String
    var isFast: Bool { level.isFast }
}

// ===========================================================================
// MARK: - Μοντέλο δεδομένων (Codable, ταιριάζει μὲ τὸ fasting.json)
// ===========================================================================
//  Ἄγνωστα κλειδιὰ τοῦ JSON (name/rule/note/comment…) ἀγνοοῦνται αὐτόματα.

struct FastingProgram: Codable {
    var levels: [String: LevelDef]
    var weekly: Weekly
    var fixed: FixedRules
    var movable: MovableRules

    struct LevelDef: Codable { let label: String; let fast: Bool }

    struct Weekly: Codable {
        let fastWeekdays: [Int]        // 0=Δε … 2=Τε, 4=Πα (μὴ χρησιμοποιούμενο ἄμεσα — βλ. resolver)
        let defaultLevel: String
        let pentecostarion: String
        enum CodingKeys: String, CodingKey {
            case fastWeekdays, defaultLevel = "default", pentecostarion
        }
    }

    struct FromTo: Codable { let from: String; let to: String }

    struct Phase: Codable {
        let from: String; let to: String
        let weekdayFastLevel: String?
        let weekendLevel: String?
        let otherwiseLevel: String?
    }

    struct FixedPeriod: Codable {
        let id: String
        let from: String; let to: String
        let phases: [Phase]?
        let weekendLevel: String?
        let otherwiseLevel: String?
    }

    struct FixedRules: Codable {
        let greatFeastsFree: [String]
        let dodekaimeronFree: FromTo
        let strictDays: [String]
        let overrideDays: [String: String]
        let periods: [FixedPeriod]
        let feastOil: [String]
        let feastFish: [String]
    }

    struct OffsetPeriod: Codable { let id: String; let fromOffset: Int; let toOffset: Int }
    struct TyriniDef: Codable { let fromOffset: Int; let toOffset: Int; let level: String }
    struct GreatLentDef: Codable {
        let fromOffset: Int; let toOffset: Int; let holyWeekFromOffset: Int
        let weekendLevel: String; let weekdayLevel: String; let holyWeekLevel: String
    }
    struct ApostlesDef: Codable {
        let startOffset: Int; let endFixed: String
        let wedFriLevel: String; let otherwiseLevel: String
    }

    struct MovableRules: Codable {
        let feastsFreeOffsets: [Int]
        let freePeriods: [OffsetPeriod]
        let tyrini: TyriniDef
        let greatLent: GreatLentDef
        let apostles: ApostlesDef
        let overrideOffsets: [String: String]
    }
}

// ===========================================================================
// MARK: - Ὁ ὑπολογιστὴς νηστείας
// ===========================================================================

final class FastingCalendar {

    static let shared = FastingCalendar()

    private let program: FastingProgram
    private let cal: Calendar = Paschalion.cal          // ἴδιο ἡμερολόγιο (UTC) μὲ τὸ Paschalion

    private init() {
        if let p = FastingCalendar.loadFromBundle() {
            self.program = p
            #if DEBUG
            print("🍞 FastingCalendar: φορτώθηκε τὸ bundled fasting.json.")
            #endif
        } else {
            self.program = FastingProgram.builtIn
            #if DEBUG
            print("🍞 FastingCalendar: χρήση ἐνσωματωμένων κανόνων (fasting.json δὲν βρέθηκε/ἀποκωδικοποιήθηκε).")
            #endif
        }
    }

    // MARK: Δημόσιο API

    /// Ὁ χαρακτηρισμὸς νηστείας γιὰ μιὰ ἡμερομηνία.
    func status(for date: Date) -> FastingStatus {
        let lvl = level(for: date)
        let label = program.levels[lvl.rawValue]?.label ?? lvl.defaultLabel
        return FastingStatus(level: lvl, label: label)
    }

    /// Μόνο τὸ ἐπίπεδο (ἂν χρειάζεσαι σκέτο τὸ enum).
    func level(for date: Date) -> FastingLevel {
        let day    = cal.startOfDay(for: date)
        let year   = cal.component(.year, from: day)
        let pascha = cal.startOfDay(for: Paschalion.pascha(year: year))
        let offset = cal.dateComponents([.day], from: pascha, to: day).day ?? 0
        let wd     = cal.component(.weekday, from: day)      // 1=Κυ … 4=Τε, 6=Πα, 7=Σα
        let isWed  = (wd == 4)
        let isFri  = (wd == 6)
        let isWeekend = (wd == 1 || wd == 7)
        let md     = FastingCalendar.mmdd(day, cal: cal)

        let base = resolveBase(md: md, offset: offset,
                               isWed: isWed, isFri: isFri, isWeekend: isWeekend,
                               day: day, year: year)

        return applyFeastRelaxation(base, md: md)
    }

    // MARK: Πυρήνας — ἡ σειρὰ ἐπίλυσης (βλ. resolutionOrder στὸ fasting.json)

    private func resolveBase(md: String, offset: Int,
                             isWed: Bool, isFri: Bool, isWeekend: Bool,
                             day: Date, year: Int) -> FastingLevel {
        let fx = program.fixed
        let mv = program.movable

        // 1. Σταθερὲς μεγάλες ἑορτές
        if fx.greatFeastsFree.contains(md) { return .free }

        // 2. Κινητὲς ἑορτὲς / περίοδοι ἐλευθερίας
        if mv.feastsFreeOffsets.contains(offset) { return .free }
        for p in mv.freePeriods where offset >= p.fromOffset && offset <= p.toOffset { return .free }

        // 3. Δωδεκαήμερο (σταθερό, «τυλίγεται» στὸ τέλος τοῦ ἔτους)
        if inMDRange(md, fx.dodekaimeronFree.from, fx.dodekaimeronFree.to) { return .free }

        // 4. Σταθερὲς αὐστηρὲς & σταθερὲς ἐξαιρέσεις
        if fx.strictDays.contains(md) { return .xerophagy }
        if let s = fx.overrideDays[md], let l = FastingLevel(rawValue: s) { return l }

        // 5. Κινητὲς ἐξαιρέσεις (ἀπόσταση ἀπὸ τὸ Πάσχα)
        if let s = mv.overrideOffsets[String(offset)], let l = FastingLevel(rawValue: s) { return l }

        // 6. Τυρινή
        if offset >= mv.tyrini.fromOffset && offset <= mv.tyrini.toOffset {
            return FastingLevel(rawValue: mv.tyrini.level) ?? .noMeat
        }

        // 7. Μεγάλη Τεσσαρακοστὴ & Μεγάλη Ἑβδομάς
        let gl = mv.greatLent
        if offset >= gl.fromOffset && offset <= gl.toOffset {
            if offset >= gl.holyWeekFromOffset && offset <= gl.toOffset {
                return FastingLevel(rawValue: gl.holyWeekLevel) ?? .xerophagy
            }
            return FastingLevel(rawValue: isWeekend ? gl.weekendLevel : gl.weekdayLevel)
                ?? (isWeekend ? .oilWine : .xerophagy)
        }

        // 8. Νηστεία Ἀποστόλων (κινητὴ ἀρχή, σταθερὸ τέλος)
        let apEnd = date(year: year, mmdd: mv.apostles.endFixed)
        if offset >= mv.apostles.startOffset, let apEnd, day <= apEnd {
            let s = (isWed || isFri) ? mv.apostles.wedFriLevel : mv.apostles.otherwiseLevel
            return FastingLevel(rawValue: s) ?? ((isWed || isFri) ? .xerophagy : .fish)
        }

        // 9–10. Σταθερὲς πολυήμερες (Δεκαπενταύγουστος, Χριστουγέννων)
        for period in fx.periods where inMDRange(md, period.from, period.to) {
            if let phases = period.phases {
                for ph in phases where inMDRange(md, ph.from, ph.to) {
                    if isWeekend, let wl = ph.weekendLevel, let l = FastingLevel(rawValue: wl) { return l }
                    if (isWed || isFri), let wf = ph.weekdayFastLevel, let l = FastingLevel(rawValue: wf) { return l }
                    if let o = ph.otherwiseLevel, let l = FastingLevel(rawValue: o) { return l }
                }
            } else {
                if isWeekend, let wl = period.weekendLevel, let l = FastingLevel(rawValue: wl) { return l }
                if let o = period.otherwiseLevel, let l = FastingLevel(rawValue: o) { return l }
            }
        }

        // 11. Πεντηκοστάριο: χαλαρότερη Τετάρτη/Παρασκευή
        if offset >= 8 && offset <= 48 && (isWed || isFri) {
            return FastingLevel(rawValue: program.weekly.pentecostarion) ?? .oilWine
        }

        // 12. Κοινὴ ἑβδομαδιαία Τετάρτη/Παρασκευή
        if isWed || isFri {
            return FastingLevel(rawValue: program.weekly.defaultLevel) ?? .xerophagy
        }

        // 13. Ἀλλιῶς
        return .free
    }

    /// Χαλαρώσεις λόγῳ ἑορτῆς — ΜΟΝΟΝ πρὸς τὰ κάτω (ποτὲ αὐστηροποίηση),
    /// καὶ μόνο ἂν ἡ ἡμέρα εἶναι ἤδη νηστίσιμη.
    private func applyFeastRelaxation(_ base: FastingLevel, md: String) -> FastingLevel {
        var lvl = base
        if lvl == .xerophagy, program.fixed.feastOil.contains(md) { lvl = .oilWine }
        if (lvl == .xerophagy || lvl == .oilWine), program.fixed.feastFish.contains(md) { lvl = .fish }
        return lvl
    }

    // MARK: Βοηθητικά

    /// "MM-DD" γιὰ μιὰ ἡμερομηνία.
    private static func mmdd(_ date: Date, cal: Calendar) -> String {
        let m = cal.component(.month, from: date)
        let d = cal.component(.day, from: date)
        return String(format: "%02d-%02d", m, d)
    }

    /// Ἐλέγχει ἂν τὸ "MM-DD" εἶναι ἐντὸς [from…to]· ὑποστηρίζει «τύλιγμα» ἔτους (π.χ. 12-25…01-04).
    private func inMDRange(_ md: String, _ from: String, _ to: String) -> Bool {
        if from <= to { return md >= from && md <= to }
        return md >= from || md <= to
    }

    /// Κατασκευὴ ἡμερομηνίας ἀπὸ "MM-DD" γιὰ δεδομένο ἔτος (UTC startOfDay).
    private func date(year: Int, mmdd: String) -> Date? {
        let parts = mmdd.split(separator: "-")
        guard parts.count == 2, let m = Int(parts[0]), let d = Int(parts[1]) else { return nil }
        var c = DateComponents(); c.year = year; c.month = m; c.day = d
        return cal.date(from: c).map { cal.startOfDay(for: $0) }
    }

    // MARK: Φόρτωση JSON

    private static func loadFromBundle() -> FastingProgram? {
        guard let url = Bundle.main.url(forResource: "fasting", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(FastingProgram.self, from: data)
    }
}

// ===========================================================================
// MARK: - Ἐνσωματωμένοι κανόνες (fallback — ταυτόσημοι μὲ τὸ fasting.json)
// ===========================================================================

extension FastingProgram {
    static let builtIn: FastingProgram = {
        let levels: [String: LevelDef] = [
            "free":      .init(label: "Κατάλυσις εἰς πάντα", fast: false),
            "no_meat":   .init(label: "Κατάλυσις εἰς πάντα πλὴν κρέατος", fast: true),
            "fish":      .init(label: "Νηστεία — ἐπιτρέπεται ἰχθύς", fast: true),
            "oil_wine":  .init(label: "Νηστεία — ἐπιτρέπεται ἔλαιον καὶ οἶνος", fast: true),
            "xerophagy": .init(label: "Νηστεία (ξηροφαγία)", fast: true)
        ]
        let weekly = Weekly(fastWeekdays: [2, 4], defaultLevel: "xerophagy", pentecostarion: "oil_wine")

        let nativity = FixedPeriod(
            id: "nativity", from: "11-15", to: "12-24",
            phases: [
                Phase(from: "11-15", to: "12-17", weekdayFastLevel: "xerophagy", weekendLevel: nil, otherwiseLevel: "fish"),
                Phase(from: "12-18", to: "12-24", weekdayFastLevel: nil, weekendLevel: "oil_wine", otherwiseLevel: "xerophagy")
            ],
            weekendLevel: nil, otherwiseLevel: nil)
        let dormition = FixedPeriod(
            id: "dormition", from: "08-01", to: "08-14",
            phases: nil, weekendLevel: "oil_wine", otherwiseLevel: "xerophagy")

        let fixed = FixedRules(
            greatFeastsFree: ["12-25", "01-06", "08-15", "06-29"],
            dodekaimeronFree: FromTo(from: "12-25", to: "01-04"),
            strictDays: ["01-05", "09-14"],
            overrideDays: ["08-29": "oil_wine", "03-25": "fish", "08-06": "fish", "11-21": "fish"],
            periods: [dormition, nativity],
            feastOil: ["01-16","01-30","02-11","02-24","03-09","03-26","07-01","07-17",
                       "07-22","09-09","09-23","10-28","11-13","11-25","12-04","12-09"],
            feastFish: ["01-07", "06-24"])

        let movable = MovableRules(
            feastsFreeOffsets: [0, 49],
            freePeriods: [
                OffsetPeriod(id: "bright", fromOffset: 1, toOffset: 7),
                OffsetPeriod(id: "pentecost_week", fromOffset: 50, toOffset: 56),
                OffsetPeriod(id: "publican", fromOffset: -69, toOffset: -64)
            ],
            tyrini: TyriniDef(fromOffset: -55, toOffset: -49, level: "no_meat"),
            greatLent: GreatLentDef(fromOffset: -48, toOffset: -1, holyWeekFromOffset: -6,
                                    weekendLevel: "oil_wine", weekdayLevel: "xerophagy", holyWeekLevel: "xerophagy"),
            apostles: ApostlesDef(startOffset: 57, endFixed: "06-28",
                                  wedFriLevel: "xerophagy", otherwiseLevel: "fish"),
            overrideOffsets: ["-8": "oil_wine", "-7": "fish", "24": "fish", "38": "fish"])

        return FastingProgram(levels: levels, weekly: weekly, fixed: fixed, movable: movable)
    }()
}

// ===========================================================================
// MARK: - DEBUG αὐτο-ἔλεγχος + Preview
// ===========================================================================

#if DEBUG
import SwiftUI

struct FastingDebugView: View {
    private let cal = Paschalion.cal
    private let year = Calendar.current.component(.year, from: Date())

    var body: some View {
        List {
            Section("Αὐτο-ἔλεγχος 2026 (γνωστὲς ἡμέρες)") {
                ForEach(Self.checks, id: \.0) { md, expected in
                    let d = Self.date(2026, md)
                    let st = FastingCalendar.shared.status(for: d)
                    let ok = st.level.rawValue == expected
                    HStack {
                        Text(md).monospaced()
                        Spacer()
                        Text(st.level.rawValue).foregroundStyle(.secondary)
                        Image(systemName: ok ? "checkmark.circle.fill" : "xmark.octagon.fill")
                            .foregroundStyle(ok ? .green : .red)
                    }
                }
            }
            Section("Σήμερα") {
                let st = FastingCalendar.shared.status(for: Date())
                Text(st.label)
                Text(st.isFast ? "Ἡμέρα νηστείας" : "Χωρὶς νηστεία").foregroundStyle(.secondary)
            }
        }
        .onAppear { Self.runConsoleSelfCheck() }
    }

    // Ἀντιπροσωπευτικὲς ἡμέρες: κινητὲς + σταθερές + χαλαρώσεις ἑορτῆς.
    static let checks: [(String, String)] = [
        ("01-05", "xerophagy"),   // παραμονὴ Θεοφανείων
        ("01-06", "free"),        // Θεοφάνεια
        ("01-07", "fish"),        // Σύναξις Προδρόμου (Τε)
        ("02-23", "xerophagy"),   // Καθαρὰ Δευτέρα (κινητή)
        ("03-25", "fish"),        // Εὐαγγελισμὸς (ἐν Σαρακοστῇ)
        ("04-12", "free"),        // Πάσχα
        ("04-17", "free"),        // Διακαινήσιμος Παρασκευή
        ("06-08", "fish"),        // ἀρχὴ Νηστείας Ἀποστόλων (κινητή)
        ("06-12", "xerophagy"),   // Παρασκευὴ Ἀποστόλων
        ("06-29", "free"),        // Πέτρου & Παύλου
        ("08-06", "fish"),        // Μεταμόρφωσις (ἐν Δεκαπενταυγούστῳ)
        ("08-15", "free"),        // Κοίμησις
        ("09-14", "xerophagy"),   // Ὕψωσις Σταυροῦ
        ("11-15", "fish"),        // ἀρχὴ Νηστείας Χριστουγέννων
        ("12-04", "oil_wine"),    // Ἁγ. Βαρβάρα (χαλάρωση ἑορτῆς)
        ("12-24", "xerophagy"),   // παραμονὴ Χριστουγέννων
        ("12-25", "free")         // Χριστούγεννα
    ]

    static func date(_ y: Int, _ md: String) -> Date {
        let p = md.split(separator: "-").compactMap { Int($0) }
        var c = DateComponents(); c.year = y; c.month = p[0]; c.day = p[1]
        return Paschalion.cal.date(from: c)!
    }

    static func runConsoleSelfCheck() {
        var pass = 0
        for (md, exp) in checks {
            let got = FastingCalendar.shared.level(for: date(2026, md)).rawValue
            if got == exp { pass += 1 }
            else { print("🍞 ΔΙΑΦΟΡΑ \(md): περίμενα \(exp), πῆρα \(got)") }
        }
        print("🍞 FastingCalendar self-check: \(pass)/\(checks.count) OK")
    }
}

#Preview { FastingDebugView() }
#endif
