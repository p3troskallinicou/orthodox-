//
//  ProgressionStore.swift
//  Klimax
//

import Foundation
import SwiftUI

struct ProgressionTier: Identifiable, Hashable {
    let id: Int
    let name: String
    let threshold: Int

    var style: ProgressionTierStyle {
        ProgressionTierStyle.style(for: id)
    }

    var assetName: String {
        "rank_badge_\(name.lowercased())"
    }
}

struct ProgressionTierStyle {
    let base: Color
    let dark: Color
    let light: Color
    let ring: Color

    var readable: Color {
        Color.adaptive(dark, light)
    }

    var readableAccent: Color {
        Color.adaptive(base, ring)
    }

    var readableSoft: Color {
        Color.adaptive(dark.opacity(0.72), light.opacity(0.84))
    }

    static func style(for id: Int) -> ProgressionTierStyle {
        switch id {
        case 1:
            ProgressionTierStyle(base: Color(red: 0.64, green: 0.37, blue: 0.18),
                                 dark: Color(red: 0.32, green: 0.18, blue: 0.08),
                                 light: Color(red: 0.88, green: 0.57, blue: 0.32),
                                 ring: Color(red: 0.95, green: 0.70, blue: 0.44))
        case 2:
            ProgressionTierStyle(base: Color(red: 0.47, green: 0.50, blue: 0.52),
                                 dark: Color(red: 0.22, green: 0.24, blue: 0.26),
                                 light: Color(red: 0.74, green: 0.77, blue: 0.80),
                                 ring: Color(red: 0.86, green: 0.88, blue: 0.90))
        case 3:
            ProgressionTierStyle(base: Color(red: 0.73, green: 0.76, blue: 0.79),
                                 dark: Color(red: 0.36, green: 0.39, blue: 0.43),
                                 light: Color(red: 0.96, green: 0.97, blue: 0.98),
                                 ring: Color(red: 0.92, green: 0.94, blue: 0.96))
        case 4:
            ProgressionTierStyle(base: Gild.gold,
                                 dark: Gild.goldRing,
                                 light: Gild.goldBright,
                                 ring: Color(red: 1.00, green: 0.88, blue: 0.42))
        case 5:
            ProgressionTierStyle(base: Color(red: 0.13, green: 0.62, blue: 0.39),
                                 dark: Color(red: 0.04, green: 0.28, blue: 0.18),
                                 light: Color(red: 0.34, green: 0.92, blue: 0.64),
                                 ring: Color(red: 0.56, green: 1.00, blue: 0.76))
        case 6:
            ProgressionTierStyle(base: Color(red: 0.13, green: 0.42, blue: 0.82),
                                 dark: Color(red: 0.04, green: 0.14, blue: 0.38),
                                 light: Color(red: 0.39, green: 0.70, blue: 1.00),
                                 ring: Color(red: 0.56, green: 0.82, blue: 1.00))
        case 7:
            ProgressionTierStyle(base: Color(red: 0.52, green: 0.28, blue: 0.80),
                                 dark: Color(red: 0.22, green: 0.08, blue: 0.38),
                                 light: Color(red: 0.78, green: 0.52, blue: 1.00),
                                 ring: Color(red: 0.88, green: 0.70, blue: 1.00))
        case 8:
            ProgressionTierStyle(base: Color(red: 0.72, green: 0.10, blue: 0.20),
                                 dark: Color(red: 0.34, green: 0.04, blue: 0.09),
                                 light: Color(red: 1.00, green: 0.30, blue: 0.42),
                                 ring: Color(red: 1.00, green: 0.58, blue: 0.64))
        case 9:
            ProgressionTierStyle(base: Color(red: 0.68, green: 0.72, blue: 0.78),
                                 dark: Color(red: 0.32, green: 0.36, blue: 0.44),
                                 light: Color(red: 0.93, green: 0.96, blue: 1.00),
                                 ring: Color(red: 0.82, green: 0.90, blue: 1.00))
        case 10:
            ProgressionTierStyle(base: Color(red: 0.64, green: 0.90, blue: 0.96),
                                 dark: Color(red: 0.20, green: 0.42, blue: 0.50),
                                 light: Color(red: 0.92, green: 1.00, blue: 1.00),
                                 ring: Color(red: 0.84, green: 0.98, blue: 1.00))
        case 11:
            ProgressionTierStyle(base: Color(red: 0.86, green: 0.56, blue: 0.98),
                                 dark: Color(red: 0.32, green: 0.14, blue: 0.50),
                                 light: Color(red: 1.00, green: 0.78, blue: 1.00),
                                 ring: Color(red: 1.00, green: 0.86, blue: 1.00))
        default:
            ProgressionTierStyle(base: Color(red: 0.96, green: 0.86, blue: 0.58),
                                 dark: Color(red: 0.42, green: 0.30, blue: 0.10),
                                 light: Color(red: 1.00, green: 0.97, blue: 0.78),
                                 ring: Color(red: 1.00, green: 0.91, blue: 0.48))
        }
    }
}

enum ProgressionCapScope: String, Codable {
    case day
    case week
    case once
}

struct XPEvent: Identifiable, Hashable {
    let id: String
    let title: String
    let value: Int
    let cap: Int
    let scope: ProgressionCapScope
    let icon: String
    let subtitle: String
    let milestoneKey: String?

    init(
        id: String,
        title: String,
        value: Int,
        cap: Int,
        scope: ProgressionCapScope,
        icon: String,
        subtitle: String,
        milestoneKey: String? = nil
    ) {
        self.id = id
        self.title = title
        self.value = value
        self.cap = cap
        self.scope = scope
        self.icon = icon
        self.subtitle = subtitle
        self.milestoneKey = milestoneKey
    }
}

enum ProgressionSacrament: String, Codable, CaseIterable, Identifiable {
    case communion
    case confession

    var id: String { rawValue }

    var title: String {
        switch self {
        case .communion: "Θεία Κοινωνία"
        case .confession: "Εξομολόγηση"
        }
    }
}

private struct ProgressionSave: Codable {
    var totalXP: Int
    var logs: [ProgressionLogEntry]

    static func seeded(from existingXP: Int) -> ProgressionSave {
        ProgressionSave(totalXP: max(0, existingXP), logs: [])
    }
}

struct ProgressionLogEntry: Identifiable, Codable, Hashable {
    let id: UUID
    let eventID: String
    let scopeKey: String
    let title: String
    let date: Date
    let xpAwarded: Int
    let isSacrament: Bool

    init(eventID: String, scopeKey: String, title: String, date: Date, xpAwarded: Int, isSacrament: Bool = false) {
        self.id = UUID()
        self.eventID = eventID
        self.scopeKey = scopeKey
        self.title = title
        self.date = date
        self.xpAwarded = xpAwarded
        self.isSacrament = isSacrament
    }
}

@MainActor
final class ProgressionStore: ObservableObject {
    static let shared = ProgressionStore()

    static let tiers: [ProgressionTier] = [
        ProgressionTier(id: 1, name: "Bronze", threshold: 0),
        ProgressionTier(id: 2, name: "Iron", threshold: 300),
        ProgressionTier(id: 3, name: "Silver", threshold: 1200),
        ProgressionTier(id: 4, name: "Gold", threshold: 3000),
        ProgressionTier(id: 5, name: "Emerald", threshold: 7000),
        ProgressionTier(id: 6, name: "Sapphire", threshold: 15000),
        ProgressionTier(id: 7, name: "Amethyst", threshold: 30000),
        ProgressionTier(id: 8, name: "Ruby", threshold: 55000),
        ProgressionTier(id: 9, name: "Platinum", threshold: 100000),
        ProgressionTier(id: 10, name: "Diamond", threshold: 180000),
        ProgressionTier(id: 11, name: "Celestial", threshold: 350000),
        ProgressionTier(id: 12, name: "Ascendant", threshold: 700000)
    ]

    static let dailyEvents: [XPEvent] = [
        XPEvent(id: "divine_liturgy", title: "Θεία Λειτουργία", value: 300, cap: 1, scope: .day, icon: "building.columns.fill", subtitle: "Όριο μία φορά την ημέρα"),
        XPEvent(id: "church_service", title: "Εσπερινός, Όρθρος, ακολουθία σε ναό", value: 100, cap: 1, scope: .day, icon: "bell.fill", subtitle: "Η παρουσία σε ναό μετρά μία φορά"),
        XPEvent(id: "mercy_work", title: "Έργο ελέους", value: 50, cap: 1, scope: .day, icon: "hands.sparkles.fill", subtitle: "Όριο μία φορά την ημέρα"),
        XPEvent(id: "fast_day", title: "Ημέρα νηστείας", value: 40, cap: 1, scope: .day, icon: "leaf.fill", subtitle: "Όριο μία φορά την ημέρα"),
        XPEvent(id: "home_service", title: "Ακολουθία στο σπίτι", value: 40, cap: 1, scope: .day, icon: "house.fill", subtitle: "Μόνο για ιδιωτική προσευχή"),
        XPEvent(id: "morning_rule", title: "Πρωινός κανόνας προσευχής", value: 35, cap: 1, scope: .day, icon: "sunrise.fill", subtitle: "Όριο μία φορά την ημέρα"),
        XPEvent(id: "evening_rule", title: "Βραδινός κανόνας προσευχής", value: 35, cap: 1, scope: .day, icon: "moon.stars.fill", subtitle: "Όριο μία φορά την ημέρα"),
        XPEvent(id: "scripture_daily", title: "Ημερήσια περικοπή Γραφής", value: 20, cap: 1, scope: .day, icon: "book.closed.fill", subtitle: "Όριο μία φορά την ημέρα"),
        XPEvent(id: "lesson_klimax", title: "Μάθημα Βιβλικής Πορείας", value: 20, cap: 2, scope: .day, icon: "map.fill", subtitle: "Όριο δύο φορές την ημέρα"),
        XPEvent(id: "gerontikon_saying", title: "Ρήση Γεροντικού", value: 10, cap: 2, scope: .day, icon: "quote.bubble.fill", subtitle: "Όριο δύο φορές την ημέρα"),
        XPEvent(id: "review_sm2", title: "Συνεδρία επαναλήψεως", value: 10, cap: 1, scope: .day, icon: "arrow.triangle.2.circlepath", subtitle: "Όριο μία φορά την ημέρα"),
        XPEvent(id: "game_activity", title: "Δραστηριότητα παιχνιδιού", value: 5, cap: 2, scope: .day, icon: "sparkles", subtitle: "Όριο δύο φορές την ημέρα")
    ].sorted { $0.value > $1.value }

    static let milestoneEvents: [XPEvent] = [
        XPEvent(id: "section_complete", title: "Ολοκλήρωση Ενότητος", value: 75, cap: 1, scope: .once, icon: "checkmark.seal.fill", subtitle: "Μία φορά για κάθε Ενότητα", milestoneKey: "section"),
        XPEvent(id: "rung_complete", title: "Ολοκλήρωση σκαλιού", value: 250, cap: 1, scope: .once, icon: "flag.checkered", subtitle: "Μία φορά για κάθε σκαλί", milestoneKey: "rung")
    ].sorted { $0.value > $1.value }

    @Published private(set) var totalXP: Int
    @Published private var logs: [ProgressionLogEntry]

