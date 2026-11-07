import AppIntents
import SwiftUI
import UIKit
import WidgetKit
import MapKit

// MARK: - Κοινὸ Timeline

enum PhoneWidgetKind: String {
    case sundayLiturgy
    case didaches
    case dailyStories
    case continueReading
    case verse
    case fasting
    case feastCalendar
    case saints
    case streaks
    case nearby

    var displayName: String {
        switch self {
        case .sundayLiturgy: "Θεία Λειτουργία"
        case .didaches: "Διδαχές"
        case .dailyStories: "Γεροντικό"
        case .continueReading: "Συνέχεια Γραφής"
        case .verse: "Χωρίο ημέρας"
        case .fasting: "Νηστεία"
        case .feastCalendar: "Εορτολόγιο"
        case .saints: "Άγιοι ημέρας"
        case .streaks: "Στόχοι"
        case .nearby: "Κοντά σου"
        }
    }

    var description: String {
        switch self {
        case .sundayLiturgy: "Η Θεία Λειτουργία της Κυριακής."
        case .didaches: "Η ομιλία της ημέρας."
        case .dailyStories: "Τα σημερινά ρητά του Γεροντικού."
        case .continueReading: "Συνέχισε τη μελέτη της Αγίας Γραφής."
        case .verse: "Ένα χωρίο της Αγίας Γραφής κάθε μέρα."
        case .fasting: "Ο κανόνας νηστείας της ημέρας."
        case .feastCalendar: "Η εορτή της ημέρας."
        case .saints: "Οι Άγιοι που τιμώνται σήμερα."
        case .streaks: "Η σημερινή πορεία των στόχων σου."
        case .nearby: "Γρήγορη πρόσβαση στους κοντινούς ναούς."
        }
    }

    var deepLink: URL {
        URL(string: "klimax://widget/\(rawValue)")!
    }

    var theme: PhoneWidgetTheme {
        switch self {
        case .sundayLiturgy:
            .init(accent: Color(red: 0.72, green: 0.50, blue: 0.20), light: Color(red: 0.96, green: 0.90, blue: 0.78), dark: Color(red: 0.25, green: 0.08, blue: 0.07), ornament: "cross.fill")
        case .didaches:
            .init(accent: Color(red: 0.20, green: 0.52, blue: 0.83), light: Color(red: 0.88, green: 0.95, blue: 1.0), dark: Color(red: 0.05, green: 0.14, blue: 0.25), ornament: "waveform")
        case .dailyStories:
            .init(accent: Color(red: 0.61, green: 0.39, blue: 0.18), light: Color(red: 0.97, green: 0.91, blue: 0.80), dark: Color(red: 0.20, green: 0.13, blue: 0.07), ornament: "quote.opening")
        case .continueReading:
            .init(accent: Color(red: 0.22, green: 0.35, blue: 0.62), light: Color(red: 0.91, green: 0.93, blue: 0.99), dark: Color(red: 0.07, green: 0.10, blue: 0.24), ornament: "bookmark.fill")
        case .verse:
            .init(accent: Color(red: 0.42, green: 0.28, blue: 0.66), light: Color(red: 0.95, green: 0.91, blue: 0.99), dark: Color(red: 0.14, green: 0.08, blue: 0.24), ornament: "text.book.closed.fill")
        case .fasting:
            .init(accent: Color(red: 0.35, green: 0.48, blue: 0.25), light: Color(red: 0.91, green: 0.95, blue: 0.84), dark: Color(red: 0.10, green: 0.18, blue: 0.08), ornament: "leaf.fill")
        case .feastCalendar:
            .init(accent: Color(red: 0.72, green: 0.22, blue: 0.26), light: Color(red: 1.0, green: 0.91, blue: 0.88), dark: Color(red: 0.25, green: 0.06, blue: 0.09), ornament: "calendar")
        case .saints:
            .init(accent: Color(red: 0.64, green: 0.45, blue: 0.16), light: Color(red: 0.98, green: 0.92, blue: 0.75), dark: Color(red: 0.20, green: 0.12, blue: 0.04), ornament: "seal.fill")
        case .streaks:
            .init(accent: Color(red: 0.96, green: 0.39, blue: 0.14), light: Color(red: 1.0, green: 0.92, blue: 0.78), dark: Color(red: 0.26, green: 0.07, blue: 0.03), ornament: "flame.fill")
        case .nearby:
            .init(accent: Color(red: 0.10, green: 0.53, blue: 0.49), light: Color(red: 0.85, green: 0.96, blue: 0.93), dark: Color(red: 0.03, green: 0.19, blue: 0.18), ornament: "map.fill")
        }
    }
}

