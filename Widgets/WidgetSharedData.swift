import Foundation
import WidgetKit

// Κοινό στρώμα δεδομένων μεταξύ κύριας εφαρμογής και widget.
// ΠΡΟΣΟΧΗ: αυτό το αρχείο πρέπει να ανήκει ΚΑΙ στα δύο targets (Klimax και WidgetsExtension).
// Στο Xcode, στο File Inspector, τσέκαρε και τα δύο στο Target Membership.
// Η κύρια εφαρμογή γράφει το ημερήσιο στιγμιότυπο, το widget το διαβάζει.

// MARK: Ημερήσιο στιγμιότυπο

/// Ό,τι χρειάζονται και οι έξι κατηγορίες του widget για μία ημέρα.
struct KlimaxWidgetSnapshot: Codable, Equatable {
    var day: Date
    var fasting: FastingInfo
    var feast: FeastInfo
    var ladder: LadderInfo
    var gerontikon: GerontikonInfo
    var saintQuote: SaintQuoteInfo
    var saint: SaintInfo
    /// Συνοπτικὰ δεδομένα γιὰ τὰ πραγματικὰ widgets τῆς σελίδας «Σήμερα».
    /// Τὸ String key εἶναι σκόπιμο, ὥστε τὸ shared μοντέλο νὰ μὴν ἐξαρτᾶται
    /// ἀπὸ private enums τῆς κύριας εφαρμογῆς.
    var todayCards: [String: PhoneWidgetCard] = [:]
    /// Ἑπτὰ ἡμέρες νηστείας γιὰ τὰ διαδραστικὰ βέλη τοῦ widget.
    var fastingCards: [PhoneWidgetCard] = []
    /// Ἡ προσωπικὴ διάταξη τοῦ εἰκονοστασίου (1–6 εἰκόνες).
    var iconostasis: IconostasisWidgetInfo = .empty
    /// Ἡ τρέχουσα κατάσταση τῆς Βιβλικῆς Πορείας καὶ τῆς μασκότ της.
    /// Optional για να συνεχίσουν να διαβάζονται παλιότερα αποθηκευμένα snapshots.
    var scriptureJourney: ScriptureJourneyWidgetInfo? = nil
    /// Dated calendar entries, independent of the seven-day selector. Optional
    /// so snapshots written by older app versions continue to decode.
    var fastingCalendar: [PhoneWidgetCard]? = nil
    var stories: [PhoneWidgetCard]? = nil

    /// Δείγμα για preview και για fallback όταν δεν υπάρχει ακόμη δεδομένο.
    /// Οι συμβολοσειρές αντικαθίστανται από τα πραγματικά δεδομένα των stores.
    static let sample = KlimaxWidgetSnapshot(
        day: Date(),
        fasting: FastingInfo(title: "Κατάλυσις εἰς πάντα", detail: "Ἡμέρα χωρὶς νηστεία.", isFastDay: false),
        feast: FeastInfo(title: "Ἰωάννου τοῦ τῆς Κλίμακος", rank: "Μνήμη"),
        ladder: LadderInfo(sectionTitle: "Ἐνότητα Α´· Ἀποταγή", rung: 1, progress: 0.35),
        gerontikon: GerontikonInfo(saying: "Ἀπὸ τοῦ πλησίον ἐστὶν ἡ ζωὴ καὶ ὁ θάνατος.", abba: "Ἀββᾶς Ἀντώνιος"),
        saintQuote: SaintQuoteInfo(quote: "Δὸς αἷμα καὶ λάβε Πνεῦμα.", saint: "Ἀββᾶς Λογγῖνος"),
        saint: SaintInfo(name: "Ἰωάννης ὁ τῆς Κλίμακος", line: "Συγγραφεὺς τῆς Κλίμακος.", iconAssetName: nil),
        todayCards: PhoneWidgetCard.sampleCards,
        iconostasis: .sample,
        scriptureJourney: .sample
    )
}

// MARK: - Widgets «Σήμερα» καὶ Εἰκονοστάσι

