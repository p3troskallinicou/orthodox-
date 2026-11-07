import WidgetKit
import SwiftUI
import UIKit

// Ολόκληρο το widget του Klimax, εικαστικό Paper/Gild, έξι ξεχωριστές κατηγορίες.
// Καθεμία εμφανίζεται στη συλλογή widget, σε μικρό, μεσαίο και μεγάλο.
// ΠΡΟΣΟΧΗ: αυτό είναι το κύριο αρχείο του WidgetsExtension. Ανήκει ΜΟΝΟ στο WidgetsExtension.
// Το WidgetSharedData.swift ανήκει και στα δύο targets.

// MARK: Γραμματοσειρά

enum KlimaxWidgetFont {
    // Ονόματα PostScript της Gentium Book Plus. Άλλαξέ τα αν το print δείξει διαφορετικά.
    // Τα τρία αρχεία πρέπει να είναι προσθεμένα ΚΑΙ στο target του widget και δηλωμένα στο Info του extension.
    static func serif(_ size: CGFloat) -> Font { .custom("GentiumBookPlus-Regular", size: size) }
    static func serifBold(_ size: CGFloat) -> Font { .custom("GentiumBookPlus-Bold", size: size) }
    static func serifItalic(_ size: CGFloat) -> Font { .custom("GentiumBookPlus-Italic", size: size) }
}

extension Color {
    static let klimaxGold = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.72, green: 0.35, blue: 0.46, alpha: 1)
            : UIColor(red: 63.0 / 255.0, green: 1.0 / 255.0, blue: 18.0 / 255.0, alpha: 1)
    })
    static let klimaxInk = Color(red: 0.196, green: 0.157, blue: 0.086)
}

// MARK: Κατηγορίες

enum WidgetCategory {
    case fasting, feast, ladder, gerontikon, saintQuote, saintIcon
}

// MARK: Είσοδος χρονογραμμής

struct KlimaxEntry: TimelineEntry {
    let date: Date
    let snapshot: KlimaxWidgetSnapshot
    let category: WidgetCategory
}

// MARK: Πάροχος (ένας ανά κατηγορία)

struct CategoryProvider: TimelineProvider {
    let category: WidgetCategory

    func placeholder(in context: Context) -> KlimaxEntry {
        KlimaxEntry(date: Date(), snapshot: .sample, category: category)
    }

    func getSnapshot(in context: Context, completion: @escaping (KlimaxEntry) -> Void) {
        completion(KlimaxEntry(date: Date(), snapshot: WidgetSharedStore.load(), category: category))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<KlimaxEntry>) -> Void) {
        let now = Date()
        let entry = KlimaxEntry(date: now, snapshot: WidgetSharedStore.load(), category: category)
        let nextRefresh = Calendar.current.nextDate(
            after: now,
            matching: DateComponents(hour: 0, minute: 5),
            matchingPolicy: .nextTime
        ) ?? now.addingTimeInterval(60 * 60)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }
}

// MARK: Φόντο Paper/Gild (αδιαφανές, με χρυσό πλαίσιο)

struct PaperGildBackground: View {
    @Environment(\.colorScheme) var scheme

    var body: some View {
        let top = scheme == .dark ? Color(red: 0.11, green: 0.10, blue: 0.07) : Color(red: 0.961, green: 0.925, blue: 0.839)
        let bottom = scheme == .dark ? Color(red: 0.07, green: 0.06, blue: 0.04) : Color(red: 0.913, green: 0.867, blue: 0.741)
        LinearGradient(colors: [top, bottom], startPoint: .top, endPoint: .bottom)
            .overlay(
                ContainerRelativeShape()
                    .inset(by: 2.5)
                    .stroke(Color.klimaxGold.opacity(scheme == .dark ? 0.55 : 0.45), lineWidth: 1)
            )
    }
}

// MARK: Κοινά διακοσμητικά

struct CategoryHeader: View {
    let text: String
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(text)
                .font(KlimaxWidgetFont.serifItalic(12))
                .foregroundStyle(Color.klimaxGold)
                .widgetAccentable()
            Rectangle()
                .fill(Color.klimaxGold.opacity(0.6))
                .frame(height: 0.8)
        }
    }
}

