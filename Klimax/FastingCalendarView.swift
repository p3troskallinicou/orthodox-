import SwiftUI

struct FastingCalendarView: View {
    @State private var monthAnchor: Date
    @State private var selected: Date
    private let levels: [FastingLevel] = [.xerophagy, .oilWine, .fish, .noMeat, .free]

    init(date: Date = Date()) {
        _monthAnchor = State(initialValue: CalendarMonthLayout.start(of: date))
        _selected = State(initialValue: Paschalion.cal.startOfDay(for: date))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                LiturgicalMonthCalendar(month: $monthAnchor, selected: $selected) { date in
                    let level = FastingCalendar.shared.level(for: date)
                    return [CalendarDayIndicator(color: level.cardTint, label: level.cardTitle)]
                }
                CalendarDayAgenda(date: selected) {
                    let level = FastingCalendar.shared.level(for: selected)
                    CalendarAgendaRow(tint: level.cardTint) {
                        VStack(alignment: .leading, spacing: 7) {
                            Label(level.cardTitle, systemImage: level.cardIcon)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(Paper.ink)
                            Text(level.cardGuidance)
                                .font(.subheadline)
                                .foregroundStyle(Paper.inkSoft)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                DisclosureGroup("Χρώματα νηστείας") {
                    VStack(spacing: 12) {
                        ForEach(levels, id: \.self) { level in
                            HStack(spacing: 10) {
                                Circle().fill(level.cardTint).frame(width: 7, height: 7)
                                Text(level.shortName).font(.subheadline).foregroundStyle(Paper.inkSoft)
                                Spacer()
                            }
                        }
                    }.padding(.top, 14)
                }
                .font(.subheadline.weight(.medium))
            }
            .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 32)
            .frame(maxWidth: 680).frame(maxWidth: .infinity)
        }
        .modifier(CalendarScreenStyle(title: "Νηστειοδρόμιο"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                CalendarTodayButton(month: $monthAnchor, selected: $selected)
            }
        }
    }
}

// The same month grid and agenda system serves both calendar data sources.
enum CalendarMonthLayout {
    static func start(of date: Date, calendar: Calendar = Paschalion.cal) -> Date {
        calendar.dateInterval(of: .month, for: date)?.start ?? date
    }

    static func cells(for date: Date, calendar: Calendar = Paschalion.cal) -> [Date?] {
        let first = start(of: date, calendar: calendar)
        guard let days = calendar.range(of: .day, in: .month, for: first) else { return [] }
        let leading = (calendar.component(.weekday, from: first) + 5) % 7
        var cells: [Date?] = Array(repeating: nil, count: leading)
        cells += days.map { calendar.date(byAdding: .day, value: $0 - 1, to: first) }
        while cells.count % 7 != 0 { cells.append(nil) }
        return cells
    }

    static func selection(in month: Date, preserving date: Date, calendar: Calendar = Paschalion.cal) -> Date {
        let first = start(of: month, calendar: calendar)
        let last = calendar.range(of: .day, in: .month, for: first)?.count ?? 1
        let day = min(calendar.component(.day, from: date), last)
        return calendar.date(byAdding: .day, value: day - 1, to: first) ?? first
    }

    static func label(_ date: Date, format: String, calendar: Calendar = Paschalion.cal) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "el_GR")
        formatter.dateFormat = format
        return formatter.string(from: date)
    }
}

struct CalendarDayIndicator {
    let color: Color
    let label: String
}