struct PhoneWidgetTheme {
    let accent: Color
    let light: Color
    let dark: Color
    let ornament: String

    static func fasting(themeKey: String?, ornament: String) -> PhoneWidgetTheme {
        switch themeKey {
        case "no_meat":
            .init(
                accent: Color(red: 0.804, green: 0.690, blue: 0.408),
                light: Color(red: 0.975, green: 0.944, blue: 0.835),
                dark: Color(red: 0.235, green: 0.184, blue: 0.075),
                ornament: ornament
            )
        case "fish":
            .init(
                accent: Color(red: 0.776, green: 0.631, blue: 0.357),
                light: Color(red: 0.966, green: 0.925, blue: 0.805),
                dark: Color(red: 0.224, green: 0.168, blue: 0.061),
                ornament: ornament
            )
        case "oil_wine":
            .init(
                accent: Color(red: 0.753, green: 0.541, blue: 0.235),
                light: Color(red: 0.970, green: 0.895, blue: 0.742),
                dark: Color(red: 0.238, green: 0.137, blue: 0.035),
                ornament: ornament
            )
        case "xerophagy":
            .init(
                accent: Color(red: 0.620, green: 0.494, blue: 0.200),
                light: Color(red: 0.939, green: 0.892, blue: 0.733),
                dark: Color(red: 0.184, green: 0.132, blue: 0.037),
                ornament: ornament
            )
        default:
            .init(
                accent: Color(red: 0.431, green: 0.482, blue: 0.322),
                light: Color(red: 0.910, green: 0.950, blue: 0.840),
                dark: Color(red: 0.100, green: 0.180, blue: 0.080),
                ornament: ornament
            )
        }
    }
}

func resolvedPhoneWidgetCard(snapshot: KlimaxWidgetSnapshot, kind: PhoneWidgetKind) -> PhoneWidgetCard {
    if kind == .dailyStories, let stories = snapshot.stories, !stories.isEmpty {
        return stories[WidgetSharedStore.storyIndex % stories.count]
    }
    if kind == .fasting, let days = snapshot.fastingCalendar, !days.isEmpty {
        let selected = WidgetSharedStore.selectedFastingDate
            ?? Calendar.current.date(byAdding: .day, value: WidgetSharedStore.fastingDayOffset, to: Date()) ?? Date()
        if let day = days.first(where: { $0.date.map { Calendar.current.isDate($0, inSameDayAs: selected) } ?? false }) { return day }
    }
    if kind == .fasting, !snapshot.fastingCards.isEmpty {
        return snapshot.fastingCards[min(WidgetSharedStore.fastingDayOffset, snapshot.fastingCards.count - 1)]
    }
    return snapshot.todayCards[kind.rawValue]
        ?? PhoneWidgetCard.sampleCards[kind.rawValue]
        ?? .init(eyebrow: "ΚΛΙΜΑΞ", title: kind.displayName, detail: "", symbol: "cross.fill")
}

private func resolvedPhoneWidgetTheme(snapshot: KlimaxWidgetSnapshot, kind: PhoneWidgetKind) -> PhoneWidgetTheme {
    let card = resolvedPhoneWidgetCard(snapshot: snapshot, kind: kind)
    return kind == .fasting
        ? .fasting(themeKey: card.themeKey, ornament: card.symbol)
        : kind.theme
}

