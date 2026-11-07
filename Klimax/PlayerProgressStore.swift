//
//  PlayerProgressStore.swift
//  Klimax
//
//  Ἡ μηχανὴ προόδου τοῦ μαθητῆ: τὸ στρῶμα ποὺ ἔλειπε καὶ ἑνώνει τοὺς βρόχους.
//
//  Ἐδῶ ζεῖ ἡ ΜΑΘΗΣΗ ὡς μνήμη προσοχῆς: τί ἄνοιξε ὁ μαθητής, πότε ἐξασκήθηκε,
//  καὶ ποιά μαθήματα χρειάζονται ἐπιστροφή. Ἡ καταγραφή παραμένει ἰδιωτικὴ
//  βοήθεια, ὄχι σύστημα πόντων, βαθμῶν ἢ πνευματικῆς ἀνταμοιβῆς.
//
//  ΠΡΟΣΘΕΤΙΚΟ ἀρχεῖο: δὲν ἀλλάζει τίποτα ὑπάρχον ἀπὸ μόνο του. Οἱ ἀριθμοὶ
//  τῶν ἀνταμοιβῶν εἶναι σταθερὲς (constants) ἐδῶ, ὥστε νὰ ρυθμίζονται ἐλεύθερα
//  ἀργότερα χωρὶς καμία μετάπτωση δεδομένων (τὸ save κρατᾶ ὑπόλοιπα, ὄχι ρυθμούς).
//

import Foundation

// MARK: - Bible node memory

struct NodeMemoryRecord: Codable, Hashable {
    let nodeID: String
    var attempts: Int
    var correctAttempts: Int
    var strength: Int
    var lastReviewed: Date?
    var nextReview: Date?
}

/// Stores review memory at statement/node level, independently from lesson
/// completion. A card may therefore move one precise teaching statement
/// forward (or back) without treating the whole lesson as equally remembered.
@MainActor
final class NodeMemoryStore {
    static let shared = NodeMemoryStore()

    private let storageKey = "klimax.scripture.node-memory.v1"
    private let defaults: UserDefaults
    private(set) var nodes: [String: BibleMemoryNode] = [:]
    private(set) var records: [String: NodeMemoryRecord]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([String: NodeMemoryRecord].self, from: data) {
            records = decoded
        } else {
            records = [:]
        }
    }

    func register(_ definitions: [BibleMemoryNode]) {
        for node in definitions { nodes[node.id] = node }
    }

    func record(nodeID: String, correct: Bool, at date: Date = Date()) {
        var record = records[nodeID] ?? NodeMemoryRecord(
            nodeID: nodeID,
            attempts: 0,
            correctAttempts: 0,
            strength: 0,
            lastReviewed: nil,
            nextReview: nil
        )

        record.attempts += 1
        if correct {
            record.correctAttempts += 1
            record.strength = min(5, record.strength + 1)
        } else {
            record.strength = max(0, record.strength - 2)
        }
        record.lastReviewed = date

        let intervals = [0, 1, 3, 7, 14, 30]
        let days = correct ? intervals[record.strength] : 0
        record.nextReview = Calendar.current.date(byAdding: .day, value: days, to: date)
        records[nodeID] = record
        persist()
    }

    func dueNodeIDs(at date: Date = Date()) -> [String] {
        records.values
            .filter { ($0.nextReview ?? .distantPast) <= date }
            .sorted { ($0.nextReview ?? .distantPast) < ($1.nextReview ?? .distantPast) }
            .map(\.nodeID)
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(records) else { return }
        defaults.set(data, forKey: storageKey)
    }
}

// MARK: - Legacy μαθησιακές σταθερές
//
// Παραμένουν μόνο γιὰ συμβατότητα παλαιῶν saves καὶ γιὰ τὸ mastery threshold.
// Νέα ὁλοκλήρωση μαθήματος δὲν παράγει XP, χρυσὸ ἢ character XP.

enum ProgressBalance {
    // Ὁλοκλήρωση νέου μαθήματος (ἡ κύρια πηγή).
    static let newLessonXP = 40
    static let newLessonGold = 25
    static let newLessonCharacterXP = 30

    // Ἀνὰ σωστὴ ἀπάντηση (competence feedback).
    static let perCorrectXP = 2
    static let perCorrectGold = 1

    // Μπόνους ἀκρίβειας (κατοχή), ὅταν ἡ ἀκρίβεια φτάνει τὸ κατώφλι.
    static let masteryAccuracy = 0.80
    static let masteryBonusXP = 15
    static let masteryBonusGold = 10

