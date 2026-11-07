//
//  AthosDesignKit.swift
//  Klimax
//
//  Τὰ κοινὰ δομικὰ στοιχεῖα τῶν δύο μέσων (Athos TV καὶ Athos Audio).
//  Ἐδῶ ζοῦν: ἡ παλέτα, τὸ ΝΑΤΙVΕ liquid glass, τὸ θολὸ βάθος (backdrop),
//  ἡ πλωτὴ μπάρα κορυφῆς, ἡ κάψουλα ἀναπαραγωγῆς καὶ οἱ βοηθοὶ χρόνου.
//
//  Κανόνας: καμία ὀθόνη λεπτομερειῶν δὲν χρησιμοποιεῖ GeometryReader ὡς ρίζα
//  καὶ καμία δὲν κλειδώνει ὕψος. Ἔτσι ἡ σελίδα φτάνει πάντα ὣς τὸ κάτω ἄκρο
//  τῆς ὀθόνης καὶ τὰ πλωτὰ κουμπιὰ δέχονται κανονικὰ τὸ ἄγγιγμα.
//

import SwiftUI
import UIKit
import MediaPlayer
import AVKit

// MARK: - Lock Screen artwork

@MainActor
enum AthosNowPlayingArtwork {
    private static let cache: NSCache<NSString, MPMediaItemArtwork> = {
        let cache = NSCache<NSString, MPMediaItemArtwork>()
        cache.countLimit = 8
        return cache
    }()

    /// Use the episode's actual subject, not a navigation label such as Search
    /// or Daily Clip. Covers are bundled, so offline playback needs no network.
    static func audio(subject: String) -> MPMediaItemArtwork? {
        let asset = AthosAudioCoverLibrary.assetName(for: subject)
        if let artwork = cache.object(forKey: asset as NSString) { return artwork }
        guard let source = UIImage(named: asset) else { return nil }
        // Some source covers are landscape. Match the square, aspect-fill
        // presentation used in the library, without stretching the artwork.
        let size = CGSize(width: 600, height: 600)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.black.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            let scale = max(size.width / source.size.width, size.height / source.size.height)
            let rendered = CGSize(width: source.size.width * scale, height: source.size.height * scale)
            source.draw(in: CGRect(x: (size.width - rendered.width) / 2,
                                   y: (size.height - rendered.height) / 2,
                                   width: rendered.width, height: rendered.height))
        }
        let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
        cache.setObject(artwork, forKey: asset as NSString)
        return artwork
    }
}

// MARK: - Podcast reference surfaces

enum AthosPodcastStyle {
    static let background = Color(uiColor: .systemBackground)
    static let secondary = Color(uiColor: .secondaryLabel)
    static let separator = Color(uiColor: .separator).opacity(0.35)
    static let videoTone = Color(red: 0.12, green: 0.20, blue: 0.25)
    private static let tones = NSCache<NSString, UIColor>()

    /// Cache a single sampled colour per cover, not on each playback tick.
    static func tone(for asset: String) -> Color {
        if let cached = tones.object(forKey: asset as NSString) { return Color(cached) }
        var pixel: [UInt8] = [0, 0, 0, 255]
        if let image = UIImage(named: asset)?.cgImage {
            pixel.withUnsafeMutableBytes { bytes in
                if let context = CGContext(data: bytes.baseAddress, width: 1, height: 1,
                    bitsPerComponent: 8, bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) {
                    context.draw(image, in: CGRect(x: 0, y: 0, width: 1, height: 1))
                }
            }
        }
        let sampled = UIColor(red: CGFloat(pixel[0]) / 255, green: CGFloat(pixel[1]) / 255,
                              blue: CGFloat(pixel[2]) / 255, alpha: 1)
        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0
        sampled.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: nil)
        let result = UIColor(hue: hue, saturation: max(0.38, saturation),
                             brightness: min(0.34, max(0.20, brightness * 0.55)), alpha: 1)
        tones.setObject(result, forKey: asset as NSString)
        return Color(result)
    }
}

