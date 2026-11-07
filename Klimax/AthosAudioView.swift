//
//  AthosAudioView.swift
//  Klimax
//
//  A cinematic home for the existing spoken-word catalogue.
//

import SwiftUI

enum AthosMediaMode: String, CaseIterable, Identifiable {
    case television
    case audio

    var id: String { rawValue }

    var title: String {
        switch self {
        case .television: "Athos TV"
        case .audio: "Athos Audio"
        }
    }

    var symbol: String {
        switch self {
        case .television: "play.tv.fill"
        case .audio: "waveform"
        }
    }
}

struct AthosMediaBrandMenu: View {
    @Binding var selection: AthosMediaMode
    var foreground: Color = .primary
    var condensed = false

    var body: some View {
        Menu {
            ForEach(AthosMediaMode.allCases) { mode in
                Button {
                    selection = mode
                } label: {
                    Label(mode.title, systemImage: selection == mode ? "checkmark" : mode.symbol)
                }
            }
        } label: {
            HStack(spacing: 5) {
                AthosMediaWordmark(mode: selection, foreground: foreground, condensed: condensed)

                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(foreground.opacity(0.7))
            }
            .frame(minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(selection.title), αλλαγή μέσου")
    }
}

private struct AthosMediaWordmark: View {
    let mode: AthosMediaMode
    let foreground: Color
    let condensed: Bool

    var body: some View {
        Text(mode.title)
            .font(.system(size: condensed ? 26 : 34, weight: .heavy))
            .tracking(-1)
            .foregroundStyle(foreground)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .accessibilityHidden(true)
    }
}

struct AthosAudioView: View {
    @Binding var mediaMode: AthosMediaMode

    @ObservedObject private var store = HomilyStore.shared
    // This screen issues playback commands but does not display the playback clock.
    // Keep clock updates confined to the player and mini-player.
    private let player = HomilyPlayer.shared
    @State private var selectedSubject: AthosAudioSubjectPresentation?
    @State private var selectedSpeaker: AthosAudioSpeaker?
    @State private var showsSpeakerDirectory = false
    @State private var isSearching = false
    @State private var jumpTarget: String?
    @State private var headerCondensed = false
    @State private var lastListened = LastListened.load()

    private var audioSubjects: [Subject] {
        store.subjects.compactMap { subject in
            let episodes = subject.episodes.filter { !$0.isVideo }
            return episodes.isEmpty ? nil : Subject(id: subject.id, episodes: episodes)
        }
    }

    private var allEpisodes: [Homily] {
        audioSubjects.flatMap(\.episodes)
    }

    private var playableEpisodes: [Homily] {
        allEpisodes.filter(\.isAudioAvailable)
    }

    private var speakerProfiles: [AthosAudioSpeaker] {
        AthosAudioSpeakerCatalog.profiles(from: allEpisodes)
    }

    private var listeningSelection: [Homily] {
        let episodes = playableEpisodes.sorted { $0.id < $1.id }
        guard !episodes.isEmpty else { return [] }
        let day = Calendar.current.ordinality(of: .day, in: .era, for: Date()) ?? 0
        let start = day % episodes.count
        return (0..<min(10, episodes.count)).map { episodes[(start + ($0 * 17)) % episodes.count] }
    }

    private var editorialEpisodes: [Homily] {
        var items = listeningSelection
        if let snapshot = lastListened, !snapshot.homily.isVideo, snapshot.homily.isAudioAvailable {
            items.insert(snapshot.homily, at: 0)
        }
        var seen = Set<String>()
        return Array(items.filter { seen.insert($0.id).inserted }.prefix(6))
    }

    var body: some View {
        ZStack(alignment: .top) {
            if store.isLoading && store.subjects.isEmpty {
                ProgressView()
                    .tint(AthosAudioPalette.gold)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = store.errorText, store.subjects.isEmpty {
                ContentUnavailableView(
                    "Athos Audio",
                    systemImage: "waveform",
                    description: Text(error)
                )
                .foregroundStyle(AthosPalette.ink)
            } else {
                catalogue
            }

            audioHeader
                .frame(height: headerCondensed ? 58 : 76)
                .background {
                    if headerCondensed {
                        Rectangle().fill(.regularMaterial).ignoresSafeArea(edges: .top)
                    } else {
                        AthosPodcastStyle.background.ignoresSafeArea(edges: .top)
                    }
                }
                .zIndex(3)
        }
        .background { AthosPodcastStyle.background.ignoresSafeArea() }
        .animation(.easeInOut(duration: 0.2), value: headerCondensed)
        .task {
            if store.subjects.isEmpty {
                await store.load()
            }
        }
        .onAppear {
            lastListened = LastListened.load()
        }
        .navigationDestination(item: $selectedSubject) { presentation in
            AthosAudioSubjectView(
                title: presentation.title,
                episodes: presentation.episodes,
                speakers: speakerProfiles
            )
        }
        .navigationDestination(item: $selectedSpeaker) { speaker in
            AthosAudioSpeakerProfileView(speaker: speaker)
        }
        .navigationDestination(isPresented: $showsSpeakerDirectory) {
            AthosAudioSpeakerDirectoryView(speakers: speakerProfiles)
        }
        .fullScreenCover(isPresented: $isSearching) {
            AthosAudioSearchView(episodes: allEpisodes, speakers: speakerProfiles)
        }
    }

    private var catalogue: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 30) {
                    if !editorialEpisodes.isEmpty {
                        AthosAudioEditorialShelf(episodes: editorialEpisodes) {
                            play($0, context: $0.subject)
                        }
                        .id(AthosAudioAnchor.top)
                        .athosMediaRise(order: 0, trigger: mediaMode)
                    }

                    if !audioSubjects.isEmpty {
                        AthosAudioSeriesSection(subjects: audioSubjects) { subject in
                            selectedSubject = AthosAudioSubjectPresentation(
                                title: subject.name, episodes: subject.episodes)
                        }
                        .id(AthosAudioAnchor.series)
                        .athosMediaRise(order: 1, trigger: mediaMode)
                    }

                    if !listeningSelection.isEmpty {
                        AthosAudioEpisodeShelf(
                            title: "Για ακρόαση",
                            episodes: listeningSelection,
                            onPlay: { play($0, context: $0.subject) }
                        )
                        .id(AthosAudioAnchor.listening)
                        .athosMediaRise(order: 2, trigger: mediaMode)
                    }

                    if !speakerProfiles.isEmpty {
                        AthosAudioSpeakersSection(
                            speakers: speakerProfiles,
                            onSelect: { selectedSpeaker = $0 },
                            onShowAll: { showsSpeakerDirectory = true }
                        )
                        .id(AthosAudioAnchor.speakers)
                        .athosMediaRise(order: 3, trigger: mediaMode)
                    }

                    Spacer(minLength: 120)
                }
                .padding(.top, 92)
            }
            .scrollIndicators(.hidden)
            .onScrollGeometryChange(for: Bool.self) { geometry in
                geometry.contentOffset.y + geometry.contentInsets.top > 24
            } action: { _, condensed in
                headerCondensed = condensed
            }
            .onChange(of: jumpTarget) { _, target in
                guard let target else { return }
                withAnimation(.smooth(duration: 0.46)) {
                    proxy.scrollTo(target, anchor: .top)
                }
                jumpTarget = nil
            }
        }
    }

    private var audioHeader: some View {
        HStack(spacing: 12) {
            AthosMediaBrandMenu(selection: $mediaMode, condensed: headerCondensed)

            Spacer(minLength: 8)

            Menu {
                Button {
                    jumpTarget = AthosAudioAnchor.top
                } label: {
                    Label("Αρχική", systemImage: "house.fill")
                }

                Button {
                    jumpTarget = AthosAudioAnchor.listening
                } label: {
                    Label("Για ακρόαση", systemImage: "headphones")
                }

                Button {
                    jumpTarget = AthosAudioAnchor.speakers
                } label: {
                    Label("Ομιλητές", systemImage: "person.2.fill")
                }

                Button {
                    jumpTarget = AthosAudioAnchor.series
                } label: {
                    Label("Θέματα", systemImage: "rectangle.stack.fill")
                }
            } label: {
                AthosAudioHeaderCircle(symbol: "line.3.horizontal")
            }
            .accessibilityLabel("Ενότητες Athos Audio")

            Button {
                isSearching = true
            } label: {
                AthosAudioHeaderCircle(symbol: "magnifyingglass")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Αναζήτηση")
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 2)
    }

    private func play(_ episode: Homily, context: String) {
        let subjectEpisodes = audioSubjects
            .first(where: { $0.name == context })?
            .episodes ?? []
        let upcoming = Array(
            subjectEpisodes
                .drop(while: { $0.id != episode.id })
                .dropFirst()
                .filter(\.isAudioAvailable)
        )
        player.present(episode, context: context, upNext: upcoming)
        lastListened = LastListened.load()
    }
}

