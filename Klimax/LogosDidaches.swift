//
//  LogosDidaches.swift
//  Klimax, ἑνότητα «Λόγος» / Διδαχές (ὀργάνωση κατὰ θέμα)
//
//  ΣΗΜΑΝΤΙΚΟ (μία φορά): Target → Signing & Capabilities → «+ Capability» →
//  Background Modes → τσέκαρε «Audio, AirPlay, and Picture in Picture».
//

import SwiftUI
import AVFoundation
import MediaPlayer

// MARK: - Ρυθμίσεις Sanity

private enum Sanity {
    static let projectId = "uqaka7yh"
    static let dataset = "production"
    static let apiVersion = "v2021-06-07"
    static let token: String? = "skK706jsv9XOGQcJz11BkV67duKyolNJwDRiGMnfGYRNifZsi7NgX12ThjJgUnCKwXRPYHtWau59pJMPiPwyfpI5Euv7c2jN1kfQiwbstCfzSoX9xSlOWMCpAeI2mLfPTNHUEvQtwNJ5m6TNFVlGFxUyHm0wcq0IfpGvsDkWkc7yRNeJrlGH"   // Viewer token ἂν τὸ dataset εἶναι ἰδιωτικό

    static let query = """
    *[_type=="homily"]{
      _id, title, episodeNumber, audioUrl, durationSeconds, hook, isShort,
      topic, youtubeVideoId, mediaType, "seriesTitle": series->title
    }
    """
    static func queryURL() -> URL {
        var c = URLComponents()
        c.scheme = "https"; c.host = "\(projectId).apicdn.sanity.io"
        c.path = "/\(apiVersion)/data/query/\(dataset)"
        c.queryItems = [URLQueryItem(name: "query", value: query)]
        return c.url!
    }
}

private let THEME_ORDER: [String] = [
        "Πνευματικὴ ζωὴ & ἀγώνας",
        "Πνευματικὸς πόλεμος",
        "Μετάνοια, πένθος & ταπείνωση",
        "Προσευχή",
        "Πάθη & λογισμοί",
        "Ἀρετὲς & καρποὶ τοῦ Πνεύματος",
        "Αὐτογνωσία",
        "Οἱ Δέκα Ἐντολές",
    "Οἱ Μακαρισμοί",
    "Πίστη & σχέση μὲ τὸν Θεό",
    "Θεία χάρις & πνευματικὰ χαρίσματα",
    "Διάκριση & πνευματικὴ σοφία",
    "Θεολογία & ἀνθρωπολογία",
        "Μυστήρια & Ἐκκλησία",
        "Δεσποτικὲς ἑορτὲς & Τριῴδιο",
        "Ἑρμηνεία τῆς Ἀποκαλύψεως",
        "Παναγία, Ἅγιοι & βίοι",
    "Γάμος & οἰκογένεια",
    "Νέοι & παιδεία",
    "Σύγχρονος κόσμος & κοινωνία",
    "Θλίψεις & δοκιμασίες",
    "Θάνατος & αἰώνια ζωή",
    "Νηστεία & πνευματικὴ ἄσκηση",
    "Ὀρθόδοξη πίστη & ὁμολογία",
    "Ἐρωτήσεις & πνευματικοὶ διάλογοι",
    "Ἁγία Γραφὴ & ἑρμηνεία",
    "Ἀκολουθίες & λατρεία",
    "Βυζαντινὴ μουσικὴ & ψαλμωδία",
    "Χιοῦμορ (σύντομα κλιπ)"
]
private let THEME_ICON: [String: String] = [
        "Πνευματικὴ ζωὴ & ἀγώνας": "flame",
        "Πνευματικὸς πόλεμος": "shield.lefthalf.filled",
        "Μετάνοια, πένθος & ταπείνωση": "drop.fill",
        "Προσευχή": "hands.and.sparkles",
        "Πάθη & λογισμοί": "wind",
        "Ἀρετὲς & καρποὶ τοῦ Πνεύματος": "leaf",
        "Αὐτογνωσία": "eye",
        "Οἱ Δέκα Ἐντολές": "list.number",
    "Οἱ Μακαρισμοί": "mountain.2",
    "Πίστη & σχέση μὲ τὸν Θεό": "sparkles",
    "Θεία χάρις & πνευματικὰ χαρίσματα": "sun.max",
    "Διάκριση & πνευματικὴ σοφία": "lamp.desk",
        "Θεολογία & ἀνθρωπολογία": "book.closed",
        "Μυστήρια & Ἐκκλησία": "building.columns",
        "Δεσποτικὲς ἑορτὲς & Τριῴδιο": "calendar",
        "Ἑρμηνεία τῆς Ἀποκαλύψεως": "scroll",
        "Παναγία, Ἅγιοι & βίοι": "person.2",
    "Γάμος & οἰκογένεια": "heart",
    "Νέοι & παιδεία": "person.3",
        "Σύγχρονος κόσμος & κοινωνία": "globe",
    "Θλίψεις & δοκιμασίες": "cloud.rain",
    "Θάνατος & αἰώνια ζωή": "infinity",
    "Νηστεία & πνευματικὴ ἄσκηση": "figure.mind.and.body",
    "Ὀρθόδοξη πίστη & ὁμολογία": "cross.case",
    "Ἐρωτήσεις & πνευματικοὶ διάλογοι": "questionmark.bubble",
    "Ἁγία Γραφὴ & ἑρμηνεία": "text.book.closed",
    "Ἀκολουθίες & λατρεία": "building.columns",
    "Βυζαντινὴ μουσικὴ & ψαλμωδία": "music.note.list",
    "Χιοῦμορ (σύντομα κλιπ)": "face.smiling"
]
private func themeIcon(_ name: String) -> String { THEME_ICON[name] ?? "text.book.closed" }
private func homilyCount(_ n: Int) -> String { n == 1 ? "1 ομιλία" : "\(n) ομιλίες" }
private func didachesSearchKey(_ text: String) -> String {
    let folded = text
        .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "el"))
        .lowercased()
        .replacingOccurrences(of: "ς", with: "σ")
    var out = ""
    var lastWasSpace = false
    for ch in folded {
        if ch.isLetter || ch.isNumber {
            out.append(ch)
            lastWasSpace = false
        } else if !lastWasSpace {
            out.append(" ")
            lastWasSpace = true
        }
    }
    return out.trimmingCharacters(in: .whitespacesAndNewlines)
}

// MARK: - Μοντέλα

struct Homily: Identifiable, Codable, Equatable {
    let id: String
    let title: String
    let episodeNumber: Int?
    let audioUrl: String?
    let durationSeconds: Int?
    let hook: String?
    let isShort: Bool?
    let topic: String?
    let youtubeVideoId: String?
    let mediaType: String?
    let seriesTitle: String?
    let audioPath: String?
    let catalogCode: String?
    let speaker: String?
    let speakers: [String]?
    let catalogDescription: String?
    let searchTerms: String?

    enum CodingKeys: String, CodingKey {
        case id = "_id", title, episodeNumber, audioUrl, durationSeconds, hook, isShort
        case topic, youtubeVideoId, mediaType, seriesTitle, audioPath, catalogCode
        case speaker, speakers, catalogDescription, searchTerms
    }

