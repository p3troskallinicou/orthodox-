//
//  LiturgicalServices.swift
//  Klimax
//
//  Greek Orthodox Sunday resolver and service assembler. The engine contains
//  calendar logic only; service text lives exclusively in bundled JSON files.
//

import Foundation

enum GospelBook: String, Decodable, Hashable { case Matthew, Mark, Luke, John }

struct GospelRef: Decodable, Hashable {
    let book: GospelBook
    let ref: String
    let displayEl: String
    let textEl: String?
    let textSource: String?

    enum CodingKeys: String, CodingKey {
        case book, ref
        case displayEl = "display_el"
        case textEl = "text_el"
        case textSource = "text_source"
    }
}

/// Ἀποστολικὸ ἀνάγνωσμα. Τὸ `book` εἶναι τὸ id τοῦ βιβλίου ὅπως στὸ scripture.json
/// (π.χ. "romans", "2timothy") — ἔτσι δὲν χρειάζεται σκληρὴ ἀντιστοίχιση ἐδῶ.
struct ApostleRef: Decodable, Hashable {
    let book: String
    let ref: String
    let displayEl: String
    let textEl: String?
    let textSource: String?

    enum CodingKeys: String, CodingKey {
        case book, ref
        case displayEl = "display_el"
        case textEl = "text_el"
        case textSource = "text_source"
    }
}

/// Date-specific precedence for the Apostolos only. This deliberately lives
/// outside fixed feast Gospel overrides, so a saint's Apostolos can replace
/// the ordinary Sunday Epistle without changing that Sunday's Gospel.
struct ApostleDateOverride: Decodable, Identifiable, Hashable {
    let id: String
    let dateNewCalendar: String
    let apostle: ApostleRef

    enum CodingKeys: String, CodingKey {
        case id, apostle
        case dateNewCalendar = "date_new_calendar"
    }
}

/// Ἐτήσια ἐγκεκριμένη ἀντιστοίχιση τοῦ Κυπριακοῦ Τυπικοῦ. Οἱ συμπτώσεις
/// ἑορτῶν δὲν μποροῦν νὰ προκύψουν πάντοτε ἀπὸ τὸν γενικὸ κυριακάτικο κύκλο.
struct YearlySundayEntry: Decodable, Hashable {
    let date: String
    let echos: Int?
    let eothinon: Int?
    let apostle: ApostleRef
    let gospel: GospelRef
    let additionalGospels: [GospelRef]?
    enum CodingKeys: String, CodingKey {
        case date, echos, eothinon, apostle, gospel
        case additionalGospels = "additional_gospels"
    }
}

enum BaseLiturgyKind: String, Decodable, Hashable { case chrysostom, basil, presanctified }

enum BaseLiturgySectionRole: String, Decodable, Hashable {
    case preparation, opening, greatLitany = "great_litany", antiphons
    case littleEntrance = "little_entrance", trisagion, readings
    case apostleSlot = "apostle_slot", gospelSlot = "gospel_slot"
    case cherubicHymn = "cherubic_hymn", greatEntrance = "great_entrance"
    case creed, anaphora, epiclesis, commemorations
    case lordsPrayer = "lords_prayer", communion, thanksgiving, dismissal, other
}

enum LiturgyBlockKind: String, Decodable, Hashable {
    case spoken, rubric, placeholder
}

/// Πῶς ἐκφέρεται ἀπὸ τὸν Ἱερέα: μυστικῶς (σιγανὴ εὐχὴ) ἢ ἐκφώνως (δυνατά).
enum LiturgyVoice: String, Decodable, Hashable {
    case silent, aloud
}

/// Διάκριση rubric: χρυσὸς τίτλος ἢ λειτουργικὴ ὁδηγία.
enum LiturgyRubricKind: String, Decodable, Hashable {
    case heading, instruction
}

struct BaseLiturgyBlock: Decodable, Identifiable, Hashable {
    let id: String
    let speaker: String?
    let kind: LiturgyBlockKind
    let textEl: String
    let voice: LiturgyVoice?
    let rubricKind: LiturgyRubricKind?
    enum CodingKeys: String, CodingKey {
        case id, speaker, kind, voice, rubricKind
        case textEl = "text_el"
    }
}

struct BaseLiturgySection: Decodable, Identifiable, Hashable {
    let id: String
    let titleEl: String
    let role: BaseLiturgySectionRole?
    let textEl: String
    let blocks: [BaseLiturgyBlock]
    enum CodingKeys: String, CodingKey {
        case id, role, blocks
        case titleEl = "title_el", textEl = "text_el"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        titleEl = try c.decode(String.self, forKey: .titleEl)
        role = try c.decodeIfPresent(BaseLiturgySectionRole.self, forKey: .role)
        blocks = try c.decodeIfPresent([BaseLiturgyBlock].self, forKey: .blocks) ?? []
        textEl = try c.decodeIfPresent(String.self, forKey: .textEl)
            ?? blocks.map(\.textEl).joined(separator: "\n\n")
    }
}

struct LiturgyPlaceholders: Decodable, Hashable {
    let apostle: String
    let gospel: String
    let troparia: String
    let kontakia: String
    let commemorations: String
    let koinonikon: String
    let prokeimenon: String
    let hierarch: String
    let deceased: String

    enum CodingKeys: String, CodingKey {
        case apostle, gospel, troparia, kontakia, commemorations, koinonikon, prokeimenon
        case hierarch, deceased
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        apostle = try c.decode(String.self, forKey: .apostle)
        gospel = try c.decode(String.self, forKey: .gospel)
        troparia = try c.decode(String.self, forKey: .troparia)
        kontakia = try c.decode(String.self, forKey: .kontakia)
        commemorations = try c.decode(String.self, forKey: .commemorations)
        koinonikon = try c.decodeIfPresent(String.self, forKey: .koinonikon) ?? "{{KOINONIKON}}"
        prokeimenon = try c.decodeIfPresent(String.self, forKey: .prokeimenon) ?? "{{PROKEIMENON}}"
        hierarch = try c.decodeIfPresent(String.self, forKey: .hierarch) ?? "{{HIERARCH}}"
        deceased = try c.decodeIfPresent(String.self, forKey: .deceased) ?? "{{DECEASED}}"
    }
}

struct BaseLiturgy: Decodable, Hashable {
    let id: BaseLiturgyKind
    let titleEl: String
    let language: String
    let sourceStatus: String
    let sections: [BaseLiturgySection]
    let placeholders: LiturgyPlaceholders
    enum CodingKeys: String, CodingKey {
        case id, language, sections, placeholders
        case titleEl = "title_el"
        case sourceStatus = "source_status"
    }
}

enum SundayCycle: String, Decodable, Hashable {
    case triodion, greatLent = "great_lent", holyWeek = "holy_week"
    case paschaPentecostarion = "pascha_pentecostarion"
    case pentecostMatthew = "pentecost_matthew", pentecostLuke = "pentecost_luke"
    case fixedOverride = "fixed_override"
}

enum OrthrosGospelPolicy: String, Decodable, Hashable {
    case eothinonCycle = "eothinon_cycle", feastSpecific = "feast_specific"
    case none, requiresYearlyCalendar = "requires_yearly_calendar"
}