struct LiturgicalMonthCalendar: View {
    @Binding var month: Date
    @Binding var selected: Date
    var calendar = Paschalion.cal
    let indicators: (Date) -> [CalendarDayIndicator]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let weekdays = ["Δ", "Τ", "Τ", "Π", "Π", "Σ", "Κ"]

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(CalendarMonthLayout.label(month, format: "yyyy", calendar: calendar))
                        .font(.subheadline.weight(.semibold)).foregroundStyle(Gild.accentForeground)
                    Text(CalendarMonthLayout.label(month, format: "LLLL", calendar: calendar).capitalized)
                        .font(.system(size: 32, weight: .bold)).foregroundStyle(Paper.ink)
                        .minimumScaleFactor(0.75).lineLimit(1)
                }
                .accessibilityElement(children: .combine)
                Spacer(minLength: 4)
                monthButton("chevron.left", label: "Προηγούμενος μήνας", delta: -1)
                monthButton("chevron.right", label: "Επόμενος μήνας", delta: 1)
            }
            HStack(spacing: 0) {
                ForEach(weekdays.indices, id: \.self) { index in
                    Text(weekdays[index])
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(index > 4 ? Paper.inkMute : Paper.inkSoft)
                        .frame(maxWidth: .infinity).accessibilityHidden(true)
                }
            }
            let cells = CalendarMonthLayout.cells(for: month, calendar: calendar)
            VStack(spacing: 0) {
                ForEach(0..<(cells.count / 7), id: \.self) { week in
                    Rectangle().fill(Paper.hairline).frame(height: 0.5)
                    HStack(spacing: 0) {
                        ForEach(0..<7, id: \.self) { weekday in
                            if let day = cells[week * 7 + weekday] {
                                dayButton(day, weekend: weekday > 4)
                            } else {
                                Color.clear.frame(maxWidth: .infinity).frame(height: 58)
                                    .accessibilityHidden(true)
                            }
                        }
                    }
                }
            }
        }
    }

    private func monthButton(_ symbol: String, label: String, delta: Int) -> some View {
        Button {
            guard let next = calendar.date(byAdding: .month, value: delta, to: CalendarMonthLayout.start(of: month, calendar: calendar)) else { return }
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) {
                month = next
                selected = CalendarMonthLayout.selection(in: next, preserving: selected, calendar: calendar)
            }
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .semibold)).foregroundStyle(Gild.accentForeground)
                .frame(width: 44, height: 44).contentShape(Rectangle())
        }
        .buttonStyle(.plain).accessibilityLabel(label)
    }

    private func dayButton(_ date: Date, weekend: Bool) -> some View {
        let chosen = calendar.isDate(date, inSameDayAs: selected)
        let today = calendar.isDate(date, inSameDayAs: Date())
        let marks = indicators(date)
        return Button {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.15)) { selected = date }
        } label: {
            VStack(spacing: 3) {
                Text("\(calendar.component(.day, from: date))")
                    .font(.system(size: 19, weight: chosen || today ? .semibold : .regular))
                    .monospacedDigit()
                    .foregroundStyle(chosen ? Gild.onGold : today ? Gild.accentForeground : weekend ? Paper.inkMute : Paper.ink)
                    .frame(width: 34, height: 34)
                    .background(chosen ? Paper.gold : .clear, in: Circle())
                HStack(spacing: 3) {
                    ForEach(Array(marks.prefix(3).enumerated()), id: \.offset) { _, mark in
                        Circle().fill(mark.color).frame(width: 5, height: 5)
                    }
                }.frame(height: 5)
            }
            .frame(maxWidth: .infinity).frame(height: 58).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(CalendarMonthLayout.label(date, format: "EEEE, d MMMM yyyy", calendar: calendar))
        .accessibilityValue(([today ? "Σήμερα" : ""] + marks.map(\.label)).filter { !$0.isEmpty }.joined(separator: ", "))
        .accessibilityAddTraits(chosen ? .isSelected : [])
    }
}

struct CalendarTodayButton: View {
    @Binding var month: Date
    @Binding var selected: Date
    var calendar = Paschalion.cal
    var body: some View {
        Button("Σήμερα") {
            selected = calendar.startOfDay(for: Date())
            month = CalendarMonthLayout.start(of: selected, calendar: calendar)
        }
        .font(.system(size: 15, weight: .semibold)).tint(Gild.accentForeground)
    }
}

struct CalendarDayAgenda<Content: View>: View {
    let date: Date
    var calendar = Paschalion.cal
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(CalendarMonthLayout.label(date, format: "EEEE, d MMMM", calendar: calendar).capitalized)
                .font(.system(size: 20, weight: .bold)).foregroundStyle(Paper.ink)
                .accessibilityAddTraits(.isHeader)
            content
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct CalendarAgendaRow<Content: View>: View {
    let tint: Color
    @ViewBuilder var content: Content
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("Όλη\nμέρα").font(.caption).foregroundStyle(Paper.inkMute)
                .frame(width: 36, alignment: .trailing).padding(.top, 2)
            content
                .frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 13)
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2).fill(tint).frame(width: 3)
                }
        }.padding(.vertical, 5)
    }
}

struct CalendarScreenStyle: ViewModifier {
    let title: String
    func body(content: Content) -> some View {
        content
            .background { AppAtmosphere().ignoresSafeArea() }
            .navigationTitle(title).navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .tint(Gild.accentForeground)
    }
}