struct AthosMediaRiseModifier<Trigger: Equatable>: ViewModifier {
    let order: Int
    let trigger: Trigger

    @State private var isSettled = false

    func body(content: Content) -> some View {
        content
            .opacity(isSettled ? 1 : 0)
            .offset(y: isSettled ? 0 : 34)
            .onAppear(perform: animateIntoPlace)
            .onChange(of: trigger) { _, _ in
                isSettled = false
                animateIntoPlace()
            }
            .onDisappear {
                isSettled = false
            }
    }

    private func animateIntoPlace() {
        guard !isSettled else { return }
        withAnimation(
            .spring(response: 0.54, dampingFraction: 0.90)
                .delay(Double(min(order, 6)) * 0.075)
        ) {
            isSettled = true
        }
    }
}

extension View {
    func athosMediaRise<Trigger: Equatable>(
        order: Int,
        trigger: Trigger
    ) -> some View {
        modifier(AthosMediaRiseModifier(order: order, trigger: trigger))
    }
}

enum AthosAudioPalette {
    static let background = AthosPalette.background
    static let elevated = AthosPalette.elevated
    static let panel = AthosPalette.panel
    static let line = AthosPalette.hairline
    static let gold = AthosPalette.gold
    static let secondary = AthosPalette.secondaryText
}