struct GoldBar: View {
    let progress: Double
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.klimaxGold.opacity(0.18))
                Capsule().fill(Color.klimaxGold).frame(width: max(6, geo.size.width * progress))
            }
        }
        .frame(height: 6)
    }
}

private func greekDate(_ date: Date) -> String {
    date.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(Locale(identifier: "el")))
}

func ink(_ scheme: ColorScheme) -> Color {
    scheme == .dark ? Color(red: 0.925, green: 0.878, blue: 0.784) : Color.klimaxInk
}

// MARK: Ρίζα προβολής

struct KlimaxWidgetView: View {
    let entry: KlimaxEntry

    var body: some View {
        switch entry.category {
        case .fasting:    FastingWidget(entry: entry)
        case .feast:      FeastWidget(entry: entry)
        case .ladder:     LadderWidget(entry: entry)
        case .gerontikon: GerontikonWidget(entry: entry)
        case .saintQuote: SaintQuoteWidget(entry: entry)
        case .saintIcon:  SaintIconWidget(entry: entry)
        }
    }
}

// MARK: Νηστεία

struct FastingWidget: View {
    @Environment(\.widgetFamily) var family
    @Environment(\.colorScheme) var scheme
    let entry: KlimaxEntry

    var body: some View {
        let info = entry.snapshot.fasting
        VStack(alignment: .leading, spacing: 8) {
            CategoryHeader(text: "Νηστεία")
            Spacer(minLength: 0)
            HStack(spacing: 8) {
                Circle()
                    .fill(info.isFastDay ? Color.klimaxGold : Color.secondary.opacity(0.4))
                    .frame(width: 9, height: 9)
                Text(info.title)
                    .font(KlimaxWidgetFont.serifBold(family == .systemSmall ? 19 : 25))
                    .foregroundStyle(ink(scheme))
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            if family != .systemSmall {
                Text(info.detail)
                    .font(KlimaxWidgetFont.serif(15))
                    .foregroundStyle(ink(scheme).opacity(0.75))
                    .lineLimit(family == .systemLarge ? 5 : 2)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

// MARK: Ἑορτολόγιο

struct FeastWidget: View {
    @Environment(\.widgetFamily) var family
    @Environment(\.colorScheme) var scheme
    let entry: KlimaxEntry

    var body: some View {
        let info = entry.snapshot.feast
        VStack(alignment: .leading, spacing: 8) {
            if family == .systemLarge {
                Text(greekDate(entry.snapshot.day))
                    .font(KlimaxWidgetFont.serif(15))
                    .foregroundStyle(ink(scheme).opacity(0.7))
            }
            CategoryHeader(text: "Ἑορτὴ τῆς ἡμέρας")
            Spacer(minLength: 0)
            Text(info.title)
                .font(KlimaxWidgetFont.serifBold(family == .systemSmall ? 20 : 29))
                .foregroundStyle(ink(scheme))
                .lineLimit(family == .systemSmall ? 3 : 4)
                .minimumScaleFactor(0.8)
            if family != .systemSmall {
                Text(info.rank)
                    .font(KlimaxWidgetFont.serifItalic(15))
                    .foregroundStyle(Color.klimaxGold)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

// MARK: Κλῖμαξ

struct LadderWidget: View {
    @Environment(\.widgetFamily) var family
    @Environment(\.colorScheme) var scheme
    let entry: KlimaxEntry

    var body: some View {
        let info = entry.snapshot.ladder
        VStack(alignment: .leading, spacing: 10) {
            CategoryHeader(text: "Ποῦ βρίσκεσαι")
            Spacer(minLength: 0)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(info.rung)")
                    .font(KlimaxWidgetFont.serifBold(family == .systemSmall ? 38 : 50))
                    .foregroundStyle(Color.klimaxGold)
                    .widgetAccentable()
                Text("βαθμίδα")
                    .font(KlimaxWidgetFont.serif(15))
                    .foregroundStyle(ink(scheme).opacity(0.7))
            }
            Text(info.sectionTitle)
                .font(KlimaxWidgetFont.serif(family == .systemSmall ? 15 : 18))
                .foregroundStyle(ink(scheme))
                .lineLimit(2)
            GoldBar(progress: info.progress)
            if family == .systemLarge {
                Text("Πρόοδος \(Int((info.progress * 100).rounded())) τοῖς ἑκατό")
                    .font(KlimaxWidgetFont.serif(13))
                    .foregroundStyle(ink(scheme).opacity(0.7))
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

// MARK: Γεροντικόν

struct GerontikonWidget: View {
    @Environment(\.widgetFamily) var family
    @Environment(\.colorScheme) var scheme
    let entry: KlimaxEntry

    var body: some View {
        let info = entry.snapshot.gerontikon
        VStack(alignment: .leading, spacing: 10) {
            CategoryHeader(text: "Γεροντικόν")
            Spacer(minLength: 0)
            Text(info.saying)
                .font(KlimaxWidgetFont.serif(family == .systemSmall ? 15 : 19))
                .foregroundStyle(ink(scheme))
                .lineLimit(family == .systemSmall ? 4 : (family == .systemMedium ? 4 : 9))
                .minimumScaleFactor(0.82)
            Text(info.abba)
                .font(KlimaxWidgetFont.serifItalic(14))
                .foregroundStyle(Color.klimaxGold)
                .widgetAccentable()
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

// MARK: Ρήσεις ἁγίων

struct SaintQuoteWidget: View {
    @Environment(\.widgetFamily) var family
    @Environment(\.colorScheme) var scheme
    let entry: KlimaxEntry

    var body: some View {
        let info = entry.snapshot.saintQuote
        VStack(alignment: .leading, spacing: 10) {
            CategoryHeader(text: "Ρήσεις ἁγίων")
            Spacer(minLength: 0)
            Text("\u{201C}\(info.quote)\u{201D}")
                .font(KlimaxWidgetFont.serifItalic(family == .systemSmall ? 17 : 22))
                .foregroundStyle(ink(scheme))
                .lineLimit(family == .systemSmall ? 4 : (family == .systemMedium ? 4 : 8))
                .minimumScaleFactor(0.82)
            Text(info.saint)
                .font(KlimaxWidgetFont.serif(14))
                .foregroundStyle(Color.klimaxGold)
                .widgetAccentable()
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

// MARK: Εἰκόνα ἁγίου (τυπογραφικὸ ἔμβλημα ὅταν λείπει εἰκόνα)

struct SaintIconWidget: View {
    @Environment(\.widgetFamily) var family
    @Environment(\.colorScheme) var scheme
    let entry: KlimaxEntry

    private var info: SaintInfo { entry.snapshot.saint }

    var body: some View {
        Group {
            if family == .systemSmall {
                VStack(spacing: 10) {
                    emblem(size: 58)
                    Text(info.name)
                        .font(KlimaxWidgetFont.serif(15))
                        .foregroundStyle(ink(scheme))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HStack(spacing: 16) {
                    emblem(size: family == .systemLarge ? 104 : 70)
                    VStack(alignment: .leading, spacing: 7) {
                        CategoryHeader(text: "Ἅγιος τῆς ἡμέρας")
                        Text(info.name)
                            .font(KlimaxWidgetFont.serifBold(family == .systemLarge ? 27 : 21))
                            .foregroundStyle(ink(scheme))
                            .lineLimit(3)
                            .minimumScaleFactor(0.8)
                        Text(info.line)
                            .font(KlimaxWidgetFont.serif(15))
                            .foregroundStyle(ink(scheme).opacity(0.75))
                            .lineLimit(family == .systemLarge ? 4 : 2)
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private func emblem(size: CGFloat) -> some View {
        if let name = info.iconAssetName, !name.isEmpty {
            Image(name)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.klimaxGold, lineWidth: 1.5))
        } else {
            ZStack {
                Circle().fill(Color.klimaxGold.opacity(0.08))
                Circle().stroke(Color.klimaxGold, lineWidth: 1.5)
                Circle().inset(by: 5).stroke(Color.klimaxGold.opacity(0.5), lineWidth: 0.8)
                Text(String(info.name.prefix(1)))
                    .font(KlimaxWidgetFont.serifBold(size * 0.48))
                    .foregroundStyle(Color.klimaxGold)
            }
            .frame(width: size, height: size)
            .widgetAccentable()
        }
    }
}

// MARK: Ορισμοί widget (ένας ανά κατηγορία, ώστε να φαίνονται όλοι στη συλλογή)

private func klimaxConfig(kind: String, category: WidgetCategory, name: LocalizedStringResource, desc: LocalizedStringResource) -> some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: CategoryProvider(category: category)) { entry in
        KlimaxWidgetView(entry: entry)
            .containerBackground(for: .widget) { PaperGildBackground() }
    }
    .configurationDisplayName(name)
    .description(desc)
    .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
}

struct KlimaxFastingWidget: Widget {
    var body: some WidgetConfiguration {
        klimaxConfig(kind: "KlimaxWidget.fasting", category: .fasting, name: "Νηστεία", desc: "Ὁ κανόνας τῆς ἡμέρας.")
    }
}
struct KlimaxFeastWidget: Widget {
    var body: some WidgetConfiguration {
        klimaxConfig(kind: "KlimaxWidget.feast", category: .feast, name: "Ἑορτολόγιο", desc: "Ἡ ἑορτὴ τῆς ἡμέρας.")
    }
}
struct KlimaxLadderWidget: Widget {
    var body: some WidgetConfiguration {
        klimaxConfig(kind: "KlimaxWidget.ladder", category: .ladder, name: "Κλῖμαξ", desc: "Ποῦ βρίσκεσαι στὴν ἄνοδο.")
    }
}
struct KlimaxGerontikonWidget: Widget {
    var body: some WidgetConfiguration {
        klimaxConfig(kind: "KlimaxWidget.gerontikon", category: .gerontikon, name: "Γεροντικόν", desc: "Μία ρήση κάθε ἡμέρα.")
    }
}
struct KlimaxSaintQuoteWidget: Widget {
    var body: some WidgetConfiguration {
        klimaxConfig(kind: "KlimaxWidget.saintQuote", category: .saintQuote, name: "Ρήσεις ἁγίων", desc: "Λόγος ἁγίου κάθε ἡμέρα.")
    }
}
struct KlimaxSaintIconWidget: Widget {
    var body: some WidgetConfiguration {
        klimaxConfig(kind: "KlimaxWidget.saintIcon", category: .saintIcon, name: "Εἰκόνα ἁγίου", desc: "Ὁ ἅγιος τῆς ἡμέρας.")
    }
}

@main
struct KlimaxWidgetBundle: WidgetBundle {
    var body: some Widget {
        // Τὰ 10 widgets τῆς σελίδας «Σήμερα».
        TodaySundayLiturgyWidget()
        TodayDidachesWidget()
        TodayStoriesWidget()
        TodayContinueReadingWidget()
        TodayVerseWidget()
        TodayFastingPhoneWidget()
        TodayFeastCalendarWidget()
        TodaySaintsWidget()
        TodayStreaksWidget()
        TodayNearbyWidget()

        // Βιβλικὴ Πορεία: μία επιλογή θέματος με όλα τα Home/Lock sizes.
        ScriptureJourneyWidget()

        // Ζωντανὴ πρόοδος μαθήματος στὸ Lock Screen καὶ Dynamic Island.
        ScriptureLearningLiveActivity()

        // Τὸ προσωπικὸ εἰκονοστάσι.
        KlimaxIconostasisWidget()

        // Κάθε θέμα δηλώνεται ἀκριβῶς μία φορά. Τὸ iOS δείχνει ἔπειτα μέσα
        // στὴν ἴδια επιλογὴ τὰ διαθέσιμα μεγέθη, ὄχι διπλὲς καταχωρίσεις.
    }
}