    private let defaults: UserDefaults
    private let storageKey = "klimax.progression.v1"
    private let calendar = Calendar(identifier: .gregorian)

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: storageKey),
           let save = try? JSONDecoder().decode(ProgressionSave.self, from: data) {
            let actualXP = PlayerProgressStore.shared.totalXP
            let wasEmeraldMock = save.totalXP == 8200 && save.logs.isEmpty && actualXP < 7000
            totalXP = wasEmeraldMock ? actualXP : save.totalXP
            logs = save.logs
            if wasEmeraldMock {
                self.save()
            }
        } else {
            let seed = ProgressionSave.seeded(from: PlayerProgressStore.shared.totalXP)
            totalXP = seed.totalXP
            logs = seed.logs
            if let data = try? JSONEncoder().encode(seed) {
                defaults.set(data, forKey: storageKey)
            }
        }
    }

    var currentTier: ProgressionTier {
        Self.tiers.last(where: { totalXP >= $0.threshold }) ?? Self.tiers[0]
    }

    var nextTier: ProgressionTier? {
        Self.tiers.first(where: { $0.threshold > totalXP })
    }

    var xpIntoTier: Int {
        totalXP - currentTier.threshold
    }

    var xpToNextTier: Int {
        guard let nextTier else { return 0 }
        return max(0, nextTier.threshold - totalXP)
    }

    var currentBathmos: Int {
        Self.level(forXP: totalXP)
    }

    var xpToNextBathmos: Int {
        guard currentBathmos < 100 else { return 0 }
        return max(0, Self.cumulativeXPForLevel(currentBathmos + 1) - totalXP)
    }

    var progressToNextBathmos: Double {
        guard currentBathmos < 100 else { return 1 }
        let start = Self.cumulativeXPForLevel(currentBathmos)
        let end = Self.cumulativeXPForLevel(currentBathmos + 1)
        return Double(totalXP - start) / Double(max(1, end - start))
    }

    var progressToNextTier: Double {
        guard let nextTier else { return 1 }
        let span = max(1, nextTier.threshold - currentTier.threshold)
        return Double(totalXP - currentTier.threshold) / Double(span)
    }

    @discardableResult
    func award(_ event: XPEvent, date: Date = Date()) -> Int {
        let key = scopeKey(for: event, date: date)
        logs.append(ProgressionLogEntry(eventID: event.id, scopeKey: key, title: event.title, date: date, xpAwarded: 0))
        save()
        #if DEBUG
        print("[ProgressionStore] recorded \(event.id) without XP")
        #endif
        return 0
    }

    func syncWithPlayerXP(_: Int) {
        // Legacy no-op. The journey surface no longer syncs lesson activity into XP.
    }

    func record(_ sacrament: ProgressionSacrament, date: Date = Date()) {
        logs.append(
            ProgressionLogEntry(
                eventID: sacrament.id,
                scopeKey: dayKey(for: date),
                title: sacrament.title,
                date: date,
                xpAwarded: 0,
                isSacrament: true
            )
        )
        save()
        #if DEBUG
        print("[ProgressionStore] sacrament \(sacrament.id) total \(totalXP)")
        #endif
    }

    func recentLogs(limit: Int = 30) -> [ProgressionLogEntry] {
        Array(logs.sorted { $0.date > $1.date }.prefix(limit))
    }

    private func save() {
        let save = ProgressionSave(totalXP: totalXP, logs: logs)
        guard let data = try? JSONEncoder().encode(save) else { return }
        defaults.set(data, forKey: storageKey)
    }

    private func scopeKey(for event: XPEvent, date: Date) -> String {
        switch event.scope {
        case .day:
            return dayKey(for: date)
        case .week:
            return weekKey(for: date)
        case .once:
            return "\(event.id)_\(event.milestoneKey ?? "single")"
        }
    }

    private func dayKey(for date: Date) -> String {
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        return "\(comps.year ?? 0)\(String(format: "%02d", comps.month ?? 0))\(String(format: "%02d", comps.day ?? 0))"
    }

    private func weekKey(for date: Date) -> String {
        let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return "\(comps.yearForWeekOfYear ?? 0)W\(String(format: "%02d", comps.weekOfYear ?? 0))"
    }

    static func cumulativeXPForLevel(_ level: Int) -> Int {
        Int(38.5 * pow(Double(max(1, level)), 2.13))
    }

    static func level(forXP xp: Int) -> Int {
        min(100, max(1, Int(floor(pow(Double(max(0, xp)) / 38.5, 1.0 / 2.13)))))
    }
}

private func progressionNumber(_ value: Int) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.groupingSeparator = ","
    formatter.locale = Locale(identifier: "en_US_POSIX")
    return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
}

private struct ProgressionSaying {
    let text: String
    let attribution: String
}

private func saying(for tier: ProgressionTier) -> ProgressionSaying {
    switch tier.id {
    case 5:
        return ProgressionSaying(
            text: "Ὕπαγε, κάθου εἰς τὸ κελλίον σου, καὶ τὸ κελλίον σου διδάξει σε τὰ πάντα.",
            attribution: "Ἀββᾶς Μωυσῆς"
        )
    default:
        // TODO: assign verified Gerontikon sayings for every tier when the local dataset is added.
        return ProgressionSaying(
            text: "Πρόσεχε σεαυτῷ.",
            attribution: "Γεροντικόν"
        )
    }
}

enum StreakKind: String, CaseIterable, Codable, Identifiable {
    case prayer
    case church
    case games
    case stories
    case scripture
    case didaches

    var id: String { rawValue }

    var title: String {
        switch self {
        case .prayer: "Prayer"
        case .church: "Church"
        case .games: "Bible Path"
        case .stories: "Stories"
        case .scripture: "Scripture"
        case .didaches: "Didaches"
        }
    }

    var subtitle: String {
        switch self {
        case .prayer: "Morning or evening prayer"
        case .church: "Service or liturgy"
        case .games: "Lesson or practice"
        case .stories: "Gerontikon reading"
        case .scripture: "Daily Scripture"
        case .didaches: "Homily listening"
        }
    }

    var icon: String {
        switch self {
        case .prayer: "hands.sparkles.fill"
        case .church: "building.columns.fill"
        case .games: "figure.stairs"
        case .stories: "text.quote"
        case .scripture: "book.closed.fill"
        case .didaches: "waveform"
        }
    }

    var tint: Color {
        switch self {
        case .prayer: Color(red: 0.55, green: 0.63, blue: 1.00)
        case .church: Color(red: 0.95, green: 0.70, blue: 0.28)
        case .games: Color(red: 0.28, green: 0.78, blue: 0.50)
        case .stories: Color(red: 0.82, green: 0.55, blue: 0.26)
        case .scripture: Color(red: 0.32, green: 0.68, blue: 0.92)
        case .didaches: Color(red: 0.78, green: 0.50, blue: 1.00)
        }
    }
}

struct StreakRecord: Codable, Hashable {
    var current: Int = 0
    var best: Int = 0
    var lastDayStamp: Int?
    var activeDays: Set<Int> = []
    // Per day stamp progress. activeDays stays the single source of truth for
    // completed days (target met). These hold the partial progress for today.
    var dailyItems: [Int: Set<String>] = [:]   // distinct item ids counted (count metric)
    var dailySeconds: [Int: Double] = [:]      // accumulated listened seconds (minutes metric)
    var plannerCompletedDays: Set<Int> = []    // explicit completions from the Today planner

    init(current: Int = 0,
         best: Int = 0,
         lastDayStamp: Int? = nil,
         activeDays: Set<Int> = [],
         dailyItems: [Int: Set<String>] = [:],
         dailySeconds: [Int: Double] = [:],
         plannerCompletedDays: Set<Int> = []) {
        self.current = current
        self.best = best
        self.lastDayStamp = lastDayStamp
        self.activeDays = activeDays
        self.dailyItems = dailyItems
        self.dailySeconds = dailySeconds
        self.plannerCompletedDays = plannerCompletedDays
    }
}

extension StreakRecord {
    enum CodingKeys: String, CodingKey {
        case current, best, lastDayStamp, activeDays, dailyItems, dailySeconds, plannerCompletedDays
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        current = (try? c.decode(Int.self, forKey: .current)) ?? 0
        best = (try? c.decode(Int.self, forKey: .best)) ?? 0
        lastDayStamp = (try? c.decodeIfPresent(Int.self, forKey: .lastDayStamp)) ?? nil
        activeDays = (try? c.decode(Set<Int>.self, forKey: .activeDays)) ?? []
        dailyItems = (try? c.decode([Int: Set<String>].self, forKey: .dailyItems)) ?? [:]
        dailySeconds = (try? c.decode([Int: Double].self, forKey: .dailySeconds)) ?? [:]
        plannerCompletedDays = (try? c.decode(Set<Int>.self, forKey: .plannerCompletedDays)) ?? []
    }
}

enum GoalMetric: String, CaseIterable, Codable, Hashable, Identifiable {
    case count      // distinct completed items per day
    case minutes    // accumulated listening minutes per day

    var id: String { rawValue }
}

enum GoalCadenceType: String, CaseIterable, Codable, Identifiable {
    case daily
    case weekly
    case weekdays

    var id: String { rawValue }

    var title: String {
        switch self {
        case .daily: "Every day"
        case .weekly: "Once a week"
        case .weekdays: "Specific days"
        }
    }
}

struct GoalCadence: Codable, Hashable {
    var type: GoalCadenceType
    var weekdays: Set<Int>

    static let daily = GoalCadence(type: .daily, weekdays: [])
    static let weekly = GoalCadence(type: .weekly, weekdays: [])

    var title: String {
        switch type {
        case .daily:
            return "Every day"
        case .weekly:
            return "Once a week"
        case .weekdays:
            let names = Self.weekdaySymbols
            let selected = weekdays.sorted().compactMap { names[$0] }
            return selected.isEmpty ? "Specific days" : selected.joined(separator: ", ")
        }
    }

    func isScheduled(on date: Date) -> Bool {
        switch type {
        case .daily, .weekly:
            return true
        case .weekdays:
            let weekday = Calendar.current.component(.weekday, from: date)
            return weekdays.contains(weekday)
        }
    }

    static let weekdayOptions: [(value: Int, label: String)] = [
        (2, "Mon"), (3, "Tue"), (4, "Wed"), (5, "Thu"), (6, "Fri"), (7, "Sat"), (1, "Sun")
    ]

    private static let weekdaySymbols: [Int: String] = [
        1: "Sun", 2: "Mon", 3: "Tue", 4: "Wed", 5: "Thu", 6: "Fri", 7: "Sat"
    ]
}

enum GoalSource: String, CaseIterable, Codable, Identifiable {
    case manual
    case prayer
    case church
    case games
    case stories
    case scripture
    case didaches

    var id: String { rawValue }

    var title: String {
        switch self {
        case .manual: "Manual check-in"
        case .prayer: "Prayer button"
        case .church: "Church/service"
        case .games: "Bible Path lessons"
        case .stories: "Gerontikon stories"
        case .scripture: "Scripture reading"
        case .didaches: "Didaches listening"
        }
    }

    var subtitle: String {
        switch self {
        case .manual: "You decide when it counts"
        case .prayer: "Completes when you mark prayer"
        case .church: "For church goals you track"
        case .games: "Completes after lesson practice"
        case .stories: "Completes when stories open"
        case .scripture: "Completes when a chapter opens"
        case .didaches: "Completes when a homily plays"
        }
    }