/// Ἀναστάσιμος ἦχος τῆς Ὀκτωήχου (1–8). Ὑπολογίζεται ἀπὸ τὴν ἡμερομηνία,
/// δὲν ἀποθηκεύεται — γιατὶ στὸ Τριῴδιο/Σαρακοστὴ ἐξαρτᾶται ἀπὸ τὴ χρονιά.
enum Echos: Int, Hashable, CaseIterable {
    case first = 1, second, third, fourth
    case plagalFirst, plagalSecond, grave, plagalFourth

    init?(number: Int) { self.init(rawValue: number) }
    var number: Int { rawValue }

    /// Ἐμφάνιση στὸν χρήστη (πολυτονικό, ὅπως στὰ λειτουργικὰ βιβλία).
    var displayEl: String {
        switch self {
        case .first:        return "Ἦχος α΄"
        case .second:       return "Ἦχος β΄"
        case .third:        return "Ἦχος γ΄"
        case .fourth:       return "Ἦχος δ΄"
        case .plagalFirst:  return "Ἦχος πλ. α΄"
        case .plagalSecond: return "Ἦχος πλ. β΄"
        case .grave:        return "Ἦχος βαρύς"
        case .plagalFourth: return "Ἦχος πλ. δ΄"
        }
    }

    /// Σταθερὸ κλειδὶ γιὰ δεδομένα (προκείμενα/ἀπολυτίκια κατ᾿ ἦχον).
    var key: String {
        switch self {
        case .grave: return "grave"
        default:     return String(rawValue)
        }
    }
}

struct SundayServiceDefinition: Decodable, Identifiable, Hashable {
    let id: String
    let titleEl: String
    let titleEn: String?
    let cycle: SundayCycle
    let relativeToPaschaDays: Int?
    let pentecostWeek: Int?
    let divineLiturgyGospel: GospelRef
    let divineLiturgyApostle: ApostleRef?
    let orthrosGospelPolicy: OrthrosGospelPolicy
    let defaultLiturgy: BaseLiturgyKind
    let needsYearlyCalendarVerification: Bool

    enum CodingKeys: String, CodingKey {
        case id, cycle
        case titleEl = "title_el", titleEn = "title_en"
        case relativeToPaschaDays = "relative_to_pascha_days"
        case pentecostWeek = "pentecost_week"
        case divineLiturgyGospel = "divine_liturgy_gospel"
        case divineLiturgyApostle = "divine_liturgy_apostle"
        case orthrosGospelPolicy = "orthros_gospel_policy"
        case defaultLiturgy = "default_liturgy"
        case needsYearlyCalendarVerification = "needs_yearly_calendar_verification"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        titleEl = try c.decode(String.self, forKey: .titleEl)
        titleEn = try c.decodeIfPresent(String.self, forKey: .titleEn)
        cycle = try c.decode(SundayCycle.self, forKey: .cycle)
        relativeToPaschaDays = try c.decodeIfPresent(Int.self, forKey: .relativeToPaschaDays)
        pentecostWeek = try c.decodeIfPresent(Int.self, forKey: .pentecostWeek)
        divineLiturgyGospel = try c.decode(GospelRef.self, forKey: .divineLiturgyGospel)
        divineLiturgyApostle = try c.decodeIfPresent(ApostleRef.self, forKey: .divineLiturgyApostle)
        orthrosGospelPolicy = try c.decodeIfPresent(OrthrosGospelPolicy.self, forKey: .orthrosGospelPolicy) ?? .eothinonCycle
        defaultLiturgy = try c.decode(BaseLiturgyKind.self, forKey: .defaultLiturgy)
        needsYearlyCalendarVerification = try c.decodeIfPresent(Bool.self, forKey: .needsYearlyCalendarVerification) ?? false
    }

    init(id: String, titleEl: String, cycle: SundayCycle, gospel: GospelRef,
         orthrosPolicy: OrthrosGospelPolicy, defaultLiturgy: BaseLiturgyKind,
         requiresVerification: Bool = false) {
        self.id = id; self.titleEl = titleEl; titleEn = nil; self.cycle = cycle
        relativeToPaschaDays = nil; pentecostWeek = nil
        divineLiturgyGospel = gospel; orthrosGospelPolicy = orthrosPolicy
        divineLiturgyApostle = nil
        self.defaultLiturgy = defaultLiturgy
        needsYearlyCalendarVerification = requiresVerification
    }

    init(base: SundayServiceDefinition, gospel: GospelRef, apostle: ApostleRef) {
        id = base.id; titleEl = base.titleEl; titleEn = base.titleEn; cycle = base.cycle
        relativeToPaschaDays = base.relativeToPaschaDays
        pentecostWeek = base.pentecostWeek
        divineLiturgyGospel = gospel
        divineLiturgyApostle = apostle
        orthrosGospelPolicy = base.orthrosGospelPolicy
        defaultLiturgy = base.defaultLiturgy
        needsYearlyCalendarVerification = false
    }
}

struct EothinonDefinition: Decodable, Hashable {
    let eothinon: Int
    let titleEl: String
    let gospel: GospelRef
    enum CodingKeys: String, CodingKey { case eothinon, gospel; case titleEl = "title_el" }
}

struct FixedFeastOverride: Decodable, Identifiable, Hashable {
    let id: String
    let dateNewCalendar: String?
    let rule: String?
    let titleEl: String
    let defaultLiturgy: BaseLiturgyKind
    let gospel: GospelRef
    enum CodingKeys: String, CodingKey {
        case id, rule, gospel
        case dateNewCalendar = "date_new_calendar", titleEl = "title_el"
        case defaultLiturgy = "default_liturgy"
    }
}

enum ScheduledServiceKind { case vespers, orthros, divineLiturgy }

struct LiturgicalYearSchedule: Decodable {
    let schemaVersion: Int
    let year: Int
    let jurisdiction: String
    let status: String
    let note: String
    let entries: [LiturgicalYearEntry]

    enum CodingKeys: String, CodingKey {
        case year, jurisdiction, status, note, entries
        case schemaVersion = "schema_version"
    }

    static func load(year: Int) throws -> LiturgicalYearSchedule {
        let resource = "typikon-services-\(year)"
        guard let url = Bundle.main.url(forResource: resource, withExtension: "json") else {
            throw NSError(domain: "Klimax.Typikon", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Δὲν ἔχει ἐνσωματωθεῖ ἀκόμη ἐγκεκριμένη Τυπικὴ Διάταξη γιὰ τὸ \(year)."
            ])
        }
        return try JSONDecoder().decode(Self.self, from: Data(contentsOf: url))
    }

    static func loadAvailable() throws -> [LiturgicalYearSchedule] {
        let urls = Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: nil) ?? []
        let schedules = try urls
            .filter { $0.deletingPathExtension().lastPathComponent.hasPrefix("typikon-services-") }
            .map { try JSONDecoder().decode(Self.self, from: Data(contentsOf: $0)) }
            .sorted { $0.year < $1.year }
        guard !schedules.isEmpty else {
            throw NSError(domain: "Klimax.Typikon", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Δὲν βρέθηκε ἐνσωματωμένη ἐτήσια Τυπικὴ Διάταξη."
            ])
        }
        return schedules
    }

    func entries(for kind: ScheduledServiceKind) -> [LiturgicalYearEntry] {
        entries.filter { $0.includes(kind) }
    }
}

