//
//  HomilyMiniPlayer.swift
//  Klimax
//
//  Ἡ σταθερὴ μπάρα ἀναπαραγωγῆς ποὺ κάθεται πάνω ἀπὸ τὸ tab bar καὶ μένει
//  ὁρατὴ σὲ ΚΑΘΕ ὀθόνη ὅσο παίζει μία ὁμιλία, μαζὶ μὲ τὴν πλήρη ὀθόνη, τὴν
//  οὐρά, καὶ τὶς λήψεις offline. Ὅλα δένουν μὲ τὸν ὑπάρχοντα HomilyPlayer.shared.
//
//  Σύνδεση: στὸ RootView, ἡ μπάρα μπαίνει σὲ «.tabViewBottomAccessory» (iOS 26),
//  ὥστε νὰ κάθεται ΠΑΝΩ ἀπὸ τὸ γυάλινο tab bar, ὄχι πάνω του.
//

import SwiftUI
// MARK: - Βοηθητικοὶ τύποι

enum HomilySleep: Equatable {
    case off
    case minutes(Int)
    case endOfTrack
}

struct HomilyChapter: Identifiable {
    let id = UUID()
    let title: String
    let startTime: Double
}

// MARK: - Σταθερὴ μπάρα (mini player)
//
//  Στὸ iOS 26 μπαίνει μέσα στὸ tabViewBottomAccessory (RootView), ποὺ τῆς δίνει
//  μόνο του τὸ γυαλὶ καὶ τὴ σωστὴ θέση ΠΑΝΩ ἀπὸ τὸ tab bar, ὅπως τὸ Apple Music.
//  Στὶς παλιότερες ἐκδόσεις τυλίγεται μόνη της σὲ γυαλί (glassWrapped).

struct HomilyMiniBar: View {
    @ObservedObject private var player = HomilyPlayer.shared
    var glassWrapped: Bool = false

    var body: some View {
        if let h = player.current {
            let row = HStack(spacing: 10) {
                AthosPodcastCover(title: player.contextTitle, showsTitle: false, fades: false)
                .frame(width: 38, height: 38)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                VStack(alignment: .leading, spacing: 1) {
                    Text(h.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AthosPalette.ink)
                        .lineLimit(1)
                    Text(player.contextTitle.interfaceGreek)
                        .font(.system(size: 11))
                        .foregroundStyle(AthosAudioPalette.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 6)

                Button { player.toggle() } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(AthosPalette.ink)
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(player.isPlaying ? "Παύση" : "Αναπαραγωγή")

                Button { player.skip(30) } label: {
                    Image(systemName: "goforward.30")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AthosAudioPalette.secondary)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Μπροστά 30 δευτερόλεπτα")
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 52)
            // The native tab accessory (or the fallback below) supplies the glass.
            // An opaque fill here would hide its translucency.
            .contentShape(Rectangle())
            .onTapGesture { player.fullScreenHomily = h }
            .contextMenu { Button("Διακοπή αναπαραγωγής", systemImage: "stop.fill") { player.stop() } }

            if glassWrapped {
                row
                    .klimaxLiquidGlass(in: RoundedRectangle(cornerRadius: 20, style: .continuous), interactive: false)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 6)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                row
            }
        }
    }
}

// MARK: - Οὐρά «Τί ἀκολουθεῖ» + Κεφάλαια

struct QueueSheet: View {
    @ObservedObject private var player = HomilyPlayer.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if !player.chapters.isEmpty {
                    Section("Κεφάλαια") {
                        ForEach(player.chapters) { ch in
                            Button {
                                player.jumpTo(ch); dismiss()
                            } label: {
                                HStack {
                                    Text(ch.title).foregroundStyle(Paper.ink)
                                    Spacer()
                                    Text(timeLabel(ch.startTime)).foregroundStyle(Paper.inkMute)
                                }
                            }
                        }
                    }
                }