    var icon: String {
        switch self {
        case .manual: "checkmark.seal.fill"
        case .prayer: "hands.sparkles.fill"
        case .church: "building.columns.fill"
        case .games: "figure.stairs"
        case .stories: "text.quote"
        case .scripture: "book.closed.fill"
        case .didaches: "waveform"
        }
    }

    var appKind: StreakKind? {
        switch self {
        case .manual: nil
        case .prayer: .prayer
        case .church: .church
        case .games: .games
        case .stories: .stories
        case .scripture: .scripture
        case .didaches: .didaches
        }
    }

    init(kind: StreakKind) {
        switch kind {
        case .prayer: self = .prayer
        case .church: self = .church
        case .games: self = .games
        case .stories: self = .stories
        case .scripture: self = .scripture
        case .didaches: self = .didaches
        }
    }

    // Sources with no in app action of their own: they advance by tapping the card.
    var isManualEntry: Bool { self == .manual || self == .church }

    // Sources where a minutes based listening target makes sense.
    var supportsMinutes: Bool { self == .didaches }
}

private enum GoalPalette {
    static let colors: [Color] = [
        Color(red: 1.00, green: 0.42, blue: 0.25),
        Color(red: 0.28, green: 0.78, blue: 0.50),
        Color(red: 0.32, green: 0.68, blue: 0.92),
        Color(red: 0.78, green: 0.50, blue: 1.00),
        Color(red: 0.95, green: 0.70, blue: 0.28),
        Color(red: 0.55, green: 0.63, blue: 1.00)
    ]

    static func color(_ index: Int) -> Color {
        colors[max(0, min(index, colors.count - 1))]
    }
}

struct StreakGoal: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var title: String
    var subtitle: String
    var icon: String
    var tintIndex: Int
    var cadence: GoalCadence
    var source: GoalSource
    var record: StreakRecord = StreakRecord()
    var targetPerDay: Int = 1
    var metric: GoalMetric = .count
    var allowedItemIDs: Set<String> = []   // empty means any item of the source counts

    var tint: Color { GoalPalette.color(tintIndex) }
    var unitLabel: String { cadence.type == .weekly ? "week" : "day" }
}

extension StreakGoal {
    enum CodingKeys: String, CodingKey {
        case id, title, subtitle, icon, tintIndex, cadence, source, record
        case targetPerDay, metric, allowedItemIDs
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(UUID.self, forKey: .id)) ?? UUID()
        title = (try? c.decode(String.self, forKey: .title)) ?? ""
        subtitle = (try? c.decode(String.self, forKey: .subtitle)) ?? ""
        icon = (try? c.decode(String.self, forKey: .icon)) ?? "checkmark.seal.fill"
        tintIndex = (try? c.decode(Int.self, forKey: .tintIndex)) ?? 0
        cadence = (try? c.decode(GoalCadence.self, forKey: .cadence)) ?? .daily
        source = (try? c.decode(GoalSource.self, forKey: .source)) ?? .manual
        record = (try? c.decode(StreakRecord.self, forKey: .record)) ?? StreakRecord()
        targetPerDay = max(1, (try? c.decode(Int.self, forKey: .targetPerDay)) ?? 1)
        metric = (try? c.decode(GoalMetric.self, forKey: .metric)) ?? .count
        allowedItemIDs = (try? c.decode(Set<String>.self, forKey: .allowedItemIDs)) ?? []
    }
}

private struct StreakSave: Codable {
    var goals: [StreakGoal]
    var freezesEquipped: Int

    static let empty = StreakSave(
        goals: [],
        freezesEquipped: 2
    )
}

private struct LegacyStreakSave: Codable {
    var records: [StreakKind: StreakRecord]
    var freezesEquipped: Int
}

@MainActor
final class StreakStore: ObservableObject {
    static let shared = StreakStore()

    @Published private var save: StreakSave

    private let defaults: UserDefaults
    private let storageKey = "klimax.streaks.v1"
    private var lastListeningPersist = Date.distantPast

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode(StreakSave.self, from: data) {
            save = decoded
        } else if let data = defaults.data(forKey: storageKey),
                  let legacy = try? JSONDecoder().decode(LegacyStreakSave.self, from: data) {
            save = Self.migrate(legacy)
            persist()
        } else {
            save = .empty
        }
    }

    var goals: [StreakGoal] { save.goals }

    var freezesEquipped: Int {
        min(2, max(0, save.freezesEquipped))
    }

    var globalCurrentStreak: Int {
        consecutiveDaysEndingNow(from: allActiveDays)
    }

    var globalBestStreak: Int {
        max(save.goals.map { $0.record.best }.max() ?? 0, globalCurrentStreak)
    }

    var completedToday: Bool {
        let today = Self.dayStamp(Date())
        return allActiveDays.contains(today)
    }

    var completedGoalsToday: Int {
        save.goals.filter { isDoneToday($0) }.count
    }

    // Today progress toward the goal target. For count metric this is the number
    // of distinct items done today; for minutes it is whole minutes accumulated.
    func progressToday(_ goal: StreakGoal, date: Date = Date()) -> Int {
        let stamp = Self.dayStamp(date)
        if goal.record.plannerCompletedDays.contains(stamp) {
            return targetToday(goal)
        }
        switch goal.metric {
        case .count:
            return goal.record.dailyItems[stamp]?.count ?? 0
        case .minutes:
            return Int((goal.record.dailySeconds[stamp] ?? 0) / 60.0)
        }
    }

    func targetToday(_ goal: StreakGoal) -> Int {
        max(1, goal.targetPerDay)
    }

    func isDoneToday(_ goal: StreakGoal) -> Bool {
        isDone(goal, on: Date())
    }

    func isDone(_ goal: StreakGoal, on date: Date) -> Bool {
        goal.record.activeDays.contains(Self.dayStamp(date))
    }

    func goalStatuses(on date: Date) -> [(goal: StreakGoal, isDone: Bool)] {
        save.goals.map { ($0, isDone($0, on: date)) }
    }

    func didAnyActivity(on date: Date) -> Bool {
        let stamp = Self.dayStamp(date)
        return allActiveDays.contains(stamp)
    }

    func weekStatus(for goalID: UUID? = nil, date: Date = Date()) -> [(date: Date, isActive: Bool, isToday: Bool)] {
        let calendar = Calendar.current
        let start = calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? calendar.startOfDay(for: date)
        let days = goalID.flatMap { id in save.goals.first(where: { $0.id == id })?.record.activeDays } ?? allActiveDays
        let actualToday = Self.dayStamp(Date())
        return (0..<7).map { offset in
            let day = calendar.date(byAdding: .day, value: offset, to: start) ?? date
            let stamp = Self.dayStamp(day)
            return (day, days.contains(stamp), stamp == actualToday)
        }
    }

    // A genuine completion of an in app action. Advances every count goal whose
    // source matches, respecting each goal's allowed item filter, counting the
    // item only once per day. Called on real completion, never on open.
    func record(_ kind: StreakKind, itemID: String, date: Date = Date()) {
        let today = Self.dayStamp(date)
        let source = GoalSource(kind: kind)
        var changed = false
        for index in save.goals.indices {
            let goal = save.goals[index]
            guard goal.source == source, goal.metric == .count else { continue }
            if !goal.allowedItemIDs.isEmpty && !goal.allowedItemIDs.contains(itemID) { continue }
            let wasDone = goal.record.activeDays.contains(today)
            var items = goal.record.dailyItems[today] ?? []
            let (inserted, _) = items.insert(itemID)
            guard inserted else { continue }
            save.goals[index].record.dailyItems[today] = items
            changed = true
            if !wasDone { finalizeIfComplete(index: index, date: date, celebrate: true) }
        }
        if changed { persist() }
    }

    // Accumulated listening time for minutes based didaches goals. Feed it small
    // positive deltas from the audio player and the AthosTV player while playing.
    func addListeningSeconds(_ delta: Double, date: Date = Date()) {
        guard delta > 0 else { return }
        let today = Self.dayStamp(date)
        var changed = false
        var finalized = false
        for index in save.goals.indices {
            let goal = save.goals[index]
            guard goal.source == .didaches, goal.metric == .minutes else { continue }
            if goal.record.activeDays.contains(today) { continue } // already met today
            save.goals[index].record.dailySeconds[today, default: 0] += delta
            changed = true
            let before = save.goals[index].record.activeDays.contains(today)
            finalizeIfComplete(index: index, date: date, celebrate: true)
            if !before && save.goals[index].record.activeDays.contains(today) { finalized = true }
        }
        if changed {
            if finalized || Date().timeIntervalSince(lastListeningPersist) > 5 {
                lastListeningPersist = Date()
                persist()
            }
        }
    }

    // Manual tap on a card. Only for sources with no in app action of their own.
    @discardableResult
    func record(goalID: UUID, date: Date = Date()) -> StreakGoal? {
        let today = Self.dayStamp(date)
        guard let index = save.goals.firstIndex(where: { $0.id == goalID }) else { return nil }
        guard save.goals[index].source.isManualEntry else { return save.goals[index] }
        if save.goals[index].record.activeDays.contains(today) { return save.goals[index] }
        var items = save.goals[index].record.dailyItems[today] ?? []
        items.insert("manual:\(today):\(items.count)")
        save.goals[index].record.dailyItems[today] = items
        finalizeIfComplete(index: index, date: date, celebrate: true)
        persist()
        return save.goals[index]
    }

    /// Keeps an explicitly linked Today item and its Goal in one reversible state.
    func setPlannerCompletion(goalID: UUID, completed: Bool, date: Date = Date()) {
        let stamp = Self.dayStamp(date)
        guard let index = save.goals.firstIndex(where: { $0.id == goalID }) else { return }
        if completed {
            save.goals[index].record.plannerCompletedDays.insert(stamp)
            // Today supplies its own green fill and success haptic, so keep this
            // interaction immediate instead of covering it with the streak sheet.
            finalizeIfComplete(index: index, date: date, celebrate: false)
        } else {
            save.goals[index].record.plannerCompletedDays.remove(stamp)
            if progressToday(save.goals[index], date: date) < targetToday(save.goals[index]) {
                save.goals[index].record.activeDays.remove(stamp)
                save.goals[index].record.current = currentStreak(for: save.goals[index], date: date)
                save.goals[index].record.lastDayStamp = save.goals[index].record.activeDays.max()
            }
        }
        persist()
    }

    // When today's progress reaches the target, mark the day complete once and
    // recompute the streak. Celebration fires only on this crossing.
    private func finalizeIfComplete(index: Int, date: Date, celebrate: Bool) {
        let today = Self.dayStamp(date)
        var goal = save.goals[index]
        guard !goal.record.activeDays.contains(today) else { return }
        guard progressToday(goal, date: date) >= targetToday(goal) else { return }
        goal.record.activeDays.insert(today)
        goal.record.current = currentStreak(for: goal, date: date)
        goal.record.best = max(goal.record.best, goal.record.current)
        goal.record.lastDayStamp = today
        save.goals[index] = goal
        if celebrate {
            StreakCelebrationCenter.shared.show(goal: goal, count: goal.record.current, started: goal.record.current == 1)
        }
    }

    @discardableResult
    func addGoal(title: String,
                 subtitle: String,
                 cadence: GoalCadence,
                 source: GoalSource,
                 icon: String,
                 tintIndex: Int,
                 targetPerDay: Int = 1,
                 metric: GoalMetric = .count,
                 allowedItemIDs: Set<String> = []) -> StreakGoal? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let goal = StreakGoal(
            title: trimmed,
            subtitle: subtitle.trimmingCharacters(in: .whitespacesAndNewlines),
            icon: icon,
            tintIndex: tintIndex,
            cadence: cadence,
            source: source,
            targetPerDay: max(1, targetPerDay),
            metric: metric,
            allowedItemIDs: allowedItemIDs
        )
        save.goals.insert(goal, at: 0)
        persist()
        return goal
    }

    func deleteGoal(_ goal: StreakGoal) {
        save.goals.removeAll { $0.id == goal.id }
        persist()
    }

    func currentStreak(for goal: StreakGoal, date: Date = Date()) -> Int {
        if goal.cadence.type == .weekly {
            return weeklyStreak(from: goal.record.activeDays, date: date)
        }
        return scheduledDayStreak(goal: goal, date: date)
    }

    private var allActiveDays: Set<Int> {
        save.goals.reduce(into: Set<Int>()) { result, goal in
            result.formUnion(goal.record.activeDays)
        }
    }

    private func consecutiveDaysEndingNow(from days: Set<Int>) -> Int {
        guard !days.isEmpty else { return 0 }
        let today = Self.dayStamp(Date())
        let start = days.contains(today) ? today : today - 1
        var count = 0
        var cursor = start
        while days.contains(cursor) {
            count += 1
            cursor -= 1
        }
        return count
    }

    private func scheduledDayStreak(goal: StreakGoal, date: Date) -> Int {
        let calendar = Calendar.current
        var cursor = calendar.startOfDay(for: date)
        let todayStamp = Self.dayStamp(cursor)
        if !goal.record.activeDays.contains(todayStamp) || !goal.cadence.isScheduled(on: cursor) {
            repeat {
                cursor = calendar.date(byAdding: .day, value: -1, to: cursor) ?? cursor
            } while !goal.cadence.isScheduled(on: cursor)
        }

        var count = 0
        var guardrail = 0
        while guardrail < 520 {
            guardrail += 1
            if goal.cadence.isScheduled(on: cursor) {
                let stamp = Self.dayStamp(cursor)
                guard goal.record.activeDays.contains(stamp) else { break }
                count += 1
            }
            repeat {
                cursor = calendar.date(byAdding: .day, value: -1, to: cursor) ?? cursor
            } while !goal.cadence.isScheduled(on: cursor) && guardrail < 520
        }
        return count
    }

    private func weeklyStreak(from days: Set<Int>, date: Date) -> Int {
        guard !days.isEmpty else { return 0 }
        let calendar = Calendar.current
        let activeWeeks = Set(days.compactMap { day -> Int? in
            guard let activeDate = calendar.date(byAdding: .day, value: day, to: calendar.startOfDay(for: Date(timeIntervalSinceReferenceDate: 0))),
                  let start = calendar.dateInterval(of: .weekOfYear, for: activeDate)?.start else { return nil }
            return Self.dayStamp(start)
        })
        guard var cursor = calendar.dateInterval(of: .weekOfYear, for: date)?.start else { return 0 }
        var cursorStamp = Self.dayStamp(cursor)
        if !activeWeeks.contains(cursorStamp) {
            cursor = calendar.date(byAdding: .day, value: -7, to: cursor) ?? cursor
            cursorStamp = Self.dayStamp(cursor)
        }
        var count = 0
        while activeWeeks.contains(cursorStamp) {
            count += 1
            cursor = calendar.date(byAdding: .day, value: -7, to: cursor) ?? cursor
            cursorStamp = Self.dayStamp(cursor)
        }
        return count
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(save) else { return }
        defaults.set(data, forKey: storageKey)
    }

    static func dayStamp(_ date: Date) -> Int {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        let reference = calendar.startOfDay(for: Date(timeIntervalSinceReferenceDate: 0))
        return calendar.dateComponents([.day], from: reference, to: start).day ?? 0
    }

    private static func migrate(_ legacy: LegacyStreakSave) -> StreakSave {
        let goals = legacy.records.compactMap { kind, record -> StreakGoal? in
            guard !record.activeDays.isEmpty else { return nil }
            let source = GoalSource(kind: kind)
            let tintIndex = StreakKind.allCases.firstIndex(of: kind) ?? 0
            return StreakGoal(
                title: kind.title,
                subtitle: kind.subtitle,
                icon: kind.icon,
                tintIndex: tintIndex,
                cadence: .daily,
                source: source,
                record: record
            )
        }
        return StreakSave(goals: goals, freezesEquipped: legacy.freezesEquipped)
    }
}

