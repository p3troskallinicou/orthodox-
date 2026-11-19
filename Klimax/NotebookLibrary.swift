//
//  NotebookLibrary.swift
//  Klimax
//

import PhotosUI
import PencilKit
import SwiftUI
import UIKit

// MARK: - Embedded sources (independent of Today widgets)

extension NotebookAnchor {
    static func saintSaying(_ saying: SaintSaying, catalog: SaintSayingsCatalog) -> NotebookAnchor {
        NotebookAnchor(kind: .saintSayings, title: catalog.saint(for: saying).shortName,
                       excerpt: saying.text, routeValue: saying.id,
                       contextTitle: catalog.category(for: saying).title)
    }
}

/// A source keeps its own visual identity inside a notebook page.
struct NotebookSourcePreview: View {
    let anchor: NotebookAnchor
    var showsOpenHint = true

    private var saying: SaintSaying? {
        SaintSayingsCatalog.bundled?.sayings.first { $0.id == anchor.routeValue }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Label(anchor.kind.title, systemImage: anchor.kind.icon)
                    .font(.caption.weight(.semibold))
                Spacer(minLength: 4)
                if showsOpenHint && anchor.kind != .personal {
                    Image(systemName: "arrow.up.right").font(.caption.weight(.semibold))
                }
            }.foregroundStyle(anchor.kind.tint)

            if anchor.kind == .saintSayings, let saying, let catalog = SaintSayingsCatalog.bundled {
                HStack(alignment: .top, spacing: 14) {
                    NotebookSayingPortrait(photo: catalog.photo(for: saying))
                        .frame(width: 84, height: 116).clipShape(RoundedRectangle(cornerRadius: 12))
                    VStack(alignment: .leading, spacing: 8) {
                        Text(anchor.cleanExcerpt).font(.system(.body, design: .serif)).lineLimit(5)
                        Text(anchor.cleanTitle).font(.caption.weight(.semibold)).foregroundStyle(Paper.inkMute)
                    }
                }
                if let context = anchor.contextTitle {
                    Text(context).font(.caption).foregroundStyle(Paper.inkMute)
                }
            } else if anchor.kind == .didaches {
                HStack(alignment: .top, spacing: 14) {
                    Image(AthosAudioCoverLibrary.assetName(for: anchor.contextTitle ?? ""))
                        .resizable().scaledToFill().frame(width: 76, height: 76)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    VStack(alignment: .leading, spacing: 6) {
                        Text(anchor.cleanTitle).font(.headline).lineLimit(3)
                        if let context = anchor.contextTitle {
                            Text(context).font(.caption).foregroundStyle(Paper.inkMute).lineLimit(2)
                        }
                        if let start = anchor.startTime {
                            Label(clipLabel(start), systemImage: "waveform")
                                .font(.caption.weight(.medium)).monospacedDigit().foregroundStyle(anchor.kind.tint)
                        }
                    }
                }
                if !anchor.cleanExcerpt.isEmpty {
                    Text(anchor.cleanExcerpt).font(.subheadline).foregroundStyle(Paper.inkSoft).lineLimit(3)
                }
            } else {
                Text(anchor.cleanTitle)
                    .font(.system(.title3, design: .serif).weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                if !anchor.cleanExcerpt.isEmpty {
                    HStack(alignment: .top, spacing: 12) {
                        RoundedRectangle(cornerRadius: 2).fill(anchor.kind.tint.opacity(0.5)).frame(width: 3)
                        Text(anchor.cleanExcerpt).font(.system(.body, design: .serif))
                            .lineSpacing(4).foregroundStyle(Paper.inkSoft).lineLimit(5)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }.fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .foregroundStyle(Paper.ink)
        .frame(maxWidth: .infinity, alignment: .leading).padding(18)
        .background {
            RoundedRectangle(cornerRadius: 22).fill(Paper.card)
                .overlay {
                    LinearGradient(colors: [anchor.kind.tint.opacity(0.10), .clear],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                }.clipShape(RoundedRectangle(cornerRadius: 22))
        }
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(Paper.hairline, lineWidth: 0.5))
        .contentShape(RoundedRectangle(cornerRadius: 22))
    }

    private func clipLabel(_ start: TimeInterval) -> String {
        func time(_ value: TimeInterval) -> String {
            let seconds = max(0, Int(value))
            return String(format: "%d:%02d", seconds / 60, seconds % 60)
        }
        return anchor.endTime.map { "\(time(start)) – \(time($0))" } ?? time(start)
    }
}

private struct NotebookSayingPortrait: View {
    let photo: SayingPhoto
    var body: some View {
        GeometryReader { geometry in
            let rect = photo.immersiveImageRect(in: geometry.size)
            Image(photo.asset).resizable()
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)
        }.clipped().accessibilityHidden(true)
    }
}

struct NotebookEditableSource: View {
    let anchor: NotebookAnchor
    let remove: () -> Void
    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            NotebookAnchorCard(anchor: anchor)
            Button(role: .destructive, action: remove) {
                Label("Αφαίρεση πηγής", systemImage: "link.badge.minus")
                    .font(.caption).frame(minHeight: 36)
            }.buttonStyle(.plain).foregroundStyle(Paper.inkMute)
        }
    }
}

struct NotebookCategoryMenu: View {
    @Binding var selection: NotebookCategory?
    var body: some View {
        Menu {
            Button("Χωρίς κατηγορία") { selection = nil }
            ForEach(NotebookCategory.allCases) { category in
                Button { selection = category } label: {
                    Label(category.title, systemImage: selection == category ? "checkmark" : category.icon)
                }
            }
        } label: {
            HStack(spacing: 9) {
                Image(systemName: selection?.icon ?? "tag")
                Text(selection?.title ?? "Κατηγορία · προαιρετική")
                Spacer()
                Image(systemName: "chevron.up.chevron.down").font(.caption)
            }.font(.subheadline.weight(.medium)).foregroundStyle(selection?.tint ?? Paper.inkMute)
                .padding(15).modifier(YouCardSurface(cornerRadius: 16))
        }
    }
}

struct SaintSayingNotebookLink: View {
    let anchor: NotebookAnchor
    @State private var showingReader = false
    @State private var unavailable = false
    @AppStorage(SaintSayingFavorites.storageKey) private var favoritesData = Data()
    private var catalog: SaintSayingsCatalog? { .bundled }
    private var saying: SaintSaying? { catalog?.sayings.first { $0.id == anchor.routeValue } }
    private var favorites: Binding<Set<String>> {
        Binding(get: { SaintSayingFavorites.decode(favoritesData) },
                set: { favoritesData = SaintSayingFavorites.encode($0) })
    }
    var body: some View {
        Button {
            if saying != nil { showingReader = true } else { unavailable = true }
        } label: { NotebookSourcePreview(anchor: anchor) }
        .buttonStyle(.plain)
        .accessibilityHint("Ανοίγει τον συγκεκριμένο λόγο του Αγίου")
        .fullScreenCover(isPresented: $showingReader) {
            if let catalog, let saying {
                SaintSayingReader(catalog: catalog, sayings: catalog.collection(saintID: saying.saintID),
                                  initialID: saying.id, favoriteIDs: favorites)
                    .presentationBackground(.clear)
            }
        }
        .alert("Η πηγή δεν είναι διαθέσιμη", isPresented: $unavailable) {
            Button("Εντάξει", role: .cancel) {}
        } message: { Text("Το αποθηκευμένο απόσπασμα παραμένει στη σημείωσή σου.") }
    }
}

struct SaintSayingSourcePicker: View {
    let onAdd: (NotebookAnchor) -> Void
    @State private var query = ""
    @State private var saintID: String?
    var body: some View {
        if let catalog = SaintSayingsCatalog.bundled {
            VStack(alignment: .leading, spacing: 14) {
                NotebookSearchField(text: $query)
                Menu {
                    Button("Όλοι οι Άγιοι") { saintID = nil }
                    ForEach(catalog.saints) { saint in
                        Button(saint.shortName) { saintID = saint.id }
                    }
                } label: {
                    Label(catalog.saints.first { $0.id == saintID }?.shortName ?? "Όλοι οι Άγιοι",
                          systemImage: "line.3.horizontal.decrease")
                        .font(.subheadline.weight(.medium)).padding(.vertical, 8)
                }.tint(Gild.accentForeground)
                let results = catalog.collection(saintID: saintID, query: query)
                if results.isEmpty {
                    ContentUnavailableView.search(text: query)
                }
                LazyVStack(spacing: 12) {
                    ForEach(results) { saying in
                        let anchor = NotebookAnchor.saintSaying(saying, catalog: catalog)
                        Button { onAdd(anchor) } label: {
                            NotebookSourcePreview(anchor: anchor, showsOpenHint: false)
                        }.buttonStyle(.plain)
                            .accessibilityHint("Προσθήκη στη σημείωση")
                    }
                }
            }
        } else {
            ContentUnavailableView("Οι λόγοι δεν είναι διαθέσιμοι", systemImage: "quote.opening")
        }
    }
}

