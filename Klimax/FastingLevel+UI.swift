//
//  FastingLevel+UI.swift  ·  Klimax
//
//  Κοινὴ παρουσίαση τῶν ἐπιπέδων νηστείας (χρώματα, εἰκονίδια, κείμενα),
//  ὥστε ἡ κάρτα «Σήμερα» καὶ τὸ Νηστειοδρόμιο νὰ μιλοῦν τὴν ἴδια γλῶσσα.
//
//  ΑΠΑΙΤΕΙ: FastingCalendar.swift (γιὰ τὸ enum FastingLevel).
//

import SwiftUI

extension FastingLevel {

    /// Quiet semantic colours for the widget's diagonal highlight.
    var widgetTint: Color {
        switch self {
        case .free: Color(red: 0.20, green: 0.57, blue: 0.36)
        case .noMeat: Color(red: 0.57, green: 0.61, blue: 0.30)
        case .fish: Color(red: 0.22, green: 0.49, blue: 0.73)
        case .oilWine: Color(red: 0.70, green: 0.49, blue: 0.23)
        case .xerophagy: Color(red: 0.49, green: 0.32, blue: 0.25)
        }
    }

    /// Εἰκονίδιο SF Symbols.
    var cardIcon: String {
        switch self {
        case .free:      return "fork.knife"
        case .noMeat:    return "carrot"
        case .fish:      return "fish"
        case .oilWine:   return "wineglass"
        case .xerophagy: return "leaf"
        }
    }

    /// Κύριο χρῶμα (φασματικὴ αὐστηρότητα· φασκόμηλο = ἐλεύθερη ἡμέρα).
    var cardTint: Color {
        switch self {
        case .free:      return Color(red: 0.431, green: 0.482, blue: 0.322)
        case .noMeat:    return Color(red: 0.804, green: 0.690, blue: 0.408)
        case .fish:      return Color(red: 0.776, green: 0.631, blue: 0.357)
        case .oilWine:   return Color(red: 0.753, green: 0.541, blue: 0.235)
        case .xerophagy: return Color(red: 0.620, green: 0.494, blue: 0.200)
        }
    }

    /// Βαθὺ χρῶμα (γιὰ βαθμίδες).
    var cardTintDeep: Color {
        switch self {
        case .free:      return Color(red: 0.333, green: 0.376, blue: 0.247)
        case .noMeat:    return Color(red: 0.663, green: 0.518, blue: 0.227)
        case .fish:      return Color(red: 0.620, green: 0.494, blue: 0.200)
        case .oilWine:   return Color(red: 0.604, green: 0.416, blue: 0.133)
        case .xerophagy: return Color(red: 0.435, green: 0.341, blue: 0.133)
        }
    }

    /// Πλῆρες ὄνομα (τίτλος serif).
    var cardTitle: String {
        switch self {
        case .free:      return "Κατάλυσις εις πάντα"
        case .noMeat:    return "Κατάλυσις πλήν κρέατος"
        case .fish:      return "Κατάλυσις ιχθύος"
        case .oilWine:   return "Έλαιον και οίνος"
        case .xerophagy: return "Ξηροφαγία"
        }
    }

    /// Σύντομο ὄνομα (γιὰ ὑπόμνημα).
    var shortName: String {
        switch self {
        case .free:      return "Κατάλυσις"
        case .noMeat:    return "Πλήν κρέατος"
        case .fish:      return "Ιχθύς"
        case .oilWine:   return "Έλαιον/οίνος"
        case .xerophagy: return "Ξηροφαγία"
        }
    }

    /// Μία γραμμὴ καθοδήγησης.
    var cardGuidance: String {
        switch self {
        case .free:      return "Επιτρέπονται όλες οι τροφές."
        case .noMeat:    return "Επιτρέπονται γαλακτοκομικά, αυγά και ιχθύς· όχι κρέας."
        case .fish:      return "Επιτρέπονται ιχθύς, έλαιον και οίνος."
        case .oilWine:   return "Επιτρέπονται έλαιον και οίνος· όχι ιχθύς."
        case .xerophagy: return "Αυστηρά νηστεία, χωρίς έλαιον και οίνο."
        }
    }
}
