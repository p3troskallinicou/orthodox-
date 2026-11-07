//
//  AthosTVView.swift
//  Klimax
//
//  Athos TV reads its complete catalogue from athos_tv_page.json.
//  YouTubePlayerKit is used only while a video is visible in the foreground.
//
//  Δομικοὶ κανόνες αὐτῆς τῆς ὀθόνης:
//  1. Καμία σελίδα δὲν χρησιμοποιεῖ GeometryReader ὡς ρίζα καὶ καμία δὲν
//     κλειδώνει ὕψος. Ἔτσι τὸ περιεχόμενο φτάνει πάντα ὣς τὸ κάτω ἄκρο.
//  2. Τὰ πλωτὰ κουμπιὰ εἶναι παιδιὰ τοῦ ριζικοῦ ZStack, ποτὲ μέσα σὲ
//     κομμένη περιοχή, ὥστε τὸ ἄγγιγμα νὰ φτάνει πάντα.
//  3. Ὅπου χρειάζεται γυαλί, χρησιμοποιεῖται τὸ native liquid glass τοῦ
//     iOS 26 χωρὶς ἀδιαφανὲς χρῶμα ἀπὸ κάτω.
//

import Foundation
import Observation
import SwiftUI
import UIKit
import YouTubePlayerKit

struct AthosTVPage: Decodable, Sendable {
    let rows: [AthosTVRow]
    let reels: [String]
    let videos: [String: AthosTVVideo]

    func videos(in row: AthosTVRow) -> [AthosTVVideo] {
        row.videoIds.compactMap { videos[$0] }
    }
}

struct AthosTVRow: Decodable, Identifiable, Sendable {
    let title: String
    let videoIds: [String]

    var id: String { title }
}

struct AthosTVVideo: Decodable, Identifiable, Sendable {
    let videoId: String
    let title: String
    let description: String
    let publishedAt: String
    let durationSeconds: Int
    let type: String
    let series: String?
    let playlists: [String]?
    let thumbnail: String
    let watchUrl: String
    let speakers: [String]?

    var id: String { videoId }

    var speakerNames: [String] {
        speakers ?? []
    }

    var durationText: String {
        let hours = durationSeconds / 3600
        let minutes = (durationSeconds % 3600) / 60
        let seconds = durationSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    var publishedYear: String {
        String(publishedAt.prefix(4))
    }

    var editorialDescription: String? {
        let markers = [
            "Κάντε εγγραφή",
            "Ακολουθήστε το κανάλι",
            "Τηλέφωνο επικοινωνίας",
            "http://",
            "https://"
        ]

        let firstMarker = markers.compactMap {
            description.range(of: $0, options: .caseInsensitive)?.lowerBound
        }.min()
        let meaningfulText = firstMarker.map { String(description[..<$0]) } ?? description
        let cleaned = meaningfulText
            .replacingOccurrences(of: "\n", with: " ")
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")

        return cleaned.count >= 24 ? cleaned : nil
    }
}

enum AthosTVCatalogue {
    static let bundledPage: AthosTVPage? = {
        guard let url = Bundle.main.url(forResource: "athos_tv_page", withExtension: "json"),
              let data = try? Data(contentsOf: url, options: .mappedIfSafe) else {
            return nil
        }
        return try? JSONDecoder().decode(AthosTVPage.self, from: data)
    }()

    static var videos: [AthosTVVideo] {
        bundledPage?.videos.values.sorted { $0.publishedAt > $1.publishedAt } ?? []
    }

    static let presentation = AthosTVPresentation(
        page: bundledPage ?? AthosTVPage(rows: [], reels: [], videos: [:])
    )
}

private final class AthosTVSessionSelection {
    static let shared = AthosTVSessionSelection()

    private var featuredVideoIDs: [String]?
    private var reelVideoIDs: [String]?

    private init() {}

    func featuredVideos(in page: AthosTVPage, presentation: AthosTVPresentation, limit: Int = 9) -> [AthosTVVideo] {
        if let featuredVideoIDs {
            let videos = featuredVideoIDs.filter { presentation.videoIDs.contains($0) }.compactMap { page.videos[$0] }
            if !videos.isEmpty {
                return videos
            }
        }

        var selectedIDs: [String] = []
        var seen = Set<String>()

        for collection in presentation.collections.shuffled() {
            let candidates = collection.videos.filter { $0.type != "reel" }.map(\.videoId).shuffled()
            guard let videoID = candidates.first(where: { seen.insert($0).inserted }) else {
                continue
            }
            selectedIDs.append(videoID)
            if selectedIDs.count == limit {
                break
            }
        }

        if selectedIDs.count < limit {
            let remaining = presentation.videos
                .filter { $0.type != "reel" && !seen.contains($0.videoId) }
                .shuffled()

            for video in remaining {
                guard seen.insert(video.videoId).inserted else { continue }
                selectedIDs.append(video.videoId)
                if selectedIDs.count == limit {
                    break
                }
            }
        }

        featuredVideoIDs = selectedIDs
        return selectedIDs.compactMap { page.videos[$0] }
    }

    func reelVideos(in page: AthosTVPage, presentation: AthosTVPresentation) -> [AthosTVVideo] {
        if let reelVideoIDs {
            let videos = reelVideoIDs.filter { presentation.videoIDs.contains($0) }.compactMap { page.videos[$0] }
            if !videos.isEmpty {
                return videos
            }
        }

        let shuffledIDs = page.reels
            .filter { presentation.videoIDs.contains($0) }
            .shuffled()
        reelVideoIDs = shuffledIDs
        return shuffledIDs.compactMap { page.videos[$0] }
    }
}

private final class AthosTVFavoritesStore: ObservableObject {
    static let shared = AthosTVFavoritesStore()

    @Published private(set) var videoIDs: [String]

    private let storageKey = "athosTV.favoriteVideoIDs"

    private init() {
        videoIDs = UserDefaults.standard.stringArray(forKey: storageKey) ?? []
    }

    func contains(_ video: AthosTVVideo) -> Bool {
        videoIDs.contains(video.videoId)
    }

    func toggle(_ video: AthosTVVideo) {
        if let index = videoIDs.firstIndex(of: video.videoId) {
            videoIDs.remove(at: index)
        } else {
            videoIDs.insert(video.videoId, at: 0)
        }
        UserDefaults.standard.set(videoIDs, forKey: storageKey)
    }