struct MoveFastingDayIntent: AppIntent {
    static var title: LocalizedStringResource = "Ἀλλαγὴ ἡμέρας νηστείας"
    static var openAppWhenRun = false

    @Parameter(title: "Μετακίνηση") var delta: Int

    init() { delta = 0 }
    init(delta: Int) { self.delta = delta }

    func perform() async throws -> some IntentResult {
        WidgetSharedStore.moveFastingDay(by: delta)
        // WidgetKit reloads the interacting widget after perform() returns.
        return .result()
    }
}

struct SelectFastingDayIntent: AppIntent {
    static var title: LocalizedStringResource = "Ἐπιλογὴ ἡμέρας νηστείας"
    static var openAppWhenRun = false

    @Parameter(title: "Ἡμέρα") var offset: Int

    init() { offset = 0 }
    init(offset: Int) { self.offset = offset }

    func perform() async throws -> some IntentResult {
        WidgetSharedStore.selectFastingDay(offset)
        // Avoid a second reload competing with the interaction's own update.
        return .result()
    }
}

struct PhoneWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: KlimaxWidgetSnapshot
    let kind: PhoneWidgetKind
    var mapImage: UIImage? = nil
    let card: PhoneWidgetCard
    let storyIndex: Int

    init(date: Date, snapshot: KlimaxWidgetSnapshot, kind: PhoneWidgetKind) {
        self.date = date
        self.snapshot = snapshot
        self.kind = kind
        self.card = resolvedPhoneWidgetCard(snapshot: snapshot, kind: kind)
        self.storyIndex = WidgetSharedStore.storyIndex % max(1, snapshot.stories?.count ?? 0)
    }
}

struct PhoneWidgetProvider: TimelineProvider {
    let kind: PhoneWidgetKind

    func placeholder(in context: Context) -> PhoneWidgetEntry {
        PhoneWidgetEntry(date: Date(), snapshot: .sample, kind: kind)
    }

    func getSnapshot(in context: Context, completion: @escaping (PhoneWidgetEntry) -> Void) {
        makeEntry(size: context.displaySize, completion: completion)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PhoneWidgetEntry>) -> Void) {
        let now = Date()
        let refresh = Calendar.current.nextDate(
            after: now,
            matching: DateComponents(hour: 0, minute: 5),
            matchingPolicy: .nextTime
        ) ?? now.addingTimeInterval(60 * 60)
        makeEntry(size: context.displaySize) { entry in
            completion(Timeline(entries: [entry], policy: .after(refresh)))
        }
    }

    private func makeEntry(size: CGSize, completion: @escaping (PhoneWidgetEntry) -> Void) {
        let entry = PhoneWidgetEntry(date: Date(), snapshot: WidgetSharedStore.load(), kind: kind)
        guard kind == .nearby else { completion(entry); return }
        // Same initial region as TodayView. No location permission or location
        // inference in the extension; opening the card uses the app's full map.
        let options = MKMapSnapshotter.Options()
        options.region = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 37.9838, longitude: 23.7275),
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05))
        options.size = size
        options.scale = 2
        MKMapSnapshotter(options: options).start { snapshot, _ in
            var result = entry
            result.mapImage = snapshot?.image
            completion(result)
        }
    }
}

// MARK: - Today widgets (Home Screen + Lock Screen)

