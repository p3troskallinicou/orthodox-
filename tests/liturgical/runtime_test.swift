import Foundation

// Compiled with the actual app resolver, assembler and Codable models.
@main struct LiturgicalRuntimeTest {
    static func main() throws {
        let repository = try LiturgicalRepository.load()
        let bible = try LiturgicalRepository.bundledBible()
        var configuration = LiturgicalConfiguration()
        configuration.timeZone = TimeZone(identifier: "Europe/Athens")!
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = configuration.timeZone
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        func date(_ key: String) -> Date { formatter.date(from: key + " 12:00")! }
        for row in repository.yearlySundays {
            let resolved = SundayResolver.resolve(date(row.date), repository: repository, configuration: configuration)
            if row.hasAvailableReadings {
                precondition(resolved != nil, "Missing available date \(row.date)")
                precondition(resolved!.divineLiturgyGospel == row.gospel)
                precondition(SundayResolver.apostle(for: date(row.date), sunday: resolved!, repository: repository, configuration: configuration) == row.apostle)
                precondition(ScripturePassageResolver.text(for: row.gospel, in: bible) != nil)
                precondition(ScripturePassageResolver.text(for: row.apostle, in: bible) != nil)
                let assembled = try ServiceAssembler.assemble(date(row.date), repository: repository, configuration: configuration, bible: bible)
                precondition(assembled != nil, "Assembly failed \(row.date)")
                precondition(assembled!.services.divineLiturgy.gospel == row.gospel)
                precondition(!assembled!.warnings.isEmpty)
            } else {
                precondition(resolved == nil, "Incomplete annual entry escaped gate \(row.date)")
                let assembled = try ServiceAssembler.assemble(date(row.date), repository: repository, configuration: configuration, bible: bible)
                precondition(assembled == nil)
            }
        }
        // Reading the remaining Sundays must not mark their sources checked.
        precondition(repository.yearlySundays.filter(\.hasCheckedGreekSundayReadings).count == 46)
        for key in ["2026-11-22", "2026-11-29", "2026-12-06", "2026-12-13", "2026-12-20", "2026-12-27"] {
            let row = repository.yearlySundays.first { $0.date == key }!
            precondition(row.hasAvailableReadings && !row.hasCheckedGreekSundayReadings)
            let package = try ServiceAssembler.assemble(date(key), repository: repository, configuration: configuration, bible: bible)!
            precondition(package.warnings.contains { $0.contains("Εκκρεμεί εσωτερικός έλεγχος") })
        }
        // Dates beyond the bundled annual file retain the existing calendar
        // behavior without being marked as annually checked.
        for key in ["2027-01-01", "2027-01-03", "2027-05-02", "2028-01-02"] {
            let resolved = SundayResolver.resolve(date(key), repository: repository, configuration: configuration)
            precondition(resolved != nil, "Calendar blocked after 2026: \(key)")
            precondition(SundayResolver.yearlyEntry(for: date(key), repository: repository, configuration: configuration) == nil)
            let assembled = try ServiceAssembler.assemble(date(key), repository: repository, configuration: configuration, bible: bible)
            precondition(assembled != nil, "Calendar assembly failed: \(key)")
            precondition(assembled!.warnings.contains { $0.contains("Εκκρεμεί εσωτερικός έλεγχος") })
        }
        for year in [2027, 2028] {
            let first = LiturgicalDateForTest.firstSunday(year, calendar: formatter.calendar!, timeZone: configuration.timeZone)
            var day = first
            while formatter.calendar.component(.year, from: day) == year {
                precondition(SundayResolver.resolve(day, repository: repository, configuration: configuration) != nil,
                             "Calendar Sunday blocked: \(formatter.string(from: day))")
                let package = try ServiceAssembler.assemble(day, repository: repository, configuration: configuration, bible: bible)
                precondition(package != nil, "Sunday service blocked: \(formatter.string(from: day))")
                precondition(package!.warnings.contains { $0.contains("Εκκρεμεί εσωτερικός έλεγχος") })
                day = formatter.calendar.date(byAdding: .day, value: 7, to: day)!
            }
        }
        let corrections: [(String, String, String)] = [
            ("2026-08-23", "10:38-42,11:27-28", "2:5-11"),
            ("2026-09-06", "22:2-14", "1:21-2:4"),
            ("2026-10-04", "6:31-36", "9:6-11")
        ]
        for (key, gospel, apostle) in corrections {
            let row = SundayResolver.yearlyEntry(for: date(key), repository: repository, configuration: configuration)!
            precondition(row.gospel.ref == gospel && row.apostle.ref == apostle)
            precondition(SundayResolver.resolve(date(key), repository: repository, configuration: configuration)?.titleEl == row.liturgicalOccasion)
        }
        let pascha = SundayResolver.resolve(date("2026-04-12"), repository: repository, configuration: configuration)!
        precondition(pascha.id == "pascha")
        precondition(SundayResolver.echos(for: date("2026-04-12"), sunday: pascha, repository: repository, configuration: configuration) == nil)
        let john = GospelRef(book: .John, ref: "1:44-52", displayEl: "", textEl: nil, textSource: nil)
        let text = ScripturePassageResolver.text(for: john, in: bible)!
        precondition(text.hasPrefix("44  ") && text.contains("\n52  ") && text.split(separator: "\n").count == 9)
        let july = repository.apostleDateOverrides.first { $0.dateNewCalendar == "07-15" }!
        precondition(july.apostle.ref == "13:11-13,14:1-5")
        precondition(ScripturePassageResolver.text(for: july.apostle, in: bible) != nil)
        for kind in [BaseLiturgyKind.chrysostom, .basil, .presanctified] {
            let base = try repository.baseLiturgy(kind)
            precondition(base.sourceStatus == "transcription_requires_liturgical_review")
            precondition(!base.sections.isEmpty)
        }
        struct Reading: Decodable { let kind: String; let book: String; let ref: String }
        let inputs = try JSONDecoder().decode([Reading].self, from: Data(contentsOf: Bundle.main.url(forResource: "readings_test_input", withExtension: "json")!))
        for input in inputs {
            let result: String?
            if input.kind == "gospel" {
                result = ScripturePassageResolver.text(for: GospelRef(book: GospelBook(rawValue: input.book)!, ref: input.ref, displayEl: "", textEl: nil, textSource: nil), in: bible)
            } else {
                result = ScripturePassageResolver.text(forBookID: input.book, ref: input.ref, in: bible)
            }
            precondition(result?.isEmpty == false, "Unresolved \(input.book) \(input.ref)")
        }
        print("PASS: actual app runtime; 52 annual Sunday assemblies, \(inputs.count) passages, feast precedence, all Sundays 2027/2028 readable with pending internal review, three liturgies")
    }
}

private enum LiturgicalDateForTest {
    static func firstSunday(_ year: Int, calendar: Calendar, timeZone: TimeZone) -> Date {
        var c = calendar
        c.timeZone = timeZone
        let first = c.date(from: DateComponents(year: year, month: 1, day: 1, hour: 12))!
        return c.component(.weekday, from: first) == 1 ? first : c.nextDate(after: first, matching: DateComponents(hour: 12, weekday: 1), matchingPolicy: .nextTime)!
    }
}