    func videos(in page: AthosTVPage, presentation: AthosTVPresentation) -> [AthosTVVideo] {
        videoIDs.filter { presentation.videoIDs.contains($0) }.compactMap { page.videos[$0] }
    }
}

@MainActor
@Observable
private final class AthosTVStore {
    private(set) var page: AthosTVPage?
    private(set) var presentation = AthosTVCatalogue.presentation
    private(set) var featuredVideos: [AthosTVVideo] = []
    private(set) var reelVideos: [AthosTVVideo] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    func load() async {
        guard page == nil, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        if let bundledPage = AthosTVCatalogue.bundledPage {
            page = bundledPage
            featuredVideos = AthosTVSessionSelection.shared.featuredVideos(in: bundledPage, presentation: presentation)
            reelVideos = AthosTVSessionSelection.shared.reelVideos(in: bundledPage, presentation: presentation)
            errorMessage = nil
            return
        }

        guard let url = Bundle.main.url(forResource: "athos_tv_page", withExtension: "json") else {
            errorMessage = "Δεν βρέθηκε ο κατάλογος του Athos TV."
            return
        }

        do {
            let data = try Data(contentsOf: url, options: .mappedIfSafe)
            let decodedPage = try await Task.detached(priority: .userInitiated) {
                try JSONDecoder().decode(AthosTVPage.self, from: data)
            }.value
            page = decodedPage
            presentation = AthosTVPresentation(page: decodedPage)
            featuredVideos = AthosTVSessionSelection.shared.featuredVideos(in: decodedPage, presentation: presentation)
            reelVideos = AthosTVSessionSelection.shared.reelVideos(in: decodedPage, presentation: presentation)
            errorMessage = nil
        } catch {
            errorMessage = "Δεν φορτώθηκε ο κατάλογος του Athos TV."
        }
    }
}

// MARK: - Κατάλογος

struct AthosTVView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var store = AthosTVStore()
    @ObservedObject private var homilyStore = HomilyStore.shared
    @StateObject private var favorites = AthosTVFavoritesStore.shared
    @State private var mediaMode: AthosMediaMode = .television
    @State private var selectedVideo: AthosTVVideo?
    @State private var reelPresentation: AthosReelPresentation?
    @State private var searchPresentation: AthosSearchPresentation?
    @State private var seriesPresentation: AthosTVCollection?
    @State private var selectedSpeaker: AthosAudioSpeaker?
    @State private var showsSpeakerDirectory = false
    @State private var jumpTarget: String?
    @State private var headerCondensed = false
    @State private var headerBottomY: CGFloat = 0
    @State private var catalogueTopY: CGFloat = 0
    @State private var isShowingEntryIntro = true
    @State private var featuredCollectionID: String?

    private var audioEpisodes: [Homily] {
        homilyStore.subjects.flatMap(\.episodes).filter { !$0.isVideo }
    }

    private var speakerProfiles: [AthosAudioSpeaker] {
        AthosAudioSpeakerCatalog.profiles(from: audioEpisodes)
    }

    private var televisionSpeakers: [AthosAudioSpeaker] {
        speakerProfiles.filter { !$0.videos.isEmpty }
    }

    var body: some View {
        ZStack {
            switch mediaMode {
            case .television:
                Group {
                    if let page = store.page {
                        catalogue(page)
                    } else if store.isLoading {
                        ProgressView()
                            .tint(AthosPalette.gold)
                    } else if let errorMessage = store.errorMessage {
                        ContentUnavailableView(
                            "Athos TV",
                            systemImage: "play.tv",
                            description: Text(errorMessage)
                        )
                        .foregroundStyle(AthosPalette.ink)
                    }
                }
                .transition(.identity)

            case .audio:
                AthosAudioView(mediaMode: $mediaMode)
                    .transition(.identity)
            }

            if isShowingEntryIntro, mediaMode == .television {
                AthosTVPlaybackIntro {
                    isShowingEntryIntro = false
                }
                .transition(.opacity)
                .zIndex(10)
            }
        }
        .background { AthosPodcastStyle.background.ignoresSafeArea() }
        .toolbar(.hidden, for: .navigationBar)
        .fullScreenCover(item: $selectedVideo) { video in
            AthosTVPlayerScreen(video: video)
        }
        .fullScreenCover(item: $reelPresentation) { presentation in
            AthosTVReelsView(
                videos: presentation.videos,
                startVideoID: presentation.startVideoID
            )
        }
        .fullScreenCover(item: $searchPresentation) { presentation in
            AthosTVSearchView(presentation: presentation.catalogue) { video in
                searchPresentation = nil
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(220))
                    present(video, reels: store.reelVideos)
                }
            }
        }
        .navigationDestination(item: $seriesPresentation) { presentation in
            AthosSeriesDetailView(collection: presentation)
        }
        .navigationDestination(item: $selectedSpeaker) { speaker in
            AthosAudioSpeakerProfileView(speaker: speaker)
        }
        .navigationDestination(isPresented: $showsSpeakerDirectory) {
            AthosAudioSpeakerDirectoryView(speakers: speakerProfiles)
        }
        .task {
            await store.load()
            if homilyStore.subjects.isEmpty {
                await homilyStore.load()
            }
        }
    }

    private func catalogue(_ page: AthosTVPage) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 28) {
                    AthosTVHomeHero(collections: store.presentation.collections,
                        selection: $featuredCollectionID,
                        mediaMode: $mediaMode,
                        onSelect: { seriesPresentation = $0 },
                        onPlay: { selectedVideo = $0 })
                        .id(AthosTVAnchor.top)

                    AthosSeriesLibrary(collections: store.presentation.collections) { collection in
                        seriesPresentation = collection
                    }
                    .athosMediaRise(order: 1, trigger: mediaMode)

                    let featured = store.featuredVideos
                    if !featured.isEmpty {
                        AthosSectionHeading(title: "Προτάσεις για εσένα").padding(.horizontal, 20)
                        AthosFeaturedCarousel(
                            videos: featured,
                            isFavorite: favorites.contains,
                            onSelect: { selectedVideo = $0 },
                            onToggleFavorite: favorites.toggle
                        )
                        .containerRelativeFrame(.horizontal)
                        .athosMediaRise(order: 2, trigger: mediaMode)
                    }

                    let favoriteVideos = favorites.videos(in: page, presentation: store.presentation)
                    if !favoriteVideos.isEmpty {
                        AthosFavoritesShelf(
                            videos: favoriteVideos,
                            onSelect: { present($0, reels: store.reelVideos) },
                            onToggleFavorite: favorites.toggle
                        )
                        .athosMediaRise(order: 1, trigger: mediaMode)
                    }

                    if !televisionSpeakers.isEmpty {
                        AthosAudioSpeakersSection(
                            speakers: televisionSpeakers,
                            onSelect: { selectedSpeaker = $0 },
                            onShowAll: { showsSpeakerDirectory = true }
                        )
                        .athosMediaRise(order: 2, trigger: mediaMode)
                    }

                    let reels = store.reelVideos
                    if !reels.isEmpty {
                        AthosReelsShelf(
                            videos: reels,
                            isFavorite: favorites.contains,
                            onSelect: {
                                reelPresentation = AthosReelPresentation(
                                    videos: reels,
                                    startVideoID: $0.videoId
                                )
                            },
                            onToggleFavorite: favorites.toggle,
                            showAll: {
                                reelPresentation = AthosReelPresentation(
                                    videos: reels,
                                    startVideoID: reels[0].videoId
                                )
                            }
                        )
                        .id(AthosTVAnchor.reels)
                        .athosMediaRise(order: 3, trigger: mediaMode)
                    }

                }
                .padding(.bottom, 44)
            }
            .scrollIndicators(.hidden)
            // Only the scrolling artwork extends through the status bar. The
            // floating controls below remain inside the normal safe area.
            .contentMargins(.top, 0, for: .scrollContent)
            .ignoresSafeArea(.container, edges: .top)
            .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).minY } action: {
                catalogueTopY = $0
            }
            .onScrollGeometryChange(for: Bool.self) { geometry in
                // Observe the scroll view, not the lazy hero (which can be
                // recycled off-screen). Publish only the boundary crossing.
                let headerDepth = max(0, headerBottomY - catalogueTopY)
                let posterHeight = geometry.containerSize.width * 1.5
                return geometry.contentOffset.y + geometry.contentInsets.top >= max(0, posterHeight - headerDepth)
            } action: { _, catalogueAtHeader in
                headerCondensed = catalogueAtHeader
            }
            .onChange(of: jumpTarget) { _, target in
                guard let target else { return }
                withAnimation(.smooth(duration: 0.46)) {
                    proxy.scrollTo(target, anchor: .top)
                }
                jumpTarget = nil
            }
        }
        .overlay(alignment: .top) {
            athosHeader(
                collections: store.presentation.collections,
                onSearch: {
                    searchPresentation = AthosSearchPresentation(
                        catalogue: store.presentation
                    )
                },
                onJump: { jumpTarget = $0 }
            )
            .frame(height: 58)
            .background {
                Rectangle().fill(.regularMaterial)
                    .ignoresSafeArea(edges: .top)
                    .opacity(headerCondensed ? 1 : 0)
            }
            .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).maxY } action: {
                headerBottomY = $0
            }
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: headerCondensed)
        }
    }

    private func present(_ video: AthosTVVideo, reels: [AthosTVVideo]) {
        if video.type == "reel" {
            reelPresentation = AthosReelPresentation(
                videos: reels,
                startVideoID: video.videoId
            )
        } else {
            selectedVideo = video
        }
    }

    private func athosHeader(
        collections: [AthosTVCollection],
        onSearch: @escaping () -> Void,
        onJump: @escaping (String) -> Void
    ) -> some View {
        AthosGlassGroup(spacing: 22) {
            HStack(spacing: 12) {
                AthosMediaBrandMenu(selection: $mediaMode,
                    foreground: .primary, condensed: true)
                    .opacity(headerCondensed ? 1 : 0)
                    .allowsHitTesting(headerCondensed)
                    .accessibilityHidden(!headerCondensed)

                Spacer(minLength: 8)

                Menu {
                    Button {
                        onJump(AthosTVAnchor.top)
                    } label: {
                        Label("Αρχική", systemImage: "house.fill")
                    }

                    Button {
                        onJump(AthosTVAnchor.reels)
                    } label: {
                        Label("Σύντομα βίντεο", systemImage: "rectangle.portrait.on.rectangle.portrait")
                    }

                    Section("Ενότητες") {
                        ForEach(collections) { collection in
                            Button(collection.title) {
                                onJump(collection.id)
                            }
                        }
                    }
                } label: {
                    AthosHeaderCircle(symbol: "line.3.horizontal", foreground: headerCondensed ? .primary : .white)
                }
                .accessibilityLabel("Ενότητες Athos TV")

                Button(action: onSearch) {
                    AthosHeaderCircle(symbol: "magnifyingglass", foreground: headerCondensed ? .primary : .white)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Αναζήτηση")
            }
        }
        .padding(.horizontal, 20)
    }
}