    init(
        id: String,
        title: String,
        episodeNumber: Int? = nil,
        audioUrl: String? = nil,
        durationSeconds: Int? = nil,
        hook: String? = nil,
        isShort: Bool? = nil,
        topic: String? = nil,
        youtubeVideoId: String? = nil,
        mediaType: String? = nil,
        seriesTitle: String? = nil,
        audioPath: String? = nil,
        catalogCode: String? = nil,
        speaker: String? = nil,
        speakers: [String]? = nil,
        catalogDescription: String? = nil,
        searchTerms: String? = nil
    ) {
        self.id = id
        self.title = title
        self.episodeNumber = episodeNumber
        self.audioUrl = audioUrl
        self.durationSeconds = durationSeconds
        self.hook = hook
        self.isShort = isShort
        self.topic = topic
        self.youtubeVideoId = youtubeVideoId
        self.mediaType = mediaType
        self.seriesTitle = seriesTitle
        self.audioPath = audioPath
        self.catalogCode = catalogCode
        self.speaker = speaker
        self.speakers = speakers
        self.catalogDescription = catalogDescription
        self.searchTerms = searchTerms
    }

    var audioURL: URL? { audioUrl.flatMap(URL.init(string:)) }
    var subject: String { topic ?? seriesTitle ?? "Άλλα" }
    var isVideo: Bool { mediaType == "video" || youtubeVideoId != nil }
    var isAudioAvailable: Bool { audioURL != nil }
    var speakerNames: [String] {
        if let speakers, !speakers.isEmpty { return speakers }
        if let speaker, !speaker.isEmpty { return [speaker] }
        return []
    }
    var youtubeURL: URL? { youtubeVideoId.flatMap { URL(string: "https://www.youtube.com/watch?v=\($0)") } }

    func matchesSearch(_ query: String) -> Bool {
        let tokens = didachesSearchKey(query).split(separator: " ").map(String.init)
        guard !tokens.isEmpty else { return true }
        let haystack = didachesSearchKey([
            title, subject, speakerNames.joined(separator: " "), catalogCode, catalogDescription, searchTerms
        ].compactMap { $0 }.joined(separator: " "))
        return tokens.allSatisfy { haystack.contains($0) }
    }

    func resolvingAudioPath(against baseURL: URL?) -> Homily {
        guard audioUrl == nil, let audioPath, let baseURL else { return self }
        return Homily(
            id: id,
            title: title,
            episodeNumber: episodeNumber,
            audioUrl: baseURL.appendingPathComponent(audioPath).absoluteString,
            durationSeconds: durationSeconds,
            hook: hook,
            isShort: isShort,
            topic: topic,
            youtubeVideoId: youtubeVideoId,
            mediaType: mediaType,
            seriesTitle: seriesTitle,
            audioPath: audioPath,
            catalogCode: catalogCode,
            speaker: speaker,
            speakers: speakers,
            catalogDescription: catalogDescription,
            searchTerms: searchTerms
        )
    }

    static func == (a: Homily, b: Homily) -> Bool { a.id == b.id }
}

struct Subject: Identifiable {
    let id: String
    let episodes: [Homily]
    var name: String { id }
}

func timeLabel(_ seconds: Double) -> String {
    guard seconds.isFinite, seconds >= 0 else { return "0:00" }
    let s = Int(seconds), h = s / 3600, m = (s % 3600) / 60, sec = s % 60
    return h > 0 ? String(format: "%d:%02d:%02d", h, m, sec) : String(format: "%d:%02d", m, sec)
}

private func durationSummary(_ seconds: Int) -> String {
    guard seconds > 0 else { return "0λ" }
    let h = seconds / 3600
    let m = (seconds % 3600) / 60
    if h > 0, m > 0 { return "\(h)ω \(m)λ" }
    if h > 0 { return "\(h)ω" }
    return "\(max(1, m))λ"
}

private func totalDurationSummary(_ episodes: [Homily]) -> String {
    durationSummary(episodes.compactMap(\.durationSeconds).reduce(0, +))
}

private struct SanityResult: Decodable { let result: [Homily] }

private struct BundledHomilyArchive: Decodable {
    let audioBaseURL: String?
    let items: [Homily]
}

// MARK: - Πρόοδος

enum PlaybackProgress {
    private static let key = "klimax.homily.progress"
    static func seconds(for id: String) -> Double {
        (UserDefaults.standard.dictionary(forKey: key)?[id] as? Double) ?? 0
    }
    static func set(_ seconds: Double, for id: String) {
        var d = UserDefaults.standard.dictionary(forKey: key) ?? [:]
        d[id] = seconds; UserDefaults.standard.set(d, forKey: key)
    }
    static func fraction(for id: String, duration: Int?) -> Double {
        guard let dur = duration, dur > 0 else { return 0 }
        return min(1, seconds(for: id) / Double(dur))
    }
}

// MARK: - Store

@MainActor
final class HomilyStore: ObservableObject {
    static let shared = HomilyStore()

    @Published var subjects: [Subject] = []
    @Published var isLoading = false
    @Published var errorText: String?
    private var hasLoaded = false