private enum AthosAudioAnchor {
    static let top = "athos-audio-top"
    static let listening = "athos-audio-listening"
    static let speakers = "athos-audio-speakers"
    static let series = "athos-audio-series"
}

private struct AthosAudioSubjectPresentation: Identifiable, Hashable {
    let title: String
    let episodes: [Homily]
    var id: String { title }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.title == rhs.title
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(title)
    }
}

private struct AthosAudioHeaderCircle: View {
    let symbol: String

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 19, weight: .semibold))
            .foregroundStyle(AthosPalette.ink)
            .frame(width: 44, height: 44)
            .contentShape(Circle())
            .glassCircleFallback(shape: Circle())
    }
}

private struct AthosAudioEditorialShelf: View {
    let episodes: [Homily]
    let onPlay: (Homily) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Για σένα").font(.system(size: 25, weight: .bold)).padding(.horizontal, 20)
            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: 14) {
                    ForEach(episodes) { episode in
                        AthosAudioEditorialCard(episode: episode) { onPlay(episode) }
                            .containerRelativeFrame(.horizontal) { width, _ in min(310, width * 0.72) }
                    }
                }.scrollTargetLayout()
            }
            .contentMargins(.horizontal, 20, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned).scrollIndicators(.hidden)
        }
    }
}

