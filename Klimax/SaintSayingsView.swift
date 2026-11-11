import SwiftUI
import UIKit
import CoreImage

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
    @State private var sharing: SaintSaying?
    @State private var saintID: String
    @State private var categoryID: String?
    @State private var query = ""
    @State private var section: SayingSection = .saint
    @State private var showsFeed = false
    @State private var selection: SayingSelection?
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
                    LazyVStack(alignment: .leading, spacing: 18) {
                        introduction
                        HStack(spacing: 12) {
                            search
                            Button { showsFeed = true } label: {
                                Label("Ροή", systemImage: "rectangle.portrait.on.rectangle.portrait")
                                    .font(.system(size: 13, weight: .medium)).padding(.horizontal, 14).frame(height: 48)
                                    .foregroundStyle(Paper.gold).athosGlass(in: Capsule())
                            }
                            .accessibilityLabel("Κάθετη προβολή της συλλογής")
                            .accessibilityIdentifier("sayings.openFeed")
                        }
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
                    .id(section).transition(.opacity)
                }
                .padding(.horizontal, 20).padding(.top, 90).padding(.bottom, 115)
            }
            .scrollDismissesKeyboard(.interactively)
            .fullScreenCover(item: $selection) { selected in
                SaintSayingReader(catalog: catalog, sayings: selected.sayings, initialID: selected.id,
                                  favoriteIDs: $favoriteIDs)
                    .presentationBackground(.clear)
            }
            .fullScreenCover(isPresented: $showsFeed) {
                SaintSayingsFeed(catalog: catalog, favoriteIDs: $favoriteIDs,
                    section: $section, saintID: $saintID, categoryID: $categoryID, query: $query) { showsFeed = false }
            }
            .sheet(item: $sharing) { saying in
                SaintSayingSharePreview(catalog: catalog, saying: saying)
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: section)
        .onChange(of: section) { _, _ in
            categoryID = nil; query = ""
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
        } else if section == .mixed {
            VStack(alignment: .leading, spacing: 7) {
                Text("ΛΟΓΙΑ ΠΟΥ ΜΑΣ ΕΝΩΝΟΥΝ").font(.system(size: 10, weight: .semibold)).tracking(2).foregroundStyle(Paper.gold)
                Text("Όλοι οι άγιοι").font(.system(size: 27, design: .serif)).foregroundStyle(Paper.ink)
                Text("\(baseCollection.count) λόγοι · \(catalog.saints.count) άγιοι").font(.subheadline).foregroundStyle(Paper.inkMute)
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
                        let sharedImageHeight = max(side * 5 / 3, pair.map { imageHeight($0, width: side) }.max() ?? side)
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
        let textRegion: CGRect
        if prominent {
            textRegion = photo.cardTextRegion(in: size)
        } else {
            let top = max(114, imageHeight * CGFloat(photo.textStart ?? 0.62))
            textRegion = CGRect(x: 0, y: top, width: width, height: max(0, imageHeight - top))
        }
        let start = textRegion.minY
        let available = textRegion.height
        let fontSize: CGFloat = prominent ? 24 : 17
        let inset: CGFloat = min(prominent ? 22 : 14, max(4, available - 8 - fontSize * 1.3))
        return ZStack(alignment: .topTrailing) {
            Button { selection = SayingSelection(id: saying.id, sayings: sayings) } label: {
                VStack(spacing: 0) {
                    ZStack(alignment: .topLeading) {
                        Color.clear
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
                                Text(catalog.saint(for: saying).shortName).font(.caption2).foregroundStyle(.white.opacity(0.7))
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .font(prominent ? .caption : .caption2).foregroundStyle(.white.opacity(0.9))
                    .padding(.horizontal, 12).padding(.vertical, 11)
                    .frame(width: width, height: footerHeight, alignment: .topLeading)
                }
                .background { SayingArtwork(photo: photo).allowsHitTesting(false) }
                .contentShape(Rectangle())
            }
            .buttonStyle(CalmCardStyle())
            .accessibilityLabel("\(catalog.category(for: saying).title). \(saying.text)")
            .accessibilityIdentifier("sayings.card.\(saying.id)")
        }
        .frame(width: width)
        .overlay(alignment: .topTrailing) {
            // Separate buttons above the card's open action; no transparent
            // top padding spans another control's hit area.
            VStack(spacing: 8) {
                SayingFavoriteButton(id: saying.id, favoriteIDs: $favoriteIDs)
                SayingShareButton(id: saying.id) { sharing = saying }
            }.padding(10).zIndex(1)
        }
        .clipShape(RoundedRectangle(cornerRadius: prominent ? 27 : 23))
        .overlay(RoundedRectangle(cornerRadius: prominent ? 27 : 23).stroke(Paper.hairline, lineWidth: 0.5).allowsHitTesting(false))
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
            let size = geometry.size
            let rect = photo.immersiveImageRect(in: size)
            ZStack {
                Image(photo.asset).resizable().scaledToFill()
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)
            }
            .frame(width: size.width, height: size.height).clipped()
            .overlay(LinearGradient(stops: [
                .init(color: .black.opacity(0.35), location: 0),
                .init(color: .clear, location: 0.25),
                .init(color: .black.opacity(0.15), location: 0.48),
                .init(color: .black.opacity(0.78), location: 0.8),
                .init(color: .black.opacity(0.84), location: 1)
            ], startPoint: .top, endPoint: .bottom))
        }.accessibilityHidden(true)
    }
}