struct LiturgicalYearEntry: Decodable, Identifiable, Hashable {
    let date: String
    let title: String
    let vespers: Bool
    let orthros: Bool
    let divineLiturgy: Bool
    let liturgyKind: BaseLiturgyKind?
    let officeBasis: String

    var id: String { date }

    enum CodingKeys: String, CodingKey {
        case date, title, vespers, orthros
        case divineLiturgy = "divine_liturgy"
        case liturgyKind = "liturgy_kind"
        case officeBasis = "office_basis"
    }

    func includes(_ kind: ScheduledServiceKind) -> Bool {
        switch kind {
        case .vespers: return vespers
        case .orthros: return orthros
        case .divineLiturgy: return divineLiturgy
        }
    }
}

struct AssembledServiceSection: Identifiable, Hashable {
    let id: String
    let titleEl: String
    let role: BaseLiturgySectionRole?
    let blocks: [AssembledServiceBlock]
    let textEl: String
}

struct AssembledServiceBlock: Identifiable, Hashable {
    let id: String
    let speaker: String?
    let kind: LiturgyBlockKind
    let textEl: String
    let voice: LiturgyVoice?
    let rubricKind: LiturgyRubricKind?
}

enum ServiceAssemblyStatus: String, Hashable { case placeholder, assembled }

struct SundayServicePackage: Hashable {
    struct SimpleService: Hashable {
        let included: Bool, textEl: String?, status: ServiceAssemblyStatus
    }
    struct OrthrosService: Hashable {
        let included: Bool, gospel: GospelRef?, textEl: String?, status: ServiceAssemblyStatus
    }
    struct DivineLiturgyService: Hashable {
        let included: Bool
        let baseLiturgy: BaseLiturgyKind
        let titleEl: String
        let gospel: GospelRef
        let echos: Echos?
        let eothinon: Int?
        let sections: [AssembledServiceSection]
        let textEl: String
        let status: ServiceAssemblyStatus
    }
    struct Services: Hashable {
        let vespers: SimpleService
        let orthros: OrthrosService
        let divineLiturgy: DivineLiturgyService
    }
    let date: String
    let sunday: SundayServiceDefinition
    let baseLiturgy: BaseLiturgyKind
    let services: Services
    let warnings: [String]
}

struct ServiceSearchResult: Identifiable, Hashable {
    let id: String
    let sectionId: String
    let sectionTitleEl: String?
    let blockId: String
    let speaker: String?
    let matchText: String
    let snippet: String
    let startOffset: Int
    let endOffset: Int
}

struct LiturgicalConfiguration: Hashable {
    enum Jurisdiction: String, Hashable { case constantinopolitan }
    enum CivilCalendar: String, Hashable { case newCalendar }
    var jurisdiction: Jurisdiction = .constantinopolitan
    var civilCalendar: CivilCalendar = .newCalendar
    var timeZone: TimeZone = .current
    var eothinonAnchor: Int = 1
}

/// Κοινωνικὰ Κυριακῶν (ὑμνολογικὸ κείμενο, ὄχι περικοπὴ Γραφῆς).
struct KoinonikonEntry: Decodable, Hashable {
    let textEl: String
    let refEl: String?
    enum CodingKeys: String, CodingKey {
        case textEl = "text_el"
        case refEl = "ref_el"
    }
}

struct KoinonikaData: Decodable, Hashable {
    let defaultEntry: KoinonikonEntry
    let overrides: [String: KoinonikonEntry]
    enum CodingKeys: String, CodingKey {
        case defaultEntry = "default"
        case overrides
    }
    /// Κοινωνικὸν γιὰ συγκεκριμένη Κυριακή: εἰδικὸ ἂν ὑπάρχει, ἀλλιῶς τὸ σταθερό.
    func entry(for sundayID: String) -> KoinonikonEntry {
        overrides[sundayID] ?? defaultEntry
    }
}

/// Κοντάκια Κυριακῶν (ὑμνολογικὸ κείμενο). Σταθερὸ «Προστασία τῶν Χριστιανῶν»
/// γιὰ τὶς κοινὲς Κυριακές· εἰδικὰ γιὰ Τριῴδιο/Πεντηκοστάριο/ἑορτές.
struct KontakionEntry: Decodable, Hashable {
    let textEl: String
    let echoEl: String?
    enum CodingKeys: String, CodingKey {
        case textEl = "text_el"
        case echoEl = "echo_el"
    }
}

struct KontakiaData: Decodable, Hashable {
    let defaultEntry: KontakionEntry?
    let overrides: [String: KontakionEntry]
    enum CodingKeys: String, CodingKey {
        case defaultEntry = "default"
        case overrides
    }
    func entry(for sundayID: String) -> KontakionEntry? {
        overrides[sundayID] ?? defaultEntry
    }
}

/// Προκείμενον Λειτουργίας. Ἀναστάσιμον κατ' ἦχον (by_echos) ἢ εἰδικὸ ἑορτῆς
/// (overrides κατὰ sunday-id). Ἔχει κύριο στίχο + (προαιρετικὰ) τὸν στίχο του.
struct ProkeimenonEntry: Decodable, Hashable {
    let textEl: String
    let stichosEl: String?
    let echoEl: String?
    enum CodingKeys: String, CodingKey {
        case textEl = "text_el"
        case stichosEl = "stichos_el"
        case echoEl = "echo_el"
    }
}

struct ProkeimenaData: Decodable, Hashable {
    let byEchos: [String: ProkeimenonEntry]
    let overrides: [String: ProkeimenonEntry]
    enum CodingKeys: String, CodingKey {
        case byEchos = "by_echos"
        case overrides
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        byEchos = try c.decodeIfPresent([String: ProkeimenonEntry].self, forKey: .byEchos) ?? [:]
        overrides = try c.decodeIfPresent([String: ProkeimenonEntry].self, forKey: .overrides) ?? [:]
    }
    /// Εἰδικὸ ἑορτῆς ἔχει προτεραιότητα· ἀλλιῶς ἀναστάσιμο κατ' ἦχον· ἀλλιῶς nil.
    func entry(echosKey: String?, sundayID: String) -> ProkeimenonEntry? {
        if let override = overrides[sundayID] { return override }
        guard let key = echosKey else { return nil }
        return byEchos[key]
    }
}

