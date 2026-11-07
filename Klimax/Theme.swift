//
//  Theme.swift
//  Klimax
//
//  Ἡ παλέτα εἶναι τώρα «προσαρμοζόμενη»: κάθε χρῶμα ξέρει καὶ τὴν ἀνοιχτή του
//  ἐκδοχὴ (light mode, τὸ γνωστὸ «χαρτί») καὶ τὴ σκοτεινή του (dark mode,
//  «νύχτα»). Τὸ iOS διαλέγει ἀνάλογα μὲ τὴ ρύθμιση τοῦ τηλεφώνου, ὥστε ὅλη
//  ἡ ἐφαρμογὴ νὰ γίνεται μόνη της ἀνοιχτὴ τὴ μέρα καὶ σκοτεινὴ τὸ βράδυ.
//  Κάθε ὀθόνη ποὺ χρησιμοποιεῖ τὴν Paper προσαρμόζεται αὐτόματα.
//

import SwiftUI
import UIKit

extension String {
    private static let interfaceGreekWords = try? NSRegularExpression(pattern: "[\\p{Greek}\\p{M}]+")
    /// Display-only spelling for interface/catalogue labels. Never apply to a
    /// scripture verse, prayer body, quotation, stored identifier or user entry.
    var interfaceGreek: String {
        let unaccented: Set<String> = [
            "το", "του", "τον", "την", "τα", "των", "τους", "τις", "της", "τω", "τη",
            "και", "να", "θα", "με", "σε", "για", "στο", "στον", "στη", "στην", "στις",
            "στα", "στους", "στων", "δε", "δεν", "μη", "μην", "αν", "ως", "πριν",
            "μου", "σου", "μας", "σας", "τι", "απ", "εκ", "εν"
        ]
        return Self.monotonicInterfaceText(self, unaccented: unaccented)
    }

    private static func monotonicInterfaceText(_ text: String, unaccented: Set<String>) -> String {
        guard let words = interfaceGreekWords else { return text }
        var result = text
        for match in words.matches(in: text, range: NSRange(text.startIndex..., in: text)).reversed() {
            guard let range = Range(match.range, in: result) else { continue }
            let original = String(result[range])
            var scalars = original.decomposedStringWithCanonicalMapping.unicodeScalars.compactMap { scalar -> Unicode.Scalar? in
                switch scalar.value {
                case 0x0313, 0x0314, 0x0345: return nil
                case 0x0300, 0x0342: return Unicode.Scalar(0x0301)
                default: return scalar
                }
            }
            let plain = String(String.UnicodeScalarView(scalars.filter { $0.value != 0x0301 }))
                .precomposedStringWithCanonicalMapping.lowercased()
            if unaccented.contains(plain) || original.lowercased() == "ποὺ" || original.lowercased() == "πὼς"
                || (original.count > 1 && original == original.uppercased()) {
                scalars.removeAll { $0.value == 0x0301 }
            }
            result.replaceSubrange(range, with: String(String.UnicodeScalarView(scalars)).precomposedStringWithCanonicalMapping)
        }
        return result
    }
}

extension Color {
    /// Ἕνα χρῶμα μὲ δύο ἐκδοχές: light καὶ dark. Τὸ σύστημα διαλέγει μόνο του.
    static func adaptive(_ light: Color, _ dark: Color) -> Color {
        Color(uiColor: UIColor { traits in
            UIColor(traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

enum Paper {
    // Ἀνοιχτὴ ἐκδοχή = τὸ σημερινὸ «χαρτί». Σκοτεινὴ = «νύχτα».
    static let bg = Color.adaptive(
        Color(red: 0.969, green: 0.949, blue: 0.910),
        Color(red: 0.071, green: 0.082, blue: 0.110))

    static let card = Color.adaptive(
        Color(red: 1.000, green: 0.996, blue: 0.985),
        Color(red: 0.106, green: 0.122, blue: 0.157))

    static let ink = Color.adaptive(
        Color(red: 0.157, green: 0.129, blue: 0.090),
        Color(red: 0.953, green: 0.925, blue: 0.855))

    static let inkSoft = Color.adaptive(
        Color(red: 0.376, green: 0.333, blue: 0.255),
        Color(red: 0.953, green: 0.925, blue: 0.855).opacity(0.78))

    static let inkMute = Color.adaptive(
        Color(red: 0.557, green: 0.514, blue: 0.435),
        Color(red: 0.953, green: 0.925, blue: 0.855).opacity(0.55))

    static let hairline = Color.adaptive(
        Color(red: 0.157, green: 0.129, blue: 0.090).opacity(0.08),
        Color.white.opacity(0.12))

    static let gold = Gild.gold

    // Κλειδωμένα σκαλιά, ὁρατὰ καθαρὰ καὶ στὶς δύο διαθέσεις.
    static let lockedFill = Color.adaptive(
        Color(red: 0.157, green: 0.129, blue: 0.090).opacity(0.05),
        Color.white.opacity(0.06))

    static let lockedRing = Color.adaptive(
        Color(red: 0.157, green: 0.129, blue: 0.090).opacity(0.12),
        Color.white.opacity(0.12))

    static let lockedIcon = Color.adaptive(
        Color(red: 0.157, green: 0.129, blue: 0.090).opacity(0.35),
        Color.white.opacity(0.35))
}

/// A gentle press-scale for tappable cards.
struct CalmCardStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(response: 0.30, dampingFraction: 0.70), value: configuration.isPressed)
    }
}

/// A thin gold progress bar on a faint track.
struct ProgressBar: View {
    let fraction: Double
    var tint: Color = Paper.gold

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Paper.ink.opacity(0.08))
                Capsule().fill(tint)
                    .frame(width: geo.size.width * max(0, min(1, fraction)))
            }
        }
    }
}