private struct AthosAudioEditorialCard: View {
    let episode: Homily
    let onPlay: () -> Void
    private var tone: Color { AthosPodcastStyle.tone(for: AthosAudioCoverLibrary.assetName(for: episode.subject)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onPlay) {
                AthosPodcastCover(title: episode.subject)
                    .aspectRatio(1.4, contentMode: .fit)
            }.buttonStyle(.plain).accessibilityLabel(episode.subject.interfaceGreek)
            VStack(alignment: .leading, spacing: 6) {
                Text(MediaProgress.shared.resumeSeconds(for: episode.id) > 0 ? "Συνέχισε την ακρόαση" : "Για ακρόαση")
                    .font(.system(size: 12, weight: .semibold)).foregroundStyle(.white.opacity(0.6))
                Button(action: onPlay) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(episode.title).font(.system(size: 18, weight: .bold))
                            .lineLimit(2, reservesSpace: true).foregroundStyle(.white)
                        Text(episode.hook?.isEmpty == false ? episode.hook! : episode.subject.interfaceGreek)
                            .font(.system(size: 14)).foregroundStyle(.white.opacity(0.75))
                            .lineLimit(2, reservesSpace: true)
                    }
                    .multilineTextAlignment(.leading).frame(maxWidth: .infinity, alignment: .leading)
                }.buttonStyle(.plain)
                HStack {
                    Button(action: onPlay) {
                        AthosPlaybackPill(id: episode.id, duration: Double(episode.durationSeconds ?? 0))
                            .background(.white.opacity(0.96), in: Capsule())
                            .environment(\.colorScheme, .light)
                    }.buttonStyle(.plain)
                    Spacer(minLength: 0)
                    Menu {
                        Button("Αναπαραγωγή", systemImage: "play.fill", action: onPlay)
                        Button("Επόμενο στην ουρά", systemImage: "text.line.first.and.arrowtriangle.forward") {
                            HomilyPlayer.shared.playNext(episode)
                        }
                        Button("Προσθήκη στην ουρά", systemImage: "text.append") {
                            HomilyPlayer.shared.addToQueue(episode)
                        }
                    } label: {
                        Image(systemName: "ellipsis").font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.white.opacity(0.65)).frame(width: 44, height: 44)
                    }.accessibilityLabel("Επιλογές ομιλίας")
                }.padding(.top, 4)
            }.padding(16)
        }
        .background(tone)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct AthosAudioContinueCard: View {
    let snapshot: LastListened.Snapshot
    let onPlay: () -> Void

    private var progress: Double {
        PlaybackProgress.fraction(
            for: snapshot.homily.id,
            duration: snapshot.homily.durationSeconds
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Συνέχισε την ακρόαση")
                .font(.system(size: 23, weight: .bold))
                .foregroundStyle(AthosPalette.ink)
                .padding(.horizontal, 18)

            Button(action: onPlay) {
                HStack(spacing: 15) {
                    AthosAudioArtwork(
                        title: snapshot.context,
                        prominent: false,
                        showsTitle: false
                    )
                    .frame(width: 68, height: 68)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                    VStack(alignment: .leading, spacing: 7) {
                        Text(snapshot.homily.title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(AthosPalette.ink)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        Text(snapshot.context.interfaceGreek)
                            .font(.caption)
                            .foregroundStyle(AthosAudioPalette.secondary)
                            .lineLimit(1)

                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(AthosPalette.hairline)
                                Capsule()
                                    .fill(AthosAudioPalette.gold)
                                    .frame(width: max(4, geometry.size.width * progress))
                            }
                        }
                        .frame(height: 3)
                    }

                    Image(systemName: "play.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(AthosPalette.onAccent)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(AthosAudioPalette.gold))
                }
                .padding(12)
                .background(
                    AthosAudioPalette.panel,
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(AthosAudioPalette.line.opacity(0.42), lineWidth: 0.8)
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 18)
        }
    }
}

private struct AthosAudioEpisodeShelf: View {
    let title: String
    let episodes: [Homily]
    let onPlay: (Homily) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title.interfaceGreek)
                .font(.system(size: 23, weight: .bold))
                .foregroundStyle(AthosPalette.ink)
                .padding(.horizontal, 18)

            ScrollView(.horizontal) {
                LazyHStack(spacing: 12) {
                    ForEach(episodes) { episode in
                        Button {
                            onPlay(episode)
                        } label: {
                            VStack(alignment: .leading, spacing: 9) {
                                AthosAudioArtwork(
                                    title: episode.subject,
                                    prominent: false
                                )
                                .frame(width: 164, height: 164)
                                .mediaProgressRow(id: episode.id, duration: Double(episode.durationSeconds ?? 0))
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                                Text(episode.title)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(AthosPalette.ink)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                                    .frame(width: 164, alignment: .leading)

                                if let duration = episode.durationSeconds {
                                    Text(timeLabel(Double(duration)))
                                        .font(.caption)
                                        .foregroundStyle(AthosAudioPalette.secondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 18)
            }
            .scrollIndicators(.hidden)
        }
    }

}

private struct AthosAudioSeriesSection: View {
    let subjects: [Subject]
    let onSelect: (Subject) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Θέματα").font(.system(size: 25, weight: .bold)).padding(.horizontal, 20)
            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: 14) {
                    ForEach(subjects) { subject in
                        Button { onSelect(subject) } label: {
                            VStack(alignment: .leading, spacing: 9) {
                                AthosPodcastCover(title: subject.name, fades: false)
                                    .frame(width: 164, height: 164)
                                    .clipShape(RoundedRectangle(cornerRadius: 9))
                                Text("\(subject.episodes.count) ομιλίες")
                                    .font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(subject.name.interfaceGreek), \(subject.episodes.count) ομιλίες")
                    }
                }.padding(.horizontal, 20)
            }.scrollIndicators(.hidden)
        }
    }
}

struct AthosAudioArtwork: View {
    let title: String
    let prominent: Bool
    var showsTitle = true

    var body: some View {
        GeometryReader { geometry in
        ZStack(alignment: .leading) {
            Image(AthosAudioCoverLibrary.assetName(for: title))
                .resizable()
                .interpolation(.high)
                .scaledToFill()
                .frame(width: geometry.size.width, height: geometry.size.height)

            LinearGradient(
                colors: [
                    Color(red: 0.99, green: 0.97, blue: 0.91)
                        .opacity(prominent ? 0.78 : 0.70),
                    Color(red: 0.99, green: 0.97, blue: 0.91)
                        .opacity(prominent ? 0.30 : 0.22),
                    Color.clear
                ],
                startPoint: .leading,
                endPoint: .trailing
            )

            if showsTitle {
                VStack(alignment: .leading, spacing: 7) {
                    Text("ATHOS AUDIO")
                        .font(.system(size: prominent ? 9 : 7, weight: .bold))
                        .tracking(prominent ? 2.5 : 1.8)
                        .foregroundStyle(Color(red: 0.52, green: 0.39, blue: 0.12))

                    Text(title.interfaceGreek)
                        .font(.system(
                            size: prominent ? 22 : 13,
                            weight: .semibold,
                            design: .serif
                        ))
                        .foregroundStyle(Color(red: 0.14, green: 0.14, blue: 0.13))
                        .lineLimit(prominent ? 3 : 2)
                        .minimumScaleFactor(0.72)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: prominent ? 190 : 112, alignment: .leading)
                }
                .padding(prominent ? 18 : 12)
            }
        }
        .frame(width: geometry.size.width, height: geometry.size.height)
        .clipped()
        }
    }
}