struct StreakCelebration: Identifiable {
    let id = UUID()
    let goalID: UUID
    let title: String
    let icon: String
    let tintIndex: Int
    let count: Int
    let unitLabel: String
    let started: Bool

    var tint: Color { GoalPalette.color(tintIndex) }
}

@MainActor
final class StreakCelebrationCenter: ObservableObject {
    static let shared = StreakCelebrationCenter()
    @Published var celebration: StreakCelebration?

    private init() {}

    func show(goal: StreakGoal, count: Int, started: Bool) {
        celebration = StreakCelebration(
            goalID: goal.id,
            title: goal.title,
            icon: goal.icon,
            tintIndex: goal.tintIndex,
            count: count,
            unitLabel: goal.unitLabel,
            started: started
        )
    }

    func dismiss(_ id: UUID? = nil) {
        guard id == nil || celebration?.id == id else { return }
        celebration = nil
    }
}

struct StreakCelebrationView: View {
    let celebration: StreakCelebration
    let dismiss: () -> Void
    @StateObject private var store = StreakStore.shared
    @State private var lit = false
    @State private var revealCount = false

    var body: some View {
        ZStack {
            streakBackground
                .ignoresSafeArea()
            LinearGradient(
                colors: [
                    celebration.tint.opacity(0.20),
                    streakOrange.opacity(0.14),
                    .clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer(minLength: 30)

                ZStack {
                    Circle()
                        .fill(streakOrange.opacity(lit ? 0.18 : 0.04))
                        .frame(width: 230, height: 230)
                        .blur(radius: 28)
                        .scaleEffect(lit ? 1.08 : 0.72)
                    StreakFlame(size: 150, active: true)
                        .scaleEffect(lit ? 1.0 : 0.72)
                        .rotationEffect(.degrees(lit ? 0 : -5))
                }
                .animation(.spring(response: 0.58, dampingFraction: 0.62), value: lit)

                VStack(spacing: 8) {
                    Text(revealCount ? "\(celebration.count)" : "0")
                        .font(.system(size: 92, weight: .black, design: .rounded))
                        .foregroundStyle(streakNumberGradient)
                        .contentTransition(.numericText())
                    Text("\(celebration.unitLabel) streak")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(streakOrange)
                }

                VStack(spacing: 8) {
                    Label(celebration.started ? "\(celebration.title) started" : "\(celebration.title) extended", systemImage: celebration.icon)
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundStyle(celebration.tint)
                        .lineLimit(1)
                        .minimumScaleFactor(0.76)
                    Text(message)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Paper.inkSoft)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 34)
                }

                StreakWeekRail(days: store.weekStatus(for: celebration.goalID), compact: false)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 16)
                    .streakGlass(cornerRadius: 26, active: true)
                    .padding(.horizontal, 24)

                Spacer(minLength: 20)

                Button {
                    dismiss()
                } label: {
                    Text("CONTINUE")
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .tracking(1.5)
                        .foregroundStyle(Color(red: 0.07, green: 0.15, blue: 0.18))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Color(red: 0.28, green: 0.74, blue: 0.96), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .shadow(color: Color(red: 0.16, green: 0.52, blue: 0.78).opacity(0.34), radius: 0, y: 5)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)
                .padding(.bottom, 26)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: celebration.id) {
            lit = false
            revealCount = false
            try? await Task.sleep(nanoseconds: 120_000_000)
            lit = true
            try? await Task.sleep(nanoseconds: 250_000_000)
            withAnimation(.spring(response: 0.34, dampingFraction: 0.72)) {
                revealCount = true
            }
        }
        .accessibilityLabel("\(celebration.title) streak \(celebration.count)")
    }

    private var message: String {
        if celebration.started {
            return "You brought this streak to life today."
        }
        return "You kept the rhythm alive. Come back tomorrow."
    }
}

struct StreakSummaryCard: View {
    @StateObject private var store = StreakStore.shared

    var body: some View {
        NavigationLink {
            StreakDashboardView(store: store)
        } label: {
            HStack(spacing: 14) {
                StreakFlame(size: 54, active: store.completedToday)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Goals")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1.5)
                        .foregroundStyle(streakOrange)
                    HStack(alignment: .firstTextBaseline, spacing: 7) {
                        Text("\(store.globalCurrentStreak)")
                            .font(.system(size: 32, weight: .black, design: .rounded))
                            .foregroundStyle(streakNumberGradient)
                        Text("goal streak")
                            .font(.system(size: 15, weight: .heavy, design: .rounded))
                            .foregroundStyle(Paper.ink)
                    }
                    StreakWeekRail(days: store.weekStatus(), compact: true)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Paper.inkMute.opacity(0.65))
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .streakGlass(cornerRadius: 26, active: store.completedToday)
        }
        .buttonStyle(CalmCardStyle())
    }
}

struct StreakDashboardView: View {
    @ObservedObject var store: StreakStore
    @State private var showingGoalComposer = false

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 22) {
                hero
                streakCalendar
                goalList
                rewards
            }
            .padding(.horizontal, KSpace.gutter)
            .padding(.top, KSpace.lg)
            .padding(.bottom, KSpace.xxl)
        }
        .background(streakBackground.ignoresSafeArea())
        .navigationTitle("Goals")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingGoalComposer = true } label: {
                    Image(systemName: "plus").font(.system(size: 15, weight: .black))
                }
                .accessibilityLabel("Add goal")
            }
        }
        .sheet(isPresented: $showingGoalComposer) {
            GoalComposerView(store: store)
                .presentationDetents([.large])
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 18) {
            StreakFlame(size: 68, active: store.completedToday)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(store.globalCurrentStreak)")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(streakNumberGradient)
                Text("goal streak")
                    .font(.system(size: 18, weight: .semibold, design: .serif))
                    .foregroundStyle(streakOrange)
            }
            Spacer(minLength: 0)
            }

            StreakWeekRail(days: store.weekStatus(), compact: false)
                .padding(.top, 4)

            Text(store.goals.isEmpty ? "Create the goals you actually want to keep." : (store.completedToday ? "\(store.completedGoalsToday) goals completed today." : "Choose one goal and keep the rhythm."))
                .font(.system(size: 14))
                .foregroundStyle(Paper.inkSoft)
                .multilineTextAlignment(.leading)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .streakGlass(cornerRadius: 30, active: store.completedToday)
    }

    private var streakCalendar: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Goal Calendar")
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(Paper.ink)
                Spacer()
                Text("\(store.freezesEquipped)/2 freezes")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(Color(red: 0.34, green: 0.74, blue: 1.0))
            }

            StreakMonthGrid(store: store)
        }
    }

    private var goalList: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Your goals")
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(Paper.ink)
                Spacer()
                Button { showingGoalComposer = true } label: {
                    Label("Add", systemImage: "plus")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(streakOrange.opacity(0.14), in: Capsule())
                }
                .buttonStyle(.plain)
            }

            if store.goals.isEmpty {
                EmptyGoalsCard { showingGoalComposer = true }
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(store.goals) { goal in
                        GoalCard(goal: goal, store: store)
                    }
                }
            }
        }
    }

    private var rewards: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color(red: 0.38, green: 0.78, blue: 1.0))
                    .frame(width: 44, height: 44)
                    .background(Color(red: 0.38, green: 0.78, blue: 1.0).opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Flexible rhythm")
                        .font(.system(size: 19, weight: .black, design: .rounded))
                        .foregroundStyle(Paper.ink)
                    Text("Manual goals stay fully yours. App-linked goals count when you act inside orthodox+.")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Paper.inkMute)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .streakGlass(cornerRadius: 24, active: false)
    }
}

