import SwiftUI
import UIKit

struct SaintSayingsView: View {
    @AppStorage(SaintSayingFavorites.storageKey) private var favoriteData = Data()

    private var favorites: Binding<Set<String>> {
        Binding(get: { SaintSayingFavorites.decode(favoriteData) },
                set: { favoriteData = SaintSayingFavorites.encode($0) })
    }

    var body: some View {
        if let catalog = SaintSayingsCatalog.bundled {
            SaintSayingsGallery(catalog: catalog, favoriteIDs: favorites)
        } else {
            ContentUnavailableView("Οι λόγοι δεν είναι διαθέσιμοι", systemImage: "text.quote", description: Text("Δεν ήταν δυνατή η φόρτωση της συλλογής."))
        }
    }
}

private enum SayingSection: String, CaseIterable, Identifiable {
    case saint, mixed, favorites
    var id: String { rawValue }
    var title: String {
        switch self {
        case .saint: "Ανά άγιο"
        case .mixed: "Όλοι οι άγιοι"
        case .favorites: "Αγαπημένα"
        }
    }
}

private struct SayingSelection: Identifiable {
    let id: String
    let sayings: [SaintSaying]
}

private struct SaintSayingsGallery: View {
    let catalog: SaintSayingsCatalog
    @Binding var favoriteIDs: Set<String>
    @State private var saintID: String
    @State private var categoryID: String?
    @State private var query = ""
    @State private var section: SayingSection = .saint
    @State private var returnSection: SayingSection = .saint
    @State private var showsFeed = false
    @State private var selection: SayingSelection?
    @Environment(\.dynamicTypeSize) private var typeSize

    init(catalog: SaintSayingsCatalog, favoriteIDs: Binding<Set<String>>) {
        self.catalog = catalog
        _favoriteIDs = favoriteIDs
        _saintID = State(initialValue: catalog.saints[0].id)
    }

    private var saint: SayingSaint { catalog.saints.first { $0.id == saintID } ?? catalog.saints[0] }
    private var baseCollection: [SaintSaying] {
        catalog.collection(saintID: section == .saint ? saintID : nil,
                           favoriteIDs: section == .favorites ? favoriteIDs : nil)
    }
    private var saintCategories: [SayingCategory] {
        let ids = Set(baseCollection.map(\.categoryID))
        return catalog.categories.filter { ids.contains($0.id) }
    }
    private var displayed: [SaintSaying] {
        catalog.collection(saintID: section == .saint ? saintID : nil,
                           categoryID: categoryID, query: query,
                           favoriteIDs: section == .favorites ? favoriteIDs : nil)
    }