    func load() async {
        guard !hasLoaded, !isLoading else { return }
        isLoading = true; errorText = nil
        let bundled = Self.loadBundledArchive()
        if subjects.isEmpty, !bundled.isEmpty {
            subjects = Self.group(bundled)
        }
        do {
            var req = URLRequest(url: Sanity.queryURL())
            if let t = Sanity.token { req.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization") }
            let (data, resp) = try await URLSession.shared.data(for: req)
            if let http = resp as? HTTPURLResponse, http.statusCode >= 300 {
                throw NSError(domain: "Sanity", code: http.statusCode,
                              userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode)"])
            }
            let remote = try JSONDecoder().decode(SanityResult.self, from: data).result
            var merged = Dictionary(uniqueKeysWithValues: bundled.map { ($0.id, $0) })
            remote.forEach { merged[$0.id] = $0 }
            self.subjects = Self.group(Array(merged.values))
        } catch {
            if bundled.isEmpty { self.errorText = error.localizedDescription }
        }
        hasLoaded = true
        isLoading = false
    }

    private static func loadBundledArchive(bundle: Bundle = .main) -> [Homily] {
        guard let url = bundle.url(forResource: "homily-archive", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let archive = try? JSONDecoder().decode(BundledHomilyArchive.self, from: data) else {
            return []
        }
        let configured = (bundle.object(forInfoDictionaryKey: "HomilyArchiveBaseURL") as? String)
            .flatMap { $0.isEmpty ? nil : $0 }
        let baseURL = (configured ?? archive.audioBaseURL).flatMap(URL.init(string:))
        return archive.items.map { $0.resolvingAudioPath(against: baseURL) }
    }
    private static func group(_ all: [Homily]) -> [Subject] {
        var byName: [String: [Homily]] = [:]
        for h in all { byName[h.subject, default: []].append(h) }
        func rank(_ n: String) -> Int { THEME_ORDER.firstIndex(of: n) ?? THEME_ORDER.count }
        return byName.map { (name, eps) in
            Subject(id: name, episodes: eps.sorted {
                ($0.episodeNumber ?? 9999, $0.title) < ($1.episodeNumber ?? 9999, $1.title) })
        }.sorted { (rank($0.name), $0.name) < (rank($1.name), $1.name) }
    }
}

// MARK: - Player engine

@MainActor
final class HomilyPlayer: ObservableObject {
    static let shared = HomilyPlayer()
    @Published var current: Homily?
    @Published var contextTitle = ""
    @Published var isPlaying = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var rate: Float = 1.0
    @Published var queue: [Homily] = []
    @Published var history: [Homily] = []
    @Published var fullScreenHomily: Homily?
    @Published var chapters: [HomilyChapter] = []
    @Published var sleepMode: HomilySleep = .off
    @Published var sleepRemaining: TimeInterval?
    private let downloads = HomilyDownloads.shared
    private var sleepTimer: Timer?
    private var sleepDeadline: Date?
    private var pauseAtEnd = false
    private var player: AVPlayer?
    private var timeObserver: Any?
    private var commandsReady = false
    private var lastObservedTime: Double = 0     // for accumulating true listened seconds
    private var completionRecordedID: String?    // guards a single completion per item
    private init() {}

    /// Ξεκινᾶ τὴν ὁμιλία τώρα, ἀνοίγει τὴν πλήρη ὀθόνη, καὶ βάζει τὴ συνέχεια στὴν οὐρά.
    func present(_ homily: Homily, context: String, upNext: [Homily] = []) {
        contextTitle = context
        fullScreenHomily = homily
        guard !homily.isVideo else { return }
        queue = upNext.filter { !$0.isVideo && $0.id != homily.id }
        history = []
        open(homily, context: context)
    }

    func open(_ homily: Homily, context: String) {
        if current?.id == homily.id, player != nil { play(); return }
        teardownObserver()
        current = homily; contextTitle = context; chapters = []
        LastListened.save(homily, context: context)
        duration = Double(homily.durationSeconds ?? 0)
        currentTime = PlaybackProgress.seconds(for: homily.id)
        lastObservedTime = currentTime
        completionRecordedID = nil
        guard let remote = homily.audioURL else { return }
        let url = downloads.localURL(id: homily.id, remote: remote) ?? remote
        configureSession(); setupRemoteCommands()
        let item = AVPlayerItem(url: url); let p = AVPlayer(playerItem: item); player = p
        if currentTime > 1 { p.seek(to: CMTime(seconds: currentTime, preferredTimescale: 600)) }
        addObserver()
        NotificationCenter.default.addObserver(self, selector: #selector(didFinish),
            name: .AVPlayerItemDidPlayToEndTime, object: item)
        loadChapters(from: item, for: homily.id)
        play()
        #if DEBUG
        print("KlimaxAudio play: \(homily.title) source=\(url.isFileURL ? "local" : "remote") queue=\(queue.count)")
        #endif
    }

    // Οὐρά «Τί ἀκολουθεῖ»
    func playNext(_ h: Homily) {
        guard !h.isVideo else { return }
        if current == nil { present(h, context: contextTitle); return }
        queue.removeAll { $0.id == h.id }; queue.insert(h, at: 0)
    }
    func addToQueue(_ h: Homily) {
        guard !h.isVideo else { return }
        if current == nil { present(h, context: contextTitle); return }
        guard !queue.contains(where: { $0.id == h.id }) else { return }
        queue.append(h)
    }
    func removeFromQueue(_ h: Homily) { queue.removeAll { $0.id == h.id } }
    func moveInQueue(from s: IndexSet, to d: Int) { queue.move(fromOffsets: s, toOffset: d) }
    func clearQueue() { queue.removeAll() }

    var hasNext: Bool { !queue.isEmpty }

    /// Ἐπόμενη ὁμιλία στὴν οὐρά.
    func nextTrack() {
        guard !queue.isEmpty else { return }
        if let cur = current { history.append(cur) }
        let next = queue.removeFirst()
        open(next, context: contextTitle)
    }

    /// Μία φορά: πίσω στὸ 0. Δεύτερη φορά (ἤδη στὴν ἀρχή): προηγούμενη ὁμιλία.
    func previousTrack() {
        if currentTime > 3 { seek(to: 0); return }
        guard let prev = history.popLast() else { seek(to: 0); return }
        if let cur = current { queue.insert(cur, at: 0) }
        open(prev, context: contextTitle)
    }

    /// Κλείνει τελείως τὴ μικρὴ μπάρα: σταματᾶ, ἀδειάζει, καὶ κρύβει τὸ accessory.
    func stop() {
        pause()
        teardownObserver()
        player = nil
        setSleep(.off)
        current = nil
        queue = []
        history = []
        chapters = []
        fullScreenHomily = nil
        isPlaying = false
        currentTime = 0
        duration = 0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    func skipForward() { skip(30) }
    func skipBackward() { skip(-15) }
    func jumpTo(_ chapter: HomilyChapter) { seek(to: chapter.startTime) }
    func play() { guard let p = player else { return }; p.playImmediately(atRate: rate); isPlaying = true; updateNowPlaying() }
    func pause() { player?.pause(); isPlaying = false; saveProgress(); MediaProgress.shared.flush(); updateNowPlaying() }
    func toggle() { isPlaying ? pause() : play() }
    func seek(to seconds: Double) {
        let t = max(0, min(seconds, duration > 0 ? duration : seconds))
        currentTime = t; lastObservedTime = t; player?.seek(to: CMTime(seconds: t, preferredTimescale: 600)); saveProgress(); updateNowPlaying()
    }
    func skip(_ d: Double) { seek(to: currentTime + d) }
    func setRate(_ r: Float) { rate = r; if isPlaying { player?.rate = r }; updateNowPlaying() }
    private func addObserver() {
        timeObserver = player?.addPeriodicTimeObserver(forInterval: CMTime(seconds: 1, preferredTimescale: 2), queue: .main) { [weak self] t in
            guard let self else { return }
            let now = t.seconds
            let delta = now - self.lastObservedTime
            self.lastObservedTime = now
            if self.isPlaying, delta > 0, delta <= 2 {
                StreakStore.shared.addListeningSeconds(delta)
            }
            self.currentTime = now
            if self.duration <= 0, let d = self.player?.currentItem?.duration.seconds, d.isFinite { self.duration = d }
            if let id = self.current?.id {
                MediaProgress.shared.update(id: id, seconds: now, duration: self.duration)
            }
            if self.duration > 0, now >= self.duration * 0.9,
               let id = self.current?.id, self.completionRecordedID != id {
                self.completionRecordedID = id
                StreakStore.shared.record(.didaches, itemID: id)
            }
            self.saveProgress(); self.updateNowPlaying()
        }
    }
    private func teardownObserver() {
        if let o = timeObserver { player?.removeTimeObserver(o); timeObserver = nil }
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
    }
    private func saveProgress() { if let id = current?.id { PlaybackProgress.set(currentTime, for: id) } }
    @objc private func didFinish() {
        if let id = current?.id {
            MediaProgress.shared.markFinished(id)
            if completionRecordedID != id {
                completionRecordedID = id
                StreakStore.shared.record(.didaches, itemID: id)
            }
        }
        if let id = current?.id { PlaybackProgress.set(0, for: id) }
        if pauseAtEnd { pauseAtEnd = false; sleepMode = .off; isPlaying = false; updateNowPlaying(); return }
        if !queue.isEmpty {
            let next = queue.removeFirst()
            if let cur = current { history.append(cur) }
            #if DEBUG
            print("KlimaxAudio auto advance -> \(next.title)")
            #endif
            open(next, context: contextTitle)
        } else {
            isPlaying = false; updateNowPlaying()
            #if DEBUG
            print("KlimaxAudio queue exhausted, stopping.")
            #endif
        }
    }
    private func configureSession() {
        let s = AVAudioSession.sharedInstance()
        try? s.setCategory(.playback, mode: .spokenAudio); try? s.setActive(true)
    }
    private func setupRemoteCommands() {
        guard !commandsReady else { return }; commandsReady = true
        let c = MPRemoteCommandCenter.shared()
        c.playCommand.addTarget { [weak self] _ in self?.play(); return .success }
        c.pauseCommand.addTarget { [weak self] _ in self?.pause(); return .success }
        c.togglePlayPauseCommand.addTarget { [weak self] _ in self?.toggle(); return .success }
        c.nextTrackCommand.addTarget { [weak self] _ in self?.nextTrack(); return .success }
        c.previousTrackCommand.addTarget { [weak self] _ in self?.previousTrack(); return .success }
        c.skipForwardCommand.preferredIntervals = [30]
        c.skipForwardCommand.addTarget { [weak self] _ in self?.skip(30); return .success }
        c.skipBackwardCommand.preferredIntervals = [15]
        c.skipBackwardCommand.addTarget { [weak self] _ in self?.skip(-15); return .success }
        c.changePlaybackPositionCommand.addTarget { [weak self] e in
            if let e = e as? MPChangePlaybackPositionCommandEvent { self?.seek(to: e.positionTime) }
            return .success
        }
    }
    // Χρονοδιακόπτης ὕπνου
    func setSleep(_ mode: HomilySleep) {
        sleepTimer?.invalidate(); sleepTimer = nil; sleepDeadline = nil; pauseAtEnd = false
        sleepMode = mode
        switch mode {
        case .off: sleepRemaining = nil
        case .endOfTrack: pauseAtEnd = true; sleepRemaining = nil
        case .minutes(let m):
            let dl = Date().addingTimeInterval(TimeInterval(m * 60))
            sleepDeadline = dl; sleepRemaining = dl.timeIntervalSinceNow
            sleepTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.tickSleep() }
            }
        }
    }
    private func tickSleep() {
        guard let dl = sleepDeadline else { return }
        sleepRemaining = max(0, dl.timeIntervalSinceNow)
        if dl.timeIntervalSinceNow <= 0 { fadeOutAndPause(); setSleep(.off) }
    }
    private func fadeOutAndPause() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            let steps = 8
            for i in 0..<steps {
                self.player?.volume = Float(steps - i) / Float(steps)
                try? await Task.sleep(nanoseconds: 120_000_000)
            }
            self.pause()
            self.player?.volume = 1
        }
    }

    // Κεφάλαια ἀπὸ ἐνσωματωμένα metadata (ἂν ὑπάρχουν στὸ ἀρχεῖο)
    private func loadChapters(from item: AVPlayerItem, for id: String) {
        let asset = item.asset
        Task { [weak self] in
            let langs = Locale.preferredLanguages
            guard let groups = try? await asset.loadChapterMetadataGroups(bestMatchingPreferredLanguages: langs),
                  !groups.isEmpty else { return }
            var result: [HomilyChapter] = []
            for g in groups {
                let start = g.timeRange.start.seconds
                let titleItem = g.items.first { $0.commonKey == .commonKeyTitle }
                let title = (try? await titleItem?.load(.stringValue)) ?? nil
                result.append(HomilyChapter(title: title ?? "Κεφάλαιο", startTime: start))
            }
            await MainActor.run {
                guard let self, self.current?.id == id else { return }
                self.chapters = result
            }
        }
    }

    private func updateNowPlaying() {
        guard let h = current else { return }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: h.title,
            MPMediaItemPropertyArtist: contextTitle,
            MPMediaItemPropertyAlbumTitle: h.subject,
            MPNowPlayingInfoPropertyExternalContentIdentifier: h.id,
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? rate : 0
        ]
        // Keep artwork on every update, including seeking, pausing and queue
        // changes. Replacing the dictionary without this key produces a grey box.
        info[MPMediaItemPropertyArtwork] = AthosNowPlayingArtwork.audio(subject: h.subject)
        if duration > 0 { info[MPMediaItemPropertyPlaybackDuration] = duration }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}

