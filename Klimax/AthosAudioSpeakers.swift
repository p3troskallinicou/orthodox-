//
//  AthosAudioSpeakers.swift
//  Klimax
//
//  Speaker directory and profile pages derived from the bundled homily archive.
//

import SwiftUI

struct AthosAudioSpeaker: Identifiable, Hashable {
    let name: String
    let episodes: [Homily]
    let videos: [AthosTVVideo]

    var id: String { name }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.name == rhs.name
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }

    var role: String {
        if name.hasPrefix("Μητροπολίτης") { return "Μητροπολίτης" }
        if name.hasPrefix("Γέροντας") { return "Γέροντας" }
        if name.hasPrefix("Αρχιμανδρίτης") { return "Αρχιμανδρίτης" }
        if name.hasPrefix("Μοναχός") { return "Μοναχός" }
        if name.hasPrefix("π.") { return "Κληρικός" }
        return "Ομιλητής"
    }

    var totalDuration: Int {
        episodes.compactMap(\.durationSeconds).reduce(0, +)
    }

    var totalMediaCount: Int {
        episodes.count + videos.count
    }

    var portraitURL: URL? {
        let preferredVideoIDs: [String: String] = [
            "Μητροπολίτης Λεμεσού Αθανάσιος": "W-qjzBRH0eg",
            "Γέροντας Εφραίμ Βατοπαιδινός": "jPD75m5XNjY",
            "Γέροντας Ιωσήφ Βατοπαιδινός": "vC-i2UKoW_s"
        ]
        if let videoID = preferredVideoIDs[name],
           let thumbnail = AthosTVCatalogue.videos.first(where: { $0.id == videoID })?.thumbnail,
           let url = URL(string: thumbnail) {
            return url
        }

        // Verified portraits for speakers who do not currently have media in Athos TV.
        let verifiedYouTubePortraits: [String: String] = [
            "Γέροντας Εφραίμ Φιλοθεΐτης": "WrHKvI1-mlI",
            "Γέροντας Αιμιλιανός Σιμωνοπετρίτης": "E6hZW00Icn8",
            "Μητροπολίτης Σισανίου και Σιατίστης Παύλος": "msPEW27z0O4",
            "Μητροπολίτης Μεσογαίας και Λαυρεωτικής Νικόλαος": "n5r_ai0aUhg",
            "Μοναχός Μωυσής Αγιορείτης": "9mOpJUX7s18",
            "Γεώργιος Παπαζάχος": "frJ1bwDPBBc"
        ]
        guard let videoID = verifiedYouTubePortraits[name] else { return nil }
        return URL(string: "https://i.ytimg.com/vi/\(videoID)/hqdefault.jpg")
    }

    var portraitAlignment: Alignment {
        switch name {
        case "Γεώργιος Παπαζάχος",
             "Γέροντας Αιμιλιανός Σιμωνοπετρίτης",
             "Γέροντας Ιωσήφ Βατοπαιδινός",
             "Μητροπολίτης Σισανίου και Σιατίστης Παύλος": .leading
        default: .center
        }
    }

    var portraitScale: CGFloat {
        switch name {
        case "Γεώργιος Παπαζάχος": 1.65
        case "Γέροντας Αιμιλιανός Σιμωνοπετρίτης": 1.50
        case "Μητροπολίτης Σισανίου και Σιατίστης Παύλος": 1.45
        case "Γέροντας Ιωσήφ Βατοπαιδινός": 1.35
        case "Γέροντας Εφραίμ Φιλοθεΐτης": 1.20
        case "Μητροπολίτης Λεμεσού Αθανάσιος",
             "Μητροπολίτης Μεσογαίας και Λαυρεωτικής Νικόλαος": 1.12
        default: 1
        }
    }

    var portraitScaleAnchor: UnitPoint {
        switch name {
        case "Γεώργιος Παπαζάχος",
             "Γέροντας Αιμιλιανός Σιμωνοπετρίτης",
             "Γέροντας Ιωσήφ Βατοπαιδινός",
             "Μητροπολίτης Σισανίου και Σιατίστης Παύλος": .leading
        default: .center
        }
    }

    var topics: [AthosAudioSpeakerTopic] {
        let counts = Dictionary(grouping: episodes, by: \.subject)
            .map { AthosAudioSpeakerTopic(name: $0.key, count: $0.value.count) }
        return counts.sorted {
            if $0.count != $1.count { return $0.count > $1.count }
            return $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    var monogram: String {
        let ignored = Set(["μητροπολίτης", "γέροντας", "αρχιμανδρίτης", "μοναχός", "π.", "και"])
        let words = name.split(separator: " ")
            .map(String.init)
            .filter { !ignored.contains($0.lowercased()) }
        let chosen = words.suffix(2)
        let value = chosen.compactMap(\.first).map(String.init).joined()
        return value.isEmpty ? "Ω" : value.uppercased()
    }

    var paletteIndex: Int {
        abs(name.unicodeScalars.reduce(0) { ($0 &* 31) &+ Int($1.value) }) % 6
    }

    var mediaSummary: String {
        var parts: [String] = []
        if !episodes.isEmpty {
            parts.append("\(episodes.count) ηχητικές")
        }
        if !videos.isEmpty {
            parts.append("\(videos.count) βίντεο")
        }
        return parts.joined(separator: "  •  ")
    }

    var videoSeries: [AthosSpeakerVideoSeries] {
        let ids = Set(videos.map(\.videoId))
        let collections = AthosTVCatalogue.presentation.collections
        var result = collections.compactMap { collection -> AthosSpeakerVideoSeries? in
            let subset = collection.limited(to: ids)
            guard !subset.videos.isEmpty else { return nil }
            return AthosSpeakerVideoSeries(name: subset.title, videos: subset.videos, collection: subset)
        }
        // Standalone videos remain accessible without inventing extra named series.
        let collectedIDs = Set(collections.flatMap { $0.videos.map(\.videoId) })
        let otherVideos = videos.filter { !collectedIDs.contains($0.videoId) }
        if !otherVideos.isEmpty {
            result.append(AthosSpeakerVideoSeries(name: "Άλλα βίντεο", videos: otherVideos))
        }
        return result
    }

    var audioCollections: [AthosSpeakerAudioCollection] {
        topics.compactMap { topic in
            let items = episodes.filter { $0.subject == topic.name }
            return items.isEmpty ? nil : AthosSpeakerAudioCollection(name: topic.name, episodes: items)
        }
    }
}

struct AthosSpeakerVideoSeries: Identifiable, Hashable {
    let name: String
    let videos: [AthosTVVideo]
    var collection: AthosTVCollection? = nil

    var id: String { collection?.id ?? name }
    var cover: AthosTVVideo? { videos.first(where: { $0.type != "reel" }) ?? videos.first }

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct AthosSpeakerAudioCollection: Identifiable, Hashable {
    let name: String
    let episodes: [Homily]

    var id: String { name }
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct AthosAudioSpeakerTopic: Identifiable, Hashable {
    let name: String
    let count: Int
    var id: String { name }
}

enum AthosAudioSpeakerCatalog {
    static func profiles(
        from episodes: [Homily],
        videos: [AthosTVVideo] = AthosTVCatalogue.presentation.videos
    ) -> [AthosAudioSpeaker] {
        var groupedAudio: [String: [Homily]] = [:]
        var groupedVideo: [String: [AthosTVVideo]] = [:]

        for episode in episodes {
            for name in episode.speakerNames where !name.isEmpty {
                groupedAudio[name, default: []].append(episode)
            }
        }

        for video in videos {
            for name in video.speakerNames where !name.isEmpty {
                groupedVideo[name, default: []].append(video)
            }
        }

        let names = Set(groupedAudio.keys).union(groupedVideo.keys)
        return names.map { name in
            AthosAudioSpeaker(
                name: name,
                episodes: groupedAudio[name, default: []].sorted {
                    ($0.episodeNumber ?? .max) < ($1.episodeNumber ?? .max)
                },
                videos: groupedVideo[name, default: []].sorted {
                    $0.publishedAt > $1.publishedAt
                }
            )
        }
        .sorted {
            if $0.totalMediaCount != $1.totalMediaCount {
                return $0.totalMediaCount > $1.totalMediaCount
            }
            return $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }
}

struct AthosAudioSpeakerAvatar: View {
    let speaker: AthosAudioSpeaker
    var size: CGFloat = 84

    private var colors: [Color] {
        let palettes: [[Color]] = [
            [.init(red: 0.12, green: 0.16, blue: 0.36), .init(red: 0.58, green: 0.41, blue: 0.12)],
            [.init(red: 0.08, green: 0.24, blue: 0.31), .init(red: 0.68, green: 0.49, blue: 0.16)],
            [.init(red: 0.23, green: 0.10, blue: 0.29), .init(red: 0.49, green: 0.36, blue: 0.67)],
            [.init(red: 0.10, green: 0.25, blue: 0.20), .init(red: 0.67, green: 0.46, blue: 0.14)],
            [.init(red: 0.29, green: 0.12, blue: 0.12), .init(red: 0.74, green: 0.46, blue: 0.20)],
            [.init(red: 0.09, green: 0.15, blue: 0.31), .init(red: 0.31, green: 0.49, blue: 0.64)]
        ]
        return palettes[speaker.paletteIndex]
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: colors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            RoundedRectangle(cornerRadius: size * 0.18, style: .continuous)
                .fill(
                    RadialGradient(
                        colors: [.white.opacity(0.18), .clear],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: size * 0.75
                    )
                )

            if let url = speaker.portraitURL {
                AsyncImage(url: url, transaction: Transaction(animation: nil)) { phase in
                    if case .success(let image) = phase {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: size, height: size, alignment: speaker.portraitAlignment)
                            .scaleEffect(speaker.portraitScale, anchor: speaker.portraitScaleAnchor)
                    } else {
                        monogram
                    }
                }
            } else {
                monogram
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: size * 0.18, style: .continuous)
                .stroke(AthosPalette.hairline, lineWidth: 0.5)
        }
        .accessibilityHidden(true)
    }

    private var monogram: some View {
        Text(speaker.monogram)
            .font(.custom("GFSDidot-Regular", size: size * 0.32))
            .foregroundStyle(Color(red: 0.99, green: 0.96, blue: 0.84))
            .minimumScaleFactor(0.6)
            .lineLimit(1)
            .padding(size * 0.18)
    }
}

struct AthosAudioSpeakersSection: View {
    let speakers: [AthosAudioSpeaker]
    let onSelect: (AthosAudioSpeaker) -> Void
    let onShowAll: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text("Ομιλητές")
                    .font(.system(size: 23, weight: .bold))
                    .foregroundStyle(AthosPalette.ink)

                Spacer()

                Button("Όλοι", action: onShowAll)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AthosAudioPalette.gold)
            }
            .padding(.horizontal, 18)

            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: 18) {
                    ForEach(speakers.prefix(12)) { speaker in
                        Button {
                            onSelect(speaker)
                        } label: {
                            VStack(alignment: .leading, spacing: 10) {
                                AthosAudioSpeakerAvatar(speaker: speaker, size: 136)

                                Text(speaker.name.interfaceGreek)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(AthosPalette.ink)
                                    .multilineTextAlignment(.leading)
                                    .lineLimit(2)
                                    .frame(width: 136, alignment: .leading)

                                Text(speaker.mediaSummary)
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(AthosAudioPalette.secondary)
                                    .lineLimit(2)
                                    .frame(width: 136, alignment: .leading)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 4)
            }
            .scrollIndicators(.hidden)
        }
    }
}