private struct EmptyGoalsCard: View {
    let add: () -> Void

    var body: some View {
        Button(action: add) {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: "target")
                    .font(.system(size: 26, weight: .black))
                    .foregroundStyle(streakOrange)
                    .frame(width: 54, height: 54)
                    .background(streakOrange.opacity(0.14), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                Text("Build your own rhythm")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(Paper.ink)
                Text("Name a goal, choose when it counts, and decide whether it is manual or connected to an action in the app.")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Paper.inkMute)
                    .lineSpacing(3)
                Label("Create goal", systemImage: "plus.circle.fill")
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(streakOrange)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .streakGlass(cornerRadius: 24, active: false)
        }
        .buttonStyle(.plain)
    }
}

private struct GoalCard: View {
    let goal: StreakGoal
    @ObservedObject var store: StreakStore

    private var done: Bool { store.isDoneToday(goal) }
    private var count: Int { store.currentStreak(for: goal) }
    private var progress: Int { store.progressToday(goal) }
    private var target: Int { store.targetToday(goal) }
    private var fraction: Double { target > 0 ? min(1, Double(progress) / Double(target)) : 0 }
    private var tappable: Bool { goal.source.isManualEntry }
    private var doneGreen: Color { Color(red: 0.32, green: 0.88, blue: 0.55) }

    private var progressText: String {
        goal.metric == .minutes ? "\(progress)/\(target) min" : "\(progress)/\(target)"
    }

    var body: some View {
        Button {
            guard tappable else { return }
            withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
                _ = store.record(goalID: goal.id)
            }
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    ZStack {
                        Circle()
                            .stroke(goal.tint.opacity(0.16), lineWidth: 3)
                            .frame(width: 46, height: 46)
                        Circle()
                            .trim(from: 0, to: fraction)
                            .stroke(done ? doneGreen : goal.tint,
                                    style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .frame(width: 46, height: 46)
                        Image(systemName: goal.icon)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(goal.tint)
                            .frame(width: 34, height: 34)
                            .background(goal.tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                    }
                    Spacer()
                    Image(systemName: done ? "checkmark.circle.fill" : (tappable ? "plus.circle.fill" : "link.circle.fill"))
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(done ? doneGreen : Paper.inkMute.opacity(0.55))
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(goal.title)
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundStyle(Paper.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)
                    Text(goal.subtitle.isEmpty ? goal.cadence.title : goal.subtitle)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Paper.inkMute)
                        .lineLimit(1)
                }

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(progressText)
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(done ? doneGreen : goal.tint)
                    Text("today")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(Paper.inkMute)
                    Spacer(minLength: 0)
                }

                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text("\(count)")
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundStyle(done ? streakNumberGradient : LinearGradient(colors: [Paper.ink, Paper.ink], startPoint: .leading, endPoint: .trailing))
                    Text("\(goal.unitLabel)s")
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(Paper.inkMute)
                }

                Text(goal.source.title)
                    .font(.system(size: 10, weight: .black))
                    .tracking(0.7)
                    .foregroundStyle(goal.tint.opacity(0.92))
                    .lineLimit(1)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 188, alignment: .leading)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Paper.card.opacity(0.76))
                    Circle()
                        .fill(goal.tint.opacity(done ? 0.16 : 0.06))
                        .frame(width: 92, height: 92)
                        .blur(radius: 9)
                        .offset(x: 56, y: 54)
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(goal.tint.opacity(done ? 0.26 : 0.10), lineWidth: 1)
            )
            .contextMenu {
                Button(role: .destructive) {
                    store.deleteGoal(goal)
                } label: {
                    Label("Delete goal", systemImage: "trash")
                }
            }
            .shadow(color: Color.adaptive(.black.opacity(0.035), .black.opacity(0.10)), radius: 8, y: 4)
        }
        .buttonStyle(CalmCardStyle())
        .accessibilityLabel("\(goal.title), \(progressText) today, \(count) \(goal.unitLabel) streak")
    }
}

private struct GoalComposerView: View {
    @ObservedObject var store: StreakStore
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var subtitle = ""
    @State private var cadenceType: GoalCadenceType = .daily
    @State private var weekdays: Set<Int> = [2, 3, 4, 5, 6, 7, 1]
    @State private var source: GoalSource = .manual
    @State private var tintIndex = 0
    @State private var targetPerDay = 1
    @State private var metric: GoalMetric = .count
    @State private var selectedPrayerIDs: Set<String> = []
    @State private var prayerStore = PrayerStore()

    private var minutesMode: Bool { source.supportsMinutes && metric == .minutes }