struct SaintSayingNoteButton: View {
    let saying: SaintSaying
    let catalog: SaintSayingsCatalog
    @State private var draft: NotebookSourceNoteDraft?
    var body: some View {
        Button {
            let anchor = NotebookAnchor.saintSaying(saying, catalog: catalog)
            draft = NotebookSourceNoteDraft(title: anchor.cleanTitle, category: .saintSayings, anchor: anchor)
        } label: {
            Image(systemName: "square.and.pencil").font(.system(size: 16, weight: .semibold))
                .frame(width: 44, height: 44).foregroundStyle(.white)
                .glassCircleFallback(shape: Circle())
        }.buttonStyle(.plain).accessibilityLabel("Σημείωση για αυτόν τον λόγο")
            .sheet(item: $draft) { NotebookSourceNoteSheet(draft: $0) }
    }
}

// MARK: - Library data

struct NotebookFolder: Codable, Hashable, Identifiable {
    var id = UUID()
    var name: String
    var parentID: UUID?
    var bookID: UUID?
    var createdAt = Date()
    var updatedAt = Date()
    var isFavorite: Bool? = nil
    var sortIndex: Double? = nil
    var category: NotebookCategory? = nil
}

struct NotebookBook: Codable, Hashable, Identifiable {
    var id = UUID()
    var title: String
    var author: String
    var coverFilename: String?
    var createdAt = Date()
    var updatedAt = Date()
    var isFavorite: Bool? = nil
    var sortIndex: Double? = nil
}

struct NotebookNotePlacement: Codable, Hashable, Identifiable {
    var noteID: UUID
    var folderID: UUID?
    var bookID: UUID?
    var pageReference: String?
    var isFavorite: Bool? = nil
    var sortIndex: Double? = nil

    var id: UUID { noteID }
}

struct NotebookPagePhoto: Codable, Hashable, Identifiable {
    var id = UUID()
    var noteID: UUID
    var imageFilename: String
    var drawingFilename: String?
    var caption: String
    var createdAt = Date()
}

private struct NotebookLibraryArchive: Codable {
    var folders: [NotebookFolder] = []
    var books: [NotebookBook] = []
    var placements: [NotebookNotePlacement] = []
    var photos: [NotebookPagePhoto] = []
}

@MainActor
final class NotebookLibraryStore: ObservableObject {
    static let shared = NotebookLibraryStore()

    @Published private(set) var folders: [NotebookFolder] = []
    @Published private(set) var books: [NotebookBook] = []
    @Published private(set) var placements: [NotebookNotePlacement] = []
    @Published private(set) var photos: [NotebookPagePhoto] = []

    private let rootURL: URL
    private let mediaURL: URL
    private let archiveURL: URL