struct AthosAudioSpeakerDirectoryView: View {
    let speakers: [AthosAudioSpeaker]
    @State private var query = ""

    private var filtered: [AthosAudioSpeaker] {
        let value = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return speakers }
        return speakers.filter {
            $0.name.localizedCaseInsensitiveContains(value)
                || $0.role.localizedCaseInsensitiveContains(value)
                || $0.topics.contains { $0.name.localizedCaseInsensitiveContains(value) }
        }
    }

    var body: some View {
        ZStack {
            AthosAudioPalette.background.ignoresSafeArea()

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filtered) { speaker in
                        NavigationLink {
                            AthosAudioSpeakerProfileView(speaker: speaker)
                        } label: {
                            AthosAudioSpeakerDirectoryRow(speaker: speaker)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 80)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Ομιλητές")
        .navigationBarTitleDisplayMode(.large)
        .toolbar(.visible, for: .navigationBar)
        .searchable(text: $query, prompt: "Όνομα ή θέμα")
        .tint(AthosAudioPalette.gold)
        .toolbarBackground(AthosAudioPalette.background.opacity(0.94), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }
}

private struct AthosAudioSpeakerDirectoryRow: View {
    let speaker: AthosAudioSpeaker

    var body: some View {
        HStack(spacing: 16) {
            AthosAudioSpeakerAvatar(speaker: speaker, size: 68)

            VStack(alignment: .leading, spacing: 6) {
                Text(speaker.name.interfaceGreek)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(AthosPalette.ink)
                    .multilineTextAlignment(.leading)

                Text("\(speaker.role)  •  \(speaker.mediaSummary)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AthosAudioPalette.secondary)
                    .lineLimit(1)

                if let topic = speaker.topics.first {
                    Text(topic.name.interfaceGreek)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AthosAudioPalette.gold.opacity(0.88))
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(AthosPalette.tertiaryText)
        }
        .padding(.vertical, 13)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AthosPalette.hairline)
                .frame(height: 0.7)
                .padding(.leading, 84)
        }
    }
}

private enum AthosSpeakerMediaFilter: String, CaseIterable, Identifiable {
    case all
    case audio
    case video

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "Όλα"
        case .audio: "Ήχος"
        case .video: "Βίντεο"
        }
    }

    var symbol: String {
        switch self {
        case .all: "square.grid.2x2.fill"
        case .audio: "waveform"
        case .video: "play.rectangle.fill"
        }
    }
}