/// Οἱ παλιὲς ὀνομασίες, τώρα δεμένες στὴν κοινὴ παλέτα τοῦ design kit.
private enum AthosTVPalette {
    static let background = AthosPalette.background
    static let elevated = AthosPalette.elevated
    static let line = AthosPalette.hairline
    static let gold = AthosPalette.goldDeep
    static let goldBright = AthosPalette.gold
    static let secondaryText = AthosPalette.secondaryText
}

private enum AthosTVAnchor {
    static let top = "athos-tv-top"
    static let reels = "athos-tv-reels"
}

private struct AthosHeaderCircle: View {
    let symbol: String
    var foreground: Color = .primary

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 19, weight: .semibold))
            .foregroundStyle(foreground)
            .frame(width: 44, height: 44)
            .contentShape(Circle())
            .athosGlass(in: Circle())
    }
}

// MARK: - Ράφια καταλόγου

/// Portrait artwork is separate from the square library covers. All eleven
/// supplied posters are available in the carousel, without changing the catalogue.
private struct AthosTVHomeHero: View {
    let collections: [AthosTVCollection]
    @Binding var selection: String?
    @Binding var mediaMode: AthosMediaMode
    let onSelect: (AthosTVCollection) -> Void
    let onPlay: (AthosTVVideo) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var width: CGFloat = 390
    private var selected: AthosTVCollection? {
        collections.first { $0.id == selection } ?? collections.first
    }
    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(collections) { collection in
                    Button { onSelect(collection) } label: {
                        AthosTVHeroPoster(collection: collection)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Άνοιγμα σειράς: \(collection.title)")
                    .frame(width: width)
                    .id(collection.id)
                }
            }.scrollTargetLayout()
        }
        .frame(height: width * 1.5)
        .scrollIndicators(.hidden).scrollTargetBehavior(.paging)
        .scrollPosition(id: $selection)
        // These controls belong to the carousel, not to each page. Swiping
        // changes only the artwork and action targets, never their position.
        .overlay(alignment: .bottom) {
            if let selected {
                VStack(spacing: 15) {
                    HStack(spacing: 12) {
                        AthosMediaBrandMenu(selection: $mediaMode,
                            foreground: .white, condensed: true)
                        Spacer(minLength: 0)
                        Text(selected.episodeCountText)
                            .font(.system(size: 13, weight: .semibold).monospacedDigit())
                            .foregroundStyle(.white.opacity(0.9))
                            .contentTransition(.numericText())
                            .animation(reduceMotion ? nil : .smooth(duration: 0.3), value: selected.videos.count)
                    }
                    HStack(spacing: 12) {
                        if let first = selected.videos.first {
                            AthosPodcastPlayButton(tone: .black) { onPlay(first) }
                        }
                        AthosGlassIconButton(symbol: "list.bullet", size: 48,
                            tint: .white, accessibility: "Όλα τα επεισόδια") { onSelect(selected) }
                    }
                }
                .padding(.horizontal, 20).padding(.top, 32).padding(.bottom, 56)
                .background {
                    LinearGradient(stops: [.init(color: .clear, location: 0),
                        .init(color: .black.opacity(0.45), location: 0.35),
                        .init(color: .black.opacity(0.72), location: 1)],
                        startPoint: .top, endPoint: .bottom)
                }
            }
        }
        .overlay(alignment: .bottom) {
            HStack(spacing: 4) {
                ForEach(collections) { collection in
                    Button {
                        withAnimation(reduceMotion ? nil : .smooth(duration: 0.3)) { selection = collection.id }
                    } label: {
                        Capsule().fill(.white.opacity(selected?.id == collection.id ? 1 : 0.35))
                            .frame(width: selected?.id == collection.id ? 23 : 7, height: 7)
                            .frame(width: 24, height: 32)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(collection.title)
                    .accessibilityAddTraits(selected?.id == collection.id ? .isSelected : [])
                }
            }
            .animation(reduceMotion ? nil : .smooth(duration: 0.32), value: selection)
            .padding(.bottom, 8)
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .onAppear { if selection == nil { selection = collections.first?.id } }
    }
}

/// Keep the approved 2:3 source whole. Neither a square crop nor an aspect-fill
/// crop is needed when the container uses the poster's own aspect ratio.
private struct AthosTVHeroPoster: View {
    let collection: AthosTVCollection
    var body: some View {
        Group {
            if let asset = collection.heroAssetName {
                Image(asset).resizable().interpolation(.high).scaledToFit()
            } else {
                AthosTVSeriesCover(collection: collection, cornerRadius: 0)
            }
        }
        .aspectRatio(2.0 / 3.0, contentMode: .fit)
        .accessibilityLabel(collection.title)
    }
}

/// Shared by home and series detail. Controls sit inside the lower poster area,
/// with no extra header or duplicated artwork above the actual poster.
private struct AthosTVPosterStage<Controls: View>: View {
    let collection: AthosTVCollection
    var onOpen: (() -> Void)? = nil
    @ViewBuilder var controls: Controls