enum AthosAudioCoverLibrary {
    static func assetName(for topic: String) -> String {
        switch topic {
        case "Πνευματικὴ ζωὴ & ἀγώνας":
            "AthosAudioCoverSpiritualLife"
        case "Πνευματικὸς πόλεμος":
            "AthosAudioCoverSpiritualWar"
        case "Μετάνοια, πένθος & ταπείνωση":
            "AthosAudioCoverRepentance"
        case "Προσευχή":
            "AthosAudioCoverPrayer"
        case "Πάθη & λογισμοί":
            "AthosAudioCoverThoughts"
        case "Ἀρετὲς & καρποὶ τοῦ Πνεύματος":
            "AthosAudioCoverVirtues"
        case "Αὐτογνωσία":
            "AthosAudioCoverSelfKnowledge"
        case "Οἱ Δέκα Ἐντολές":
            "AthosAudioCoverCommandments"
        case "Οἱ Μακαρισμοί":
            "AthosAudioCoverBeatitudes"
        case "Πίστη & σχέση μὲ τὸν Θεό":
            "AthosAudioCoverSpiritualLife"
        case "Θεία χάρις & πνευματικὰ χαρίσματα":
            "AthosAudioCoverTheology"
        case "Διάκριση & πνευματικὴ σοφία":
            "AthosAudioCoverSelfKnowledge"
        case "Θεολογία & ἀνθρωπολογία":
            "AthosAudioCoverTheology"
        case "Μυστήρια & Ἐκκλησία":
            "AthosAudioCoverChurch"
        case "Δεσποτικὲς ἑορτὲς & Τριῴδιο":
            "AthosAudioCoverFeasts"
        case "Ἑρμηνεία τῆς Ἀποκαλύψεως":
            "AthosAudioCoverApocalypse"
        case "Παναγία, Ἅγιοι & βίοι":
            "AthosAudioCoverSaints"
        case "Γάμος & οἰκογένεια":
            "AthosAudioCoverMarriage"
        case "Νέοι & παιδεία":
            "AthosAudioCoverModernWorld"
        case "Σύγχρονος κόσμος & κοινωνία":
            "AthosAudioCoverModernWorld"
        case "Θλίψεις & δοκιμασίες":
            "AthosAudioCoverTrials"
        case "Θάνατος & αἰώνια ζωή":
            "AthosAudioCoverTrials"
        case "Νηστεία & πνευματικὴ ἄσκηση":
            "AthosAudioCoverSpiritualWar"
        case "Ὀρθόδοξη πίστη & ὁμολογία":
            "AthosAudioCoverChurch"
        case "Ἐρωτήσεις & πνευματικοὶ διάλογοι":
            "AthosAudioCoverThoughts"
        case "Ἁγία Γραφὴ & ἑρμηνεία":
            "AthosAudioCoverTheology"
        case "Ἀκολουθίες & λατρεία":
            "AthosAudioCoverChurch"
        case "Βυζαντινὴ μουσικὴ & ψαλμωδία":
            "AthosAudioCoverPrayer"
        case "Χιοῦμορ (σύντομα κλιπ)":
            "AthosAudioCoverHumor"
        default:
            "AthosAudioCoverSpiritualLife"
        }
    }
}

private struct AthosAudioSubjectView: View {
    let title: String
    let episodes: [Homily]
    let speakers: [AthosAudioSpeaker]
    @Environment(\.dismiss) private var dismiss
    private let player = HomilyPlayer.shared
    @State private var selectedSpeaker: AthosAudioSpeaker?
    @State private var filter: AthosEpisodeFilter = .all
    @State private var reversed = false
    private var tone: Color { AthosPodcastStyle.tone(for: AthosAudioCoverLibrary.assetName(for: title)) }
    private var visibleEpisodes: [Homily] {
        let matching = episodes.filter { filter.includes(id: $0.id) }
        return reversed ? Array(matching.reversed()) : matching
    }