/// The app's compact "liquid glass" treatment, with a quiet material fallback
/// for systems before the native glass effect became available.
extension View {
    @ViewBuilder
    func glassCircleFallback<S: Shape>(shape: S, interactive: Bool = true) -> some View {
        if #available(iOS 26.0, *) {
            if interactive {
                self.glassEffect(.regular.interactive(), in: shape)
            } else {
                self.glassEffect(.regular, in: shape)
            }
        } else {
            self
                .background(.ultraThinMaterial, in: shape)
                .overlay(shape.stroke(.white.opacity(0.25), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
        }
    }

    @ViewBuilder
    func klimaxLiquidGlass<S: InsettableShape>(
        in shape: S,
        selected: Bool = false,
        interactive: Bool = true
    ) -> some View {
        let blueWash = LinearGradient(
            colors: [
                Color.adaptive(
                    Color(red: 0.82, green: 0.91, blue: 1.0).opacity(selected ? 0.34 : 0.24),
                    Color(red: 0.12, green: 0.19, blue: 0.29).opacity(selected ? 0.40 : 0.28)
                ),
                Color.adaptive(
                    .white.opacity(selected ? 0.08 : 0.045),
                    Color(red: 0.04, green: 0.10, blue: 0.18).opacity(selected ? 0.22 : 0.16)
                ),
                Color.adaptive(
                    Color(red: 0.58, green: 0.77, blue: 1.0).opacity(selected ? 0.18 : 0.12),
                    Color(red: 0.04, green: 0.13, blue: 0.24).opacity(selected ? 0.34 : 0.24)
                )
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        let shine = LinearGradient(
            colors: [
                Color.adaptive(.white.opacity(0.28), Color(red: 0.30, green: 0.48, blue: 0.76).opacity(0.075)),
                Color.adaptive(.white.opacity(0.06), Color(red: 0.08, green: 0.18, blue: 0.32).opacity(0.06)),
                .clear
            ],
            startPoint: .topLeading,
            endPoint: .center
        )

        let stroke = LinearGradient(
            colors: [
                Color.adaptive(
                    .white.opacity(selected ? 0.72 : 0.50),
                    Color(red: 0.48, green: 0.61, blue: 0.80).opacity(selected ? 0.34 : 0.22)
                ),
                Color.adaptive(
                    Color(red: 0.56, green: 0.76, blue: 1.0).opacity(selected ? 0.42 : 0.26),
                    Color(red: 0.22, green: 0.35, blue: 0.56).opacity(selected ? 0.22 : 0.14)
                ),
                Color.adaptive(
                    .white.opacity(0.03),
                    Color(red: 0.07, green: 0.14, blue: 0.25).opacity(0.18)
                )
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        if #available(iOS 26.0, *) {
            if interactive {
                self
                    .glassEffect(.regular.interactive(), in: shape)
                    .background(shape.fill(blueWash))
                    .overlay(shape.fill(shine).blendMode(.plusLighter).allowsHitTesting(false))
                    .overlay(shape.strokeBorder(stroke, lineWidth: selected ? 0.85 : 0.55).allowsHitTesting(false))
                    .shadow(color: Color.adaptive(.black.opacity(0.035), .clear), radius: 8, x: 0, y: 4)
            } else {
                self
                    .glassEffect(.regular, in: shape)
                    .background(shape.fill(blueWash))
                    .overlay(shape.fill(shine).blendMode(.plusLighter).allowsHitTesting(false))
                    .overlay(shape.strokeBorder(stroke, lineWidth: selected ? 0.85 : 0.55).allowsHitTesting(false))
                    .shadow(color: Color.adaptive(.black.opacity(0.025), .clear), radius: 6, x: 0, y: 3)
            }
        } else {
            self
                .background(.ultraThinMaterial, in: shape)
                .background(shape.fill(blueWash))
                .overlay(shape.fill(shine).blendMode(.plusLighter).allowsHitTesting(false))
                .overlay(shape.strokeBorder(stroke, lineWidth: selected ? 0.85 : 0.55).allowsHitTesting(false))
                .shadow(color: Color.adaptive(.black.opacity(0.035), .clear), radius: 8, x: 0, y: 4)
        }
    }
}

/// A time-aware greeting reused by the home and Today screens.
func klimaxGreeting(date: Date = Date()) -> String {
    switch Calendar.current.component(.hour, from: date) {
    case 5..<12:  return "Good morning"
    case 12..<17: return "Good afternoon"
    case 17..<22: return "Good evening"
    default:      return "Peace be with you"
    }
}