    private init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        rootURL = support.appendingPathComponent("KlimaxNotebook", isDirectory: true)
        mediaURL = rootURL.appendingPathComponent("Media", isDirectory: true)
        archiveURL = rootURL.appendingPathComponent("library-v1.json")
        try? FileManager.default.createDirectory(at: mediaURL, withIntermediateDirectories: true)
        load()
    }

    func folders(parentID: UUID?, bookID: UUID?) -> [NotebookFolder] {
        folders
            .filter { $0.parentID == parentID && $0.bookID == bookID }
            .sorted(by: folderComesFirst)
    }

    var orderedBooks: [NotebookBook] {
        books.sorted {
            if ($0.isFavorite == true) != ($1.isFavorite == true) { return $0.isFavorite == true }
            if let left = $0.sortIndex, let right = $1.sortIndex, left != right { return left < right }
            if $0.sortIndex != nil && $1.sortIndex == nil { return true }
            if $0.sortIndex == nil && $1.sortIndex != nil { return false }
            return $0.updatedAt > $1.updatedAt
        }
    }

    func folder(id: UUID) -> NotebookFolder? { folders.first { $0.id == id } }
    func book(id: UUID) -> NotebookBook? { books.first { $0.id == id } }
    func placement(for noteID: UUID) -> NotebookNotePlacement? { placements.first { $0.noteID == noteID } }
    func photos(for noteID: UUID) -> [NotebookPagePhoto] {
        photos.filter { $0.noteID == noteID }.sorted { $0.createdAt < $1.createdAt }
    }

    func notes(in folderID: UUID) -> [NotebookNote] {
        let ids = Set(placements.filter { $0.folderID == folderID }.map(\.noteID))
        return sortedNotes(NotebookStore.shared.notes.filter { ids.contains($0.id) })
    }

    func notes(inBook bookID: UUID, folderID: UUID? = nil) -> [NotebookNote] {
        let ids = Set(placements.filter { $0.bookID == bookID && $0.folderID == folderID }.map(\.noteID))
        return sortedNotes(NotebookStore.shared.notes.filter { ids.contains($0.id) })
    }

    func unfiledNotes() -> [NotebookNote] {
        let filed = Set(placements.filter { $0.folderID != nil || $0.bookID != nil }.map(\.noteID))
        return sortedNotes(NotebookStore.shared.notes.filter { !filed.contains($0.id) })
    }

    func allNotes(in folderID: UUID) -> [NotebookNote] {
        let folderIDs = Set([folderID] + descendants(of: folderID))
        let ids = Set(placements.filter { placement in
            placement.folderID.map(folderIDs.contains) ?? false
        }.map(\.noteID))
        return NotebookStore.shared.notes.filter { ids.contains($0.id) }
    }

    func allNotes(inBook bookID: UUID) -> [NotebookNote] {
        let ids = Set(placements.filter { $0.bookID == bookID }.map(\.noteID))
        return NotebookStore.shared.notes.filter { ids.contains($0.id) }
    }

    func upsert(folder: NotebookFolder) {
        var value = folder
        value.name = value.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.name.isEmpty else { return }
        value.updatedAt = Date()
        if let index = folders.firstIndex(where: { $0.id == value.id }) { folders[index] = value }
        else { folders.append(value) }
        save()
    }

    func upsert(book: NotebookBook, cover: UIImage?) {
        var value = book
        value.title = value.title.trimmingCharacters(in: .whitespacesAndNewlines)
        value.author = value.author.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.title.isEmpty else { return }
        if let cover, let filename = writeJPEG(cover, prefix: "cover") {
            if let old = value.coverFilename { removeFile(old) }
            value.coverFilename = filename
        }
        value.updatedAt = Date()
        if let index = books.firstIndex(where: { $0.id == value.id }) { books[index] = value }
        else { books.append(value) }
        books.sort { $0.updatedAt > $1.updatedAt }
        save()
    }

    func place(noteID: UUID, folderID: UUID?, bookID: UUID?, pageReference: String?) {
        let cleanPage = pageReference?.trimmingCharacters(in: .whitespacesAndNewlines)
        let existing = placement(for: noteID)
        let value = NotebookNotePlacement(
            noteID: noteID,
            folderID: folderID,
            bookID: bookID,
            pageReference: cleanPage?.isEmpty == true ? nil : cleanPage,
            isFavorite: existing?.isFavorite,
            sortIndex: existing?.sortIndex
        )
        if let index = placements.firstIndex(where: { $0.noteID == noteID }) { placements[index] = value }
        else { placements.append(value) }
        save()
    }

    func move(noteID: UUID, folderID: UUID?, bookID: UUID?) {
        let pageReference = placement(for: noteID)?.pageReference
        place(noteID: noteID, folderID: folderID, bookID: bookID, pageReference: pageReference)
    }

    func toggleFavorite(folderID: UUID) {
        guard let index = folders.firstIndex(where: { $0.id == folderID }) else { return }
        folders[index].isFavorite = !(folders[index].isFavorite == true)
        save()
    }

    func toggleFavorite(noteID: UUID) {
        let index = ensurePlacement(for: noteID)
        placements[index].isFavorite = !(placements[index].isFavorite == true)
        save()
    }

    func reorderFolder(movingID: UUID, before targetID: UUID) {
        guard movingID != targetID,
              let moving = folder(id: movingID), let target = folder(id: targetID),
              moving.parentID == target.parentID, moving.bookID == target.bookID
        else { return }
        var ids = folders(parentID: target.parentID, bookID: target.bookID).map(\.id)
        guard let old = ids.firstIndex(of: movingID) else { return }
        ids.remove(at: old)
        guard let targetIndex = ids.firstIndex(of: targetID) else { return }
        ids.insert(movingID, at: targetIndex)
        assignFolderOrder(ids)
    }

    func moveFolder(_ folderID: UUID, by offset: Int) {
        guard let value = folder(id: folderID) else { return }
        var ids = folders(parentID: value.parentID, bookID: value.bookID).map(\.id)
        guard let old = ids.firstIndex(of: folderID) else { return }
        let next = min(max(old + offset, 0), ids.count - 1)
        guard next != old else { return }
        ids.swapAt(old, next)
        assignFolderOrder(ids)
    }

    func reorderNote(movingID: UUID, before targetID: UUID) {
        guard movingID != targetID else { return }
        let moving = placement(for: movingID)
        let target = placement(for: targetID)
        guard moving?.folderID == target?.folderID, moving?.bookID == target?.bookID else { return }
        var ids = siblingNotes(for: targetID).map(\.id)
        guard let old = ids.firstIndex(of: movingID) else { return }
        ids.remove(at: old)
        guard let targetIndex = ids.firstIndex(of: targetID) else { return }
        ids.insert(movingID, at: targetIndex)
        assignNoteOrder(ids)
    }

    func moveNote(_ noteID: UUID, by offset: Int) {
        var ids = siblingNotes(for: noteID).map(\.id)
        guard let old = ids.firstIndex(of: noteID) else { return }
        let next = min(max(old + offset, 0), ids.count - 1)
        guard next != old else { return }
        ids.swapAt(old, next)
        assignNoteOrder(ids)
    }

    @discardableResult
    func addPhoto(_ image: UIImage, to noteID: UUID) -> NotebookPagePhoto? {
        guard let filename = writeJPEG(image, prefix: "page") else { return nil }
        let photo = NotebookPagePhoto(noteID: noteID, imageFilename: filename, caption: "")
        photos.append(photo)
        save()
        return photo
    }

    func updateCaption(photoID: UUID, caption: String) {
        guard let index = photos.firstIndex(where: { $0.id == photoID }) else { return }
        photos[index].caption = caption
        save()
    }

    func saveDrawing(_ data: Data, for photoID: UUID) {
        guard let index = photos.firstIndex(where: { $0.id == photoID }) else { return }
        let filename = photos[index].drawingFilename ?? "drawing-\(photoID.uuidString).pkdrawing"
        do {
            try data.write(to: mediaURL.appendingPathComponent(filename), options: .atomic)
            photos[index].drawingFilename = filename
            save()
        } catch { }
    }

    func removePhoto(id: UUID) {
        guard let photo = photos.first(where: { $0.id == id }) else { return }
        removeFile(photo.imageFilename)
        if let drawingFilename = photo.drawingFilename { removeFile(drawingFilename) }
        photos.removeAll { $0.id == id }
        save()
    }

    func removeNoteData(noteID: UUID) {
        photos(for: noteID).forEach { photo in
            removeFile(photo.imageFilename)
            if let drawingFilename = photo.drawingFilename { removeFile(drawingFilename) }
        }
        photos.removeAll { $0.noteID == noteID }
        placements.removeAll { $0.noteID == noteID }
        save()
    }

    func delete(folderID: UUID) {
        let removedIDs = Set([folderID] + descendants(of: folderID))
        folders.removeAll { removedIDs.contains($0.id) }
        placements = placements.compactMap { placement in
            guard placement.folderID.map(removedIDs.contains) == true else { return placement }
            var updated = placement
            updated.folderID = nil
            return updated.bookID == nil ? nil : updated
        }
        save()
    }

    func delete(bookID: UUID) {
        guard let book = book(id: bookID) else { return }
        if let cover = book.coverFilename { removeFile(cover) }
        let bookFolderIDs = Set(folders.filter { $0.bookID == bookID }.map(\.id))
        folders.removeAll { $0.bookID == bookID }
        placements.removeAll { $0.bookID == bookID || $0.folderID.map(bookFolderIDs.contains) == true }
        books.removeAll { $0.id == bookID }
        save()
    }

    func image(filename: String?) -> UIImage? {
        guard let filename else { return nil }
        return UIImage(contentsOfFile: mediaURL.appendingPathComponent(filename).path)
    }

    func drawingData(filename: String?) -> Data? {
        guard let filename else { return nil }
        return try? Data(contentsOf: mediaURL.appendingPathComponent(filename))
    }

    private func descendants(of folderID: UUID) -> [UUID] {
        var result: [UUID] = []
        var queue = [folderID]
        while let parent = queue.first {
            queue.removeFirst()
            let children = folders.filter { $0.parentID == parent }.map(\.id)
            result.append(contentsOf: children)
            queue.append(contentsOf: children)
        }
        return result
    }

    private func folderComesFirst(_ left: NotebookFolder, _ right: NotebookFolder) -> Bool {
        if (left.isFavorite == true) != (right.isFavorite == true) { return left.isFavorite == true }
        if let lhs = left.sortIndex, let rhs = right.sortIndex, lhs != rhs { return lhs < rhs }
        if left.sortIndex != nil && right.sortIndex == nil { return true }
        if left.sortIndex == nil && right.sortIndex != nil { return false }
        return left.name.localizedCaseInsensitiveCompare(right.name) == .orderedAscending
    }

    private func sortedNotes(_ values: [NotebookNote]) -> [NotebookNote] {
        values.sorted { left, right in
            let lhs = placement(for: left.id)
            let rhs = placement(for: right.id)
            if (lhs?.isFavorite == true) != (rhs?.isFavorite == true) { return lhs?.isFavorite == true }
            if let leftOrder = lhs?.sortIndex, let rightOrder = rhs?.sortIndex, leftOrder != rightOrder { return leftOrder < rightOrder }
            if lhs?.sortIndex != nil && rhs?.sortIndex == nil { return true }
            if lhs?.sortIndex == nil && rhs?.sortIndex != nil { return false }
            return left.updatedAt > right.updatedAt
        }
    }

    private func siblingNotes(for noteID: UUID) -> [NotebookNote] {
        guard let value = placement(for: noteID) else { return unfiledNotes() }
        if let folderID = value.folderID { return notes(in: folderID) }
        if let bookID = value.bookID { return notes(inBook: bookID) }
        return unfiledNotes()
    }

    private func ensurePlacement(for noteID: UUID) -> Int {
        if let index = placements.firstIndex(where: { $0.noteID == noteID }) { return index }
        placements.append(NotebookNotePlacement(noteID: noteID, folderID: nil, bookID: nil, pageReference: nil))
        return placements.count - 1
    }

    func moveNotes(_ values: [NotebookNote], from offsets: IndexSet, to destination: Int) {
        var ids = values.map(\.id)
        ids.move(fromOffsets: offsets, toOffset: destination)
        assignNoteOrder(ids)
    }

    func moveFolders(_ values: [NotebookFolder], from offsets: IndexSet, to destination: Int) {
        var ids = values.map(\.id)
        ids.move(fromOffsets: offsets, toOffset: destination)
        assignFolderOrder(ids)
    }

    func moveBooks(_ values: [NotebookBook], from offsets: IndexSet, to destination: Int) {
        var ids = values.map(\.id)
        ids.move(fromOffsets: offsets, toOffset: destination)
        for (position, id) in ids.enumerated() {
            if let index = books.firstIndex(where: { $0.id == id }) { books[index].sortIndex = Double(position) }
        }
        save()
    }

    private func assignFolderOrder(_ ids: [UUID]) {
        for (position, id) in ids.enumerated() {
            if let index = folders.firstIndex(where: { $0.id == id }) { folders[index].sortIndex = Double(position) }
        }
        save()
    }

    private func assignNoteOrder(_ ids: [UUID]) {
        for (position, id) in ids.enumerated() {
            let index = ensurePlacement(for: id)
            placements[index].sortIndex = Double(position)
        }
        save()
    }

    private func writeJPEG(_ image: UIImage, prefix: String) -> String? {
        let normalized = image.normalizedForNotebook(maxDimension: 2400)
        guard let data = normalized.jpegData(compressionQuality: 0.84) else { return nil }
        let filename = "\(prefix)-\(UUID().uuidString).jpg"
        do {
            try data.write(to: mediaURL.appendingPathComponent(filename), options: .atomic)
            return filename
        } catch { return nil }
    }

    private func removeFile(_ filename: String) {
        try? FileManager.default.removeItem(at: mediaURL.appendingPathComponent(filename))
    }

    private func load() {
        guard let data = try? Data(contentsOf: archiveURL),
              let archive = try? JSONDecoder().decode(NotebookLibraryArchive.self, from: data)
        else { return }
        folders = archive.folders
        books = archive.books
        placements = archive.placements
        photos = archive.photos
    }

    private func save() {
        let archive = NotebookLibraryArchive(folders: folders, books: books, placements: placements, photos: photos)
        guard let data = try? JSONEncoder().encode(archive) else { return }
        try? data.write(to: archiveURL, options: .atomic)
    }
}

private extension UIImage {
    func normalizedForNotebook(maxDimension: CGFloat) -> UIImage {
        let longest = max(size.width, size.height)
        let scale = longest > maxDimension ? maxDimension / longest : 1
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: target)
        return renderer.image { _ in draw(in: CGRect(origin: .zero, size: target)) }
    }
}

// MARK: - Notes home

struct NotebookHomeView: View {
    @ObservedObject private var notes = NotebookStore.shared
    @ObservedObject private var library = NotebookLibraryStore.shared
    @State private var query = ""
    @State private var creation: NotebookCreation?
    @State private var editMode: EditMode = .inactive
    @State private var selectedCategory: NotebookCategory?

    private var rootFolders: [NotebookFolder] { library.folders(parentID: nil, bookID: nil) }
    private var visibleNotes: [NotebookNote] {
        guard !query.isEmpty else { return library.unfiledNotes() }
        return notes.notes.filter { note in
            ([note.title, note.body] + note.anchors.map { $0.cleanTitle + " " + $0.cleanExcerpt })
                .joined(separator: " ").localizedStandardContains(query)
        }.sorted { $0.updatedAt > $1.updatedAt }
    }

