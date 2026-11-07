//
//  ContentModels.swift
//  Klimax
//
//  The Ladder (Κλίμαξ) content: virtues, the saints who guide each virtue, and
//  their teachings. Seeded with public-domain Fathers under Humility. Saint and
//  teaching bodies are placeholders for the reading view; the references are
//  real.
//
//  The virtues are listed in the ascending order of St John's Ladder — from the
//  first struggles toward Love at the summit (Step λ´/30). The `id` of each
//  virtue is kept stable so its saints still attach correctly; only the order of
//  the array changed.
//

import Foundation

// MARK: - Virtues (the library)

struct Virtue: Identifiable, Hashable {
    let id: Int
    let title: String      // Greek
    let subtitle: String   // English
    let icon: String       // SF Symbol
    let total: Int
    let completed: Int
    let isAvailable: Bool
}

extension Virtue {
    // The 30 rungs of the Ladder, in St John's own ascending order — the
    // exact order the Klimax corpus gives (Λόγος Α´ … Λ´). Only the first
    // is available; the rest unlock as their lessons are built.
    static let all: [Virtue] = [
        Virtue(id: 1,  title: "Ἀποταγή",             subtitle: "ΒΑΘΜΙΣ Α´",   icon: "arrow.turn.up.right",  total: 1, completed: 0, isAvailable: true),
        Virtue(id: 2,  title: "Ἀπροσπάθεια",         subtitle: "ΒΑΘΜΙΣ Β´",   icon: "wind",                  total: 0, completed: 0, isAvailable: false),
        Virtue(id: 3,  title: "Ξενιτεία",             subtitle: "ΒΑΘΜΙΣ Γ´",   icon: "map.fill",              total: 0, completed: 0, isAvailable: false),
        Virtue(id: 4,  title: "Ὑπακοή",               subtitle: "ΒΑΘΜΙΣ Δ´",   icon: "hand.raised.fill",      total: 0, completed: 0, isAvailable: false),
        Virtue(id: 5,  title: "Μετάνοια",             subtitle: "ΒΑΘΜΙΣ Ε´",   icon: "arrow.uturn.backward",  total: 0, completed: 0, isAvailable: false),
        Virtue(id: 6,  title: "Μνήμη θανάτου",        subtitle: "ΒΑΘΜΙΣ Ϛ´",   icon: "hourglass",             total: 0, completed: 0, isAvailable: false),
        Virtue(id: 7,  title: "Πένθος",               subtitle: "ΒΑΘΜΙΣ Ζ´",   icon: "cloud.rain.fill",       total: 0, completed: 0, isAvailable: false),
        Virtue(id: 8,  title: "Ἀοργησία",             subtitle: "ΒΑΘΜΙΣ Η´",   icon: "leaf.fill",             total: 0, completed: 0, isAvailable: false),
        Virtue(id: 9,  title: "Μνησικακία",           subtitle: "ΒΑΘΜΙΣ Θ´",   icon: "bandage.fill",          total: 0, completed: 0, isAvailable: false),
        Virtue(id: 10, title: "Καταλαλιά",            subtitle: "ΒΑΘΜΙΣ Ι´",   icon: "text.bubble.fill",      total: 0, completed: 0, isAvailable: false),
        Virtue(id: 11, title: "Σιωπή",                subtitle: "ΒΑΘΜΙΣ ΙΑ´",  icon: "speaker.slash.fill",    total: 0, completed: 0, isAvailable: false),
        Virtue(id: 12, title: "Ψεῦδος",               subtitle: "ΒΑΘΜΙΣ ΙΒ´",  icon: "theatermasks.fill",     total: 0, completed: 0, isAvailable: false),
        Virtue(id: 13, title: "Ἀκηδία",               subtitle: "ΒΑΘΜΙΣ ΙΓ´",  icon: "moon.zzz.fill",         total: 0, completed: 0, isAvailable: false),
        Virtue(id: 14, title: "Γαστριμαργία",         subtitle: "ΒΑΘΜΙΣ ΙΔ´",  icon: "fork.knife",            total: 0, completed: 0, isAvailable: false),
        Virtue(id: 15, title: "Ἁγνεία",               subtitle: "ΒΑΘΜΙΣ ΙΕ´",  icon: "sparkles",              total: 0, completed: 0, isAvailable: false),
        Virtue(id: 16, title: "Φιλαργυρία",           subtitle: "ΒΑΘΜΙΣ ΙϚ´",  icon: "banknote.fill",         total: 0, completed: 0, isAvailable: false),
        Virtue(id: 17, title: "Ἀκτημοσύνη",           subtitle: "ΒΑΘΜΙΣ ΙΖ´",  icon: "shippingbox.fill",      total: 0, completed: 0, isAvailable: false),
        Virtue(id: 18, title: "Ἀναισθησία",           subtitle: "ΒΑΘΜΙΣ ΙΗ´",  icon: "eye.slash.fill",        total: 0, completed: 0, isAvailable: false),
        Virtue(id: 19, title: "Ὕπνος καὶ προσευχή",   subtitle: "ΒΑΘΜΙΣ ΙΘ´",  icon: "moon.stars.fill",       total: 0, completed: 0, isAvailable: false),
        Virtue(id: 20, title: "Ἀγρυπνία",             subtitle: "ΒΑΘΜΙΣ Κ´",   icon: "eye.fill",              total: 0, completed: 0, isAvailable: false),
        Virtue(id: 21, title: "Δειλία",               subtitle: "ΒΑΘΜΙΣ ΚΑ´",  icon: "figure.walk",           total: 0, completed: 0, isAvailable: false),
        Virtue(id: 22, title: "Κενοδοξία",            subtitle: "ΒΑΘΜΙΣ ΚΒ´",  icon: "megaphone.fill",        total: 0, completed: 0, isAvailable: false),
        Virtue(id: 23, title: "Ὑπερηφανία",           subtitle: "ΒΑΘΜΙΣ ΚΓ´",  icon: "crown.fill",            total: 0, completed: 0, isAvailable: false),
        Virtue(id: 24, title: "Ἀκακία",               subtitle: "ΒΑΘΜΙΣ ΚΔ´",  icon: "hands.sparkles.fill",   total: 0, completed: 0, isAvailable: false),
        Virtue(id: 25, title: "Ταπεινοφροσύνη",       subtitle: "ΒΑΘΜΙΣ ΚΕ´",  icon: "leaf.fill",             total: 0, completed: 0, isAvailable: false),
        Virtue(id: 26, title: "Διάκρισις",            subtitle: "ΒΑΘΜΙΣ ΚϚ´",  icon: "scope",                 total: 0, completed: 0, isAvailable: false),
        Virtue(id: 27, title: "Ἡσυχία",               subtitle: "ΒΑΘΜΙΣ ΚΖ´",  icon: "moon.fill",             total: 0, completed: 0, isAvailable: false),
        Virtue(id: 28, title: "Προσευχή",             subtitle: "ΒΑΘΜΙΣ ΚΗ´",  icon: "flame.fill",            total: 0, completed: 0, isAvailable: false),
        Virtue(id: 29, title: "Ἀπάθεια",              subtitle: "ΒΑΘΜΙΣ ΚΘ´",  icon: "shield.fill",           total: 0, completed: 0, isAvailable: false),
        Virtue(id: 30, title: "Ἀγάπη",                subtitle: "ΒΑΘΜΙΣ Λ´",   icon: "heart.fill",            total: 0, completed: 0, isAvailable: false)
    ]
}