    private var resolvedCadence: GoalCadence {
        switch cadenceType {
        case .daily:
            return .daily
        case .weekly:
            return .weekly
        case .weekdays:
            return GoalCadence(type: .weekdays, weekdays: weekdays.isEmpty ? [Calendar.current.component(.weekday, from: Date())] : weekdays)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    preview
                    fieldGroup
                    cadenceGroup
                    sourceGroup
                    amountGroup
                    if source == .prayer {
                        prayerPickerGroup
                    }
                    colorGroup
                }
                .padding(.horizontal, KSpace.gutter)
                .padding(.top, KSpace.lg)
                .padding(.bottom, KSpace.xxl)
            }
            .background(streakBackground.ignoresSafeArea())
            .navigationTitle("New goal")
            .navigationBarTitleDisplayMode(.inline)
            .task { await prayerStore.load() }
            .onChange(of: source) { _, newValue in
                if !newValue.supportsMinutes { metric = .count }
                if newValue != .prayer { selectedPrayerIDs = [] }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") {
                        store.addGoal(
                            title: title,
                            subtitle: subtitle,
                            cadence: resolvedCadence,
                            source: source,
                            icon: source.icon,
                            tintIndex: tintIndex,
                            targetPerDay: targetPerDay,
                            metric: metric,
                            allowedItemIDs: source == .prayer ? selectedPrayerIDs : []
                        )
                        dismiss()
                    }
                    .fontWeight(.black)
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private var preview: some View {
        HStack(spacing: 14) {
            Image(systemName: source.icon)
                .font(.system(size: 24, weight: .black))
                .foregroundStyle(GoalPalette.color(tintIndex))
                .frame(width: 58, height: 58)
                .background(GoalPalette.color(tintIndex).opacity(0.14), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            VStack(alignment: .leading, spacing: 5) {
                Text(title.isEmpty ? "Your goal" : title)
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(Paper.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.76)
                Text("\(resolvedCadence.title) · \(source.title)")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(Paper.inkMute)
            }
            Spacer()
        }
        .padding(18)
        .streakGlass(cornerRadius: 26, active: false)
    }

    private var fieldGroup: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Name")
                .font(.system(size: 11, weight: .black))
                .tracking(1.5)
                .foregroundStyle(streakOrange)
            TextField("e.g. Read three stories", text: $title)
                .font(.system(size: 17, weight: .semibold))
                .textInputAutocapitalization(.sentences)
                .padding(14)
                .background(Paper.card.opacity(0.72), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            TextField("Optional note", text: $subtitle)
                .font(.system(size: 15, weight: .semibold))
                .textInputAutocapitalization(.sentences)
                .padding(14)
                .background(Paper.card.opacity(0.72), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private var cadenceGroup: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tracking rhythm")
                .font(.system(size: 11, weight: .black))
                .tracking(1.5)
                .foregroundStyle(streakOrange)
            Picker("Rhythm", selection: $cadenceType) {
                ForEach(GoalCadenceType.allCases) { cadence in
                    Text(cadence.title).tag(cadence)
                }
            }
            .pickerStyle(.segmented)

            if cadenceType == .weekdays {
                HStack(spacing: 7) {
                    ForEach(GoalCadence.weekdayOptions, id: \.value) { day in
                        Button {
                            if weekdays.contains(day.value) {
                                weekdays.remove(day.value)
                            } else {
                                weekdays.insert(day.value)
                            }
                        } label: {
                            Text(String(day.label.prefix(1)))
                                .font(.system(size: 12, weight: .black, design: .rounded))
                                .foregroundStyle(weekdays.contains(day.value) ? Color(red: 0.10, green: 0.11, blue: 0.13) : Paper.inkMute)
                                .frame(width: 34, height: 34)
                                .background(weekdays.contains(day.value) ? AnyShapeStyle(streakNumberGradient) : AnyShapeStyle(Paper.ink.opacity(0.08)), in: Circle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(16)
        .streakGlass(cornerRadius: 22, active: false)
    }

    private var sourceGroup: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How it counts")
                .font(.system(size: 11, weight: .black))
                .tracking(1.5)
                .foregroundStyle(streakOrange)
            VStack(spacing: 8) {
                ForEach(GoalSource.allCases) { item in
                    Button {
                        source = item
                    } label: {
                        HStack(spacing: 11) {
                            Image(systemName: item.icon)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(item == source ? GoalPalette.color(tintIndex) : Paper.inkMute)
                                .frame(width: 32, height: 32)
                                .background((item == source ? GoalPalette.color(tintIndex) : Paper.inkMute).opacity(0.10), in: Circle())
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title)
                                    .font(.system(size: 14, weight: .black, design: .rounded))
                                    .foregroundStyle(Paper.ink)
                                Text(item.subtitle)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(Paper.inkMute)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Image(systemName: item == source ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(item == source ? Color(red: 0.32, green: 0.88, blue: 0.55) : Paper.inkMute.opacity(0.38))
                        }
                        .padding(10)
                        .background(Paper.ink.opacity(item == source ? 0.055 : 0.025), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .streakGlass(cornerRadius: 22, active: false)
    }

    private var countLabel: String {
        let n = targetPerDay
        if source.supportsMinutes {
            return n == 1 ? "1 homily per day" : "\(n) homilies per day"
        }
        return n == 1 ? "1 time per day" : "\(n) times per day"
    }

    private var amountHint: String {
        if minutesMode { return "Counts your listening across homilies and AthosTV." }
        switch source {
        case .prayer: return selectedPrayerIDs.isEmpty ? "Any prayer you mark counts toward this." : "Only the prayers you pick below count."
        case .scripture: return "Distinct chapters you actually read."
        case .stories: return "Distinct stories you actually read."
        case .didaches: return "Distinct homilies you finish."
        case .games: return "Distinct lessons you complete."
        default: return "Each check in advances the day."
        }
    }

    private var amountGroup: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How much per day")
                .font(.system(size: 11, weight: .black))
                .tracking(1.5)
                .foregroundStyle(streakOrange)

            if source.supportsMinutes {
                Picker("Measure", selection: $metric) {
                    Text("Homilies").tag(GoalMetric.count)
                    Text("Minutes").tag(GoalMetric.minutes)
                }
                .pickerStyle(.segmented)
                .onChange(of: metric) { _, newValue in
                    if newValue == .minutes {
                        targetPerDay = max(5, (targetPerDay / 5) * 5)
                    } else {
                        targetPerDay = min(20, max(1, targetPerDay))
                    }
                }
            }

            if minutesMode {
                Stepper(value: $targetPerDay, in: 5...120, step: 5) {
                    Text("\(targetPerDay) minutes per day")
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(Paper.ink)
                }
            } else {
                Stepper(value: $targetPerDay, in: 1...20) {
                    Text(countLabel)
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(Paper.ink)
                }
            }

            Text(amountHint)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Paper.inkMute)
        }
        .padding(16)
        .streakGlass(cornerRadius: 22, active: false)
    }

    private func togglePrayer(_ id: String) {
        if selectedPrayerIDs.contains(id) {
            selectedPrayerIDs.remove(id)
        } else {
            selectedPrayerIDs.insert(id)
        }
        targetPerDay = selectedPrayerIDs.isEmpty ? 1 : min(20, max(1, selectedPrayerIDs.count))
    }

    private var prayerPickerGroup: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Specific prayers (optional)")
                .font(.system(size: 11, weight: .black))
                .tracking(1.5)
                .foregroundStyle(streakOrange)

            Text(selectedPrayerIDs.isEmpty
                 ? "Leave empty to count any prayer, or pick the exact prayers this goal needs."
                 : "\(selectedPrayerIDs.count) selected. The daily target follows your selection.")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Paper.inkMute)

            if prayerStore.categories.isEmpty {
                Text("Loading prayers...")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Paper.inkMute)
            } else {
                ForEach(prayerStore.categories) { category in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(category.titleEnglish ?? category.titleGreek)
                            .font(.system(size: 13, weight: .black, design: .rounded))
                            .foregroundStyle(Paper.ink)
                            .padding(.top, 6)
                        ForEach(category.prayers) { prayer in
                            Button {
                                togglePrayer(prayer.id)
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: selectedPrayerIDs.contains(prayer.id) ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundStyle(selectedPrayerIDs.contains(prayer.id) ? Color(red: 0.32, green: 0.88, blue: 0.55) : Paper.inkMute.opacity(0.4))
                                    Text(prayer.titleEnglish ?? prayer.titleGreek)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(Paper.ink)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                    Spacer(minLength: 0)
                                }
                                .padding(.vertical, 5)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(16)
        .streakGlass(cornerRadius: 22, active: false)
    }

    private var colorGroup: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Color")
                .font(.system(size: 11, weight: .black))
                .tracking(1.5)
                .foregroundStyle(streakOrange)
            HStack(spacing: 12) {
                ForEach(Array(GoalPalette.colors.enumerated()), id: \.offset) { index, color in
                    Button {
                        tintIndex = index
                    } label: {
                        Circle()
                            .fill(color)
                            .frame(width: 34, height: 34)
                            .overlay(
                                Circle()
                                    .stroke(tintIndex == index ? Paper.ink : .white.opacity(0.56), lineWidth: tintIndex == index ? 3 : 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .streakGlass(cornerRadius: 22, active: false)
    }
}

private struct StreakMonthGrid: View {
    @ObservedObject var store: StreakStore
    @State private var selectedDate = Date()

    private var monthDays: [Date] {
        let calendar = Calendar.current
        let now = Date()
        guard let interval = calendar.dateInterval(of: .month, for: now),
              let range = calendar.range(of: .day, in: .month, for: now) else { return [] }
        return range.compactMap { day in
            calendar.date(byAdding: .day, value: day - 1, to: interval.start)
        }
    }

    private var selectedStatuses: [(goal: StreakGoal, isDone: Bool)] {
        store.goalStatuses(on: selectedDate)
    }

    private var selectedDoneCount: Int {
        selectedStatuses.filter { $0.isDone }.count
    }

    private func doneCount(on date: Date) -> Int {
        store.goalStatuses(on: date).filter { $0.isDone }.count
    }

    var body: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)
        VStack(spacing: 12) {
            HStack {
                Text(Date().formatted(.dateTime.month(.wide).year()))
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(Paper.ink)
                Spacer()
                Image(systemName: "flame.fill")
                    .foregroundStyle(streakOrange)
            }

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(monthDays, id: \.self) { date in
                    let active = store.didAnyActivity(on: date)
                    let selected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
                            selectedDate = date
                        }
                    } label: {
                        Text("\(Calendar.current.component(.day, from: date))")
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .foregroundStyle(active ? Color(red: 0.12, green: 0.12, blue: 0.12) : Paper.inkMute.opacity(selected ? 0.92 : 0.56))
                            .frame(height: 30)
                            .frame(maxWidth: .infinity)
                            .background(
                                Capsule()
                                    .fill(active ? AnyShapeStyle(streakNumberGradient) : AnyShapeStyle(Paper.ink.opacity(selected ? 0.10 : 0.055)))
                            )
                            .overlay(
                                Capsule()
                                    .stroke(selected ? streakOrange.opacity(0.82) : .clear, lineWidth: 2)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(date.formatted(.dateTime.day().month())), \(doneCount(on: date)) goals completed")
                }
            }

            selectedDayDetails
                .padding(.top, 6)
        }
        .padding(16)
        .streakGlass(cornerRadius: 24, active: false)
    }

    private var selectedDayDetails: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(selectedDate.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(Paper.ink)
                    Text("\(selectedDoneCount) of \(store.goals.count) goals completed")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Paper.inkMute)
                }
                Spacer()
                Image(systemName: selectedDoneCount > 0 ? "flame.fill" : "circle")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(selectedDoneCount > 0 ? streakOrange : Paper.inkMute.opacity(0.42))
            }

            if selectedStatuses.isEmpty {
                Text("No goals yet. Add one above and this day will show exactly what counted.")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Paper.inkMute)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(selectedStatuses, id: \.goal.id) { item in
                        HStack(spacing: 7) {
                            Image(systemName: item.goal.icon)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(item.isDone ? item.goal.tint : Paper.inkMute.opacity(0.46))
                                .frame(width: 24, height: 24)
                                .background(item.goal.tint.opacity(item.isDone ? 0.13 : 0.04), in: Circle())
                            Text(item.goal.title)
                                .font(.system(size: 11, weight: .heavy, design: .rounded))
                                .foregroundStyle(item.isDone ? Paper.ink : Paper.inkMute.opacity(0.55))
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(item.isDone ? Color(red: 0.32, green: 0.88, blue: 0.55) : Paper.inkMute.opacity(0.34))
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 8)
                        .background(Paper.ink.opacity(item.isDone ? 0.045 : 0.025), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                    }
                }
            }
        }
        .padding(12)
        .background(Paper.card.opacity(0.62), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Paper.hairline.opacity(0.55), lineWidth: 1)
        )
    }
}

private struct StreakWeekRail: View {
    let days: [(date: Date, isActive: Bool, isToday: Bool)]
    let compact: Bool

    var body: some View {
        VStack(spacing: compact ? 5 : 9) {
            HStack(spacing: compact ? 6 : 8) {
                ForEach(days, id: \.date) { day in
                    VStack(spacing: compact ? 3 : 5) {
                        Text(weekday(day.date))
                            .font(.system(size: compact ? 8 : 11, weight: .black, design: .rounded))
                            .foregroundStyle(day.isToday ? streakOrange : Paper.inkMute)
                        ZStack {
                            Circle()
                                .fill(day.isActive ? AnyShapeStyle(streakNumberGradient) : AnyShapeStyle(Paper.ink.opacity(0.12)))
                            Image(systemName: day.isActive ? "checkmark" : "")
                                .font(.system(size: compact ? 9 : 12, weight: .black))
                                .foregroundStyle(Color(red: 0.09, green: 0.11, blue: 0.13))
                        }
                        .frame(width: compact ? 18 : 34, height: compact ? 18 : 34)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func weekday(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = compact ? "EEEEE" : "EEE"
        return formatter.string(from: date)
    }
}

private struct StreakFlame: View {
    let size: CGFloat
    let active: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.black.opacity(active ? 0.14 : 0.08))
                .frame(width: size * 0.64, height: size * 0.24)
                .blur(radius: size * 0.05)
                .offset(y: size * 0.34)
            Image(systemName: "flame.fill")
                .font(.system(size: size * 0.76, weight: .black))
                .symbolRenderingMode(.palette)
                .foregroundStyle(
                    active ? Color(red: 1.0, green: 0.82, blue: 0.0) : Paper.inkMute.opacity(0.34),
                    active ? Color(red: 1.0, green: 0.30, blue: 0.26) : Paper.inkMute.opacity(0.18)
                )
                .shadow(color: active ? Color(red: 1.0, green: 0.44, blue: 0.10).opacity(0.38) : .clear, radius: size * 0.14, y: size * 0.05)
        }
        .frame(width: size, height: size)
    }
}

private var streakOrange: Color {
    Color(red: 1.0, green: 0.42, blue: 0.25)
}

private var streakNumberGradient: LinearGradient {
    LinearGradient(
        colors: [
            Color(red: 1.0, green: 0.86, blue: 0.06),
            Color(red: 1.0, green: 0.52, blue: 0.12),
            Color(red: 1.0, green: 0.33, blue: 0.28)
        ],
        startPoint: .top,
        endPoint: .bottom
    )
}

private var streakBackground: Color {
    Color.adaptive(
        Color(red: 0.969, green: 0.949, blue: 0.910),
        Color(red: 0.045, green: 0.085, blue: 0.095)
    )
}

struct ProgressionSummaryCard: View {
    @Environment(ScriptureStore.self) private var scripture
    @ObservedObject private var notes = NotebookStore.shared
    @AppStorage(ReadingState.lastBookKey) private var lastBookID = ""
    @AppStorage(ReadingState.lastChapterKey) private var lastChapter = 0

    private var remembranceLine: String {
        if let note = notes.notes.sorted(by: { $0.updatedAt > $1.updatedAt }).first {
            return "Τελευταία σημείωση: \(note.title)"
        }

        if !lastBookID.isEmpty, lastChapter > 0, let book = scripture.book(id: lastBookID) {
            return "Τελευταία ανάγνωση: \(book.titleGreek) \(lastChapter)"
        }

        if let listened = LastListened.load() {
            return "Τελευταία ομιλία: \(listened.homily.title)"
        }

        return "Ένας ήσυχος τόπος για όσα συνάντησες."
    }

    var body: some View {
        NavigationLink {
            ProgressionView()
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "lamp.desk.fill")
                        .font(.system(size: 13, weight: .bold))
                        .frame(width: 28, height: 28)
                        .background(Paper.gold.opacity(0.13), in: Circle())
                    Text("Το κελλί")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1.6)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Paper.inkMute.opacity(0.75))
                }
                .foregroundStyle(Paper.gold)

                Text(remembranceLine)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(Paper.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text("Μνήμη επιστροφής μέσα στον χρόνο της Εκκλησίας.")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Paper.inkMute)
                    .lineLimit(2)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .journeyGlass(cornerRadius: 26, intensity: 0.95)
        }
        .buttonStyle(CalmCardStyle())
    }
}