    var body: some View {
        List {
            VStack(alignment: .leading, spacing: 14) {
                Text("Σημειώσεις").font(.system(size: 30, weight: .semibold, design: .serif)).foregroundStyle(Paper.ink)
                Text("Οι σκέψεις, οι αναγνώσεις και οι σελίδες σου σε τάξη.")
                    .font(.subheadline).foregroundStyle(Paper.inkMute)
                NotebookSearchField(text: $query)
                Button { creation = .note(folderID: nil, bookID: nil) } label: {
                    HStack {
                        Label("Νέα σημείωση", systemImage: "square.and.pencil")
                        Spacer()
                        Image(systemName: "plus")
                    }.font(.subheadline.weight(.semibold)).foregroundStyle(Gild.accentForeground)
                        .padding(16).modifier(YouCardSurface(cornerRadius: 18))
                }.buttonStyle(.borderless)
            }.modifier(NotebookBrowserRow(isHeader: true))

            if query.isEmpty {
                Section {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(NotebookCategory.allCases) { category in
                            Button { selectedCategory = category } label: {
                                HStack(spacing: 9) {
                                    Image(systemName: category.icon).frame(width: 20)
                                    Text(category.title).font(.system(size: 13, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.8)
                                    Spacer(minLength: 0)
                                    Text("\(notes.count(in: category))").font(.caption.weight(.semibold))
                                }.foregroundStyle(category.tint).padding(12).frame(maxWidth: .infinity, minHeight: 56)
                                    .background(category.tint.opacity(0.07), in: RoundedRectangle(cornerRadius: 15))
                            }.buttonStyle(.plain)
                        }
                    }.modifier(NotebookBrowserRow(isHeader: true))
                } header: { sectionTitle("Κατηγορίες") }

                Section {
                    ForEach(rootFolders) { folder in
                        NotebookManagedFolderRow(folder: folder, count: library.allNotes(in: folder.id).count)
                    }.onMove { library.moveFolders(rootFolders, from: $0, to: $1) }
                    if rootFolders.isEmpty {
                        Button { creation = .folder(parentID: nil, bookID: nil) } label: {
                            NotebookEmptyRow(icon: "folder.badge.plus", text: "Δημιούργησε τον πρώτο σου φάκελο")
                        }.buttonStyle(.borderless).modifier(NotebookBrowserRow(isHeader: true))
                    }
                } header: {
                    HStack { sectionTitle("Φάκελοι"); Spacer(); Button("Νέος", systemImage: "plus") { creation = .folder(parentID: nil, bookID: nil) }.labelStyle(.iconOnly) }
                }

                Section {
                    if library.books.isEmpty {
                        Button { creation = .book } label: {
                            NotebookEmptyRow(icon: "books.vertical.fill", text: "Πρόσθεσε ένα βιβλίο και κράτησε τις δικές σου σημειώσεις")
                        }.buttonStyle(.borderless).modifier(NotebookBrowserRow(isHeader: true))
                    } else {
                        ForEach(library.orderedBooks) { book in NotebookManagedBookRow(book: book) }
                            .onMove { library.moveBooks(library.orderedBooks, from: $0, to: $1) }
                    }
                } header: {
                    HStack { sectionTitle("Βιβλιοθήκη ανάγνωσης"); Spacer(); Button("Βιβλίο", systemImage: "plus") { creation = .book }.labelStyle(.iconOnly) }
                }
            }

            Section {
                NotebookNotesCard(notes: visibleNotes, allowsReordering: query.isEmpty)
                if visibleNotes.isEmpty {
                    NotebookEmptyRow(icon: query.isEmpty ? "note.text" : "magnifyingglass",
                                     text: query.isEmpty ? "Οι σημειώσεις χωρίς φάκελο εμφανίζονται εδώ." : "Δεν βρέθηκαν σημειώσεις")
                        .modifier(NotebookBrowserRow(isHeader: true))
                }
            } header: { sectionTitle(query.isEmpty ? "Χωρίς φάκελο" : "Αποτελέσματα") }
        }
        .modifier(NotebookBrowserStyle())
        .environment(\.editMode, $editMode)
        .navigationDestination(item: $selectedCategory) { NotebookCategoryPages(category: $0) }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    withAnimation { editMode = editMode.isEditing ? .inactive : .active }
                } label: {
                    Image(systemName: editMode.isEditing ? "checkmark" : "arrow.up.arrow.down")
                }.accessibilityLabel(editMode.isEditing ? "Τέλος ταξινόμησης" : "Αλλαγή σειράς")

                Menu {
                    Button { creation = .note(folderID: nil, bookID: nil) } label: { Label("Νέα σημείωση", systemImage: "square.and.pencil") }
                    Button { creation = .folder(parentID: nil, bookID: nil) } label: { Label("Νέος φάκελος", systemImage: "folder.badge.plus") }
                    Button { creation = .book } label: { Label("Νέο βιβλίο", systemImage: "book.closed") }
                } label: { Image(systemName: "ellipsis").foregroundStyle(Paper.ink) }
                Button { creation = .note(folderID: nil, bookID: nil) } label: {
                    Label("Νέα σημείωση", systemImage: "square.and.pencil")
                }.tint(Gild.accentForeground)
            }
        }
        .sheet(item: $creation) { NotebookCreationSheet(creation: $0) }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title).font(.system(size: 19, weight: .semibold, design: .serif))
            .foregroundStyle(Paper.ink).textCase(nil)
    }
}

private struct NotebookCategoryPages: View {
    let category: NotebookCategory
    @ObservedObject private var notes = NotebookStore.shared
    @State private var query = ""
    @State private var creating = false
    var body: some View {
        List {
            NotebookSearchField(text: $query).modifier(NotebookBrowserRow(isHeader: true))
            let pages = notes.notes(in: category).filter {
                query.isEmpty || ([$0.title, $0.body] + $0.anchors.map(\.cleanExcerpt)).joined(separator: " ").localizedStandardContains(query)
            }
            NotebookNotesCard(notes: pages, allowsReordering: false)
            if pages.isEmpty {
                NotebookEmptyRow(icon: category.icon, text: "Δεν υπάρχουν σημειώσεις σε αυτή την κατηγορία ακόμη.")
                    .modifier(NotebookBrowserRow(isHeader: true))
            }
        }.modifier(NotebookBrowserStyle())
            .navigationTitle(category.title).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { creating = true } label: { Label("Νέα σημείωση", systemImage: "square.and.pencil") }
                }
            }
            .sheet(isPresented: $creating) {
                NotebookRichEditor(note: .blank(category: category), folderID: nil, bookID: nil)
            }
    }
}

private enum NotebookCreation: Identifiable {
    case note(folderID: UUID?, bookID: UUID?)
    case folder(parentID: UUID?, bookID: UUID?)
    case book

    var id: String {
        switch self {
        case let .note(folderID, bookID): "note-\(folderID?.uuidString ?? "root")-\(bookID?.uuidString ?? "none")"
        case let .folder(parentID, bookID): "folder-\(parentID?.uuidString ?? "root")-\(bookID?.uuidString ?? "none")"
        case .book: "book"
        }
    }
}

private struct NotebookCreationSheet: View {
    let creation: NotebookCreation
    var body: some View {
        switch creation {
        case let .note(folderID, bookID):
            NotebookRichEditor(note: .blank(), folderID: folderID, bookID: bookID)
        case let .folder(parentID, bookID):
            NotebookFolderEditor(parentID: parentID, bookID: bookID)
        case .book:
            NotebookBookEditor()
        }
    }
}

// MARK: - Folder and book screens

private struct NotebookFolderView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var notesStore = NotebookStore.shared
    @ObservedObject private var library = NotebookLibraryStore.shared
    let folderID: UUID
    @State private var query = ""
    @State private var creation: NotebookCreation?
    @State private var editMode: EditMode = .inactive
    @State private var confirmingDelete = false

    private var folder: NotebookFolder? { library.folder(id: folderID) }
    private var childFolders: [NotebookFolder] {
        guard let folder else { return [] }
        return library.folders(parentID: folderID, bookID: folder.bookID)
    }
    private var visibleNotes: [NotebookNote] {
        let values = library.notes(in: folderID)
        guard !query.isEmpty else { return values }
        return values.filter { "\($0.title) \($0.body)".localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        Group {
            if let folder {
                List {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(folder.name).font(.system(size: 30, weight: .semibold, design: .serif)).foregroundStyle(Paper.ink)
                        Text("\(library.allNotes(in: folderID).count) σημειώσεις")
                            .font(.subheadline).foregroundStyle(Paper.inkMute)
                        NotebookSearchField(text: $query)
                    }.modifier(NotebookBrowserRow(isHeader: true))
                    if query.isEmpty {
                        ForEach(childFolders) { child in
                            NotebookManagedFolderRow(folder: child, count: library.allNotes(in: child.id).count)
                        }.onMove { library.moveFolders(childFolders, from: $0, to: $1) }
                    }
                    NotebookNotesCard(notes: visibleNotes, allowsReordering: query.isEmpty)
                    if visibleNotes.isEmpty && childFolders.isEmpty {
                        NotebookEmptyRow(icon: "note.text.badge.plus", text: "Δεν υπάρχουν σημειώσεις εδώ ακόμη")
                            .modifier(NotebookBrowserRow(isHeader: true))
                    }
                }
                .modifier(NotebookBrowserStyle())
        .environment(\.editMode, $editMode)
                .navigationTitle(folder.bookID == nil ? "Φάκελος" : "Ενότητα βιβλίου")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    withAnimation { editMode = editMode.isEditing ? .inactive : .active }
                } label: {
                    Image(systemName: editMode.isEditing ? "checkmark" : "arrow.up.arrow.down")
                }.accessibilityLabel(editMode.isEditing ? "Τέλος ταξινόμησης" : "Αλλαγή σειράς")

                        Menu {
                            Button { creation = .note(folderID: folderID, bookID: folder.bookID) } label: { Label("Νέα σημείωση", systemImage: "square.and.pencil") }
                            Button { creation = .folder(parentID: folderID, bookID: folder.bookID) } label: { Label("Νέος υποφάκελος", systemImage: "folder.badge.plus") }
                            Divider()
                            Button(role: .destructive) { confirmingDelete = true } label: { Label("Διαγραφή φακέλου", systemImage: "trash") }
                        } label: { Image(systemName: "ellipsis.circle").foregroundStyle(Paper.gold) }
                        Button { creation = .note(folderID: folderID, bookID: folder.bookID) } label: { Image(systemName: "square.and.pencil").foregroundStyle(Paper.gold) }
                    }
                }
                .alert("Διαγραφή φακέλου;", isPresented: $confirmingDelete) {
                    Button("Άκυρο", role: .cancel) {}
                    Button("Διαγραφή", role: .destructive) { library.delete(folderID: folderID); dismiss() }
                } message: { Text("Οι σημειώσεις θα διατηρηθούν και θα μεταφερθούν στις σημειώσεις χωρίς φάκελο.") }
                .sheet(item: $creation) { NotebookCreationSheet(creation: $0) }
            } else { ContentUnavailableView("Ο φάκελος δεν υπάρχει", systemImage: "folder") }
        }
    }
}