/// Ἕνα μικρὸ, σταθερὸ payload ποὺ μπορεῖ νὰ σχεδιαστεῖ σὲ Home Screen
/// καὶ στὶς τρεῖς οἰκογένειες Lock Screen χωρὶς νὰ φορτώνει τὰ stores τοῦ app.
struct PhoneWidgetCard: Codable, Equatable {
    var eyebrow: String
    var title: String
    var detail: String
    var symbol: String
    var value: String?
    var progress: Double?
    /// Πρόσθετο context ποὺ χωρᾷ στὸ μεσαῖο/μεγάλο μέγεθος.
    var secondaryDetail: String? = nil
    /// Μικρὲς γραμμὲς πληροφορίας μόνο γιὰ τὸ μεγάλο μέγεθος.
    var items: [PhoneWidgetItem] = []
    /// Προαιρετικὸ style token (π.χ. free/fish/oil_wine/xerophagy).
    var themeKey: String? = nil
    var date: Date? = nil
    var expandedText: String? = nil
    var reflection: String? = nil

    static let sampleCards: [String: PhoneWidgetCard] = [
        "sundayLiturgy": .init(eyebrow: "ΘΕΙΑ ΛΕΙΤΟΥΡΓΙΑ", title: "Κυριακὴ τῆς ἡμέρας", detail: "Εὐαγγέλιον καὶ ἀκολουθία", symbol: "cross.fill"),
        "didaches": .init(eyebrow: "ΔΙΔΑΧΕΣ", title: "Ὁμιλία τῆς ἡμέρας", detail: "Μικρὴ στάση γιὰ σήμερα", symbol: "waveform"),
        "dailyStories": .init(eyebrow: "ΓΕΡΟΝΤΙΚΟΝ", title: "Ρητὰ τῆς ἡμέρας", detail: "Τρεῖς μικρὲς ἱστορίες", symbol: "text.quote"),
        "continueReading": .init(eyebrow: "ΣΥΝΕΧΕΙΑ ΑΝΑΓΝΩΣΗΣ", title: "Κατὰ Ἰωάννην 1", detail: "Συνέχισε ἀπὸ ἐκεῖ ποὺ ἔμεινες", symbol: "book.fill"),
        "verse": .init(eyebrow: "ΧΩΡΙΟ ΗΜΕΡΑΣ", title: "Ἐν ἀρχῇ ἦν ὁ Λόγος.", detail: "Ἰωάννης 1·1", symbol: "book.closed.fill"),
        "fasting": .init(eyebrow: "ΝΗΣΤΕΙΑ", title: "Κατάλυσις εἰς πάντα", detail: "Ἐπιτρέπονται ὅλες οἱ τροφές.", symbol: "leaf.fill"),
        "feastCalendar": .init(eyebrow: "ΕΟΡΤΟΛΟΓΙΟ", title: "Ἡ ἑορτὴ τῆς ἡμέρας", detail: "Σήμερα", symbol: "calendar"),
        "saints": .init(eyebrow: "ΑΓΙΟΙ ΤΗΣ ΗΜΕΡΑΣ", title: "Οἱ Ἅγιοι σήμερα", detail: "Ἄνοιγμα στὴν Κλῖμακα", symbol: "seal.fill"),
        "streaks": .init(eyebrow: "ΣΤΟΧΟΙ", title: "Συνέχισε τὴν πορεία", detail: "Ἡ σημερινὴ πρόοδος", symbol: "flame.fill", value: "0", progress: 0),
        "nearby": .init(eyebrow: "ΚΟΝΤΑ ΣΟΥ", title: "Ναοὶ κοντά σου", detail: "Ἄνοιγμα χάρτη", symbol: "mappin.circle.fill")
    ]
}

struct PhoneWidgetItem: Codable, Equatable, Identifiable {
    var id: String { "\(symbol)-\(title)-\(detail)" }
    var symbol: String
    var title: String
    var detail: String
}

struct IconostasisWidgetSaint: Codable, Equatable, Identifiable {
    var id: String
    var name: String
    /// Ὄνομα PNG μέσα στὸ κοινὸ App Group, ὄχι asset-catalog name.
    var imageFileName: String?
}

struct IconostasisWidgetInfo: Codable, Equatable {
    var saints: [IconostasisWidgetSaint]

    static let empty = IconostasisWidgetInfo(saints: [])
    static let sample = IconostasisWidgetInfo(saints: [
        .init(id: "sample-john", name: "Ἅγιος Ἰωάννης", imageFileName: nil),
        .init(id: "sample-mary", name: "Ἡ Θεοτόκος", imageFileName: nil),
        .init(id: "sample-nicholas", name: "Ἅγιος Νικόλαος", imageFileName: nil)
    ])
}