// MARK: - Saints & teachings

struct Teaching: Identifiable, Hashable {
    let id: Int
    let title: String      // Greek
    let subtitle: String   // short English label
    let source: String     // the work it is drawn from
    let body: String       // placeholder reading text (synthesised in our own words)
}

struct Saint: Identifiable, Hashable {
    let id: Int
    let name: String       // Greek
    let epithet: String    // English descriptor
    let teachings: [Teaching]
}

/// A navigation value pairing a saint with one of their teachings.
struct TeachingRoute: Hashable {
    let saint: Saint
    let teaching: Teaching
}

extension Saint {
    static func all(for virtue: Virtue) -> [Saint] {
        switch virtue.id {
        case 25: return humility   // Ταπεινοφροσύνη
        default: return []
        }
    }

    static let humility: [Saint] = [
        Saint(id: 1, name: "Ἀββᾶς Δωρόθεος", epithet: "On humility, from the Discourses", teachings: [
            Teaching(id: 1, title: "Τὸ θεμέλιον", subtitle: "THE FOUNDATION", source: "Discourses on the Spiritual Life",
                     body: "Abba Dorotheos teaches that humility is the ground beneath every other virtue; without it, what we build cannot stand."),
            Teaching(id: 2, title: "Ἡ ὁδός", subtitle: "THE ROAD DOWN", source: "Discourses on the Spiritual Life",
                     body: "He describes how the soul descends, not by self-contempt, but by quietly preferring others and refusing to weigh its own worth.")
        ]),
        Saint(id: 2, name: "Ἰωάννης ὁ Σιναΐτης", epithet: "Author of the Ladder", teachings: [
            Teaching(id: 1, title: "Ὁ ἀναβαθμός", subtitle: "THE STEP", source: "The Ladder of Divine Ascent, Step 25",
                     body: "St John of the Ladder places humility as a step that cannot be described, only recognised by those who have begun to climb it.")
        ]),
        Saint(id: 3, name: "Ἰσαὰκ ὁ Σύρος", epithet: "Of the Ascetical Homilies", teachings: [
            Teaching(id: 1, title: "Ἡ ταπεινὴ καρδία", subtitle: "THE LOWLY HEART", source: "Ascetical Homilies",
                     body: "St Isaac the Syrian writes that a humble heart is granted a peace the proud cannot purchase by any labour.")
        ]),
        Saint(id: 4, name: "Ἀββᾶς Ποιμήν", epithet: "From the Sayings of the Desert Fathers", teachings: [
            Teaching(id: 1, title: "Ὁ λόγος", subtitle: "A SAYING", source: "Apophthegmata Patrum",
                     body: "Abba Poemen counsels the brother to keep his own faults before his eyes, and to leave the faults of others to God.")
        ]),
        Saint(id: 5, name: "Ἀντώνιος ὁ Μέγας", epithet: "Father of monks", teachings: [
            Teaching(id: 1, title: "Αἱ παγίδες", subtitle: "THE SNARES", source: "Apophthegmata Patrum",
                     body: "St Antony saw all the snares of the enemy spread over the earth, and asked who could pass them; the answer he heard was: humility.")
        ])
    ]
}