private struct NotebookBookView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var library = NotebookLibraryStore.shared
    let bookID: UUID
    @State private var creation: NotebookCreation?
    @State private var editMode: EditMode = .inactive
    @State private var editingBook = false
    @State private var confirmingDelete = false

    private var book: NotebookBook? { library.book(id: bookID) }
    private var sections: [NotebookFolder] { library.folders(parentID: nil, bookID: bookID) }

    var body: some View {
        Group {
            if let book {
                List {
                    HStack(alignment: .top, spacing: 18) {
                        NotebookBookCover(book: book).frame(width: 84, height: 120)
                        VStack(alignment: .leading, spacing: 8) {
                            Text(book.title).font(.system(size: 26, weight: .semibold, design: .serif)).foregroundStyle(Paper.ink)
                            if !book.author.isEmpty { Text(book.author).font(.subheadline).foregroundStyle(Paper.inkMute) }
                            Text("\(library.allNotes(inBook: bookID).count) σημειώσεις").font(.caption).foregroundStyle(Paper.inkMute)
                        }
                    }.modifier(NotebookBrowserRow(isHeader: true))
                    ForEach(sections) { section in
                        NotebookManagedFolderRow(folder: section, count: library.allNotes(in: section.id).count)
                    }.onMove { library.moveFolders(sections, from: $0, to: $1) }
                    NotebookNotesCard(notes: library.notes(inBook: bookID))
                    if sections.isEmpty && library.notes(inBook: bookID).isEmpty {
                        NotebookEmptyRow(icon: "note.text", text: "Κράτησε την πρώτη σου σημείωση για αυτό το βιβλίο")
                            .modifier(NotebookBrowserRow(isHeader: true))
                    }
                }
                .modifier(NotebookBrowserStyle())
        .environment(\.editMode, $editMode)
                .navigationTitle("Βιβλίο")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    withAnimation { editMode = editMode.isEditing ? .inactive : .active }
                } label: {
                    Image(systemName: editMode.isEditing ? "checkmark" : "arrow.up.arrow.down")
                }.accessibilityLabel(editMode.isEditing ? "Τέλος ταξινόμησης" : "Αλλαγή σειράς")

                        Menu {
                            Button { creation = .note(folderID: nil, bookID: bookID) } label: { Label("Νέα σημείωση", systemImage: "square.and.pencil") }
                            Button { creation = .folder(parentID: nil, bookID: bookID) } label: { Label("Νέα ενότητα", systemImage: "folder.badge.plus") }
                            Button { editingBook = true } label: { Label("Επεξεργασία βιβλίου", systemImage: "pencil") }
                            Divider()
                            Button(role: .destructive) { confirmingDelete = true } label: { Label("Αφαίρεση βιβλίου", systemImage: "trash") }
                        } label: { Image(systemName: "ellipsis.circle").foregroundStyle(Paper.gold) }
                        Button { creation = .note(folderID: nil, bookID: bookID) } label: { Image(systemName: "square.and.pencil").foregroundStyle(Paper.gold) }
                    }
                }
                .sheet(item: $creation) { NotebookCreationSheet(creation: $0) }
                .sheet(isPresented: $editingBook) { NotebookBookEditor(book: book) }
                .alert("Αφαίρεση βιβλίου;", isPresented: $confirmingDelete) {
                    Button("Άκυρο", role: .cancel) {}
                    Button("Αφαίρεση", role: .destructive) { library.delete(bookID: bookID); dismiss() }
                } message: { Text("Το βιβλίο και η οργάνωσή του θα αφαιρεθούν. Οι σημειώσεις και οι φωτογραφίες τους θα διατηρηθούν στις σημειώσεις χωρίς φάκελο.") }
            } else { ContentUnavailableView("Το βιβλίο δεν υπάρχει", systemImage: "book.closed") }
        }
    }
}

// MARK: - Rich note editor and detail

private struct NotebookRichEditor: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var library = NotebookLibraryStore.shared
    @State private var draft: NotebookNote
    @State private var pageReference: String
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showingCamera = false
    @State private var showingAnchorComposer = false
    @State private var annotating: NotebookPagePhoto?
    @State private var committed = false
    private let folderID: UUID?
    private let bookID: UUID?
    private let originalPhotoIDs: Set<UUID>

    init(note: NotebookNote, folderID: UUID?, bookID: UUID?) {
        _draft = State(initialValue: note)
        _pageReference = State(initialValue: NotebookLibraryStore.shared.placement(for: note.id)?.pageReference ?? "")
        self.folderID = folderID
        self.bookID = bookID
        originalPhotoIDs = Set(NotebookLibraryStore.shared.photos(for: note.id).map(\.id))
    }

    private var pagePhotos: [NotebookPagePhoto] { library.photos(for: draft.id) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    NotebookFieldLabel("ΤΙΤΛΟΣ")
                    TextField("Τίτλος σημείωσης", text: $draft.title, axis: .vertical)
                        .font(.system(size: 28, weight: .semibold, design: .serif))
                        .padding(16).background(Paper.card.opacity(0.72), in: RoundedRectangle(cornerRadius: 18))

                    if bookID == nil {
                        NotebookCategoryMenu(selection: $draft.category)
                    }

                    if bookID != nil {
                        NotebookFieldLabel("ΣΕΛΙΔΑ Ή ΕΥΡΟΣ")
                        TextField("π.χ. 79 ή 79–82", text: $pageReference)
                            .font(.system(size: 16, weight: .semibold))
                            .padding(16).background(Paper.card.opacity(0.72), in: RoundedRectangle(cornerRadius: 18))
                    }

                    HStack {
                        NotebookFieldLabel("ΣΥΝΔΕΔΕΜΕΝΕΣ ΠΗΓΕΣ")
                        Spacer()
                        Button { showingAnchorComposer = true } label: {
                            Label("Πηγή", systemImage: "plus").font(.system(size: 13, weight: .bold))
                        }
                        .tint(Paper.gold)
                    }
                    if draft.anchors.isEmpty {
                        Button { showingAnchorComposer = true } label: {
                            Label("Σύνδεση πηγής (προαιρετικό)", systemImage: "link.badge.plus")
                                .font(.system(size: 14, weight: .semibold)).foregroundStyle(Paper.inkMute)
                                .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                                .background(Paper.card.opacity(0.55), in: RoundedRectangle(cornerRadius: 18))
                        }
                        .buttonStyle(.plain)
                    } else {
                        VStack(spacing: 9) {
                            ForEach(draft.anchors) { anchor in
                                NotebookEditableSource(anchor: anchor) {
                                    draft.anchors.removeAll { $0.id == anchor.id }
                                }
                            }
                        }
                    }

                    NotebookFieldLabel("ΣΗΜΕΙΩΣΗ")
                    TextEditor(text: $draft.body)
                        .font(.system(size: 18, design: .serif))
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 230)
                        .padding(12).background(Paper.card.opacity(0.72), in: RoundedRectangle(cornerRadius: 18))

                    HStack {
                        NotebookFieldLabel("ΦΩΤΟΓΡΑΦΙΕΣ ΣΕΛΙΔΩΝ")
                        Spacer()
                        Menu {
                            PhotosPicker(selection: $selectedPhoto, matching: .images) { Label("Από φωτογραφίες", systemImage: "photo") }
                            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                                Button { showingCamera = true } label: { Label("Λήψη φωτογραφίας", systemImage: "camera") }
                            }
                        } label: { Label("Προσθήκη", systemImage: "plus").font(.system(size: 13, weight: .bold)) }
                        .tint(Paper.gold)
                    }

                    if pagePhotos.isEmpty {
                        Text("Φωτογράφισε μόνο τις σελίδες που χρειάζεσαι για την προσωπική σου μελέτη. Μετά μπορείς να υπογραμμίσεις ή να γράψεις επάνω τους.")
                            .font(.system(size: 13, weight: .semibold)).foregroundStyle(Paper.inkMute)
                            .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                            .background(Paper.card.opacity(0.55), in: RoundedRectangle(cornerRadius: 18))
                    } else {
                        ForEach(pagePhotos) { photo in
                            NotebookPhotoEditorCard(photo: photo, annotate: { annotating = photo })
                        }
                    }
                }
                .padding(20).padding(.bottom, 30)
            }
            .background(AppAtmosphere().ignoresSafeArea())
            .navigationTitle("Σημείωση")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Άκυρο") { cancel() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Αποθήκευση") {
                        committed = true
                        var saved = draft
                        if bookID != nil { saved.category = nil }
                        NotebookStore.shared.upsert(saved)
                        library.place(noteID: draft.id, folderID: folderID, bookID: bookID, pageReference: pageReference)
                        dismiss()
                    }.fontWeight(.bold).disabled(draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && draft.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onChange(of: selectedPhoto) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                        library.addPhoto(image, to: draft.id)
                    }
                    selectedPhoto = nil
                }
            }
            .sheet(isPresented: $showingCamera) {
                NotebookCameraPicker { image in library.addPhoto(image, to: draft.id) }
                    .ignoresSafeArea()
            }
            .sheet(isPresented: $showingAnchorComposer) {
                AnchorComposerSheet { anchor in draft.anchors.append(anchor) }
                    .presentationDetents([.medium, .large])
            }
            .fullScreenCover(item: $annotating) { photo in NotebookAnnotationView(photo: photo) }
            .interactiveDismissDisabled()
        }
    }

    private func cancel() {
        if !committed && NotebookStore.shared.note(id: draft.id) == nil {
            for photo in pagePhotos where !originalPhotoIDs.contains(photo.id) { library.removePhoto(id: photo.id) }
        }
        dismiss()
    }
}