// MARK: - Βιβλικὴ Πορεία / μασκότ

enum ScriptureMascotMood: String, Codable, Hashable {
    case ready
    case thinking
    case celebrating

    var assetName: String {
        switch self {
        case .ready: "ScriptureMascotReady"
        case .thinking: "ScriptureMascotThinking"
        case .celebrating: "ScriptureMascotCelebrating"
        }
    }
}

struct ScriptureJourneyWidgetInfo: Codable, Equatable {
    var lessonTitle: String
    var unitTitle: String
    var completedLessons: Int
    var totalLessons: Int
    var currentStep: Int
    var totalSteps: Int
    var streak: Int
    var mood: ScriptureMascotMood
    var message: String

    var progress: Double {
        guard totalLessons > 0 else { return 0 }
        return min(1, max(0, Double(completedLessons) / Double(totalLessons)))
    }

    static let sample = ScriptureJourneyWidgetInfo(
        lessonTitle: "Ὁ λόγος καὶ τὸ ἔργον",
        unitTitle: "Γένεσις",
        completedLessons: 0,
        totalLessons: 2,
        currentStep: 0,
        totalSteps: 9,
        streak: 0,
        mood: .ready,
        message: "Τὸ πρῶτο μάθημα σὲ περιμένει."
    )
}

struct FastingInfo: Codable, Equatable {
    var title: String
    var detail: String
    var isFastDay: Bool
}

struct FeastInfo: Codable, Equatable {
    var title: String
    var rank: String
}

struct LadderInfo: Codable, Equatable {
    var sectionTitle: String
    var rung: Int
    var progress: Double   // 0.0 έως 1.0
}

struct GerontikonInfo: Codable, Equatable {
    var saying: String
    var abba: String
}

struct SaintQuoteInfo: Codable, Equatable {
    var quote: String
    var saint: String
}

struct SaintInfo: Codable, Equatable {
    var name: String
    var line: String
    /// Όνομα εικόνας στα Assets, ή nil για τυπογραφικό σχέδιο όταν λείπει εικόνα.
    var iconAssetName: String?
}

// MARK: Αποθήκη κοινού στρώματος

/// Pure diff, shared with regression tests. A goal change must never restart
/// the map snapshotter or invalidate every other Home Screen widget.
enum WidgetRefreshPlan {
    static func kinds(from old: KlimaxWidgetSnapshot?, to new: KlimaxWidgetSnapshot) -> Set<String> {
        let todayKeys = Set(new.todayCards.keys).union(old?.todayCards.keys.map { $0 } ?? [])
        var result = Set<String>()
        let dayChanged = old.map { !Calendar.current.isDate($0.day, inSameDayAs: new.day) } ?? true
        for key in todayKeys where dayChanged || old?.todayCards[key] != new.todayCards[key] {
            result.insert("Klimax.Today.\(key)")
        }
        if old?.fastingCalendar != new.fastingCalendar || old?.fastingCards != new.fastingCards {
            result.insert("Klimax.Today.fasting")
        }
        if old?.stories != new.stories { result.insert("Klimax.Today.dailyStories") }
        if old?.iconostasis != new.iconostasis { result.insert("Klimax.Iconostasis") }
        if old?.scriptureJourney != new.scriptureJourney { result.insert("Klimax.ScriptureJourney") }
        if old?.fasting != new.fasting { result.insert("KlimaxWidget.fasting") }
        if old?.feast != new.feast { result.insert("KlimaxWidget.feast") }
        if old?.ladder != new.ladder { result.insert("KlimaxWidget.ladder") }
        if old?.gerontikon != new.gerontikon { result.insert("KlimaxWidget.gerontikon") }
        if old?.saintQuote != new.saintQuote { result.insert("KlimaxWidget.saintQuote") }
        if old?.saint != new.saint { result.insert("KlimaxWidget.saintIcon") }
        return result
    }
}

enum WidgetSharedStore {