/// Ἀπολυτίκιον (τροπάριον Μικρᾶς Εἰσόδου). Ἀναστάσιμον κατ' ἦχον (by_echos),
/// εἰδικὸ ἑορτῆς ποὺ ἀντικαθιστᾶ (overrides), ἢ πρόσθετο ποὺ προστίθεται στὸ
/// ἀναστάσιμο (additions — π.χ. τῆς ἡμέρας στὶς Κυριακὲς τῆς Σαρακοστῆς).
/// `label`: ἐτικέτα κεφαλίδας (π.χ. «Ἀπολυτίκιον τοῦ Ἁγίου»)· ἀλλιῶς «Ἀπολυτίκιον».
/// `preformatted == true`: τὸ text_el ἔχει ἤδη τὶς ἐτικέτες του (π.χ. δύο
/// ἀπολυτίκια Βαΐων σὲ διαφορετικοὺς ἤχους) — δὲν προστίθεται αὐτόματη κεφαλίδα.
struct ApolytikionEntry: Decodable, Hashable {
    let textEl: String
    let echoEl: String?
    let label: String?
    let preformatted: Bool?
    enum CodingKeys: String, CodingKey {
        case textEl = "text_el"
        case echoEl = "echo_el"
        case label
        case preformatted
    }
}

struct ApolytikiaData: Decodable, Hashable {
    let byEchos: [String: ApolytikionEntry]
    let overrides: [String: ApolytikionEntry]
    let additions: [String: ApolytikionEntry]
    enum CodingKeys: String, CodingKey {
        case byEchos = "by_echos"
        case overrides
        case additions
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        byEchos = try c.decodeIfPresent([String: ApolytikionEntry].self, forKey: .byEchos) ?? [:]
        overrides = try c.decodeIfPresent([String: ApolytikionEntry].self, forKey: .overrides) ?? [:]
        additions = try c.decodeIfPresent([String: ApolytikionEntry].self, forKey: .additions) ?? [:]
    }
    /// Βάση: εἰδικὸ ἑορτῆς (ἀντικαθιστᾶ) ἢ ἀναστάσιμο κατ' ἦχον· ἀλλιῶς nil.
    func entry(echosKey: String?, sundayID: String) -> ApolytikionEntry? {
        if let override = overrides[sundayID] { return override }
        guard let key = echosKey else { return nil }
        return byEchos[key]
    }
    /// Πρόσθετο ἀπολυτίκιο τῆς ἡμέρας (προστίθεται μετὰ τὴ βάση), ἢ nil.
    func addition(sundayID: String) -> ApolytikionEntry? {
        additions[sundayID]
    }
}

struct LiturgicalRepository {
    let sundays: [SundayServiceDefinition]
    let eothina: [EothinonDefinition]
    let overrides: [FixedFeastOverride]
    let apostleDateOverrides: [ApostleDateOverride]
    let yearlySundays: [YearlySundayEntry]
    let koinonika: KoinonikaData?
    let kontakia: KontakiaData?
    let prokeimena: ProkeimenaData?
    let apolytikia: ApolytikiaData?

    static func load() throws -> LiturgicalRepository {
        let repository = LiturgicalRepository(
            sundays: try decode("sunday-gospels", as: [SundayServiceDefinition].self),
            eothina: try decode("eothina-gospels", as: [EothinonDefinition].self),
            overrides: try decode("fixed-feast-overrides", as: [FixedFeastOverride].self),
            apostleDateOverrides: try decode("apostle-date-overrides", as: [ApostleDateOverride].self),
            yearlySundays: try decode("kanonion-2026", as: [YearlySundayEntry].self),
            koinonika: try? decode("koinonika", as: KoinonikaData.self),
            kontakia: try? decode("kontakia", as: KontakiaData.self),
            prokeimena: try? decode("prokeimena", as: ProkeimenaData.self),
            apolytikia: try? decode("apolytikia", as: ApolytikiaData.self)
        )
        #if DEBUG
        LiturgicalValidation.validate(repository)
        #endif
        return repository
    }

    func baseLiturgy(_ kind: BaseLiturgyKind) throws -> BaseLiturgy {
        try Self.decode("\(kind.rawValue).el", as: BaseLiturgy.self)
    }

    private static func decode<T: Decodable>(_ resource: String, as type: T.Type) throws -> T {
        guard let url = Bundle.main.url(forResource: resource, withExtension: "json") else {
            throw NSError(domain: "Klimax.Liturgical", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Missing \(resource).json"])
        }
        return try JSONDecoder().decode(T.self, from: Data(contentsOf: url))
    }
}

enum SundayResolver {
    static func resolve(_ date: Date, repository: LiturgicalRepository,
                        configuration: LiturgicalConfiguration = .init()) -> SundayServiceDefinition? {
        let calendar = configuredCalendar(configuration)
        let civil = civilUTC(date, calendar: calendar)
        let year = Paschalion.cal.component(.year, from: civil)

        let base: SundayServiceDefinition?
        if let override = matchingOverride(date: civil, year: year, repository: repository) {
            base = SundayServiceDefinition(id: override.id, titleEl: override.titleEl,
                cycle: .fixedOverride, gospel: override.gospel, orthrosPolicy: .feastSpecific,
                defaultLiturgy: override.defaultLiturgy)
        } else {
            guard calendar.component(.weekday, from: date) == 1 else { return nil }
            let pascha = Paschalion.pascha(year: year)
            let offset = Paschalion.cal.dateComponents([.day], from: pascha, to: civil).day ?? Int.min
            if let definition = repository.sundays.first(where: { $0.relativeToPaschaDays == offset }) {
                base = definition
            } else {
                let paschaYear = civil >= pascha ? year : year - 1
                let previousPascha = Paschalion.pascha(year: paschaYear)
                let postOffset = Paschalion.cal.dateComponents([.day], from: previousPascha, to: civil).day ?? -1
                if postOffset >= 56, postOffset.isMultiple(of: 7) {
                    let week = postOffset / 7 - 7
                    base = repository.sundays.first(where: { $0.pentecostWeek == week })
                } else {
                    base = nil
                }
            }
        }
        guard let base else { return nil }
        guard let annual = yearlyEntry(for: date, repository: repository, configuration: configuration)
        else { return base }
        return SundayServiceDefinition(base: base, gospel: annual.gospel, apostle: annual.apostle)
    }

    static func liturgySelector(_ sunday: SundayServiceDefinition, date: Date) -> BaseLiturgyKind {
        if sunday.id == "st_basil_jan_1" { return .basil }
        if sunday.cycle == .greatLent { return .basil }
        return sunday.defaultLiturgy == .presanctified ? .chrysostom : sunday.defaultLiturgy
    }

    /// The Apostolos follows its own fixed-date precedence. A date override is
    /// checked in the configured local timezone; otherwise the ordinary Sunday
    /// cycle reading is used. Gospel resolution is intentionally untouched.
    static func apostle(for date: Date, sunday: SundayServiceDefinition,
                         repository: LiturgicalRepository,
                         configuration: LiturgicalConfiguration = .init()) -> ApostleRef? {
        let calendar = configuredCalendar(configuration)
        let key = String(
            format: "%02d-%02d",
            calendar.component(.month, from: date),
            calendar.component(.day, from: date)
        )
        return yearlyEntry(for: date, repository: repository, configuration: configuration)?.apostle
            ?? repository.apostleDateOverrides.first(where: { $0.dateNewCalendar == key })?.apostle
            ?? sunday.divineLiturgyApostle
    }

