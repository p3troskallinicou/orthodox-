//
//  NotebookLibrary.swift
//  Klimax
//

import PhotosUI
import PencilKit
import SwiftUI
import UIKit

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

    private var rootFolders: [NotebookFolder] { library.folders(parentID: nil, bookID: nil) }
    private var unfiled: [NotebookNote] {
        guard !query.isEmpty else { return library.unfiledNotes() }
        let key = query.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        return notes.notes
            .filter { "\($0.title) \($0.body)".folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current).contains(key) }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("Σημειώσεις")
                        .font(.system(size: 30, weight: .semibold, design: .serif))
                        .foregroundStyle(Paper.ink)
                    Text("Οι σκέψεις, οι αναγνώσεις και οι σελίδες σου σε τάξη.")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Paper.inkMute)
                }

                NotebookSearchField(text: $query)
                if query.isEmpty {
                    Button { creation = .note(folderID: nil, bookID: nil) } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "square.and.pencil").font(.system(size: 20))
                            Text("Νέα σημείωση").font(.system(size: 15, weight: .semibold))
                            Spacer(minLength: 0)
                            Image(systemName: "plus").font(.system(size: 12, weight: .semibold))
                        }.foregroundStyle(Gild.accentForeground).padding(17)
                            .frame(maxWidth: .infinity, minHeight: 54)
                            .modifier(YouCardSurface(cornerRadius: 18))
                    }.buttonStyle(.plain)
                }

                if query.isEmpty {
                    NotebookSectionHeader(title: "Φάκελοι", actionTitle: "Νέος") {
                        creation = .folder(parentID: nil, bookID: nil)
                    }
                    NotebookListCard {
                        if rootFolders.isEmpty {
                            NotebookEmptyRow(icon: "folder.badge.plus", text: "Δημιούργησε τον πρώτο σου φάκελο")
                        } else {
                            ForEach(Array(rootFolders.enumerated()), id: \.element.id) { index, folder in
                                NotebookManagedFolderRow(folder: folder, count: library.allNotes(in: folder.id).count)
                                if index < rootFolders.count - 1 { Divider().overlay(Paper.hairline) }
                            }
                        }
                    }

                    NotebookSectionHeader(title: "Βιβλιοθήκη ανάγνωσης", actionTitle: "Βιβλίο") {
                        creation = .book
                    }
                    if library.books.isEmpty {
                        NotebookListCard {
                            NotebookEmptyRow(icon: "books.vertical.fill", text: "Πρόσθεσε ένα βιβλίο και κράτησε τις δικές σου σημειώσεις")
                        }
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 14) {
                                ForEach(library.orderedBooks) { book in
                                    NavigationLink { NotebookBookView(bookID: book.id) } label: {
                                        NotebookBookTile(book: book, count: library.allNotes(inBook: book.id).count)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }

                NotebookSectionHeader(title: query.isEmpty ? "Χωρίς φάκελο" : "Αποτελέσματα", actionTitle: nil, action: nil)
                if unfiled.isEmpty {
                    NotebookListCard {
                        NotebookEmptyRow(icon: query.isEmpty ? "note.text" : "magnifyingglass", text: query.isEmpty ? (notes.notes.isEmpty ? "Οι πρώτες σου σκέψεις ξεκινούν με μια νέα σημείωση." : "Όλες οι σημειώσεις σου έχουν οργανωθεί") : "Δεν βρέθηκαν σημειώσεις")
                    }
                } else {
                    NotebookNotesCard(notes: unfiled)
                }
            }
            .padding(.horizontal, KSpace.gutter)
            .padding(.top, KSpace.lg)
            .padding(.bottom, KSpace.xxl)
        }
        .background(AppAtmosphere().ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { creation = .note(folderID: nil, bookID: nil) } label: { Label("Νέα σημείωση", systemImage: "square.and.pencil") }
                    Button { creation = .folder(parentID: nil, bookID: nil) } label: { Label("Νέος φάκελος", systemImage: "folder.badge.plus") }
                    Button { creation = .book } label: { Label("Νέο βιβλίο", systemImage: "book.closed") }
                } label: {
                    Image(systemName: "plus").font(.system(size: 18, weight: .semibold)).foregroundStyle(Paper.ink)
                }
            }
        }
        .sheet(item: $creation) { item in NotebookCreationSheet(creation: item) }
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
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 22) {
                        Text(folder.name).font(.system(size: 30, weight: .semibold, design: .serif)).foregroundStyle(Paper.ink)
                        if let category = folder.category {
                            Label(category.title, systemImage: category.icon)
                                .font(.system(size: 12, weight: .black)).foregroundStyle(category.tint)
                        }
                        Text("\(library.allNotes(in: folderID).count) σημειώσεις")
                            .font(.system(size: 14, weight: .bold)).foregroundStyle(Paper.inkMute)
                        NotebookSearchField(text: $query)

                        if !childFolders.isEmpty && query.isEmpty {
                            NotebookListCard {
                                ForEach(Array(childFolders.enumerated()), id: \.element.id) { index, child in
                                    NotebookManagedFolderRow(folder: child, count: library.allNotes(in: child.id).count)
                                    if index < childFolders.count - 1 { Divider().overlay(Paper.hairline) }
                                }
                            }
                        }
                        if visibleNotes.isEmpty {
                            NotebookListCard { NotebookEmptyRow(icon: "note.text.badge.plus", text: "Δεν υπάρχουν σημειώσεις εδώ ακόμη") }
                        } else { NotebookNotesCard(notes: visibleNotes) }
                    }
                    .padding(.horizontal, KSpace.gutter).padding(.top, KSpace.lg).padding(.bottom, 100)
                }
                .background(AppAtmosphere().ignoresSafeArea())
                .navigationTitle(folder.bookID == nil ? "Φάκελος" : "Ενότητα βιβλίου")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItemGroup(placement: .topBarTrailing) {
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
    @State private var editingBook = false
    @State private var confirmingDelete = false

    private var book: NotebookBook? { library.book(id: bookID) }
    private var sections: [NotebookFolder] { library.folders(parentID: nil, bookID: bookID) }

    var body: some View {
        Group {
            if let book {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 24) {
                        HStack(alignment: .top, spacing: 18) {
                            NotebookBookCover(book: book).frame(width: 116, height: 166)
                            VStack(alignment: .leading, spacing: 8) {
                                Text(book.title).font(.system(size: 26, weight: .semibold, design: .serif)).foregroundStyle(Paper.ink)
                                if !book.author.isEmpty { Text(book.author).font(.system(size: 16, weight: .bold)).foregroundStyle(Paper.inkMute) }
                                Spacer()
                                Text("\(library.allNotes(inBook: bookID).count) σημειώσεις")
                                    .font(.system(size: 13, weight: .black)).foregroundStyle(Paper.gold)
                            }
                        }.frame(minHeight: 166)

                        NotebookSectionHeader(title: "Ενότητες & σελίδες", actionTitle: "Νέα") {
                            creation = .folder(parentID: nil, bookID: bookID)
                        }
                        NotebookListCard {
                            if sections.isEmpty {
                                NotebookEmptyRow(icon: "folder.badge.plus", text: "Φτιάξε ενότητες για κεφάλαια, θέματα ή σελίδες")
                            } else {
                                ForEach(Array(sections.enumerated()), id: \.element.id) { index, section in
                                    NotebookManagedFolderRow(folder: section, count: library.allNotes(in: section.id).count)
                                    if index < sections.count - 1 { Divider().overlay(Paper.hairline) }
                                }
                            }
                        }

                        let rootNotes = library.notes(inBook: bookID)
                        if !rootNotes.isEmpty {
                            NotebookSectionHeader(title: "Σημειώσεις βιβλίου", actionTitle: nil, action: nil)
                            NotebookNotesCard(notes: rootNotes)
                        }

                        Label("Οι φωτογραφίες και οι σημειώσεις παραμένουν ιδιωτικές στη συσκευή σου. Το orthodox+ δεν δημοσιεύει ούτε διανέμει το περιεχόμενο του βιβλίου.", systemImage: "lock.shield.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Paper.inkMute)
                            .padding(16)
                            .background(Paper.card.opacity(0.6), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .padding(.horizontal, KSpace.gutter).padding(.top, KSpace.lg).padding(.bottom, 100)
                }
                .background(AppAtmosphere().ignoresSafeArea())
                .navigationTitle("Βιβλίο")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItemGroup(placement: .topBarTrailing) {
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
                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                        .padding(16).background(Paper.card.opacity(0.72), in: RoundedRectangle(cornerRadius: 18))

                    if bookID == nil {
                        NotebookFieldLabel("ΚΑΤΗΓΟΡΙΑ · ΠΡΟΑΙΡΕΤΙΚΗ")
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            ForEach(NotebookCategory.allCases) { category in
                                Button {
                                    withAnimation(.easeInOut(duration: 0.18)) {
                                        draft.category = draft.category == category ? nil : category
                                    }
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: category.icon)
                                        Text(category.title).lineLimit(1).minimumScaleFactor(0.75)
                                    }
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(draft.category == category ? .white : category.tint)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(draft.category == category ? category.tint : Paper.card.opacity(0.72), in: Capsule())
                                    .overlay(Capsule().stroke(draft.category == category ? Color.clear : Paper.hairline))
                                }
                                .buttonStyle(.plain)
                            }
                        }
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
                                HStack(spacing: 10) {
                                    Image(systemName: anchor.kind.icon).foregroundStyle(anchor.kind.tint)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(anchor.cleanTitle).font(.system(size: 14, weight: .bold)).foregroundStyle(Paper.ink).lineLimit(1)
                                        Text(anchor.kind.title).font(.system(size: 11, weight: .bold)).foregroundStyle(Paper.inkMute)
                                    }
                                    Spacer()
                                    Button(role: .destructive) { draft.anchors.removeAll { $0.id == anchor.id } } label: {
                                        Image(systemName: "xmark.circle.fill")
                                    }
                                }
                                .padding(13)
                                .background(Paper.card.opacity(0.58), in: RoundedRectangle(cornerRadius: 18))
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
                                .frame(maxWidth: .infinity, alignment: .leading).padding(18)
                                .modifier(YouCardSurface(cornerRadius: 22))
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
            .background(Paper.bg)
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
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            ForEach(NotebookCategory.allCases) { item in
                                Button {
                                    withAnimation(.easeInOut(duration: 0.18)) {
                                        category = category == item ? nil : item
                                    }
                                } label: {
                                    Label(item.title, systemImage: item.icon)
                                        .font(.system(size: 12, weight: .bold))
                                        .lineLimit(1).minimumScaleFactor(0.72)
                                        .foregroundStyle(category == item ? .white : item.tint)
                                        .frame(maxWidth: .infinity).padding(.vertical, 11)
                                        .background(category == item ? item.tint : Paper.card.opacity(0.72), in: Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .scrollContentBackground(.hidden).background(Paper.bg)
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

private struct NotebookSectionHeader: View {
    let title: String
    let actionTitle: String?
    let action: (() -> Void)?
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.system(size: 19, weight: .semibold, design: .serif)).foregroundStyle(Paper.ink)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
            if let actionTitle, let action {
                Button(action: action) {
                    Label(actionTitle, systemImage: "plus").font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Gild.accentForeground).padding(.horizontal, 10).frame(minHeight: 44)
                }.buttonStyle(.plain)
            }
        }.padding(.top, 4)
    }
}

private struct NotebookListCard<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View { VStack(spacing: 0) { content }.padding(.horizontal, 16).modifier(YouCardSurface()) }
}

private struct NotebookSwipeRow<Content: View>: View {
    let onDelete: () -> Void
    let onFavorite: (() -> Void)?
    let content: Content
    @State private var settledOffset: CGFloat = 0
    @GestureState private var dragOffset: CGFloat = 0

    init(onDelete: @escaping () -> Void, onFavorite: (() -> Void)? = nil, @ViewBuilder content: () -> Content) {
        self.onDelete = onDelete
        self.onFavorite = onFavorite
        self.content = content()
    }

    private var visibleOffset: CGFloat { min(82, max(-82, settledOffset + dragOffset)) }

    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                if let onFavorite {
                    Button {
                        withAnimation(.snappy) { settledOffset = 0 }
                        onFavorite()
                    } label: {
                        Label("Αγαπημένο", systemImage: "star.fill")
                            .labelStyle(.iconOnly)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 82)
                            .frame(maxHeight: .infinity)
                            .background(Paper.gold)
                    }
                    .buttonStyle(.plain)
                }
                Spacer(minLength: 0)
                Button {
                    withAnimation(.snappy) { settledOffset = 0 }
                    onDelete()
                } label: {
                    Label("Διαγραφή", systemImage: "trash.fill")
                        .labelStyle(.iconOnly)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 82)
                        .frame(maxHeight: .infinity)
                        .background(Color.red)
                }
                .buttonStyle(.plain)
            }

            content
                .background(Paper.card)
                .offset(x: visibleOffset)
        }
        .clipped()
        .simultaneousGesture(
            DragGesture(minimumDistance: 16)
                .updating($dragOffset) { value, state, _ in
                    guard abs(value.translation.width) > abs(value.translation.height) else { return }
                    state = value.translation.width
                }
                .onEnded { value in
                    guard abs(value.translation.width) > abs(value.translation.height) else { return }
                    let proposed = settledOffset + value.translation.width
                    withAnimation(.snappy) {
                        if proposed < -42 { settledOffset = -82 }
                        else if proposed > 42, onFavorite != nil { settledOffset = 82 }
                        else { settledOffset = 0 }
                    }
                }
        )
    }
}

