import AppIntents
import SwiftUI
import WidgetKit

// Home Screen equivalents of TodayView's cards. WidgetKit owns the outer
// dimensions and margins; app-only navigation, scrolling and live Map views
// are represented by links, bounded text and AppIntent buttons here.
enum HomeWidgetStyle {
    static let burgundy = Color(red: 63 / 255, green: 1 / 255, blue: 18 / 255)
    static func ink(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.953, green: 0.925, blue: 0.855) : Color(red: 0.157, green: 0.129, blue: 0.090)
    }
    static func accent(_ scheme: ColorScheme) -> Color { scheme == .dark ? ink(scheme) : burgundy }
    static func surface(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.106, green: 0.122, blue: 0.157) : Color(red: 1, green: 0.996, blue: 0.985)
    }
}

struct HomeDashboardBackground: View {
    @Environment(\.colorScheme) private var scheme
    let kind: PhoneWidgetKind
    let card: PhoneWidgetCard
    private var tint: Color {
        switch kind {
        case .fasting: PhoneWidgetTheme.fasting(themeKey: card.themeKey, ornament: card.symbol).accent
        case .dailyStories: .brown.opacity(0.45)
        case .streaks: .orange.opacity(0.18)
        default: HomeWidgetStyle.burgundy.opacity(0.25)
        }
    }
    var body: some View {
        HomeWidgetStyle.surface(scheme)
            .overlay(LinearGradient(colors: [tint.opacity(0.10), .clear], startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(alignment: .bottomTrailing) {
                if kind == .streaks {
                    RadialGradient(colors: [.orange.opacity(0.16), .clear], center: .bottomTrailing, startRadius: 0, endRadius: 150)
                }
            }
            .overlay(ContainerRelativeShape().inset(by: 0.5).stroke(HomeWidgetStyle.ink(scheme).opacity(0.08), lineWidth: 0.75))
    }
}

struct HomeSelectFastingDateIntent: AppIntent {
    static var title: LocalizedStringResource = "Επιλογή ημέρας νηστείας"
    static var openAppWhenRun = false
    @Parameter(title: "Ημερομηνία") var date: Date
    init() { date = Date() }
    init(date: Date) { self.date = date }
    func perform() async throws -> some IntentResult {
        WidgetSharedStore.selectFastingDate(date)
        // The button's AppIntent completion triggers WidgetKit's reload.
        return .result()
    }
}

struct HomeNextStoryIntent: AppIntent {
    static var title: LocalizedStringResource = "Επόμενη ιστορία"
    static var openAppWhenRun = false
    func perform() async throws -> some IntentResult {
        WidgetSharedStore.nextStory()
        // Do not enqueue a duplicate reload here.
        return .result()
    }
}

struct HomeDashboardWidget: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var scheme
    let entry: PhoneWidgetEntry
    private var small: Bool { family == .systemSmall }
    private var large: Bool { family == .systemLarge }
    private var card: PhoneWidgetCard { entry.card }
    private var ink: Color { HomeWidgetStyle.ink(scheme) }
    private var accent: Color { HomeWidgetStyle.accent(scheme) }
    private var calendar: Calendar { .current }

    var body: some View {
        Group {
            switch entry.kind {
            case .fasting: fasting
            case .dailyStories: story
            case .streaks:
                if family == .systemMedium { mediumStreak } else { streak }
            case .continueReading:
                if family == .systemMedium { mediumReading } else { reading }
            case .didaches:
                if family == .systemMedium { mediumAudio } else { audio }
            case .nearby: nearby
            case .feastCalendar: feast
            default:
                if family == .systemMedium { mediumEditorial } else { editorial }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .foregroundStyle(ink)
        .widgetURL(entry.kind.deepLink)
    }

    private func title(_ text: String, size: CGFloat, lines: Int) -> some View {
        Text(text).font(.system(size: size, weight: .semibold, design: .serif))
            .lineLimit(lines).minimumScaleFactor(0.85).frame(maxWidth: .infinity, alignment: .leading)
    }
    private func header(_ text: String, symbol: String? = nil) -> some View {
        HStack(spacing: 6) {
            if let symbol { Image(systemName: symbol) }
            Text(text).font(.system(size: 9, weight: .bold)).tracking(0.8).lineLimit(1).minimumScaleFactor(0.8)
            Spacer(minLength: 0)
            Image(systemName: "arrow.up.right").font(.system(size: 10, weight: .semibold))
        }.foregroundStyle(accent)
    }
    private func glyph(_ symbol: String, tint: Color? = nil) -> some View {
        Image(systemName: symbol).font(.system(size: 18, weight: .semibold))
            .foregroundStyle(tint ?? accent).frame(width: 42, height: 42)
            .background((tint ?? HomeWidgetStyle.burgundy).opacity(0.13), in: RoundedRectangle(cornerRadius: 13))
            .overlay(RoundedRectangle(cornerRadius: 13).stroke((tint ?? accent).opacity(0.18), lineWidth: 1))
    }
    private func detail(_ text: String, lines: Int = 2, size: CGFloat = 12) -> some View {
        Text(text).font(.system(size: size)).foregroundStyle(ink.opacity(0.72)).lineLimit(lines)
    }
    private var progress: some View {
        GeometryReader { proxy in
            Capsule().fill(ink.opacity(0.08)).overlay(alignment: .leading) {
                Capsule().fill(accent).frame(width: proxy.size.width * min(1, max(0, card.progress ?? 0)))
            }
        }.frame(height: 4)
    }

    private var fasting: some View {
        VStack(alignment: .leading, spacing: 7) {
            header("ΝΗΣΤΕΙΑ", symbol: card.symbol)
            title(fastingTitle, size: large ? 24 : 18, lines: 2).invalidatableContent()
            detail(card.detail, lines: small ? 4 : 2, size: small ? 11 : 12).invalidatableContent()
            if large {
                Divider()
                monthGrid
            } else if !small {
                Spacer(minLength: 0)
                weekRail
            } else { Spacer(minLength: 0) }
        }
    }
    private var fastingTitle: String {
        switch card.themeKey {
        case "free": "Χωρίς νηστεία"
        case "no_meat": "Χωρίς κρέας"
        case "fish": "Επιτρέπεται ψάρι"
        case "oil_wine": "Λάδι και κρασί"
        case "xerophagy": "Ξηροφαγία"
        default: card.title
        }
    }
    private var selectedDate: Date { card.date ?? entry.snapshot.day }
    private var monthDays: [PhoneWidgetCard] {
        (entry.snapshot.fastingCalendar ?? []).filter {
            $0.date.map { calendar.isDate($0, equalTo: selectedDate, toGranularity: .month) } ?? false
        }
    }
    private var weekRail: some View {
        HStack(spacing: 3) {
            ForEach(0..<7, id: \.self) { offset in
                let date = calendar.date(byAdding: .day, value: offset, to: entry.date) ?? entry.date
                if let day = entry.snapshot.fastingCalendar?.first(where: { $0.date.map { calendar.isDate($0, inSameDayAs: date) } ?? false }) {
                    dayButton(day, height: 39, weekday: true)
                }
            }
        }
    }
    private var monthGrid: some View {
        let days = monthDays
        return VStack(spacing: 4) {
            HStack {
                monthButton(-1)
                Spacer(minLength: 0)
                Text(selectedDate.formatted(.dateTime.month(.wide).year().locale(Locale(identifier: "el_GR"))))
                    .font(.system(size: 12, weight: .semibold)).lineLimit(1)
                Spacer(minLength: 0)
                monthButton(1)
            }.foregroundStyle(accent)
            HStack(spacing: 4) {
                ForEach(Array(["Δ", "Τ", "Τ", "Π", "Π", "Σ", "Κ"].enumerated()), id: \.offset) { _, label in
                    Text(label).font(.system(size: 9, weight: .semibold)).frame(maxWidth: .infinity)
                }
            }.foregroundStyle(ink.opacity(0.55))
            if let first = days.first?.date {
                let leading = (calendar.component(.weekday, from: first) + 5) % 7
                let cells = ((leading + days.count + 6) / 7) * 7
                GeometryReader { geometry in
                    let height = max(16, (geometry.size.height - CGFloat(cells / 7 - 1) * 4) / CGFloat(cells / 7))
                    VStack(spacing: 4) {
                        ForEach(0..<(cells / 7), id: \.self) { row in
                            HStack(spacing: 4) {
                                ForEach(0..<7, id: \.self) { column in
                                    let index = row * 7 + column - leading
                                    if days.indices.contains(index) { dayButton(days[index], height: height) }
                                    else { Color.clear.frame(maxWidth: .infinity).frame(height: height) }
                                }
                            }
                        }
                    }
                }
            } else {
                detail("Άνοιξε την εφαρμογή για ενημέρωση του ημερολογίου.", lines: 3)
                Spacer(minLength: 0)
            }
            Text("Επίλεξε ημέρα για τον κανόνα νηστείας").font(.system(size: 10)).foregroundStyle(ink.opacity(0.55))
        }
    }
    private func monthButton(_ delta: Int) -> some View {
        let start = calendar.dateInterval(of: .month, for: selectedDate)?.start ?? selectedDate
        let next = calendar.date(byAdding: .month, value: delta, to: start) ?? start
        let available = entry.snapshot.fastingCalendar?.contains { $0.date.map { calendar.isDate($0, inSameDayAs: next) } ?? false } ?? false
        return Button(intent: HomeSelectFastingDateIntent(date: next)) {
            Image(systemName: delta < 0 ? "chevron.left" : "chevron.right").frame(width: 28, height: 24)
        }.buttonStyle(.plain).disabled(!available)
            .accessibilityLabel(delta < 0 ? "Προηγούμενος μήνας" : "Επόμενος μήνας")
    }
    private func dayButton(_ day: PhoneWidgetCard, height: CGFloat, weekday: Bool = false) -> some View {
        let date = day.date ?? selectedDate
        let selected = calendar.isDate(date, inSameDayAs: selectedDate)
        let tint = PhoneWidgetTheme.fasting(themeKey: day.themeKey, ornament: day.symbol).accent
        return Button(intent: HomeSelectFastingDateIntent(date: date)) {
            VStack(spacing: 2) {
                if weekday {
                    Text(date.formatted(.dateTime.weekday(.narrow).locale(Locale(identifier: "el_GR")))).font(.system(size: 8, weight: .bold))
                }
                Text("\(calendar.component(.day, from: date))").font(.system(size: 11, weight: selected ? .bold : .medium))
                Circle().fill(tint).frame(width: 4, height: 4)
            }
            .foregroundStyle(selected ? accent : ink).frame(maxWidth: .infinity).frame(height: height)
            .background(tint.opacity(selected ? 0.24 : 0.09), in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(selected ? accent : ink.opacity(0.08), lineWidth: selected ? 1.5 : 0.5))
        }.buttonStyle(.plain).accessibilityLabel("\(date.formatted(date: .abbreviated, time: .omitted)), \(day.title)")
    }

    private var story: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("ΓΕΡΟΝΤΙΚΟ", systemImage: "text.quote").font(.system(size: 9, weight: .bold)).tracking(1)
                Spacer(minLength: 0)
                let count = entry.snapshot.stories?.count ?? 0
                Text("\(count == 0 ? 0 : entry.storyIndex + 1)/\(count)").font(.caption2).invalidatableContent()
            }.foregroundStyle(accent)
            title(card.title, size: large ? 24 : small ? 15 : 17, lines: small ? 3 : 2).invalidatableContent()
            if !small {
                Text(card.detail).font(.system(size: large ? 17 : 13, design: .serif))
                    .foregroundStyle(ink.opacity(0.75)).lineSpacing(large ? 4 : 2).lineLimit(large ? 7 : 2)
            }
            if large {
                if let reference = card.secondaryDetail { detail(reference, size: 11) }
                if let reflection = card.reflection {
                    Divider()
                    detail("ΓΙΑ ΣΚΕΨΗ", size: 9)
                    detail(reflection, lines: 3, size: 13)
                }
            }
            Spacer(minLength: 0)
            HStack {
                ForEach(0..<(entry.snapshot.stories?.count ?? 0), id: \.self) { index in
                    Capsule().fill(index == entry.storyIndex ? accent : ink.opacity(0.15))
                        .frame(width: index == entry.storyIndex ? 16 : 5, height: 5)
                }
                Spacer(minLength: 0)
                Button(intent: HomeNextStoryIntent()) {
                    Image(systemName: "arrow.right").frame(width: 30, height: 24)
                }.buttonStyle(.plain).foregroundStyle(accent).accessibilityLabel("Επόμενη ιστορία")
            }
        }
    }