struct PhoneTodayWidgetView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var scheme
    let entry: PhoneWidgetEntry

    private var card: PhoneWidgetCard {
        entry.card
    }

    private var theme: PhoneWidgetTheme {
        resolvedPhoneWidgetTheme(snapshot: entry.snapshot, kind: entry.kind)
    }

    var body: some View {
        Group {
            switch family {
            case .accessoryInline:
                Label(inlineText, systemImage: card.symbol)
            case .accessoryCircular:
                circularView
            case .accessoryRectangular:
                rectangularView
            case .systemSmall:
                HomeDashboardWidget(entry: entry)
            case .systemMedium:
                HomeDashboardWidget(entry: entry)
            default:
                HomeDashboardWidget(entry: entry)
            }
        }
        .widgetURL(entry.kind.deepLink)
    }

    private var inlineText: String {
        if let value = card.value, !value.isEmpty { return "\(entry.kind.displayName): \(value)" }
        return card.title
    }

    private var circularView: some View {
        ZStack {
            if let progress = card.progress {
                Gauge(value: min(max(progress, 0), 1)) {
                    Image(systemName: card.symbol)
                } currentValueLabel: {
                    Text(card.value ?? "")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                }
                .gaugeStyle(.accessoryCircular)
            } else {
                VStack(spacing: 2) {
                    Image(systemName: card.symbol)
                        .font(.system(size: 17, weight: .semibold))
                    if entry.kind == .feastCalendar {
                        Text(entry.date, format: .dateTime.day())
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                    }
                }
            }
        }
        .widgetAccentable()
    }

    private var rectangularView: some View {
        HStack(spacing: 8) {
            Image(systemName: card.symbol)
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 24)
                .widgetAccentable()
            VStack(alignment: .leading, spacing: 1) {
                Text(card.eyebrow)
                    .font(.system(size: 9, weight: .bold))
                    .lineLimit(1)
                Text(card.title)
                    .font(.system(size: 13, weight: .semibold, design: .serif))
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
            if let value = card.value {
                Text(value)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
            }
        }
    }

}

private func phoneWidgetConfiguration(_ kind: PhoneWidgetKind) -> some WidgetConfiguration {
    StaticConfiguration(kind: "Klimax.Today.\(kind.rawValue)", provider: PhoneWidgetProvider(kind: kind)) { entry in
        PhoneTodayWidgetView(entry: entry)
            .containerBackground(for: .widget) {
                if kind == .nearby, let image = entry.mapImage {
                    Image(uiImage: image).resizable().scaledToFill()
                        .overlay(LinearGradient(colors: [.black.opacity(0.1), .clear, .black.opacity(0.5)], startPoint: .top, endPoint: .bottom))
                } else {
                    HomeDashboardBackground(kind: kind, card: entry.card)
                }
            }
    }
    .configurationDisplayName(LocalizedStringResource(stringLiteral: kind.displayName))
    .description(LocalizedStringResource(stringLiteral: kind.description))
    .supportedFamilies([
        .systemSmall, .systemMedium, .systemLarge,
        .accessoryInline, .accessoryCircular, .accessoryRectangular
    ])
}

struct TodaySundayLiturgyWidget: Widget { var body: some WidgetConfiguration { phoneWidgetConfiguration(.sundayLiturgy) } }
struct TodayDidachesWidget: Widget { var body: some WidgetConfiguration { phoneWidgetConfiguration(.didaches) } }
struct TodayStoriesWidget: Widget { var body: some WidgetConfiguration { phoneWidgetConfiguration(.dailyStories) } }
struct TodayContinueReadingWidget: Widget { var body: some WidgetConfiguration { phoneWidgetConfiguration(.continueReading) } }
struct TodayVerseWidget: Widget { var body: some WidgetConfiguration { phoneWidgetConfiguration(.verse) } }
struct TodayFastingPhoneWidget: Widget { var body: some WidgetConfiguration { phoneWidgetConfiguration(.fasting) } }
struct TodayFeastCalendarWidget: Widget { var body: some WidgetConfiguration { phoneWidgetConfiguration(.feastCalendar) } }
struct TodaySaintsWidget: Widget { var body: some WidgetConfiguration { phoneWidgetConfiguration(.saints) } }
struct TodayStreaksWidget: Widget { var body: some WidgetConfiguration { phoneWidgetConfiguration(.streaks) } }
struct TodayNearbyWidget: Widget { var body: some WidgetConfiguration { phoneWidgetConfiguration(.nearby) } }

// MARK: - Προσωπικὸ Εἰκονοστάσι

