//
//  VirtualIconostasis.swift
//  Klimax
//

import SwiftUI
import UIKit

@MainActor
final class VirtualIconostasisStore: ObservableObject {
    static let shared = VirtualIconostasisStore()

    private struct SaveData: Codable {
        var layoutCount: Int
        var selectedSaintIDs: [String]
    }

    @Published private(set) var layoutCount: Int
    @Published private(set) var selectedSaintIDs: [String]

    private let storageKey = "klimax.profile.iconostasis.v1"

    private init() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode(SaveData.self, from: data) {
            let ids = Array(saved.selectedSaintIDs.uniqued().prefix(6))
            layoutCount = ids.count
            selectedSaintIDs = ids
        } else {
            layoutCount = 0
            selectedSaintIDs = []
        }
    }

    var isConfigured: Bool { !selectedSaintIDs.isEmpty }

    func configure(selectedSaintIDs: [String]) {
        let ids = Array(selectedSaintIDs.uniqued().prefix(6))
        guard !ids.isEmpty else { return }
        self.layoutCount = ids.count
        self.selectedSaintIDs = ids
        persist()
    }

    private func persist() {
        let value = SaveData(layoutCount: layoutCount, selectedSaintIDs: selectedSaintIDs)
        guard let data = try? JSONEncoder().encode(value) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}

private extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

struct VirtualIconostasisCard: View {
    @State private var saints = SaintsStore.shared
    @ObservedObject private var collection = SaintCollectionStore.shared
    @ObservedObject private var iconostasis = VirtualIconostasisStore.shared
    @State private var showingEditor = false

    private var allItems: [SaintCollectionItem] { saints.ranks.saintCollectionItems }

    private var selectedItems: [SaintCollectionItem] {
        iconostasis.selectedSaintIDs.compactMap { id in
            allItems.first(where: { $0.saint.id == id && collection.contains($0.saint) })
        }
    }