// MARK: - Παλέτα (Paper / Gild)

private enum Pal {
    static let paper  = Paper.bg
    static let card   = Paper.card
    static let ink    = Paper.ink
    static let gild   = Paper.gold
    static let gildSoft = Gild.goldBright
    static let faint  = Paper.inkMute
    static let hair   = Paper.hairline
    static let blueGlass = Color.adaptive(
        Color(red: 0.80, green: 0.90, blue: 1.0),
        Color(red: 0.06, green: 0.16, blue: 0.28)
    )
    static let deepGlass = Color.adaptive(
        Color.white,
        Color(red: 0.05, green: 0.08, blue: 0.13)
    )
}

private struct DidachesSurface: ViewModifier {
    var cornerRadius: CGFloat = 18
    var highlighted = false

    @ViewBuilder
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if highlighted {
            content
                .background(.ultraThinMaterial, in: shape)
                .background(
                    shape.fill(
                        LinearGradient(
                            colors: [
                                Pal.blueGlass.opacity(0.25),
                                Pal.deepGlass.opacity(0.70),
                                Pal.gild.opacity(0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                )
                .overlay(
                    shape.stroke(
                        LinearGradient(
                            colors: [
                                Color.adaptive(.white.opacity(0.78), Pal.blueGlass.opacity(0.22)),
                                Pal.hair.opacity(0.82),
                                Color.adaptive(Pal.gild.opacity(0.18), Pal.gild.opacity(0.10))
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.05
                    )
                )
                .shadow(color: Color.adaptive(.black.opacity(0.07), .clear), radius: 16, x: 0, y: 8)
        } else {
            content
                .background(
                    shape.fill(
                        LinearGradient(
                            colors: [
                                Pal.card,
                                Pal.blueGlass.opacity(0.10),
                                Pal.card
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                )
                .overlay(shape.stroke(Pal.hair.opacity(0.62), lineWidth: 0.75))
                .shadow(color: Color.adaptive(.black.opacity(0.018), .clear), radius: 3, x: 0, y: 1)
        }
    }
}

private extension View {
    func didachesSurface(cornerRadius: CGFloat = 18, highlighted: Bool = false) -> some View {
        modifier(DidachesSurface(cornerRadius: cornerRadius, highlighted: highlighted))
    }
}

// Διακοσμητικὸς χρυσὸς κανόνας (manuscript)
private struct GoldRule: View {
    var body: some View {
        HStack(spacing: 8) {
            Rectangle().fill(Pal.gild.opacity(0.35)).frame(height: 1)
            Image(systemName: "seal").font(.system(size: 9)).foregroundStyle(Pal.gild.opacity(0.8))
            Rectangle().fill(Pal.gild.opacity(0.35)).frame(height: 1)
        }
    }
}

// MARK: - Βιβλιοθήκη (θέματα)

struct DidachesLibraryView: View {
    @ObservedObject private var store = HomilyStore.shared
    @State private var query = ""

    private var visibleSubjects: [Subject] {
        let needle = didachesSearchKey(query)
        guard !needle.isEmpty else { return store.subjects }
        return store.subjects.filter { subject in
            didachesSearchKey(subject.name).contains(needle) ||
            subject.episodes.contains { $0.matchesSearch(query) }
        }
    }

    var body: some View {
        ZStack {
            Pal.paper.ignoresSafeArea()
            content
        }
        .navigationTitle("Διδαχές")
        .task { if store.subjects.isEmpty { await store.load() } }
        .tint(Pal.gild)
    }

    @ViewBuilder private var content: some View {
        if store.isLoading && store.subjects.isEmpty {
            ProgressView("Φόρτωση…").tint(Pal.gild)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let err = store.errorText, store.subjects.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "wifi.exclamationmark").font(.largeTitle).foregroundStyle(Pal.gild)
                Text("Δεν φορτώθηκαν οι ομιλίες").font(.headline).foregroundStyle(Pal.ink)
                Text(err).font(.footnote).foregroundStyle(Pal.faint).multilineTextAlignment(.center)
                Button("Δοκίμασε ξανά") { Task { await store.load() } }.buttonStyle(.borderedProminent).tint(Pal.gild)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    didachesHeader
                        .logosBlockRise(0)
                    quickCards
                        .logosBlockRise(1)
                    searchField
                        .logosBlockRise(2)
                    VStack(alignment: .leading, spacing: 10) {
                        Text(query.isEmpty ? "ΘΕΜΑΤΑ" : "ΑΠΟΤΕΛΕΣΜΑΤΑ")
                            .font(.system(size: 11, weight: .semibold))
                            .tracking(3)
                            .foregroundStyle(Pal.gild)
                            .padding(.horizontal, 4)
                            .logosBlockRise(3)

                        if visibleSubjects.isEmpty {
                            emptySearchState
                                .logosBlockRise(4)
                        } else {
                            LazyVStack(spacing: 10) {
                                ForEach(visibleSubjects) { subject in
                                    NavigationLink { SubjectDetailView(subject: subject) } label: {
                                        SubjectCard(subject: subject)
                                    }
                                    .buttonStyle(CalmCardStyle())
                                }
                            }
                            .logosBlockRise(4)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 78)
                .padding(.bottom, 28)
            }
        }
    }

    private var didachesHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ΔΙΔΑΧΕΣ")
                .font(.system(size: 12, weight: .semibold))
                .tracking(4)
                .foregroundStyle(Pal.gild)
            Text("Λόγοι για την πορεία")
                .font(.system(size: 34, weight: .regular, design: .serif))
                .foregroundStyle(Pal.ink)
            Text("Θέματα, ομιλίες και σύντομα αποσπάσματα για ακρόαση.")
                .font(.system(size: 15, design: .serif))
                .foregroundStyle(Pal.faint)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 14)
        .padding(.horizontal, 4)
    }

    private var quickCards: some View {
        VStack(spacing: 10) {
            ContinueListeningCard()
            DailyClipCard()
        }
    }

    private var searchField: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Pal.faint)
            TextField("Αναζήτηση σε θέματα ή ομιλίες…", text: $query)
                .font(.system(size: 15))
                .foregroundStyle(Pal.ink)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Pal.faint.opacity(0.65))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(Pal.card, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).stroke(Pal.hair, lineWidth: 1))
    }

    private var emptySearchState: some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 24))
                .foregroundStyle(Pal.gild.opacity(0.75))
            Text("Δεν βρέθηκε διδαχή")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Pal.ink)
            Text("Δοκίμασε άλλη λέξη ή θέμα.")
                .font(.footnote)
                .foregroundStyle(Pal.faint)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .didachesSurface()
    }
}