    private var streak: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "flame.fill").font(.system(size: small ? 30 : 38, weight: .bold)).foregroundStyle(.orange)
            if small { Spacer(minLength: 0) }
            HStack(alignment: .firstTextBaseline) {
                Text(card.value ?? "0").font(.system(size: large ? 46 : 34, weight: .black, design: .rounded))
                    .foregroundStyle(LinearGradient(colors: [.yellow, .orange, .red], startPoint: .top, endPoint: .bottom))
                if !small { Text("ημέρες συνέπειας").font(.headline) }
            }
            if small { detail("ημέρες συνέπειας", size: 11) }
            else {
                progress
                detail(card.detail)
                if large { Divider(); header("ΟΙ ΣΤΟΧΟΙ ΣΟΥ ΣΗΜΕΡΑ"); itemRows }
                Spacer(minLength: 0)
            }
        }
    }
    private var mediumStreak: some View {
        HStack(spacing: 16) {
            Image(systemName: "flame.fill").font(.system(size: 42, weight: .bold)).foregroundStyle(.orange).frame(width: 64)
            VStack(alignment: .leading, spacing: 6) {
                header("ΣΤΟΧΟΙ")
                HStack(alignment: .firstTextBaseline) {
                    Text(card.value ?? "0").font(.system(size: 34, weight: .black, design: .rounded))
                        .foregroundStyle(LinearGradient(colors: [.yellow, .orange, .red], startPoint: .top, endPoint: .bottom))
                    Text("ημέρες").font(.headline)
                }
                progress
                detail(card.detail, size: 11)
            }
        }.frame(maxHeight: .infinity)
    }
    private var mediumReading: some View {
        HStack(spacing: 16) {
            glyph("book.fill")
            VStack(alignment: .leading, spacing: 6) {
                header("ΣΥΝΕΧΕΙΑ ΑΝΑΓΝΩΣΗΣ")
                title(card.title, size: 20, lines: 1)
                Text(card.detail).font(.system(size: 13, design: .serif)).foregroundStyle(ink.opacity(0.72)).lineLimit(2)
            }
        }.frame(maxHeight: .infinity)
    }
    private var mediumAudio: some View {
        HStack(spacing: 14) {
            glyph("waveform", tint: .blue)
            VStack(alignment: .leading, spacing: 8) {
                Text("ΟΜΙΛΙΑ ΗΜΕΡΑΣ").font(.system(size: 9, weight: .bold)).tracking(1).foregroundStyle(.blue)
                title(card.title, size: 18, lines: 2)
                HStack(spacing: 12) {
                    progress
                    Link(destination: entry.kind.deepLink) {
                        Image(systemName: "play.fill").foregroundStyle(.white).frame(width: 34, height: 34).background(.blue, in: Circle())
                    }.accessibilityLabel("Άνοιγμα ομιλίας")
                }
            }
        }.frame(maxHeight: .infinity)
    }
    private var mediumEditorial: some View {
        HStack(spacing: 14) {
            VStack(spacing: 8) {
                glyph(card.symbol)
                if let value = card.value { Text(value).font(.system(size: 28, weight: .semibold, design: .rounded)) }
            }
            VStack(alignment: .leading, spacing: 7) {
                header(card.eyebrow)
                title(card.title, size: 18, lines: 2)
                detail(card.detail, lines: 2)
            }
        }.frame(maxHeight: .infinity)
    }
    private var reading: some View {
        VStack(alignment: .leading, spacing: 10) {
            glyph("book.fill")
            if small { Spacer(minLength: 0) }
            if !small { header("ΣΥΝΕΧΕΙΑ ΑΝΑΓΝΩΣΗΣ") }
            title(small ? "Συνέχεια" : card.title, size: small ? 17 : 20, lines: 2)
            if small { detail(card.title, size: 11) }
            else {
                Text(large ? (card.expandedText ?? card.detail) : card.detail)
                    .font(.system(size: large ? 17 : 13, design: .serif)).foregroundStyle(ink.opacity(0.75))
                    .lineSpacing(large ? 4 : 2).lineLimit(large ? 10 : 2)
                Spacer(minLength: 0)
            }
        }
    }
    private var audio: some View {
        VStack(alignment: .leading, spacing: 9) {
            if !small { glyph("waveform", tint: .blue) }
            Text("ΟΜΙΛΙΑ ΗΜΕΡΑΣ").font(.system(size: 9, weight: .bold)).tracking(1).foregroundStyle(.blue)
            title(card.title, size: small ? 15 : 19, lines: small ? 3 : 2)
            Spacer(minLength: 0)
            HStack(spacing: 14) {
                progress
                Link(destination: entry.kind.deepLink) {
                    Image(systemName: "play.fill").font(.system(size: 18, weight: .semibold)).foregroundStyle(.white)
                        .frame(width: 38, height: 38).background(.blue, in: Circle())
                }.accessibilityLabel("Άνοιγμα ομιλίας")
            }
            if large { Divider(); detail(card.detail, lines: 3); itemRows }
        }
    }
    private var editorial: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                glyph(card.symbol)
                Spacer(minLength: 0)
                if let value = card.value { Text(value).font(.system(size: 28, weight: .semibold, design: .rounded)) }
            }
            if small { Spacer(minLength: 0) }
            if !small { header(card.eyebrow) }
            title(card.title, size: small ? 15 : large ? 24 : 18, lines: small ? 3 : large ? 5 : 2)
            detail(card.detail, lines: large ? 3 : 2, size: small ? 10 : 12)
            if large {
                Divider()
                if let text = card.expandedText ?? card.reflection {
                    Text(text).font(.system(size: 15, design: .serif)).lineSpacing(4).lineLimit(8)
                } else { itemRows }
            }
            if !small { Spacer(minLength: 0) }
        }
    }
    private var itemRows: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(card.items.prefix(3)) { item in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: item.symbol).foregroundStyle(accent).frame(width: 18)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.title).font(.system(size: 13, weight: .semibold)).lineLimit(2)
                        if !item.detail.isEmpty { detail(item.detail, size: 11) }
                    }
                }
            }
        }
    }

    private var nearby: some View {
        VStack(alignment: .leading) {
            Text("Κοντά σου").font(.system(size: small ? 18 : 22, weight: .bold))
            Spacer(minLength: 0)
            HStack {
                Spacer(minLength: 0)
                Image(systemName: "cross.fill").font(.system(size: 26, weight: .bold))
                    .foregroundStyle(HomeWidgetStyle.burgundy).frame(width: 50, height: 50)
                    .background(.white.opacity(0.92), in: Circle())
                Spacer(minLength: 0)
            }
            Spacer(minLength: 0)
            Text("Ναοί κοντά σου").font(.system(size: 12, weight: .semibold))
            if large { Text("Άνοιξε τον χάρτη για αναζήτηση στην περιοχή σου").font(.caption) }
        }.foregroundStyle(entry.mapImage == nil ? ink : .white)
    }

    private var feast: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 12) {
                VStack(spacing: 0) {
                    Text(entry.snapshot.day.formatted(.dateTime.month(.abbreviated).locale(Locale(identifier: "el_GR"))).uppercased())
                        .font(.system(size: large ? 9 : 8, weight: .black)).foregroundStyle(.white.opacity(0.88))
                    Text(card.value ?? entry.snapshot.day.formatted(.dateTime.day()))
                        .font(.system(size: large ? 26 : 20, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                }.frame(width: large ? 42 : 34, height: large ? 44 : 34)
                    .background(HomeWidgetStyle.burgundy, in: RoundedRectangle(cornerRadius: large ? 17 : 14))
                    .overlay(RoundedRectangle(cornerRadius: large ? 17 : 14).stroke(.white.opacity(0.28), lineWidth: 1))
                if !small {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("ΕΟΡΤΟΛΟΓΙΟ").font(.system(size: 10, weight: .bold)).tracking(1).foregroundStyle(accent)
                        detail("Οι μνήμες της ημέρας", size: 11)
                    }
                }
                Spacer(minLength: 0)
            }
            title(small ? "Εορτολόγιο" : card.title, size: small ? 16 : large ? 22 : 17, lines: small ? 1 : 2)
            detail(card.secondaryDetail ?? card.detail, lines: small ? 2 : 1, size: 11)
            if large {
                Divider()
                header("ΤΙΣ ΕΠΟΜΕΝΕΣ ΗΜΕΡΕΣ")
                itemRows
            }
            Spacer(minLength: 0)
        }
    }
}
