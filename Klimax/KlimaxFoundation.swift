//
//  KlimaxFoundation.swift
//  Klimax
//
//  Νέα βάση σχεδιασμού (design foundation) για τον ανασχεδιασμό.
//
//  ΠΡΟΣΘΕΤΙΚΟ αρχείο: δεν αλλάζει ΤΙΠΟΤΑ από τα υπάρχοντα. Το `Paper` και το
//  `Gild` μένουν ακριβώς ως έχουν· εδώ απλώς προστίθενται καινούργια ονόματα
//  (KType, KSpace, KMotion, glassChrome, readingSurface, AscentDots). Οι οθόνες
//  θα περάσουν σταδιακά πάνω σε αυτά, μία-μία. Μπορείς να το ρίξεις στο project
//  με ασφάλεια: δεν μπορεί να χαλάσει το build.
//
//  Οδηγία: σύρε το αρχείο μέσα στον φάκελο Klimax στο Xcode, μετά Product →
//  Clean Build Folder (⇧⌘K) και τρέξε.
//

import SwiftUI

// MARK: - Τυπογραφία  (Didot για display, ανάγνωσιμο serif για body)

enum KType {
    // Το όνομα PostScript της GFS Didot, όπως έρχεται από το .otf. Αν η
    // γραμματοσειρά δεν είναι ακόμη προστεθειμένη στο project, ο κώδικας
    // παραμένει έγκυρος· πέφτει απλώς πίσω στο system serif κατά το runtime.
    private static let didot = "GFSDidot"

    /// Μεγάλος λειτουργικός τίτλος (π.χ. «Κλῖμαξ», όνομα ἁγίου). Με φειδώ.
    static func display(_ size: CGFloat = 34) -> Font {
        .custom(didot, size: size)
    }

    /// Body ανάγνωσης πολυτονικού. System serif (New York): γερό, καθαρό, με
    /// πλήρη υποστήριξη πολυτονικού. (Εναλλακτικά, bundled GFS Neohellenic.)
    static func body(_ size: CGFloat = 19) -> Font {
        .system(size: size, weight: .regular, design: .serif)
    }

    static func title(_ size: CGFloat = 22) -> Font {
        .system(size: size, weight: .regular, design: .serif)
    }

    static func caption(_ size: CGFloat = 13) -> Font {
        .system(size: size, weight: .regular, design: .default)
    }

    /// Μικρές «tracked» ετικέτες (π.χ. Ἦχος α΄, λεζάντες κεφαλαίων).
    static func label(_ size: CGFloat = 11) -> Font {
        .system(size: size, weight: .semibold, design: .default)
    }
}

// MARK: - Κενά  (κλίμακα 4pt, γενναιόδωρη «αναπνοή»)

enum KSpace {
    static let xxs: CGFloat = 4
    static let xs:  CGFloat = 8
    static let sm:  CGFloat = 12
    static let md:  CGFloat = 16
    static let lg:  CGFloat = 24
    static let xl:  CGFloat = 32
    static let xxl: CGFloat = 44

    /// Πλάγιο περιθώριο σελίδας — μία πηγή αλήθειας για όλες τις οθόνες.
    static let gutter: CGFloat = 22

    /// Άνετο line spacing για ανάγνωση πολυτονικού.
    static let readingLineSpacing: CGFloat = 9
}

// MARK: - Κίνηση  (ήρεμη, «σκόπιμη», όχι διακόσμηση)

enum KMotion {
    static let press   = Animation.spring(response: 0.30, dampingFraction: 0.72)
    static let settle  = Animation.spring(response: 0.45, dampingFraction: 0.82)
    static let breathe = Animation.easeInOut(duration: 2.6)
}

// MARK: - Chrome: το glass ΜΟΝΟ εδώ (ποτέ κάτω από κείμενο)

extension View {
    /// Πλωτό control (π.χ. ρυθμιστής μεγέθους ανάγνωσης, κουμπί) με Liquid
    /// Glass στο iOS 26 και ήσυχο material fallback πριν από αυτό.
    @ViewBuilder
    func glassChrome<S: Shape>(in shape: S = Capsule()) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular.interactive(), in: shape)
        } else {
            self
                .background(.ultraThinMaterial, in: shape)
                .overlay(shape.stroke(.white.opacity(0.20), lineWidth: 0.5))
        }
    }
}

// MARK: - Επιφάνεια ανάγνωσης: πάντα ΣΥΜΠΑΓΕΣ «χαρτί» κάτω από το κείμενο

private struct ReadingSurface: ViewModifier {
    func body(content: Content) -> some View {
        content
            .lineSpacing(KSpace.readingLineSpacing)
            .foregroundStyle(Paper.ink)
            .padding(.horizontal, KSpace.gutter)
            .background(Paper.card)   // συμπαγές, όχι glass
    }
}

extension View {
    /// Τυλίγει ένα κείμενο ανάγνωσης στη «χάρτινη» επιφάνεια με σωστό
    /// line spacing και περιθώρια. Το glass δεν πλησιάζει ποτέ εδώ.
    func readingSurface() -> some View { modifier(ReadingSurface()) }
}

// MARK: - «Ἀνάβαση»: λιτή ένδειξη προόδου (αντικαθιστά νοηματικά το XP-bar)

struct AscentDots: View {
    let total: Int
    let reached: Int

    var body: some View {
        HStack(spacing: KSpace.xs) {
            ForEach(0..<max(total, 1), id: \.self) { i in
                Circle()
                    .fill(i < reached ? Gild.gold : Paper.ink.opacity(0.12))
                    .frame(width: 7, height: 7)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Ανάβαση \(reached) από \(total)")
    }
}