    var body: some View {
        GeometryReader { geometry in
            let width = max(240, geometry.size.width - 40)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 22) {
                    Picker("Συλλογή αποφθεγμάτων", selection: $section) {
                        ForEach(SayingSection.allCases) { item in Text(item.title).tag(item) }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("sayings.section")
                    introduction
                    search
                    categories
                    if displayed.isEmpty {
                        if section == .favorites && baseCollection.isEmpty {
                            ContentUnavailableView("Αγαπημένα αποφθέγματα", systemImage: "heart",
                                description: Text("Πάτησε την καρδιά σε έναν λόγο για να τον βρίσκεις εδώ."))
                        } else {
                            ContentUnavailableView.search(text: query)
                        }
                    } else {
                        mosaic(width: width)
                    }
                }
                .padding(.horizontal, 20).padding(.top, 90).padding(.bottom, 115)
            }
            .scrollDismissesKeyboard(.interactively)
            .fullScreenCover(item: $selection) { selected in
                SaintSayingReader(catalog: catalog, sayings: selected.sayings, initialID: selected.id,
                                  favoriteIDs: $favoriteIDs)
                    .presentationBackground(.clear)
            }
            .fullScreenCover(isPresented: $showsFeed, onDismiss: { section = returnSection }) {
                SaintSayingsFeed(catalog: catalog, favoriteIDs: $favoriteIDs) { destination in
                    returnSection = destination
                    showsFeed = false
                }
            }
        }
        .onChange(of: section) { _, next in
            categoryID = nil; query = ""
            if next == .mixed { showsFeed = true }
        }
        .onChange(of: favoriteIDs) { _, _ in
            if let id = categoryID, !saintCategories.contains(where: { $0.id == id }) { categoryID = nil }
        }
    }

    @ViewBuilder private var introduction: some View {
        if section == .favorites {
            VStack(alignment: .leading, spacing: 7) {
                Text("ΟΙ ΛΟΓΟΙ ΠΟΥ ΚΡΑΤΑΣ").font(.system(size: 10, weight: .semibold)).tracking(2).foregroundStyle(Paper.gold)
                Text("Αγαπημένα αποφθέγματα").font(.system(size: 27, design: .serif)).foregroundStyle(Paper.ink)
                Text("\(baseCollection.count) αποθηκευμένοι λόγοι · όλοι οι άγιοι").font(.subheadline).foregroundStyle(Paper.inkMute)
            }
        } else {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("ΛΟΓΙΑ ΠΟΥ ΜΕΝΟΥΝ").font(.system(size: 10, weight: .semibold)).tracking(2.5).foregroundStyle(Paper.gold)
                    Menu {
                        ForEach(catalog.saints) { saint in
                            Button(saint.shortName) { saintID = saint.id; categoryID = nil }
                        }
                    } label: { Label(saint.shortName, systemImage: "chevron.down") }
                    .font(.system(size: 26, weight: .semibold, design: .serif)).foregroundStyle(Paper.ink)
                    Text("\(baseCollection.count) λόγοι · \(saintCategories.count) θέματα")
                        .font(.subheadline).foregroundStyle(Paper.inkMute)
                }
                Spacer(minLength: 0)
                Image(catalog.photos.first { $0.id == saint.photoID }?.asset ?? catalog.photos[0].asset)
                    .resizable().scaledToFill().frame(width: 62, height: 78)
                    .clipShape(RoundedRectangle(cornerRadius: 17)).accessibilityHidden(true)
            }
        }
    }

    private var search: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass").foregroundStyle(Paper.inkMute)
            TextField("Βρες έναν λόγο…", text: $query).autocorrectionDisabled()
                .accessibilityIdentifier("sayings.search")
            if !query.isEmpty {
                Button { query = "" } label: { Image(systemName: "xmark.circle.fill") }
                    .accessibilityLabel("Καθαρισμός αναζήτησης")
            }
        }
        .font(.subheadline).padding(13)
        .background(Paper.card, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Paper.hairline, lineWidth: 0.5))
    }

    private var categories: some View {
        Menu {
            Picker("Κατηγορία", selection: $categoryID) {
                Text("Όλες οι κατηγορίες").tag(nil as String?)
                ForEach(saintCategories) { category in Text(category.title).tag(Optional(category.id)) }
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "line.3.horizontal.decrease").foregroundStyle(Paper.gold)
                Text(saintCategories.first { $0.id == categoryID }?.title ?? "Όλες οι κατηγορίες")
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 8)
                Image(systemName: "chevron.down").foregroundStyle(Paper.gold)
            }
            .font(.subheadline).foregroundStyle(Paper.ink).padding(14)
            .background(Paper.card, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Paper.hairline, lineWidth: 0.5))
        }
        .accessibilityIdentifier("sayings.category.menu")
    }

    @ViewBuilder private func mosaic(width: CGFloat) -> some View {
        let sayings = displayed
        ForEach(Array(stride(from: 0, to: sayings.count, by: 5)), id: \.self) { start in
            let group = Array(sayings.dropFirst(start).prefix(5))
            VStack(spacing: 12) {
                tile(group[0], width: width, imageHeight: imageHeight(group[0], width: width),
                     footerHeight: footerHeight(group, width: width, prominent: true), prominent: true, sayings: sayings)
                if typeSize.isAccessibilitySize {
                    ForEach(group.dropFirst()) { saying in
                        tile(saying, width: width, imageHeight: imageHeight(saying, width: width),
                             footerHeight: footerHeight([saying], width: width, prominent: true), prominent: true, sayings: sayings)
                    }
                } else {
                    ForEach(Array(stride(from: 1, to: group.count, by: 2)), id: \.self) { rowStart in
                        let pair = Array(group.dropFirst(rowStart).prefix(2))
                        let side = (width - 12) / 2
                        let sharedImageHeight = pair.map { imageHeight($0, width: side) }.max() ?? side
                        let sharedFooterHeight = footerHeight(pair, width: side, prominent: false)
                        HStack(alignment: .top, spacing: 12) {
                            ForEach(pair) { saying in
                                tile(saying, width: side, imageHeight: sharedImageHeight,
                                     footerHeight: sharedFooterHeight, prominent: false, sayings: sayings)
                            }
                            if pair.count == 1 { Color.clear.frame(width: side, height: 0).accessibilityHidden(true) }
                        }
                    }
                }
            }
        }
    }

    private func imageHeight(_ saying: SaintSaying, width: CGFloat) -> CGFloat {
        let photo = catalog.photo(for: saying)
        return width * photo.height / photo.width
    }

    private func footerHeight(_ sayings: [SaintSaying], width: CGFloat, prominent: Bool) -> CGFloat {
        let font = UIFont.preferredFont(forTextStyle: prominent ? .caption1 : .caption2)
        let height = sayings.map { saying in
            let text = catalog.category(for: saying).title as NSString
            return text.boundingRect(with: CGSize(width: max(50, width - 48), height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: [.font: font], context: nil).height
        }.max() ?? 20
        return ceil(height) + 26 + (section == .favorites ? 20 : 0)
    }

    private func tile(_ saying: SaintSaying, width: CGFloat, imageHeight: CGFloat, footerHeight: CGFloat,
                      prominent: Bool, sayings: [SaintSaying]) -> some View {
        let photo = catalog.photo(for: saying)
        let size = CGSize(width: width, height: imageHeight)
        let imageRect = photo.cardImageRect(in: size)
        let textRegion = photo.cardTextRegion(in: size)
        let start = textRegion.minY
        let available = textRegion.height
        let fontSize: CGFloat = prominent ? 24 : 17
        let inset: CGFloat = min(prominent ? 22 : 14, max(4, available - 8 - fontSize * 1.3))
        return ZStack(alignment: .topTrailing) {
            Button { selection = SayingSelection(id: saying.id, sayings: sayings) } label: {
                VStack(spacing: 0) {
                    ZStack(alignment: .topLeading) {
                        Color.black
                        Image(photo.asset).resizable().scaledToFit()
                            .frame(width: imageRect.width, height: imageRect.height)
                            .offset(x: imageRect.minX)
                            .frame(width: width, height: imageHeight, alignment: .topLeading)
                        if photo.fillsCard == true {
                            LinearGradient(stops: [
                                .init(color: .clear, location: max(0, start / imageHeight - 0.08)),
                                .init(color: .black.opacity(0.67), location: start / imageHeight),
                                .init(color: .black.opacity(0.8), location: 1)
                            ], startPoint: .top, endPoint: .bottom)
                        } else {
                            LinearGradient(colors: [.clear, .black.opacity(0.75)], startPoint: .center, endPoint: .bottom)
                        }
                        Text(saying.text).font(.system(size: fontSize, weight: .medium, design: .serif))
                            .foregroundStyle(.white).lineSpacing(2)
                            .lineLimit(max(1, Int((available - inset - 8) / (fontSize * 1.3))))
                            .padding(.horizontal, inset).padding(.top, inset)
                            .frame(width: width, height: max(0, available - 8), alignment: .topLeading)
                            .clipped().offset(y: start)
                    }.frame(width: width, height: imageHeight).clipped()
                    HStack(alignment: .top, spacing: 7) {
                        Image(systemName: catalog.category(for: saying).symbol).foregroundStyle(Paper.gold)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(catalog.category(for: saying).title)
                            if section == .favorites {
                                Text(catalog.saint(for: saying).shortName).font(.caption2).foregroundStyle(Paper.inkMute)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .font(prominent ? .caption : .caption2).foregroundStyle(Paper.ink)
                    .padding(.horizontal, 12).padding(.vertical, 11)
                    .frame(width: width, height: footerHeight, alignment: .topLeading).background(Paper.card)
                }
            }
            .buttonStyle(CalmCardStyle())
            .accessibilityLabel("\(catalog.category(for: saying).title). \(saying.text)")
            .accessibilityIdentifier("sayings.card.\(saying.id)")
            SayingFavoriteButton(id: saying.id, favoriteIDs: $favoriteIDs)
                .padding(10)
        }
        .frame(width: width)
        .clipShape(RoundedRectangle(cornerRadius: prominent ? 27 : 23))
        .overlay(RoundedRectangle(cornerRadius: prominent ? 27 : 23).stroke(Paper.hairline, lineWidth: 0.5))
    }
}

private struct SayingFavoriteButton: View {
    let id: String
    @Binding var favoriteIDs: Set<String>
    var liked: (() -> Void)? = nil
    private var isFavorite: Bool { favoriteIDs.contains(id) }
    var body: some View {
        Button {
            if isFavorite { favoriteIDs.remove(id) }
            else { favoriteIDs.insert(id); liked?() }
        } label: {
            Image(systemName: isFavorite ? "heart.fill" : "heart")
                .font(.system(size: 19, weight: .medium)).foregroundStyle(.white)
                .frame(width: 42, height: 42)
                .background(isFavorite ? Paper.gold : Color.black.opacity(0.45), in: Circle())
                .overlay(Circle().stroke(.white.opacity(0.25), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isFavorite ? "Αφαίρεση από τα αγαπημένα" : "Προσθήκη στα αγαπημένα")
        .accessibilityValue(isFavorite ? "Αποθηκευμένο" : "Μη αποθηκευμένο")
        .accessibilityIdentifier("sayings.favorite.\(id)")
    }
}

/// One edge-to-edge photograph, shared by the tile and its expanded reader.
/// A translucent scrim keeps text legible without replacing any image area.
private struct SayingArtwork: View {
    let photo: SayingPhoto

    var body: some View {
        GeometryReader { geometry in
            let boundary = photo.textBoundary(in: geometry.size) / geometry.size.height
            Image(photo.asset).resizable().scaledToFill()
                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
                .clipped()
                .overlay {
                    if photo.textStart != nil {
                        let start = photo.textRegion(in: geometry.size).minY / geometry.size.height
                        LinearGradient(stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .clear, location: max(0, start - 0.08)),
                            .init(color: .black.opacity(0.65), location: start),
                            .init(color: .black.opacity(0.80), location: 1)
                        ], startPoint: .top, endPoint: .bottom)
                    } else {
                        LinearGradient(stops: [
                            .init(color: .black.opacity(0.60), location: 0),
                            .init(color: .black.opacity(0.48), location: max(0, boundary - 0.03)),
                            .init(color: .clear, location: min(1, boundary + 0.18)),
                            .init(color: .clear, location: 0.85),
                            .init(color: .black.opacity(0.25), location: 1)
                        ], startPoint: .top, endPoint: .bottom)
                    }
            }
        }.accessibilityHidden(true)
    }
}

private struct SaintSayingReader: View {
    let catalog: SaintSayingsCatalog
    let sayings: [SaintSaying]
    @State private var currentID: String
    @Binding var favoriteIDs: Set<String>
    @State private var dragDown: CGFloat = 0
    @State private var source: SaintSaying?
    @State private var textAtTop = true
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(catalog: SaintSayingsCatalog, sayings: [SaintSaying], initialID: String, favoriteIDs: Binding<Set<String>>) {
        self.catalog = catalog
        self.sayings = sayings
        _favoriteIDs = favoriteIDs
        _currentID = State(initialValue: initialID)
    }

    private var index: Int { sayings.firstIndex { $0.id == currentID } ?? 0 }
    private var current: SaintSaying { sayings[index] }
    private var glass: Bool { if #available(iOS 26.0, *) { return true }; return false }

    var body: some View {
        GeometryReader { geometry in
            let viewport = CGSize(width: geometry.size.width, height: geometry.size.height + geometry.safeAreaInsets.top + geometry.safeAreaInsets.bottom)
            let frame = PrayerInvitationCardLayout(viewport: viewport, safeAreaTop: geometry.safeAreaInsets.top, safeAreaBottom: geometry.safeAreaInsets.bottom, isLiquidGlass: glass).frame
            ZStack(alignment: .top) {
                Color.black.opacity(0.22 * max(0.35, 1 - dragDown / 500))
                    .contentShape(Rectangle()).onTapGesture { dismiss() }.accessibilityHidden(true)
                card(size: frame.size)
                    .offset(y: dragDown)
                    .padding(.top, frame.minY)
            }
            .frame(width: viewport.width, height: viewport.height)
            .offset(y: -geometry.safeAreaInsets.top)
        }
        .sheet(item: $source) { saying in sourceDetails(saying) }
    }

    private func card(size: CGSize) -> some View {
        TabView(selection: $currentID) {
            // Native left-to-right paging: swipe left for the next saying.
            // The next button updates this same selection, in the same order.
            ForEach(sayings) { saying in
                readerPage(saying, size: size).tag(saying.id)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(width: size.width, height: size.height)
        .overlay(alignment: .top) {
            HStack {
                Text(catalog.saint(for: current).shortName)
                    .font(.system(size: 12, weight: .medium)).foregroundStyle(.white.opacity(0.7))
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 16, weight: .semibold))
                        .frame(width: 44, height: 44).foregroundStyle(.primary)
                        .glassCircleFallback(shape: Circle())
                }.accessibilityLabel("Κλείσιμο").accessibilityIdentifier("sayings.reader.close")
            }.padding(.horizontal, 18).padding(.top, 18)
        }
        .overlay(alignment: .bottom) {
            HStack {
                Button { source = current } label: {
                    Label(current.sourceChecked ? "Πηγή" : "Πηγή · υπό έλεγχο", systemImage: "info.circle")
                        .font(.system(size: 11, weight: .medium)).padding(12)
                        .foregroundStyle(.primary).glassCircleFallback(shape: Capsule())
                }.accessibilityIdentifier("sayings.reader.source")
                SayingFavoriteButton(id: current.id, favoriteIDs: $favoriteIDs)
                Spacer(minLength: 4)
                Text("\(index + 1) / \(sayings.count)").font(.system(size: 11, weight: .semibold)).monospacedDigit()
                    .padding(12).foregroundStyle(.primary).glassCircleFallback(shape: Capsule(), interactive: false)
                Button { advance() } label: {
                    Image(systemName: "arrow.right").font(.system(size: 16, weight: .semibold))
                        .frame(width: 44, height: 44).foregroundStyle(.primary).glassCircleFallback(shape: Circle())
                }.disabled(index == sayings.count - 1).opacity(index == sayings.count - 1 ? 0.4 : 1)
                    .accessibilityLabel("Επόμενος λόγος").accessibilityIdentifier("sayings.reader.next")
            }.padding(18)
        }
        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 34).strokeBorder(.white.opacity(0.2), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.24), radius: 22, y: 12)
        .simultaneousGesture(DragGesture(minimumDistance: 18).onChanged { value in
            guard textAtTop, value.translation.height > abs(value.translation.width) * 1.5 else { return }
            dragDown = max(0, value.translation.height)
        }.onEnded { value in
            if dragDown > 90 || (dragDown > 25 && value.predictedEndTranslation.height > 180) {
                dismiss()
            } else {
                withAnimation(reduceMotion ? nil : .smooth(duration: 0.25)) { dragDown = 0 }
            }
        })
        .onChange(of: currentID) { _, _ in textAtTop = true }
        .accessibilityAction(named: "Επόμενος λόγος") { advance() }
        .accessibilityAction(.escape) { dismiss() }
    }

    @ViewBuilder private func readerPage(_ saying: SaintSaying, size: CGSize) -> some View {
        if catalog.photo(for: saying).textStart != nil {
            portraitReaderPage(saying, size: size)
        } else {
            originalReaderPage(saying, size: size)
        }
    }

    private func portraitReaderPage(_ saying: SaintSaying, size: CGSize) -> some View {
        let photo = catalog.photo(for: saying)
        let imageHeight = min(size.height * 0.48, size.width * photo.height / photo.width)
        return VStack(spacing: 0) {
            Image(photo.asset).resizable().scaledToFit()
                .frame(width: size.width, height: imageHeight)
                .background(Paper.bg)
                .accessibilityHidden(true)
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Label(catalog.category(for: saying).title, systemImage: catalog.category(for: saying).symbol)
                        .font(.subheadline).foregroundStyle(Paper.gold)
                    Text(saying.text)
                        .font(.system(.title2, design: .serif, weight: .medium))
                        .lineSpacing(5).foregroundStyle(Paper.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("sayings.reader.text")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(24)
            }
            .onScrollGeometryChange(for: Bool.self) { $0.contentOffset.y <= 0 } action: { _, atTop in
                if saying.id == currentID { textAtTop = atTop }
            }
        }
        .padding(.top, 70).padding(.bottom, 82)
        .frame(width: size.width, height: size.height)
        .background(Paper.card)
    }

    private func originalReaderPage(_ saying: SaintSaying, size: CGSize) -> some View {
        let photo = catalog.photo(for: saying)
        let region = photo.textRegion(in: size)
        let textHeight = region.height - 14
        let top = photo.textStart == nil ? 74 : region.minY + 12
        let readingHeight = photo.textStart == nil ? max(30, textHeight - 74) : max(0, size.height - top - 82)
        return ZStack(alignment: .top) {
            SayingArtwork(photo: photo)
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if textHeight > 210 {
                        Text(catalog.category(for: saying).title.uppercased())
                            .font(.system(size: 10, weight: .semibold)).tracking(1.5).foregroundStyle(.white.opacity(0.8))
                    }
                    Text(saying.text)
                        .font(.system(.title2, design: .serif, weight: .medium)).lineSpacing(5).foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("sayings.reader.text")
                }.frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 25).padding(.bottom, 12)
            }
            .scrollIndicators(.visible)
            .onScrollGeometryChange(for: Bool.self) { $0.contentOffset.y <= 0 } action: { _, atTop in
                if saying.id == currentID { textAtTop = atTop }
            }
            .frame(height: readingHeight)
            .padding(.top, top)
        }
        .frame(width: size.width, height: size.height)
        .clipped()
    }

    private func advance() {
        guard index + 1 < sayings.count else { return }
        withAnimation(reduceMotion ? nil : .smooth(duration: 0.3)) { currentID = sayings[index + 1].id }
    }

    private func sourceDetails(_ saying: SaintSaying) -> some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Πηγή του αποσπάσματος").font(.title2.bold())
                    Text(saying.sourceStatus).font(.subheadline.weight(.semibold))
                    if let url = URL(string: saying.source), ["https", "http"].contains(url.scheme) {
                        Link(destination: url) { Label("Άνοιγμα πηγής", systemImage: "arrow.up.right.square") }
                    } else { Text(saying.source).font(.body) }
                }.frame(maxWidth: .infinity, alignment: .leading).padding(24)
            }
            .navigationTitle("Πηγή").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Κλείσιμο") { source = nil } } }
        }.presentationDetents([.medium, .large])
    }
}

