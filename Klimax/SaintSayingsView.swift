import SwiftUI

struct SaintSayingsView: View {
    var body: some View {
        if let catalog = SaintSayingsCatalog.bundled {
            SaintSayingsGallery(catalog: catalog)
        } else {
            ContentUnavailableView("Οι λόγοι δεν είναι διαθέσιμοι", systemImage: "text.quote", description: Text("Δεν ήταν δυνατή η φόρτωση της συλλογής."))
        }
    }
}

private struct SayingSelection: Identifiable {
    let id: String
    let sayings: [SaintSaying]
}

private struct SaintSayingsGallery: View {
    let catalog: SaintSayingsCatalog
    @State private var saintID: String
    @State private var categoryID: String?
    @State private var query = ""
    @State private var selection: SayingSelection?
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(catalog: SaintSayingsCatalog) {
        self.catalog = catalog
        _saintID = State(initialValue: catalog.saints[0].id)
    }

    private var saint: SayingSaint { catalog.saints.first { $0.id == saintID } ?? catalog.saints[0] }
    private var saintCategories: [SayingCategory] { catalog.categories(for: saintID) }
    private var displayed: [SaintSaying] { catalog.filtered(saintID: saintID, categoryID: categoryID, query: query) }

    var body: some View {
        GeometryReader { geometry in
            let width = max(240, geometry.size.width - 40)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 22) {
                    introduction
                    search
                    categories
                    if displayed.isEmpty {
                        ContentUnavailableView.search(text: query)
                            .frame(maxWidth: .infinity).padding(.vertical, 40)
                    } else {
                        mosaic(width: width)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 90)
                .padding(.bottom, 115)
            }
            .scrollDismissesKeyboard(.interactively)
            .fullScreenCover(item: $selection) { selected in
                SaintSayingReader(catalog: catalog, sayings: selected.sayings, initialID: selected.id)
                    .presentationBackground(.clear)
            }
        }
    }

    private var introduction: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                Text("ΛΟΓΙΑ ΠΟΥ ΜΕΝΟΥΝ")
                    .font(.system(size: 10, weight: .semibold)).tracking(2.5).foregroundStyle(Paper.gold)
                if catalog.saints.count > 1 {
                    Menu {
                        ForEach(catalog.saints) { saint in
                            Button(saint.shortName) { saintID = saint.id; categoryID = nil }
                        }
                    } label: { Label(saint.shortName, systemImage: "chevron.down") }
                        .font(.system(size: 26, weight: .semibold, design: .serif)).foregroundStyle(Paper.ink)
                } else {
                    Text(saint.shortName).font(.system(size: 29, weight: .semibold, design: .serif)).foregroundStyle(Paper.ink)
                }
                Text("\(catalog.sayings.filter { $0.saintID == saintID }.count) λόγοι · \(saintCategories.count) θέματα")
                    .font(.subheadline).foregroundStyle(Paper.inkMute)
            }
            Spacer(minLength: 0)
            Image(catalog.photos.first { $0.id == saint.photoID }?.asset ?? catalog.photos[0].asset)
                .resizable().scaledToFill().frame(width: 62, height: 78)
                .clipShape(RoundedRectangle(cornerRadius: 17))
                .accessibilityHidden(true)
        }
    }

    private var search: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass").foregroundStyle(Paper.inkMute)
            TextField("Βρες έναν λόγο…", text: $query).autocorrectionDisabled()
                .accessibilityIdentifier("sayings.search")
            if !query.isEmpty {
                Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
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
                ForEach(saintCategories) { category in
                    Text(category.title).tag(Optional(category.id))
                }
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "line.3.horizontal.decrease").foregroundStyle(Paper.gold)
                Text(saintCategories.first { $0.id == categoryID }?.title ?? "Όλες οι κατηγορίες")
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 8)
                Image(systemName: "chevron.down").foregroundStyle(Paper.gold)
            }
            .font(.subheadline)
            .foregroundStyle(Paper.ink)
            .padding(14)
            .background(Paper.card, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Paper.hairline, lineWidth: 0.5))
        }
        .accessibilityLabel("Κατηγορία")
        .accessibilityValue(saintCategories.first { $0.id == categoryID }?.title ?? "Όλες οι κατηγορίες")
        .accessibilityIdentifier("sayings.category.menu")
    }

    @ViewBuilder private func mosaic(width: CGFloat) -> some View {
        let sayings = displayed
        // Stable groups provide full-width feature cards and interlocking
        // square/tall tiles without a continuously recalculated masonry layout.
        ForEach(Array(stride(from: 0, to: sayings.count, by: 5)), id: \.self) { start in
            let group = Array(sayings.dropFirst(start).prefix(5))
            VStack(spacing: 12) {
                tile(group[0], width: width, height: width * 0.88, prominent: true, sayings: sayings)
                if typeSize.isAccessibilitySize {
                    ForEach(group.dropFirst()) { saying in
                        tile(saying, width: width, height: width * 0.9, prominent: true, sayings: sayings)
                    }
                } else {
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(0..<2) { column in
                            VStack(spacing: 12) {
                                ForEach(Array(group.enumerated()).filter { $0.offset > 0 && ($0.offset - 1) % 2 == column }, id: \.element.id) { item in
                                    let side = (width - 12) / 2
                                    tile(item.element, width: side, height: side * (item.offset == 1 || item.offset == 4 ? 1.5 : 1.12), prominent: false, sayings: sayings)
                                }
                            }.frame(width: (width - 12) / 2)
                        }
                    }
                }
            }
        }
    }

    private func tile(_ saying: SaintSaying, width: CGFloat, height: CGFloat, prominent: Bool, sayings: [SaintSaying]) -> some View {
        Button { selection = SayingSelection(id: saying.id, sayings: sayings) } label: {
            let photo = catalog.photo(for: saying)
            // Preserve the supplied portrait composition, including signatures.
            // Native aspect ratio gives every photo a predictable safe text area.
            let artworkHeight = photo.textStart == nil ? height : width * photo.height / photo.width
            let region = photo.textRegion(in: CGSize(width: width, height: artworkHeight))
            let textHeight = max(0, region.height - 8)
            let fontSize: CGFloat = prominent ? 24 : 17
            let inset: CGFloat = min(prominent ? 22 : 14, max(4, textHeight - fontSize * 1.3))
            let lines = max(1, Int((textHeight - inset) / (fontSize * 1.3)))
            VStack(spacing: 0) {
                ZStack(alignment: .topLeading) {
                    SayingArtwork(photo: photo)
                    Text(saying.text)
                        .font(.system(size: fontSize, weight: .medium, design: .serif))
                        .lineSpacing(prominent ? 2 : 1)
                        .lineLimit(lines)
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
                        .padding(.horizontal, inset).padding(.top, inset)
                        .frame(width: width, height: textHeight, alignment: .topLeading)
                        .clipped()
                        .offset(y: region.minY)
                }
                .frame(width: width, height: artworkHeight)
                Label(catalog.category(for: saying).title, systemImage: catalog.category(for: saying).symbol)
                    .font(.system(size: prominent ? 13 : 11))
                    .foregroundStyle(Paper.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12).padding(.vertical, 11)
                    .background(Paper.card)
            }
            .frame(width: width)
            .clipShape(RoundedRectangle(cornerRadius: prominent ? 27 : 23, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: prominent ? 27 : 23).stroke(Paper.hairline, lineWidth: 0.5))
        }
        .buttonStyle(CalmCardStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(catalog.category(for: saying).title). \(saying.text)")
        .accessibilityHint("Άνοιγμα κάρτας")
        .accessibilityIdentifier("sayings.card.\(saying.id)")
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
    @State private var dragDown: CGFloat = 0
    @State private var source: SaintSaying?
    @State private var textAtTop = true
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(catalog: SaintSayingsCatalog, sayings: [SaintSaying], initialID: String) {
        self.catalog = catalog
        self.sayings = sayings
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
                    if !saying.sourceNote.isEmpty { Text(saying.sourceNote).foregroundStyle(.secondary) }
                    Text("Η κατάσταση ελέγχου προέρχεται από τη συλλογή κειμένων. Δεν αποτελεί ανεξάρτητη επαλήθευση της εφαρμογής.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Text(saying.id).font(.caption.monospaced()).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, alignment: .leading).padding(24)
            }
            .navigationTitle("Πηγή").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Κλείσιμο") { source = nil } } }
        }.presentationDetents([.medium, .large])
    }
}