    /// Ἀναστάσιμος ἦχος τῆς Ὀκτωήχου γιὰ τὴ συγκεκριμένη Κυριακή.
    /// nil ὅταν κυριαρχεῖ ἡ ἑορτὴ καὶ δὲν ψάλλεται ἀναστάσιμον κατ᾿ ἦχον
    /// (Πάσχα, Θωμᾶ/Ἀντίπασχα, Πεντηκοστή, Βαΐων) — ἐκεῖ τὰ τροπάρια καὶ
    /// τὸ προκείμενον εἶναι ἴδια τῆς ἑορτῆς, ὄχι κατ᾿ ἦχον.
    static func echos(for date: Date, sunday: SundayServiceDefinition,
                      repository: LiturgicalRepository? = nil,
                      configuration: LiturgicalConfiguration = .init()) -> Echos? {
        if let repository,
           let annual = yearlyEntry(for: date, repository: repository, configuration: configuration) {
            return annual.echos.flatMap(Echos.init(number:))
        }
        switch sunday.id {
        case "pascha", "thomas_sunday", "pentecost", "palm_sunday": return nil
        default: break
        }
        let calendar = configuredCalendar(configuration)
        let civil = civilUTC(date, calendar: calendar)
        let year = Paschalion.cal.component(.year, from: civil)
        let thisPascha = Paschalion.pascha(year: year)
        let anchorPascha = civil >= thisPascha ? thisPascha : Paschalion.pascha(year: year - 1)
        let days = Paschalion.cal.dateComponents([.day], from: anchorPascha, to: civil).day ?? 0
        let weeks = days / 7
        // Ἄγκυρα: ἑβδ. 8 ἀπὸ Πάσχα = Ἁγ. Πάντων = πλ. δ΄ (8)· ἑβδ. 9 = Β΄ Ματθ. = α΄ (1)·
        // ὁ κύκλος συνεχίζεται ἀδιάκοπα ὣς τὰ Βαΐα τῆς ἑπόμενης χρονιᾶς.
        let index = (((weeks - 9) % 8) + 8) % 8      // 0…7 (floored mod)
        return Echos(number: index + 1)              // 1…8
    }

    /// Ἀριθμὸς ἑωθινοῦ εὐαγγελίου (1–11) γιὰ Κυριακὲς μὲ κύκλο ἑωθινῶν· nil ἀλλιῶς.
    static func eothinonNumber(for date: Date, sunday: SundayServiceDefinition,
                               repository: LiturgicalRepository? = nil,
                               configuration: LiturgicalConfiguration = .init()) -> Int? {
        if let repository,
           let annual = yearlyEntry(for: date, repository: repository, configuration: configuration) {
            return annual.eothinon
        }
        guard sunday.orthrosGospelPolicy == .eothinonCycle else { return nil }
        let calendar = configuredCalendar(configuration)
        let civil = civilUTC(date, calendar: calendar)
        let year = Paschalion.cal.component(.year, from: civil)
        let thisPascha = Paschalion.pascha(year: year)
        let anchorPascha = civil >= thisPascha ? thisPascha : Paschalion.pascha(year: year - 1)
        let days = Paschalion.cal.dateComponents([.day], from: anchorPascha, to: civil).day ?? 0
        let weeks = max(0, days / 7)
        return ((configuration.eothinonAnchor - 1 + weeks) % 11) + 1
    }

    static func orthrosGospel(for date: Date, sunday: SundayServiceDefinition,
                              repository: LiturgicalRepository,
                              configuration: LiturgicalConfiguration = .init()) -> GospelRef? {
        guard !repository.eothina.isEmpty,
              let number = eothinonNumber(for: date, sunday: sunday, repository: repository,
                                           configuration: configuration)
        else { return nil }
        return repository.eothina.first(where: { $0.eothinon == number })?.gospel
    }

    private static func configuredCalendar(_ configuration: LiturgicalConfiguration) -> Calendar {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = configuration.timeZone
        return calendar
    }

    static func yearlyEntry(for date: Date, repository: LiturgicalRepository,
                            configuration: LiturgicalConfiguration = .init()) -> YearlySundayEntry? {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = configuration.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        let key = formatter.string(from: date)
        return repository.yearlySundays.first(where: { $0.date == key })
    }

    private static func civilUTC(_ date: Date, calendar: Calendar) -> Date {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return Paschalion.cal.date(from: c)!
    }

    private static func matchingOverride(date: Date, year: Int,
                                         repository: LiturgicalRepository) -> FixedFeastOverride? {
        let key = String(format: "%02d-%02d", Paschalion.cal.component(.month, from: date),
                         Paschalion.cal.component(.day, from: date))
        if let exact = repository.overrides.first(where: { $0.dateNewCalendar == key }) { return exact }
        return repository.overrides.first { item in
            guard let rule = item.rule else { return false }
            return [year - 1, year, year + 1].contains { anchorYear in
                guard let target = dateForRule(rule, year: anchorYear) else { return false }
                return Paschalion.cal.isDate(target, inSameDayAs: date)
            }
        }
    }

    private static func dateForRule(_ rule: String, year: Int) -> Date? {
        switch rule {
        case "sunday_before_nativity": return adjacentSunday(year: year, month: 12, day: 25, direction: -1)
        case "two_sundays_before_nativity":
            return Paschalion.cal.date(byAdding: .day, value: -7,
                to: adjacentSunday(year: year, month: 12, day: 25, direction: -1)!)
        case "sunday_after_nativity": return adjacentSunday(year: year, month: 12, day: 25, direction: 1)
        case "sunday_before_theophany": return adjacentSunday(year: year, month: 1, day: 6, direction: -1)
        case "sunday_after_theophany": return adjacentSunday(year: year, month: 1, day: 6, direction: 1)
        default: return nil
        }
    }

    private static func adjacentSunday(year: Int, month: Int, day: Int, direction: Int) -> Date? {
        guard let feast = Paschalion.cal.date(from: DateComponents(year: year, month: month, day: day)) else { return nil }
        for distance in 1...7 {
            let candidate = Paschalion.cal.date(byAdding: .day, value: direction * distance, to: feast)!
            if Paschalion.cal.component(.weekday, from: candidate) == 1 { return candidate }
        }
        return nil
    }
}

private enum BaseLiturgyBlockFallback {
    static func make(_ section: BaseLiturgySection) -> BaseLiturgyBlock {
        BaseLiturgyBlock(id: "\(section.id)-text", speaker: nil, kind: .spoken,
                         textEl: section.textEl, voice: nil, rubricKind: nil)
    }
}

enum ScripturePassageResolver {
    /// Γενικὴ ἀνάλυση περικοπῆς: δέχεται id βιβλίου (ὅπως στὸ scripture.json) + ref.
    static func text(forBookID bookID: String, ref: String, in bible: Bible) -> String? {
        let candidates = bookIDCandidates(bookID)
        guard let book = bible.testaments.flatMap(\.books)
                .first(where: { candidates.contains($0.id.lowercased()) }),
              let requests = parse(ref), !requests.isEmpty else { return nil }

        var output: [String] = []
        for request in requests {
            guard let chapter = book.chapters.first(where: { $0.number == request.chapter }) else { return nil }
            let verses = chapter.verses.filter { request.verses.contains($0.number) }
            let expectedCount = request.verses.upperBound == Int.max
                ? verses.count
                : request.verses.upperBound - request.verses.lowerBound + 1
            guard !verses.isEmpty, verses.count == expectedCount else { return nil }
            if requests.map(\.chapter).uniqued.count > 1 {
                output.append("\(book.titleGreek) \(request.chapter)")
            }
            output.append(contentsOf: verses.map { "\($0.number)  \($0.ancient)" })
        }
        return output.joined(separator: "\n")
    }