    static let appGroupID = "group.com.petroskallinicou.Klimax"
    private static let snapshotKey = "klimax.widget.snapshot"
    private static let fastingOffsetKey = "klimax.widget.fasting.offset"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
    }

    /// Καλείται από την κύρια εφαρμογή όταν αλλάζει η ημέρα ή το περιεχόμενο.
    static func save(_ snapshot: KlimaxWidgetSnapshot) {
        guard let defaults else {
            #if DEBUG
            print("[WidgetStore] το App Group δεν είναι διαθέσιμο. Τσέκαρε το capability και στα δύο targets.")
            #endif
            return
        }
        let changedKinds = WidgetRefreshPlan.kinds(from: storedSnapshot(), to: snapshot)
        guard !changedKinds.isEmpty else { return }
        do {
            let data = try JSONEncoder().encode(snapshot)
            defaults.set(data, forKey: snapshotKey)
            for kind in changedKinds { WidgetCenter.shared.reloadTimelines(ofKind: kind) }
            #if DEBUG
            print("[WidgetStore] αποθηκεύτηκε στιγμιότυπο, ανανέωση widgets")
            #endif
        } catch {
            #if DEBUG
            print("[WidgetStore] σφάλμα αποθήκευσης: \(error)")
            #endif
        }
    }

    /// Καλείται από το widget (TimelineProvider). Πάντα επιστρέφει κάτι εμφανίσιμο.
    static func load() -> KlimaxWidgetSnapshot {
        storedSnapshot() ?? .sample
    }


    /// Ἐνημερώνει μόνο τὶς κάρτες «Σήμερα», κρατώντας ἄθικτα τὰ παλιὰ widgets
    /// καὶ τὸ Εἰκονοστάσι. Χρήσιμο καθὼς τὰ stores φορτώνουν ἀσύγχρονα.
    static func updateTodayCards(_ cards: [String: PhoneWidgetCard], fastingCards: [PhoneWidgetCard] = [], fastingCalendar: [PhoneWidgetCard] = [], stories: [PhoneWidgetCard] = []) {
        let stored = storedSnapshot()
        var snapshot = stored ?? .sample
        // Σὲ νέα ἐγκατάσταση τὸ sample χρησιμεύει μόνο γιὰ τὶς Today κάρτες·
        // δὲν πρέπει νὰ μοιάζει σὰν ὁ χρήστης νὰ ἔχει ἤδη φτιάξει εἰκονοστάσι.
        if stored == nil { snapshot.iconostasis = .empty }
        snapshot.day = Date()
        snapshot.todayCards.merge(cards) { _, new in new }
        if !fastingCards.isEmpty { snapshot.fastingCards = fastingCards }
        if !fastingCalendar.isEmpty { snapshot.fastingCalendar = fastingCalendar }
        snapshot.stories = stories
        save(snapshot)
    }

    static func updateIconostasis(_ iconostasis: IconostasisWidgetInfo) {
        var snapshot = load()
        snapshot.iconostasis = iconostasis
        save(snapshot)
    }

    static func updateScriptureJourney(_ journey: ScriptureJourneyWidgetInfo) {
        var snapshot = load()
        snapshot.scriptureJourney = journey
        save(snapshot)
    }

    static var fastingDayOffset: Int {
        min(6, max(0, defaults?.integer(forKey: fastingOffsetKey) ?? 0))
    }

    static func moveFastingDay(by delta: Int) {
        defaults?.removeObject(forKey: "klimax.widget.fasting.date")
        defaults?.set(min(6, max(0, fastingDayOffset + delta)), forKey: fastingOffsetKey)
    }

    static func selectFastingDay(_ offset: Int) {
        defaults?.removeObject(forKey: "klimax.widget.fasting.date")
        defaults?.set(min(6, max(0, offset)), forKey: fastingOffsetKey)
    }

    static var selectedFastingDate: Date? {
        defaults?.object(forKey: "klimax.widget.fasting.date") as? Date
    }

    static func selectFastingDate(_ date: Date) {
        defaults?.set(date, forKey: "klimax.widget.fasting.date")
    }

    static var storyIndex: Int { max(0, defaults?.integer(forKey: "klimax.widget.story.index") ?? 0) }
    static func nextStory() {
        let count = load().stories?.count ?? 0
        defaults?.set(count > 0 ? (storyIndex + 1) % count : 0, forKey: "klimax.widget.story.index")
    }

    private static func storedSnapshot() -> KlimaxWidgetSnapshot? {
        guard let defaults, let data = defaults.data(forKey: snapshotKey) else { return nil }
        do {
            return try JSONDecoder().decode(KlimaxWidgetSnapshot.self, from: data)
        } catch {
            #if DEBUG
            print("[WidgetStore] σφάλμα ανάγνωσης, χρήση δείγματος: \(error)")
            #endif
            return nil
        }
    }
}