    // Ἐπανάληψη ὁλοκληρωμένου μαθήματος: μικρὸ κλάσμα, character XP μηδέν.
    static let replayFactor = 0.12
    static let replaySoftCapPerDay = 2   // μετὰ ἀπὸ τόσες ἐπαναλήψεις τὴν ἴδια μέρα, σχεδὸν μηδέν

    // Ἡμερήσιος στόχος (μία δραστηριότητα ἀρκεῖ) καὶ ὁρόσημα streak.
    static let dailyGoalGold = 20
    static let dailyGoalXP = 10
    static let streakMilestones: [Int: Int] = [3: 15, 7: 50, 14: 80, 30: 150, 60: 250]

    // Καμπύλη ἐπιπέδου παίκτη (ἀθροιστικὸ XP γιὰ κάθε ἑπόμενο ἐπίπεδο).
    // Ἁπλὴ κλιμακούμενη: L1=0, L2=100, L3=250, L4=450, L5=700, μετὰ +300/ἐπίπεδο.
    static func level(forTotalXP xp: Int) -> Int {
        var level = 1
        var threshold = 0
        var step = 100
        while xp >= threshold + step {
            threshold += step
            level += 1
            step = min(step + 50, 300)
        }
        return level
    }

    static func xpIntoLevel(_ xp: Int) -> (into: Int, span: Int) {
        var threshold = 0
        var step = 100
        while xp >= threshold + step {
            threshold += step
            step = min(step + 50, 300)
        }
        return (xp - threshold, step)
    }
}

// MARK: - Κατοχὴ ἀνὰ μάθημα (σκελετὸς τώρα, πλήρης SM2 στὸ P1)

enum MasteryState: String, Codable {
    case new, learning, practicing, strong, mastered

    var label: String {
        switch self {
        case .new:        return "Νέο"
        case .learning:   return "Μαθαίνεις"
        case .practicing: return "Εξάσκηση"
        case .strong:     return "Σταθερό"
        case .mastered:   return "Κατοχή"
        }
    }
}

struct LessonRecord: Codable, Hashable {
    var timesCompleted: Int
    var bestAccuracy: Double
    var lastCompleted: Date
    var lastCompletedDayStamp: Int   // ἡμέρα (startOfDay) ὡς ἀκέραιος, γιὰ φθίνουσα ἐπανάληψη
    var replaysOnDay: Int

    var masteryState: MasteryState {
        if bestAccuracy >= 0.95 && timesCompleted >= 2 { return .mastered }
        if bestAccuracy >= ProgressBalance.masteryAccuracy { return .strong }
        if timesCompleted >= 1 { return .practicing }
        return .learning
    }
}

struct PlayerSave: Codable {
    var version: Int
    var totalXP: Int
    var currentStreak: Int
    var bestStreak: Int
    var lastActivityDayStamp: Int?
    var lastDailyGoalDayStamp: Int?
    var lessonRecords: [String: LessonRecord]

    static let empty = PlayerSave(
        version: 1,
        totalXP: 0,
        currentStreak: 0,
        bestStreak: 0,
        lastActivityDayStamp: nil,
        lastDailyGoalDayStamp: nil,
        lessonRecords: [:]
    )
}

/// Τὸ ἀποτέλεσμα μιᾶς ὁλοκλήρωσης, γιὰ νὰ τὸ δείξει ἡ ὀθόνη (π.χ. «+25 χρυσός»).
struct LessonReward: Hashable {
    var xp: Int
    var gold: Int
    var characterXP: Int
    var isReplay: Bool
    var hitMastery: Bool
    var streakExtended: Bool
    var newStreak: Int
    var dailyGoalJustMet: Bool
    var leveledUpTo: Int?
}

@MainActor
final class PlayerProgressStore: ObservableObject {
    static let shared = PlayerProgressStore()

    @Published private(set) var save: PlayerSave

