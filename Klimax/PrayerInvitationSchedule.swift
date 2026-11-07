import Foundation

enum PrayerInvitationKind: String, Codable, CaseIterable {
    case morning, evening

    var prayerID: String { self == .morning ? "prooimiaki" : "mikron-apodeipnon" }
    var title: String { self == .morning ? "Πρωινή προσευχή" : "Μικρό Απόδειπνο" }
    var coverTitle: String { self == .morning ? "Πρωινή\nπροσευχή" : "Μικρό\nΑπόδειπνο" }
    var subtitle: String {
        self == .morning ? "Ξεκίνα τη μέρα με μια στιγμή προσευχής." : "Κλείσε τη μέρα με μια στιγμή γαλήνης."
    }

    static func current(at date: Date, calendar: Calendar = .current) -> Self? {
        switch calendar.component(.hour, from: date) {
        case 0..<12: .morning
        case 19..<24: .evening
        default: nil
        }
    }

    func imageName(at date: Date, calendar: Calendar = .current) -> String {
        let day = calendar.ordinality(of: .day, in: .era, for: date) ?? 1
        return "Prayer\(self == .morning ? "Morning" : "Evening")\(day % (self == .morning ? 10 : 8) + 1)"
    }
}

/// Only two records are retained. Showing (not completing) consumes a window;
/// explicit snoozes are the only exception. Local calendar dates handle DST.
struct PrayerInvitationSchedule {
    private struct Record: Codable {
        var day: String
        var reminder: Date?
    }
    private let defaults: UserDefaults
    private let key = "klimax.prayer.invitation.v1"

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    private var records: [String: Record] {
        guard let data = defaults.data(forKey: key),
              let value = try? JSONDecoder().decode([String: Record].self, from: data) else { return [:] }
        return value
    }

    private func dayKey(_ date: Date, _ calendar: Calendar) -> String {
        let c = calendar.dateComponents([.era, .year, .month, .day], from: date)
        return "\(c.era ?? 0)-\(c.year ?? 0)-\(c.month ?? 0)-\(c.day ?? 0)"
    }

    func pending(at date: Date, calendar: Calendar = .current, allowFirstPresentation: Bool = true) -> PrayerInvitationKind? {
        // An explicitly requested reminder may fall outside the normal hours.
        if let reminder = activeReminders(at: date).first, reminder.date <= date { return reminder.kind }
        guard let kind = PrayerInvitationKind.current(at: date, calendar: calendar) else { return nil }
        if activeReminders(at: date).contains(where: { $0.kind == kind }) { return nil }
        guard let record = records[kind.rawValue], record.day == dayKey(date, calendar) else {
            return allowFirstPresentation ? kind : nil
        }
        return nil
    }

    func markPresented(_ kind: PrayerInvitationKind, at date: Date, calendar: Calendar = .current) {
        var saved = records
        saved[kind.rawValue] = Record(day: dayKey(date, calendar), reminder: nil)
        persist(saved)
    }

    @discardableResult
    func snooze(_ kind: PrayerInvitationKind, minutes: Int, at date: Date, calendar: Calendar = .current) -> Bool {
        snooze(kind, until: date.addingTimeInterval(Double(minutes) * 60), at: date, calendar: calendar)
    }

    @discardableResult
    func snooze(_ kind: PrayerInvitationKind, until reminder: Date, at date: Date, calendar: Calendar = .current) -> Bool {
        guard reminder > date, reminder.timeIntervalSince(date) <= 24 * 60 * 60 else { return false }
        var saved = records
        saved[kind.rawValue] = Record(day: dayKey(date, calendar), reminder: reminder)
        persist(saved)
        return true
    }

    func nextReminder(at date: Date, calendar: Calendar = .current) -> Date? {
        activeReminders(at: date).first?.date
    }

    private func activeReminders(at date: Date) -> [(kind: PrayerInvitationKind, date: Date)] {
        records.compactMap { key, record in
            guard let kind = PrayerInvitationKind(rawValue: key), let reminder = record.reminder,
                  date.timeIntervalSince(reminder) < 24 * 60 * 60 else { return nil }
            return (kind: kind, date: reminder)
        }.sorted { $0.date < $1.date }
    }

    private func persist(_ records: [String: Record]) {
        if let data = try? JSONEncoder().encode(records) { defaults.set(data, forKey: key) }
    }
}
