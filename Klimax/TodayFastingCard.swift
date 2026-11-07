//
//  TodayFastingCard.swift  ·  Klimax — ἡ κάρτα νηστείας γιὰ τὸ «Σήμερα»
//
//  Signature: χρυσωμένο μετάλλιο. Χρησιμοποιεῖ τὰ δικά σου Paper tokens καὶ
//  τὴν κοινὴ παρουσίαση (FastingLevel+UI). Ὅταν `showsCalendarHint == true`,
//  δείχνει ἕνδειξη ὅτι ἀνοίγει τὸ πλῆρες Νηστειοδρόμιο (τὸ NavigationLink
//  τοποθετεῖται ἀπ᾿ ἔξω, στὸ TodayView).
//
//  ΑΠΑΙΤΕΙ: FastingCalendar.swift, FastingLevel+UI.swift, Paschalion.swift.
//

import SwiftUI

struct TodayFastingCard: View {

    var date: Date = Date()
    var showsCalendarHint: Bool = false

    private var status: FastingStatus { FastingCalendar.shared.status(for: date) }
    private var level: FastingLevel { status.level }

    var body: some View {
        VStack(spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(status.isFast ? "ΝΗΣΤΕΙΑ" : "ΧΩΡΙΣ ΝΗΣΤΕΙΑ")
                    .font(.system(size: 10, weight: .semibold)).tracking(2)
                    .foregroundStyle(Paper.gold)
                Spacer()
                Text(dateString)
                    .font(.system(size: 12))
                    .foregroundStyle(Paper.inkMute)
            }

            Rectangle().fill(Paper.hairline).frame(height: 1)

            medallion

            VStack(spacing: 5) {
                Text(level.cardTitle)
                    // Ὅταν μπεῖ ἡ GFS Didot: .font(.custom("GFSDidot", size: 22))
                    .font(.system(size: 22, weight: .regular, design: .serif))
                    .foregroundStyle(Paper.ink)
                    .multilineTextAlignment(.center)
                Text(level.cardGuidance)
                    .font(.system(size: 13, design: .serif))
                    .foregroundStyle(Paper.inkMute)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if showsCalendarHint {
                HStack(spacing: 5) {
                    Text("Ολόκληρο το νηστειοδρόμιο")
                        .font(.system(size: 12, weight: .semibold))
                    Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold))
                }
                .foregroundStyle(Paper.gold)
                .padding(.top, 2)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(Paper.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Paper.hairline, lineWidth: 1))
        .shadow(color: .black.opacity(0.05), radius: 12, x: 0, y: 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(status.isFast ? "Νηστεία" : "Χωρὶς νηστεία"). \(level.cardTitle). \(level.cardGuidance)")
        .accessibilityHint(showsCalendarHint ? "Άνοιγμα του πλήρους νηστειοδρομίου" : "")
    }

    private var medallion: some View {
        ZStack {
            Circle().fill(Paper.bg)
            Circle()
                .stroke(
                    LinearGradient(colors: [level.cardTint, level.cardTintDeep],
                                   startPoint: .top, endPoint: .bottom),
                    lineWidth: 2
                )
            Circle().inset(by: 6).stroke(level.cardTint.opacity(0.45), lineWidth: 0.75)
            Image(systemName: level.cardIcon)
                .font(.system(size: 30, weight: .regular))
                .foregroundStyle(
                    LinearGradient(colors: [level.cardTint, level.cardTintDeep],
                                   startPoint: .top, endPoint: .bottom)
                )
                .accessibilityHidden(true)
        }
        .frame(width: 86, height: 86)
        .shadow(color: level.cardTint.opacity(0.28), radius: 6, x: 0, y: 2)
    }

    private var dateString: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "el_GR")
        f.dateFormat = "EEEE, d MMMM"
        return f.string(from: date)
    }
}

#if DEBUG
#Preview {
    ScrollView {
        VStack(spacing: 18) {
            TodayFastingCard(showsCalendarHint: true)
            TodayFastingCard(date: Calendar.current.date(from: DateComponents(year: 2026, month: 3, day: 25))!)
        }.padding(20)
    }
}
#endif