    var body: some View {
        ScrollViewReader { proxy in
            ZStack(alignment: .top) {
                AthosPodcastStyle.background.ignoresSafeArea(edges: .bottom)
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        VStack(spacing: 0) {
                            Color.clear.frame(height: 58)
                            AthosPodcastCover(title: title).aspectRatio(1, contentMode: .fit)
                            VStack(alignment: .leading, spacing: 16) {
                                if let first = episodes.first(where: \.isAudioAvailable) {
                                    AthosPodcastPlayButton(tone: tone) { play(first) }
                                        .frame(maxWidth: .infinity)
                                }
                                if let name = episodes.first?.speakerNames.first {
                                    Button {
                                        selectedSpeaker = speakers.first { $0.name == name }
                                    } label: {
                                        HStack(spacing: 5) {
                                            Text(name.interfaceGreek)
                                            Image(systemName: "chevron.right").font(.caption)
                                        }.font(.system(size: 16, weight: .medium))
                                    }.buttonStyle(.plain)
                                }
                                Label("\(episodes.count) ομιλίες · \(athosAudioDuration(episodes.compactMap(\.durationSeconds).reduce(0, +)))",
                                      systemImage: "headphones")
                                    .font(.system(size: 13, weight: .medium)).foregroundStyle(.white.opacity(0.65))
                            }
                            .padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 24)
                        }
                        .foregroundStyle(.white).background { tone.ignoresSafeArea(edges: .top) }
                        HStack {
                            Text("Επεισόδια").font(.system(size: 25, weight: .bold))
                            Image(systemName: "chevron.right").font(.system(size: 17, weight: .bold))
                                .foregroundStyle(.tertiary)
                            Spacer()
                            Text("\(visibleEpisodes.count)").font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 20).padding(.top, 24).padding(.bottom, 16)
                        .id("athos-audio-episodes")
                        ForEach(visibleEpisodes) { episode in
                            let number = (episodes.firstIndex { $0.id == episode.id } ?? 0) + 1
                            AthosAudioEpisodeRow(number: number, episode: episode,
                                onSpeakerTap: { name in selectedSpeaker = speakers.first { $0.name == name } }) {
                                play(episode)
                            }
                        }
                        if visibleEpisodes.isEmpty {
                            ContentUnavailableView("Δεν υπάρχουν επεισόδια", systemImage: "line.3.horizontal.decrease",
                                description: Text("Δοκίμασε άλλο φίλτρο."))
                        }
                        Color.clear.frame(height: 90)
                    }
                }.scrollIndicators(.hidden)
                AthosSeriesGlassToolbar(filter: $filter, reversed: $reversed,
                    onBack: { dismiss() },
                    onEpisodes: {
                        filter = .all
                        withAnimation(.smooth(duration: 0.3)) { proxy.scrollTo("athos-audio-episodes", anchor: .top) }
                    },
                    onPlayFirst: { if let first = episodes.first(where: \.isAudioAvailable) { play(first) } },
                    onPlayLatest: { if let last = episodes.last(where: \.isAudioAvailable) { play(last) } })
            }
            .background { tone.ignoresSafeArea(edges: .top) }
        }
        .foregroundStyle(Color.primary)
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(item: $selectedSpeaker) { speaker in AthosAudioSpeakerProfileView(speaker: speaker) }
    }

    private func play(_ episode: Homily) {
        guard episode.isAudioAvailable else { return }
        player.present(episode, context: title,
            upNext: Array(episodes.drop(while: { $0.id != episode.id }).dropFirst()).filter(\.isAudioAvailable))
    }
}

private struct AthosAudioEpisodeRow: View {
    let number: Int
    let episode: Homily
    let onSpeakerTap: (String) -> Void
    let onPlay: () -> Void
    private var finished: Bool { MediaProgress.shared.isFinished(episode.id) }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("ΕΠΕΙΣΟΔΙΟ \(number)").font(.system(size: 10, weight: .medium))
                .foregroundStyle(AthosPodcastStyle.secondary)
            Button(action: onPlay) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(episode.title).font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.primary).multilineTextAlignment(.leading).lineLimit(3)
                    if let hook = episode.hook, !hook.isEmpty {
                        Text(hook).font(.system(size: 14)).foregroundStyle(AthosPodcastStyle.secondary)
                            .lineLimit(2).multilineTextAlignment(.leading)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
            }.buttonStyle(.plain).disabled(!episode.isAudioAvailable)
            if let name = episode.speakerNames.first {
                Button(name.interfaceGreek) { onSpeakerTap(name) }
                    .font(.system(size: 13)).foregroundStyle(AthosPodcastStyle.secondary).buttonStyle(.plain)
            }
            HStack {
                Button(action: onPlay) {
                    AthosPlaybackPill(id: episode.id, duration: Double(episode.durationSeconds ?? 0))
                }.buttonStyle(.plain).disabled(!episode.isAudioAvailable)
                Spacer()
                if episode.isAudioAvailable {
                    HomilyDownloadButton(homily: episode, compact: true,
                        tint: Gild.accentForeground, muted: AthosPodcastStyle.secondary)
                        .frame(width: 44, height: 44)
                } else {
                    Label("Μη διαθέσιμο", systemImage: "externaldrive.badge.exclamationmark")
                        .font(.caption).foregroundStyle(AthosPodcastStyle.secondary)
                }
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 14)
        .background(finished ? AthosPlaybackStatus.green.opacity(0.08) : .clear)
        .overlay(alignment: .bottom) {
            Rectangle().fill(AthosPodcastStyle.separator).frame(height: 0.5).padding(.leading, 20)
        }
    }
}