    /// Ἀνοχὴ στὸν τρόπο γραφῆς id ἀριθμημένων βιβλίων (π.χ. 1corinthians /
    /// firstcorinthians / icorinthians / 1_corinthians).
    private static func bookIDCandidates(_ id: String) -> Set<String> {
        let low = id.lowercased()
        var out: Set<String> = [low]
        let prefixes: [(String, [String])] = [
            ("1", ["first", "i", "a"]), ("2", ["second", "ii", "b"]), ("3", ["third", "iii", "c"])
        ]
        for (digit, words) in prefixes where low.hasPrefix(digit) {
            let rest = String(low.dropFirst())
            out.insert(digit + "_" + rest)
            for w in words { out.insert(w + rest); out.insert(w + "_" + rest) }
        }
        return out
    }

    static func text(for gospel: GospelRef, in bible: Bible) -> String? {
        let bookID: String
        switch gospel.book {
        case .Matthew: bookID = "matthew"
        case .Mark: bookID = "mark"
        case .Luke: bookID = "luke"
        case .John: bookID = "john"
        }
        return text(forBookID: bookID, ref: gospel.ref, in: bible)
    }

    static func text(for apostle: ApostleRef, in bible: Bible) -> String? {
        text(forBookID: apostle.book, ref: apostle.ref, in: bible)
    }

    private struct Request {
        let chapter: Int
        let verses: ClosedRange<Int>
    }