struct ProgressionView: View {
    @Environment(ScriptureStore.self) private var scripture
    @ObservedObject private var progress = PlayerProgressStore.shared
    @ObservedObject private var notes = NotebookStore.shared
    @State private var feastCalendar = OrthodoxFeastCalendarService()
    @AppStorage(ReadingState.lastBookKey) private var lastBookID = ""
    @AppStorage(ReadingState.lastChapterKey) private var lastChapter = 0

    private var today: Date { Date() }
    private var fasting: FastingStatus { FastingCalendar.shared.status(for: today) }
    private var calendarDay: OrthodoxCalendarDay? { feastCalendar.day(for: today) }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                header
                liturgicalTimeStrip
                seasonMeditationCard
                roadMemoryFlow
                returnInvitations
                anchorageCard
            }
            .padding(.horizontal, KSpace.gutter)
            .padding(.top, KSpace.lg)
            .padding(.bottom, KSpace.xxl)
        }
        .background(Paper.bg.ignoresSafeArea())
        .navigationTitle("Το κελλί")
        .navigationBarTitleDisplayMode(.inline)
        .task { await feastCalendar.loadCalendar() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Το κελλί")
                .font(.system(size: 42, weight: .heavy, design: .rounded))
                .foregroundStyle(Paper.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text("«Κάθισε στὸ κελλί σου, καὶ τὸ κελλὶ θὰ σὲ διδάξει τὰ πάντα»")
                .font(.system(size: 20, weight: .regular, design: .serif))
                .lineSpacing(5)
                .foregroundStyle(Paper.inkMute)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 4)
    }

    private var liturgicalTimeStrip: some View {
        NavigationLink {
            OrthodoxFeastCalendarView(service: feastCalendar)
        } label: {
            VStack(alignment: .leading, spacing: 13) {
                HStack {
                    Text("Ο λειτουργικός χρόνος")
                        .font(.system(size: 11, weight: .black))
                        .tracking(2.4)
                        .foregroundStyle(Paper.gold)
                    Spacer()
                    Image(systemName: "calendar")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Paper.gold.opacity(0.9))
                }

                VStack(alignment: .leading, spacing: 8) {
                    CellTimeLine(icon: "sparkles", title: "Περίοδος", value: liturgicalPeriodTitle)
                    CellTimeLine(icon: fasting.level.cardIcon, title: "Νηστεία", value: fasting.label)
                    CellTimeLine(icon: "flame.fill", title: "Μνήμη", value: feastTitle)
                }
            }
            .padding(18)
            .warmGlassCard(cornerRadius: 24, goldOpacity: 0.055)
        }
        .buttonStyle(CalmCardStyle())
    }

    private var seasonMeditationCard: some View {
        let item = seasonalRecommendation
        return NavigationLink {
            item.destination
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Image(systemName: item.icon)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(item.tint)
                        .frame(width: 40, height: 40)
                        .background(item.tint.opacity(0.13), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Για την περίοδο")
                            .font(.system(size: 11, weight: .black))
                            .tracking(2.4)
                            .foregroundStyle(Paper.gold)
                        Text(item.source)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Paper.inkMute)
                            .lineLimit(1)
                    }
                    Spacer()
                    Text(item.verb)
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(item.tint)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 11)
                        .background(item.tint.opacity(0.12), in: Capsule())
                }

                Text(item.title)
                    .font(KType.title(25))
                    .foregroundStyle(Paper.ink)
                    .fixedSize(horizontal: false, vertical: true)

                Text(item.body)
                    .font(.system(size: 15, weight: .semibold))
                    .lineSpacing(4)
                    .foregroundStyle(Paper.inkMute)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(18)
            .warmGlassCard(cornerRadius: 26, goldOpacity: 0.04)
        }
        .buttonStyle(CalmCardStyle())
    }

    private var roadMemoryFlow: some View {
        VStack(alignment: .leading, spacing: 13) {
            Text("Η ανάμνηση της οδού")
                .font(.system(size: 11, weight: .black))
                .tracking(2.2)
                .foregroundStyle(Paper.gold)

            VStack(spacing: 9) {
                ForEach(memoryItems) { item in
                    NavigationLink {
                        item.destination
                    } label: {
                        CellMemoryRow(item: item)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(18)
        .warmGlassCard(cornerRadius: 24, goldOpacity: 0.035)
    }

    private var returnInvitations: some View {
        let invitations = returnItems
        return Group {
            if !invitations.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Πού να επιστρέψεις")
                        .font(.system(size: 11, weight: .black))
                        .tracking(2.2)
                        .foregroundStyle(Paper.gold)

                    ForEach(invitations) { item in
                        NavigationLink {
                            item.destination
                        } label: {
                            CellReturnInvitation(item: item)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var anchorageCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 9) {
                Image(systemName: "anchor.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Paper.gold)
                Text("Το αγκυροβόλιο")
                    .font(.system(size: 11, weight: .black))
                    .tracking(2.2)
                    .foregroundStyle(Paper.gold)
            }

            Text(anchorText)
                .font(.system(size: 22, weight: .regular, design: .serif))
                .lineSpacing(7)
                .foregroundStyle(Paper.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text("Εδώ δεν μετράμε για να κερδίσουμε. Κρατάμε μνήμη για να επιστρέφουμε με αγάπη.")
                .font(.system(size: 14, weight: .semibold))
                .lineSpacing(4)
                .foregroundStyle(Paper.inkMute)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .warmGlassCard(cornerRadius: 24, goldOpacity: 0.075)
    }

    private var liturgicalPeriodTitle: String {
        if let major = calendarDay?.majorFeast, major.importance == .great {
            return major.title
        }

        let calendar = Paschalion.cal
        let year = calendar.component(.year, from: today)
        let pascha = calendar.startOfDay(for: Paschalion.pascha(year: year))
        let day = calendar.startOfDay(for: today)
        let offset = calendar.dateComponents([.day], from: pascha, to: day).day ?? 0

        switch offset {
        case -70 ..< -48:
            return "Τριῴδιον"
        case -48 ..< 0:
            return "Μεγάλη Τεσσαρακοστή"
        case 0:
            return "Άγιον Πάσχα"
        case 1 ... 39:
            return "Πεντηκοστάριον"
        case 40:
            return "Ανάληψις"
        case 41 ... 56:
            return "Πεντηκοστάριον"
        default:
            return "Μετά την Πεντηκοστή"
        }
    }

    private var feastTitle: String {
        calendarDay?.majorFeast?.title
        ?? calendarDay?.feasts.first?.title
        ?? "Μνήμη των Αγίων της ημέρας"
    }

    private var seasonalRecommendation: CellSeasonRecommendation {
        CellSeasonRecommendation.pick(
            fasting: fasting,
            period: liturgicalPeriodTitle,
            feastTitle: feastTitle,
            hasFeast: calendarDay?.majorFeast != nil,
            calendar: feastCalendar
        )
    }

    private var memoryItems: [CellMemoryItem] {
        var items: [CellMemoryItem] = []

        if progress.lastPracticeDate != nil {
            items.append(
                CellMemoryItem(
                    icon: "map.fill",
                    title: "Συνέχισες τη Βιβλική Πορεία.",
                    subtitle: "Η μνήμη αυτή σε επιστρέφει στο επόμενο βιβλικό μάθημα.",
                    destination: AnyView(LadderView())
                )
            )
        }

        if !lastBookID.isEmpty, lastChapter > 0, let book = scripture.book(id: lastBookID) {
            items.append(
                CellMemoryItem(
                    icon: "book.closed.fill",
                    title: "Στάθηκες στο \(book.titleGreek) \(lastChapter).",
                    subtitle: "Η ανάγνωση μένει ως τόπος επιστροφής.",
                    destination: AnyView(ChapterReadingView(route: ChapterRoute(bookID: lastBookID, chapterNumber: lastChapter)))
                )
            )
        }

        if let listened = LastListened.load() {
            items.append(
                CellMemoryItem(
                    icon: "waveform",
                    title: "Άκουσες την ομιλία «\(listened.homily.title)».",
                    subtitle: listened.context,
                    destination: AnyView(CellHomilyReturnView(homily: listened.homily, context: listened.context))
                )
            )
        }

        items.append(
            CellMemoryItem(
                icon: "flame.fill",
                title: "Η μέρα φέρνει τη μνήμη: \(feastTitle).",
                subtitle: "Άνοιξε το Εορτολόγιο για να δεις τη μνήμη της ημέρας.",
                destination: AnyView(OrthodoxFeastCalendarView(service: feastCalendar))
            )
        )

        if let note = notes.notes.sorted(by: { $0.updatedAt > $1.updatedAt }).first {
            items.append(
                CellMemoryItem(
                    icon: "note.text",
                    title: "Κράτησες στο σημειωματάριο: \(note.title).",
                    subtitle: "Οι προσωπικές σημειώσεις μένουν ιδιωτικές.",
                    destination: AnyView(NotebookView())
                )
            )
        }

        if items.isEmpty {
            items.append(
                CellMemoryItem(
                    icon: "leaf.fill",
                    title: "Το κελλί θα κρατήσει όσα συναντήσεις.",
                    subtitle: "Άνοιξε μια ανάγνωση, μια ομιλία ή μια σημείωση και γύρισε εδώ.",
                    destination: AnyView(ScriptureLibraryView())
                )
            )
        }

        return Array(items.prefix(5))
    }

    private var returnItems: [CellMemoryItem] {
        var items: [CellMemoryItem] = []

        if !lastBookID.isEmpty, lastChapter > 0, let book = scripture.book(id: lastBookID) {
            items.append(
                CellMemoryItem(
                    icon: "text.book.closed.fill",
                    title: "Γύρισε στο \(book.titleGreek).",
                    subtitle: "Ένα κεφάλαιο μπορεί να ξαναδιαβαστεί σαν πρώτη φορά.",
                    destination: AnyView(ChapterReadingView(route: ChapterRoute(bookID: lastBookID, chapterNumber: lastChapter)))
                )
            )
        }

        if let listened = LastListened.load() {
            items.append(
                CellMemoryItem(
                    icon: "play.circle.fill",
                    title: "Άκου ξανά την ομιλία που έμεινε ανοιχτή.",
                    subtitle: listened.homily.title,
                    destination: AnyView(CellHomilyReturnView(homily: listened.homily, context: listened.context))
                )
            )
        }

        if items.isEmpty {
            items.append(
                CellMemoryItem(
                    icon: "quote.bubble.fill",
                    title: "Διάλεξε έναν λόγο και κάθισε μαζί του.",
                    subtitle: "Το Γεροντικόν ανοίγει χώρο για ήσυχη επιστροφή.",
                    destination: AnyView(ShortStoriesSectionView())
                )
            )
        }

        return Array(items.prefix(2))
    }

    private var anchorText: String {
        let day = Calendar.current.ordinality(of: .day, in: .era, for: today) ?? 0
        if day.isMultiple(of: 2) {
            return "«Ὁ δοῦλος πράττει τὸ καλὸ ἀπὸ φόβο. Ὁ μισθωτὸς γιὰ τὴν ἀνταμοιβή. Ὁ υἱὸς ἀπὸ ἀγάπη.»"
        } else {
            return "«Πρόσεχε σεαυτῷ.»"
        }
    }
}

private struct CellTimeLine: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Paper.gold)
                .frame(width: 18)
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Paper.inkMute)
                .frame(width: 66, alignment: .leading)
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(Paper.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct CellSeasonRecommendation {
    let icon: String
    let title: String
    let source: String
    let body: String
    let verb: String
    let tint: Color
    let destination: AnyView

    static func pick(
        fasting: FastingStatus,
        period: String,
        feastTitle: String,
        hasFeast: Bool,
        calendar: OrthodoxFeastCalendarService
    ) -> CellSeasonRecommendation {
        let rules: [CellSeasonRule] = [
            CellSeasonRule(
                matches: { $0.hasFeast },
                make: { context in
                    CellSeasonRecommendation(
                        icon: "flame.fill",
                        title: context.feastTitle,
                        source: "Εορτολόγιο",
                        body: "Η μέρα στέκεται πρώτα στη μνήμη που της δίνει η Εκκλησία.",
                        verb: "Δές",
                        tint: Paper.gold,
                        destination: AnyView(OrthodoxFeastCalendarView(service: context.calendar))
                    )
                }
            ),
            CellSeasonRule(
                matches: { $0.fasting.isFast },
                make: { _ in
                    CellSeasonRecommendation(
                        icon: "leaf.fill",
                        title: "Ένας λόγος για την εγκράτεια",
                        source: "Γεροντικόν",
                        body: "Η νηστεία της ημέρας μπορεί να γίνει αφορμή για προσοχή και ησυχία.",
                        verb: "Κάθισε με αυτό",
                        tint: Color.adaptive(Color(red: 0.42, green: 0.52, blue: 0.32), Color(red: 0.68, green: 0.82, blue: 0.52)),
                        destination: AnyView(ShortStoriesSectionView())
                    )
                }
            ),
            CellSeasonRule(
                matches: { $0.period.contains("Τεσσαρακοστή") || $0.period.contains("Τριῴδιον") },
                make: { _ in
                    CellSeasonRecommendation(
                        icon: "hands.sparkles.fill",
                        title: "Μια προσευχή μετανοίας",
                        source: "Προσευχές",
                        body: "Η περίοδος καλεί σε επιστροφή, όχι σε βιασύνη.",
                        verb: "Δές",
                        tint: Color.adaptive(Color(red: 0.48, green: 0.42, blue: 0.62), Color(red: 0.74, green: 0.68, blue: 0.92)),
                        destination: AnyView(PrayerLibraryView())
                    )
                }
            )
        ]

        let context = CellSeasonContext(
            fasting: fasting,
            period: period,
            feastTitle: feastTitle,
            hasFeast: hasFeast,
            calendar: calendar
        )

        for rule in rules where rule.matches(context) {
            return rule.make(context)
        }

        return CellSeasonRecommendation(
            icon: "book.closed.fill",
            title: "Ένα κεφάλαιο για τη μέρα",
            source: "Αγία Γραφή",
            body: "Άνοιξε έναν λόγο της Γραφής χωρίς να τον κάνεις έργο προς ολοκλήρωση.",
            verb: "Δές",
            tint: Color.adaptive(Color(red: 0.22, green: 0.42, blue: 0.58), Color(red: 0.52, green: 0.72, blue: 0.92)),
            destination: AnyView(ScriptureLibraryView())
        )
    }
}

private struct CellSeasonContext {
    let fasting: FastingStatus
    let period: String
    let feastTitle: String
    let hasFeast: Bool
    let calendar: OrthodoxFeastCalendarService
}

private struct CellSeasonRule {
    let matches: (CellSeasonContext) -> Bool
    let make: (CellSeasonContext) -> CellSeasonRecommendation
}

private struct CellMemoryItem: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let subtitle: String
    let destination: AnyView
}

private struct CellMemoryRow: View {
    let item: CellMemoryItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: item.icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Paper.gold)
                .frame(width: 34, height: 34)
                .background(Paper.gold.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Paper.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(item.subtitle)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Paper.inkMute)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Paper.inkMute.opacity(0.68))
                .padding(.top, 4)
        }
        .padding(12)
        .background(Paper.ink.opacity(0.045), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
    }
}

private struct CellReturnInvitation: View {
    let item: CellMemoryItem

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: item.icon)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Paper.gold)
                    .frame(width: 38, height: 38)
                    .background(Paper.gold.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                Text(item.title)
                    .font(KType.title(20))
                    .foregroundStyle(Paper.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }

            Text(item.subtitle)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Paper.inkMute)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .warmGlassCard(cornerRadius: 22, goldOpacity: 0.04)
    }
}