struct AthosPodcastCover: View {
    let title: String
    var showsTitle = true
    var fades = true
    var fadesTop = false
    var artworkSubject: String? = nil
    private var asset: String { AthosAudioCoverLibrary.assetName(for: artworkSubject ?? title) }
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottomLeading) {
                Image(asset).resizable().scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height).clipped()
                LinearGradient(colors: [.black.opacity(0.08), .clear, .black.opacity(0.32)],
                               startPoint: .top, endPoint: .bottom)
                if fades {
                    // A longer, eased top fade removes the hard artwork edge
                    // under the full-screen player's status bar and handle.
                    let tone = AthosPodcastStyle.tone(for: asset)
                    LinearGradient(stops: [.init(color: fadesTop ? tone : .clear, location: 0),
                        .init(color: fadesTop ? tone.opacity(0.96) : .clear, location: 0.04),
                        .init(color: fadesTop ? tone.opacity(0.65) : .clear, location: 0.12),
                        .init(color: fadesTop ? tone.opacity(0.22) : .clear, location: 0.23),
                        .init(color: .clear, location: 0.34),
                        .init(color: .clear, location: 0.55),
                        .init(color: tone, location: 1)],
                        startPoint: .top, endPoint: .bottom)
                }
                if showsTitle {
                    Text(title.interfaceGreek)
                        .font(.system(size: min(40, geometry.size.width * 0.105), weight: .bold, design: .serif))
                        .foregroundStyle(.white).shadow(color: .black.opacity(0.5), radius: 12)
                        .lineLimit(3).minimumScaleFactor(0.75)
                        .padding(.horizontal, 28).padding(.bottom, geometry.size.height * 0.20)
                }
            }
        }.accessibilityHidden(true)
    }
}

struct AthosPodcastBackButton: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left").font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white).frame(width: 32, height: 32)
                .background(.black.opacity(0.3), in: Circle()).frame(width: 44, height: 44)
        }.buttonStyle(.plain).accessibilityLabel("Πίσω")
    }
}

/// Shared Apple-style capsule, with native glass only on navigation controls.
struct AthosPodcastPlayButton: View {
    var title = "Αναπαραγωγή"
    let tone: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: "play.fill")
                .font(.system(.headline, weight: .bold))
                .multilineTextAlignment(.center)
                .foregroundStyle(tone)
                .padding(.horizontal, 22).padding(.vertical, 13)
                .frame(minHeight: 48)
                .background(.white, in: Capsule())
        }.buttonStyle(.plain)
    }
}

enum AthosEpisodeFilter: String, CaseIterable, Identifiable {
    case all = "Όλα τα επεισόδια"
    case inProgress = "Σε εξέλιξη"
    case unplayed = "Δεν έχουν ξεκινήσει"
    case completed = "Ολοκληρωμένα"
    var id: String { rawValue }

    func includes(id: String) -> Bool {
        if self == .all { return true }
        let finished = MediaProgress.shared.isFinished(id)
        let started = MediaProgress.shared.resumeSeconds(for: id) > 0
        switch self {
        case .all: return true
        case .inProgress: return started && !finished
        case .unplayed: return !started && !finished
        case .completed: return finished
        }
    }
}

struct AthosSeriesGlassToolbar: View {
    @Binding var filter: AthosEpisodeFilter
    @Binding var reversed: Bool
    var overContent = false
    let onBack: () -> Void
    let onEpisodes: () -> Void
    let onPlayFirst: () -> Void
    let onPlayLatest: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    private var foreground: Color { overContent ? .primary : .white }

    var body: some View {
        HStack {
            AthosGlassIconButton(symbol: "chevron.left", tint: foreground, accessibility: "Πίσω", action: onBack)
            Spacer()
            HStack(spacing: 0) {
                Menu {
                    Picker("Επεισόδια", selection: $filter) {
                        ForEach(AthosEpisodeFilter.allCases) { item in Text(item.rawValue).tag(item) }
                    }
                } label: { toolbarSymbol("line.3.horizontal.decrease") }
                .accessibilityLabel("Φίλτρο επεισοδίων")
                Menu {
                    Picker("Ταξινόμηση", selection: $reversed) {
                        Text("Από την αρχή").tag(false)
                        Text("Από το τέλος").tag(true)
                    }
                } label: { toolbarSymbol("arrow.up.arrow.down") }
                .accessibilityLabel("Σειρά επεισοδίων")
                Menu {
                    Button("Όλα τα επεισόδια", systemImage: "list.bullet") { onEpisodes() }
                    Button("Πρώτο επεισόδιο", systemImage: "play.fill", action: onPlayFirst)
                    Button("Τελευταίο επεισόδιο", systemImage: "play.fill", action: onPlayLatest)
                } label: { toolbarSymbol("ellipsis") }
                .accessibilityLabel("Επιλογές σειράς")
            }
            .athosGlass(in: Capsule())
        }
        .padding(.horizontal, 16).padding(.vertical, 6)
        .environment(\.colorScheme, overContent ? colorScheme : .dark)
    }

