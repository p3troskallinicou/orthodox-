//
//  GildTheme.swift
//  Klimax
//
//  The application accent palette, plus a few shared spring animations.
//  The legacy property names remain so the accent can be trialled/reverted
//  from this single file without touching every screen.
//

import SwiftUI

enum Gild {
    /// Keep the accent in the oxblood family in both appearances; lifting the
    /// green/blue channels into a pastel made the dark palette read as pink.
    static let gold = Color.adaptive(
        Color(red: 63.0 / 255.0, green: 1.0 / 255.0, blue: 18.0 / 255.0),
        Color(red: 166.0 / 255.0, green: 56.0 / 255.0, blue: 64.0 / 255.0)
    )
    static let goldBright = Color.adaptive(
        Color(red: 0.39, green: 0.055, blue: 0.15),
        Color(red: 190.0 / 255.0, green: 68.0 / 255.0, blue: 69.0 / 255.0)
    )
    static let goldRing = Color.adaptive(
        Color(red: 0.145, green: 0.0, blue: 0.045),
        Color(red: 132.0 / 255.0, green: 37.0 / 255.0, blue: 48.0 / 255.0)
    )
    /// Small text on dark surfaces needs contrast independently of brand fills.
    static let accentForeground = Color.adaptive(
        Color(red: 63.0 / 255.0, green: 1.0 / 255.0, blue: 18.0 / 255.0),
        Color(red: 0.953, green: 0.925, blue: 0.855)
    )
    static let onGold = Color(red: 0.985, green: 0.965, blue: 0.950)
    static let parchment   = Color(red: 0.953, green: 0.925, blue: 0.855)
    static let glassStroke = Color.white.opacity(0.18)
    static let night       = Color(red: 0.071, green: 0.082, blue: 0.110)
    static let lockedFill  = Color.white.opacity(0.06)
    static let lockedRing  = Color.white.opacity(0.12)
    static let lockedIcon  = Color.white.opacity(0.35)
    static let patronFill  = Color(red: 0.170, green: 0.025, blue: 0.070)
}

enum GildMotion {
    static let press   = Animation.spring(response: 0.30, dampingFraction: 0.70)
    static let settle  = Animation.spring(response: 0.45, dampingFraction: 0.82)
    static let breathe = Animation.easeInOut(duration: 2.4)
}