private struct SaintSayingReader: View {
    let catalog: SaintSayingsCatalog
    let sayings: [SaintSaying]
    @State private var currentID: String
    @Binding var favoriteIDs: Set<String>
    @State private var sharing: SaintSaying?
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
        .sheet(item: $sharing) { saying in
            SaintSayingSharePreview(catalog: catalog, saying: saying)
        }
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
                SayingShareButton(id: current.id) { sharing = current }
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
                        .foregroundStyle(.white).glassCircleFallback(shape: Capsule())
                }.accessibilityIdentifier("sayings.reader.source")
                SayingFavoriteButton(id: current.id, favoriteIDs: $favoriteIDs)
                Spacer(minLength: 4)
                Text("\(index + 1) / \(sayings.count)").font(.system(size: 11, weight: .semibold)).monospacedDigit()
                    .padding(12).foregroundStyle(.primary).glassCircleFallback(shape: Capsule(), interactive: false)
                Button { advance() } label: {
                    Image(systemName: "arrow.right").font(.system(size: 16, weight: .semibold))
                        .frame(width: 44, height: 44).foregroundStyle(.white).glassCircleFallback(shape: Circle())
                }.disabled(index == sayings.count - 1).opacity(index == sayings.count - 1 ? 0.4 : 1)
                    .accessibilityLabel("Επόμενος λόγος").accessibilityIdentifier("sayings.reader.next")
            }.tint(.white).padding(18)
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

    private func readerPage(_ saying: SaintSaying, size: CGSize) -> some View {
        let photo = catalog.photo(for: saying)
        let top = photo.readerTextTop(in: size)
        let readingHeight = max(44, size.height - top - 84)
        return ZStack(alignment: .top) {
            SayingArtwork(photo: photo)
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Label(catalog.category(for: saying).title, systemImage: catalog.category(for: saying).symbol)
                        .font(.system(size: 11, weight: .semibold)).foregroundStyle(.white.opacity(0.8))
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

/// Collection and presentation are independent. The same pager works for one
/// saint, the entire catalog, or favourites without dismissing/reopening itself.
/// Native glass controls keep their identity while opening and closing.
private enum SayingFilterAction {
    case dismiss
    case category(String?)
    case shuffle
}

private struct SaintSayingsFeed: View {
    let catalog: SaintSayingsCatalog
    @Binding var favoriteIDs: Set<String>
    @State private var sharing: SaintSaying?
    @Binding var section: SayingSection
    @Binding var saintID: String
    @Binding var categoryID: String?
    @Binding var query: String
    let leave: () -> Void
    @State private var orderedIDs: [String]
    @State private var currentID: String?
    @State private var showsFilters = false
    @State private var showsCategories = false
    @State private var isClosingFilters = false
    @State private var filterTask: Task<Void, Never>?
    @State private var feedOpacity = 1.0
    @State private var source: SaintSaying?
    @FocusState private var searchFocused: Bool
    @AccessibilityFocusState private var filterAccessibilityFocus: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(catalog: SaintSayingsCatalog, favoriteIDs: Binding<Set<String>>, section: Binding<SayingSection>,
         saintID: Binding<String>, categoryID: Binding<String?>, query: Binding<String>, leave: @escaping () -> Void) {
        self.catalog = catalog
        _favoriteIDs = favoriteIDs
        _section = section; _saintID = saintID; _categoryID = categoryID; _query = query
        self.leave = leave
        let ids = catalog.sayings.map(\.id).shuffled()
        _orderedIDs = State(initialValue: ids)
        _currentID = State(initialValue: catalog.collection(saintID: section.wrappedValue == .saint ? saintID.wrappedValue : nil,
            categoryID: categoryID.wrappedValue, query: query.wrappedValue,
            favoriteIDs: section.wrappedValue == .favorites ? favoriteIDs.wrappedValue : nil, order: ids).first?.id)
    }

    private var displayed: [SaintSaying] {
        catalog.collection(saintID: section == .saint ? saintID : nil, categoryID: categoryID, query: query,
            favoriteIDs: section == .favorites ? favoriteIDs : nil, order: orderedIDs)
    }
    private var availableCategories: [SayingCategory] {
        let ids = Set(catalog.collection(saintID: section == .saint ? saintID : nil,
            favoriteIDs: section == .favorites ? favoriteIDs : nil).map(\.categoryID))
        return catalog.categories.filter { ids.contains($0.id) }
    }
    private var collectionKey: String { section.rawValue + (section == .saint ? saintID : "") }
    private var filterMotion: Animation { .timingCurve(0.22, 0.75, 0.22, 1, duration: 0.3) }

    var body: some View {
        GeometryReader { geometry in
            let top = max(geometry.safeAreaInsets.top, 54)
            let bottom = max(geometry.safeAreaInsets.bottom, 24)
            ZStack(alignment: .top) {
                Color.black
                pages(size: geometry.size, safeTop: top, safeBottom: bottom)
                    .id(collectionKey).transition(.opacity)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: collectionKey)
                    .opacity(feedOpacity)
                if showsFilters {
                    Button { dismissFilters() } label: {
                        Color.clear.contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Κλείσιμο φίλτρων")
                    .accessibilityIdentifier("sayings.feed.dismissFilters")
                    .transition(.opacity)
                }
                controls(menuHeight: max(120, min(480, geometry.size.height - top - bottom - 270)))
                    .padding(.horizontal, 14).padding(.top, top + 8)
            }
        }
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
        .sheet(item: $source) { saying in sourceDetails(saying) }
        .sheet(item: $sharing) { saying in
            SaintSayingSharePreview(catalog: catalog, saying: saying)
        }
        .onChange(of: query) { _, _ in currentID = displayed.first?.id }
        .onChange(of: categoryID) { _, _ in currentID = displayed.first?.id }
        .onChange(of: collectionKey) { _, _ in
            categoryID = nil; query = ""; currentID = displayed.first?.id
            showsCategories = false; showsFilters = false
        }
        .onChange(of: favoriteIDs) { _, _ in
            if section == .favorites, !displayed.contains(where: { $0.id == currentID }) { currentID = displayed.first?.id }
        }
        .onDisappear { filterTask?.cancel(); searchFocused = false }
        .accessibilityAction(named: "Επόμενος λόγος") { advance(1) }
        .accessibilityAction(named: "Προηγούμενος λόγος") { advance(-1) }
    }

    @ViewBuilder private func pages(size: CGSize, safeTop: CGFloat, safeBottom: CGFloat) -> some View {
        if displayed.isEmpty {
            if section == .favorites && query.isEmpty && categoryID == nil {
                ContentUnavailableView("Αγαπημένα αποφθέγματα", systemImage: "heart",
                    description: Text("Πάτησε την καρδιά σε έναν λόγο για να τον βρίσκεις εδώ."))
            } else { ContentUnavailableView.search(text: query).foregroundStyle(.white) }
        } else {
            ScrollView(.vertical) {
                LazyVStack(spacing: 0) {
                    ForEach(displayed) { saying in
                        SaintSayingReel(catalog: catalog, saying: saying, favoriteIDs: $favoriteIDs,
                            position: (displayed.firstIndex(where: { $0.id == saying.id }) ?? 0) + 1,
                            count: displayed.count, safeTop: safeTop, safeBottom: safeBottom,
                            showSource: { source = saying }, showShare: { sharing = saying })
                            .frame(width: size.width, height: size.height).id(saying.id)
                    }
                }.scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $currentID)
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .accessibilityIdentifier("sayings.feed")
        }
    }

    private var sectionControls: some View {
        ZStack(alignment: .leading) {
            Button(action: leave) {
                Image(systemName: "chevron.left").frame(width: 36, height: 36)
            }
            .athosGlass(in: Circle())
            .accessibilityLabel("Έξοδος από την προβολή πλήρους οθόνης")
            HStack(spacing: 3) {
                ForEach(SayingSection.allCases) { item in
                    Button { section = item } label: {
                        Text(item.title).padding(.vertical, 10).frame(maxWidth: .infinity)
                            .background(.white.opacity(section == item ? 0.18 : 0), in: Capsule())
                    }
                    .accessibilityAddTraits(section == item ? .isSelected : [])
                    .accessibilityIdentifier("sayings.feed.section.\(item.rawValue)")
                }
            }
            .padding(3).athosGlass(in: Capsule())
            .padding(.horizontal, 40)
        }
        .font(.system(size: 11, weight: .medium)).foregroundStyle(.white).lineLimit(1)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: section)
    }

    private func controls(menuHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionControls
            HStack(spacing: 12) {
                Button {
                    if showsFilters { dismissFilters() }
                    else { withAnimation(reduceMotion ? nil : filterMotion) { showsFilters = true } }
                } label: {
                    HStack(spacing: 0) {
                        Image(systemName: "line.3.horizontal.decrease").font(.system(size: 18))
                            .frame(width: 44, height: 44)
                        Text("Φίλτρα και αναζήτηση")
                            .font(.system(size: 11, weight: .medium)).fixedSize()
                            .frame(width: showsFilters ? filterLabelWidth : 0, alignment: .leading)
                            .clipped().opacity(showsFilters ? 1 : 0)
                    }
                }
                .buttonStyle(.plain).athosGlass(in: Capsule())
                .accessibilityLabel("Φίλτρα και αναζήτηση")
                .accessibilityValue(showsFilters ? "Αναπτυγμένο" : "Συμπτυγμένο")
                .accessibilityFocused($filterAccessibilityFocus)
                .accessibilityIdentifier("sayings.feed.filters")
                .disabled(isClosingFilters)
                if section == .saint {
                    Menu {
                        Picker("Άγιος", selection: $saintID) {
                            ForEach(catalog.saints) { Text($0.shortName).tag($0.id) }
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Text(catalog.saints.first { $0.id == saintID }?.shortName ?? "Άγιος")
                                .font(.system(size: 11, weight: .medium)).lineLimit(1)
                            Image(systemName: "chevron.down").font(.system(size: 9))
                        }.padding(.horizontal, 12).frame(height: 44)
                    }.athosGlass(in: Capsule()).accessibilityIdentifier("sayings.feed.saint")
                    .opacity(showsFilters ? 0 : 1).frame(maxWidth: showsFilters ? 0 : .infinity).clipped()
                }
                Spacer(minLength: 0)
                Button {
                    if showsFilters { dismissFilters(.shuffle) } else { applyFilterAction(.shuffle) }
                } label: {
                    Image(systemName: "shuffle").font(.system(size: 19, weight: .medium))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain).athosGlass(in: Circle())
                .accessibilityLabel("Ανακάτεμα αποφθεγμάτων")
                .accessibilityIdentifier("sayings.feed.shuffle").disabled(isClosingFilters)
            }
            if showsFilters {
                VStack(spacing: 8) {
                    filterPanel
                    if showsCategories {
                        categoryList(height: menuHeight)
                            .transition(.opacity.combined(with: .scale(scale: 0.985, anchor: .topLeading)))
                    }
                }
                .allowsHitTesting(!isClosingFilters)
                .transition(.opacity.combined(with: .offset(y: -6)))
                .animation(reduceMotion ? nil : .easeOut(duration: 0.19), value: showsFilters)
            }
        }.foregroundStyle(.white).tint(.white)
    }

    private var filterLabelWidth: CGFloat {
        ("Φίλτρα και αναζήτηση" as NSString).size(withAttributes: [.font: UIFont.systemFont(ofSize: 11, weight: .medium)]).width + 14
    }

    private var filterPanel: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(.white.opacity(0.85))
                TextField("", text: $query, prompt: Text("Βρες έναν λόγο…").foregroundStyle(.white.opacity(0.9)))
                    .autocorrectionDisabled().textInputAutocapitalization(.never).focused($searchFocused)
                    .accessibilityLabel("Αναζήτηση αποφθεγμάτων")
                    .accessibilityIdentifier("sayings.feed.search")
            }
            .padding(.horizontal, 12).frame(minHeight: 44)
            .background(.black.opacity(0.3), in: RoundedRectangle(cornerRadius: 13))
            Button {
                searchFocused = false
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) { showsCategories.toggle() }
            } label: {
                HStack {
                    Text(catalog.categories.first { $0.id == categoryID }?.title ?? "Όλες οι κατηγορίες")
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.down").font(.system(size: 11, weight: .semibold))
                }.padding(.horizontal, 12).frame(minHeight: 44)
            }
            .buttonStyle(.plain).background(.black.opacity(0.3), in: RoundedRectangle(cornerRadius: 13))
            .accessibilityLabel("Κατηγορία")
            .accessibilityIdentifier("sayings.feed.category")
        }
        .font(.subheadline).padding(12)
        .athosGlass(in: RoundedRectangle(cornerRadius: 20), interactive: false)
    }

    private func categoryList(height: CGFloat) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                categoryRow(nil, title: "Όλες οι κατηγορίες")
                ForEach(availableCategories) { category in categoryRow(category.id, title: category.title) }
            }
        }
        .scrollBounceBehavior(.basedOnSize).frame(height: height)
        .athosGlass(in: RoundedRectangle(cornerRadius: 18), interactive: false)
        .accessibilityIdentifier("sayings.feed.categoryList")
    }

    private func categoryRow(_ id: String?, title: String) -> some View {
        Button { dismissFilters(.category(id)) } label: {
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: "checkmark").font(.system(size: 14, weight: .semibold))
                    .opacity(categoryID == id ? 1 : 0).frame(width: 20)
                Text(title).font(.subheadline).multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12).padding(.vertical, 12).frame(minHeight: 44)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(categoryID == id ? 0.07 : 0))
            .overlay(alignment: .bottom) { Rectangle().fill(.white.opacity(0.09)).frame(height: 0.5) }
        }
        .buttonStyle(.plain).disabled(isClosingFilters)
        .accessibilityAddTraits(categoryID == id ? .isSelected : [])
        .accessibilityIdentifier("sayings.feed.category.\(id ?? "all")")
    }

    private func dismissFilters(_ action: SayingFilterAction = .dismiss) {
        guard !isClosingFilters else { return }
        searchFocused = false
        if reduceMotion || !showsFilters {
            showsCategories = false; showsFilters = false
            applyFilterAction(action); filterAccessibilityFocus = true
            return
        }
        isClosingFilters = true
        filterTask?.cancel()
        filterTask = Task { @MainActor in
            // Wait for SwiftUI's actual animation completion before changing the feed.
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                withAnimation(filterMotion, completionCriteria: .logicallyComplete) {
                    showsCategories = false; showsFilters = false
                } completion: { continuation.resume() }
            }
            guard !Task.isCancelled else { return }
            let changesResults: Bool
            switch action { case .dismiss: changesResults = false; default: changesResults = true }
            if changesResults { feedOpacity = 0.65 }
            applyFilterAction(action)
            if changesResults {
                // Give the new content one frame before its short opacity animation.
                do { try await Task.sleep(for: .milliseconds(16)) } catch { return }
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: 0.16)) { feedOpacity = 1 }
            }
            isClosingFilters = false; filterAccessibilityFocus = true
        }
    }

    private func applyFilterAction(_ action: SayingFilterAction) {
        switch action {
        case .dismiss: break
        case .category(let id): categoryID = id; currentID = displayed.first?.id
        case .shuffle: orderedIDs.shuffle(); currentID = displayed.first?.id
        }
    }

    private func sourceDetails(_ saying: SaintSaying) -> some View {
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
    let showShare: () -> Void
    @State private var textExpanded = false
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
            let available = max(100, size.height - topClearance - safeBottom - 175)
            let textLayout = SaintSayingTextLayout(naturalHeight: measuredTextHeight(width: textWidth),
                availableHeight: available, lineHeight: textSize * 1.35)
            ZStack {
                Color.black
                SayingArtwork(photo: photo)
                    .overlay(Color.black.opacity(textExpanded && textLayout.needsExpansion ? 0.22 : 0))
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.35), value: textExpanded)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) { like() }
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 10) {
                    Spacer(minLength: topClearance)
                    Text(catalog.saint(for: saying).shortName)
                        .font(.system(size: 12)).foregroundStyle(.white.opacity(0.75))
                    completeText(layout: textLayout)
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

                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        SayingShareButton(id: saying.id, action: showShare)
                    }.padding(.bottom, safeBottom + 110)
                }.padding(.horizontal, 15)

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

    private func completeText(layout: SaintSayingTextLayout) -> some View {
        ScrollViewReader { proxy in
            VStack(alignment: .leading, spacing: 4) {
                ScrollView(.vertical) {
                    quoteText.id("quote-start-" + saying.id)
                        .simultaneousGesture(TapGesture(count: 2).onEnded { like() })
                }
                .scrollDisabled(!layout.needsExpansion || !textExpanded)
                .scrollBounceBehavior(.basedOnSize)
                .scrollIndicators(.hidden)
                .frame(height: layout.height(expanded: textExpanded))
                .clipped()
                .mask {
                    if layout.needsExpansion && !textExpanded {
                        LinearGradient(stops: [.init(color: .black, location: 0),
                            .init(color: .black, location: 0.90), .init(color: .clear, location: 1)],
                            startPoint: .top, endPoint: .bottom)
                    } else { Rectangle() }
                }
                .overlay {
                    if layout.needsExpansion && !textExpanded {
                        Button { expandText() } label: { Color.clear.contentShape(Rectangle()) }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Εμφάνιση ολόκληρου του λόγου")
                    }
                }
                if layout.needsExpansion {
                    Button {
                        if textExpanded {
                            var transaction = Transaction(); transaction.disablesAnimations = true
                            withTransaction(transaction) { proxy.scrollTo("quote-start-" + saying.id, anchor: .top) }
                        }
                        withAnimation(reduceMotion ? nil : .timingCurve(0.22, 0.75, 0.22, 1, duration: 0.42)) {
                            textExpanded.toggle()
                        }
                    } label: {
                        Text(textExpanded ? "Λιγότερα" : "Περισσότερα")
                            .font(.system(size: 13, weight: .semibold))
                            .frame(minHeight: 36, alignment: .leading)
                    }
                    .buttonStyle(.plain).foregroundStyle(.white)
                    .accessibilityValue(textExpanded ? "Αναπτυγμένο" : "Συμπτυγμένο")
                    .accessibilityIdentifier("sayings.reel.expand.\(saying.id)")
                }
            }
        }
    }

    private func expandText() {
        withAnimation(reduceMotion ? nil : .timingCurve(0.22, 0.75, 0.22, 1, duration: 0.42)) { textExpanded = true }
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

// MARK: - Quote image sharing (isolated from catalog and favorite persistence)

private struct SayingShareButton: View {
    let id: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 19, weight: .medium)).foregroundStyle(.white)
                .frame(width: 42, height: 42)
                .contentShape(Rectangle())
                .background(Color.black.opacity(0.45), in: Circle())
                .overlay(Circle().stroke(.white.opacity(0.25), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Κοινοποίηση αποφθέγματος")
        .accessibilityIdentifier("sayings.share.\(id)")
    }
}