    private var collectedCount: Int {
        allItems.filter { collection.contains($0.saint) }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14).fill(Paper.gold.opacity(0.09))
                    Image(systemName: "building.columns.fill")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(Gild.accentForeground)
                }
                .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Το εικονοστάσι μου")
                        .font(.system(size: 20, weight: .semibold, design: .serif))
                        .foregroundStyle(Paper.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                    Text(iconostasis.isConfigured ? "\(iconostasis.layoutCount) εικόνες από τη συλλογή σου" : "Ένας προσωπικός χώρος μνήμης")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Paper.inkMute)
                }

                Spacer()

                Button { showingEditor = true } label: {
                    Image(systemName: iconostasis.isConfigured ? "pencil" : "plus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Paper.ink)
                        .frame(width: 36, height: 36)
                        .glassCircleFallback(shape: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(iconostasis.isConfigured ? "Επεξεργασία εικονοστασίου" : "Δημιουργία εικονοστασίου")
            }

            if saints.ranks.isEmpty && saints.isLoading {
                ProgressView().tint(Paper.gold).frame(maxWidth: .infinity).padding(.vertical, 28)
            } else if iconostasis.isConfigured && selectedItems.count == iconostasis.layoutCount {
                VirtualIconostasisLayout(items: selectedItems, layoutCount: iconostasis.layoutCount)
                    .frame(height: iconostasis.layoutCount % 2 == 1 ? 158 : 138)

                Text("Πάτησε μία εικόνα για να ανοίξεις τον βίο του Αγίου.")
                    .font(.system(size: 11, weight: .medium, design: .serif))
                    .foregroundStyle(Paper.inkMute)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "rectangle.portrait.on.rectangle.portrait.angled")
                        .font(.system(size: 31, weight: .light))
                        .foregroundStyle(Paper.gold)
                    Text(collectedCount > 0
                         ? "Διάλεξε όσες ξεκλειδωμένες κάρτες θέλεις, από μία έως έξι."
                         : "Ξεκλείδωσε μία κάρτα Αγίου για να ξεκινήσεις.")
                        .font(.system(size: 14, weight: .semibold, design: .serif))
                        .foregroundStyle(Paper.inkMute)
                        .multilineTextAlignment(.center)

                    if collectedCount > 0 {
                        Button { showingEditor = true } label: {
                            Label("Δημιουργία", systemImage: "sparkles")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 17).padding(.vertical, 11)
                                .background(Paper.gold, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    } else if !saints.ranks.isEmpty {
                        NavigationLink {
                            SaintCollectionView(ranks: saints.ranks)
                        } label: {
                            Label("Άνοιγμα Συλλογής Αγίων", systemImage: "rectangle.portrait.on.rectangle.portrait")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Paper.gold)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(YouCardSurface())
        .task {
            await saints.load()
            syncIconostasisWidget()
        }
        .onChange(of: iconostasis.selectedSaintIDs) { _, _ in
            syncIconostasisWidget()
        }
        .sheet(isPresented: $showingEditor) {
            VirtualIconostasisEditor()
                .presentationDetents([.large])
        }
    }

    /// Ἀντιγράφει μόνο τὶς 1–6 ἐπιλεγμένες εἰκόνες στὸ App Group. Ἔτσι τὸ
    /// Widget Extension μπορεῖ νὰ δείξει τὸ προσωπικὸ εἰκονοστάσι χωρὶς νὰ
    /// κουβαλᾷ ὁλόκληρο τὸ asset catalogue τῆς εφαρμογῆς.
    private func syncIconostasisWidget() {
        guard !saints.ranks.isEmpty else { return }

        let entries = iconostasis.selectedSaintIDs.compactMap { id -> IconostasisWidgetSaint? in
            guard let item = allItems.first(where: { $0.saint.id == id }) else { return nil }
            let fileName = copyIconToWidgetContainer(item.saint.icon, saintID: item.saint.id)
            return IconostasisWidgetSaint(
                id: item.saint.id,
                name: item.saint.displayName,
                imageFileName: fileName
            )
        }
        WidgetSharedStore.updateIconostasis(.init(saints: entries))
    }

    private func copyIconToWidgetContainer(_ assetName: String?, saintID: String) -> String? {
        guard let assetName, !assetName.isEmpty,
              let image = UIImage(named: assetName),
              let root = WidgetSharedStore.containerURL,
              let data = image.pngData() else { return nil }

        let safeID = saintID.unicodeScalars.map { scalar -> Character in
            CharacterSet.alphanumerics.contains(scalar) ? Character(String(scalar)) : "-"
        }
        let fileName = "iconostasis-\(String(safeID)).png"
        do {
            try data.write(to: root.appendingPathComponent(fileName), options: .atomic)
            return fileName
        } catch {
            #if DEBUG
            print("[IconostasisWidget] αποτυχία αντιγραφής εικόνας: \(error)")
            #endif
            return nil
        }
    }
}

private struct VirtualIconostasisLayout: View {
    let items: [SaintCollectionItem]
    let layoutCount: Int

    private var proportions: [CGFloat] {
        switch layoutCount {
        case 1: [0.34]
        case 2: [0.27, 0.27]
        case 3: [0.20, 0.30, 0.20]
        case 4: [0.16, 0.23, 0.23, 0.16]
        case 5: [0.14, 0.17, 0.29, 0.17, 0.14]
        default: [0.11, 0.13, 0.20, 0.20, 0.13, 0.11]
        }
    }

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                HStack(alignment: .bottom, spacing: layoutCount == 6 ? 4 : 5) {
                    ForEach(Array(items.prefix(layoutCount).enumerated()), id: \.element.id) { index, item in
                        NavigationLink {
                            SaintDetailView(saint: item.saint)
                        } label: {
                            VirtualSaintIcon(item: item)
                                .frame(width: proxy.size.width * proportions[index])
                        }
                        .buttonStyle(.plain)
                    }
                }

                IconostasisShelf()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
    }
}

private struct VirtualSaintIcon: View {
    let item: SaintCollectionItem

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.36, green: 0.20, blue: 0.08), Color(red: 0.72, green: 0.50, blue: 0.18)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            if let icon = item.saint.icon, !icon.isEmpty, UIImage(named: icon) != nil {
                SaintPortraitCanvas(icon: icon)
                    .padding(3)
            } else {
                ZStack {
                    Paper.gold.opacity(0.16)
                    Image(systemName: SaintGlyph.forRank(item.rank.id))
                        .font(.system(size: 23, weight: .light))
                        .foregroundStyle(Paper.gold)
                }
                .padding(3)
            }
        }
        .aspectRatio(0.68, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(Paper.gold.opacity(0.92), lineWidth: 1.4)
                .padding(1)
        }
        .shadow(color: Color.black.opacity(0.24), radius: 6, y: 4)
        .accessibilityLabel(item.saint.displayName)
    }
}