struct AthosAudioSpeakerProfileView: View {
    let speaker: AthosAudioSpeaker

    @ObservedObject private var player = HomilyPlayer.shared
    @State private var selectedMedia: AthosSpeakerMediaFilter = .all
    @State private var selectedSeries: AthosSpeakerVideoSeries?
    @State private var selectedAudioCollection: AthosSpeakerAudioCollection?

    private var showsAudio: Bool {
        selectedMedia != .video && !speaker.episodes.isEmpty
    }

    private var showsVideo: Bool {
        selectedMedia != .audio && !speaker.videos.isEmpty
    }

    var body: some View {
        ZStack(alignment: .top) {
            AthosAudioPalette.background.ignoresSafeArea()

            profileGradient
                .frame(height: 230)
                .blur(radius: 24)
                .ignoresSafeArea(edges: Edge.Set.top)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    profileHero

                    if !speaker.episodes.isEmpty && !speaker.videos.isEmpty {
                        mediaPicker
                            .padding(.horizontal, 18)
                            .padding(.top, 20)
                    }

                    if showsVideo {
                        sectionHeading("Σειρές βίντεο", count: speaker.videoSeries.count)
                        ScrollView(.horizontal) {
                            LazyHStack(spacing: 14) {
                                ForEach(speaker.videoSeries) { series in
                                    Button {
                                        selectedSeries = series
                                    } label: {
                                        AthosSpeakerVideoSeriesCard(series: series)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 18)
                            .padding(.vertical, 4)
                        }
                        .scrollIndicators(.hidden)
                    }

                    if showsAudio {
                        sectionHeading("Θέματα ήχου", count: speaker.audioCollections.count)
                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 150), spacing: 12)],
                            spacing: 12
                        ) {
                            ForEach(speaker.audioCollections) { collection in
                                Button {
                                    selectedAudioCollection = collection
                                } label: {
                                    AthosSpeakerAudioCollectionCard(collection: collection)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 18)
                    }

                    Spacer(minLength: 100)
                }
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle(speaker.name.interfaceGreek)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .tint(AthosAudioPalette.gold)
        .navigationDestination(item: $selectedSeries) { series in
            AthosSpeakerVideoSeriesView(speaker: speaker, series: series)
        }
        .navigationDestination(item: $selectedAudioCollection) { collection in
            AthosSpeakerAudioCollectionView(speaker: speaker, collection: collection)
        }
    }