    private func toolbarSymbol(_ name: String) -> some View {
        Image(systemName: name).font(.system(size: 20, weight: .semibold))
            .foregroundStyle(foreground).frame(width: 48, height: 46).contentShape(Rectangle())
    }
}

struct AthosPodcastVolume: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        #if targetEnvironment(simulator)
        // Simulator has no system audio route; show a non-interactive preview.
        let view = UISlider(frame: .zero)
        view.value = 0.55
        view.isUserInteractionEnabled = false
        view.minimumTrackTintColor = UIColor.white.withAlphaComponent(0.55)
        view.maximumTrackTintColor = UIColor.white.withAlphaComponent(0.18)
        view.setThumbImage(UIImage(), for: .normal)
        view.accessibilityLabel = "Ένταση ήχου — διαθέσιμη στη συσκευή"
        return view
        #else
        let view = MPVolumeView(frame: .zero)
        view.tintColor = UIColor.white.withAlphaComponent(0.65)
        view.showsRouteButton = false
        view.setVolumeThumbImage(UIImage(systemName: "circle.fill",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 7)), for: .normal)
        return view
        #endif
    }
    func updateUIView(_ view: UIView, context: Context) {}
}

struct AthosPodcastScrubber: UIViewRepresentable {
    @Binding var value: Double
    let duration: Double
    let onEditing: (Bool) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIView(context: Context) -> UISlider {
        let slider = UISlider(frame: .zero)
        slider.minimumTrackTintColor = UIColor.white.withAlphaComponent(0.65)
        slider.maximumTrackTintColor = UIColor.white.withAlphaComponent(0.20)
        slider.setThumbImage(UIImage(systemName: "circle.fill",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 6))?.withTintColor(.white, renderingMode: .alwaysOriginal), for: .normal)
        slider.accessibilityLabel = "Θέση αναπαραγωγής"
        slider.addTarget(context.coordinator, action: #selector(Coordinator.began), for: .touchDown)
        slider.addTarget(context.coordinator, action: #selector(Coordinator.changed(_:)), for: .valueChanged)
        slider.addTarget(context.coordinator, action: #selector(Coordinator.ended), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        return slider
    }
    func updateUIView(_ slider: UISlider, context: Context) {
        context.coordinator.parent = self
        slider.maximumValue = Float(max(1, duration))
        slider.value = Float(value)
        slider.accessibilityValue = athosClock(value)
    }
    final class Coordinator: NSObject {
        var parent: AthosPodcastScrubber
        var tracking = false
        init(_ parent: AthosPodcastScrubber) { self.parent = parent }
        @objc func began() { tracking = true; parent.onEditing(true) }
        @objc func changed(_ slider: UISlider) {
            // VoiceOver changes don't send touchDown/touchUp.
            if !tracking { parent.onEditing(true) }
            parent.value = Double(slider.value)
            if !tracking { parent.onEditing(false) }
        }
        @objc func ended() { tracking = false; parent.onEditing(false) }
    }
}

struct AthosPodcastAirPlay: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let view = AVRoutePickerView(frame: .zero)
        view.tintColor = UIColor.white.withAlphaComponent(0.65)
        view.activeTintColor = .white
        return view
    }
    func updateUIView(_ view: AVRoutePickerView, context: Context) {}
}

// MARK: - Παλέτα

enum AthosPalette {
    // Share the surrounding app's appearance; artwork retains its own colours.
    static let background = Paper.bg
    static let elevated = Paper.card
    static let panel = Color.adaptive(Color(red: 0.92, green: 0.91, blue: 0.89),
                                      Color(red: 0.12, green: 0.14, blue: 0.17))
    static let ink = Paper.ink
    static let hairline = Paper.hairline
    static let secondaryText = Paper.inkSoft
    static let tertiaryText = Paper.inkMute
    static let gold = Gild.goldBright
    static let goldDeep = Paper.gold
    static let onAccent = Color.adaptive(.white, Color(red: 0.16, green: 0.08, blue: 0.10))

}

// MARK: - Native Liquid Glass

