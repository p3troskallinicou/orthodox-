//
//  SaintCollection.swift
//  Klimax
//
//  A private collection of remembrance cards. The catalogue itself remains
//  fully open; the quiz only reveals the companion card.
//

import SwiftUI
import UIKit

// MARK: - Collection data

struct SaintCollectionItem: Identifiable, Hashable {
    let saint: SaintEntry
    let rank: SaintRank

    var id: String { saint.id }
}

extension Array where Element == SaintRank {
    var saintCollectionItems: [SaintCollectionItem] {
        flatMap { rank in
            rank.saints.map { SaintCollectionItem(saint: $0, rank: rank) }
        }
    }
}

@MainActor
final class SaintCollectionStore: ObservableObject {
    static let shared = SaintCollectionStore()

    struct Record: Codable, Hashable {
        let saintID: String
        let collectedAt: Date
        let quizVersion: Int
    }

    @Published private(set) var records: [String: Record]

    private let storageKey = "klimax.saints.collection.v1"
    private let quizVersion = 1

    private init() {
        guard
            let data = UserDefaults.standard.data(forKey: storageKey),
            let decoded = try? JSONDecoder().decode([String: Record].self, from: data)
        else {
            records = [:]
            return
        }
        records = decoded
    }

    func contains(_ saint: SaintEntry) -> Bool {
        records[saint.id] != nil
    }

    func record(for saint: SaintEntry) -> Record? {
        records[saint.id]
    }

    func collect(_ saint: SaintEntry, at date: Date = Date()) {
        guard records[saint.id] == nil else { return }
        records[saint.id] = Record(
            saintID: saint.id,
            collectedAt: date,
            quizVersion: quizVersion
        )
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(records) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}

// MARK: - Gallery

private enum SaintCollectionFilter: String, CaseIterable, Identifiable {
    case all
    case collected

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "Όλες"
        case .collected: "Κρατημένες"
        }
    }
}

struct SaintCollectionView: View {
    let ranks: [SaintRank]
    var embedded = false

    @ObservedObject private var collection = SaintCollectionStore.shared
    @State private var query = ""
    @State private var filter: SaintCollectionFilter = .all

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    private var allItems: [SaintCollectionItem] {
        ranks.saintCollectionItems
    }

    private var visibleItems: [SaintCollectionItem] {
        let queryKey = saintSearchKey(query)
        return allItems.filter { item in
            let matchesFilter = filter == .all || collection.contains(item.saint)
            guard matchesFilter else { return false }
            guard !queryKey.isEmpty else { return true }

            let haystack = saintSearchKey([
                item.saint.name,
                item.saint.nameEnglish ?? "",
                item.saint.feast ?? "",
                item.saint.rankTitle ?? "",
                item.rank.titleGreek
            ].joined(separator: " "))
            return haystack.contains(queryKey)
        }
    }