private struct SubjectCard: View {
    let subject: Subject
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().fill(Pal.gild.opacity(0.13))
                Circle().stroke(Pal.gild.opacity(0.30), lineWidth: 1)
                Image(systemName: themeIcon(subject.name))
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(Pal.gild)
            }
            .frame(width: 52, height: 52)
            VStack(alignment: .leading, spacing: 3) {
                Text(subject.name.interfaceGreek)
                    .font(.system(size: 18, weight: .semibold, design: .serif))
                    .foregroundStyle(Pal.ink)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    Text(homilyCount(subject.episodes.count))
                    if let first = subject.episodes.first?.title {
                        Text("•")
                        Text(first)
                            .lineLimit(1)
                    }
                }
                .font(.system(size: 12))
                .foregroundStyle(Pal.faint)
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Pal.faint.opacity(0.78))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .didachesSurface(cornerRadius: 18)
    }
}

// MARK: - Ὁμιλίες θέματος

struct SubjectDetailView: View {
    let subject: Subject
    private let player = HomilyPlayer.shared

    private var totalDuration: String { totalDurationSummary(subject.episodes) }

    private func after(_ ep: Homily) -> [Homily] {
        Array(subject.episodes.drop(while: { $0.id != ep.id }).dropFirst())
    }

    private var featuredEpisode: Homily? {
        subject.episodes.first {
            let progress = PlaybackProgress.fraction(for: $0.id, duration: $0.durationSeconds)
            return progress > 0.01 && progress < 0.99 && !$0.isVideo && $0.isAudioAvailable
        } ?? subject.episodes.first(where: { $0.isVideo || $0.isAudioAvailable })
    }

    var body: some View {
        ZStack {
            detailBackdrop
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    if let featuredEpisode {
                        ListenNextCard(
                            episode: featuredEpisode,
                            progress: PlaybackProgress.fraction(for: featuredEpisode.id, duration: featuredEpisode.durationSeconds)
                        ) {
                            player.present(featuredEpisode, context: subject.name, upNext: after(featuredEpisode))
                        }
                    }
                    episodeSectionHeader
                    LazyVStack(spacing: 10) {
                        ForEach(Array(subject.episodes.enumerated()), id: \.element.id) { idx, ep in
                            EpisodeRow(index: idx + 1, episode: ep,
                                       progress: PlaybackProgress.fraction(for: ep.id, duration: ep.durationSeconds),
                                       onPlay: { player.present(ep, context: subject.name, upNext: after(ep)) },
                                       onQueue: { player.addToQueue(ep) })
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 34)
            }
        }
        .navigationTitle("Διδαχές")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var detailBackdrop: some View {
        ZStack {
            Pal.paper.ignoresSafeArea()
            LinearGradient(
                colors: [
                    Pal.blueGlass.opacity(0.18),
                    Color.clear,
                    Pal.gild.opacity(0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: themeIcon(subject.name))
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(Pal.gild)
                    .frame(width: 58, height: 58)
                    .background(
                        Circle()
                            .fill(Pal.gild.opacity(0.12))
                            .overlay(Circle().stroke(Pal.gild.opacity(0.22), lineWidth: 1))
                    )

                VStack(alignment: .leading, spacing: 7) {
                    Text("ΘΕΜΑ")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(3.4)
                        .foregroundStyle(Pal.gild)
                    Text(subject.name.interfaceGreek)
                        .font(.system(size: 31, weight: .semibold, design: .serif))
                        .foregroundStyle(Pal.ink)
                        .lineSpacing(1)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 10) {
                infoPill("\(subject.episodes.count)", "ομιλίες", icon: "rectangle.stack.fill")
                infoPill(totalDuration, "σύνολο", icon: "clock.fill")
            }

            if let first = subject.episodes.first {
                Text("Ξεκίνα από το «\(first.title)» ή συνέχισε εκεί που έμεινες.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Pal.faint)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(18)
        .didachesSurface(cornerRadius: 26, highlighted: true)
    }

    private var episodeSectionHeader: some View {
        HStack(alignment: .lastTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("ΟΜΙΛΙΕΣ")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(3.2)
                    .foregroundStyle(Pal.gild)
                Text("Διάλεξε μάθημα")
                    .font(.system(size: 20, weight: .semibold, design: .serif))
                    .foregroundStyle(Pal.ink)
            }
            Spacer()
            Text(totalDuration)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Pal.faint)
        }
        .padding(.horizontal, 4)
        .padding(.top, 2)
    }

    private func infoPill(_ value: String, _ label: String, icon: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Pal.gild)
            Text(value)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Pal.ink)
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Pal.faint)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .background(Pal.ink.opacity(0.045), in: Capsule())
        .overlay(Capsule().stroke(Pal.hair.opacity(0.75), lineWidth: 1))
    }
}

private struct ListenNextCard: View {
    let episode: Homily
    let progress: Double
    let action: () -> Void