private struct NotebookRichNoteDetail: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var notes = NotebookStore.shared
    @ObservedObject private var library = NotebookLibraryStore.shared
    let noteID: UUID
    @State private var editing = false
    @State private var showingMove = false
    @State private var annotating: NotebookPagePhoto?
    @State private var confirmingDelete = false

    var body: some View {
        Group {
            if let note = notes.note(id: noteID) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text(note.title).font(.system(size: 30, weight: .semibold, design: .serif)).foregroundStyle(Paper.ink)
                        if library.placement(for: noteID)?.bookID == nil, let category = note.category {
                            Label(category.title, systemImage: category.icon)
                                .font(.system(size: 12, weight: .black)).foregroundStyle(category.tint)
                        }
                        HStack {
                            Text(note.updatedAt.formatted(date: .abbreviated, time: .shortened))
                            if let page = library.placement(for: noteID)?.pageReference { Label("Σελίδα \(page)", systemImage: "bookmark.fill") }
                        }.font(.system(size: 12, weight: .bold)).foregroundStyle(Paper.inkMute)
                        if !note.anchors.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                NotebookFieldLabel("ΣΥΝΔΕΔΕΜΕΝΕΣ ΠΗΓΕΣ")
                                ForEach(note.anchors) { NotebookAnchorCard(anchor: $0) }
                            }
                        }
                        if !note.body.isEmpty {
                            Text(note.body).font(.system(size: 18, design: .serif)).lineSpacing(6).foregroundStyle(Paper.ink)
                                .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 8)
                                .textSelection(.enabled)
                        }
                        ForEach(library.photos(for: noteID)) { photo in
                            VStack(alignment: .leading, spacing: 10) {
                                Button { annotating = photo } label: {
                                    NotebookAnnotatedPhoto(photo: photo)
                                        .clipShape(RoundedRectangle(cornerRadius: 20))
                                }.buttonStyle(.plain)
                                if !photo.caption.isEmpty { Text(photo.caption).font(.system(size: 15, weight: .semibold)).foregroundStyle(Paper.ink) }
                            }
                        }
                    }.padding(.horizontal, KSpace.gutter).padding(.top, KSpace.lg).padding(.bottom, 80)
                }
                .background(AppAtmosphere().ignoresSafeArea())
                .navigationTitle("Σημείωση").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Button(role: .destructive) { confirmingDelete = true } label: { Image(systemName: "trash") }
                        Button { showingMove = true } label: { Image(systemName: "folder").foregroundStyle(Paper.gold) }
                        Button { editing = true } label: { Image(systemName: "pencil").foregroundStyle(Paper.gold) }
                    }
                }
                .sheet(isPresented: $editing) {
                    let placement = library.placement(for: noteID)
                    NotebookRichEditor(note: note, folderID: placement?.folderID, bookID: placement?.bookID)
                }
                .fullScreenCover(item: $annotating) { NotebookAnnotationView(photo: $0) }
                .sheet(isPresented: $showingMove) { NotebookMoveNoteSheet(noteID: noteID) }
                .alert("Διαγραφή σημείωσης;", isPresented: $confirmingDelete) {
                    Button("Άκυρο", role: .cancel) {}
                    Button("Διαγραφή", role: .destructive) { library.removeNoteData(noteID: noteID); notes.delete(note); dismiss() }
                }
            } else { ContentUnavailableView("Η σημείωση δεν υπάρχει", systemImage: "note.text") }
        }
    }
}

private struct NotebookMoveNoteSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var library = NotebookLibraryStore.shared
    let noteID: UUID

    private var generalFolders: [(NotebookFolder, Int)] { flattenedFolders(parentID: nil, bookID: nil, depth: 0) }

    var body: some View {
        NavigationStack {
            List {
                Section("Σημειώσεις") {
                    destinationRow(title: "Χωρίς φάκελο", icon: "tray", folderID: nil, bookID: nil, depth: 0)
                }

                if !generalFolders.isEmpty {
                    Section("Φάκελοι") {
                        ForEach(generalFolders, id: \.0.id) { folder, depth in
                            destinationRow(title: folder.name, icon: "folder.fill", folderID: folder.id, bookID: nil, depth: depth)
                        }
                    }
                }

                ForEach(library.orderedBooks) { book in
                    Section(book.title) {
                        destinationRow(title: "Κύρια σελίδα βιβλίου", icon: "book.closed.fill", folderID: nil, bookID: book.id, depth: 0)
                        ForEach(flattenedFolders(parentID: nil, bookID: book.id, depth: 0), id: \.0.id) { folder, depth in
                            destinationRow(title: folder.name, icon: "folder.fill", folderID: folder.id, bookID: book.id, depth: depth)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppAtmosphere().ignoresSafeArea())
            .navigationTitle("Μετακίνηση σημείωσης")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Άκυρο") { dismiss() } } }
        }
    }

    @ViewBuilder
    private func destinationRow(title: String, icon: String, folderID: UUID?, bookID: UUID?, depth: Int) -> some View {
        let current = library.placement(for: noteID)
        Button {
            library.move(noteID: noteID, folderID: folderID, bookID: bookID)
            dismiss()
        } label: {
            HStack(spacing: 12) {
                Color.clear.frame(width: CGFloat(depth) * 16, height: 1)
                Image(systemName: icon).foregroundStyle(Paper.gold)
                Text(title).foregroundStyle(Paper.ink)
                Spacer()
                if current?.folderID == folderID && current?.bookID == bookID {
                    Image(systemName: "checkmark").fontWeight(.bold).foregroundStyle(Paper.gold)
                }
            }
        }
    }

    private func flattenedFolders(parentID: UUID?, bookID: UUID?, depth: Int) -> [(NotebookFolder, Int)] {
        library.folders(parentID: parentID, bookID: bookID).flatMap { folder in
            [(folder, depth)] + flattenedFolders(parentID: folder.id, bookID: bookID, depth: depth + 1)
        }
    }
}

// MARK: - Editors

private struct NotebookFolderEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var category: NotebookCategory?
    let parentID: UUID?
    let bookID: UUID?
    private let original: NotebookFolder?

    init(parentID: UUID?, bookID: UUID?) {
        self.parentID = parentID
        self.bookID = bookID
        original = nil
        _name = State(initialValue: "")
        _category = State(initialValue: nil)
    }

    init(folder: NotebookFolder) {
        parentID = folder.parentID
        bookID = folder.bookID
        original = folder
        _name = State(initialValue: folder.name)
        _category = State(initialValue: folder.category)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(original == nil ? (bookID == nil ? "Νέος φάκελος" : "Νέα ενότητα βιβλίου") : "Όνομα") {
                    TextField(bookID == nil ? "Όνομα φακέλου" : "π.χ. Κεφάλαιο 1 ή Σημαντικά χωρία", text: $name)
                }
                if bookID == nil {
                    Section("Κατηγορία · Προαιρετική") {
                        NotebookCategoryMenu(selection: $category)
                        .padding(.vertical, 4)
                    }
                }
            }
            .scrollContentBackground(.hidden).background(AppAtmosphere().ignoresSafeArea())
            .navigationTitle(original == nil ? (bookID == nil ? "Φάκελος" : "Ενότητα") : "Επεξεργασία")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Άκυρο") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(original == nil ? "Δημιουργία" : "Αποθήκευση") {
                        var value = original ?? NotebookFolder(name: name, parentID: parentID, bookID: bookID)
                        value.name = name
                        value.category = bookID == nil ? category : nil
                        NotebookLibraryStore.shared.upsert(folder: value)
                        dismiss()
                    }
                        .fontWeight(.bold).disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }.presentationDetents([.medium, .large])
    }
}