private enum SayingShareFormat: String, CaseIterable, Identifiable {
    case story, image
    var id: String { rawValue }
    var title: String { self == .story ? "Story" : "Εικόνα" }
    var size: CGSize { CGSize(width: 1080, height: self == .story ? 1920 : 1776) }
}

private struct SayingSharePayload: Identifiable {
    let id = UUID()
    let url: URL
}

private struct SaintSayingSharePreview: View {
    let catalog: SaintSayingsCatalog
    let saying: SaintSaying
    @State private var format: SayingShareFormat = .story
    @State private var image: UIImage?
    @State private var failure = false
    @State private var enlarged = false
    @State private var payload: SayingSharePayload?
    @State private var temporaryURL: URL?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    Picker("Μορφή εικόνας", selection: $format) {
                        ForEach(SayingShareFormat.allCases) { item in Text(item.title).tag(item) }
                    }.pickerStyle(.segmented).accessibilityIdentifier("sayings.share.format")
                    if let image {
                        Button {
                            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) { enlarged.toggle() }
                        } label: {
                            Image(uiImage: image).resizable().scaledToFit()
                                .frame(maxWidth: enlarged ? .infinity : 280)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        }.buttonStyle(.plain)
                            .accessibilityLabel("\(catalog.saint(for: saying).shortName). \(saying.text)")
                            .accessibilityHint("Πάτησε για αλλαγή μεγέθους προεπισκόπησης")
                            .accessibilityIdentifier("sayings.share.image")
                    } else if !failure {
                        ProgressView("Προετοιμασία εικόνας…").frame(minHeight: 180)
                    }
                    if failure {
                        Text("Δεν ήταν δυνατή η προετοιμασία της εικόνας. Προσπάθησε ξανά.")
                            .font(.subheadline).foregroundStyle(Paper.inkSoft)
                        Button("Δοκιμή ξανά") { prepareImage() }.buttonStyle(.bordered)
                    }
                }.frame(maxWidth: .infinity).padding(20)
            }
            .background(Paper.bg)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Button(action: shareImage) {
                    Label("Κοινοποίηση εικόνας", systemImage: "square.and.arrow.up")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity).frame(minHeight: 50)
                        .foregroundStyle(.white)
                        .background(Paper.gold.opacity(image == nil ? 0.4 : 1), in: RoundedRectangle(cornerRadius: 16))
                }.buttonStyle(.plain).disabled(image == nil)
                    .accessibilityIdentifier("sayings.share.openSystemSheet")
                    .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 12).background(Paper.bg)
            }
            .navigationTitle("Κοινοποίηση").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Κλείσιμο", systemImage: "xmark") { dismiss() }
                        .accessibilityIdentifier("sayings.share.close")
                }
            }
            .task(id: format) { prepareImage() }
            .sheet(item: $payload, onDismiss: removeTemporaryImage) { item in
                SayingImageActivitySheet(url: item.url) { payload = nil }
            }
            .onDisappear { if payload == nil { removeTemporaryImage() } }
        }.presentationDetents([.large]).presentationDragIndicator(.visible)
    }

    @MainActor private func prepareImage() {
        image = nil; failure = false
        do { image = try SayingShareRenderer.render(saying, catalog: catalog, format: format) }
        catch { failure = true }
    }

    private func shareImage() {
        guard payload == nil, let data = image?.pngData() else { return }
        removeTemporaryImage()
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("OrthodoxPlus-quote-\(UUID().uuidString).png")
        do {
            try data.write(to: url, options: [.atomic])
            temporaryURL = url; payload = SayingSharePayload(url: url)
        } catch { failure = true }
    }

    private func removeTemporaryImage() {
        if let url = temporaryURL { try? FileManager.default.removeItem(at: url) }
        temporaryURL = nil
    }
}