/// The mixed collection is presented over the app chrome, without changing the
/// surrounding tab/navigation architecture. Its shuffle is stable until requested.
private struct SaintSayingsFeed: View {
    let catalog: SaintSayingsCatalog
    @Binding var favoriteIDs: Set<String>
    let leave: (SayingSection) -> Void
    @State private var orderedIDs: [String]
    @State private var categoryID: String?
    @State private var query = ""
    @State private var currentID: String?
    @State private var showsFilters = false
    @State private var source: SaintSaying?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(catalog: SaintSayingsCatalog, favoriteIDs: Binding<Set<String>>, leave: @escaping (SayingSection) -> Void) {
        self.catalog = catalog
        _favoriteIDs = favoriteIDs
        self.leave = leave
        let ids = catalog.sayings.map(\.id).shuffled()
        _orderedIDs = State(initialValue: ids)
        _currentID = State(initialValue: ids.first)
    }

    private var displayed: [SaintSaying] {
        catalog.collection(categoryID: categoryID, query: query, order: orderedIDs)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                Color.black
                if displayed.isEmpty {
                    ContentUnavailableView.search(text: query).foregroundStyle(.white)
                } else {
                    ScrollView(.vertical) {
                        LazyVStack(spacing: 0) {
                            ForEach(displayed) { saying in
                                SaintSayingReel(catalog: catalog, saying: saying, favoriteIDs: $favoriteIDs,
                                    position: (displayed.firstIndex(where: { $0.id == saying.id }) ?? 0) + 1,
                                    count: displayed.count, safeTop: max(geometry.safeAreaInsets.top, 54),
                                    safeBottom: max(geometry.safeAreaInsets.bottom, 24),
                                    showSource: { source = saying })
                                    .frame(width: geometry.size.width, height: geometry.size.height)
                                    .id(saying.id)
                            }
                        }.scrollTargetLayout()
                    }
                    .scrollTargetBehavior(.paging)
                    .scrollPosition(id: $currentID)
                    .scrollIndicators(.hidden)
                    .scrollDismissesKeyboard(.interactively)
                    .accessibilityIdentifier("sayings.feed")
                }
                controls.padding(.horizontal, 14).padding(.top, max(geometry.safeAreaInsets.top, 54) + 8)
            }
        }
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
        .sheet(item: $source) { saying in
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("Πηγή του αποσπάσματος").font(.title2.bold())
                        Text(saying.sourceStatus).font(.subheadline.weight(.semibold))
                        if let url = URL(string: saying.source), ["https", "http"].contains(url.scheme) {
                            Link("Άνοιγμα πηγής", destination: url)
                        } else { Text(saying.source) }
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(24)
                }
                .navigationTitle("Πηγή").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Κλείσιμο") { source = nil } } }
            }.presentationDetents([.medium, .large])
        }
        .onChange(of: query) { _, _ in currentID = displayed.first?.id }
        .onChange(of: categoryID) { _, _ in currentID = displayed.first?.id }
        .accessibilityAction(named: "Επόμενος λόγος") { advance(1) }
        .accessibilityAction(named: "Προηγούμενος λόγος") { advance(-1) }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack(alignment: .leading) {
                Button { leave(.saint) } label: {
                    Image(systemName: "chevron.left").frame(width: 36, height: 36)
                }.accessibilityLabel("Έξοδος από την προβολή πλήρους οθόνης")
                HStack(spacing: 8) {
                    Button("Ανά άγιο") { leave(.saint) }
                    Text("Όλοι οι άγιοι").padding(9).background(.white.opacity(0.2), in: Capsule())
                    Button("Αγαπημένα") { leave(.favorites) }
                }
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 40)
            }
            .font(.system(size: 11, weight: .medium)).foregroundStyle(.white)
            .padding(6).background(.black.opacity(0.4), in: Capsule())

            Button {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { showsFilters.toggle() }
            } label: {
                Label("Φίλτρα και αναζήτηση", systemImage: "line.3.horizontal.decrease")
                    .font(.system(size: 11, weight: .medium)).padding(11)
                    .foregroundStyle(.white).background(.black.opacity(0.45), in: Capsule())
            }
            .accessibilityIdentifier("sayings.feed.filters")
            if showsFilters {
                VStack(spacing: 12) {
                    TextField("Βρες έναν λόγο…", text: $query).autocorrectionDisabled()
                        .textFieldStyle(.roundedBorder).accessibilityIdentifier("sayings.feed.search")
                    HStack {
                        Menu {
                            Picker("Κατηγορία", selection: $categoryID) {
                                Text("Όλες οι κατηγορίες").tag(nil as String?)
                                ForEach(catalog.categories) { category in
                                    Text(category.title).tag(Optional(category.id))
                                }
                            }
                        } label: {
                            Label(catalog.categories.first { $0.id == categoryID }?.title ?? "Όλες οι κατηγορίες", systemImage: "chevron.down")
                                .font(.subheadline).multilineTextAlignment(.leading)
                        }.accessibilityIdentifier("sayings.feed.category")
                        Spacer(minLength: 8)
                        Button {
                            orderedIDs.shuffle(); currentID = displayed.first?.id
                            showsFilters = false
                        } label: { Image(systemName: "shuffle").frame(width: 44, height: 44) }
                        .accessibilityLabel("Ανακάτεμα")
                    }
                }
                .padding(16).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
            }
        }.tint(.white)
    }

    private func advance(_ direction: Int) {
        guard let id = currentID, let index = displayed.firstIndex(where: { $0.id == id }),
              displayed.indices.contains(index + direction) else { return }
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) { currentID = displayed[index + direction].id }
    }
}

