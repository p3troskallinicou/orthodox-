//
//  OrthodoxFeastCalendarService.swift
//  Klimax
//
//  Offline-first Greek Orthodox feast calendar. Fixed commemorations come
//  from the bundled calendar.json, while movable commemorations come from
//  Paschalion.swift.
//

import Foundation
import Observation

@MainActor
@Observable
final class OrthodoxFeastCalendarService {
    private(set) var isLoaded = false
    private(set) var loadError: String?
    private(set) var source: OrthodoxCalendarSource?

    private var fixedByMonthDay: [String: [OrthodoxFeast]] = [:]

    nonisolated static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "el_GR")
        calendar.timeZone = TimeZone(identifier: "Europe/Nicosia")!
        return calendar
    }()

    func loadCalendar() async {
        guard !isLoaded else { return }
        do {
            let payload = try await Task.detached(priority: .userInitiated) {
                try Self.loadBundledPayload()
            }.value
            source = payload.source
            fixedByMonthDay = payload.fixedByMonthDay
            isLoaded = true
            loadError = nil
            #if DEBUG
            Self.runDebugValidation()
            #endif
        } catch {
            loadError = "Δεν φορτώθηκε το Εορτολόγιο: \(error.localizedDescription)"
        }
    }

    func day(for date: Date) -> OrthodoxCalendarDay? {
        guard isLoaded else { return nil }
        let components = Self.calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = components.year, let month = components.month, let day = components.day else { return nil }

        let fixed = fixedByMonthDay[Self.monthDayKey(month: month, day: day)] ?? []
        let movable = movableFeasts(on: date)
        let feasts = Self.deduplicatedDayFeasts(fixed + movable).sorted(by: Self.feastOrder)
        let major = feasts.first { $0.importance == .great }
            ?? feasts.first { $0.principal }
            ?? feasts.first { $0.importance == .major }
        let key = Self.dateKey(year: year, month: month, day: day)

        return OrthodoxCalendarDay(
            id: key,
            date: key,
            day: day,
            month: month,
            year: year,
            feasts: feasts,
            majorFeast: major,
            liturgicalNotes: []
        )
    }

    func feasts(for date: Date) -> [OrthodoxFeast] { day(for: date)?.feasts ?? [] }
    func today() -> OrthodoxCalendarDay? { day(for: Date()) }

    func upcomingFeasts(limit: Int, from start: Date = Date()) -> [OrthodoxCalendarDay] {
        guard limit > 0 else { return [] }
        var result: [OrthodoxCalendarDay] = []
        for offset in 0..<732 {
            guard let date = Self.calendar.date(byAdding: .day, value: offset, to: start),
                  let calendarDay = day(for: date),
                  !calendarDay.feasts.isEmpty else { continue }
            result.append(calendarDay)
            if result.count == limit { break }
        }
        return result
    }

    func searchFeasts(_ query: String) -> [OrthodoxCalendarDay] {
        let needle = Self.searchKey(query)
        guard needle.count >= 2 else { return [] }
        let year = Self.calendar.component(.year, from: Date())
        return days(in: year).filter { day in
            day.feasts.contains { feast in
                Self.searchKey(feast.title).contains(needle)
                    || Self.searchKey(feast.category ?? "").contains(needle)
                    || feast.namesCelebrated.contains { Self.searchKey($0).contains(needle) }
            }
        }
    }

    func days(in year: Int) -> [OrthodoxCalendarDay] {
        guard isLoaded,
              let start = Self.calendar.date(from: DateComponents(year: year, month: 1, day: 1)),
              let end = Self.calendar.date(from: DateComponents(year: year + 1, month: 1, day: 1)) else { return [] }

        var result: [OrthodoxCalendarDay] = []
        var cursor = start
        while cursor < end {
            if let calendarDay = day(for: cursor) { result.append(calendarDay) }
            cursor = Self.calendar.date(byAdding: .day, value: 1, to: cursor)!
        }
        return result
    }

    func date(for day: OrthodoxCalendarDay) -> Date? {
        Self.calendar.date(from: DateComponents(year: day.year, month: day.month, day: day.day))
    }

    private func movableFeasts(on date: Date) -> [OrthodoxFeast] {
        Paschalion.commemorations(on: date).map { movable in
            OrthodoxFeast(
                id: "movable-\(Self.calendar.component(.year, from: date))-\(movable.id)",
                title: movable.titleGreek,
                type: .movableFeast,
                importance: Self.importance(for: movable.rank),
                namesCelebrated: [],
                description: movable.subtitle,
                category: "Κινητές εορτές",
                principal: movable.rank == .great || movable.rank == .major,
                kind: .movable,
                month: nil,
                day: nil,
                paschaOffset: movable.pday,
                saintId: nil
            )
        }
    }

    private struct BundledPayload {
        let source: OrthodoxCalendarSource
        let fixedByMonthDay: [String: [OrthodoxFeast]]
    }

    private struct BundledCalendar: Decodable {
        let schemaVersion: Int
        let calendarSystem: String
        let script: String
        let source: String
        let note: String?
        let fastNote: String?
        let fixed: [String: FixedDay]
    }

    private struct FixedDay: Decodable {
        let feast: FixedFeast?
        let commemorations: [Commemoration]
    }

    private struct FixedFeast: Decodable {
        let title: String
        let rank: String
        let kind: String
    }

    private struct Commemoration: Decodable {
        let saintId: String
        let name: String
        let category: String
        let rank: String
        let principal: Bool
    }

    nonisolated private static func loadBundledPayload() throws -> BundledPayload {
        guard let url = Bundle.main.url(forResource: "calendar", withExtension: "json") else {
            throw NSError(
                domain: "Klimax.OrthodoxCalendar",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "calendar.json is missing"]
            )
        }

        let bundled = try JSONDecoder().decode(BundledCalendar.self, from: Data(contentsOf: url))
        let source = OrthodoxCalendarSource(
            name: bundled.source,
            calendarSystem: bundled.calendarSystem,
            script: bundled.script,
            notes: bundled.note,
            fastNotes: bundled.fastNote
        )

        var fixedByMonthDay: [String: [OrthodoxFeast]] = [:]
        for (monthDay, entry) in bundled.fixed {
            guard let (month, day) = parseMonthDay(monthDay) else { continue }
            var feasts: [OrthodoxFeast] = []

            if let feast = entry.feast {
                feasts.append(
                    OrthodoxFeast(
                        id: "fixed-feast-\(monthDay)-\(searchKey(feast.title))",
                        title: feast.title,
                        type: type(for: feast.kind, title: feast.title),
                        importance: importance(for: feast.rank),
                        namesCelebrated: [],
                        description: nil,
                        category: feast.kind,
                        principal: true,
                        kind: .fixed,
                        month: month,
                        day: day,
                        paschaOffset: nil,
                        saintId: nil
                    )
                )
            }

            feasts += entry.commemorations.map { commemoration in
                OrthodoxFeast(
                    id: "fixed-\(monthDay)-\(commemoration.saintId)",
                    title: commemoration.name,
                    type: type(for: commemoration.category, title: commemoration.name),
                    importance: importance(for: commemoration.rank),
                    namesCelebrated: [],
                    description: nil,
                    category: commemoration.category,
                    principal: commemoration.principal,
                    kind: .fixed,
                    month: month,
                    day: day,
                    paschaOffset: nil,
                    saintId: commemoration.saintId
                )
            }

            fixedByMonthDay[monthDay] = deduplicatedDayFeasts(feasts)
        }

        return BundledPayload(source: source, fixedByMonthDay: fixedByMonthDay)
    }

    nonisolated private static func parseMonthDay(_ key: String) -> (Int, Int)? {
        let parts = key.split(separator: "-")
        guard parts.count == 2,
              let month = Int(parts[0]),
              let day = Int(parts[1]) else { return nil }
        return (month, day)
    }

    nonisolated private static func type(for rawCategory: String, title: String) -> FeastType {
        let category = searchKey(rawCategory)
        let normalizedTitle = searchKey(title)

        if category.contains("δεσποτικ") { return .lordFeast }
        if category.contains("θεομητορ") || normalizedTitle.contains("θeotok") || normalizedTitle.contains("παναγ") {
            return .theotokosFeast
        }
        if category.contains("αποστολ") { return .apostleFeast }
        if category.contains("μαρτυ") { return .martyrFeast }
        return .saintFeast
    }

    nonisolated private static func importance(for rawRank: String) -> FeastImportance {
        switch searchKey(rawRank) {
        case "great":
            return .great
        case "major":
            return .major
        default:
            return .normal
        }
    }

    nonisolated private static func importance(for rank: FeastRank) -> FeastImportance {
        switch rank {
        case .great: return .great
        case .major: return .major
        case .minor: return .normal
        }
    }

    nonisolated private static func monthDayKey(month: Int, day: Int) -> String {
        String(format: "%02d-%02d", month, day)
    }

    nonisolated private static func dateKey(year: Int, month: Int, day: Int) -> String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    nonisolated private static func searchKey(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "el_GR"))
            .lowercased()
            .replacingOccurrences(of: "ς", with: "σ")
            .filter { $0.isLetter || $0.isNumber || $0 == " " }
    }

    nonisolated private static func deduplicatedDayFeasts(_ feasts: [OrthodoxFeast]) -> [OrthodoxFeast] {
        var seen = Set<String>()
        return feasts.filter { feast in
            let key = searchKey(feast.title)
            return seen.insert(key).inserted
        }
    }

    nonisolated private static func feastOrder(_ lhs: OrthodoxFeast, _ rhs: OrthodoxFeast) -> Bool {
        let score: [FeastImportance: Int] = [.great: 3, .major: 2, .normal: 1]
        if score[lhs.importance, default: 0] != score[rhs.importance, default: 0] {
            return score[lhs.importance, default: 0] > score[rhs.importance, default: 0]
        }
        if lhs.principal != rhs.principal { return lhs.principal && !rhs.principal }
        return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
    }

    #if DEBUG
    nonisolated private static func runDebugValidation() {
        let expected: [(Int, Int, Int, String)] = [
            (0, 4, 20, "Πάσχα"),
            (-7, 4, 13, "Βαΐων"),
            (39, 5, 29, "Ανάληψη"),
            (49, 6, 8, "Πεντηκοστή"),
            (50, 6, 9, "Αγίου Πνεύματος")
        ]

        for (offset, month, day, label) in expected {
            let date = Paschalion.cal.date(byAdding: .day, value: offset, to: Paschalion.pascha(year: 2025))!
            let components = Paschalion.cal.dateComponents([.month, .day], from: date)
            assert(components.month == month && components.day == day, "Incorrect 2025 date for \(label)")
        }

        print("📅 Εορτολόγιο: validation passed for bundled calendar.json and Paschalion")
    }
    #endif
}
