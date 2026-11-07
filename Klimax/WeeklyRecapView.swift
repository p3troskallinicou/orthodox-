//
//  WeeklyRecapView.swift
//  Klimax
//
//  Ο εβδομαδιαιος απολογισμος της καρτελας Εσυ, σε ασυμμετρο bento.
//  Καθε συγκριση ειναι με τον παλιοτερο εαυτο, ποτε με αλλους.
//
//  ΠΡΟΣΘΕΤΙΚΟ αρχειο. Συρε το μεσα στον φακελο Klimax στο Xcode, μετα
//  Product, Clean Build Folder, και τρεξε. Μπαινει ως ενοτητα μεσα στην
//  ProfileView (δες την αλλαγη στο ProfileView.swift).
//

import SwiftUI

// Ενας διακοπτης. true = liquid glass καρτες (οπως το ενεκρινες).
// false = συμπαγες Paper.card, συνεπες με την υπολοιπη εφαρμογη και με τον
// κανονα του KlimaxFoundation (glass μονο για chrome, οχι κατω απο κειμενο).
private let useLiquidGlass = true

// MARK: Μοντελο μετρησης

private struct RecapMetric: Identifiable {
    let id = UUID()
    let label: String
    let value: Int
    let previousWeekValue: Int
    let detail: String

    var displayValue: String { "\(value)" }
    var trend: RecapTrend { RecapTrend(current: value, previous: previousWeekValue) }
}

private enum RecapTrend {
    case up
    case down
    case flat

    init(current: Int, previous: Int) {
        if current > previous {
            self = .up
        } else if current < previous {
            self = .down
        } else {
            self = .flat
        }
    }

    var glowColor: Color? {
        switch self {
        case .up:
            Color(red: 0.12, green: 0.78, blue: 0.43)
        case .down:
            Color(red: 0.96, green: 0.20, blue: 0.24)
        case .flat:
            nil
        }
    }

    var icon: String? {
        switch self {
        case .up: "arrow.up.right"
        case .down: "arrow.down.right"
        case .flat: nil
        }
    }
}

// MARK: Επιφανεια καρτας (γυαλι η χαρτι, με διακοπτη)

private struct RecapCard: ViewModifier {
    var cornerRadius: CGFloat = 20
    var trend: RecapTrend = .flat

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if useLiquidGlass {
            ZStack(alignment: .bottom) {
                if let color = trend.glowColor {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.42), color.opacity(0.12), .clear],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .frame(height: 28)
                        .offset(y: 10)
                        .padding(.horizontal, 18)
                }

                content
                    .background(
                        shape.fill(
                            LinearGradient(
                                colors: [
                                    Color.adaptive(
                                        Color(red: 0.82, green: 0.91, blue: 1.0).opacity(0.34),
                                        Color(red: 0.22, green: 0.35, blue: 0.54).opacity(0.16)
                                    ),
                                    .white.opacity(0.08),
                                    Color.adaptive(
                                        Color(red: 0.58, green: 0.77, blue: 1.0).opacity(0.18),
                                        Color(red: 0.14, green: 0.22, blue: 0.34).opacity(0.20)
                                    )
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    )
                    .overlay(
                        shape.strokeBorder(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.72),
                                    Color.adaptive(
                                        Color(red: 0.56, green: 0.76, blue: 1.0).opacity(0.36),
                                        .white.opacity(0.10)
                                    ),
                                    .white.opacity(0.04)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.9
                        )
                    )
            }
        } else {
            content
                .background(Paper.card, in: shape)
                .overlay(shape.stroke(Paper.hairline, lineWidth: 1))
        }
    }
}

private extension View {
    func recapCard(cornerRadius: CGFloat = 20, trend: RecapTrend = .flat) -> some View {
        modifier(RecapCard(cornerRadius: cornerRadius, trend: trend))
    }
}

// MARK: Κοινα κομματια

private struct TileLabel: View {
    let text: String
    var reserveTwoLines: Bool = true
    var trend: RecapTrend = .flat

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(text)
                .font(KType.label(12))
                .foregroundStyle(Paper.inkMute)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(minHeight: reserveTwoLines ? 32 : 0, alignment: .topLeading)
            Spacer(minLength: 0)
            Image(systemName: trend.icon ?? "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(trend.glowColor ?? Paper.inkMute)
        }
    }
}

private struct BigNumber: View {
    let value: String
    var size: CGFloat = 40
    var body: some View {
        Text(value)
            .font(.system(size: size, weight: .heavy))
            .foregroundStyle(Paper.ink)
    }
}

private struct TileDetail: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Paper.inkMute)
            .lineSpacing(2)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: Καρτες