extension View {
    /// Τὸ γνήσιο γυαλὶ τοῦ iOS 26. Σὲ iOS 18 πέφτει σὲ διακριτικὸ ὑλικό.
    /// Δὲν μπαίνει ποτὲ ἀδιαφανὲς χρῶμα ἀπὸ κάτω: αὐτὸ ἀκύρωνε τὸ φαινόμενο.
    @ViewBuilder
    func athosGlass<S: Shape>(in shape: S, interactive: Bool = true) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(interactive ? .regular.interactive() : .regular, in: shape)
        } else {
            self
                .background(.ultraThinMaterial, in: shape)
                .overlay(shape.stroke(Color.white.opacity(0.16), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.30), radius: 10, y: 4)
        }
    }

    /// Ἡ ἁπαλὴ ἄκρη τοῦ iOS 26 στὴν κορυφὴ τοῦ scroll. Αὐτὴ ἀντικαθιστᾶ κάθε
    /// χειροποίητο πέπλο κάτω ἀπὸ τὴ γραμμὴ κατάστασης.
    @ViewBuilder
    func athosSoftTopEdge() -> some View {
        if #available(iOS 26.0, *) {
            self.scrollEdgeEffectStyle(.soft, for: .top)
        } else {
            self
        }
    }
}

/// Ὁμάδα γυαλιοῦ: στὸ iOS 26 τὰ γειτονικὰ σχήματα λιώνουν μεταξύ τους ὅπως
/// στὸ Apple Podcasts. Στὶς παλιότερες ἐκδόσεις εἶναι ἁπλὸ πέρασμα.
struct AthosGlassGroup<Content: View>: View {
    var spacing: CGFloat = 18
    @ViewBuilder var content: Content

    var body: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) {
                content
            }
        } else {
            content
        }
    }
}

/// Στρογγυλὸ γυάλινο κουμπί. Ἡ περιοχὴ ἀφῆς ταυτίζεται μὲ τὸν κύκλο.
struct AthosGlassIconButton: View {
    let symbol: String
    var size: CGFloat = 46
    var tint: Color = AthosPalette.ink
    var accessibility: String = "Ενέργεια"
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size * 0.40, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: size, height: size)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .athosGlass(in: Circle())
        .accessibilityLabel(accessibility)
    }
}

// MARK: - Θολὸ βάθος

/// Τὸ χρωματιστὸ θολὸ βάθος ποὺ ἀνεβαίνει πίσω ἀπὸ τὴ γραμμὴ κατάστασης.
/// Δὲν μπαίνει μέσα στὸ scroll: μένει σταθερὸ καὶ σβήνει καθὼς κατεβαίνεις.
struct AthosBackdrop<Content: View>: View {
    var height: CGFloat = 470
    var opacity: Double = 1
    @ViewBuilder var content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .scaleEffect(1.35)
            .blur(radius: 62)
            .saturation(1.30)
            .frame(height: height)
            .frame(maxWidth: .infinity)
            .clipped()
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .black, location: 0),
                        .init(color: .black.opacity(0.82), location: 0.40),
                        .init(color: .black.opacity(0.28), location: 0.74),
                        .init(color: .clear, location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .opacity(opacity)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

// MARK: - Πλωτὴ μπάρα κορυφῆς

/// Πίσω ἀριστερά, ἐνέργειες δεξιὰ σὲ ἑνιαία γυάλινη κάψουλα.
/// Παιδὶ τοῦ ριζικοῦ ZStack, ὥστε νὰ σέβεται τὸ safe area καὶ νὰ δέχεται ἀφή.
struct AthosFloatingTopBar<Trailing: View>: View {
    let onBack: () -> Void
    @ViewBuilder var trailing: Trailing

    var body: some View {
        AthosGlassGroup(spacing: 20) {
            HStack(spacing: 12) {
                AthosGlassIconButton(
                    symbol: "chevron.left",
                    size: 46,
                    accessibility: "Πίσω",
                    action: onBack
                )

                Spacer(minLength: 0)

                trailing
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 4)
    }
}

/// Ζεῦγος ἐνεργειῶν μέσα σὲ μία γυάλινη κάψουλα (καρδιὰ καὶ τρεῖς τελεῖες).
struct AthosGlassActionCapsule<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        HStack(spacing: 0) {
            content
        }
        .athosGlass(in: Capsule())
    }
}

// MARK: - Κάψουλα ἀναπαραγωγῆς

/// Ἡ χρυσὴ κάψουλα κάθε ἐπεισοδίου. Ὅταν ἡ ἀκρόαση ἔχει ξεκινήσει, δείχνει
/// λεπτὴ μπάρα προόδου καὶ τὸν χρόνο ποὺ ἀπομένει.
struct AthosPlayPill: View {
    let symbol: String
    let label: String
    var progress: Double = 0
    var tint: Color = AthosPalette.gold

    private var showsProgress: Bool { progress > 0.01 && progress < 0.99 }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .black))

            if showsProgress {
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(tint.opacity(0.26))
                        .frame(width: 44, height: 5)
                    Capsule()
                        .fill(tint)
                        .frame(width: max(5, 44 * progress), height: 5)
                }
            }

            Text(label)
                .font(.system(size: 15, weight: .bold))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 13)
        .frame(height: 32)
        .background(tint.opacity(0.10), in: Capsule())
        .contentShape(Capsule())
    }
}