    private var label: String {
        progress > 0.01 && progress < 0.99 ? "ΣΥΝΕΧΙΣΕ" : "ΠΡΩΤΗ ΟΜΙΛΙΑ"
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(Pal.gild)
                    Image(systemName: episode.isVideo ? "play.rectangle.fill" : "play.fill")
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(.white)
                        .offset(x: episode.isVideo ? 0 : 1)
                }
                .frame(width: 50, height: 50)
                .shadow(color: Pal.gild.opacity(0.22), radius: 10, y: 4)

                VStack(alignment: .leading, spacing: 5) {
                    Text(label)
                        .font(.system(size: 10, weight: .bold))
                        .tracking(2.4)
                        .foregroundStyle(Pal.gild)
                    Text(episode.title)
                        .font(.system(size: 18, weight: .semibold, design: .serif))
                        .foregroundStyle(Pal.ink)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    HStack(spacing: 8) {
                        if let d = episode.durationSeconds {
                            Label(timeLabel(Double(d)), systemImage: "clock")
                        }
                        if progress > 0.01 && progress < 0.99 {
                            Text("\(Int(progress * 100))%")
                        }
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Pal.faint)

                    if progress > 0.01 && progress < 0.99 && !episode.isVideo {
                        ProgressBar(fraction: progress)
                            .frame(height: 4)
                            .padding(.top, 3)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .didachesSurface(cornerRadius: 22, highlighted: true)
        }
        .buttonStyle(CalmCardStyle())
    }
}

private struct EpisodeRow: View {
    let index: Int
    let episode: Homily
    let progress: Double
    var onPlay: () -> Void = {}
    var onQueue: () -> Void = {}
    @ObservedObject private var downloads = HomilyDownloads.shared

    private var isDownloaded: Bool {
        downloads.state(id: episode.id, remote: episode.audioURL) == .downloaded
    }

    var body: some View {
        HStack(spacing: 12) {
            numberBadge

            VStack(alignment: .leading, spacing: 6) {
                Text(episode.title)
                    .font(.system(size: 17, weight: .semibold, design: .serif))
                    .foregroundStyle(Pal.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    if let d = episode.durationSeconds {
                        Label(timeLabel(Double(d)), systemImage: "clock")
                    }
                    if let speaker = episode.speaker, !speaker.isEmpty {
                        Text(speaker).lineLimit(1)
                    }
                    if episode.isVideo { tag("βίντεο") }
                    if episode.isShort == true { tag("σύντομο") }
                    if isDownloaded {
                        Image(systemName: "arrow.down.circle.fill").foregroundStyle(Pal.gild)
                    }
                }
                .font(.caption2.weight(.medium))
                .foregroundStyle(Pal.faint)
            }

            Spacer(minLength: 8)

            Menu { menuContent } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Pal.faint)
                    .frame(width: 30, height: 34)
                    .contentShape(Rectangle())
            }

            Image(systemName: episode.isAudioAvailable || episode.isVideo ? (episode.isVideo ? "play.rectangle.fill" : "play.fill") : "externaldrive.badge.exclamationmark")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(Circle().fill(Pal.gild))
                .shadow(color: Pal.gild.opacity(0.20), radius: 8, y: 3)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 12)
        .didachesSurface(cornerRadius: 18)
        .mediaProgressRow(id: episode.id, duration: Double(episode.durationSeconds ?? 0))
        .contentShape(Rectangle())
        .onTapGesture {
            if episode.isVideo || episode.isAudioAvailable { onPlay() }
        }
    }

    @ViewBuilder private var menuContent: some View {
        if episode.isVideo || episode.isAudioAvailable {
            Button { onPlay() } label: { Label("Αναπαραγωγή τώρα", systemImage: "play.fill") }
        }
        if !episode.isVideo {
            if episode.isAudioAvailable {
                Button { onQueue() } label: { Label("Προσθήκη στην ουρά", systemImage: "plus") }
                Divider()
                switch downloads.state(id: episode.id, remote: episode.audioURL) {
                case .none:
                    Button {
                        if let u = episode.audioURL { downloads.download(id: episode.id, remote: u) }
                    } label: { Label("Λήψη", systemImage: "arrow.down.circle") }
                case .downloading:
                    Label("Γίνεται λήψη…", systemImage: "arrow.down.circle")
                case .downloaded:
                    Button(role: .destructive) {
                        downloads.remove(id: episode.id, remote: episode.audioURL)
                    } label: { Label("Διαγραφή λήψης", systemImage: "trash") }
                }
            } else {
                Label("Δεν έχει συνδεθεί το αρχείο ήχου", systemImage: "externaldrive.badge.exclamationmark")
            }
        }
    }

    private var numberBadge: some View {
        ZStack {
            Circle().fill(Pal.gild.opacity(progress > 0.99 && !episode.isVideo ? 0.18 : 0.08))
            Circle().stroke(Pal.gild.opacity(0.28), lineWidth: 1)
            if progress > 0.99 && !episode.isVideo {
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Pal.gild)
            } else {
                Text("\(index)")
                    .font(.system(size: 14, weight: .semibold, design: .serif))
                    .foregroundStyle(Pal.gild)
            }
        }
        .frame(width: 38, height: 38)
    }

    private func tag(_ t: String) -> some View {
        Text(t).font(.caption2).padding(.horizontal, 6).padding(.vertical, 1)
            .background(Capsule().fill(Pal.gild.opacity(0.15))).foregroundStyle(Pal.gild)
    }
}

// MARK: - Player

struct HomilyPlayerView: View {
    let episode: Homily
    let context: String
    @ObservedObject private var player = HomilyPlayer.shared
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss
    @State private var scrubbing = false
    @State private var scrubValue = 0.0
    @State private var showQueue = false
    @State private var noteDraft: NotebookSourceNoteDraft?
    private let speeds: [Float] = [0.75, 1.0, 1.25, 1.5, 2.0]

    init(episode: Homily, context: String, initiallyShowingQueue: Bool = false) {
        self.episode = episode
        self.context = context
        _showQueue = State(initialValue: initiallyShowingQueue)
    }

    private var shown: Homily { episode.isVideo ? episode : (player.current ?? episode) }
    private var shownContext: String { episode.isVideo ? context : player.contextTitle }
    private var tone: Color { AthosPodcastStyle.tone(for: AthosAudioCoverLibrary.assetName(for: shown.subject)) }
    private var displayTime: Double { scrubbing ? scrubValue : player.currentTime }
    private var showReplay: Bool { MediaProgress.shared.isFinished(shown.id) && !player.isPlaying }