private struct NotebookManagedFolderRow: View {
    @ObservedObject private var library = NotebookLibraryStore.shared
    let folder: NotebookFolder
    let count: Int
    @State private var editingFolder = false

    var body: some View {
        NotebookSwipeRow(
            onDelete: { library.delete(folderID: folder.id) },
            onFavorite: { library.toggleFavorite(folderID: folder.id) }
        ) {
            NavigationLink { NotebookFolderView(folderID: folder.id) } label: {
                NotebookFolderRow(folder: folder, count: count)
            }
            .buttonStyle(.plain)
        }
        .draggable("klimax-folder:\(folder.id.uuidString)")
        .dropDestination(for: String.self) { items, _ in
            guard let raw = items.first, raw.hasPrefix("klimax-folder:"),
                  let id = UUID(uuidString: String(raw.dropFirst("klimax-folder:".count)))
            else { return false }
            library.reorderFolder(movingID: id, before: folder.id)
            return true
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
            Image(systemName: "chevron.right").font(.system(size: 13, weight: .bold)).foregroundStyle(Paper.inkMute.opacity(0.7))
        }.frame(minHeight: 64).contentShape(Rectangle())
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
    @ObservedObject private var library = NotebookLibraryStore.shared
    var body: some View {
        NotebookListCard {
            ForEach(Array(notes.enumerated()), id: \.element.id) { index, note in
                NotebookSwipeRow(
                    onDelete: {
                        library.removeNoteData(noteID: note.id)
                        NotebookStore.shared.delete(note)
                    },
                    onFavorite: { library.toggleFavorite(noteID: note.id) }
                ) {
                    NavigationLink { NotebookRichNoteDetail(noteID: note.id) } label: {
                        HStack(spacing: 13) {
                            VStack(alignment: .leading, spacing: 5) {
                                HStack(spacing: 7) {
                                    Text(note.title).font(.system(size: 17, weight: .semibold, design: .serif)).foregroundStyle(Paper.ink).lineLimit(2)
                                    if library.placement(for: note.id)?.isFavorite == true {
                                        Image(systemName: "star.fill").font(.system(size: 11, weight: .bold)).foregroundStyle(Paper.gold)
                                    }
                                }
                                if !note.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    Text(note.body).font(.system(size: 12)).foregroundStyle(Paper.inkSoft).lineLimit(2)
                                }
                                HStack(spacing: 8) {
                                    Text(note.updatedAt.formatted(date: .abbreviated, time: .omitted))
                                    if library.placement(for: note.id)?.bookID == nil, let category = note.category { Text(category.title) }
                                    if let page = library.placement(for: note.id)?.pageReference { Text("Σελίδα \(page)") }
                                    if !library.photos(for: note.id).isEmpty { Label("\(library.photos(for: note.id).count)", systemImage: "photo") }
                                }.font(.system(size: 12, weight: .semibold)).foregroundStyle(Paper.inkMute)
                            }
                            Spacer(); Image(systemName: "chevron.right").font(.system(size: 13, weight: .bold)).foregroundStyle(Paper.inkMute.opacity(0.7))
                        }.frame(minHeight: 68).padding(.vertical, 10).contentShape(Rectangle())
                    }.buttonStyle(.plain)
                }
                .draggable("klimax-note:\(note.id.uuidString)")
                .dropDestination(for: String.self) { items, _ in
                    guard let raw = items.first, raw.hasPrefix("klimax-note:"),
                          let id = UUID(uuidString: String(raw.dropFirst("klimax-note:".count)))
                    else { return false }
                    library.reorderNote(movingID: id, before: note.id)
                    return true
                }
                .contextMenu {
                    Button { library.toggleFavorite(noteID: note.id) } label: {
                        Label(library.placement(for: note.id)?.isFavorite == true ? "Αφαίρεση από αγαπημένα" : "Αγαπημένο", systemImage: library.placement(for: note.id)?.isFavorite == true ? "star.slash" : "star")
                    }
                    Button { library.moveNote(note.id, by: -1) } label: { Label("Μετακίνηση επάνω", systemImage: "arrow.up") }
                    Button { library.moveNote(note.id, by: 1) } label: { Label("Μετακίνηση κάτω", systemImage: "arrow.down") }
                    Divider()
                    Button(role: .destructive) {
                        library.removeNoteData(noteID: note.id)
                        NotebookStore.shared.delete(note)
                    } label: { Label("Διαγραφή", systemImage: "trash") }
                }
                if index < notes.count - 1 { Divider().overlay(Paper.hairline) }
            }
        }
    }
}

private struct NotebookBookTile: View {
    let book: NotebookBook
    let count: Int
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            NotebookBookCover(book: book).frame(width: 126, height: 176)
            Text(book.title).font(.system(size: 15, weight: .bold)).foregroundStyle(Paper.ink).lineLimit(2).frame(width: 126, alignment: .leading)
            Text("\(count) σημειώσεις").font(.system(size: 11, weight: .bold)).foregroundStyle(Paper.inkMute)
        }.frame(width: 126, alignment: .leading)
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
    var body: some View { Text(title).font(.system(size: 11, weight: .black)).tracking(2.7).foregroundStyle(Paper.gold) }
}