private struct CellHomilyReturnView: View {
    let homily: Homily
    let context: String
    @State private var didPresent = false

    var body: some View {
        DidachesLibraryView()
            .onAppear {
                guard !didPresent else { return }
                didPresent = true
                HomilyPlayer.shared.present(homily, context: context)
            }
    }
}

private struct JourneyMetricCard: View {
    let icon: String
    let title: String
    let value: String
    let subtitle: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(tint.opacity(0.13), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            Spacer(minLength: 0)
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(Paper.inkMute)
            Text(value)
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundStyle(Paper.ink)
            Text(subtitle)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Paper.inkMute)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 136, alignment: .leading)
        .background(Paper.ink.opacity(0.045), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(tint.opacity(0.16), lineWidth: 1))
    }
}

private struct JourneyObservationRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Paper.gold)
                .frame(width: 34, height: 34)
                .background(Paper.gold.opacity(0.12), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(KType.title(16))
                    .foregroundStyle(Paper.ink)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Paper.inkMute)
                    .lineLimit(2)
            }
            Spacer()
        }
        .padding(12)
        .background(Paper.ink.opacity(0.045), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private extension View {
    func streakGlass(cornerRadius: CGFloat, active: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return self
            .background(
                shape.fill(
                    LinearGradient(
                        colors: [
                            Color.adaptive(
                                Color(red: 1.0, green: 0.77, blue: 0.24).opacity(active ? 0.24 : 0.12),
                                Color(red: 0.32, green: 0.15, blue: 0.06).opacity(active ? 0.42 : 0.24)
                            ),
                            Paper.card.opacity(0.76),
                            Color.adaptive(
                                Color(red: 1.0, green: 0.34, blue: 0.20).opacity(active ? 0.14 : 0.05),
                                Color(red: 0.95, green: 0.28, blue: 0.18).opacity(active ? 0.18 : 0.08)
                            )
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            )
            .overlay(
                shape.stroke(
                    LinearGradient(
                        colors: [
                            Color.adaptive(.white.opacity(0.64), Color(red: 1.0, green: 0.62, blue: 0.20).opacity(active ? 0.28 : 0.12)),
                            Color(red: 1.0, green: 0.50, blue: 0.12).opacity(active ? 0.28 : 0.12),
                            Paper.hairline.opacity(0.60)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
            )
    }

    func warmGlassCard(cornerRadius: CGFloat, goldOpacity: Double) -> some View {
        self
            .profileLiquidGlass(cornerRadius: cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Paper.gold.opacity(goldOpacity))
                    .allowsHitTesting(false)
            )
    }

    func journeyGlass(cornerRadius: CGFloat, intensity: Double) -> some View {
        let green = Color.adaptive(Color(red: 0.35, green: 0.58, blue: 0.45), Color(red: 0.58, green: 0.95, blue: 0.72))
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return self
            .profileLiquidGlass(cornerRadius: cornerRadius)
            .background(
                shape.fill(
                    LinearGradient(
                        colors: [
                            Paper.gold.opacity(0.07 * intensity),
                            green.opacity(0.08 * intensity),
                            Paper.card.opacity(0.58)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .allowsHitTesting(false)
            )
            .overlay(
                ZStack {
                    RadialGradient(
                        colors: [
                            green.opacity(0.18 * intensity),
                            Paper.gold.opacity(0.08 * intensity),
                            .clear
                        ],
                        center: .topLeading,
                        startRadius: 8,
                        endRadius: 250
                    )
                    shape.stroke(
                        LinearGradient(
                            colors: [
                                Color.adaptive(.white.opacity(0.46), green.opacity(0.30 * intensity)),
                                Paper.hairline.opacity(0.62),
                                Paper.gold.opacity(0.20 * intensity)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                }
                .clipShape(shape)
                .allowsHitTesting(false)
            )
    }

    func journeyAura(intensity: Double) -> some View {
        let green = Color.adaptive(Color(red: 0.22, green: 0.48, blue: 0.34), Color(red: 0.44, green: 0.86, blue: 0.62))
        return self
            .background(
                GeometryReader { proxy in
                    ZStack {
                        Circle()
                            .fill(green.opacity(0.11 * intensity))
                            .frame(width: proxy.size.width * 1.00, height: proxy.size.width * 1.00)
                            .blur(radius: 36)
                            .offset(y: proxy.size.height * 0.08)
                        Circle()
                            .fill(Paper.gold.opacity(0.05 * intensity))
                            .frame(width: proxy.size.width * 0.66, height: proxy.size.width * 0.66)
                            .blur(radius: 28)
                            .offset(y: -proxy.size.height * 0.04)
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                    .allowsHitTesting(false)
                }
            )
    }

    func rankLiquidGlass(tier: ProgressionTier, cornerRadius: CGFloat, intensity: Double) -> some View {
        let style = tier.style
        return self
            .profileLiquidGlass(cornerRadius: cornerRadius)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                style.base.opacity(0.12 * intensity),
                                style.dark.opacity(0.06 * intensity),
                                Paper.gold.opacity(0.025)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .allowsHitTesting(false)
            )
            .overlay(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(style.base.opacity(0.050 * intensity))
                    RadialGradient(
                        colors: [
                            style.light.opacity(0.18 * intensity),
                            style.base.opacity(0.07 * intensity),
                            .clear
                        ],
                        center: .topLeading,
                        startRadius: 10,
                        endRadius: 240
                    )
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    style.light.opacity(0.36 * intensity),
                                    Paper.inkMute.opacity(0.20),
                                    style.ring.opacity(0.24 * intensity)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .allowsHitTesting(false)
            )
    }

    func rankAura(tier: ProgressionTier, intensity: Double) -> some View {
        let style = tier.style
        return self
            .background(
                GeometryReader { proxy in
                    ZStack {
                        Circle()
                            .fill(style.base.opacity(0.13 * intensity))
                            .frame(width: proxy.size.width * 0.96, height: proxy.size.width * 0.96)
                            .blur(radius: 34)
                            .offset(y: proxy.size.height * 0.06)
                        Circle()
                            .fill(style.dark.opacity(0.07 * intensity))
                            .frame(width: proxy.size.width * 1.10, height: proxy.size.width * 1.10)
                            .blur(radius: 44)
                            .offset(y: proxy.size.height * 0.14)
                        Circle()
                            .fill(style.light.opacity(0.045 * intensity))
                            .frame(width: proxy.size.width * 0.58, height: proxy.size.width * 0.58)
                            .blur(radius: 26)
                            .offset(y: -proxy.size.height * 0.03)
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                    .allowsHitTesting(false)
                }
            )
    }
}