private struct AthosAudioSearchView: View {
    let episodes: [Homily]
    let speakers: [AthosAudioSpeaker]
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var player = HomilyPlayer.shared
    @State private var query = ""
    @State private var scope = "Όλα"
    private let scopes = ["Όλα", "Σειρές", "Επεισόδια", "Ομιλητές"]
    private var term: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var results: [Homily] { term.isEmpty ? episodes : episodes.filter { $0.matchesSearch(term) } }
    private var speakerResults: [AthosAudioSpeaker] {
        term.isEmpty ? speakers : speakers.filter {
            $0.name.localizedCaseInsensitiveContains(term)
            || $0.role.localizedCaseInsensitiveContains(term)
            || $0.topics.contains { $0.name.localizedCaseInsensitiveContains(term) }
        }
    }
    private var series: [String] {
        Array(Set(episodes.map(\.subject))).filter {
            term.isEmpty || $0.interfaceGreek.localizedCaseInsensitiveContains(term)
        }.sorted()
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
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 5) {
                        ForEach(scopes, id: \.self) { item in
                            Button { scope = item } label: {
                                Text(item).font(.system(size: 13, weight: .semibold))
                                    .padding(.horizontal, 13).padding(.vertical, 10)
                                    .foregroundStyle(scope == item ? .white : .primary)
                                    .background(scope == item ? Paper.gold : .clear, in: Capsule())
                            }.accessibilityAddTraits(scope == item ? .isSelected : [])
                        }
                    }.padding(.horizontal, 20).padding(.vertical, 10)
                }
                List {
                    if scope == "Όλα" || scope == "Ομιλητές" {
                        ForEach(Array(speakerResults.prefix(scope == "Όλα" ? 3 : speakerResults.count))) { speaker in
                            NavigationLink {
                                AthosAudioSpeakerProfileView(speaker: speaker)
                            } label: {
                                HStack(spacing: 12) {
                                    AthosAudioSpeakerAvatar(speaker: speaker, size: 58)
                                    searchText(speaker.name.interfaceGreek, detail: "Ομιλητής · \(speaker.mediaSummary)")
                                }.padding(.vertical, 5)
                            }
                            .listRowBackground(AthosPodcastStyle.background)
                        }
                    }
                    if scope == "Όλα" || scope == "Σειρές" {
                        ForEach(Array(series.prefix(scope == "Όλα" ? 6 : series.count)), id: \.self) { subject in
                            NavigationLink {
                                AthosAudioSubjectView(title: subject, episodes: episodes.filter { $0.subject == subject }, speakers: speakers)
                            } label: {
                                HStack(spacing: 12) {
                                    AthosPodcastCover(title: subject, showsTitle: false, fades: false)
                                        .frame(width: 58, height: 58).clipShape(RoundedRectangle(cornerRadius: 5))
                                    searchText(subject.interfaceGreek, detail: "Σειρά · Athos Audio")
                                }.padding(.vertical, 5)
                            }
                            .listRowBackground(AthosPodcastStyle.background)
                        }
                    }
                    if scope == "Όλα" || scope == "Επεισόδια" {
                        ForEach(Array(results.prefix(scope == "Όλα" ? 20 : results.count))) { episode in
                            HStack(spacing: 12) {
                                Button {
                                    guard episode.isAudioAvailable else { return }
                                    dismiss()
                                    Task { @MainActor in
                                        try? await Task.sleep(for: .milliseconds(220))
                                        player.present(episode, context: episode.subject)
                                    }
                                } label: {
                                    HStack(spacing: 12) {
                                        AthosPodcastCover(title: episode.subject, showsTitle: false, fades: false)
                                            .frame(width: 58, height: 58).clipShape(RoundedRectangle(cornerRadius: 5))
                                        VStack(alignment: .leading, spacing: 5) {
                                            searchText(episode.title, detail: episode.subject.interfaceGreek)
                                            AthosPlaybackPill(id: episode.id, duration: Double(episode.durationSeconds ?? 0))
                                        }
                                    }.contentShape(Rectangle())
                                }.buttonStyle(.plain).disabled(!episode.isAudioAvailable)
                                Spacer(minLength: 0)
                                if episode.isAudioAvailable {
                                    HomilyDownloadButton(homily: episode, compact: true,
                                        tint: Gild.accentForeground, muted: AthosPodcastStyle.secondary)
                                        .frame(width: 32, height: 44)
                                }
                            }.padding(.vertical, 5)
                            .listRowBackground(AthosPodcastStyle.background)
                        }
                    }
                    if (scope == "Όλα" && results.isEmpty && speakerResults.isEmpty && series.isEmpty)
                        || (scope == "Επεισόδια" && results.isEmpty)
                        || (scope == "Σειρές" && series.isEmpty)
                        || (scope == "Ομιλητές" && speakerResults.isEmpty) {
                        ContentUnavailableView.search(text: query).listRowBackground(Color.clear)
                    }
                }
                .listStyle(.plain).scrollContentBackground(.hidden).scrollDismissesKeyboard(.interactively)
            }
            .background(AthosPodcastStyle.background).foregroundStyle(Color.primary)
            .toolbar(.hidden, for: .navigationBar)
        }
    }
    private func searchText(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.system(size: 16, weight: .medium)).foregroundStyle(Color.primary).lineLimit(2)
            Text(detail).font(.system(size: 14)).foregroundStyle(AthosPodcastStyle.secondary).lineLimit(1)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