struct IconostasisEntry: TimelineEntry {
    let date: Date
    let snapshot: KlimaxWidgetSnapshot
}

struct IconostasisProvider: TimelineProvider {
    func placeholder(in context: Context) -> IconostasisEntry { .init(date: Date(), snapshot: .sample) }
    func getSnapshot(in context: Context, completion: @escaping (IconostasisEntry) -> Void) {
        completion(.init(date: Date(), snapshot: WidgetSharedStore.load()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<IconostasisEntry>) -> Void) {
        let now = Date()
        let refresh = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: now))
            ?? now.addingTimeInterval(60 * 60)
        completion(.init(entries: [.init(date: now, snapshot: WidgetSharedStore.load())], policy: .after(refresh)))
    }
}

struct IconostasisPhoneWidgetView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var scheme
    let entry: IconostasisEntry

    private var saints: [IconostasisWidgetSaint] {
        entry.snapshot.iconostasis.saints
    }

    var body: some View {
        Group {
            switch family {
            case .accessoryInline:
                Label("Τὸ εἰκονοστάσι μου · \(saints.count) εἰκόνες", systemImage: "building.columns.fill")
            case .accessoryCircular:
                ZStack {
                    AccessoryWidgetBackground()
                    Image(systemName: "building.columns.fill")
                        .font(.system(size: 20, weight: .semibold))
                    Text("\(saints.count)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .offset(y: 17)
                }
                .widgetAccentable()
            case .accessoryRectangular:
                HStack(spacing: 8) {
                    Image(systemName: "building.columns.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .widgetAccentable()
                    VStack(alignment: .leading, spacing: 2) {
                        Text("ΤΟ ΕΙΚΟΝΟΣΤΑΣΙ ΜΟΥ")
                            .font(.system(size: 9, weight: .bold))
                        Text(saints.isEmpty
                             ? "Ρύθμισέ το στὴν Κλῖμακα"
                             : saints.prefix(2).map(\.name).joined(separator: " · "))
                            .font(.system(size: 12, weight: .semibold, design: .serif))
                            .lineLimit(2)
                    }
                }
            default:
                homeIconostasis
            }
        }
        .widgetURL(URL(string: "klimax://widget/iconostasis"))
    }

    private var homeIconostasis: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Τὸ εἰκονοστάσι μου", systemImage: "building.columns.fill")
                    .font(KlimaxWidgetFont.serifBold(family == .systemSmall ? 12 : 15))
                    .foregroundStyle(Color.klimaxGold)
                    .widgetAccentable()
                Spacer(minLength: 0)
                Text("\(saints.count)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(ink(scheme).opacity(0.65))
            }

            if saints.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "rectangle.portrait.on.rectangle.portrait.angled")
                        .font(.system(size: family == .systemSmall ? 25 : 32, weight: .light))
                        .foregroundStyle(Color.klimaxGold)
                        .widgetAccentable()
                    Text("Διάλεξε τὶς εἰκόνες σου στὴν Κλῖμακα")
                        .font(KlimaxWidgetFont.serif(family == .systemSmall ? 12 : 15))
                        .foregroundStyle(ink(scheme).opacity(0.72))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                GeometryReader { proxy in
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        HStack(alignment: .bottom, spacing: saints.count >= 5 ? 3 : 5) {
                            ForEach(Array(saints.prefix(limit).enumerated()), id: \.element.id) { index, saint in
                                icon(for: saint)
                                    .frame(width: iconWidth(total: proxy.size.width, count: min(saints.count, limit), index: index))
                            }
                        }
                        widgetShelf
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                }
            }

            if family == .systemLarge, !saints.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    Text("ΟΙ ΕΙΚΟΝΕΣ ΣΟΥ")
                        .font(.system(size: 9, weight: .black))
                        .tracking(1.5)
                        .foregroundStyle(Color.klimaxGold)
                    Text(saints.map(\.name).joined(separator: " · "))
                        .font(KlimaxWidgetFont.serif(13))
                        .foregroundStyle(ink(scheme).opacity(0.72))
                        .lineLimit(2)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var limit: Int { family == .systemSmall ? 3 : 6 }

    private func iconWidth(total: CGFloat, count: Int, index: Int) -> CGFloat {
        guard count > 0 else { return 0 }
        let available = total - CGFloat(max(0, count - 1)) * (count >= 5 ? 3 : 5)
        let middleBoost: CGFloat = (count % 2 == 1 && index == count / 2) ? 1.22 : 1
        let denominator = CGFloat(count) + (count % 2 == 1 ? 0.22 : 0)
        return (available / denominator) * middleBoost
    }

    private func icon(for saint: IconostasisWidgetSaint) -> some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.34, green: 0.18, blue: 0.07), Color(red: 0.75, green: 0.53, blue: 0.20)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            if let image = sharedImage(named: saint.imageFileName) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .padding(2)
            } else {
                Text(String(saint.name.prefix(1)))
                    .font(KlimaxWidgetFont.serifBold(family == .systemSmall ? 19 : 24))
                    .foregroundStyle(Color.klimaxGold)
                    .minimumScaleFactor(0.6)
            }
        }
        .aspectRatio(0.68, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(Color.klimaxGold.opacity(0.9), lineWidth: 1))
        .clipped()
        .accessibilityLabel(saint.name)
    }

    private func sharedImage(named name: String?) -> UIImage? {
        guard let name, let root = WidgetSharedStore.containerURL else { return nil }
        return UIImage(contentsOfFile: root.appendingPathComponent(name).path)
    }

    private var widgetShelf: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color(red: 0.31, green: 0.15, blue: 0.06), Color(red: 0.67, green: 0.43, blue: 0.16), Color(red: 0.28, green: 0.13, blue: 0.05)],
                    startPoint: .leading,
                    endPoint: .trailing
                ))
                .overlay(alignment: .top) { Rectangle().fill(Color.klimaxGold.opacity(0.75)).frame(height: 1) }
                .frame(height: family == .systemSmall ? 6 : 8)
            HStack {
                Capsule().fill(Color(red: 0.31, green: 0.15, blue: 0.06)).frame(width: 18, height: 4)
                Spacer()
                Capsule().fill(Color(red: 0.31, green: 0.15, blue: 0.06)).frame(width: 18, height: 4)
            }
            .padding(.horizontal, 12)
        }
    }
}

