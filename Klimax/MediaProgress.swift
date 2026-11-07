//
//  MediaProgress.swift
//  Klimax
//
//  A small, private tracker for long form media (AthosTV videos and audio
//  homilies). It remembers, per item id, the last position and whether the
//  item was finished, so the playback pills can show a compact progress track
//  and a green tick when you are done, and so a video can resume where you
//  left off. This is quiet private measurement, in the same spirit as the
//  streak system: no scores, no ranking, just a gentle sense of place.
//

import SwiftUI

@Observable
final class MediaProgress {
    static let shared = MediaProgress()

    private struct Entry: Codable {
        var seconds: Double
        var finished: Bool
        var duration: Double? = nil
    }

    private var entries: [String: Entry]
    private let key = "klimax.mediaprogress.v1"
    private var lastPersist = Date.distantPast

    private init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([String: Entry].self, from: data) {
            entries = decoded
        } else {
            entries = [:]
        }
    }

    /// Fraction 0...1 for playback indicators. Finished items always read as full.
    func fraction(for id: String, duration: Double) -> Double {
        guard let entry = entries[id] else { return 0 }
        if entry.finished { return 1 }
        let total = entry.duration ?? duration
        guard total > 0 else { return 0 }
        return min(1, max(0, entry.seconds / total))
    }

    func isFinished(_ id: String) -> Bool {
        entries[id]?.finished ?? false
    }

    /// Where to resume from. A finished item starts fresh.
    func resumeSeconds(for id: String) -> Double {
        guard let entry = entries[id], !entry.finished else { return 0 }
        return max(0, entry.seconds)
    }

    /// Feed the current playback position. Crossing about ninety percent marks
    /// the item finished.
    func update(id: String, seconds: Double, duration: Double) {
        guard !id.isEmpty, seconds.isFinite, duration.isFinite else { return }
        var entry = entries[id] ?? Entry(seconds: 0, finished: false)
        entry.seconds = max(0, seconds)
        if duration > 0 { entry.duration = duration }
        if duration > 0, seconds >= duration * 0.9 {
            entry.finished = true
        }
        entries[id] = entry
        persistThrottled()
    }

    func markFinished(_ id: String) {
        guard !id.isEmpty else { return }
        var entry = entries[id] ?? Entry(seconds: 0, finished: false)
        entry.finished = true
        entries[id] = entry
        persist()
    }

    private func persistThrottled() {
        if Date().timeIntervalSince(lastPersist) > 3 { persist() }
    }

    func flush() { persist() }

    private func persist() {
        lastPersist = Date()
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

/// A visible, accessible status in the row's layout, never over its text.
/// Shared label for audio/video play buttons, also safe inside a tappable row.
/// Only the pill expands; progress never adds a second bar beneath the row.
struct AthosPlaybackPill: View {
    let id: String
    let duration: Double
    var compact = false

    var body: some View {
        AthosPlaybackPillLabel(duration: duration,
            fraction: MediaProgress.shared.fraction(for: id, duration: duration),
            started: MediaProgress.shared.resumeSeconds(for: id) > 0,
            finished: MediaProgress.shared.isFinished(id), compact: compact)
    }
}

/// Value-only rendering also allows previews of all states without changing
/// the listener's playback history or manufacturing completed episodes.
struct AthosPlaybackPillLabel: View {
    let duration: Double
    let fraction: Double
    let started: Bool
    let finished: Bool
    var compact = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .caption) private var trackWidth: CGFloat = 44

    private var tint: Color { finished ? AthosPlaybackStatus.green : Gild.accentForeground }
    private var durationLabel: String {
        guard duration.isFinite, duration > 0 else { return "Αναπαραγωγή" }
        let minutes = max(1, Int(duration / 60))
        if minutes >= 60, minutes % 60 == 0 { return "\(minutes / 60) ώρ." }
        if minutes >= 60 { return "\(minutes / 60) ώρ. \(minutes % 60) λεπ." }
        return "\(minutes) λεπ."
    }
    private var visibleDuration: String {
        guard compact else { return durationLabel }
        guard duration.isFinite, duration > 0 else { return "Προβολή" }
        let minutes = max(1, Int(duration / 60))
        return minutes >= 60 ? "\(minutes / 60)ω \(minutes % 60)λ" : durationLabel
    }

    var body: some View {
        Group {
            if compact {
                // Under episode artwork, grow vertically inside the pill,
                // never into the neighbouring title/description column.
                VStack(spacing: 5) {
                    durationContent
                    if started, !finished { progressTrack }
                }
            } else {
                HStack(spacing: 8) {
                    durationContent
                    if started, !finished { progressTrack }
                }
            }
        }
        .foregroundStyle(tint)
        .padding(.horizontal, compact ? 10 : 12).padding(.vertical, 9)
        .frame(maxWidth: compact ? .infinity : nil)
        .background(finished ? AthosPlaybackStatus.green.opacity(0.15) : Color.primary.opacity(0.06), in: Capsule())
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: started)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: finished)
        .frame(minHeight: 44)
        .contentShape(Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(finished ? "Ολοκληρώθηκε · \(durationLabel)" : "Αναπαραγωγή · \(durationLabel)")
        .accessibilityValue(started && !finished ? "Σε εξέλιξη, \(Int(fraction * 100)) τοις εκατό" : "")
        .accessibilityHint(finished ? "Αναπαραγωγή ξανά" : "")
    }

    private var durationContent: some View {
        HStack(spacing: 8) {
            Image(systemName: finished ? "checkmark" : "play.fill")
                .font(.system(size: 11, weight: .bold))
            Text(visibleDuration).font(.system(.caption, weight: .semibold)).monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.85)
        }
    }

    private var progressTrack: some View {
        Capsule().fill(tint.opacity(0.16))
            .frame(width: trackWidth, height: 3)
            .overlay(alignment: .leading) {
                Capsule().fill(tint).frame(width: trackWidth * fraction, height: 3)
            }
            .transition(.opacity.combined(with: .scale(scale: 0.85, anchor: .leading)))
            .accessibilityHidden(true)
    }
}