    var body: some View {
        ZStack {
            if !embedded { AppAtmosphere().ignoresSafeArea() }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    introduction
                    if query.isEmpty, filter == .all, let next = allItems.first(where: { !collection.contains($0.saint) }) {
                        NavigationLink {
                            SaintCollectibleCardView(item: next, allItems: allItems, showsCatalogLink: true)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "sparkles").font(.title2).foregroundStyle(Gild.accentForeground)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Η επόμενη γνωριμία σου").font(.caption.weight(.semibold)).foregroundStyle(Gild.accentForeground)
                                    Text(next.saint.displayName).font(.system(size: 18, weight: .semibold, design: .serif))
                                        .foregroundStyle(Paper.ink).multilineTextAlignment(.leading)
                                    Text("Διάβασε, απάντησε και κράτησε την κάρτα.")
                                        .font(.caption).foregroundStyle(Paper.inkMute)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "arrow.right").foregroundStyle(Gild.accentForeground)
                            }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
                                .background(Paper.card, in: RoundedRectangle(cornerRadius: 20))
                                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Paper.gold.opacity(0.18), lineWidth: 1))
                        }.buttonStyle(.plain)
                    }
                    searchField
                    filterPicker

                    if visibleItems.isEmpty {
                        emptyState
                    } else {
                        LazyVGrid(columns: columns, spacing: 18) {
                            ForEach(visibleItems) { item in
                                NavigationLink {
                                    SaintCollectibleCardView(
                                        item: item,
                                        allItems: allItems,
                                        showsCatalogLink: true
                                    )
                                } label: {
                                    SaintCollectionTile(
                                        item: item,
                                        isCollected: collection.contains(item.saint),
                                        collectedAt: collection.record(for: item.saint)?.collectedAt
                                    )
                                }
                                .buttonStyle(CalmCardStyle())
                            }
                        }
                    }

                    Spacer(minLength: 42)
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Συλλογή Αγίων")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(embedded ? .hidden : .visible, for: .navigationBar)
    }

    private var introduction: some View {
        let collectedCount = allItems.filter { collection.contains($0.saint) }.count
        return VStack(alignment: .leading, spacing: 12) {
            Text("ΓΝΩΡΙΣΕ · ΘΥΜΗΣΟΥ · ΚΡΑΤΗΣΕ")
                .font(.system(size: 10, weight: .bold))
                .tracking(2.6)
                .foregroundStyle(Gild.accentForeground)

            Text("Η συλλογή σου μεγαλώνει")
                .font(.system(size: 31, weight: .regular, design: .serif))
                .foregroundStyle(Paper.ink)

            Text("Κάθε γνωριμία γίνεται μια κάρτα. Ανακάλυψε τον βίο και δοκίμασε όσα έμαθες.")
                .font(.system(size: 14))
                .foregroundStyle(Paper.inkMute)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text("\(collectedCount)").font(.system(size: 28, weight: .semibold, design: .rounded)).foregroundStyle(Gild.accentForeground)
                Text("από \(allItems.count) κάρτες στη συλλογή σου").font(.caption).foregroundStyle(Paper.inkMute)
            }
            ProgressView(value: Double(collectedCount), total: Double(max(1, allItems.count)))
                .tint(Paper.gold).accessibilityLabel("Πρόοδος συλλογής")
        }
        .padding(.horizontal, 2)
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Paper.inkMute)

            TextField("Αναζήτηση αγίου", text: $query)
                .font(.system(size: 15))
                .foregroundStyle(Paper.ink)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Paper.inkMute.opacity(0.55))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 15)
        .frame(height: 48)
        .klimaxLiquidGlass(
            in: RoundedRectangle(cornerRadius: 17, style: .continuous),
            interactive: false
        )
    }

    private var filterPicker: some View {
        HStack(spacing: 6) {
            ForEach(SaintCollectionFilter.allCases) { option in
                Button {
                    withAnimation(.easeInOut(duration: 0.20)) {
                        filter = option
                    }
                } label: {
                    Text(option.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(filter == option ? Paper.ink : Paper.inkMute)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(filter == option ? Paper.card : .clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Paper.ink.opacity(0.045), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: filter == .collected ? "rectangle.portrait.on.rectangle.portrait" : "magnifyingglass")
                .font(.system(size: 28, weight: .regular))
                .foregroundStyle(Paper.gold)

            Text(filter == .collected ? "Δεν έχεις κρατήσει ακόμη κάποια κάρτα." : "Δεν βρέθηκε άγιος.")
                .font(.system(size: 16, design: .serif))
                .foregroundStyle(Paper.ink)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 42)
    }
}

private struct SaintCollectionTile: View {
    let item: SaintCollectionItem
    let isCollected: Bool
    let collectedAt: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SaintCardFace(
                item: item,
                isCollected: isCollected,
                collectedAt: collectedAt,
                side: .front,
                compact: true
            )
            .aspectRatio(0.68, contentMode: .fit)

            HStack(spacing: 6) {
                Image(systemName: isCollected ? "seal.fill" : "lock.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(isCollected ? SaintCardPalette.forRank(item.rank.id).accent : Paper.inkMute)

                Text(isCollected ? "Κρατημένη" : "Γνώρισε τον Άγιο")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(isCollected ? Paper.ink : Paper.inkMute)
                    .lineLimit(1)
            }
            .padding(.horizontal, 3)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.saint.displayName), \(isCollected ? "κάρτα κρατημένη" : "κάρτα κλειστή")")
    }
}

// MARK: - Full card

struct SaintCollectibleCardView: View {
    let item: SaintCollectionItem
    let allItems: [SaintCollectionItem]
    var showsCatalogLink: Bool

    @ObservedObject private var collection = SaintCollectionStore.shared
    @State private var isFlipped = false
    @State private var horizontalTilt: Double = 0
    @State private var verticalTilt: Double = 0
    @State private var showingQuiz = false

    private var isCollected: Bool {
        collection.contains(item.saint)
    }

    private var collectedAt: Date? {
        collection.record(for: item.saint)?.collectedAt
    }

    private var palette: SaintCardPalette {
        .forRank(item.rank.id)
    }

    private var hasCuratedQuiz: Bool {
        SaintQuizFactory.hasQuiz(for: item.saint)
    }

    var body: some View {
        ZStack {
            cardBackdrop

            ScrollView {
                VStack(spacing: 18) {
                    heading

                    card
                        .frame(maxWidth: 330)
                        .padding(.horizontal, 30)

                    if isCollected {
                        Label("Πάτησε ή σύρε οριζόντια για να γυρίσεις την κάρτα.", systemImage: "rotate.3d")
                            .font(.system(size: 12, design: .serif))
                            .foregroundStyle(Paper.inkMute)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    } else {
                        lockedActions
                    }

                    if showsCatalogLink {
                        NavigationLink(value: item.saint) {
                            Label("Διάβασε τον βίο", systemImage: "book.closed")
                                .font(.system(size: 15, weight: .semibold, design: .serif))
                                .foregroundStyle(Paper.ink)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                                .klimaxLiquidGlass(
                                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                                )
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 28)
                    }

                    Spacer(minLength: 36)
                }
                .padding(.top, 18)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle(item.saint.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .fullScreenCover(isPresented: $showingQuiz) {
            SaintCardQuizView(item: item)
        }
        .onChange(of: isCollected) { _, collected in
            if collected {
                isFlipped = false
            }
        }
    }

    private var cardBackdrop: some View {
        ZStack {
            Paper.bg.ignoresSafeArea()

            RadialGradient(
                colors: [
                    palette.accent.opacity(0.28),
                    palette.soft.opacity(0.15),
                    .clear
                ],
                center: .top,
                startRadius: 20,
                endRadius: 520
            )
            .ignoresSafeArea()

            if let icon = item.saint.icon, !icon.isEmpty, UIImage(named: icon) != nil {
                Image(icon)
                    .resizable()
                    .scaledToFill()
                    .blur(radius: 42)
                    .opacity(0.09)
                    .ignoresSafeArea()
            }
        }
    }

    private var heading: some View {
        VStack(spacing: 5) {
            Text(item.rank.titleGreek.uppercased())
                .font(.system(size: 10, weight: .bold))
                .tracking(2.4)
                .foregroundStyle(palette.accent)

            Text(item.saint.displayName)
                .font(.system(size: 25, weight: .regular, design: .serif))
                .foregroundStyle(Paper.ink)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            if let feast = item.saint.feast, !feast.isEmpty {
                Text(feast)
                    .font(.system(size: 13, design: .serif))
                    .foregroundStyle(Paper.inkMute)
            }
        }
    }

    private var card: some View {
        ZStack {
            SaintCardFace(
                item: item,
                isCollected: isCollected,
                collectedAt: collectedAt,
                side: .front,
                compact: false
            )
            .opacity(isFlipped ? 0 : 1)

            SaintCardFace(
                item: item,
                isCollected: isCollected,
                collectedAt: collectedAt,
                side: .back,
                compact: false
            )
            .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
            .opacity(isFlipped ? 1 : 0)
        }
        .aspectRatio(0.68, contentMode: .fit)
        .rotation3DEffect(
            .degrees(isFlipped ? 180 : 0),
            axis: (x: 0, y: 1, z: 0),
            perspective: 0.72
        )
        .rotation3DEffect(
            .degrees(horizontalTilt),
            axis: (x: 0, y: 1, z: 0),
            perspective: 0.72
        )
        .rotation3DEffect(
            .degrees(verticalTilt),
            axis: (x: 1, y: 0, z: 0),
            perspective: 0.72
        )
        .shadow(color: palette.accent.opacity(0.20), radius: 24, x: 0, y: 15)
        .animation(.spring(response: 0.56, dampingFraction: 0.84), value: isFlipped)
        .animation(.spring(response: 0.30, dampingFraction: 0.78), value: horizontalTilt)
        .animation(.spring(response: 0.30, dampingFraction: 0.78), value: verticalTilt)
        .contentShape(Rectangle())
        .onTapGesture {
            guard isCollected else { return }
            isFlipped.toggle()
        }
        .gesture(
            DragGesture(minimumDistance: 4)
                .onChanged { value in
                    horizontalTilt = max(-9, min(9, Double(value.translation.width / 18)))
                    verticalTilt = max(-5, min(5, Double(-value.translation.height / 28)))
                }
                .onEnded { value in
                    if isCollected, abs(value.translation.width) > 54 {
                        isFlipped.toggle()
                    }
                    horizontalTilt = 0
                    verticalTilt = 0
                }
        )
    }

    private var lockedActions: some View {
        VStack(spacing: 10) {
            Text(
                hasCuratedQuiz
                    ? "Η κάρτα περιμένει να γνωρίσεις λίγο καλύτερα τον Άγιο."
                    : "Το επιμελημένο quiz δεν είναι ακόμη έτοιμο. Δεν θα σου δείξουμε πρόχειρες ή ατεκμηρίωτες ερωτήσεις."
            )
                .font(.system(size: 14, design: .serif))
                .foregroundStyle(Paper.inkMute)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            if hasCuratedQuiz {
                Button {
                    showingQuiz = true
                } label: {
                    Label("Γνώρισε τον Άγιο", systemImage: "questionmark.bubble.fill")
                        .font(.system(size: 16, weight: .bold, design: .serif))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(palette.accent)
                        )
                }
                .buttonStyle(CalmCardStyle())
                .padding(.horizontal, 28)
            }
        }
    }
}

private enum SaintCardSide {
    case front
    case back
}

private struct SaintCardFace: View {
    let item: SaintCollectionItem
    let isCollected: Bool
    let collectedAt: Date?
    let side: SaintCardSide
    let compact: Bool

    private var palette: SaintCardPalette {
        .forRank(item.rank.id)
    }

    private var innerOutlineInset: CGFloat {
        compact ? 2.5 : 3.5
    }

    private var innerCardShape: SaintCardShape {
        SaintCardShape().inset(by: innerOutlineInset)
    }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height

            ZStack {
                SaintCardShape()
                    .fill(
                        LinearGradient(
                            colors: [palette.top, palette.bottom],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                cardPattern(width: width, height: height)

                if side == .front {
                    front(width: width, height: height)
                } else {
                    back(width: width, height: height)
                }

                SaintCardShape()
                    .stroke(palette.rim.opacity(0.96), lineWidth: compact ? 1.4 : 2.2)

                innerCardShape
                    .stroke(Color.white.opacity(0.22), lineWidth: compact ? 0.45 : 0.75)
            }
            .clipShape(SaintCardShape())
        }
    }

    private func cardPattern(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(palette.accent.opacity(0.20))
                .frame(width: width * 1.06)
                .blur(radius: compact ? 12 : 22)
                .offset(x: width * 0.25, y: -height * 0.16)

            Path { path in
                path.move(to: CGPoint(x: width * 0.08, y: height * 0.24))
                path.addLine(to: CGPoint(x: width * 0.92, y: height * 0.10))
                path.move(to: CGPoint(x: width * 0.12, y: height * 0.71))
                path.addLine(to: CGPoint(x: width * 0.88, y: height * 0.58))
            }
            .stroke(palette.rim.opacity(0.20), lineWidth: compact ? 0.7 : 1)
        }
    }

    private func front(width: CGFloat, height: CGFloat) -> some View {
        ZStack(alignment: .bottom) {
            ZStack {
                saintArtwork(width: width, height: height)
                    .frame(width: width, height: height)

                LinearGradient(
                    stops: [
                        .init(color: palette.top.opacity(0.78), location: 0),
                        .init(color: palette.top.opacity(0.22), location: 0.20),
                        .init(color: .clear, location: 0.47),
                        .init(color: palette.bottom.opacity(0.42), location: 0.65),
                        .init(color: palette.bottom.opacity(0.96), location: 0.86),
                        .init(color: palette.bottom, location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .clipShape(innerCardShape)

            VStack(spacing: 0) {
                HStack {
                    Text(item.rank.titleGreek.uppercased())
                        .font(.system(size: compact ? width * 0.045 : width * 0.035, weight: .bold))
                        .tracking(compact ? 0.7 : 1.5)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)

                    Spacer()

                    Image(systemName: "cross.fill")
                        .font(.system(size: compact ? width * 0.075 : width * 0.06, weight: .semibold))
                }
                .foregroundStyle(palette.rim)
                .padding(.horizontal, width * 0.075)
                .padding(.top, height * 0.052)

                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: compact ? 2 : 6) {
                if !compact {
                    Text("ΚΑΡΤΑ ΜΝΗΜΗΣ")
                        .font(.system(size: width * 0.034, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(palette.rim)
                }

                Text(item.saint.displayName)
                    .font(.system(
                        size: compact ? width * 0.105 : width * 0.078,
                        weight: .semibold,
                        design: .serif
                    ))
                    .foregroundStyle(Color.white.opacity(0.96))
                    .lineLimit(compact ? 3 : 2)
                    .minimumScaleFactor(0.68)
                    .fixedSize(horizontal: false, vertical: true)

                if let feast = item.saint.feast, !feast.isEmpty {
                    Text(feast)
                        .font(.system(size: compact ? width * 0.065 : width * 0.045, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.68))
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, width * 0.075)
            .padding(.bottom, height * 0.064)

            if !isCollected {
                lockedOverlay(width: width, height: height)
            }
        }
    }

    private func saintArtwork(width: CGFloat, height: CGFloat) -> some View {
        Group {
            if let icon = item.saint.icon, !icon.isEmpty, UIImage(named: icon) != nil {
                SaintPortraitCanvas(icon: icon)
                    .frame(width: width, height: height, alignment: .center)
                    .saturation(isCollected ? 1 : 0.18)
                    .blur(radius: isCollected ? 0 : (compact ? 5 : 9))
                    .opacity(isCollected ? 1 : 0.25)
                    .overlay {
                        palette.top
                            .opacity(compact ? 0.10 : 0.14)
                            .blendMode(.multiply)
                    }
            } else {
                ZStack {
                    Circle()
                        .fill(palette.soft.opacity(0.26))
                        .frame(width: width * 0.56)

                    Image(systemName: SaintGlyph.forRank(item.rank.id))
                        .font(.system(size: width * 0.25, weight: .light))
                        .foregroundStyle(palette.rim.opacity(isCollected ? 0.92 : 0.28))
                }
            }
        }
    }

    private func lockedOverlay(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(0.34)

            VStack(spacing: compact ? 5 : 10) {
                Image(systemName: "lock.fill")
                    .font(.system(size: compact ? width * 0.12 : width * 0.10, weight: .semibold))
                Text(compact ? "ΓΝΩΡΙΣΕ" : "Η ΚΑΡΤΑ ΠΕΡΙΜΕΝΕΙ")
                    .font(.system(size: compact ? width * 0.052 : width * 0.036, weight: .bold))
                    .tracking(compact ? 1.2 : 2)
            }
            .foregroundStyle(palette.rim)
            .offset(y: -height * 0.055)
        }
        .mask(SaintCardShape())
    }

    private func back(width: CGFloat, height: CGFloat) -> some View {
        VStack(spacing: compact ? 8 : 14) {
            Image(systemName: "cross.fill")
                .font(.system(size: compact ? width * 0.13 : width * 0.10, weight: .semibold))
                .foregroundStyle(palette.rim)

            Text("ΚΑΡΤΑ ΜΝΗΜΗΣ")
                .font(.system(size: compact ? width * 0.055 : width * 0.038, weight: .bold))
                .tracking(compact ? 1.2 : 2.2)
                .foregroundStyle(palette.rim)

            Text(item.saint.displayName)
                .font(.system(
                    size: compact ? width * 0.105 : width * 0.074,
                    weight: .semibold,
                    design: .serif
                ))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(compact ? 3 : 2)
                .minimumScaleFactor(0.7)

            VStack(spacing: compact ? 3 : 6) {
                Text(item.saint.rankTitle ?? item.rank.titleGreek)
                if let feast = item.saint.feast, !feast.isEmpty {
                    Text("Μνήμη \(feast)")
                }
            }
            .font(.system(size: compact ? width * 0.06 : width * 0.043, design: .serif))
            .foregroundStyle(Color.white.opacity(0.70))
            .multilineTextAlignment(.center)

            if !compact, let remembrance = remembranceText {
                Rectangle()
                    .fill(palette.rim.opacity(0.45))
                    .frame(width: width * 0.20, height: 1)
                    .padding(.vertical, 2)

                Text(remembrance)
                    .font(.system(size: width * 0.047, design: .serif))
                    .foregroundStyle(Color.white.opacity(0.88))
                    .lineSpacing(4)
                    .lineLimit(7)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, width * 0.07)
            }

            Spacer(minLength: 0)

            if let collectedAt {
                VStack(spacing: 3) {
                    Text("ΚΡΑΤΗΘΗΚΕ")
                        .font(.system(size: compact ? width * 0.045 : width * 0.031, weight: .bold))
                        .tracking(1.5)
                    Text(collectedAt.formatted(.dateTime.day().month(.wide).year()))
                        .font(.system(size: compact ? width * 0.058 : width * 0.040, weight: .medium))
                }
                .foregroundStyle(palette.rim)
            }
        }
        .padding(.horizontal, width * 0.08)
        .padding(.vertical, height * 0.075)
    }

    private var remembranceText: String? {
        guard let paragraph = item.saint.bio?.first(where: { !$0.isEmpty }) else {
            return item.saint.apolytikion?.textEl
        }
        return paragraph
    }
}

private struct SaintCardShape: InsettableShape {
    var insetAmount: CGFloat = 0

    func inset(by amount: CGFloat) -> SaintCardShape {
        var shape = self
        shape.insetAmount += amount
        return shape
    }

    func path(in rect: CGRect) -> Path {
        let drawingRect = rect.insetBy(dx: insetAmount, dy: insetAmount)
        guard drawingRect.width > 0, drawingRect.height > 0 else {
            return Path()
        }

        let topRadius = min(drawingRect.width, drawingRect.height) * 0.065
        let cut = drawingRect.width * 0.10

        var path = Path()
        path.move(to: CGPoint(x: drawingRect.minX + topRadius, y: drawingRect.minY))
        path.addLine(to: CGPoint(x: drawingRect.maxX - topRadius, y: drawingRect.minY))
        path.addQuadCurve(
            to: CGPoint(x: drawingRect.maxX, y: drawingRect.minY + topRadius),
            control: CGPoint(x: drawingRect.maxX, y: drawingRect.minY)
        )
        path.addLine(to: CGPoint(x: drawingRect.maxX, y: drawingRect.maxY - cut))
        path.addLine(to: CGPoint(x: drawingRect.maxX - cut, y: drawingRect.maxY))
        path.addLine(to: CGPoint(x: drawingRect.minX + cut, y: drawingRect.maxY))
        path.addLine(to: CGPoint(x: drawingRect.minX, y: drawingRect.maxY - cut))
        path.addLine(to: CGPoint(x: drawingRect.minX, y: drawingRect.minY + topRadius))
        path.addQuadCurve(
            to: CGPoint(x: drawingRect.minX + topRadius, y: drawingRect.minY),
            control: CGPoint(x: drawingRect.minX, y: drawingRect.minY)
        )
        path.closeSubpath()
        return path
    }
}

private struct SaintCardPalette {
    let top: Color
    let bottom: Color
    let accent: Color
    let soft: Color
    let rim: Color

    static func forRank(_ id: String) -> SaintCardPalette {
        switch id {
        case "theotokos":
            palette(0.18, 0.31, 0.55, 0.07, 0.12, 0.25, 0.69, 0.80, 0.98)
        case "apostoloi":
            palette(0.49, 0.30, 0.09, 0.15, 0.10, 0.06, 0.86, 0.66, 0.29)
        case "profitai":
            palette(0.31, 0.24, 0.47, 0.11, 0.08, 0.20, 0.71, 0.58, 0.88)
        case "ierarchai":
            palette(0.45, 0.16, 0.23, 0.14, 0.07, 0.10, 0.86, 0.58, 0.44)
        case "martyres", "neomartyres":
            palette(0.46, 0.12, 0.14, 0.13, 0.06, 0.08, 0.90, 0.49, 0.38)
        case "osioi":
            palette(0.26, 0.37, 0.24, 0.09, 0.14, 0.10, 0.69, 0.74, 0.43)
        case "omologitai":
            palette(0.28, 0.35, 0.45, 0.09, 0.12, 0.18, 0.63, 0.74, 0.86)
        case "anargyroi":
            palette(0.16, 0.38, 0.39, 0.06, 0.13, 0.15, 0.43, 0.78, 0.72)
        case "dikaioi":
            palette(0.39, 0.31, 0.19, 0.13, 0.10, 0.07, 0.79, 0.68, 0.43)
        case "myroforoi":
            palette(0.42, 0.24, 0.38, 0.14, 0.08, 0.13, 0.84, 0.62, 0.78)
        case "synaxeis":
            palette(0.30, 0.28, 0.50, 0.10, 0.09, 0.18, 0.70, 0.66, 0.91)
        default:
            palette(0.38, 0.31, 0.20, 0.12, 0.10, 0.07, 0.82, 0.68, 0.38)
        }
    }

    private static func palette(
        _ topR: Double,
        _ topG: Double,
        _ topB: Double,
        _ bottomR: Double,
        _ bottomG: Double,
        _ bottomB: Double,
        _ accentR: Double,
        _ accentG: Double,
        _ accentB: Double
    ) -> SaintCardPalette {
        let accent = Color(red: accentR, green: accentG, blue: accentB)
        return SaintCardPalette(
            top: Color(red: topR, green: topG, blue: topB),
            bottom: Color(red: bottomR, green: bottomG, blue: bottomB),
            accent: accent,
            soft: Color(red: topR, green: topG, blue: topB),
            rim: accent
        )
    }
}

// MARK: - Quiz

private struct SaintQuizQuestion: Identifiable {
    let id = UUID()
    let prompt: String
    let options: [String]
    let correctIndex: Int
    let explanation: String
}

private enum SaintQuizFactory {
    private struct Catalog: Decodable {
        let schemaVersion: Int
        let quizzes: [CuratedQuiz]
    }

    private struct CuratedQuiz: Decodable {
        let saintID: String
        let sourceUrls: [String]
        let questions: [CuratedQuestion]
    }

    private struct CuratedQuestion: Decodable {
        let topic: String
        let prompt: String
        let correctAnswer: String
        let distractors: [String]
        let explanation: String
    }

    private static let quizzesBySaintID: [String: CuratedQuiz] = loadCatalog()

    static func hasQuiz(for saint: SaintEntry) -> Bool {
        quizzesBySaintID[saint.id] != nil
    }

    static func questions(for item: SaintCollectionItem) -> [SaintQuizQuestion] {
        guard let quiz = quizzesBySaintID[item.saint.id] else { return [] }
        let baseSeed = stableSeed(item.saint.id)

        return quiz.questions.enumerated().map { index, question in
            let correctIndex = positive(baseSeed &+ index &* 17) % 3
            var values = question.distractors
            values.insert(question.correctAnswer, at: correctIndex)
            return SaintQuizQuestion(
                prompt: question.prompt,
                options: values,
                correctIndex: correctIndex,
                explanation: question.explanation
            )
        }
    }

    private static func loadCatalog() -> [String: CuratedQuiz] {
        guard
            let url = Bundle.main.url(forResource: "saint-quizzes", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let catalog = try? JSONDecoder().decode(Catalog.self, from: data),
            catalog.schemaVersion == 1
        else {
            assertionFailure("The curated saint quiz catalog is missing or invalid.")
            return [:]
        }

        var result: [String: CuratedQuiz] = [:]
        for quiz in catalog.quizzes {
            guard validate(quiz) else {
                assertionFailure("Invalid curated quiz for saint ID: \(quiz.saintID)")
                continue
            }
            guard result[quiz.saintID] == nil else {
                assertionFailure("Duplicate curated quiz for saint ID: \(quiz.saintID)")
                continue
            }
            result[quiz.saintID] = quiz
        }
        return result
    }

    private static func validate(_ quiz: CuratedQuiz) -> Bool {
        guard
            !quiz.saintID.isEmpty,
            quiz.questions.count == 10,
            quiz.questions.first?.topic == "feast",
            !quiz.sourceUrls.isEmpty,
            quiz.sourceUrls.allSatisfy({ URL(string: $0)?.scheme == "https" }),
            Set(quiz.questions.map(\.topic)).count == quiz.questions.count
        else { return false }

        return quiz.questions.allSatisfy { question in
            let answers = [question.correctAnswer] + question.distractors
            return !question.topic.isEmpty
                && !question.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !question.explanation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && question.distractors.count == 2
                && answers.allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                && Set(answers.map(saintSearchKey)).count == 3
        }
    }

    private static func positive(_ value: Int) -> Int {
        value == Int.min ? Int.max : abs(value)
    }

    private static func stableSeed(_ value: String) -> Int {
        value.unicodeScalars.reduce(17) { partial, scalar in
            (partial &* 31) &+ Int(scalar.value)
        }
    }
}

private struct SaintCardQuizView: View {
    let item: SaintCollectionItem

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var collection = SaintCollectionStore.shared

    @State private var questionIndex = 0
    @State private var selectedIndex: Int?
    @State private var stage: Stage = .quiz
    @State private var questions: [SaintQuizQuestion]

    private enum Stage {
        case quiz
        case reveal
    }

    init(item: SaintCollectionItem) {
        self.item = item
        _questions = State(
            initialValue: SaintQuizFactory.questions(for: item)
        )
    }

    private var currentQuestion: SaintQuizQuestion? {
        guard questions.indices.contains(questionIndex) else { return nil }
        return questions[questionIndex]
    }

    private var palette: SaintCardPalette {
        .forRank(item.rank.id)
    }

    private var quizEyebrow: String {
        let key = saintSearchKey(item.saint.displayName)
        if key.hasPrefix("αγια ") || key.hasPrefix("οσια ") || key.hasPrefix("η αγια ") {
            return "ΓΝΩΡΙΣΕ ΤΗΝ ΑΓΙΑ"
        }
        if key.hasPrefix("αγιοι ") || key.hasPrefix("οσιοι ") || key.hasPrefix("οι αγιοι ") {
            return "ΓΝΩΡΙΣΕ ΤΟΥΣ ΑΓΙΟΥΣ"
        }
        return "ΓΝΩΡΙΣΕ ΤΟΝ ΑΓΙΟ"
    }

    var body: some View {
        ZStack {
            Paper.bg.ignoresSafeArea()

            RadialGradient(
                colors: [palette.accent.opacity(0.24), .clear],
                center: .top,
                startRadius: 20,
                endRadius: 520
            )
            .ignoresSafeArea()

            switch stage {
            case .quiz:
                quiz
            case .reveal:
                reveal
            }
        }
        .overlay(alignment: .topTrailing) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Paper.ink)
                    .frame(width: 44, height: 44)
                    .klimaxLiquidGlass(in: Circle())
            }
            .buttonStyle(.plain)
            .padding(.top, 10)
            .padding(.trailing, 16)
        }
        .onAppear {
            if questions.isEmpty {
                collection.collect(item.saint)
                stage = .reveal
            }
        }
    }

    private var quiz: some View {
        ScrollView {
            VStack(spacing: 22) {
                VStack(spacing: 7) {
                    Text(quizEyebrow)
                        .font(.system(size: 10, weight: .bold))
                        .tracking(2.5)
                        .foregroundStyle(palette.accent)

                    Text(item.saint.displayName)
                        .font(.system(size: 25, design: .serif))
                        .foregroundStyle(Paper.ink)
                        .multilineTextAlignment(.center)

                    HStack(spacing: 7) {
                        ForEach(questions.indices, id: \.self) { index in
                            Capsule()
                                .fill(index <= questionIndex ? palette.accent : Paper.ink.opacity(0.10))
                                .frame(width: index == questionIndex ? 28 : 9, height: 5)
                        }
                    }
                    .padding(.top, 5)
                }
                .padding(.horizontal, 38)

                if let question = currentQuestion {
                    VStack(spacing: 16) {
                        Text(question.prompt)
                            .font(.system(size: 22, weight: .semibold, design: .serif))
                            .foregroundStyle(Paper.ink)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)

                        VStack(spacing: 11) {
                            ForEach(question.options.indices, id: \.self) { index in
                                answerButton(
                                    question.options[index],
                                    index: index,
                                    correctIndex: question.correctIndex
                                )
                            }
                        }

                        if let selectedIndex {
                            if selectedIndex == question.correctIndex {
                                VStack(alignment: .leading, spacing: 7) {
                                    Label("Γιατί έχει σημασία", systemImage: "lightbulb.fill")
                                        .font(.system(size: 13, weight: .bold, design: .serif))
                                        .foregroundStyle(palette.accent)

                                    Text(question.explanation)
                                        .font(.system(size: 14, design: .serif))
                                        .foregroundStyle(Paper.ink)
                                        .lineSpacing(3)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(14)
                                .background(
                                    palette.accent.opacity(0.08),
                                    in: RoundedRectangle(cornerRadius: 15, style: .continuous)
                                )

                                Button {
                                    advance()
                                } label: {
                                    Text(questionIndex == questions.count - 1 ? "Φανέρωσε την κάρτα" : "Συνέχισε")
                                        .font(.system(size: 16, weight: .bold, design: .serif))
                                        .foregroundStyle(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .background(
                                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                .fill(palette.accent)
                                        )
                                }
                                .buttonStyle(CalmCardStyle())
                            } else {
                                Button {
                                    withAnimation(.easeInOut(duration: 0.18)) {
                                        self.selectedIndex = nil
                                    }
                                } label: {
                                    Text("Δοκίμασε ξανά")
                                        .font(.system(size: 15, weight: .semibold, design: .serif))
                                        .foregroundStyle(Paper.ink)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 13)
                                        .klimaxLiquidGlass(
                                            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(18)
                    .background(
                        Paper.card,
                        in: RoundedRectangle(cornerRadius: 22, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(palette.accent.opacity(0.24), lineWidth: 1)
                    )
                    .padding(.horizontal, 18)
                }
            }
            .padding(.top, 78)
            .padding(.bottom, 36)
        }
        .scrollIndicators(.hidden)
    }

    private func answerButton(
        _ text: String,
        index: Int,
        correctIndex: Int
    ) -> some View {
        let isSelected = selectedIndex == index
        let isCorrect = isSelected && index == correctIndex
        let isWrong = isSelected && index != correctIndex

        return Button {
            guard selectedIndex == nil else { return }
            withAnimation(.easeInOut(duration: 0.18)) {
                selectedIndex = index
            }
        } label: {
            HStack(alignment: .top, spacing: 11) {
                Image(systemName: isCorrect ? "checkmark.circle.fill" : (isWrong ? "xmark.circle.fill" : "circle"))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(
                        isCorrect ? palette.accent : (isWrong ? Color.red.opacity(0.68) : Paper.inkMute.opacity(0.55))
                    )

                Text(text)
                    .font(.system(size: 15, design: .serif))
                    .foregroundStyle(Paper.ink)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(isSelected ? palette.accent.opacity(0.10) : Paper.bg.opacity(0.72))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .stroke(
                        isCorrect ? palette.accent.opacity(0.65) : (isWrong ? Color.red.opacity(0.35) : Paper.hairline),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var reveal: some View {
        ScrollView {
            VStack(spacing: 18) {
                VStack(spacing: 6) {
                    Text("Η ΚΑΡΤΑ ΦΑΝΕΡΩΘΗΚΕ")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(2.4)
                        .foregroundStyle(palette.accent)

                    Text(item.saint.displayName)
                        .font(.system(size: 27, design: .serif))
                        .foregroundStyle(Paper.ink)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 30)

                SaintCardFace(
                    item: item,
                    isCollected: true,
                    collectedAt: collection.record(for: item.saint)?.collectedAt,
                    side: .front,
                    compact: false
                )
                .aspectRatio(0.68, contentMode: .fit)
                .frame(maxWidth: 310)
                .padding(.horizontal, 36)
                .shadow(color: palette.accent.opacity(0.24), radius: 26, x: 0, y: 16)
                .transition(.scale(scale: 0.84).combined(with: .opacity))

                Text("Η κάρτα φυλάχθηκε στη Συλλογή Αγίων.")
                    .font(.system(size: 14, design: .serif))
                    .foregroundStyle(Paper.inkMute)

                Button {
                    dismiss()
                } label: {
                    Text("Κράτησέ την")
                        .font(.system(size: 16, weight: .bold, design: .serif))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(palette.accent)
                        )
                }
                .buttonStyle(CalmCardStyle())
                .padding(.horizontal, 28)
            }
            .padding(.top, 70)
            .padding(.bottom, 34)
        }
        .scrollIndicators(.hidden)
    }

    private func advance() {
        guard let question = currentQuestion, selectedIndex == question.correctIndex else {
            return
        }

        if questionIndex == questions.count - 1 {
            collection.collect(item.saint)
            withAnimation(.spring(response: 0.58, dampingFraction: 0.84)) {
                stage = .reveal
            }
        } else {
            withAnimation(.easeInOut(duration: 0.22)) {
                questionIndex += 1
                selectedIndex = nil
            }
        }
    }
}