    var body: some View {
        Group {
            if let onOpen {
                Button(action: onOpen) { AthosTVHeroPoster(collection: collection) }
                    .buttonStyle(.plain).accessibilityLabel("Άνοιγμα σειράς: \(collection.title)")
            } else {
                AthosTVHeroPoster(collection: collection)
            }
        }
        .overlay(alignment: .bottom) {
            controls
                .padding(.horizontal, 20).padding(.top, 32).padding(.bottom, 24)
                .frame(maxWidth: .infinity)
                .background {
                    LinearGradient(stops: [.init(color: .clear, location: 0),
                        .init(color: .black.opacity(0.45), location: 0.35),
                        .init(color: .black.opacity(0.72), location: 1)],
                        startPoint: .top, endPoint: .bottom)
                }
        }
    }
}

private struct AthosFeaturedCarousel: View {
    let videos: [AthosTVVideo]
    let isFavorite: (AthosTVVideo) -> Bool
    let onSelect: (AthosTVVideo) -> Void
    let onToggleFavorite: (AthosTVVideo) -> Void
    @State private var selectedVideoID: String?

    var body: some View {
        GeometryReader { proxy in
            let cardWidth = min(max(proxy.size.width * 0.86, 240), min(360, proxy.size.width - 40))
            let cardHeight = cardWidth * 9 / 16 + 108
            let sideInset = max((proxy.size.width - cardWidth) / 2, 0)

            ScrollView(.horizontal) {
                LazyHStack(spacing: 14) {
                    ForEach(videos) { video in
                        ZStack(alignment: .topTrailing) {
                            Button {
                                if selectedVideoID == video.videoId {
                                    onSelect(video)
                                } else {
                                    withAnimation(.smooth(duration: 0.46)) {
                                        selectedVideoID = video.videoId
                                    }
                                }
                            } label: {
                                AthosFeaturedPoster(
                                    video: video,
                                    cardWidth: cardWidth,
                                    cardHeight: cardHeight
                                )
                            }
                            .buttonStyle(.plain)

                            AthosFavoriteButton(
                                isFavorite: isFavorite(video),
                                action: { onToggleFavorite(video) }
                            )
                            .padding(12)
                        }
                        .frame(width: cardWidth, height: cardHeight)
                        .id(video.videoId)
                        .zIndex(selectedVideoID == video.videoId ? 2 : 1)
                        .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                            content
                                .scaleEffect(phase.isIdentity ? 1 : 0.96)
                                .opacity(phase.isIdentity ? 1 : 0.72)
                        }
                    }
                }
                .frame(height: proxy.size.height)
                .scrollTargetLayout()
            }
            .contentMargins(.horizontal, sideInset, for: .scrollContent)
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $selectedVideoID, anchor: .center)
            .onAppear {
                guard selectedVideoID == nil else { return }
                let initialIndex = min(1, max(videos.count - 1, 0))
                selectedVideoID = videos[safe: initialIndex]?.videoId
            }
            .task(id: selectedVideoID) {
                guard videos.count > 1 else { return }

                do {
                    try await Task.sleep(for: .seconds(5))
                } catch {
                    return
                }

                let currentIndex = videos.firstIndex {
                    $0.videoId == selectedVideoID
                } ?? 0
                let nextIndex = (currentIndex + 1) % videos.count

                withAnimation(.smooth(duration: 0.52)) {
                    selectedVideoID = videos[nextIndex].videoId
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 312)
    }
}

private struct AthosFeaturedPoster: View {
    let video: AthosTVVideo
    let cardWidth: CGFloat
    let cardHeight: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            AthosRemoteThumbnail(video: video, contentMode: .fill)
                .frame(width: cardWidth, height: cardHeight - 108)
                .clipped()
            VStack(alignment: .leading, spacing: 7) {
                Text(video.speakerNames.first ?? "ATHOS TV")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(AthosPalette.gold)
                    .lineLimit(1)
                Text(video.title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(AthosPalette.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Label(video.durationText, systemImage: "play.fill")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(AthosPalette.secondaryText)
            }
            .padding(.horizontal, 16)
            .frame(height: 108, alignment: .center)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: cardWidth, height: cardHeight)
        .background(AthosPalette.elevated)
        .mediaProgressRow(id: video.videoId, duration: Double(video.durationSeconds))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22)
                .stroke(AthosPalette.hairline, lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.08), radius: 12, y: 5)
    }
}

private struct AthosFavoriteButton: View {
    let isFavorite: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isFavorite ? "heart.fill" : "heart")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(isFavorite ? AthosPalette.gold : AthosPalette.ink)
                .frame(width: 38, height: 38)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .athosGlass(in: Circle())
        .accessibilityLabel(
            isFavorite ? "Αφαίρεση από τα αγαπημένα" : "Προσθήκη στα αγαπημένα"
        )
    }
}

private struct AthosFavoritesShelf: View {
    let videos: [AthosTVVideo]
    let onSelect: (AthosTVVideo) -> Void
    let onToggleFavorite: (AthosTVVideo) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            AthosSectionHeading(title: "Αγαπημένα")
                .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(videos) { video in
                        ZStack(alignment: .topTrailing) {
                            Button {
                                onSelect(video)
                            } label: {
                                ZStack(alignment: .bottomLeading) {
                                    AthosRemoteThumbnail(video: video, contentMode: .fill)
                                        .frame(width: 246, height: 138)

                                    LinearGradient(
                                        colors: [.clear, .black.opacity(0.92)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )

                                    Text(video.title)
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(AthosPalette.ink)
                                        .lineLimit(3)
                                        .multilineTextAlignment(.leading)
                                        .padding(12)
                                        .padding(.trailing, 34)
                                }
                                .frame(width: 246, height: 138)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(AthosTVPalette.line.opacity(0.48), lineWidth: 0.7)
                                )
                            }
                            .buttonStyle(.plain)

                            AthosFavoriteButton(
                                isFavorite: true,
                                action: { onToggleFavorite(video) }
                            )
                            .padding(8)
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

private struct AthosSeriesLibrary: View {
    let collections: [AthosTVCollection]
    let onSelect: (AthosTVCollection) -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline) {
                AthosSectionHeading(title: "Σειρές")
                Spacer()
                Text("\(collections.count)").font(.subheadline.monospacedDigit())
                    .foregroundStyle(AthosPalette.secondaryText)
            }

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: dynamicTypeSize.isAccessibilitySize ? 260 : 146,
                                            maximum: 260), spacing: 18, alignment: .top)],
                alignment: .leading, spacing: 24
            ) {
                ForEach(collections) { collection in
                    Button { onSelect(collection) } label: {
                        AthosSeriesCard(collection: collection)
                    }
                    .buttonStyle(.plain)
                    .id(collection.id)
                    .accessibilityIdentifier("athos.series.\(collection.id)")
                }
            }
        }
        .padding(.horizontal, 20)
    }
}

/// Titles are embedded in the approved art: no tint, gradient, crop or text overlay.
struct AthosTVSeriesCover: View {
    let collection: AthosTVCollection
    var cornerRadius: CGFloat = 12

    var body: some View {
        Group {
            if let asset = collection.coverAssetName {
                Image(asset).resizable().interpolation(.high).scaledToFit()
            } else if let first = collection.videos.first {
                // Kept for future reactivation of the two unmapped, hidden collections.
                AthosRemoteThumbnail(video: first, contentMode: .fit)
                    .aspectRatio(1, contentMode: .fit)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .accessibilityLabel(collection.title)
    }
}

struct AthosSeriesCard: View {
    let collection: AthosTVCollection

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            AthosTVSeriesCover(collection: collection)
            HStack(spacing: 6) {
                Text(collection.episodeCountText).font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold))
            }
            .foregroundStyle(AthosPalette.secondaryText)
            .padding(.horizontal, 2)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(collection.title), \(collection.episodeCountText)")
        .accessibilityHint("Άνοιγμα σειράς")
    }
}