struct AthosPlaybackStatus: View {
    let id: String
    let duration: Double
    private var progress: Double { MediaProgress.shared.fraction(for: id, duration: duration) }
    static let green = Color.adaptive(Color(red: 0.12, green: 0.43, blue: 0.29),
                                      Color(red: 0.40, green: 0.80, blue: 0.58))

    var body: some View {
        if MediaProgress.shared.isFinished(id) {
            Label("Ολοκληρώθηκε", systemImage: "checkmark.circle.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Self.green)
        } else if MediaProgress.shared.resumeSeconds(for: id) > 0 {
            VStack(alignment: .leading, spacing: 5) {
                Text(progress > 0 ? "Σε εξέλιξη · \(Int(progress * 100))%" : "Σε εξέλιξη")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(AthosPalette.secondaryText)
                if progress > 0 {
                    ProgressView(value: progress).tint(Self.green)
                        .accessibilityLabel("Πρόοδος αναπαραγωγής")
                }
            }
        }
    }
}

struct AthosEpisodeSurface: ViewModifier {
    let id: String
    func body(content: Content) -> some View {
        let finished = MediaProgress.shared.isFinished(id)
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        content
            .background {
                shape.fill(AthosPalette.elevated)
                    .overlay(shape.fill(AthosPlaybackStatus.green.opacity(finished ? 0.09 : 0)))
            }
            .overlay {
                shape.stroke(finished ? AthosPlaybackStatus.green.opacity(0.35) : AthosPalette.hairline,
                             lineWidth: 0.8).allowsHitTesting(false)
            }
            .overlay(alignment: .leading) {
                if finished {
                    Capsule().fill(AthosPlaybackStatus.green)
                        .frame(width: 3).padding(.vertical, 22)
                        .allowsHitTesting(false)
                }
            }
    }
}

/// Applied to a whole row or entry (not just its thumbnail). While in progress
/// it draws a thin green line along the bottom, from the left, sized to how far
/// you are. When finished it adds a green wash that is strongest on the left and
/// fades toward the right, and fills the bottom line.
struct MediaProgressRowStyle: ViewModifier {
    let id: String
    let duration: Double
    var barLeading: CGFloat = 16
    var barTrailing: CGFloat = 52
    var barBottom: CGFloat = 12
    var washInset: CGFloat = 6
    var washRadius: CGFloat = 18

    private var store: MediaProgress { .shared }
    private var finished: Bool { store.isFinished(id) }
    private var fraction: Double { store.fraction(for: id, duration: duration) }
    private let green = Color(red: 0.30, green: 0.82, blue: 0.48)

    func body(content: Content) -> some View {
        content
            .overlay {
                if finished {
                    RoundedRectangle(cornerRadius: washRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [green.opacity(0.26), green.opacity(0.07), .clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .padding(washInset)
                        .allowsHitTesting(false)
                }
            }
            .overlay(alignment: .bottomLeading) {
                if !finished, fraction > 0.001 {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(green.opacity(0.18))
                                .frame(width: max(0, geo.size.width - barLeading - barTrailing), height: 4)
                            Capsule()
                                .fill(green)
                                .frame(width: max(0, geo.size.width - barLeading - barTrailing) * fraction, height: 4)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                        .padding(.leading, barLeading)
                        .padding(.bottom, barBottom)
                    }
                    .allowsHitTesting(false)
                }
            }
    }
}

extension View {
    /// Marks a whole entry with listening or watching progress. Pass the item id
    /// and its duration in seconds.
    func mediaProgressRow(id: String, duration: Double) -> some View {
        modifier(MediaProgressRowStyle(id: id, duration: duration))
    }
}