private struct IconostasisShelf: View {
    var body: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.34, green: 0.18, blue: 0.08),
                            Color(red: 0.66, green: 0.42, blue: 0.16),
                            Color(red: 0.30, green: 0.15, blue: 0.06)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .overlay(alignment: .top) {
                    Rectangle().fill(Paper.gold.opacity(0.74)).frame(height: 1)
                }
                .frame(height: 9)
                .shadow(color: Color.black.opacity(0.2), radius: 5, y: 3)

            HStack {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(red: 0.34, green: 0.18, blue: 0.08))
                    .frame(width: 24, height: 5)
                Spacer()
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(red: 0.34, green: 0.18, blue: 0.08))
                    .frame(width: 24, height: 5)
            }
            .padding(.horizontal, 18)
        }
    }
}

private struct VirtualIconostasisEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var saints = SaintsStore.shared
    @ObservedObject private var collection = SaintCollectionStore.shared
    @ObservedObject private var iconostasis = VirtualIconostasisStore.shared

    @State private var selectedIDs: [String]
    @State private var query = ""

    init() {
        _selectedIDs = State(initialValue: VirtualIconostasisStore.shared.selectedSaintIDs)
    }

    private var collectedItems: [SaintCollectionItem] {
        saints.ranks.saintCollectionItems.filter { collection.contains($0.saint) }
    }

    private var visibleItems: [SaintCollectionItem] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return collectedItems }
        return collectedItems.filter {
            "\($0.saint.displayName) \($0.saint.name) \($0.saint.nameEnglish ?? "")"
                .localizedCaseInsensitiveContains(query)
        }
    }

    private var selectedItems: [SaintCollectionItem] {
        selectedIDs.compactMap { id in collectedItems.first(where: { $0.saint.id == id }) }
    }

    private var layoutCount: Int { max(selectedIDs.count, 1) }
    private var canSave: Bool { !selectedIDs.isEmpty && selectedItems.count == selectedIDs.count }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Το εικονοστάσι σου")
                            .font(.system(size: 30, weight: .heavy, design: .rounded))
                            .foregroundStyle(Paper.ink)
                        Text("Διάλεξε από μία έως έξι κάρτες και τοποθέτησέ τες με τη σειρά που θέλεις. Η διάταξη προσαρμόζεται αυτόματα.")
                            .font(.system(size: 14, weight: .semibold, design: .serif))
                            .foregroundStyle(Paper.inkMute)
                    }

                    IconostasisArrangementEditor(
                        items: selectedItems,
                        selectedIDs: $selectedIDs,
                        layoutCount: layoutCount
                    )
                    .frame(height: layoutCount % 2 == 1 ? 166 : 146)

                    HStack {
                        Text("ΞΕΚΛΕΙΔΩΜΕΝΕΣ ΚΑΡΤΕΣ")
                            .font(.system(size: 11, weight: .black)).tracking(2.4).foregroundStyle(Paper.gold)
                        Spacer()
                        Text("\(selectedIDs.count)/6")
                            .font(.system(size: 12, weight: .black)).foregroundStyle(canSave ? Paper.gold : Paper.inkMute)
                    }

                    if collectedItems.isEmpty {
                        collectionEmptyState
                    } else {
                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass").foregroundStyle(Paper.inkMute)
                            TextField("Αναζήτηση Αγίου", text: $query)
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .padding(13)
                        .background(Paper.card.opacity(0.72), in: RoundedRectangle(cornerRadius: 16))

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 13) {
                            ForEach(visibleItems) { item in
                                iconChoice(item)
                            }
                        }
                    }
                }
                .padding(20).padding(.bottom, 30)
            }
            .background(Paper.bg.ignoresSafeArea())
            .navigationTitle("Επεξεργασία")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Άκυρο") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Αποθήκευση") {
                        iconostasis.configure(selectedSaintIDs: selectedIDs)
                        dismiss()
                    }
                    .fontWeight(.bold)
                    .disabled(!canSave)
                }
            }
            .task {
                await saints.load()
                let validIDs = Set(collectedItems.map(\.id))
                selectedIDs = selectedIDs.filter(validIDs.contains)
            }
        }
        .tint(Paper.gold)
    }

    @ViewBuilder
    private func iconChoice(_ item: SaintCollectionItem) -> some View {
        let selectedIndex = selectedIDs.firstIndex(of: item.id)
        let selectionIsFull = selectedIDs.count >= 6 && selectedIndex == nil

        Button {
            if let selectedIndex {
                selectedIDs.remove(at: selectedIndex)
            } else if !selectionIsFull {
                selectedIDs.append(item.id)
            }
        } label: {
            VStack(spacing: 7) {
                ZStack(alignment: .topTrailing) {
                    VirtualSaintIcon(item: item)
                    if let selectedIndex {
                        Text("\(selectedIndex + 1)")
                            .font(.system(size: 11, weight: .black))
                            .foregroundStyle(.white)
                            .frame(width: 24, height: 24)
                            .background(Paper.gold, in: Circle())
                            .padding(4)
                    }
                }
                Text(item.saint.displayName)
                    .font(.system(size: 11, weight: .bold, design: .serif))
                    .foregroundStyle(Paper.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .opacity(selectionIsFull ? 0.38 : 1)
        }
        .buttonStyle(.plain)
        .disabled(selectionIsFull)
    }

    private var collectionEmptyState: some View {
        VStack(spacing: 13) {
            Image(systemName: "lock.rectangle.stack")
                .font(.system(size: 30, weight: .light)).foregroundStyle(Paper.gold)
            Text("Ξεκλείδωσε μία κάρτα από τη Συλλογή Αγίων για να δημιουργήσεις το εικονοστάσι σου.")
                .font(.system(size: 14, weight: .semibold, design: .serif))
                .foregroundStyle(Paper.inkMute).multilineTextAlignment(.center)
            if !saints.ranks.isEmpty {
                NavigationLink {
                    SaintCollectionView(ranks: saints.ranks)
                } label: {
                    Label("Μετάβαση στη συλλογή", systemImage: "arrow.right")
                        .font(.system(size: 14, weight: .bold)).foregroundStyle(Paper.gold)
                }
            }
        }
        .frame(maxWidth: .infinity).padding(.vertical, 34)
    }
}

private struct IconostasisArrangementEditor: View {
    let items: [SaintCollectionItem]
    @Binding var selectedIDs: [String]
    let layoutCount: Int

    private var proportions: [CGFloat] {
        switch layoutCount {
        case 1: [0.34]
        case 2: [0.27, 0.27]
        case 3: [0.20, 0.30, 0.20]
        case 4: [0.16, 0.23, 0.23, 0.16]
        case 5: [0.14, 0.17, 0.29, 0.17, 0.14]
        default: [0.11, 0.13, 0.20, 0.20, 0.13, 0.11]
        }
    }

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                HStack(alignment: .bottom, spacing: layoutCount == 6 ? 4 : 5) {
                    ForEach(0..<layoutCount, id: \.self) { index in
                        Group {
                            if index < items.count {
                                Button { selectedIDs.remove(at: index) } label: {
                                    VirtualSaintIcon(item: items[index])
                                        .overlay(alignment: .topTrailing) {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.system(size: 15, weight: .bold))
                                                .foregroundStyle(.white, Paper.ink.opacity(0.6))
                                                .padding(3)
                                        }
                                }
                                .buttonStyle(.plain)
                                .draggable("iconostasis:\(items[index].id)")
                            } else {
                                RoundedRectangle(cornerRadius: 7)
                                    .fill(Paper.ink.opacity(0.05))
                                    .overlay {
                                        VStack(spacing: 4) {
                                            Image(systemName: "plus")
                                            Text("\(index + 1)")
                                        }
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(Paper.inkMute)
                                    }
                                    .aspectRatio(0.68, contentMode: .fit)
                                    .overlay(RoundedRectangle(cornerRadius: 7).stroke(Paper.hairline, style: StrokeStyle(lineWidth: 1, dash: [4])))
                            }
                        }
                        .frame(width: proxy.size.width * proportions[index])
                        .dropDestination(for: String.self) { payloads, _ in
                            guard let payload = payloads.first, payload.hasPrefix("iconostasis:"),
                                  let oldIndex = selectedIDs.firstIndex(of: String(payload.dropFirst("iconostasis:".count))),
                                  index < selectedIDs.count, oldIndex != index
                            else { return false }
                            let id = selectedIDs.remove(at: oldIndex)
                            selectedIDs.insert(id, at: min(index, selectedIDs.count))
                            return true
                        }
                    }
                }

                IconostasisShelf()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
    }
}