    private let storageKey = "klimax.player.progress.v1"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode(PlayerSave.self, from: data) {
            save = decoded
        } else {
            save = .empty
        }
    }

    // MARK: Ἀναγνώσιμα

    var totalXP: Int { save.totalXP }
    var level: Int { ProgressBalance.level(forTotalXP: save.totalXP) }
    var currentStreak: Int { save.currentStreak }
    var bestStreak: Int { save.bestStreak }
    var completedLessonCount: Int { save.lessonRecords.values.filter { $0.timesCompleted > 0 }.count }
    var lessonPracticeCount: Int { save.lessonRecords.values.reduce(0) { $0 + $1.timesCompleted } }
    var reviewReadyCount: Int {
        save.lessonRecords.values.filter { record in
            record.masteryState == .learning || record.masteryState == .practicing
        }.count
    }
    var lastPracticeDate: Date? {
        save.lessonRecords.values.map(\.lastCompleted).max()
    }

    /// Ὁ ἡμερήσιος στόχος (μία δραστηριότητα) ἔχει ἐπιτευχθεῖ σήμερα.
    var dailyGoalMetToday: Bool {
        save.lastDailyGoalDayStamp == Self.dayStamp(Date())
    }

    func masteryState(for lessonID: String) -> MasteryState {
        save.lessonRecords[lessonID]?.masteryState ?? .new
    }

    // MARK: Ἡ κύρια εἴσοδος: ὁλοκλήρωση μαθήματος

    /// Καλεῖται μία φορά ὅταν ὁλοκληρώνεται ἕνα μάθημα. Καταγράφει μνήμη
    /// μελέτης καὶ στόχους, χωρὶς πόντους, χρυσὸ ἢ πνευματικὴ κατάταξη.
    @discardableResult
    func completeLesson(lessonID: String, exerciseCount: Int, correctAnswers: Int, firstTime: Bool) -> LessonReward {
        let today = Self.dayStamp(Date())
        let accuracy = exerciseCount > 0 ? Double(correctAnswers) / Double(exerciseCount) : 0
        let hitMastery = accuracy >= ProgressBalance.masteryAccuracy

        // πόσες φορὲς ἔχει ξαναγίνει σήμερα (γιὰ φθίνουσα ἐπανάληψη)
        var record = save.lessonRecords[lessonID]
        let replaysToday: Int = {
            guard let r = record, r.lastCompletedDayStamp == today else { return 0 }
            return r.replaysOnDay
        }()

        // ἐνημέρωση δεδομένων μαθήματος
        let newRecord = LessonRecord(
            timesCompleted: (record?.timesCompleted ?? 0) + 1,
            bestAccuracy: max(record?.bestAccuracy ?? 0, accuracy),
            lastCompleted: Date(),
            lastCompletedDayStamp: today,
            replaysOnDay: (record?.lastCompletedDayStamp == today ? replaysToday + 1 : 0)
        )
        record = newRecord
        save.lessonRecords[lessonID] = newRecord

        // streak + ἡμερήσιος στόχος, ὡς μνήμη συνέπειας καὶ ὄχι ἀνταμοιβή.
        let streakResult = registerDailyActivity(today: today)
        StreakStore.shared.record(.games, itemID: lessonID)
        var dailyGoalJustMet = false
        if save.lastDailyGoalDayStamp != today {
            save.lastDailyGoalDayStamp = today
            dailyGoalJustMet = true
        }

        persist()

        return LessonReward(
            xp: 0, gold: 0, characterXP: 0,
            isReplay: !firstTime, hitMastery: hitMastery,
            streakExtended: streakResult.extended, newStreak: save.currentStreak,
            dailyGoalJustMet: dailyGoalJustMet, leveledUpTo: nil
        )
    }

    // MARK: Streak (ἀσφαλὲς ὡς πρὸς τὴ ζώνη ὥρας, μὲ χάρη μιᾶς ἡμέρας)

    private func registerDailyActivity(today: Int) -> (extended: Bool, newStreak: Int) {
        guard let last = save.lastActivityDayStamp else {
            save.currentStreak = 1
            save.bestStreak = max(save.bestStreak, 1)
            save.lastActivityDayStamp = today
            return (true, 1)
        }
        if today == last {
            return (false, save.currentStreak)   // ἤδη μέτρησε σήμερα
        }
        if today == last + 1 {
            save.currentStreak += 1               // συνεχόμενη ἡμέρα
        } else {
            save.currentStreak = 1                // κενό: ἤρεμο ξεκίνημα ἀπὸ τὴν ἀρχή, χωρὶς τιμωρία
        }
        save.bestStreak = max(save.bestStreak, save.currentStreak)
        save.lastActivityDayStamp = today
        return (true, save.currentStreak)
    }

    // MARK: Persistence

    private func persist() {
        guard let data = try? JSONEncoder().encode(save) else { return }
        defaults.set(data, forKey: storageKey)
    }

    // Ἡμέρα ὡς αὔξων ἀκέραιος (ἡμέρες ἀπὸ σταθερὴ ἀναφορά, τοπικὸ ἡμερολόγιο).
    // Ἔτσι τὸ «today == last + 1» εἶναι σωστὸ καὶ στὰ ὅρια μηνῶν καὶ στὸ DST.
    private static func dayStamp(_ date: Date) -> Int {
        let cal = Calendar.current
        let start = cal.startOfDay(for: date)
        let ref = cal.startOfDay(for: Date(timeIntervalSinceReferenceDate: 0))
        return cal.dateComponents([.day], from: ref, to: start).day ?? 0
    }
}