    var body: some View {
        GeometryReader { geometry in
            let coverHeight = max(190, min(geometry.size.width * 1.05, geometry.size.height - 390))
            ScrollView {
                VStack(spacing: 0) {
                    if showQueue {
                        minimizeButton
                        queuePanel.frame(height: coverHeight + 70)
                    } else {
                        AthosPodcastCover(title: shownContext, fadesTop: true, artworkSubject: shown.subject)
                            .frame(height: coverHeight + 32)
                            .overlay(alignment: .top) { minimizeButton }
                        titleBlock.padding(.horizontal, 28).padding(.top, 8).padding(.bottom, 18)
                    }
                    if episode.isVideo {
                        Button {
                            if let url = episode.youtubeURL { openURL(url) }
                        } label: {
                            Label("Άνοιγμα στο YouTube", systemImage: "play.rectangle.fill")
                                .font(.headline).padding(18)
                        }
                    } else {
                        if !showQueue { scrubber.padding(.horizontal, 28) }
                        transport.padding(.horizontal, 22).padding(.top, showQueue ? 18 : 8)
                        Spacer(minLength: 20)
                        HStack(spacing: 12) {
                            Image(systemName: "speaker.fill").font(.caption)
                            AthosPodcastVolume().frame(height: 28)
                            Image(systemName: "speaker.wave.3.fill").font(.caption)
                        }
                        .foregroundStyle(.white.opacity(0.55))
                        .padding(.horizontal, 28).padding(.top, 12)
                        HStack(spacing: 64) {
                            AthosPodcastAirPlay().frame(width: 44, height: 44)
                                .accessibilityLabel("AirPlay")
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) { showQueue.toggle() }
                            } label: {
                                Image(systemName: showQueue ? "list.bullet.rectangle.fill" : "list.bullet")
                                    .font(.system(size: 22)).frame(width: 44, height: 44)
                                    .foregroundStyle(.white.opacity(showQueue ? 1 : 0.6))
                            }
                            .accessibilityLabel(showQueue ? "Εμφάνιση εξωφύλλου" : "Τι ακολουθεί")
                        }
                        .padding(.top, 12)
                    }
                }
                .frame(maxWidth: 600).frame(maxWidth: .infinity)
                .frame(minHeight: geometry.size.height - 12)
                .padding(.bottom, 12)
            }.scrollIndicators(.hidden)
        }
        .foregroundStyle(.white).tint(.white)
        .background {
            ZStack {
                tone
                if showQueue {
                    LinearGradient(colors: [.white.opacity(0.12), .clear, .black.opacity(0.25)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                }
            }.ignoresSafeArea()
        }
        .preferredColorScheme(.dark)
        .accessibilityIdentifier("athos.player.fullscreen")
        .onAppear { if !episode.isVideo, player.current?.id != episode.id { player.open(episode, context: context) } }
        .sheet(item: $noteDraft) { draft in
            NotebookSourceNoteSheet(draft: draft).presentationDetents([.medium, .large])
        }
    }

    private var minimizeButton: some View {
        Button { dismiss() } label: {
            Capsule().fill(.white.opacity(0.4)).frame(width: 36, height: 5)
                .frame(maxWidth: .infinity).frame(height: 44).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Ελαχιστοποίηση αναπαραγωγής")
        .accessibilityIdentifier("athos.player.close")
        .simultaneousGesture(DragGesture(minimumDistance: 15).onEnded { value in
            if value.translation.height > 45, abs(value.translation.width) < value.translation.height {
                dismiss()
            }
        })
    }

    private var titleBlock: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("ATHOS AUDIO").font(.system(size: 10, weight: .medium)).foregroundStyle(.white.opacity(0.55))
                Text(shown.title).font(.system(size: 18, weight: .semibold)).lineLimit(2)
                Text(shownContext.interfaceGreek).font(.system(size: 16)).foregroundStyle(.white.opacity(0.6)).lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            optionsMenu
        }
    }

    private var optionsMenu: some View {
        Menu {
            Button("Προηγούμενη ομιλία", systemImage: "backward.end.fill") { player.previousTrack() }
            Button("Επόμενη ομιλία", systemImage: "forward.end.fill") { player.nextTrack() }.disabled(!player.hasNext)
            Button("Σημείωση αποσπάσματος", systemImage: "note.text.badge.plus") { noteDraft = makeCurrentClipNoteDraft() }
            HomilyDownloadButton(homily: shown, compact: false, tint: .white, muted: .white.opacity(0.6))
            if !player.chapters.isEmpty {
                Menu("Κεφάλαια") {
                    ForEach(player.chapters) { chapter in
                        Button(chapter.title) { player.jumpTo(chapter) }
                    }
                }
            }
            Button("Διακοπή και κλείσιμο", systemImage: "stop.fill") { player.stop(); dismiss() }
        } label: {
            Image(systemName: "ellipsis").font(.system(size: 16, weight: .bold))
                .frame(width: 30, height: 30).background(.white.opacity(0.16), in: Circle())
                .frame(width: 44, height: 44)
        }.accessibilityLabel("Επιλογές ομιλίας")
    }

    private var scrubber: some View {
        VStack(spacing: 0) {
            AthosPodcastScrubber(value: Binding(get: { displayTime }, set: { scrubValue = $0 }),
                   duration: player.duration,
                   onEditing: { editing in
                       if editing { scrubValue = player.currentTime }
                       scrubbing = editing
                       if !editing { player.seek(to: scrubValue) }
                   })
                .frame(height: 28)
            HStack {
                Text(timeLabel(displayTime))
                Spacer()
                Text("−\(timeLabel(max(0, player.duration - displayTime)))")
            }
            .font(.system(size: 11)).monospacedDigit().foregroundStyle(.white.opacity(0.5))
        }
    }

    private var transport: some View {
        HStack(spacing: 0) {
            Menu {
                ForEach(speeds, id: \.self) { rate in
                    Button { player.setRate(rate) } label: {
                        Label(String(format: "%g×", rate), systemImage: player.rate == rate ? "checkmark" : "")
                    }
                }
            } label: {
                Text(String(format: "%g×", player.rate)).font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.65)).frame(maxWidth: .infinity, minHeight: 52)
            }.accessibilityLabel("Ταχύτητα αναπαραγωγής")
            Button { player.skip(-15) } label: {
                Image(systemName: "gobackward.15").font(.system(size: 28))
                    .frame(maxWidth: .infinity, minHeight: 60)
            }.accessibilityLabel("Πίσω 15 δευτερόλεπτα")
            Button {
                if showReplay { player.seek(to: 0); player.play() } else { player.toggle() }
            } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : (showReplay ? "arrow.counterclockwise" : "play.fill"))
                    .font(.system(size: 44, weight: .semibold)).frame(maxWidth: .infinity, minHeight: 76)
            }.accessibilityLabel(player.isPlaying ? "Παύση" : "Αναπαραγωγή")
            Button { player.skip(30) } label: {
                Image(systemName: "goforward.30").font(.system(size: 28))
                    .frame(maxWidth: .infinity, minHeight: 60)
            }.accessibilityLabel("Μπροστά 30 δευτερόλεπτα")
            Menu {
                Button("Ανενεργό") { player.setSleep(.off) }
                ForEach([5, 10, 15, 30, 60], id: \.self) { minutes in
                    Button("\(minutes) λεπτά") { player.setSleep(.minutes(minutes)) }
                }
                Button("Στο τέλος του ηχητικού") { player.setSleep(.endOfTrack) }
            } label: {
                Image(systemName: player.sleepMode == .off ? "moon.zzz" : "moon.zzz.fill")
                    .font(.system(size: 19)).foregroundStyle(.white.opacity(0.65))
                    .frame(maxWidth: .infinity, minHeight: 52)
            }.accessibilityLabel("Χρονοδιακόπτης ύπνου")
        }.buttonStyle(.plain)
    }

    private var queuePanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                AthosPodcastCover(title: shownContext, showsTitle: false, fades: false)
                    .frame(width: 56, height: 56).clipShape(RoundedRectangle(cornerRadius: 5))
                VStack(alignment: .leading, spacing: 4) {
                    Text(shown.title).font(.system(size: 17, weight: .medium)).lineLimit(1)
                    Text(shownContext.interfaceGreek).font(.system(size: 16)).foregroundStyle(.white.opacity(0.55)).lineLimit(1)
                }
                Spacer(minLength: 0)
                optionsMenu
            }
            .padding(.top, 12)
            HStack {
                Text("Τι ακολουθεί").font(.system(size: 17, weight: .medium))
                Spacer()
                if !player.queue.isEmpty {
                    Button("Καθαρισμός") { player.clearQueue() }.font(.system(size: 15))
                }
            }.padding(.top, 16)
            if player.queue.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "text.line.first.and.arrowtriangle.forward").font(.title2)
                    Text("Η ουρά είναι άδεια").font(.headline)
                    Text("Πρόσθεσε ομιλίες για να συνεχίσεις την ακρόαση.").font(.subheadline)
                }
                .foregroundStyle(.white.opacity(0.6)).multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(player.queue) { item in
                        HStack(spacing: 12) {
                            AthosPodcastCover(title: item.subject, showsTitle: false, fades: false)
                                .frame(width: 46, height: 46).clipShape(RoundedRectangle(cornerRadius: 4))
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title).font(.system(size: 16)).lineLimit(2)
                                if let duration = item.durationSeconds {
                                    Text(timeLabel(Double(duration))).font(.system(size: 14)).foregroundStyle(.white.opacity(0.55))
                                }
                            }
                        }
                        .contextMenu { Button("Αφαίρεση από την ουρά", systemImage: "minus.circle") { player.removeFromQueue(item) } }
                        .listRowBackground(Color.clear).listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    }
                    .onMove { player.moveInQueue(from: $0, to: $1) }
                }
                .listStyle(.plain).scrollContentBackground(.hidden)
                .environment(\.editMode, .constant(.active))
            }
        }.padding(.horizontal, 28)
    }

    private func makeCurrentClipNoteDraft() -> NotebookSourceNoteDraft? {
        guard !shown.isVideo, shown.audioUrl != nil else { return nil }
        let start = max(0, displayTime)
        let end = min(player.duration > 0 ? player.duration : start + 15, start + 15)
        return NotebookSourceNoteDraft(
            title: shown.title,
            category: .didaches,
            anchor: NotebookAnchor(
                kind: .didaches,
                title: shown.title,
                excerpt: shown.hook ?? "Απόσπασμα \(timeLabel(start)) έως \(timeLabel(end))",
                routeValue: shown.id,
                startTime: start,
                endTime: end,
                audioUrl: shown.audioUrl,
                contextTitle: shownContext
            )
        )
    }
}