    private var profileHero: some View {
        ZStack {
            profileGradient

            Circle()
                .fill(AthosAudioPalette.gold.opacity(0.12))
                .frame(width: 230, height: 230)
                .blur(radius: 54)
                .offset(x: 130, y: -110)

            Circle()
                .stroke(.white.opacity(0.055), lineWidth: 1)
                .frame(width: 300, height: 300)
                .offset(x: -155, y: 125)

            VStack(spacing: 13) {
                AthosAudioSpeakerAvatar(speaker: speaker, size: 112)

                Text(speaker.role.uppercased())
                    .font(.system(size: 11, weight: .heavy))
                    .tracking(2.4)
                    .foregroundStyle(AthosAudioPalette.gold)

                Text(speaker.name.interfaceGreek)
                    .font(.custom("GFSDidot-Regular", size: 30))
                    .foregroundStyle(AthosPalette.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.82)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    if !speaker.episodes.isEmpty {
                        profileStat(value: speaker.episodes.count, label: "Ηχητικές", symbol: "waveform")
                    }
                    if !speaker.videos.isEmpty {
                        profileStat(value: speaker.videos.count, label: "Βίντεο", symbol: "play.rectangle.fill")
                    }
                    if !speaker.topics.isEmpty {
                        profileStat(value: speaker.topics.count, label: "Θέματα", symbol: "text.line.first.and.arrowtriangle.forward")
                    }
                }

                if let first = speaker.episodes.first(where: \.isAudioAvailable) {
                    heroButton("Ακρόαση", symbol: "play.fill", prominent: true) {
                        play(first, in: speaker.episodes)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 24)
        }
        .frame(maxWidth: .infinity)
        .background(AthosAudioPalette.elevated)
        .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 28, bottomTrailingRadius: 28))
    }

    private var profileGradient: some View {
        LinearGradient(
            colors: [AthosAudioPalette.elevated, AthosAudioPalette.gold.opacity(0.24), AthosAudioPalette.background],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func profileStat(value: Int, label: String, symbol: String) -> some View {
        VStack(spacing: 3) {
            Label("\(value)", systemImage: symbol)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(AthosPalette.ink)
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(AthosAudioPalette.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 57)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(.white.opacity(0.12), lineWidth: 0.7)
        }
    }

    private func heroButton(
        _ title: String,
        symbol: String,
        prominent: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(prominent ? AthosPalette.onAccent : AthosPalette.ink)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    prominent ? AnyShapeStyle(AthosPalette.gold) : AnyShapeStyle(.ultraThinMaterial),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )
                .overlay {
                    if !prominent {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(.white.opacity(0.16), lineWidth: 0.8)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    private var mediaPicker: some View {
        HStack(spacing: 6) {
            ForEach(AthosSpeakerMediaFilter.allCases) { filter in
                Button {
                    withAnimation(.easeInOut(duration: 0.22)) {
                        selectedMedia = filter
                    }
                } label: {
                    Label(filter.title, systemImage: filter.symbol)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(selectedMedia == filter ? AthosPalette.onAccent : AthosPalette.ink)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(
                            selectedMedia == filter ? AthosAudioPalette.gold : .clear,
                            in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(5)
        .background(AthosAudioPalette.panel, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(.white.opacity(0.11), lineWidth: 0.8)
        }
    }

    private func sectionHeading(_ title: String, count: Int) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: 23, weight: .bold))
                .foregroundStyle(AthosPalette.ink)
            Spacer()
            Text("\(count)")
                .font(.caption.weight(.bold))
                .foregroundStyle(AthosAudioPalette.secondary)
        }
        .padding(.horizontal, 18)
        .padding(.top, 30)
        .padding(.bottom, 8)
    }

    private func play(_ episode: Homily, in episodes: [Homily]) {
        guard episode.isAudioAvailable else { return }
        let following = Array(
            episodes
                .drop(while: { $0.id != episode.id })
                .dropFirst()
                .filter(\.isAudioAvailable)
        )
        player.present(episode, context: speaker.name, upNext: following)
    }
}

private struct AthosSpeakerVideoSeriesCard: View {
    let series: AthosSpeakerVideoSeries

    var body: some View {
        Group {
            if let collection = series.collection {
                AthosSeriesCard(collection: collection)
            } else {
                VStack(alignment: .leading, spacing: 9) {
                    if let cover = series.cover {
                        AthosSpeakerRemoteImage(urlString: cover.thumbnail)
                            .frame(width: 180, height: 180)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    Text(series.name).font(.subheadline.weight(.medium))
                    Text("\(series.videos.count) βίντεο")
                        .font(.subheadline).foregroundStyle(AthosPalette.secondaryText)
                }.foregroundStyle(AthosPalette.ink)
            }
        }
        .frame(width: 180, alignment: .leading)
        .contentShape(Rectangle())
    }
}

private struct AthosSpeakerAudioCollectionCard: View {
    let collection: AthosSpeakerAudioCollection

    private var accent: Color {
        let colors: [Color] = [
            AthosAudioPalette.gold,
            .init(red: 0.42, green: 0.62, blue: 0.74),
            .init(red: 0.55, green: 0.42, blue: 0.70),
            .init(red: 0.36, green: 0.64, blue: 0.51),
            .init(red: 0.76, green: 0.43, blue: 0.30)
        ]
        let hash = abs(collection.name.unicodeScalars.reduce(0) { ($0 &* 31) &+ Int($1.value) })
        return colors[hash % colors.count]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "waveform")
                    .font(.system(size: 21, weight: .bold))
                    .foregroundStyle(accent)

                Spacer()

                Text("\(collection.episodes.count)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AthosAudioPalette.secondary)
            }

            Text(collection.name.interfaceGreek)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(AthosPalette.ink)
                .multilineTextAlignment(.leading)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("Ηχητικές ομιλίες")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(AthosAudioPalette.secondary)
        }
        .padding(15)
        .frame(maxWidth: .infinity, minHeight: 138, alignment: .topLeading)
        .background(
            LinearGradient(
                colors: [accent.opacity(0.20), AthosAudioPalette.panel],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 15, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(accent.opacity(0.20), lineWidth: 0.8)
        }
    }
}

private struct AthosSpeakerVideoSeriesView: View {
    let speaker: AthosAudioSpeaker
    let series: AthosSpeakerVideoSeries

    @State private var selectedVideo: AthosTVVideo?

    var body: some View {
        if let collection = series.collection {
            AthosSeriesDetailView(collection: collection)
        } else {
            standaloneVideos
        }
    }

    private var standaloneVideos: some View {
        ZStack {
            AthosAudioPalette.background.ignoresSafeArea()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    collectionHeader(
                        title: series.name,
                        subtitle: "\(speaker.name)  •  \(series.videos.count) βίντεο",
                        symbol: "play.rectangle.fill"
                    )

                    ForEach(Array(series.videos.enumerated()), id: \.element.id) { index, video in
                        AthosSpeakerVideoRow(number: index + 1, video: video) {
                            selectedVideo = video
                        }
                    }
                    Spacer(minLength: 80)
                }
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle(series.name.interfaceGreek)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(AthosAudioPalette.background.opacity(0.94), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .fullScreenCover(item: $selectedVideo) { video in
            AthosTVPlayerScreen(video: video)
        }
    }
}

private struct AthosSpeakerAudioCollectionView: View {
    let speaker: AthosAudioSpeaker
    let collection: AthosSpeakerAudioCollection

    @ObservedObject private var player = HomilyPlayer.shared

    var body: some View {
        ZStack {
            AthosAudioPalette.background.ignoresSafeArea()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    collectionHeader(
                        title: collection.name,
                        subtitle: "\(speaker.name)  •  \(collection.episodes.count) ηχητικές",
                        symbol: "waveform"
                    )

                    ForEach(Array(collection.episodes.enumerated()), id: \.element.id) { index, episode in
                        AthosAudioSpeakerEpisodeRow(number: index + 1, episode: episode) {
                            play(episode, index: index)
                        }
                    }
                    Spacer(minLength: 80)
                }
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle(collection.name.interfaceGreek)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(AthosAudioPalette.background.opacity(0.94), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }

    private func play(_ episode: Homily, index: Int) {
        guard episode.isAudioAvailable else { return }
        player.present(
            episode,
            context: collection.name,
            upNext: Array(collection.episodes.dropFirst(index + 1)).filter(\.isAudioAvailable)
        )
    }
}

private func collectionHeader(title: String, subtitle: String, symbol: String) -> some View {
    VStack(alignment: .leading, spacing: 13) {
        Image(systemName: symbol)
            .font(.system(size: 32, weight: .bold))
            .foregroundStyle(AthosAudioPalette.gold)
            .frame(width: 66, height: 66)
            .background(AthosAudioPalette.gold.opacity(0.12), in: RoundedRectangle(cornerRadius: 17))

        Text(title)
            .font(.custom("GFSDidot-Regular", size: 31))
            .foregroundStyle(AthosPalette.ink)
            .fixedSize(horizontal: false, vertical: true)

        Text(subtitle)
            .font(.caption.weight(.semibold))
            .foregroundStyle(AthosAudioPalette.secondary)
    }
    .padding(.horizontal, 18)
    .padding(.top, 28)
    .padding(.bottom, 20)
}

private struct AthosSpeakerVideoRow: View {
    let number: Int
    let video: AthosTVVideo
    let onPlay: () -> Void

    var body: some View {
        Button(action: onPlay) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    AthosSpeakerRemoteImage(urlString: video.thumbnail)
                    Image(systemName: video.type == "reel" ? "rectangle.portrait.fill" : "play.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(.black.opacity(0.62), in: Circle())
                }
                .frame(width: 126, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    Text(video.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AthosPalette.ink)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)

                    Text([video.durationText, video.publishedYear]
                        .filter { !$0.isEmpty }
                        .joined(separator: "  •  "))
                        .font(.caption)
                        .foregroundStyle(AthosAudioPalette.secondary)
                    AthosPlaybackStatus(id: video.videoId, duration: Double(video.durationSeconds))
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text("\(number)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(AthosPalette.tertiaryText)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AthosPalette.hairline)
                .frame(height: 0.7)
                .padding(.leading, 158)
        }
        .modifier(AthosEpisodeSurface(id: video.videoId))
    }
}

private struct AthosSpeakerRemoteImage: View {
    let urlString: String

    var body: some View {
        AsyncImage(url: URL(string: urlString), transaction: Transaction(animation: nil)) { phase in
            if case .success(let image) = phase {
                image.resizable().scaledToFill()
            } else {
                ZStack {
                    AthosAudioPalette.elevated
                    Image(systemName: "play.rectangle.fill")
                        .foregroundStyle(AthosAudioPalette.gold)
                }
            }
        }
        .clipped()
    }
}

private struct AthosAudioSpeakerEpisodeRow: View {
    let number: Int
    let episode: Homily
    let onPlay: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onPlay) {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(AthosAudioPalette.panel)

                        Image(systemName: "waveform")
                            .font(.system(size: 21, weight: .medium))
                            .foregroundStyle(AthosAudioPalette.gold)

                        Text("\(number)")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(AthosPalette.secondaryText)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            .padding(6)
                    }
                    .frame(width: 92, height: 60)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(episode.title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AthosPalette.ink)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        Text([episode.subject, episode.durationSeconds.map { timeLabel(Double($0)) }]
                            .compactMap { $0 }
                            .joined(separator: "  •  "))
                            .font(.caption)
                            .foregroundStyle(AthosAudioPalette.secondary)
                            .lineLimit(1)
                        AthosPlaybackStatus(id: episode.id, duration: Double(episode.durationSeconds ?? 0))
                    }

                    Spacer(minLength: 2)
                }
            }
            .buttonStyle(.plain)
            .disabled(!episode.isAudioAvailable)

            if episode.isAudioAvailable {
                HomilyDownloadButton(
                    homily: episode,
                    compact: true,
                    tint: AthosAudioPalette.gold,
                    muted: AthosAudioPalette.secondary
                )
            } else {
                Image(systemName: "externaldrive.badge.exclamationmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AthosAudioPalette.secondary)
                    .frame(width: 36)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 11)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AthosPalette.hairline)
                .frame(height: 0.7)
                .padding(.leading, 124)
        }
        .modifier(AthosEpisodeSurface(id: episode.id))
    }
}

private func speakerDuration(_ seconds: Int) -> String {
    let hours = seconds / 3600
    let minutes = (seconds % 3600) / 60
    if hours > 0, minutes > 0 { return "\(hours)ω \(minutes)λ" }
    if hours > 0 { return "\(hours)ω" }
    return "\(max(minutes, 1))λ"
}