    private static func parse(_ raw: String) -> [Request]? {
        var requests: [Request] = []
        var currentChapter: Int?
        for group in raw.split(separator: ";") {
            for tokenValue in group.split(separator: ",") {
                let token = String(tokenValue).trimmingCharacters(in: .whitespaces)
                let sides = token.split(separator: "-", maxSplits: 1).map(String.init)
                let startParts = sides[0].split(separator: ":", maxSplits: 1).map(String.init)
                let startVerse: Int
                if startParts.count == 2 {
                    guard let chapter = Int(startParts[0]), let verse = Int(startParts[1]) else { return nil }
                    currentChapter = chapter; startVerse = verse
                } else {
                    guard currentChapter != nil, let verse = Int(startParts[0]) else { return nil }
                    startVerse = verse
                }
                guard let startChapter = currentChapter else { return nil }
                if sides.count == 1 {
                    requests.append(.init(chapter: startChapter, verses: startVerse...startVerse))
                    continue
                }
                let endParts = sides[1].split(separator: ":", maxSplits: 1).map(String.init)
                if endParts.count == 1 {
                    guard let endVerse = Int(endParts[0]), endVerse >= startVerse else { return nil }
                    requests.append(.init(chapter: startChapter, verses: startVerse...endVerse))
                } else {
                    guard let endChapter = Int(endParts[0]), let endVerse = Int(endParts[1]),
                          endChapter >= startChapter else { return nil }
                    for chapterNumber in startChapter...endChapter {
                        if chapterNumber == startChapter {
                            // A cross-chapter request needs the chapter's actual final verse;
                            // use a wide range and trim it against available data below.
                            requests.append(.init(chapter: chapterNumber, verses: startVerse...Int.max))
                        } else if chapterNumber == endChapter {
                            requests.append(.init(chapter: chapterNumber, verses: 1...endVerse))
                        } else {
                            requests.append(.init(chapter: chapterNumber, verses: 1...Int.max))
                        }
                    }
                    currentChapter = endChapter
                }
            }
        }
        return requests
    }
}

private extension Array where Element: Hashable {
    var uniqued: [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

enum ServiceAssembler {
    static func assemble(_ date: Date, repository: LiturgicalRepository,
                         configuration: LiturgicalConfiguration = .init(),
                         bible: Bible? = nil,
                         scheduledEntry: LiturgicalYearEntry? = nil) throws -> SundayServicePackage? {
        let resolved = SundayResolver.resolve(date, repository: repository, configuration: configuration)
        let scheduledDefinition: SundayServiceDefinition? = scheduledEntry.flatMap { entry in
            guard entry.divineLiturgy, let kind = entry.liturgyKind else { return nil }
            let readingNotice = GospelRef(
                book: .Matthew,
                ref: "",
                displayEl: "Τὰ ἀναγνώσματα τῆς ἐτήσιας Τυπικῆς Διατάξεως",
                textEl: nil,
                textSource: nil
            )
            return SundayServiceDefinition(
                id: "typikon-\(entry.date)", titleEl: entry.title, cycle: .fixedOverride,
                gospel: readingNotice, orthrosPolicy: .requiresYearlyCalendar,
                defaultLiturgy: kind, requiresVerification: true
            )
        }
        guard let sunday = resolved ?? scheduledDefinition else { return nil }
        let kind = scheduledEntry?.liturgyKind ?? SundayResolver.liturgySelector(sunday, date: date)
        let base = try repository.baseLiturgy(kind)
        let annual = SundayResolver.yearlyEntry(for: date, repository: repository,
                                                configuration: configuration)
        let gospelRefs = [sunday.divineLiturgyGospel] + (annual?.additionalGospels ?? [])
        let internalGospel = gospelRefs.compactMap { reference in
            bible.flatMap { ScripturePassageResolver.text(for: reference, in: $0) }
                ?? reference.textEl
        }.joined(separator: "\n\n")
        let gospelBlock = internalGospel.isEmpty
            ? "Εὐαγγέλιον: \(sunday.divineLiturgyGospel.displayEl)"
            : "Εὐαγγέλιον: \(sunday.divineLiturgyGospel.displayEl)\n\n\(internalGospel)"

        // Ἀπόστολος: ἴδιο μοτίβο μὲ τὸ Εὐαγγέλιο. Ἂν ἡ Κυριακὴ δὲν ἔχει
        // ἀποστολικὴ περικοπὴ (ἢ δὲν λύνεται τὸ κείμενο), τὸ {{APOSTLE}} μένει
        // ὡς placeholder καὶ τὸ view τὸ δείχνει ὡς κουτάκι.
        let resolvedApostle = SundayResolver.apostle(
            for: date, sunday: sunday, repository: repository, configuration: configuration
        )
        let internalApostle: String? = resolvedApostle.flatMap { ref in
            (bible.flatMap { ScripturePassageResolver.text(for: ref, in: $0) }) ?? ref.textEl
        }
        let apostleBlock: String? = resolvedApostle.map { ref in
            internalApostle.map { "Ἀπόστολος: \(ref.displayEl)\n\n\($0)" }
                ?? "Ἀπόστολος: \(ref.displayEl)"
        }

        // Κοινωνικόν: ὑμνολογικὸ κείμενο ἀπὸ τὰ δεδομένα (εἰδικὸ ἂν ὑπάρχει,
        // ἀλλιῶς τὸ σταθερὸ Κυριακῆς). Ἂν λείπει τὸ ἀρχεῖο, μένει κουτάκι.
        let koinonikonText: String? = repository.koinonika?.entry(for: sunday.id).textEl

        // Κοντάκιον: σταθερὸ «Προστασία» γιὰ κοινὲς Κυριακές, εἰδικὸ γιὰ ἑορτές.
        let kontakionText: String? = repository.kontakia?.entry(for: sunday.id)?.textEl

        // Ἀναστάσιμος ἦχος + ἀριθμὸς ἑωθινοῦ (ὑπολογισμένα ἀπὸ τὴν ἡμερομηνία).
        let echos = SundayResolver.echos(for: date, sunday: sunday, repository: repository,
                                         configuration: configuration)
        let eothinon = SundayResolver.eothinonNumber(for: date, sunday: sunday,
                                                      repository: repository,
                                                      configuration: configuration)

        // Προκείμενον: ἀναστάσιμο κατ' ἦχον (ἢ εἰδικὸ ἑορτῆς). Ὁ τίτλος παίρνει
        // τὸν ἦχο ἀπὸ τὰ δεδομένα, ἀλλιῶς τὸν ὑπολογισμένο ἦχο τῆς Κυριακῆς.
        let prokeimenonText: String? = repository.prokeimena.flatMap { data -> String? in
            guard let entry = data.entry(echosKey: echos?.key, sundayID: sunday.id) else { return nil }
            let tone = entry.echoEl ?? echos?.displayEl
            let head = tone.map { "Προκείμενον. \($0)" } ?? "Προκείμενον"
            let body = entry.stichosEl.map { "\(entry.textEl)\nΣτίχ. \($0)" } ?? entry.textEl
            return "\(head)\n\(body)"
        }

        // Ἀπολυτίκιον (τροπάριον εἰσόδου): βάση (εἰδικὸ ἑορτῆς ἢ ἀναστάσιμο κατ'
        // ἦχον) + προαιρετικὸ πρόσθετο τῆς ἡμέρας (π.χ. Κυριακὲς Σαρακοστῆς).
        let troparionText: String? = repository.apolytikia.flatMap { data -> String? in
            func format(_ e: ApolytikionEntry) -> String {
                if e.preformatted == true { return e.textEl }
                let tone = e.echoEl ?? echos?.displayEl
                let name = e.label ?? "Ἀπολυτίκιον"
                let head = tone.map { "\(name). \($0)" } ?? name
                return "\(head)\n\(e.textEl)"
            }
            var parts: [String] = []
            if let base = data.entry(echosKey: echos?.key, sundayID: sunday.id) {
                parts.append(format(base))
            }
            if let addition = data.addition(sundayID: sunday.id) {
                parts.append(format(addition))
            }
            return parts.isEmpty ? nil : parts.joined(separator: "\n")
        }

        let sections = base.sections.map { section in
            let sourceBlocks = section.blocks.isEmpty
                ? [BaseLiturgyBlockFallback.make(section)]
                : section.blocks
            let blocks = sourceBlocks.map { block -> AssembledServiceBlock in
                // Τὸ Εὐαγγέλιο (καὶ ὁ Ἀπόστολος, ἂν ὑπάρχει) ἀντικαθίστανται
                // inline. Τὰ ὑπόλοιπα placeholders (Προκείμενον, Τροπάρια,
                // Κοντάκια, …) μένουν ὡς {{TOKEN}} καὶ τὰ δείχνει
                // τὸ view ὡς κουτάκια «πρὸς συμπλήρωση».
                var text = block.textEl.replacingOccurrences(
                    of: base.placeholders.gospel, with: gospelBlock)
                if let apostleBlock {
                    text = text.replacingOccurrences(of: base.placeholders.apostle, with: apostleBlock)
                }
                if let koinonikonText {
                    text = text.replacingOccurrences(of: base.placeholders.koinonikon, with: koinonikonText)
                }
                if let kontakionText {
                    text = text.replacingOccurrences(of: base.placeholders.kontakia, with: kontakionText)
                }
                if let prokeimenonText {
                    text = text.replacingOccurrences(of: base.placeholders.prokeimenon, with: prokeimenonText)
                }
                if let troparionText {
                    text = text.replacingOccurrences(of: base.placeholders.troparia, with: troparionText)
                }
                // Τοπικὰ/προσωπικὰ ὀνόματα δὲν μποροῦν νὰ συμπληρωθοῦν
                // αὐτόματα. Δείχνονται ὡς καθαρὲς λειτουργικὲς ἐνδείξεις,
                // ποτὲ ὡς τεχνικὰ {{TOKENS}} μέσα στὸ ἀναγνώσιμο κείμενο.
                text = text.replacingOccurrences(
                    of: base.placeholders.hierarch, with: "(δεῖνος)"
                )
                text = text.replacingOccurrences(
                    of: base.placeholders.commemorations, with: "(δεῖνος)"
                )
                text = text.replacingOccurrences(
                    of: base.placeholders.deceased,
                    with: "(μνημονεύει ἐνταῦθα ὅσα ὀνόματα θέλει κεκοιμημένων)"
                )
                return AssembledServiceBlock(
                    id: block.id, speaker: block.speaker, kind: block.kind,
                    textEl: text, voice: block.voice, rubricKind: block.rubricKind
                )
            }
            return AssembledServiceSection(
                id: section.id, titleEl: section.titleEl, role: section.role, blocks: blocks,
                textEl: blocks.map(\.textEl).joined(separator: "\n\n")
            )
        }
        let combined = sections.map(\.textEl).filter { !$0.isEmpty }.joined(separator: "\n\n")
        var warnings: [String] = []
        if SundayResolver.yearlyEntry(for: date, repository: repository,
                                      configuration: configuration) == nil {
            warnings.append("Ἡ συγκεκριμένη ἡμερομηνία δὲν καλύπτεται ἀπὸ ἐτήσιο Κυπριακὸ Τυπικό· χρησιμοποιεῖται ὁ γενικὸς κύκλος.")
        }
        if base.sourceStatus == "placeholder_only" {
            warnings.append("Τὸ βασικὸ κείμενο τῆς ἀκολουθίας δὲν ἔχει προστεθεῖ ἀκόμη.")
        }
        // Ἀναστάσιμος ἦχος + ἀριθμὸς ἑωθινοῦ: ὑπολογίστηκαν παραπάνω.
        #if DEBUG
        let echosLog = echos?.displayEl ?? "— (ἑορτή)"
        let eothLog = eothinon.map { " · ἑωθινὸν \($0)" } ?? ""
        print("🎼 [Klimax·Ἦχος] \(sunday.id): \(echosLog)\(eothLog)")
        #endif
        let formatter = DateFormatter(); formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = configuration.timeZone; formatter.dateFormat = "yyyy-MM-dd"
        return SundayServicePackage(
            date: formatter.string(from: date), sunday: sunday, baseLiturgy: kind,
            services: .init(
                vespers: .init(included: true, textEl: nil, status: .placeholder),
                orthros: .init(included: true,
                    gospel: SundayResolver.orthrosGospel(for: date, sunday: sunday,
                        repository: repository, configuration: configuration),
                    textEl: nil, status: .placeholder),
                divineLiturgy: .init(included: true, baseLiturgy: kind, titleEl: base.titleEl,
                    gospel: sunday.divineLiturgyGospel, echos: echos, eothinon: eothinon,
                    sections: sections, textEl: combined, status: .assembled)),
            warnings: warnings)
    }
}

enum ServiceSearch {
    static func search(_ service: SundayServicePackage.DivineLiturgyService,
                       query rawQuery: String) -> [ServiceSearchResult] {
        let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }
        var results: [ServiceSearchResult] = []
        for section in service.sections {
            for block in section.blocks {
                var searchStart = block.textEl.startIndex
                var ordinal = 0
                while searchStart < block.textEl.endIndex,
                      let range = block.textEl.range(of: query,
                        options: [.caseInsensitive, .diacriticInsensitive],
                        range: searchStart..<block.textEl.endIndex) {
                    let start = block.textEl.distance(from: block.textEl.startIndex, to: range.lowerBound)
                    let end = block.textEl.distance(from: block.textEl.startIndex, to: range.upperBound)
                    let snippetStart = block.textEl.index(range.lowerBound, offsetBy: -min(32, start))
                    let remaining = block.textEl.distance(from: range.upperBound, to: block.textEl.endIndex)
                    let snippetEnd = block.textEl.index(range.upperBound, offsetBy: min(48, remaining))
                    let snippet = block.textEl[snippetStart..<snippetEnd].replacingOccurrences(of: "\n", with: " ")
                    results.append(.init(
                        id: "\(section.id)-\(block.id)-\(start)-\(ordinal)",
                        sectionId: section.id, sectionTitleEl: section.titleEl,
                        blockId: block.id, speaker: block.speaker,
                        matchText: String(block.textEl[range]), snippet: String(snippet),
                        startOffset: start, endOffset: end
                    ))
                    ordinal += 1
                    searchStart = range.upperBound
                }
            }
        }
        return results
    }
}

enum LiturgicalFeatureWindow {
    static func shouldShowSundayLiturgy(at date: Date, calendar: Calendar = .current) -> Bool {
        guard calendar.component(.weekday, from: date) == 1 else { return false }
        let hour = calendar.component(.hour, from: date)
        return hour >= 5 && hour < 10
    }
}

#if DEBUG
private enum LiturgicalValidation {
    static func validate(_ repository: LiturgicalRepository) {
        let cases: [(String, String, BaseLiturgyKind, String)] = [
            ("2026-02-01", "publican_pharisee", .chrysostom, "18:10-14"),
            ("2026-03-01", "sunday_of_orthodoxy", .basil, "1:44-52"),
            ("2026-03-08", "gregory_palamas", .basil, "2:1-12"),
            ("2026-03-15", "veneration_of_cross", .basil, "8:34-9:1"),
            ("2026-03-22", "john_climacus", .basil, "9:17-31"),
            ("2026-03-29", "mary_of_egypt", .basil, "10:32-45"),
            ("2026-04-05", "palm_sunday", .chrysostom, "12:1-18"),
            ("2026-04-12", "pascha", .chrysostom, "1:1-17"),
            ("2026-05-31", "pentecost", .chrysostom, "7:37-52;8:12"),
            ("2026-06-07", "all_saints", .chrysostom, "10:32-33,37-38;19:27-30"),
            ("2026-06-28", "matthew_04", .chrysostom, "8:5-13")
        ]
        let configuration = LiturgicalConfiguration(timeZone: TimeZone(identifier: "UTC")!)
        for (rawDate, expectedID, expectedLiturgy, expectedRef) in cases {
            let date = parse(rawDate)
            let resolved = SundayResolver.resolve(date, repository: repository, configuration: configuration)
            assert(resolved?.id == expectedID, "Wrong Sunday for \(rawDate): \(resolved?.id ?? "nil")")
            assert(resolved.map { SundayResolver.liturgySelector($0, date: date) } == expectedLiturgy)
            assert(resolved?.divineLiturgyGospel.ref == expectedRef)
        }

        // 2026-07-05: the feast of St Athanasius the Athonite supplies the
        // Apostolos (Gal. 5:22–6:2), while the Fifth Sunday of Matthew Gospel
        // remains Matt. 8:28–9:1. The instant below is still July 4 in UTC but
        // already July 5 in Nicosia, guarding against timezone regressions.
        let nicosia = LiturgicalConfiguration(timeZone: TimeZone(identifier: "Asia/Nicosia")!)
        if let today = try? ServiceAssembler.assemble(
            parse("2026-07-04T22:30"), repository: repository, configuration: nicosia
        ) {
            assert(today.sunday.id == "matthew_05")
            assert(today.services.divineLiturgy.gospel.ref == "8:28-9:1")
            assert(today.services.divineLiturgy.echos == .fourth)
            assert(today.services.divineLiturgy.eothinon == 5)
            assert(today.services.divineLiturgy.textEl.contains("Γαλ. 5:22–6:2"))
            assert(!today.services.divineLiturgy.textEl.contains("Ρωμ. 10:1–10"))
        } else {
            assertionFailure("Failed to assemble the Nicosia service for 2026-07-05")
        }
        assert(repository.sundays.filter { $0.cycle == .pentecostLuke }
            .allSatisfy(\.needsYearlyCalendarVerification))
        assert(repository.yearlySundays.count == 52)
        assert(Set(repository.yearlySundays.map(\.date)).count == 52)

        if let package = try? ServiceAssembler.assemble(parse("2026-02-01"), repository: repository,
                                                        configuration: configuration) {
            assert(package.services.divineLiturgy.textEl.contains("Λουκ. 18:10–14"))
            assert(!package.services.divineLiturgy.textEl.contains("{{GOSPEL}}"))
            // {{APOSTLE}} is data-driven: filled when the Sunday carries a
            // "divine_liturgy_apostle" reading, otherwise kept as a chip.
            let service = package.services.divineLiturgy
            assert(!ServiceSearch.search(service, query: "ευαγγελιον").isEmpty)
            assert(!ServiceSearch.search(service, query: "18:10").isEmpty)
            assert(ServiceSearch.search(service, query: "   ").isEmpty)
        }

        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(identifier: "UTC")!
        assert(LiturgicalFeatureWindow.shouldShowSundayLiturgy(at: parse("2026-02-01T05:00"), calendar: calendar))
        assert(LiturgicalFeatureWindow.shouldShowSundayLiturgy(at: parse("2026-02-01T09:59"), calendar: calendar))
        assert(!LiturgicalFeatureWindow.shouldShowSundayLiturgy(at: parse("2026-02-01T10:00"), calendar: calendar))
        assert(!LiturgicalFeatureWindow.shouldShowSundayLiturgy(at: parse("2026-02-01T04:59"), calendar: calendar))
        assert(!LiturgicalFeatureWindow.shouldShowSundayLiturgy(at: parse("2026-02-02T07:00"), calendar: calendar))
    }

    private static func parse(_ value: String) -> Date {
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = value.contains("T") ? "yyyy-MM-dd'T'HH:mm" : "yyyy-MM-dd"
        return formatter.date(from: value)!
    }
}
#endif