private struct StatTile: View {
    let metric: RecapMetric
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TileLabel(text: metric.label, trend: metric.trend)
            BigNumber(value: metric.displayValue).padding(.top, 6)
            TileDetail(text: metric.detail).padding(.top, 11)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .recapCard(trend: metric.trend)
    }
}

private struct HeroTile: View {
    let value: Int
    let previousWeekValue: Int
    let delta: String

    private var trend: RecapTrend {
        RecapTrend(current: value, previous: previousWeekValue)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TileLabel(text: "Ημέρες παρών", reserveTwoLines: false, trend: trend)
            Spacer(minLength: 8)
            BigNumber(value: "\(value)", size: 88)
            Spacer(minLength: 8)
            HStack(spacing: 4) {
                Image(systemName: trend.icon ?? "minus").font(.system(size: 12, weight: .semibold))
                Text(delta).font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(trend.glowColor ?? Gild.gold)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .recapCard(trend: trend)
    }
}

private struct RungTile: View {
    let numeral: String
    let name: String
    let reached: Int
    let previousWeekReached: Int
    let total: Int

    private var trend: RecapTrend {
        RecapTrend(current: reached, previous: previousWeekReached)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TileLabel(text: "Πού βρίσκεσαι", reserveTwoLines: false, trend: trend)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(numeral)
                    .font(.system(size: 38, weight: .heavy))
                    .foregroundStyle(Paper.ink)
                Text(name)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Paper.ink)
            }
            .padding(.top, 6)
            HStack(spacing: 8) {
                ProgressBar(fraction: Double(reached) / Double(max(total, 1)))
                    .frame(height: 3)
                Text("\(reached) / \(total)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Paper.inkMute)
            }
            .padding(.top, 12)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .recapCard(trend: trend)
    }
}

// MARK: Η ενοτητα

struct WeeklyRecapView: View {
    // Δειγματικα δεδομενα. Δεσε τα με τα υπαρχοντα stores:
    //   Ημέρες παρών  -> PlayerProgressStore.shared.currentStreak
    //   Μαθήματα      -> πληθος ολοκληρωμενων στο save.lessonRecords
    //   Σκαλί/Αρετές  -> LadderView / Virtue προοδος
    //   Ρητά, Χωρία   -> μετρητες Γεροντικου και Γραφης της εβδομαδας
    private let rita  = RecapMetric(label: "Ρητά του Γεροντικού", value: 12, previousWeekValue: 9, detail: "Αντώνιος, Αρσένιος")
    private let mathimata = RecapMetric(label: "Μαθήματα",        value: 8,  previousWeekValue: 8, detail: "Ενότητα Α'")
    private let aretes = RecapMetric(label: "Αρετές",             value: 3,  previousWeekValue: 4, detail: "Αποταγή, Αμεριμνία, Ξενιτεία")
    private let choria = RecapMetric(label: "Χωρία Γραφής",       value: 9,  previousWeekValue: 6, detail: "Ψαλμοί, Ματθαίος")
    private let prosefches = RecapMetric(label: "Προσευχές",      value: 5,  previousWeekValue: 7, detail: "Προοιμιακή, Ακάθιστος")

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 7) {
                Text("Αυτή την εβδομάδα")
                    .font(.system(size: 26, weight: .heavy))
                    .foregroundStyle(Paper.ink)
                Text("13 έως 19 Ιουλίου")
                    .font(KType.label(12)).tracking(1)
                    .foregroundStyle(Paper.inkMute)
            }
            bento
        }
    }

    @ViewBuilder
    private var bento: some View {
        let stack = VStack(spacing: 11) {
            HStack(alignment: .top, spacing: 11) {
                HeroTile(value: 6, previousWeekValue: 5, delta: "μία περισσότερη από πριν")
                VStack(spacing: 11) {
                    RungTile(numeral: "Α'", name: "Αποταγή", reached: 1, previousWeekReached: 1, total: 30)
                    StatTile(metric: rita)
                }
            }
            HStack(spacing: 11) {
                StatTile(metric: mathimata)
                StatTile(metric: aretes)
            }
            HStack(spacing: 11) {
                StatTile(metric: choria)
                StatTile(metric: prosefches)
            }
        }

        stack
    }
}

#Preview("Recap ανοιχτό") {
    ScrollView { WeeklyRecapView().padding(KSpace.gutter) }
        .background(Paper.bg.ignoresSafeArea())
        .preferredColorScheme(.light)
}

#Preview("Recap σκοτεινό") {
    ScrollView { WeeklyRecapView().padding(KSpace.gutter) }
        .background(Paper.bg.ignoresSafeArea())
        .preferredColorScheme(.dark)
}