                Section("Τι ακολουθεί") {
                    if player.queue.isEmpty {
                        Text("Η ουρά είναι άδεια.").foregroundStyle(Paper.inkMute)
                    } else {
                        ForEach(player.queue) { h in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(h.title).foregroundStyle(Paper.ink).lineLimit(1)
                                if let d = h.durationSeconds {
                                    Text(timeLabel(Double(d))).font(.caption).foregroundStyle(Paper.inkMute)
                                }
                            }
                        }
                        .onMove { player.moveInQueue(from: $0, to: $1) }
                        .onDelete { idx in idx.map { player.queue[$0] }.forEach { player.removeFromQueue($0) } }
                    }
                }
            }
            .navigationTitle("Τι ακολουθεί")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { EditButton() }
                ToolbarItem(placement: .topBarTrailing) {
                    if !player.queue.isEmpty {
                        Button("Καθαρισμός") { player.clearQueue() }
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Λήψη offline

enum HomilyDownloadState: Equatable {
    case none
    case downloading(Double)
    case downloaded
}

struct HomilyDownloadButton: View {
    let homily: Homily
    var compact: Bool = true
    var tint: Color = Paper.gold
    var muted: Color = Paper.inkMute
    @ObservedObject private var downloads = HomilyDownloads.shared

    var body: some View {
        let state = downloads.state(id: homily.id, remote: homily.audioURL)
        Button {
            switch state {
            case .none: if let u = homily.audioURL { downloads.download(id: homily.id, remote: u) }
            case .downloaded: downloads.remove(id: homily.id, remote: homily.audioURL)
            case .downloading: break
            }
        } label: {
            if compact {
                icon(for: state)
            } else {
                VStack(spacing: 3) {
                    icon(for: state)
                    Text(label(for: state)).font(.system(size: 11))
                }
                .foregroundStyle(state == .downloaded ? tint : muted)
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private func icon(for s: HomilyDownloadState) -> some View {
        switch s {
        case .none:
            Image(systemName: "arrow.down.circle").font(.system(size: 17)).foregroundStyle(tint)
        case .downloading(let p):
            if p <= 0.001 {
                ProgressView().controlSize(.small).tint(tint).frame(width: 18, height: 18)
            } else {
                ZStack {
                    Circle().stroke(muted.opacity(0.22), lineWidth: 2)
                    Circle().trim(from: 0, to: p)
                        .stroke(tint, lineWidth: 2)
                        .rotationEffect(.degrees(-90))
                }
                .frame(width: 18, height: 18)
            }
        case .downloaded:
            Image(systemName: "checkmark.circle.fill").font(.system(size: 17)).foregroundStyle(tint)
        }
    }

    private func label(for s: HomilyDownloadState) -> String {
        switch s {
        case .none: return "Λήψη"
        case .downloading: return "Λήψη…"
        case .downloaded: return "Κατεβασμένο"
        }
    }
}

@MainActor
final class HomilyDownloads: ObservableObject {
    static let shared = HomilyDownloads()

    @Published private var states: [String: HomilyDownloadState] = [:]

    private init() {}

    private var folder: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("KlimaxHomilies", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private func safe(_ id: String) -> String {
        id.replacingOccurrences(of: "[^A-Za-z0-9]", with: "_", options: .regularExpression)
    }

    private func fileName(id: String, remote: URL?) -> String {
        let ext = (remote?.pathExtension.isEmpty == false) ? remote!.pathExtension : "m4a"
        return "\(safe(id)).\(ext)"
    }

    func localURL(id: String, remote: URL?) -> URL? {
        let u = folder.appendingPathComponent(fileName(id: id, remote: remote))
        return FileManager.default.fileExists(atPath: u.path) ? u : nil
    }

    func state(id: String, remote: URL?) -> HomilyDownloadState {
        if localURL(id: id, remote: remote) != nil { return .downloaded }
        return states[id] ?? .none
    }

    func download(id: String, remote: URL) {
        guard localURL(id: id, remote: remote) == nil else { return }
        if case .downloading = (states[id] ?? .none) { return }
        states[id] = .downloading(0)
        let dest = folder.appendingPathComponent(fileName(id: id, remote: remote))
        #if DEBUG
        print("KlimaxAudio download start \(id) <- \(remote.absoluteString)")
        #endif

        Task {
            var req = URLRequest(url: remote)
            // Μερικοὶ servers ἀπορρίπτουν αἰτήματα χωρὶς κανονικὸ User-Agent
            // (ἐνῶ ὁ AVPlayer περνᾶ), γι' αὐτὸ στέλνουμε ἕνα κανονικό.
            req.setValue(
                "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1",
                forHTTPHeaderField: "User-Agent")
            req.setValue("*/*", forHTTPHeaderField: "Accept")
            do {
                let (tmp, resp) = try await URLSession.shared.download(for: req)
                if let http = resp as? HTTPURLResponse {
                    #if DEBUG
                    print("KlimaxAudio download HTTP \(http.statusCode) len=\(http.expectedContentLength) \(id)")
                    #endif
                    guard (200..<400).contains(http.statusCode) else {
                        states[id] = HomilyDownloadState.none
                        return
                    }
                }
                try? FileManager.default.removeItem(at: dest)
                try FileManager.default.moveItem(at: tmp, to: dest)
                states[id] = .downloaded
                #if DEBUG
                let attrs = try? FileManager.default.attributesOfItem(atPath: dest.path)
                let size = (attrs?[.size] as? Int) ?? 0
                print("KlimaxAudio download done \(id) -> \(dest.lastPathComponent) size=\(size) bytes")
                #endif
            } catch {
                states[id] = HomilyDownloadState.none
                #if DEBUG
                let ns = error as NSError
                print("KlimaxAudio download failed \(id): [\(ns.domain) \(ns.code)] \(error.localizedDescription)")
                #endif
            }
        }
    }

    func remove(id: String, remote: URL?) {
        if let u = localURL(id: id, remote: remote) { try? FileManager.default.removeItem(at: u) }
        states[id] = HomilyDownloadState.none
    }
}