private struct NotebookBookEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: NotebookBook
    @State private var selectedCover: PhotosPickerItem?
    @State private var coverImage: UIImage?
    @State private var showingCamera = false

    init(book: NotebookBook? = nil) { _draft = State(initialValue: book ?? NotebookBook(title: "", author: "")) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 20).fill(Paper.card)
                        if let image = coverImage ?? NotebookLibraryStore.shared.image(filename: draft.coverFilename) {
                            Image(uiImage: image).resizable().scaledToFill()
                        } else {
                            VStack(spacing: 10) { Image(systemName: "book.closed.fill").font(.system(size: 40)); Text("Εξώφυλλο").fontWeight(.bold) }.foregroundStyle(Paper.gold)
                        }
                    }.frame(width: 150, height: 210).clipShape(RoundedRectangle(cornerRadius: 20))

                    Menu {
                        PhotosPicker(selection: $selectedCover, matching: .images) { Label("Από φωτογραφίες", systemImage: "photo") }
                        if UIImagePickerController.isSourceTypeAvailable(.camera) {
                            Button { showingCamera = true } label: { Label("Φωτογράφιση εξωφύλλου", systemImage: "camera") }
                        }
                    } label: { Label("Προσθήκη εξωφύλλου", systemImage: "camera.fill").font(.system(size: 15, weight: .bold)) }
                    .tint(Paper.gold)

                    VStack(alignment: .leading, spacing: 14) {
                        NotebookFieldLabel("ΒΙΒΛΙΟ")
                        TextField("Τίτλος", text: $draft.title).font(.system(size: 21, weight: .bold)).padding(15).background(Paper.card, in: RoundedRectangle(cornerRadius: 18))
                        TextField("Συγγραφέας (προαιρετικά)", text: $draft.author).padding(15).background(Paper.card, in: RoundedRectangle(cornerRadius: 18))
                    }
                }.padding(20)
            }.background(AppAtmosphere().ignoresSafeArea())
            .navigationTitle(draft.title.isEmpty ? "Νέο βιβλίο" : "Επεξεργασία")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Άκυρο") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Αποθήκευση") { NotebookLibraryStore.shared.upsert(book: draft, cover: coverImage); dismiss() }
                        .fontWeight(.bold).disabled(draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onChange(of: selectedCover) { _, item in
                Task { if let data = try? await item?.loadTransferable(type: Data.self) { coverImage = UIImage(data: data) } }
            }
            .sheet(isPresented: $showingCamera) { NotebookCameraPicker { coverImage = $0 }.ignoresSafeArea() }
        }
    }
}

// MARK: - Photos and annotation

private struct NotebookPhotoEditorCard: View {
    @ObservedObject private var library = NotebookLibraryStore.shared
    let photo: NotebookPagePhoto
    let annotate: () -> Void
    @State private var caption: String

    init(photo: NotebookPagePhoto, annotate: @escaping () -> Void) {
        self.photo = photo; self.annotate = annotate
        _caption = State(initialValue: photo.caption)
    }

    var body: some View {
        VStack(spacing: 12) {
            NotebookAnnotatedPhoto(photo: photo).frame(maxHeight: 360).clipShape(RoundedRectangle(cornerRadius: 18))
            HStack {
                Button(action: annotate) { Label("Επισήμανση", systemImage: "pencil.tip.crop.circle").font(.system(size: 13, weight: .bold)) }
                Spacer()
                Button(role: .destructive) { library.removePhoto(id: photo.id) } label: { Image(systemName: "trash") }
            }.tint(Paper.gold)
            TextField("Σχόλιο κάτω από τη φωτογραφία…", text: $caption, axis: .vertical)
                .font(.system(size: 15, weight: .semibold)).padding(13).background(Paper.bg.opacity(0.75), in: RoundedRectangle(cornerRadius: 14))
                .onChange(of: caption) { _, value in library.updateCaption(photoID: photo.id, caption: value) }
        }.padding(14).background(Paper.card.opacity(0.72), in: RoundedRectangle(cornerRadius: 22))
    }
}

private struct NotebookAnnotatedPhoto: View {
    @ObservedObject private var library = NotebookLibraryStore.shared
    let photo: NotebookPagePhoto

    var body: some View {
        if let image = library.image(filename: photo.imageFilename) {
            GeometryReader { proxy in
                let fitted = aspectFit(image.size, in: proxy.size)
                ZStack {
                    Color.black.opacity(0.06)
                    Image(uiImage: image).resizable().scaledToFit()
                    if let data = library.drawingData(filename: photo.drawingFilename), let drawing = try? PKDrawing(data: data) {
                        Image(uiImage: drawing.image(from: CGRect(origin: .zero, size: fitted), scale: UIScreen.main.scale))
                            .resizable().frame(width: fitted.width, height: fitted.height)
                    }
                }
            }.aspectRatio(image.size.width / max(image.size.height, 1), contentMode: .fit)
        } else { Color.secondary.opacity(0.15).overlay(Image(systemName: "photo")) }
    }

    private func aspectFit(_ source: CGSize, in bounds: CGSize) -> CGSize {
        let scale = min(bounds.width / max(source.width, 1), bounds.height / max(source.height, 1))
        return CGSize(width: source.width * scale, height: source.height * scale)
    }
}

private struct NotebookAnnotationView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var library = NotebookLibraryStore.shared
    let photo: NotebookPagePhoto
    @State private var drawingData: Data

    init(photo: NotebookPagePhoto) {
        self.photo = photo
        _drawingData = State(initialValue: NotebookLibraryStore.shared.drawingData(filename: photo.drawingFilename) ?? Data())
    }

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                if let image = library.image(filename: photo.imageFilename) {
                    let size = aspectFit(image.size, in: proxy.size)
                    ZStack {
                        Color.black.ignoresSafeArea()
                        Image(uiImage: image).resizable().scaledToFit().frame(width: size.width, height: size.height)
                        NotebookPencilCanvas(drawingData: $drawingData).frame(width: size.width, height: size.height)
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("Επισήμανση σελίδας").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Άκυρο") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Τέλος") { library.saveDrawing(drawingData, for: photo.id); dismiss() }.fontWeight(.bold) }
            }
        }
    }

    private func aspectFit(_ source: CGSize, in bounds: CGSize) -> CGSize {
        let usable = CGSize(width: bounds.width, height: max(bounds.height - 20, 1))
        let scale = min(usable.width / max(source.width, 1), usable.height / max(source.height, 1))
        return CGSize(width: source.width * scale, height: source.height * scale)
    }
}

private struct NotebookPencilCanvas: UIViewRepresentable {
    @Binding var drawingData: Data

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        var parent: NotebookPencilCanvas
        let toolPicker = PKToolPicker()
        init(parent: NotebookPencilCanvas) { self.parent = parent }
        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) { parent.drawingData = canvasView.drawing.dataRepresentation() }
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }
    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.delegate = context.coordinator
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.drawingPolicy = .anyInput
        if let drawing = try? PKDrawing(data: drawingData) { canvas.drawing = drawing }
        DispatchQueue.main.async {
            context.coordinator.toolPicker.setVisible(true, forFirstResponder: canvas)
            context.coordinator.toolPicker.addObserver(canvas)
            canvas.becomeFirstResponder()
        }
        return canvas
    }
    func updateUIView(_ uiView: PKCanvasView, context: Context) { context.coordinator.parent = self }
}

private struct NotebookCameraPicker: UIViewControllerRepresentable {
    let onImage: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss
    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController(); picker.sourceType = .camera; picker.delegate = context.coordinator; return picker
    }
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: NotebookCameraPicker
        init(parent: NotebookCameraPicker) { self.parent = parent }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage { parent.onImage(image) }
            parent.dismiss()
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { parent.dismiss() }
    }
}

// MARK: - Reusable notebook UI

private struct NotebookSearchField: View {
    @Binding var text: String
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(Paper.inkMute)
            TextField("Αναζήτηση", text: $text).textInputAutocapitalization(.never)
            if !text.isEmpty { Button { text = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(Paper.inkMute) } }
        }.font(.system(size: 15)).padding(.horizontal, 15).frame(height: 48)
            .modifier(YouCardSurface(cornerRadius: 16))
    }
}

private struct NotebookBrowserStyle: ViewModifier {
    func body(content: Content) -> some View {
        content.listStyle(.plain).scrollContentBackground(.hidden)
            .background(AppAtmosphere().ignoresSafeArea())
    }
}

private struct NotebookBrowserRow: ViewModifier {
    var isHeader = false
    func body(content: Content) -> some View {
        content.listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: isHeader ? 8 : 13, leading: KSpace.gutter, bottom: isHeader ? 12 : 13, trailing: KSpace.gutter))
            .listRowSeparator(isHeader ? .hidden : .visible)
            .listRowSeparatorTint(Paper.hairline)
            .alignmentGuide(.listRowSeparatorLeading) { _ in 56 }
    }
}

private struct NotebookManagedFolderRow: View {
    @ObservedObject private var library = NotebookLibraryStore.shared
    let folder: NotebookFolder
    let count: Int
    @State private var editingFolder = false