private struct SaintSayingReel: View {
    let catalog: SaintSayingsCatalog
    let saying: SaintSaying
    @Binding var favoriteIDs: Set<String>
    let position: Int
    let count: Int
    let safeTop: CGFloat
    let safeBottom: CGFloat
    let showSource: () -> Void
    @State private var showsHeart = false
    @State private var heartTask: Task<Void, Never>?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .title2) private var textSize = 25.0

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let photo = catalog.photo(for: saying)
            let textWidth = max(120, size.width - 94)
            let topClearance = safeTop + 140
            let available = max(100, size.height - topClearance - safeBottom - 135)
            let height = min(measuredTextHeight(width: textWidth), available)
            ZStack {
                Color.black
                let scale = max(size.width / photo.width, size.height / photo.height)
                Image(photo.asset).resizable().scaledToFill()
                    .frame(width: photo.width * scale, height: photo.height * scale)
                    .offset(x: (size.width - photo.width * scale) * (photo.width > photo.height ? 0.75 : 0.5))
                    .frame(width: size.width, height: size.height, alignment: .topLeading)
                    .clipped()
                    .overlay(LinearGradient(stops: [
                        .init(color: .black.opacity(0.4), location: 0),
                        .init(color: .clear, location: 0.32),
                        .init(color: .black.opacity(0.35), location: 0.52),
                        .init(color: .black.opacity(0.9), location: 1)
                    ], startPoint: .top, endPoint: .bottom))
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) { like() }
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 10) {
                    Spacer(minLength: topClearance)
                    Text(catalog.saint(for: saying).shortName)
                        .font(.system(size: 12)).foregroundStyle(.white.opacity(0.75))
                    completeText(height: height, width: textWidth, available: available)
                        .simultaneousGesture(TapGesture(count: 2).onEnded { like() })
                    Label(catalog.category(for: saying).title, systemImage: catalog.category(for: saying).symbol)
                        .font(.system(size: 12)).foregroundStyle(.white.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                    Button(action: showSource) {
                        Label("Πηγή", systemImage: "info.circle").font(.system(size: 11))
                    }.foregroundStyle(.white.opacity(0.75))
                }
                .padding(.leading, 23).padding(.trailing, 70).padding(.bottom, safeBottom + 12)
                .frame(width: size.width, height: size.height, alignment: .bottomLeading)

                VStack {
                    HStack {
                        Text("\(position) / \(count)").font(.system(size: 10, weight: .medium)).monospacedDigit()
                            .padding(8).background(.black.opacity(0.4), in: Capsule())
                        Spacer()
                    }.padding(.top, safeTop + 110)
                    Spacer()
                    HStack {
                        Spacer()
                        SayingFavoriteButton(id: saying.id, favoriteIDs: $favoriteIDs, liked: burst)
                    }.padding(.bottom, safeBottom + 160)
                }.foregroundStyle(.white).padding(.horizontal, 15)

                Image(systemName: "heart.fill")
                    .font(.system(size: 96)).foregroundStyle(.white.opacity(0.65))
                    .shadow(color: .black.opacity(0.2), radius: 10, y: 3)
                    .scaleEffect(showsHeart ? 1 : (reduceMotion ? 1 : 0.4))
                    .opacity(showsHeart ? 1 : 0)
                    .allowsHitTesting(false).accessibilityHidden(true)
            }
            .frame(width: size.width, height: size.height).clipped()
        }
        .accessibilityIdentifier("sayings.reel.\(saying.id)")
        .accessibilityAction(named: "Προσθήκη στα αγαπημένα") { like() }
        .onDisappear { heartTask?.cancel(); showsHeart = false }
    }

    @ViewBuilder private func completeText(height: CGFloat, width: CGFloat, available: CGFloat) -> some View {
        if measuredTextHeight(width: width) > available {
            ScrollView(.vertical) {
                quoteText
            }
            .scrollBounceBehavior(.basedOnSize)
            .frame(height: height)
        } else {
            quoteText
        }
    }

    private var quoteText: some View {
        Text(saying.text)
            .font(.system(size: textSize, weight: .medium, design: .serif))
            .lineSpacing(5).foregroundStyle(.white)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier("sayings.reel.text.\(saying.id)")
    }

    private func measuredTextHeight(width: CGFloat) -> CGFloat {
        // Reserve a little extra space for serif glyph metrics and Dynamic Type.
        let paragraph = NSMutableParagraphStyle(); paragraph.lineSpacing = 5
        let base = UIFont.systemFont(ofSize: textSize, weight: .medium)
        let font = base.fontDescriptor.withDesign(.serif).map { UIFont(descriptor: $0, size: textSize) } ?? base
        return ceil((saying.text as NSString).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font, .paragraphStyle: paragraph], context: nil).height) + 12
    }

    private func like() {
        // Double-tap is idempotent; only the explicit heart button can unlike.
        favoriteIDs.insert(saying.id)
        burst()
    }

    private func burst() {
        heartTask?.cancel()
        withAnimation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.6)) { showsHeart = true }
        heartTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(650))
            guard !Task.isCancelled else { return }
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) { showsHeart = false }
        }
    }
}