// MARK: - Περίληψη μὲ «ΠΕΡΙΣΣΟΤΕΡΑ»

/// Δύο γραμμὲς περιγραφῆς μὲ τὴ λέξη ΠΕΡΙΣΣΟΤΕΡΑ νὰ ἐπιπλέει στὸ τέλος,
/// ὅπως στὸ Apple Podcasts. Τὸ ἄγγιγμα ἀνοίγει τὸ πλῆρες κείμενο.
struct AthosSummaryText: View {
    let text: String
    var lineLimit: Int = 2
    var moreLabel: String = "ΠΕΡΙΣΣΟΤΕΡΑ"
    let onTap: () -> Void

    private var isTruncated: Bool { text.count > 96 }

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .bottomTrailing) {
                Text(text)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(AthosPalette.ink)
                    .lineSpacing(2)
                    .lineLimit(lineLimit)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if isTruncated {
                    HStack(spacing: 0) {
                        LinearGradient(
                            colors: [
                                AthosPalette.background.opacity(0),
                                AthosPalette.background
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: 44)

                        Text(moreLabel)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(AthosPalette.ink)
                            .padding(.leading, 1)
                            .padding(.trailing, 1)
                            .background(AthosPalette.background)
                    }
                    .frame(height: 21)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(text)
        .accessibilityHint("Άνοιγμα πλήρους περιγραφής")
    }
}

// MARK: - Ἐπικεφαλίδα ἑνότητας

struct AthosSectionHeading: View {
    let title: String
    var action: (() -> Void)?

    var body: some View {
        if let action {
            Button(action: action) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 23, weight: .bold))
                        .foregroundStyle(AthosPalette.ink)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(AthosPalette.secondaryText)
                }
            }
            .buttonStyle(.plain)
        } else {
            Text(title)
                .font(.system(size: 23, weight: .bold))
                .foregroundStyle(AthosPalette.ink)
        }
    }
}

struct AthosHairline: View {
    var body: some View {
        Rectangle()
            .fill(AthosPalette.hairline)
            .frame(height: 0.5)
    }
}

// MARK: - Χρόνος καὶ ἡμερομηνία

/// «14λ» ἢ «1ω 14λ».
func athosCompactDuration(_ seconds: Int) -> String {
    guard seconds > 0 else { return "" }
    let hours = seconds / 3600
    if hours > 0 {
        let remainingMinutes = max(0, (seconds % 3600) / 60)
        return remainingMinutes > 0 ? "\(hours)ω \(remainingMinutes)λ" : "\(hours)ω"
    }
    return "\(max(1, Int((Double(seconds) / 60.0).rounded())))λ"
}

/// Ὅ,τι ἀπομένει, μὲ βάση τὴν πρόοδο.
func athosRemainingDuration(_ seconds: Int, progress: Double) -> String {
    guard seconds > 0 else { return "" }
    let remaining = Double(seconds) * max(0, min(1, 1 - progress))
    let minutes = max(1, Int((remaining / 60.0).rounded()))
    if minutes >= 60 {
        let hours = minutes / 60
        let leftover = minutes % 60
        return leftover > 0 ? "\(hours)ω \(leftover)λ" : "\(hours)ω"
    }
    return "\(minutes)λ"
}

/// «24 Σεπ» ἀπὸ ISO ἡμερομηνία.
func athosShortDate(_ publishedAt: String) -> String {
    let datePart = String(publishedAt.prefix(10))
    let parser = DateFormatter()
    parser.locale = Locale(identifier: "en_US_POSIX")
    parser.dateFormat = "yyyy-MM-dd"

    guard let date = parser.date(from: datePart) else {
        return "ΕΠΕΙΣΟΔΙΟ"
    }

    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "el_GR")
    formatter.dateFormat = "d MMM"
    return formatter.string(from: date).replacingOccurrences(of: ".", with: "")
}

/// «36:18» καὶ «1:02:44» γιὰ τὸν scrubber.
func athosClock(_ seconds: Double) -> String {
    guard seconds.isFinite, seconds >= 0 else { return "0:00" }
    let total = Int(seconds)
    let hours = total / 3600
    let minutes = (total % 3600) / 60
    let secs = total % 60
    if hours > 0 {
        return String(format: "%d:%02d:%02d", hours, minutes, secs)
    }
    return String(format: "%d:%02d", minutes, secs)
}