struct IconostasisWidgetBackground: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        RadialGradient(
            colors: scheme == .dark
                ? [Color(red: 0.29, green: 0.16, blue: 0.06), Color(red: 0.055, green: 0.035, blue: 0.02)]
                : [Color(red: 1.0, green: 0.93, blue: 0.69), Color(red: 0.80, green: 0.61, blue: 0.27)],
            center: .top,
            startRadius: 10,
            endRadius: 310
        )
        .overlay(alignment: .top) {
            Image(systemName: "sun.max.fill")
                .font(.system(size: 130, weight: .thin))
                .foregroundStyle(Color.klimaxGold.opacity(0.10))
                .offset(y: -55)
        }
        .overlay {
            ContainerRelativeShape()
                .inset(by: 2)
                .stroke(Color.klimaxGold.opacity(0.48), lineWidth: 1)
        }
    }
}

struct KlimaxIconostasisWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "Klimax.Iconostasis", provider: IconostasisProvider()) { entry in
            IconostasisPhoneWidgetView(entry: entry)
                .containerBackground(for: .widget) { IconostasisWidgetBackground() }
        }
        .configurationDisplayName("Τὸ εἰκονοστάσι μου")
        .description("Οἱ προσωπικὲς εἰκόνες σου στὴν Ἀρχικὴ Ὀθόνη ἢ στὴν Ὀθόνη Κλειδώματος.")
        .supportedFamilies([
            .systemSmall, .systemMedium, .systemLarge,
            .accessoryInline, .accessoryCircular, .accessoryRectangular
        ])
    }
}
