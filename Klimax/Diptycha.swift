import Foundation
import Observation

enum DiptychaCategory: String, Codable, CaseIterable, Identifiable {
    case zontes
    case astheneis
    case odoiporountes
    case kekoimimenoi

    var id: String { rawValue }
}

struct DiptychaEntry: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var category: DiptychaCategory
    var note: String?
    var prayerGrammar: PrayerNameGrammar?
    let createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        category: DiptychaCategory,
        note: String? = nil,
        prayerGrammar: PrayerNameGrammar? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.note = note
        self.prayerGrammar = prayerGrammar
        self.createdAt = createdAt
    }
}

@MainActor
@Observable
final class DiptychaStore {
    private(set) var entries: [DiptychaEntry] = []

    private let fileManager: FileManager
    private let storageURL: URL

    init(fileManager: FileManager = .default, storageURL: URL? = nil) {
        self.fileManager = fileManager
        self.storageURL = storageURL ?? Self.defaultStorageURL(fileManager: fileManager)
        load()
    }

    func entries(in category: DiptychaCategory) -> [DiptychaEntry] {
        entries.filter { $0.category == category }
    }

    func add(name: String, category: DiptychaCategory, note: String?, prayerGrammar: PrayerNameGrammar? = nil) {
        let cleanName = Self.cleanName(name)
        guard !cleanName.isEmpty else { return }
        entries.append(.init(name: cleanName, category: category, note: Self.cleanNote(note), prayerGrammar: prayerGrammar))
        save()
    }

    func update(_ entry: DiptychaEntry, name: String, category: DiptychaCategory, note: String?, prayerGrammar: PrayerNameGrammar? = nil) {
        guard let index = entries.firstIndex(where: { $0.id == entry.id }) else { return }
        let cleanName = Self.cleanName(name)
        guard !cleanName.isEmpty else { return }
        entries[index].name = cleanName
        entries[index].category = category
        entries[index].note = Self.cleanNote(note)
        entries[index].prayerGrammar = prayerGrammar
        save()
    }

    func delete(_ entry: DiptychaEntry) {
        entries.removeAll { $0.id == entry.id }
        save()
    }

    func move(_ movingID: UUID, before targetID: UUID, in category: DiptychaCategory) {
        guard movingID != targetID,
              let sourceIndex = entries.firstIndex(where: { $0.id == movingID && $0.category == category }),
              let targetIndex = entries.firstIndex(where: { $0.id == targetID && $0.category == category }) else {
            return
        }
        let entry = entries.remove(at: sourceIndex)
        let adjustedTarget = sourceIndex < targetIndex ? targetIndex - 1 : targetIndex
        entries.insert(entry, at: adjustedTarget)
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: storageURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        entries = (try? decoder.decode([DiptychaEntry].self, from: data)) ?? []
    }

    private func save() {
        do {
            try fileManager.createDirectory(
                at: storageURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(entries).write(to: storageURL, options: .atomic)
        } catch {
            assertionFailure("Diptycha could not be saved: \(error)")
        }
    }

    private static func defaultStorageURL(fileManager: FileManager) -> URL {
        let directory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Klimax", isDirectory: true)
        return directory.appendingPathComponent("diptycha.json")
    }

    private static func cleanName(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return String(trimmed.prefix(40))
    }

    private static func cleanNote(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else { return nil }
        return trimmed
    }
}