private struct SayingImageActivitySheet: UIViewControllerRepresentable {
    let url: URL
    let finished: () -> Void
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        // Save to Files and compatible installed extensions remain available.
        // Do not invoke Photos without a separately approved privacy declaration.
        if Bundle.main.object(forInfoDictionaryKey: "NSPhotoLibraryAddUsageDescription") == nil &&
            Bundle.main.object(forInfoDictionaryKey: "NSPhotoLibraryUsageDescription") == nil {
            controller.excludedActivityTypes = [.saveToCameraRoll]
        }
        if let popover = controller.popoverPresentationController {
            popover.sourceView = controller.view
            popover.sourceRect = CGRect(x: 0, y: 0, width: 1, height: 1)
            popover.permittedArrowDirections = []
        }
        controller.completionWithItemsHandler = { _, _, _, _ in finished() }
        return controller
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

@MainActor private enum SayingShareRenderer {
    enum RenderError: Error { case missingImage, missingBrand, textDoesNotFit }

    static func render(_ saying: SaintSaying, catalog: SaintSayingsCatalog,
                       format: SayingShareFormat) throws -> UIImage {
        let photo = catalog.photo(for: saying)
        guard let portrait = UIImage(named: photo.asset) else { throw RenderError.missingImage }
        guard let brand = UIImage(named: "SaintSayingShareBrand")?.cgImage,
              let croppedBrand = brand.cropping(to: CGRect(x: 420, y: 216, width: 697, height: 566))
        else { throw RenderError.missingBrand }
        let size = format.size
        let card = format == .story ? CGRect(x: 98, y: 232, width: 884, height: 1456)
            : CGRect(origin: .zero, size: size)
        let scale = card.width / 884
        let inset = 64 * scale, textWidth = card.width - 128 * scale
        let brandWidth = 98 * scale
        let brandHeight = brandWidth * 566 / 697
        let brandBottom = card.maxY - 64 * scale
        let brandTop = brandBottom - max(74 * scale, brandHeight)
        let textBottom = brandTop - 155 * scale
        let minimumTop = card.minY + 155 * scale
        let layout = try textLayout(saying.text, width: textWidth, height: textBottom - minimumTop, scale: scale)
        let textTop = min(card.minY + card.height * 0.615, textBottom - layout.height)
        let rendererFormat = UIGraphicsImageRendererFormat(); rendererFormat.scale = 1; rendererFormat.opaque = true
        return UIGraphicsImageRenderer(size: size, format: rendererFormat).image { output in
            let ctx = output.cgContext
            UIColor(white: 0.06, alpha: 1).setFill(); ctx.fill(CGRect(origin: .zero, size: size))
            if format == .story {
                let source = CIImage(image: portrait)
                if let source {
                    let processed = source.clampedToExtent()
                        .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 40])
                        .applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0.4])
                        .cropped(to: source.extent)
                    if let cg = CIContext().createCGImage(processed, from: source.extent) {
                        draw(UIImage(cgImage: cg), photo: photo, in: CGRect(origin: .zero, size: size))
                    }
                }
                UIColor(white: 0.025, alpha: 0.83).setFill(); ctx.fill(CGRect(origin: .zero, size: size))
                ctx.saveGState(); ctx.setShadow(offset: CGSize(width: 0, height: 25), blur: 55,
                                               color: UIColor.black.withAlphaComponent(0.55).cgColor)
                UIColor.black.setFill(); UIBezierPath(roundedRect: card, cornerRadius: 62).fill(); ctx.restoreGState()
            }
            ctx.saveGState()
            UIBezierPath(roundedRect: card, cornerRadius: format == .story ? 62 : 0).addClip()
            draw(portrait, photo: photo, in: card)
            let opacity: [CGFloat] = [0.25, 0, 0.19, 0.73, 1]
            let colors = opacity.map { UIColor.black.withAlphaComponent($0).cgColor }
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray,
                                         locations: [0, 0.35, 0.55, 0.75, 1]) {
                ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: card.minY),
                                       end: CGPoint(x: 0, y: card.maxY), options: [])
            }
            if textTop < card.minY + card.height * 0.52 {
                let fadeStart = max(card.minY, textTop - 200 * scale)
                let fadeEnd = min(card.maxY, textTop + 140 * scale)
                let opacity: [CGFloat] = [0, 0.04, 0.12, 0.24, 0.35]
                let colors = opacity.map { UIColor.black.withAlphaComponent($0).cgColor }
                if let fade = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray,
                                         locations: [0, 0.25, 0.5, 0.75, 1]) {
                    ctx.drawLinearGradient(fade, start: CGPoint(x: 0, y: fadeStart),
                                           end: CGPoint(x: 0, y: fadeEnd), options: [.drawsAfterEndLocation])
                }
            }
            let nameAttributes: [NSAttributedString.Key: Any] = [.font: serif(34 * scale), .foregroundColor: UIColor.white]
            (catalog.saint(for: saying).shortName as NSString).draw(
                in: CGRect(x: card.minX + 46 * scale, y: card.minY + 65 * scale,
                           width: card.width - 92 * scale, height: 60 * scale), withAttributes: nameAttributes)
            (saying.text as NSString).draw(with: CGRect(x: card.minX + inset, y: textTop, width: textWidth, height: layout.height + 2),
                options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: layout.attributes, context: nil)
            ctx.saveGState(); ctx.setBlendMode(.screen)
            UIImage(cgImage: croppedBrand).draw(in: CGRect(x: card.midX - brandWidth / 2,
                y: brandBottom - brandHeight, width: brandWidth, height: brandHeight))
            ctx.restoreGState(); ctx.restoreGState()
        }
    }

    private static func serif(_ size: CGFloat) -> UIFont {
        UIFont(name: "GFSDidot-Regular", size: size) ?? UIFont(descriptor:
            UIFont.systemFont(ofSize: size, weight: .medium).fontDescriptor.withDesign(.serif)
                ?? UIFont.systemFont(ofSize: size).fontDescriptor, size: size)
    }

    private static func textLayout(_ text: String, width: CGFloat, height: CGFloat, scale: CGFloat)
        throws -> (height: CGFloat, attributes: [NSAttributedString.Key: Any]) {
        for pointSize in stride(from: 48, through: 28, by: -1) {
            let size = CGFloat(pointSize) * scale
            let paragraph = NSMutableParagraphStyle(); paragraph.lineBreakMode = .byWordWrapping
            paragraph.minimumLineHeight = size * 1.35; paragraph.maximumLineHeight = size * 1.35
            let attributes: [NSAttributedString.Key: Any] = [.font: serif(size), .paragraphStyle: paragraph,
                                                            .foregroundColor: UIColor.white]
            let measured = ceil((text as NSString).boundingRect(
                with: CGSize(width: width, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attributes, context: nil).height)
            if measured <= height { return (measured, attributes) }
        }
        throw RenderError.textDoesNotFit
    }

    private static func draw(_ image: UIImage, photo: SayingPhoto, in frame: CGRect) {
        let rect = photo.immersiveImageRect(in: frame.size).offsetBy(dx: frame.minX, dy: frame.minY)
        image.draw(in: rect)
    }
}