private struct AthosReelsShelf: View {
    let videos: [AthosTVVideo]
    let isFavorite: (AthosTVVideo) -> Bool
    let onSelect: (AthosTVVideo) -> Void
    let onToggleFavorite: (AthosTVVideo) -> Void
    let showAll: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                AthosSectionHeading(title: "Σύντομα βίντεο", action: showAll)
                Spacer()
            }
            .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(videos.prefix(18)) { video in
                        ZStack(alignment: .topTrailing) {
                            Button {
                                onSelect(video)
                            } label: {
                                ZStack(alignment: .bottomLeading) {
                                    AthosRemoteThumbnail(video: video)
                                        .frame(width: 148, height: 254)

                                    LinearGradient(
                                        colors: [.clear, AthosPalette.background.opacity(0.94)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                    .frame(width: 148, height: 254)

                                    VStack(alignment: .leading, spacing: 6) {
                                        Image(systemName: "play.fill")
                                            .font(.system(size: 12, weight: .bold))
                                        Text(video.title)
                                            .font(.system(size: 12, weight: .semibold))
                                            .lineLimit(7)
                                            .minimumScaleFactor(0.78)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    .foregroundStyle(AthosPalette.ink)
                                    .frame(width: 124, alignment: .leading)
                                    .padding(12)
                                    .frame(width: 148, height: 254, alignment: .bottomLeading)
                                }
                                .frame(width: 148, height: 254)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(AthosTVPalette.line.opacity(0.38), lineWidth: 0.7)
                                )
                            }
                            .buttonStyle(.plain)

                            AthosFavoriteButton(
                                isFavorite: isFavorite(video),
                                action: { onToggleFavorite(video) }
                            )
                            .padding(8)
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

private struct AthosRemoteThumbnail: View {
    let video: AthosTVVideo
    var contentMode: ContentMode = .fill

    var body: some View {
        AsyncImage(
            url: URL(string: video.thumbnail),
            transaction: Transaction(animation: nil)
        ) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            case .failure:
                thumbnailPlaceholder
            case .empty:
                ZStack {
                    thumbnailPlaceholder
                    ProgressView().tint(AthosPalette.gold)
                }
            @unknown default:
                thumbnailPlaceholder
            }
        }
        .background(.black)
        .clipped()
    }

    private var thumbnailPlaceholder: some View {
        ZStack {
            AthosPalette.elevated
            Image(systemName: "play.rectangle.fill")
                .font(.system(size: 30))
                .foregroundStyle(AthosTVPalette.gold.opacity(0.72))
        }
    }
}

// MARK: - Σελίδα σειρᾶς

struct AthosSeriesDetailView: View {
    let collection: AthosTVCollection
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedVideo: AthosTVVideo?
    @State private var filter: AthosEpisodeFilter = .all
    @State private var reversed = false
    @State private var toolbarOverEpisodes = false
    @State private var toolbarBottomY: CGFloat = 0
    @State private var scrollFrame: CGRect = .zero
    @State private var episodesHeadingHeight: CGFloat = 0
    @ObservedObject private var favorites = AthosTVFavoritesStore.shared
    private var visibleEpisodes: [AthosTVVideo] {
        let matching = collection.videos.filter {
            filter.includes(id: $0.videoId)
        }
        return reversed ? Array(matching.reversed()) : matching
    }

    var body: some View {
        ScrollViewReader { proxy in
            ZStack(alignment: .top) {
                AthosPodcastStyle.background.ignoresSafeArea(edges: .bottom)
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        seriesHero
                        HStack {
                            Text("Επεισόδια").font(.system(size: 25, weight: .bold))
                            Image(systemName: "chevron.right").font(.system(size: 17, weight: .bold))
                                .foregroundStyle(.tertiary)
                            Spacer()
                            Text("\(visibleEpisodes.count)").font(.subheadline.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 20).padding(.top, 24).padding(.bottom, 16)
                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: {
                            episodesHeadingHeight = $0
                        }
                        .id("athos-series-episodes")
                        ForEach(visibleEpisodes) { video in
                            let index = collection.videos.firstIndex { $0.id == video.id } ?? 0
                            AthosEpisodeRow(index: index + 1, video: video,
                                isFavorite: favorites.contains(video),
                                onFavorite: { favorites.toggle(video) }) {
                                selectedVideo = video
                            }
                        }
                        if visibleEpisodes.isEmpty {
                            ContentUnavailableView("Δεν υπάρχουν επεισόδια", systemImage: "line.3.horizontal.decrease",
                                description: Text("Δοκίμασε άλλο φίλτρο."))
                        }
                        Color.clear.frame(height: 90)
                    }
                }
                .scrollIndicators(.hidden)
                .contentMargins(.top, 0, for: .scrollContent)
                .ignoresSafeArea(.container, edges: .top)
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: {
                    scrollFrame = $0
                }
                .onScrollGeometryChange(for: Bool.self) { geometry in
                    let toolbarDepth = max(0, toolbarBottomY - scrollFrame.minY)
                    return geometry.contentOffset.y + geometry.contentInsets.top >= max(0, geometry.containerSize.width * 1.5 - toolbarDepth)
                } action: { _, overEpisodes in
                    toolbarOverEpisodes = overEpisodes
                }
                AthosSeriesGlassToolbar(filter: $filter, reversed: $reversed,
                    overContent: toolbarOverEpisodes,
                    onBack: { dismiss() },
                    onEpisodes: {
                        filter = .all
                        // Land the heading below the floating toolbar, rather
                        // than hiding the heading and first episode behind it.
                        let toolbarDepth = max(0, toolbarBottomY - scrollFrame.minY)
                        let anchorY = min(1, toolbarDepth / max(1, scrollFrame.height - episodesHeadingHeight))
                        withAnimation(reduceMotion ? nil : .smooth(duration: 0.3)) {
                            proxy.scrollTo("athos-series-episodes", anchor: UnitPoint(x: 0.5, y: anchorY))
                        }
                    },
                    onPlayFirst: { selectedVideo = collection.videos.first },
                    onPlayLatest: { selectedVideo = collection.videos.last })
                    .background {
                        Rectangle().fill(.regularMaterial).ignoresSafeArea(edges: .top)
                            .opacity(toolbarOverEpisodes ? 1 : 0)
                    }
                    .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).maxY } action: {
                        toolbarBottomY = $0
                    }
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: toolbarOverEpisodes)
            }
        }
        .foregroundStyle(Color.primary)
        .fullScreenCover(item: $selectedVideo) { video in AthosTVPlayerScreen(video: video) }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var seriesHero: some View {
        AthosTVPosterStage(collection: collection) {
            VStack(alignment: .leading, spacing: 16) {
                if let first = collection.videos.first {
                    AthosPodcastPlayButton(tone: .black) { selectedVideo = first }
                        .accessibilityIdentifier("athos.series.play")
                        .frame(maxWidth: .infinity)
                }
                if collection.definition.sourceTitles.count > 1 {
                    Text("Ζωντανές και βιντεοσκοπημένες ομιλίες του Μητροπολίτη Λεμεσού Αθανασίου.")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white.opacity(0.92))
                } else if let speaker = collection.videos.first?.speakerNames.first {
                    Text(speaker.interfaceGreek).font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white.opacity(0.92))
                }
                Label("\(collection.episodeCountText) · Athos TV", systemImage: "play.tv")
                    .font(.system(size: 13, weight: .medium)).foregroundStyle(.white.opacity(0.85))
            }
        }
    }
}