    var body: some View {
        NavigationLink { NotebookFolderView(folderID: folder.id) } label: {
            NotebookFolderRow(folder: folder, count: count)
        }
        .modifier(NotebookBrowserRow())
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) { library.delete(folderID: folder.id) } label: { Label("Διαγραφή", systemImage: "trash") }
            Button { editingFolder = true } label: { Label("Όνομα", systemImage: "pencil") }.tint(.gray)
        }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            Button { library.toggleFavorite(folderID: folder.id) } label: {
                Label(folder.isFavorite == true ? "Αφαίρεση αγαπημένου" : "Αγαπημένο", systemImage: folder.isFavorite == true ? "star.slash" : "star")
            }.tint(Gild.accentForeground)
        }
        .contextMenu {
            Button { editingFolder = true } label: { Label("Επεξεργασία", systemImage: "pencil") }
            Button { library.toggleFavorite(folderID: folder.id) } label: {
                Label(folder.isFavorite == true ? "Αφαίρεση από αγαπημένα" : "Αγαπημένο", systemImage: folder.isFavorite == true ? "star.slash" : "star")
            }
            Button { library.moveFolder(folder.id, by: -1) } label: { Label("Μετακίνηση επάνω", systemImage: "arrow.up") }
            Button { library.moveFolder(folder.id, by: 1) } label: { Label("Μετακίνηση κάτω", systemImage: "arrow.down") }
            Divider()
            Button(role: .destructive) { library.delete(folderID: folder.id) } label: { Label("Διαγραφή", systemImage: "trash") }
        }
        .accessibilityAction(named: "Αγαπημένο") { library.toggleFavorite(folderID: folder.id) }
        .accessibilityAction(named: "Μετακίνηση επάνω") { library.moveFolder(folder.id, by: -1) }
        .accessibilityAction(named: "Μετακίνηση κάτω") { library.moveFolder(folder.id, by: 1) }
        .sheet(isPresented: $editingFolder) { NotebookFolderEditor(folder: folder) }
    }
}

private struct NotebookFolderRow: View {
    let folder: NotebookFolder
    let count: Int
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "folder.fill").font(.system(size: 20)).foregroundStyle(folder.category?.tint ?? Gild.accentForeground)
                .frame(width: 42, height: 42)
                .background((folder.category?.tint ?? Paper.gold).opacity(0.08), in: RoundedRectangle(cornerRadius: 13))
            VStack(alignment: .leading, spacing: 3) {
                Text(folder.name).font(.system(size: 16, weight: .semibold)).foregroundStyle(Paper.ink).lineLimit(2)
                if let category = folder.category {
                    Label(category.title, systemImage: category.icon)
                        .font(.system(size: 10, weight: .bold)).foregroundStyle(category.tint)
                }
            }
            Spacer()
            if folder.isFavorite == true { Image(systemName: "star.fill").font(.system(size: 12, weight: .bold)).foregroundStyle(Paper.gold) }
            Text("\(count)").font(.system(size: 15, weight: .bold)).foregroundStyle(Paper.inkMute)
        }.frame(minHeight: 48).contentShape(Rectangle())
    }
}

private struct NotebookEmptyRow: View {
    let icon: String
    let text: String
    var body: some View {
        HStack(spacing: 13) { Image(systemName: icon).font(.system(size: 23)).foregroundStyle(Paper.gold); Text(text).font(.system(size: 15, weight: .semibold)).foregroundStyle(Paper.inkMute) }
            .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 20)
    }
}

private struct NotebookNotesCard: View {
    let notes: [NotebookNote]
    var allowsReordering = true
    @ObservedObject private var library = NotebookLibraryStore.shared
    var body: some View {
        ForEach(notes) { note in
            NotebookNoteRow(note: note, allowsReordering: allowsReordering)
        }.onMove { offsets, destination in
            guard allowsReordering else { return }
            library.moveNotes(notes, from: offsets, to: destination)
        }
    }
}

private struct NotebookNoteRow: View {
    let note: NotebookNote
    let allowsReordering: Bool
    @ObservedObject private var library = NotebookLibraryStore.shared
    var body: some View {
            NavigationLink { NotebookRichNoteDetail(noteID: note.id) } label: {
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: note.category?.icon ?? "note.text")
                        .font(.system(size: 20, weight: .regular)).foregroundStyle(note.category?.tint ?? Gild.accentForeground)
                        .frame(width: 42, height: 48)
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(note.title).font(.system(size: 17, weight: .semibold)).foregroundStyle(Paper.ink).lineLimit(2)
                            if library.placement(for: note.id)?.isFavorite == true {
                                Image(systemName: "star.fill").font(.caption2).foregroundStyle(Gild.accentForeground)
                            }
                        }
                        if !note.body.isEmpty {
                            Text(note.body).font(.subheadline).foregroundStyle(Paper.inkSoft).lineLimit(2)
                        }
                        if let anchor = note.anchors.first {
                            Label(anchor.cleanTitle, systemImage: anchor.kind.icon)
                                .font(.caption).foregroundStyle(anchor.kind.tint).lineLimit(1)
                        }
                        HStack(spacing: 8) {
                            Text(note.updatedAt.formatted(date: .abbreviated, time: .omitted))
                            if let page = library.placement(for: note.id)?.pageReference { Text("Σελίδα \(page)") }
                            if !library.photos(for: note.id).isEmpty { Label("\(library.photos(for: note.id).count)", systemImage: "photo") }
                        }.font(.caption).foregroundStyle(Paper.inkMute)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }.padding(.vertical, 2)
            }
            .modifier(NotebookBrowserRow())
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button(role: .destructive) { delete(note) } label: { Label("Διαγραφή", systemImage: "trash") }
            }
            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                Button { library.toggleFavorite(noteID: note.id) } label: {
                    Label(library.placement(for: note.id)?.isFavorite == true ? "Αφαίρεση αγαπημένου" : "Αγαπημένο",
                          systemImage: library.placement(for: note.id)?.isFavorite == true ? "star.slash" : "star")
                }.tint(Gild.accentForeground)
            }
            .moveDisabled(!allowsReordering)
            .contextMenu {
                Button { library.toggleFavorite(noteID: note.id) } label: { Label("Αγαπημένο", systemImage: "star") }
                if allowsReordering {
                    Button { library.moveNote(note.id, by: -1) } label: { Label("Μετακίνηση επάνω", systemImage: "arrow.up") }
                    Button { library.moveNote(note.id, by: 1) } label: { Label("Μετακίνηση κάτω", systemImage: "arrow.down") }
                }
                Button(role: .destructive) { delete(note) } label: { Label("Διαγραφή", systemImage: "trash") }
            }
    }
    private func delete(_ note: NotebookNote) {
        library.removeNoteData(noteID: note.id)
        NotebookStore.shared.delete(note)
    }
}

private struct NotebookManagedBookRow: View {
    @ObservedObject private var library = NotebookLibraryStore.shared
    let book: NotebookBook
    @State private var editing = false
    var body: some View {
        NavigationLink { NotebookBookView(bookID: book.id) } label: {
            HStack(spacing: 14) {
                NotebookBookCover(book: book).frame(width: 42, height: 56)
                VStack(alignment: .leading, spacing: 4) {
                    Text(book.title).font(.system(size: 17, weight: .semibold)).foregroundStyle(Paper.ink).lineLimit(2)
                    Text("\(library.allNotes(inBook: book.id).count) σημειώσεις").font(.subheadline).foregroundStyle(Paper.inkMute)
                }
                Spacer(minLength: 4)
                if book.isFavorite == true { Image(systemName: "star.fill").font(.caption2).foregroundStyle(Gild.accentForeground) }
            }
        }.modifier(NotebookBrowserRow())
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) { library.delete(bookID: book.id) } label: { Label("Αφαίρεση", systemImage: "trash") }
            Button { editing = true } label: { Label("Επεξεργασία", systemImage: "pencil") }.tint(.gray)
        }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            Button { toggleFavorite() } label: { Label("Αγαπημένο", systemImage: book.isFavorite == true ? "star.slash" : "star") }.tint(Gild.accentForeground)
        }
        .contextMenu {
            Button { editing = true } label: { Label("Επεξεργασία", systemImage: "pencil") }
            Button { toggleFavorite() } label: { Label("Αγαπημένο", systemImage: "star") }
        }
        .sheet(isPresented: $editing) { NotebookBookEditor(book: book) }
    }
    private func toggleFavorite() {
        var updated = book
        updated.isFavorite = book.isFavorite != true
        library.upsert(book: updated, cover: nil)
    }
}

private struct NotebookBookCover: View {
    @ObservedObject private var library = NotebookLibraryStore.shared
    let book: NotebookBook
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16).fill(LinearGradient(colors: [Paper.gold.opacity(0.82), Paper.gold.opacity(0.38)], startPoint: .topLeading, endPoint: .bottomTrailing))
            if let image = library.image(filename: book.coverFilename) { Image(uiImage: image).resizable().scaledToFill() }
            else { VStack(spacing: 8) { Image(systemName: "book.closed.fill").font(.system(size: 30)); Text(book.title).font(.system(size: 12, weight: .heavy, design: .serif)).multilineTextAlignment(.center).lineLimit(4).padding(8) }.foregroundStyle(.white) }
        }.clipShape(RoundedRectangle(cornerRadius: 16)).overlay(RoundedRectangle(cornerRadius: 16).stroke(Paper.hairline))
    }
}

private struct NotebookFieldLabel: View {
    let title: String
    init(_ title: String) { self.title = title }
    var body: some View { Text(title).font(.system(size: 11, weight: .semibold)).tracking(1.1).foregroundStyle(Paper.inkMute) }
}