// MARK: - «Σήμερα»: Συνέχισε + Ἀπόσπασμα ἡμέρας

enum LastListened {
    private static let key = "klimax.homily.lastListened"
    struct Snapshot: Codable { let homily: Homily; let context: String }
    static func save(_ homily: Homily, context: String) {
        if let data = try? JSONEncoder().encode(Snapshot(homily: homily, context: context)) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
    static func load() -> Snapshot? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(Snapshot.self, from: data)
    }
}

@MainActor
final class DailyClipStore: ObservableObject {
    @Published var clip: Homily?
    private static let q = """
    *[_type=="homily" && (isShort==true || durationSeconds<=240 || title match "Κλιπ")]{
      _id,title,episodeNumber,audioUrl,durationSeconds,hook,isShort,topic,youtubeVideoId,mediaType,"seriesTitle":series->title
    }
    """
    func load() async {
        guard clip == nil else { return }
        var c = URLComponents()
        c.scheme = "https"; c.host = "\(Sanity.projectId).apicdn.sanity.io"
        c.path = "/\(Sanity.apiVersion)/data/query/\(Sanity.dataset)"
        c.queryItems = [URLQueryItem(name: "query", value: Self.q)]
        guard let url = c.url else { return }
        var req = URLRequest(url: url)
        if let t = Sanity.token { req.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization") }
        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let all = try? JSONDecoder().decode(SanityResult.self, from: data).result,
              !all.isEmpty else { return }
        let pool = all.filter { !$0.isVideo }.sorted { $0.id < $1.id }
        guard !pool.isEmpty else { return }
        let day = Int(Date().timeIntervalSince1970 / 86400)          // ἀλλάζει κάθε μέρα, χωρὶς ἐπαναλήψεις μέχρι νὰ τελειώσουν ὅλα
        clip = pool[day % pool.count]
    }
}

// Κάρτα «Συνέχισε ἀπ' ὅπου ἔμεινες»
struct ContinueListeningCard: View {
    @State private var snap = LastListened.load()
    private let player = HomilyPlayer.shared
    var body: some View {
        if let s = snap {
            Button { player.present(s.homily, context: s.context) } label: { body(for: s) }
                .buttonStyle(.plain)
                .onAppear { snap = LastListened.load() }
        }
    }
    private func body(for s: LastListened.Snapshot) -> some View {
        let prog = PlaybackProgress.fraction(for: s.homily.id, duration: s.homily.durationSeconds)
        return VStack(alignment: .leading, spacing: 10) {
            Label("Συνέχισε", systemImage: "play.circle.fill").font(.caption.weight(.semibold)).foregroundStyle(Pal.gild)
            Text(s.homily.title).font(.system(.headline, design: .serif)).foregroundStyle(Pal.ink).lineLimit(2)
            Text(s.context).font(.caption).foregroundStyle(Pal.faint)
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Pal.gild.opacity(0.15)).frame(height: 4)
                    Capsule().fill(Pal.gild).frame(width: max(4, g.size.width * prog), height: 4)
                }
            }.frame(height: 4)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .didachesSurface(cornerRadius: 18, highlighted: true)
    }
}

// Κάρτα «Ἀπόσπασμα τῆς ἡμέρας»
struct DailyClipCard: View {
    @ObservedObject private var store = HomilyStore.shared
    private let player = HomilyPlayer.shared

    private var clip: Homily? {
        let pool = store.subjects
            .flatMap(\.episodes)
            .filter { !$0.isVideo && $0.isAudioAvailable }
            .sorted { $0.id < $1.id }
        guard !pool.isEmpty else { return nil }
        let day = Int(Date().timeIntervalSince1970 / 86400)
        return pool[day % pool.count]
    }

    var body: some View {
        Group {
            if let clip {
                Button { player.present(clip, context: "Απόσπασμα της ημέρας") } label: { body(for: clip) }
                    .buttonStyle(.plain)
            }
        }
    }
    private func body(for clip: Homily) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(Pal.gild.opacity(0.12))
                Image(systemName: "sparkles").font(.system(size: 20)).foregroundStyle(Pal.gild)
            }.frame(width: 50, height: 50)
            VStack(alignment: .leading, spacing: 3) {
                Text("Απόσπασμα της ημέρας").font(.caption.weight(.semibold)).foregroundStyle(Pal.gild)
                Text(clip.title).font(.system(.subheadline, design: .serif)).foregroundStyle(Pal.ink).lineLimit(2)
                if let d = clip.durationSeconds {
                    Text(timeLabel(Double(d))).font(.caption2).foregroundStyle(Pal.faint)
                }
            }
            Spacer(minLength: 6)
            Image(systemName: "play.circle.fill").font(.title2).foregroundStyle(Pal.gild)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .didachesSurface(cornerRadius: 18)
    }
}

#Preview { DidachesLibraryView() }