#if DEBUG
struct AthosVideoReferencePreview: View {
    var collectionID: String? = nil
    var body: some View {
        NavigationStack {
            if let collection = AthosTVCatalogue.presentation.collections.first(where: { collectionID == nil || $0.id == collectionID }) {
                AthosSeriesDetailView(collection: collection)
            }
        }
    }
}

struct AthosSeriesArtworkPreview: View {
    var body: some View {
        ScrollView {
            AthosSeriesLibrary(collections: AthosTVCatalogue.presentation.collections, onSelect: { _ in })
                .padding(.vertical, 20)
        }.background { AppAtmosphere().ignoresSafeArea() }
    }
}

/// Exercise wrapping without altering playback history or real series order.
struct AthosEpisodeSpacingPreview: View {
    private var videos: [AthosTVVideo] {
        Array(AthosTVCatalogue.videos.filter {
            $0.title.count > 65 && ($0.editorialDescription?.count ?? 0) > 100
        }.prefix(2)) + Array(AthosTVCatalogue.videos.prefix(1))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Επεισόδια").font(.title2.bold()).padding(20)
                ForEach(Array(videos.enumerated()), id: \.element.id) { index, video in
                    AthosEpisodeRow(index: index + 1, video: video,
                        isFavorite: false, onFavorite: {}, onPlay: {})
                }
                HStack(spacing: 16) {
                    AthosPlaybackPillLabel(duration: 4440, fraction: 0.42,
                        started: true, finished: false, compact: true).frame(width: 96)
                    AthosPlaybackPillLabel(duration: 4440, fraction: 1,
                        started: false, finished: true, compact: true).frame(width: 96)
                }.padding(20)
            }
        }.background(AthosPodcastStyle.background)
    }
}
#endif

private struct AthosEpisodeRow: View {
    let index: Int
    let video: AthosTVVideo
    let isFavorite: Bool
    let onFavorite: () -> Void
    let onPlay: () -> Void
    @ScaledMetric(relativeTo: .caption) private var thumbnailWidth: CGFloat = 96

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("ΕΠΕΙΣΟΔΙΟ \(index)").font(.system(size: 10, weight: .medium))
                .foregroundStyle(AthosPodcastStyle.secondary)
            HStack(alignment: .top, spacing: 12) {
                // Keep the duration attached to its artwork, independently of
                // the height of the neighbouring title and description.
                VStack(alignment: .leading, spacing: 4) {
                    Button(action: onPlay) {
                        AthosRemoteThumbnail(video: video, contentMode: .fill)
                            .frame(width: thumbnailWidth, height: thumbnailWidth * 9 / 16)
                            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    }
                    .buttonStyle(.plain).accessibilityLabel("Αναπαραγωγή: \(video.title)")
                    Button(action: onPlay) {
                        AthosPlaybackPill(id: video.videoId, duration: Double(video.durationSeconds), compact: true)
                    }.buttonStyle(.plain)
                }.frame(width: thumbnailWidth, alignment: .leading)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .top, spacing: 6) {
                        Button(action: onPlay) {
                            Text(video.title).font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(Color.primary).multilineTextAlignment(.leading).lineLimit(3)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                        }.buttonStyle(.plain)
                        AthosFavoriteButton(isFavorite: isFavorite, action: onFavorite)
                            .frame(width: 44, height: 44)
                    }
                    if let description = video.editorialDescription, !description.isEmpty {
                        Button(action: onPlay) {
                            Text(description).font(.system(size: 14)).foregroundStyle(AthosPodcastStyle.secondary)
                                .lineLimit(2).multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                        }.buttonStyle(.plain)
                    }
                    if let speaker = video.speakerNames.first {
                        Text(speaker.interfaceGreek).font(.system(size: 13)).foregroundStyle(AthosPodcastStyle.secondary)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 14)
        .background(MediaProgress.shared.isFinished(video.videoId) ? AthosPlaybackStatus.green.opacity(0.08) : .clear)
        .overlay(alignment: .bottom) {
            Rectangle().fill(AthosPodcastStyle.separator).frame(height: 0.5).padding(.leading, 20)
        }
    }
}

private struct AthosSearchPresentation: Identifiable {
    let id = UUID()
    let catalogue: AthosTVPresentation
}

private struct AthosTVSearchView: View {
    let presentation: AthosTVPresentation
    let onSelect: (AthosTVVideo) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var scope = "Όλα"
    @ObservedObject private var favorites = AthosTVFavoritesStore.shared
    private var term: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var results: [AthosTVVideo] {
        term.isEmpty ? Array(presentation.videos.prefix(60)) : presentation.videos.filter {
            $0.title.localizedCaseInsensitiveContains(term)
                || $0.speakerNames.contains { $0.localizedCaseInsensitiveContains(term) }
        }
    }
    private var series: [AthosTVCollection] {
        presentation.collections.filter { term.isEmpty || $0.matches(term) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    HStack(spacing: 7) {
                        Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                        TextField("Αναζήτηση", text: $query).textInputAutocapitalization(.never).autocorrectionDisabled()
                        if !query.isEmpty {
                            Button { query = "" } label: {
                                Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                            }.accessibilityLabel("Καθαρισμός αναζήτησης")
                        }
                    }.padding(9).background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
                    Button("Άκυρο") { dismiss() }.foregroundStyle(Gild.accentForeground)
                }.padding(.horizontal, 20).padding(.top, 12)
                HStack(spacing: 5) {
                    ForEach(["Όλα", "Σειρές", "Επεισόδια"], id: \.self) { item in
                        Button { scope = item } label: {
                            Text(item).font(.system(size: 13, weight: .semibold))
                                .padding(.horizontal, 13).padding(.vertical, 10)
                                .foregroundStyle(scope == item ? .white : .primary)
                                .background(scope == item ? Paper.gold : .clear, in: Capsule())
                        }.accessibilityAddTraits(scope == item ? .isSelected : [])
                    }
                    Spacer()
                }.padding(.horizontal, 20).padding(.vertical, 10)
                List {
                    if scope != "Επεισόδια" {
                        ForEach(Array(series.prefix(scope == "Όλα" ? 6 : series.count))) { collection in
                            NavigationLink {
                                AthosSeriesDetailView(collection: collection)
                            } label: {
                                HStack(spacing: 14) {
                                    AthosTVSeriesCover(collection: collection).frame(width: 112, height: 112)
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("Σειρά").font(.subheadline.weight(.medium))
                                        Text(collection.episodeCountText).font(.subheadline).foregroundStyle(.secondary)
                                    }
                                }.padding(.vertical, 7)
                            }
                            .accessibilityLabel("\(collection.title), \(collection.episodeCountText)")
                            .listRowBackground(AthosPodcastStyle.background)
                        }
                    }
                    if scope != "Σειρές" {
                        ForEach(results) { video in
                            HStack(spacing: 12) {
                                Button { onSelect(video) } label: {
                                    HStack(spacing: 12) {
                                        AthosRemoteThumbnail(video: video, contentMode: .fill)
                                            .frame(width: 58, height: 58).clipShape(RoundedRectangle(cornerRadius: 5))
                                        VStack(alignment: .leading, spacing: 5) {
                                            Text(video.title).font(.system(size: 16, weight: .medium)).lineLimit(2)
                                            if let speaker = video.speakerNames.first {
                                                Text(speaker.interfaceGreek).font(.system(size: 14)).foregroundStyle(.secondary).lineLimit(1)
                                            }
                                            AthosPlaybackPill(id: video.videoId, duration: Double(video.durationSeconds))
                                        }.frame(maxWidth: .infinity, alignment: .leading)
                                    }.contentShape(Rectangle())
                                }.buttonStyle(.plain)
                                AthosFavoriteButton(isFavorite: favorites.contains(video), action: { favorites.toggle(video) })
                            }.padding(.vertical, 5).listRowBackground(AthosPodcastStyle.background)
                        }
                    }
                    if (scope == "Όλα" && results.isEmpty && series.isEmpty)
                        || (scope == "Σειρές" && series.isEmpty)
                        || (scope == "Επεισόδια" && results.isEmpty) {
                        ContentUnavailableView.search(text: query).listRowBackground(Color.clear)
                    }
                }.listStyle(.plain).scrollContentBackground(.hidden).scrollDismissesKeyboard(.interactively)
            }
            .background(AthosPodcastStyle.background).foregroundStyle(Color.primary)
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