private func athosAudioDuration(_ seconds: Int) -> String {
    guard seconds > 0 else { return "" }
    let hours = seconds / 3600
    let minutes = (seconds % 3600) / 60
    if hours > 0, minutes > 0 { return "\(hours)ω \(minutes)λ" }
    if hours > 0 { return "\(hours)ω" }
    return "\(max(minutes, 1))λ"
}

#if DEBUG
/// Isolated visual fixtures: no playback, downloads, progress writes or account data.
struct AthosReferencePreview: View {
    let screen: String
    private let topic = "Προσευχή"
    private let samples: [Homily] = [
        Homily(id: "reference-prayer-1", title: "Η προσευχή στην καθημερινή ζωή", audioUrl: "file:///reference-preview.mp3", durationSeconds: 1920,
               hook: "Μια ομιλία για τη δύναμη της προσευχής και την ειρήνη της καρδιάς.", topic: "Προσευχή", speaker: "Athos Audio"),
        Homily(id: "reference-prayer-2", title: "Η ησυχία και η καρδιά", audioUrl: "file:///reference-preview.mp3", durationSeconds: 1380, topic: "Προσευχή"),
        Homily(id: "reference-prayer-3", title: "Πίστη, ελπίδα και αγάπη", audioUrl: "file:///reference-preview.mp3", durationSeconds: 1680, topic: "Προσευχή")
    ]
    init(screen: String) {
        self.screen = screen
        if screen == "player" || screen == "queue" {
            HomilyPlayer.shared.current = samples[0]
            HomilyPlayer.shared.contextTitle = topic
            HomilyPlayer.shared.duration = 1920
            HomilyPlayer.shared.currentTime = 720
            HomilyPlayer.shared.queue = Array(samples.dropFirst())
        }
    }
    var body: some View {
        Group {
            if screen == "progress" {
                VStack(alignment: .leading, spacing: 28) {
                    Text("Πρόοδος ακρόασης").font(.title2.bold())
                    ForEach([false, true], id: \.self) { dark in
                        VStack(alignment: .leading, spacing: 16) {
                            Text(dark ? "Σκοτεινή εμφάνιση" : "Φωτεινή εμφάνιση").font(.headline)
                            AthosPlaybackPillLabel(duration: 2280, fraction: 0, started: false, finished: false)
                            AthosPlaybackPillLabel(duration: 2280, fraction: 0.42, started: true, finished: false)
                            AthosPlaybackPillLabel(duration: 2280, fraction: 1, started: false, finished: true)
                        }.frame(maxWidth: .infinity, alignment: .leading).padding(20)
                            .background(AthosPodcastStyle.background, in: RoundedRectangle(cornerRadius: 16))
                            .environment(\.colorScheme, dark ? .dark : .light)
                    }
                }.padding(20).frame(maxHeight: .infinity).background(Color(uiColor: .systemGroupedBackground))
            } else if screen == "player" || screen == "queue" {
                HomilyPlayerView(episode: samples[0], context: topic, initiallyShowingQueue: screen == "queue")
            } else if screen == "search" {
                AthosAudioSearchView(episodes: samples, speakers: [])
            } else if screen == "tv" {
                AthosVideoReferencePreview()
            } else if screen.hasPrefix("tv-series:") {
                AthosVideoReferencePreview(collectionID: String(screen.dropFirst("tv-series:".count)))
            } else if screen == "tv-rows" {
                AthosEpisodeSpacingPreview()
            } else if screen == "tv-artwork" {
                AthosSeriesArtworkPreview()
            } else if screen == "audio-home" {
                NavigationStack { AthosAudioView(mediaMode: .constant(.audio)) }
            } else {
                NavigationStack {
                    AthosAudioSubjectView(title: topic, episodes: samples, speakers: [])
                }
            }
        }
        .allowsHitTesting(false)
    }
}
#endif