private struct AthosReelPresentation: Identifiable {
    let id = UUID()
    let videos: [AthosTVVideo]
    let startVideoID: String
}

// MARK: - YouTube

private extension YouTubePlayer.Parameters {
    static func athosTV(autoPlay: Bool, startAt seconds: Double = 0) -> Self {
        .init(
            autoPlay: autoPlay,
            startTime: seconds > 1 ? Measurement(value: seconds, unit: UnitDuration.seconds) : nil,
            showControls: false,
            showFullscreenButton: false,
            keyboardControlsDisabled: true,
            restrictRelatedVideosToSameChannel: false
        )
    }
}

private extension YouTubePlayer.HTMLBuilder {
    static var athosTV: Self {
        .init { builder, encodedOptions in
            let playerVariables = "\"playerVars\":{"
            let athosPlayerVariables = "\"playerVars\":{\"iv_load_policy\":3,"
            let patchedOptions = encodedOptions.replacingOccurrences(
                of: playerVariables,
                with: athosPlayerVariables
            )

            return try Self.defaultHTMLProvider()(builder, patchedOptions)
        }
    }
}

private extension YouTubePlayer.Configuration {
    static var athosTV: Self {
        .init(
            fullscreenMode: .system,
            allowsInlineMediaPlayback: true,
            htmlBuilder: .athosTV
        )
    }

    static var athosTVSystemFullscreen: Self {
        .init(
            fullscreenMode: .system,
            allowsInlineMediaPlayback: false,
            htmlBuilder: .athosTV
        )
    }
}

@MainActor
private enum AthosPlayerOrientation {
    static func request(_ orientations: UIInterfaceOrientationMask) {
        KlimaxAppDelegate.supportedOrientations = orientations

        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
        else {
            return
        }

        let rootViewController = scene.windows.first(where: \.isKeyWindow)?
            .rootViewController
        rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        topViewController(from: rootViewController)?
            .setNeedsUpdateOfSupportedInterfaceOrientations()

        scene.requestGeometryUpdate(
            .iOS(interfaceOrientations: orientations)
        )
    }

    private static func topViewController(
        from viewController: UIViewController?
    ) -> UIViewController? {
        if let presented = viewController?.presentedViewController {
            return topViewController(from: presented)
        }
        if let navigation = viewController as? UINavigationController {
            return topViewController(from: navigation.visibleViewController)
        }
        if let tab = viewController as? UITabBarController {
            return topViewController(from: tab.selectedViewController)
        }
        return viewController
    }
}

struct AthosTVPlayerScreen: View {
    let video: AthosTVVideo
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var player: YouTubePlayer
    @State private var isShowingIntro = true
    @State private var didRequestAutomaticPlayback = false
    @State private var didEnterSystemFullscreen = false
    @State private var isDismissing = false
    // AthosTV videos are essentially homilies, so their watch time feeds the
    // same didaches listening goals. Accumulated with a conservative wall clock
    // that only counts while playback is active and the app is foreground.
    @State private var isActivelyPlaying = false
    @State private var didRecordAthosCompletion = false

    init(video: AthosTVVideo) {
        self.video = video
        let resume = MediaProgress.shared.resumeSeconds(for: video.videoId)
        _player = StateObject(
            wrappedValue: YouTubePlayer(
                source: .video(id: video.videoId),
                parameters: .athosTV(autoPlay: false, startAt: resume),
                configuration: .athosTVSystemFullscreen
            )
        )
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.ignoresSafeArea()

                YouTubePlayerView(player)
                    .frame(
                        width: max(proxy.size.width, 1),
                        height: max(proxy.size.height, 1)
                    )
                    .opacity(0.001)
                    .allowsHitTesting(false)

                if isShowingIntro {
                    if proxy.size.width > proxy.size.height {
                        AthosTVPlaybackIntro {
                            withAnimation(.easeOut(duration: 0.24)) {
                                isShowingIntro = false
                            }
                            requestAutomaticPlayback()
                        }
                        .transition(.opacity)
                    } else {
                        Color.black
                            .ignoresSafeArea()
                    }
                }
            }
        }
        .statusBarHidden(true)
        .task {
            await Task.yield()
            AthosPlayerOrientation.request(.landscape)
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { break }
                guard isActivelyPlaying, !isShowingIntro else { continue }
                StreakStore.shared.addListeningSeconds(1)
                guard let current = try? await player.getCurrentTime() else { continue }
                let position = current.converted(to: .seconds).value
                let actualDuration = try? await player.getDuration()
                let total = actualDuration?.converted(to: .seconds).value ?? Double(video.durationSeconds)
                MediaProgress.shared.update(id: video.videoId, seconds: position, duration: total)
                if !didRecordAthosCompletion,
                   total > 0,
                   position >= total * 0.9 {
                    didRecordAthosCompletion = true
                    StreakStore.shared.record(.didaches, itemID: video.videoId)
                }
            }
        }
        .onReceive(player.statePublisher) { state in
            guard state.isReady, !isShowingIntro else { return }
            requestAutomaticPlayback()
        }
        .onReceive(player.playbackStatePublisher) { state in
            isActivelyPlaying = state == .playing
            if state == .ended {
                MediaProgress.shared.markFinished(video.videoId)
            } else if state != .playing {
                MediaProgress.shared.flush()
            }
        }
        .onReceive(player.fullscreenStatePublisher) { state in
            if state.isFullscreen {
                didEnterSystemFullscreen = true
            } else if didEnterSystemFullscreen {
                closePlayerBridge()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase != .active else { return }
            pause()
        }
        .onDisappear {
            pause()
            AthosPlayerOrientation.request(.portrait)
        }
    }

    private func closePlayerBridge() {
        guard !isDismissing else { return }
        isDismissing = true
        pause()
        AthosPlayerOrientation.request(.portrait)
        dismiss()
    }

    private func pause() {
        isActivelyPlaying = false
        MediaProgress.shared.flush()
        Task {
            try? await player.pause()
        }
    }

    private func requestAutomaticPlayback() {
        guard !didRequestAutomaticPlayback, player.state.isReady else { return }
        didRequestAutomaticPlayback = true

        Task {
            do {
                try await player.play()
            } catch {
                didRequestAutomaticPlayback = false
                await MainActor.run { isActivelyPlaying = false }
            }
        }
    }
}

// MARK: - Σύντομα βίντεο

private struct AthosTVReelsView: View {
    let videos: [AthosTVVideo]
    let startVideoID: String

    @Environment(\.dismiss) private var dismiss
    @State private var currentVideoID: String?

    init(videos: [AthosTVVideo], startVideoID: String) {
        self.videos = videos
        self.startVideoID = startVideoID
        _currentVideoID = State(initialValue: nil)
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()

            ScrollView(.vertical) {
                LazyVStack(spacing: 0) {
                    ForEach(videos) { video in
                        AthosReelPage(
                            video: video,
                            isActive: currentVideoID == video.videoId
                        )
                        .containerRelativeFrame(.vertical)
                        .id(video.videoId)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $currentVideoID)
            .ignoresSafeArea()

            AthosGlassIconButton(
                symbol: "xmark",
                size: 44,
                tint: .white,
                accessibility: "Κλείσιμο"
            ) {
                dismiss()
            }
            .padding(.top, 10)
            .padding(.trailing, 16)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .statusBarHidden(true)
        .task {
            await Task.yield()
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                currentVideoID = startVideoID
            }
        }
    }
}

private struct AthosReelPage: View {
    let video: AthosTVVideo
    let isActive: Bool
    @ObservedObject private var favorites = AthosTVFavoritesStore.shared

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if isActive {
                AthosActiveReelPlayer(video: video)
            } else {
                GeometryReader { proxy in
                    AthosRemoteThumbnail(video: video)
                        .frame(
                            width: max(proxy.size.width, proxy.size.height * 9 / 16),
                            height: proxy.size.height
                        )
                        .position(
                            x: proxy.size.width / 2,
                            y: proxy.size.height / 2
                        )
                }
                .overlay(Color.black.opacity(0.20))
            }

            LinearGradient(
                colors: [.clear, .black.opacity(0.08), .black.opacity(0.88)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 250)
            .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 8) {
                Text(video.title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                Link(destination: youTubeURL) {
                    Label("Άνοιγμα στο YouTube", systemImage: "arrow.up.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.82))
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 34)

            AthosFavoriteButton(
                isFavorite: favorites.contains(video),
                action: { favorites.toggle(video) }
            )
            .padding(.trailing, 18)
            .padding(.bottom, 102)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
        .background(Color.black)
        .clipped()
    }

    private var youTubeURL: URL {
        URL(string: video.watchUrl)
            ?? URL(string: "https://www.youtube.com/watch?v=\(video.videoId)")!
    }
}

private struct AthosActiveReelPlayer: View {
    let video: AthosTVVideo
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var player: YouTubePlayer

    init(video: AthosTVVideo) {
        self.video = video
        _player = StateObject(
            wrappedValue: YouTubePlayer(
                source: .video(id: video.videoId),
                parameters: .athosTV(autoPlay: true),
                configuration: .athosTV
            )
        )
    }

    var body: some View {
        GeometryReader { proxy in
            YouTubePlayerView(player) { state in
                switch state {
                case .idle, .ready:
                    EmptyView()
                case .error:
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(AthosPalette.gold)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.black)
                }
            }
            .frame(
                width: max(proxy.size.width, proxy.size.height * 9 / 16),
                height: proxy.size.height
            )
            .position(
                x: proxy.size.width / 2,
                y: proxy.size.height / 2
            )
        }
        .background(.black)
        .clipped()
        .onAppear {
            play()
        }
        .onReceive(player.statePublisher) { state in
            guard state.isReady else { return }
            play()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase != .active else { return }
            pause()
        }
        .onDisappear {
            pause()
        }
    }

    private func play() {
        Task {
            try? await player.play()
        }
    }

    private func pause() {
        Task {
            try? await player.pause()
        }
    }
}

// MARK: - Εἰσαγωγικὴ σήμανση

private struct AthosTVPlaybackIntro: View {
    let onFinished: () -> Void

    @State private var mountainProgress: CGFloat = 0
    @State private var crossProgress: CGFloat = 0
    @State private var wordmarkOpacity: Double = 0
    @State private var wordmarkScale: CGFloat = 0.96
    @State private var screenOpacity: Double = 1
    @State private var hasStarted = false

    var body: some View {
        ZStack {
            AthosPalette.background

            VStack(spacing: 2) {
                ZStack {
                    AthosMountainOutline()
                        .trim(from: 0, to: mountainProgress)
                        .stroke(
                            AthosPalette.ink,
                            style: StrokeStyle(
                                lineWidth: 3.2,
                                lineCap: .round,
                                lineJoin: .round
                            )
                        )

                    AthosMountainCross()
                        .trim(from: 0, to: crossProgress)
                        .stroke(
                            AthosPalette.ink,
                            style: StrokeStyle(
                                lineWidth: 3.2,
                                lineCap: .square,
                                lineJoin: .round
                            )
                        )
                }
                .frame(width: 286, height: 104)
                .shadow(color: AthosPalette.gold.opacity(0.12), radius: 8)

                Image("AthosTVWordmark")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 286, height: 72)
                    .foregroundStyle(AthosPalette.ink)
                    .opacity(wordmarkOpacity)
                    .scaleEffect(wordmarkScale)
            }
        }
        .opacity(screenOpacity)
        .ignoresSafeArea()
        .accessibilityHidden(true)
        .task {
            guard !hasStarted else { return }
            hasStarted = true

            try? await Task.sleep(for: .milliseconds(90))
            withAnimation(.easeOut(duration: 0.3)) {
                wordmarkOpacity = 1
                wordmarkScale = 1
            }

            try? await Task.sleep(for: .milliseconds(230))
            withAnimation(.easeInOut(duration: 0.82)) {
                mountainProgress = 1
            }

            try? await Task.sleep(for: .milliseconds(550))
            withAnimation(.easeOut(duration: 0.28)) {
                crossProgress = 1
            }

            try? await Task.sleep(for: .milliseconds(420))
            withAnimation(.easeInOut(duration: 0.22)) {
                screenOpacity = 0
            }

            try? await Task.sleep(for: .milliseconds(230))
            onFinished()
        }
    }
}

private struct AthosMountainOutline: Shape {
    func path(in rect: CGRect) -> Path {
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + rect.width * x, y: rect.minY + rect.height * y)
        }

        var path = Path()
        path.move(to: point(0.03, 0.90))
        path.addCurve(
            to: point(0.22, 0.62),
            control1: point(0.10, 0.82),
            control2: point(0.17, 0.60)
        )
        path.addCurve(
            to: point(0.31, 0.64),
            control1: point(0.26, 0.60),
            control2: point(0.28, 0.70)
        )
        path.addLine(to: point(0.41, 0.42))
        path.addCurve(
            to: point(0.46, 0.38),
            control1: point(0.43, 0.39),
            control2: point(0.44, 0.38)
        )
        path.addLine(to: point(0.46, 0.28))
        path.addLine(to: point(0.50, 0.20))
        path.addLine(to: point(0.54, 0.28))
        path.addLine(to: point(0.54, 0.38))
        path.addCurve(
            to: point(0.59, 0.42),
            control1: point(0.56, 0.38),
            control2: point(0.57, 0.39)
        )
        path.addLine(to: point(0.69, 0.64))
        path.addCurve(
            to: point(0.78, 0.62),
            control1: point(0.72, 0.70),
            control2: point(0.74, 0.60)
        )
        path.addCurve(
            to: point(0.97, 0.90),
            control1: point(0.83, 0.60),
            control2: point(0.90, 0.82)
        )
        return path
    }
}

private struct AthosMountainCross: Shape {
    func path(in rect: CGRect) -> Path {
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + rect.width * x, y: rect.minY + rect.height * y)
        }

        var path = Path()
        path.move(to: point(0.50, 0.20))
        path.addLine(to: point(0.50, 0.03))
        path.move(to: point(0.465, 0.085))
        path.addLine(to: point(0.535, 0.085))
        return path
    }
}
