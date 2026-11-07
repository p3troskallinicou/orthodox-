//
//  TodayView.swift
//  Klimax
//
//  The home tab, kept deliberately quiet, the opposite of a busy dashboard.
//  A greeting, a single place to continue, one verse to sit with, and a gentle
//  glance at the user's goals. Nothing that nags.
//

import SwiftUI
import MapKit
import UniformTypeIdentifiers
import UIKit

private enum TodayWidgetID: String, CaseIterable, Codable, Identifiable {
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

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sundayLiturgy: return "Θεία Λειτουργία"
        case .didaches: return "Διδαχές"
        case .dailyStories: return "Γεροντικό"
        case .continueReading: return "Συνέχεια Γραφής"
        case .verse: return "Χωρίο ημέρας"
        case .fasting: return "Νηστεία"
        case .feastCalendar: return "Εορτολόγιο"
        case .saints: return "Άγιοι ημέρας"
        case .streaks: return "Στόχοι"
        case .nearby: return "Κοντά σου"
        }
    }

    var icon: String {
        switch self {
        case .sundayLiturgy: return "cross.fill"
        case .didaches: return "waveform"
        case .dailyStories: return "text.quote"
        case .continueReading: return "book.fill"
        case .verse: return "book.closed.fill"
        case .fasting: return "leaf.fill"
        case .feastCalendar: return "calendar"
        case .saints: return "seal.fill"
        case .streaks: return "flame.fill"
        case .nearby: return "mappin.circle.fill"
        }
    }
}

private enum TodayWidgetSize: String, CaseIterable, Codable, Identifiable {
    case small
    case wide
    case large

    var id: String { rawValue }
    var title: String {
        switch self {
        case .small: return "Μικρό"
        case .wide: return "Μεσαίο"
        case .large: return "Μεγάλο"
        }
    }

    var icon: String {
        switch self {
        case .small: return "square"
        case .wide: return "rectangle"
        case .large: return "square.grid.2x2"
        }
    }

    var columns: Int {
        switch self {
        case .small: return 1
        case .wide, .large: return 2
        }
    }

}

private struct TodayWidgetConfig: Identifiable, Codable, Equatable {
    var id: TodayWidgetID
    var size: TodayWidgetSize
    var isVisible = true

    static let defaultLayout: [TodayWidgetConfig] = [
        .init(id: .streaks, size: .small),
        .init(id: .continueReading, size: .small),
        .init(id: .fasting, size: .wide),
        .init(id: .dailyStories, size: .small),
        .init(id: .didaches, size: .small),
        .init(id: .sundayLiturgy, size: .wide),
        .init(id: .feastCalendar, size: .wide),
        .init(id: .nearby, size: .wide)
    ]
}

private struct TodayWidgetRow: Identifiable {
    let widgets: [TodayWidgetConfig]
    var id: String { widgets.map(\.id.rawValue).joined(separator: "-") }
}

private enum DayPlanKind: String, CaseIterable, Codable, Identifiable {
    case prayer, reading, fasting, quiet, church, personal, other

    var id: String { rawValue }
    var title: String {
        switch self {
        case .prayer: "Προσευχή"
        case .reading: "Ανάγνωση"
        case .fasting: "Ρυθμός"
        case .quiet: "Ησυχία"
        case .church: "Εκκλησία"
        case .personal: "Προσωπικό"
        case .other: "Άλλο"
        }
    }
    var icon: String {
        switch self {
        case .prayer: "hands.sparkles.fill"
        case .reading: "book.closed.fill"
        case .fasting: "leaf.fill"
        case .quiet: "pause.circle.fill"
        case .church: "building.columns.fill"
        case .personal: "sparkles"
        case .other: "square.grid.2x2.fill"
        }
    }
    var tint: Color {
        switch self {
        case .prayer: Paper.gold
        case .reading: Color(red: 0.36, green: 0.18, blue: 0.25)
        case .fasting: Color(red: 0.43, green: 0.52, blue: 0.32)
        case .quiet: Color(red: 0.48, green: 0.32, blue: 0.46)
        case .church: Color(red: 0.66, green: 0.48, blue: 0.20)
        case .personal: Color(red: 0.30, green: 0.52, blue: 0.58)
        case .other: Color(red: 0.46, green: 0.44, blue: 0.40)
        }
    }
}

private enum DayPlanCadenceType: String, CaseIterable, Codable, Identifiable {
    case once, daily, weekly, weekdays

    var id: String { rawValue }
    var title: String {
        switch self {
        case .once: "Μόνο αυτή την ημέρα"
        case .daily: "Κάθε μέρα"
        case .weekly: "Κάθε εβδομάδα"
        case .weekdays: "Συγκεκριμένες ημέρες"
        }
    }
}

private struct DayPlanCadence: Codable, Hashable {
    var type: DayPlanCadenceType = .once
    var weekdays: Set<Int> = []

    var title: String {
        switch type {
        case .once, .daily, .weekly: return type.title
        case .weekdays:
            let labels = Dictionary(uniqueKeysWithValues: GoalCadence.weekdayOptions.map { ($0.value, $0.label) })
            let value = weekdays.sorted().compactMap { labels[$0] }.joined(separator: ", ")
            return value.isEmpty ? type.title : value
        }
    }
}

private struct DayPlanItem: Codable, Hashable, Identifiable {
    var id = UUID()
    var dayKey: Int
    var title: String
    var detail: String
    var kind: DayPlanKind
    var customKind = ""
    var categoryID: UUID?
    var colorID: String?
    var cadence = DayPlanCadence()
    var linkedGoalID: UUID?
    var order = 0
    var isComplete = false
    var completedDayKeys: Set<Int> = []
    var createdAt = Date()

    var kindTitle: String {
        kind == .other && !customKind.isEmpty ? customKind : kind.title
    }

    enum CodingKeys: String, CodingKey {
        case id, dayKey, title, detail, kind, customKind, categoryID, colorID, cadence, linkedGoalID, order, isComplete, completedDayKeys, createdAt
    }

    init(
        id: UUID = UUID(),
        dayKey: Int,
        title: String,
        detail: String,
        kind: DayPlanKind,
        customKind: String = "",
        categoryID: UUID? = nil,
        colorID: String? = nil,
        cadence: DayPlanCadence = DayPlanCadence(),
        linkedGoalID: UUID? = nil,
        order: Int = 0,
        isComplete: Bool = false,
        completedDayKeys: Set<Int> = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.dayKey = dayKey
        self.title = title
        self.detail = detail
        self.kind = kind
        self.customKind = customKind
        self.categoryID = categoryID
        self.colorID = colorID
        self.cadence = cadence
        self.linkedGoalID = linkedGoalID
        self.order = order
        self.isComplete = isComplete
        self.completedDayKeys = completedDayKeys
        self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(UUID.self, forKey: .id)) ?? UUID()
        dayKey = (try? c.decode(Int.self, forKey: .dayKey)) ?? 0
        title = (try? c.decode(String.self, forKey: .title)) ?? ""
        detail = (try? c.decode(String.self, forKey: .detail)) ?? ""
        kind = (try? c.decode(DayPlanKind.self, forKey: .kind)) ?? .personal
        customKind = (try? c.decode(String.self, forKey: .customKind)) ?? ""
        categoryID = try? c.decodeIfPresent(UUID.self, forKey: .categoryID)
        colorID = try? c.decodeIfPresent(String.self, forKey: .colorID)
        cadence = (try? c.decode(DayPlanCadence.self, forKey: .cadence)) ?? DayPlanCadence()
        linkedGoalID = try? c.decodeIfPresent(UUID.self, forKey: .linkedGoalID)
        order = (try? c.decode(Int.self, forKey: .order)) ?? 0
        isComplete = (try? c.decode(Bool.self, forKey: .isComplete)) ?? false
        completedDayKeys = (try? c.decode(Set<Int>.self, forKey: .completedDayKeys)) ?? []
        if isComplete && completedDayKeys.isEmpty { completedDayKeys.insert(dayKey) }
        createdAt = (try? c.decode(Date.self, forKey: .createdAt)) ?? Date()
    }
}

@MainActor
private final class TodayDayPlanStore: ObservableObject {
    static let shared = TodayDayPlanStore()

    @Published private(set) var items: [DayPlanItem] = []
    private let defaults: UserDefaults
    private let storageKey = "today.dayPlan.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([DayPlanItem].self, from: data) {
            items = decoded
        }
    }

    func items(on date: Date) -> [DayPlanItem] {
        let key = Self.dayKey(date)
        let weekday = Calendar.current.component(.weekday, from: date)
        return items.filter { item in
            guard key >= item.dayKey else { return false }
            switch item.cadence.type {
            case .once: return item.dayKey == key
            case .daily: return true
            case .weekly: return weekday == Self.weekday(for: item.dayKey)
            case .weekdays: return item.cadence.weekdays.contains(weekday)
            }
        }
        .sorted { lhs, rhs in
            lhs.order == rhs.order ? lhs.createdAt < rhs.createdAt : lhs.order < rhs.order
        }
    }

    func add(
        title: String,
        detail: String,
        kind: DayPlanKind,
        customKind: String,
        cadence: DayPlanCadence,
        categoryID: UUID? = nil,
        colorID: String? = nil,
        on date: Date
    ) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let nextOrder = (items(on: date).map(\.order).max() ?? -1) + 1
        items.append(DayPlanItem(
            dayKey: Self.dayKey(date),
            title: trimmed,
            detail: detail.trimmingCharacters(in: .whitespacesAndNewlines),
            kind: kind,
            customKind: customKind.trimmingCharacters(in: .whitespacesAndNewlines),
            categoryID: categoryID,
            colorID: colorID,
            cadence: cadence,
            order: nextOrder
        ))
        persist()
    }

    func addLinkedGoal(_ goal: StreakGoal, on date: Date) {
        let key = Self.dayKey(date)
        guard !items.contains(where: { $0.linkedGoalID == goal.id && $0.dayKey == key }) else { return }
        let nextOrder = (items(on: date).map(\.order).max() ?? -1) + 1
        items.append(DayPlanItem(
            dayKey: key,
            title: goal.title,
            detail: goal.subtitle,
            kind: .personal,
            customKind: "Στόχος",
            cadence: DayPlanCadence(),
            linkedGoalID: goal.id,
            order: nextOrder
        ))
        persist()
    }

    func link(_ item: DayPlanItem, to goal: StreakGoal) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].linkedGoalID = goal.id
        persist()
    }

    func update(
        _ item: DayPlanItem,
        title: String,
        detail: String,
        kind: DayPlanKind,
        customKind: String,
        cadence: DayPlanCadence,
        categoryID: UUID? = nil,
        colorID: String? = nil
    ) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var updated = items[index]
        updated.title = trimmed
        updated.detail = detail.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.kind = kind
        updated.customKind = customKind.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.cadence = cadence
        updated.categoryID = categoryID
        updated.colorID = colorID
        items[index] = updated
        persist()
    }

    func isComplete(_ item: DayPlanItem, on date: Date) -> Bool {
        item.completedDayKeys.contains(Self.dayKey(date))
    }

    func toggle(_ item: DayPlanItem, on date: Date) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        let key = Self.dayKey(date)
        var updated = items[index]
        if updated.completedDayKeys.contains(key) {
            updated.completedDayKeys.remove(key)
        } else {
            updated.completedDayKeys.insert(key)
        }
        updated.isComplete = updated.completedDayKeys.contains(updated.dayKey)
        items[index] = updated
        persist()
    }

    func delete(_ item: DayPlanItem) {
        items.removeAll { $0.id == item.id }
        persist()
    }

    func move(_ movingID: UUID, before targetID: UUID, on date: Date) {
        var visible = items(on: date)
        guard let from = visible.firstIndex(where: { $0.id == movingID }),
              let to = visible.firstIndex(where: { $0.id == targetID }), from != to else { return }
        let moved = visible.remove(at: from)
        visible.insert(moved, at: to)
        let orders = Dictionary(uniqueKeysWithValues: visible.enumerated().map { ($0.element.id, $0.offset) })
        var updated = items
        for index in updated.indices {
            if let order = orders[updated[index].id] { updated[index].order = order }
        }
        items = updated
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        defaults.set(data, forKey: storageKey)
    }

    private static func dayKey(_ date: Date) -> Int {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return (parts.year ?? 0) * 10_000 + (parts.month ?? 0) * 100 + (parts.day ?? 0)
    }

    private static func weekday(for dayKey: Int) -> Int {
        let year = dayKey / 10_000
        let month = (dayKey / 100) % 100
        let day = dayKey % 100
        let date = Calendar.current.date(from: DateComponents(year: year, month: month, day: day)) ?? Date()
        return Calendar.current.component(.weekday, from: date)
    }
}

/// Gives every Today row an exact two-column geometry. Unlike a flexible
/// `HStack`, this never falls back to the cards' intrinsic content widths.
/// Apple's published Home Screen point sizes, not percentages of a card.
/// Unlisted/windowed sizes use the nearest profile, scaled down only to fit.
private struct TodayWidgetMetrics {
    let small: CGFloat
    let medium: CGFloat
    let mediumHeight: CGFloat
    let largeHeight: CGFloat
    var gap: CGFloat { medium - small * 2 }

    static func resolve(screen: CGSize, availableWidth: CGFloat) -> Self {
        let profiles: [(CGFloat, CGFloat, CGFloat, CGFloat, CGFloat)] = [
            (320, 568, 141, 292, 311), (375, 667, 148, 321, 324),
            (375, 812, 155, 329, 345), (390, 844, 158, 338, 354),
            (393, 852, 158, 338, 354), (414, 736, 159, 348, 357),
            (414, 896, 169, 360, 379), (428, 926, 170, 364, 382),
            (430, 932, 170, 364, 382)
        ]
        let portraitWidth = min(screen.width, screen.height)
        let portraitHeight = max(screen.width, screen.height)
        let profile = profiles.min {
            abs($0.0 - portraitWidth) * 10 + abs($0.1 - portraitHeight)
                < abs($1.0 - portraitWidth) * 10 + abs($1.1 - portraitHeight)
        }!
        let scale = min(1, max(0, availableWidth) / profile.3)
        return Self(small: profile.2 * scale, medium: profile.3 * scale,
                    mediumHeight: (profile.0 == 414 && profile.1 == 736 ? 157 : profile.2) * scale,
                    largeHeight: profile.4 * scale)
    }
}

private struct TodayWidgetRowLayout: Layout {
    let size: TodayWidgetSize
    let spacing: CGFloat

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let width = proposal.width ?? 0
        let metrics = TodayWidgetMetrics.resolve(screen: UIScreen.main.bounds.size, availableWidth: width)
        let height: CGFloat
        switch size {
        case .small: height = metrics.small
        case .wide: height = metrics.mediumHeight
        case .large: height = metrics.largeHeight
        }
        return CGSize(width: width, height: height)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let metrics = TodayWidgetMetrics.resolve(screen: UIScreen.main.bounds.size, availableWidth: bounds.width)
        let side = metrics.small
        let leading = bounds.minX + (bounds.width - metrics.medium) / 2
        if size == .small {
            for (index, subview) in subviews.enumerated() {
                subview.place(
                    at: CGPoint(x: leading + CGFloat(index) * (side + metrics.gap), y: bounds.minY),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(width: side, height: side)
                )
            }
        } else {
            subviews.first?.place(
                at: CGPoint(x: leading, y: bounds.minY),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: metrics.medium, height: bounds.height)
            )
        }
    }
}

private struct TodayWidgetBoardLayout: Layout {
    let sizes: [TodayWidgetSize]
    let spacing: CGFloat
    func frames(width: CGFloat) -> [CGRect] {
        let m = TodayWidgetMetrics.resolve(screen: UIScreen.main.bounds.size, availableWidth: width)
        let left = (width - m.medium) / 2
        var result: [CGRect] = []
        var y: CGFloat = 0
        var pendingSmall = false
        for size in sizes {
            if size == .small {
                result.append(CGRect(x: left + (pendingSmall ? m.small + m.gap : 0), y: y, width: m.small, height: m.small))
                if pendingSmall { y += m.small + spacing }
                pendingSmall.toggle()
            } else {
                if pendingSmall { y += m.small + spacing; pendingSmall = false }
                let height = size == .large ? m.largeHeight : m.mediumHeight
                result.append(CGRect(x: left, y: y, width: m.medium, height: height))
                y += height + spacing
            }
        }
        return result
    }
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        return CGSize(width: width, height: frames(width: width).map(\.maxY).max() ?? 0)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for (view, frame) in zip(subviews, frames(width: bounds.width)) {
            view.place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY), anchor: .topLeading,
                       proposal: ProposedViewSize(width: frame.width, height: frame.height))
        }
    }
}

// Gallery samples deliberately keep their content stable while the pager moves.
// In particular, calendar calculations and embedded maps must not rebuild for
// every change to the finger's horizontal position.
private struct WidgetGallerySample: View, Equatable {
    let identity: String
    let size: TodayWidgetSize
    let width: CGFloat
    let height: CGFloat
    let content: (TodayWidgetSize) -> AnyView
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.identity == rhs.identity && lhs.size == rhs.size && lhs.width == rhs.width && lhs.height == rhs.height
    }
    var body: some View {
        content(size)
            .frame(width: width, height: height)
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

private struct WidgetGalleryPreview: View {
    let title: String
    let alreadyAdded: Bool
    let content: (TodayWidgetSize) -> AnyView
    let onAdd: (TodayWidgetSize) -> Void
    @State private var selected: TodayWidgetSize = .small
    @GestureState(resetTransaction: Transaction(animation: .easeOut(duration: 0.22))) private var swipe: CGFloat = 0
    var body: some View {
        GeometryReader { geometry in
            let metrics = TodayWidgetMetrics.resolve(screen: UIScreen.main.bounds.size, availableWidth: geometry.size.width - 40)
            VStack(spacing: 16) {
                Text("Σύρε για να διαλέξεις μέγεθος")
                    .font(.subheadline).foregroundStyle(.secondary)
                GeometryReader { pager in
                HStack(spacing: 0) {
                    ForEach(TodayWidgetSize.allCases) { size in
                        VStack(spacing: 16) {
                            Spacer(minLength: 0)
                            WidgetGallerySample(identity: title, size: size,
                                width: size == .small ? metrics.small : metrics.medium,
                                height: size == .large ? metrics.largeHeight : size == .small ? metrics.small : metrics.mediumHeight,
                                content: content).equatable()
                            Text(size.title).font(.headline)
                            Spacer(minLength: 24)
                        }.frame(width: pager.size.width, height: pager.size.height)
                    }
                }
                .offset(x: -CGFloat(TodayWidgetSize.allCases.firstIndex(of: selected) ?? 0) * pager.size.width + swipe)
                .frame(width: pager.size.width, alignment: .leading)
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 12)
                    .updating($swipe) { value, state, _ in
                        if abs(value.translation.width) > abs(value.translation.height) {
                            let atEdge = (selected == .small && value.translation.width > 0) || (selected == .large && value.translation.width < 0)
                            state = value.translation.width * (atEdge ? 0.25 : 1)
                        }
                    }
                    .onEnded { value in
                        guard abs(value.translation.width) > 35,
                              abs(value.translation.width) > abs(value.translation.height) else { return }
                        let index = TodayWidgetSize.allCases.firstIndex(of: selected) ?? 0
                        let next = min(2, max(0, index + (value.translation.width < 0 ? 1 : -1)))
                        withAnimation(.easeOut(duration: 0.22)) { selected = TodayWidgetSize.allCases[next] }
                    })
                .clipped()
                }
                HStack(spacing: 12) {
                    ForEach(TodayWidgetSize.allCases) { size in
                        Button { withAnimation(.easeOut(duration: 0.22)) { selected = size } } label: {
                            Text(size.title).font(.caption.weight(.semibold)).padding(.horizontal, 12).padding(.vertical, 8)
                                .background(selected == size ? Gild.accentForeground.opacity(0.12) : .clear, in: Capsule())
                        }.buttonStyle(.plain).foregroundStyle(selected == size ? Gild.accentForeground : Paper.inkMute)
                    }
                }
                Button { onAdd(selected) } label: {
                    Text(alreadyAdded ? "Εφαρμογή μεγέθους" : "Προσθήκη widget")
                        .font(.headline).frame(maxWidth: .infinity).padding(16)
                }.buttonStyle(.borderedProminent).tint(Gild.accentForeground)
                    .padding(.horizontal, 24).padding(.bottom, 20)
            }.padding(.top, 20)
        }
        .background(Color(uiColor: .systemGroupedBackground)).navigationTitle(title).navigationBarTitleDisplayMode(.inline)
    }
}

struct TodayView: View {
    @Environment(ScriptureStore.self) private var store
    @ObservedObject private var lessonProgress = LessonProgressStore.shared
    @StateObject private var streaks = StreakStore.shared
    @StateObject private var dailyClip = DailyClipStore()
    @ObservedObject private var shortStories = ShortStoriesStore.shared
    @AppStorage("today.widgetLayout.v3") private var savedWidgetLayout = ""
    @State private var showChurchMap = false
    @State private var churchPreviewScale = 0.05
    @State private var churchPreviewCamera: MapCameraPosition = .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.9838, longitude: 23.7275),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)))
    @State private var isEditingDashboard = false
    @State private var jiggle = false
    @State private var widgets = TodayWidgetConfig.defaultLayout
    @State private var feastCalendar = OrthodoxFeastCalendarService()
    @State private var sundayService: SundayServicePackage?
    @State private var now = Date()
    @Namespace private var mapZoom

    // Saints catalogue, only to resolve today's commemorations to their pages.
    @State private var saintsStore = SaintsStore.shared
    @State private var selectedSaint: SaintEntry?
    @State private var fastingSelectedDate: Date?
    @State private var draggingWidget: TodayWidgetID?
    @State private var showWidgetGallery = false
    @State private var widgetBoardFrame: CGRect = .zero
    private var widgetFrames: [TodayWidgetID: CGRect] {
        let frames = TodayWidgetBoardLayout(sizes: displayedWidgets.map(\.size), spacing: widgetSpacing)
            .frames(width: widgetBoardFrame.width)
        return Dictionary(uniqueKeysWithValues: zip(displayedWidgets, frames).map {
            ($0.0.id, $0.1.offsetBy(dx: widgetBoardFrame.minX, dy: widgetBoardFrame.minY))
        })
    }
    @State private var headerCondensed = false
    @State private var selectedJourneyDate = Calendar.current.startOfDay(for: Date())
    @State private var showJourneyCalendar = false
    @State private var pagerCoordinator = TodayPagerCoordinator()
    private let widgetSpacing: CGFloat = 20

    private var displayedWidgets: [TodayWidgetConfig] {
        widgets.filter { widget in
            return widget.isVisible && (isEditingDashboard || isWidgetAvailable(widget.id))
        }
    }

    private func isWidgetAvailable(_ id: TodayWidgetID) -> Bool {
        switch id {
        case .sundayLiturgy:
            return sundayService != nil
        case .saints:
            return false
        case .continueReading:
            return store.continueReading() != nil
        default:
            return true
        }
    }

    private var widgetRows: [TodayWidgetRow] {
        var rows: [TodayWidgetRow] = []
        var index = 0
        while index < displayedWidgets.count {
            let current = displayedWidgets[index]
            if current.size == .small {
                let nextIndex = index + 1
                if nextIndex < displayedWidgets.count,
                   displayedWidgets[nextIndex].size == .small {
                    rows.append(TodayWidgetRow(widgets: [current, displayedWidgets[nextIndex]]))
                    index += 2
                } else {
                    rows.append(TodayWidgetRow(widgets: [current]))
                    index += 1
                }
            } else {
                rows.append(TodayWidgetRow(widgets: [current]))
                index += 1
            }
        }
        return rows
    }

    private var activeVirtue: Virtue {
        Virtue.all.first { $0.isAvailable } ?? Virtue.all[0]
    }

    private var lessonSections: [LessonSection] {
        LessonContent.sections(forVirtue: activeVirtue.id)
    }

    private var ladderLessons: [LessonContent] {
        lessonSections.flatMap(\.lessons)
    }

    private var completedLessonCount: Int {
        ladderLessons.filter { lessonProgress.isCompleted($0.id) }.count
    }

    private var nextLesson: LessonContent? {
        ladderLessons.first { !lessonProgress.isCompleted($0.id) } ?? ladderLessons.last
    }

    private var lessonProgressFraction: Double {
        guard !ladderLessons.isEmpty else { return 0 }
        return Double(completedLessonCount) / Double(ladderLessons.count)
    }

    var body: some View {
        todayPagerBody
        .toolbar(.hidden, for: .navigationBar)
        .fullScreenCover(isPresented: $showChurchMap) {
            ChurchMapView()
                .navigationTransition(.zoom(sourceID: "churchMap", in: mapZoom))
        }
        .task {
            await feastCalendar.loadCalendar()
            syncPhoneWidgets()
        }
        .task {
            await saintsStore.load()
            syncPhoneWidgets()
        }
        .task {
            await shortStories.load()
            syncPhoneWidgets()
        }
        .task {
            await dailyClip.load()
            syncPhoneWidgets()
        }
        .task(id: store.bible?.version) {
            loadSundayServiceFeature()
            syncPhoneWidgets()
        }
        .onAppear {
            widgets = loadSavedWidgets()
            syncPhoneWidgets()
            #if DEBUG
            let args = ProcessInfo.processInfo.arguments
            if let index = args.firstIndex(of: "-UITestWidgetSize"), args.indices.contains(index + 1),
               let size = TodayWidgetSize(rawValue: args[index + 1]) {
                // Visual QA only: never migrate or overwrite the saved layout.
                widgets = TodayWidgetID.allCases.filter { $0 != .saints }.map {
                    TodayWidgetConfig(id: $0, size: size)
                }
                if let focus = args.firstIndex(of: "-UITestWidgetFocus"), args.indices.contains(focus + 1) {
                    widgets = widgets.filter { $0.id.rawValue == args[focus + 1] }
                }
            }
            print("[Klimax][Today] premium glass home active")
            #endif
        }
        .onChange(of: isEditingDashboard) { _, editing in
            if editing {
                withAnimation(.easeInOut(duration: 0.14).repeatForever(autoreverses: true)) {
                    jiggle.toggle()
                }
            } else {
                draggingWidget = nil
                jiggle = false
                saveWidgets(widgets)
            }
        }
        .sheet(isPresented: $showWidgetGallery) {
            widgetGallery
                .presentationDetents([.large])
                .presentationCornerRadius(30)
                .presentationDragIndicator(.visible)
        }
        .onChange(of: streaks.globalCurrentStreak) { _, _ in syncPhoneWidgets() }
        .onChange(of: streaks.completedGoalsToday) { _, _ in syncPhoneWidgets() }
        .sheet(item: $selectedSaint) { saint in
            NavigationStack {
                SaintDetailView(saint: saint)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Κλείσιμο") { selectedSaint = nil }
                                .foregroundStyle(Paper.gold)
                        }
                    }
            }
        }
        .sheet(isPresented: $showJourneyCalendar) {
            journeyCalendarSheet
        }
    }

    private var todayPagerBody: some View {
        GeometryReader { geometry in
            TodayPageSwitcher(
            coordinator: pagerCoordinator,
            transitionTopInset: headerCondensed ? 58 : 76,
            dailyPage: TodayPlannerPage(selectedJourneyDate: $selectedJourneyDate, headerCondensed: $headerCondensed, pagerCoordinator: pagerCoordinator, bottomInset: geometry.safeAreaInsets.bottom),
            dashboardPage: dashboardPage.safeAreaPadding(.bottom, geometry.safeAreaInsets.bottom)
        ) { page, transitionInProgress, switchPage in
            todayHeader(
                page: page,
                transitionInProgress: transitionInProgress,
                switchPage: switchPage
            )
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
        }
    }

    private var dashboardPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Color.clear.frame(height: 82)

                dashboardIntroduction

                if isEditingDashboard {
                    Button { showWidgetGallery = true } label: {
                        Label("Προσθήκη widget", systemImage: "plus")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 18).padding(.vertical, 10)
                            .background(.ultraThinMaterial, in: Capsule())
                    }
                    .buttonStyle(.plain).foregroundStyle(Gild.accentForeground)
                    .padding(.horizontal, 24)
                }

                TodayWidgetBoardLayout(sizes: displayedWidgets.map(\.size), spacing: widgetSpacing) {
                            ForEach(displayedWidgets) { widget in
                                widgetContainer(widget)
                                    .modifier(ReorderModifier(
                                        editing: isEditingDashboard,
                                        widget: widget,
                                        widgets: $widgets,
                                        dragging: $draggingWidget,
                                        boardFrame: $widgetBoardFrame,
                                        onReorder: saveWidgets
                                    ))
                                    .onDrag {
                                        draggingWidget = widget.id
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        return NSItemProvider(object: widget.id.rawValue as NSString)
                                    }
                                    .onDrop(of: [UTType.text], delegate: WidgetDropDelegate(
                                        item: widget.id, widgets: $widgets,
                                        dragging: $draggingWidget, onReorder: saveWidgets
                                    ))
                            }
                }
                .onGeometryChange(for: CGRect.self) { proxy in
                    proxy.frame(in: .global)
                } action: { widgetBoardFrame = $0 }
                .padding(.horizontal, 20)
                Spacer(minLength: 34)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
        .onScrollGeometryChange(for: Bool.self) { geometry in
            geometry.contentOffset.y + geometry.contentInsets.top > 28
        } action: { _, condensed in
            if pagerCoordinator.selectedPage == 1, headerCondensed != condensed { headerCondensed = condensed }
        }
    }

    /// Γράφει στὸ App Group τὸ ἴδιο περιεχόμενο ποὺ βλέπει ὁ χρήστης στὴ
    /// σελίδα «Σήμερα». Τὸ Widget Extension διαβάζει μόνο αὐτὸ τὸ μικρὸ
    /// στιγμιότυπο καὶ ἔτσι παραμένει γρήγορο καὶ λειτουργεῖ offline.
    private func syncPhoneWidgets() {
        // Coalesce startup notifications and goal changes. Never rebuild the
        // extension snapshot in the middle of the completion/fade animation.
        pagerCoordinator.widgetRefreshTask?.cancel()
        pagerCoordinator.widgetRefreshTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(650))
            guard !Task.isCancelled else { return }
            writePhoneWidgetSnapshot()
        }
    }

    private func writePhoneWidgetSnapshot() {
        var cards = PhoneWidgetCard.sampleCards

        if let package = sundayService {
            cards[TodayWidgetID.sundayLiturgy.rawValue] = .init(
                eyebrow: "ΘΕΙΑ ΛΕΙΤΟΥΡΓΙΑ",
                title: package.sunday.titleEl,
                detail: "Ευαγγέλιον: \(package.services.divineLiturgy.gospel.displayEl)",
                symbol: "cross.fill",
                secondaryDetail: "Η κυριακάτικη ακολουθία συγκεντρωμένη σε ένα μέρος.",
                items: liturgyPreviewLines(package).map {
                    .init(symbol: "sparkle", title: $0, detail: "")
                }
            )
        }

        if let clip = dailyClip.clip {
            let duration = clip.durationSeconds.map { "\(max(1, $0 / 60)) λεπτά" } ?? "Σύντομη ακρόαση"
            cards[TodayWidgetID.didaches.rawValue] = .init(
                eyebrow: "ΔΙΔΑΧΕΣ",
                title: clip.title,
                detail: clip.hook ?? duration,
                symbol: "waveform",
                progress: PlaybackProgress.fraction(for: clip.id, duration: clip.durationSeconds),
                secondaryDetail: duration,
                items: [
                    .init(symbol: "play.circle.fill", title: "Άκουσε τώρα", detail: duration),
                    .init(symbol: "headphones", title: "Ηχητική διδασκαλία", detail: clip.topic ?? "Διδαχές")
                ]
            )
        } else if let last = LastListened.load() {
            cards[TodayWidgetID.didaches.rawValue] = .init(
                eyebrow: "ΣΥΝΕΧΙΣΕ ΑΚΡΟΑΣΗ",
                title: last.homily.title,
                detail: last.context,
                symbol: "play.fill",
                progress: PlaybackProgress.fraction(for: last.homily.id, duration: last.homily.durationSeconds),
                secondaryDetail: "Συνέχισε από το σημείο που σταμάτησες."
            )
        }

        let dailyStories = shortStories.daily(count: 3)
        if let story = dailyStories.first {
            cards[TodayWidgetID.dailyStories.rawValue] = .init(
                eyebrow: "ΓΕΡΟΝΤΙΚΟΝ",
                title: story.theme ?? story.father ?? "Ρητά της ημέρας",
                detail: story.text,
                symbol: "text.quote",
                value: "\(dailyStories.count)",
                secondaryDetail: "Τρείς μικρές στάσεις από το Γεροντικόν.",
                items: dailyStories.map {
                    .init(symbol: "quote.opening", title: $0.theme ?? $0.father ?? "Γεροντικόν", detail: $0.reference ?? "")
                }
            )
        }

        if let route = store.continueReading(), let book = store.book(id: route.bookID) {
            let opening = store.chapter(route)?.verses.first?.ancient ?? "Συνέχισε από εκεί που έμεινες"
            cards[TodayWidgetID.continueReading.rawValue] = .init(
                eyebrow: "ΣΥΝΕΧΕΙΑ ΑΝΑΓΝΩΣΗΣ",
                title: "\(book.titleGreek) \(route.chapterNumber)",
                detail: opening,
                symbol: "book.fill",
                secondaryDetail: "Συνέχισε από το κεφάλαιο \(route.chapterNumber).",
                items: [
                    .init(symbol: "bookmark.fill", title: "Τελευταίο σημείο", detail: "\(book.titleGreek) \(route.chapterNumber)"),
                    .init(symbol: "text.book.closed.fill", title: "Αγία Γραφή", detail: "Άνοιγμα αναγνώστη")
                ]
            )
        }

        if let vod = store.verseOfTheDay() {
            cards[TodayWidgetID.verse.rawValue] = .init(
                eyebrow: "ΧΩΡΙΟ ΗΜΕΡΑΣ",
                title: vod.verse.ancient,
                detail: "\(vod.book.titleGreek) \(vod.chapter.number)·\(vod.verse.number)",
                symbol: "book.closed.fill",
                secondaryDetail: "Χωρίο για μελέτη και περισυλλογή.",
                items: [
                    .init(symbol: "book.pages.fill", title: vod.book.titleGreek, detail: "Κεφάλαιο \(vod.chapter.number)"),
                    .init(symbol: "bookmark", title: "Στίχος \(vod.verse.number)", detail: "Άνοιγμα στην Αγία Γραφή")
                ]
            )
        }

        let fastDaysThisMonth = monthFastCount
        let fastingCards: [PhoneWidgetCard] = (0..<7).compactMap { offset in
            guard let date = Calendar.current.date(byAdding: .day, value: offset, to: now) else { return nil }
            let status = FastingCalendar.shared.status(for: date)
            let dayLabel = offset == 0 ? "ΣΗΜΕΡΑ" : (offset == 1 ? "ΑΥΡΙΟ" : fastingDayLabel(date).uppercased())
            return PhoneWidgetCard(
                eyebrow: "ΝΗΣΤΕΙΑ · \(dayLabel)",
                title: status.level.cardTitle,
                detail: status.level.cardGuidance,
                symbol: status.level.cardIcon,
                value: "\(Calendar.current.component(.day, from: date))",
                secondaryDetail: status.level.shortName,
                items: [
                    .init(symbol: status.level.cardIcon, title: status.level.shortName, detail: status.level.cardGuidance),
                    .init(symbol: "calendar", title: fastingDayLabel(date), detail: status.isFast ? "Ημέρα νηστείας" : "Ελεύθερη ημέρα"),
                    .init(symbol: "calendar.badge.checkmark", title: "Αυτόν τον μήνα", detail: "\(fastDaysThisMonth) ημέρες νηστείας")
                ],
                themeKey: status.level.rawValue
            )
        }
        if let todayFasting = fastingCards.first {
            cards[TodayWidgetID.fasting.rawValue] = todayFasting
        }

        if let day = feastCalendar.today(), let feast = day.feasts.first {
            let names = day.feasts.first(where: { !$0.namesCelebrated.isEmpty })?.namesCelebrated
                .prefix(3).joined(separator: ", ") ?? "Σήμερα"
            cards[TodayWidgetID.feastCalendar.rawValue] = .init(
                eyebrow: "ΕΟΡΤΟΛΟΓΙΟ",
                title: feast.title,
                detail: names.isEmpty ? "Σήμερα" : names,
                symbol: "calendar",
                value: "\(day.day)",
                secondaryDetail: names.isEmpty ? "Η σημερινή εκκλησιαστική μνήμη." : "Εορτάζουν: \(names)",
                items: upcomingFeastRows(limit: 3).map {
                    .init(symbol: "calendar.badge.clock", title: $0, detail: "")
                }
            )
        }

        if !todaysCatalogedSaints.isEmpty {
            cards[TodayWidgetID.saints.rawValue] = .init(
                eyebrow: "ΑΓΙΟΙ ΤΗΣ ΗΜΕΡΑΣ",
                title: todaysCatalogedSaints.prefix(2).map(\.displayName).joined(separator: " · "),
                detail: "\(todaysCatalogedSaints.count) μνήμες σήμερα",
                symbol: "seal.fill",
                value: "\(todaysCatalogedSaints.count)",
                secondaryDetail: "Γνώρισε τους βίους και τα απολυτίκια τους.",
                items: todaysCatalogedSaints.prefix(3).map {
                    .init(symbol: "person.crop.circle", title: $0.displayName, detail: $0.rankTitle ?? "")
                }
            )
        }

        let goalCount = streaks.goals.count
        let completed = streaks.completedGoalsToday
        let goalProgress = goalCount > 0 ? Double(completed) / Double(goalCount) : 0
        cards[TodayWidgetID.streaks.rawValue] = .init(
            eyebrow: "ΣΤΟΧΟΙ",
            title: streaks.completedToday ? "Οι σημερινοί στόχοι προχωρούν" : "Συνέχισε την πορεία",
            detail: goalCount > 0 ? "\(completed) από \(goalCount) στόχους σήμερα" : "Δημιούργησε τον πρώτο σου στόχο",
            symbol: "flame.fill",
            value: "\(streaks.globalCurrentStreak)",
            progress: goalProgress,
            secondaryDetail: streaks.completedToday ? "Υπάρχει σημερινή δραστηριότητα." : "Ένα μικρό βήμα αρκεί.",
            items: streaks.goals.prefix(3).map { goal in
                .init(
                    symbol: streaks.isDoneToday(goal) ? "checkmark.circle.fill" : goal.icon,
                    title: goal.title,
                    detail: streaks.isDoneToday(goal) ? "Ολοκληρώθηκε" : goal.subtitle
                )
            }
        )

        cards[TodayWidgetID.nearby.rawValue] = .init(
            eyebrow: "ΚΟΝΤΑ ΣΟΥ",
            title: "Ναοί κοντά σου",
            detail: "Άνοιγμα του χάρτη εκκλησιών",
            symbol: "mappin.circle.fill",
            secondaryDetail: "Βρές εκκλησίες στην περιοχή σου.",
            items: [
                .init(symbol: "location.fill", title: "Τρέχουσα περιοχή", detail: "Χρήση τοποθεσίας"),
                .init(symbol: "map.fill", title: "Χάρτης ναών", detail: "Άνοιγμα πλήρους χάρτη")
            ]
        )

        // Export the same civil dates and presentation as the in-app calendar.
        // Three months permit useful navigation without running app stores in
        // the extension. Dates outside this range are deliberately unavailable.
        let calendar = Calendar.current
        let monthStart = calendar.dateInterval(of: .month, for: now)?.start ?? now
        let calendarCards: [PhoneWidgetCard] = (-1...1).flatMap { monthOffset -> [PhoneWidgetCard] in
            guard let start = calendar.date(byAdding: .month, value: monthOffset, to: monthStart),
                  let days = calendar.range(of: .day, in: .month, for: start) else { return [] }
            return days.compactMap { day in
                guard let date = calendar.date(byAdding: .day, value: day - 1, to: start) else { return nil }
                let level = fastingWidgetLevel(for: date)
                return PhoneWidgetCard(eyebrow: "ΝΗΣΤΕΙΑ", title: fastingWidgetTitle(level),
                    detail: level.cardGuidance, symbol: level.cardIcon,
                    value: "\(day)", themeKey: level.rawValue, date: date)
            }
        }
        let storyCards = dailyStories.map { story in
            PhoneWidgetCard(eyebrow: "ΓΕΡΟΝΤΙΚΟ", title: (story.theme ?? story.father ?? "Ιστορίες ημέρας").interfaceGreek,
                detail: story.text, symbol: "text.quote", secondaryDetail: story.reference,
                reflection: story.meaning)
        }
        if let route = store.continueReading() {
            cards[TodayWidgetID.continueReading.rawValue]?.expandedText = store.chapter(route)?.verses.prefix(4)
                .map { "\($0.number). \($0.ancient)" }.joined(separator: "\n\n")
        }
        if let vod = store.verseOfTheDay() {
            cards[TodayWidgetID.verse.rawValue]?.reflection = vod.verse.modern
        }
        if let package = sundayService {
            cards[TodayWidgetID.sundayLiturgy.rawValue]?.expandedText = sundayApolytikion(package)
        }
        WidgetSharedStore.updateTodayCards(cards, fastingCards: fastingCards, fastingCalendar: calendarCards, stories: storyCards)
    }

    private var journeyCalendarSheet: some View {
        NavigationStack {
            VStack(spacing: 8) {
                DatePicker(
                    "Ημερομηνία",
                    selection: $selectedJourneyDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .tint(Paper.gold)
                .padding(.horizontal, 12)
                Spacer(minLength: 0)
            }
            .background(AppAtmosphere().ignoresSafeArea())
            .navigationTitle("Επιλογή ημέρας")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Έτοιμο") { showJourneyCalendar = false }
                        .foregroundStyle(Paper.gold)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func todayHeader(
        page: Int,
        transitionInProgress: Bool,
        switchPage: @escaping () -> Void
    ) -> some View {
        let condensed = headerCondensed
        return HStack(spacing: 14) {
            Image("OrthodoxWordmark")
                .resizable()
                .renderingMode(.template)
                .scaledToFit()
                .foregroundStyle(Paper.ink)
                .frame(width: condensed ? 132 : 154, height: condensed ? 36 : 42, alignment: .leading)
                .accessibilityLabel("Orthodox Plus")

            Spacer(minLength: 4)

            todayModeSwitch(
                page: page,
                transitionInProgress: transitionInProgress,
                switchPage: switchPage
            )

            if page == 0 {
                Button { showJourneyCalendar = true } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "calendar")
                            .font(.system(size: 14, weight: .bold))
                        Text(selectedJourneyDate.formatted(.dateTime.day()))
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(Paper.ink)
                    .padding(.horizontal, 13)
                    .frame(height: 40)
                    .todayLiquidGlass(cornerRadius: 20, interactive: true)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Άνοιγμα ημερολογίου")
            } else {
                headerButton(
                    icon: isEditingDashboard ? "checkmark" : "slider.horizontal.3",
                    accessibilityLabel: isEditingDashboard ? "Τέλος προσαρμογής Σήμερα" : "Προσαρμογή Σήμερα",
                    highlighted: isEditingDashboard
                ) {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                        isEditingDashboard.toggle()
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .frame(height: condensed ? 58 : 76)
        .background { AppHeaderSurface(condensed: condensed) }
        .animation(.smooth(duration: 0.28), value: condensed)
    }

    private func todayModeSwitch(
        page: Int,
        transitionInProgress: Bool,
        switchPage: @escaping () -> Void
    ) -> some View {
        let widgetsSelected = page == 1

        return Button(action: switchPage) {
            ZStack {
                Capsule()
                    .fill(widgetsSelected
                          ? Color(red: 0.17, green: 0.60, blue: 0.39)
                          : Color.adaptive(Paper.ink.opacity(0.10), .white.opacity(0.13)))

                HStack(spacing: 0) {
                    Image(systemName: "checkmark")
                        .frame(maxWidth: .infinity)
                    Image(systemName: "square.grid.2x2")
                        .frame(maxWidth: .infinity)
                }
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(widgetsSelected ? Color.white.opacity(0.82) : Paper.inkMute.opacity(0.72))
                .padding(.horizontal, 4)

                Circle()
                    .fill(Color.adaptive(.white, Color(red: 0.93, green: 0.93, blue: 0.91)))
                    .overlay {
                        Image(systemName: widgetsSelected ? "square.grid.2x2" : "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(widgetsSelected
                                             ? Color(red: 0.11, green: 0.48, blue: 0.30)
                                             : Paper.ink)
                    }
                    .shadow(color: .black.opacity(0.15), radius: 3, y: 1.5)
                    .frame(width: 30, height: 30)
                    .frame(maxWidth: .infinity, alignment: widgetsSelected ? .trailing : .leading)
                    .padding(3)
            }
            .frame(width: 68, height: 36)
            .overlay(Capsule().stroke(Color.white.opacity(0.32), lineWidth: 0.65))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Προβολή σελίδας Σήμερα")
        .accessibilityValue(widgetsSelected ? "Widgets" : "Η ημέρα σου")
        .accessibilityHint(widgetsSelected ? "Επιστροφή στην ημέρα σου" : "Μετάβαση στα widgets")
        .animation(.spring(response: 0.30, dampingFraction: 0.82), value: widgetsSelected)
        .disabled(transitionInProgress)
    }

    private var dashboardIntroduction: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 5) {
                Text(todayString.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.65)
                    .foregroundStyle(Paper.gold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                Text(klimaxGreeting())
                    .font(.system(size: 30, weight: .semibold, design: .serif))
                    .foregroundStyle(Paper.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                Text(isEditingDashboard ? "Σύρε, κρύψε ή άλλαξε μέγεθος." : "Μικρές στάσεις για προσευχή και μελέτη.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Paper.inkMute)
            }
            Spacer()
            if !isEditingDashboard {
                Text("\(displayedWidgets.count)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Paper.gold)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Paper.gold.opacity(0.09), in: Capsule())
                    .overlay(Capsule().stroke(Paper.gold.opacity(0.13), lineWidth: 0.75))
            }
        }
        .padding(.horizontal, 22)
    }

    private func headerButton(
        icon: String,
        accessibilityLabel: String,
        highlighted: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(highlighted ? Paper.gold : Paper.ink)
                .frame(width: 40, height: 40)
                .todayLiquidGlass(cornerRadius: 20, highlighted: highlighted, interactive: true)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }

    private func widgetContainer(_ widget: TodayWidgetConfig) -> some View {
        GeometryReader { geometry in
        Group {
            if isEditingDashboard && (!widget.isVisible || !isWidgetAvailable(widget.id)) {
                widgetPlaceholder(widget)
            } else {
                dashboardWidget(widget)
                    .allowsHitTesting(!isEditingDashboard)
            }
        }
        .frame(width: geometry.size.width, height: geometry.size.height)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            if isEditingDashboard {
                // Disable the widget's links without disabling the editor's
                // drag surface. Keep resize/remove controls above this layer.
                Rectangle().fill(Color.clear).contentShape(Rectangle())
            }
        }
        .opacity(widget.isVisible ? 1 : 0.42)
        .overlay {
            if isEditingDashboard && !widget.isVisible {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Paper.bg.opacity(0.58))
                Label("Κρυμμένο", systemImage: "eye.slash.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Paper.inkMute)
            }
        }
        .overlay(alignment: .topLeading) {
            if isEditingDashboard {
                removeBadge(widget).offset(x: -7, y: -7)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if isEditingDashboard && widget.isVisible && isWidgetAvailable(widget.id) {
                resizeBadge(widget).offset(x: -7, y: -7)
            }
        }
        .rotationEffect(.degrees(isEditingDashboard ? (jiggle ? 0.55 : -0.55) : 0))
        .scaleEffect(isEditingDashboard ? 0.985 : 1)
        .contextMenu {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { isEditingDashboard = true }
            } label: { Label("Προσαρμογή widgets", systemImage: "slider.horizontal.3") }
            Button { showWidgetGallery = true } label: {
                Label("Προσθήκη widget", systemImage: "plus")
            }
        }
        .animation(.easeInOut(duration: 0.14), value: jiggle)
        }
    }

    private func removeBadge(_ widget: TodayWidgetConfig) -> some View {
        Button { toggleWidgetVisibility(widget.id) } label: {
            Image(systemName: widget.isVisible ? "minus" : "plus")
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(Paper.ink)
                .frame(width: 26, height: 26)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().stroke(Paper.hairline, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func resizeBadge(_ widget: TodayWidgetConfig) -> some View {
        WidgetResizeHandle(size: widget.size) { size in
            guard let index = index(for: widget.id) else { return }
            withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                widgets[index].size = size
            }
            UISelectionFeedbackGenerator().selectionChanged()
            saveWidgets(widgets)
        }
    }

    private var widgetGallery: some View {
        NavigationStack {
            GeometryReader { geometry in
                let metrics = TodayWidgetMetrics.resolve(screen: UIScreen.main.bounds.size, availableWidth: geometry.size.width - 40)
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Διάλεξε τι θέλεις να βλέπεις στο Σήμερα")
                        .font(.subheadline).foregroundStyle(.secondary)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], alignment: .center, spacing: 24) {
                    ForEach(TodayWidgetID.allCases.filter { $0 != .saints }) { id in
                        let added = widgets.contains { $0.id == id && $0.isVisible }
                        NavigationLink {
                            WidgetGalleryPreview(title: id.title, alreadyAdded: added,
                                content: { gallerySample(id, size: $0) }, onAdd: { addWidget(id, size: $0) })
                        } label: {
                        VStack(spacing: 10) {
                            WidgetGallerySample(identity: id.rawValue, size: .small,
                                width: metrics.small, height: metrics.small,
                                content: { gallerySample(id, size: $0) }).equatable()
                            HStack(spacing: 5) {
                                Text(id.title).font(.subheadline.weight(.semibold)).multilineTextAlignment(.center)
                                if added { Image(systemName: "checkmark.circle.fill").font(.caption) }
                            }
                            .foregroundStyle(Paper.ink)
                        }
                        .frame(maxWidth: .infinity).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(id.title)
                        .accessibilityHint("Προεπισκόπηση μικρού, μεσαίου και μεγάλου widget")
                    }
                }
                }.padding(20)
            }
            .scrollIndicators(.hidden)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .tint(Gild.accentForeground)
            .navigationTitle("Widgets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) {
                Button("Τέλος") { showWidgetGallery = false }
            } }
        }
    }

    private func gallerySample(_ id: TodayWidgetID, size: TodayWidgetSize) -> AnyView {
        let config = TodayWidgetConfig(id: id, size: size)
        return AnyView(Group {
            if isWidgetAvailable(id) { dashboardWidget(config) }
            else { widgetPlaceholder(config) }
        })
    }

    private func addWidget(_ id: TodayWidgetID, size: TodayWidgetSize) {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
            if let index = widgets.firstIndex(where: { $0.id == id && $0.isVisible }) {
                widgets[index].size = size
            } else {
                widgets.removeAll { $0.id == id }
                widgets.append(TodayWidgetConfig(id: id, size: size))
            }
        }
        saveWidgets(widgets)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        showWidgetGallery = false
    }

    private func widgetPlaceholder(_ widget: TodayWidgetConfig) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            widgetGlyph(widget.id.icon)
            Spacer(minLength: 0)
            Text(widget.id.title)
                .font(.system(size: widget.size == .small ? 17 : 21, weight: .semibold, design: .serif))
                .foregroundStyle(Paper.ink)
                .lineLimit(2)
            Text(isWidgetAvailable(widget.id) ? "Κρυμμένο από το Σήμερα" : "Δεν είναι διαθέσιμο τώρα")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Paper.inkMute)
                .lineLimit(1)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .todayLiquidGlass(cornerRadius: 22, highlighted: widget.size != .small)
    }

    private func index(for id: TodayWidgetID) -> Int? {
        widgets.firstIndex { $0.id == id }
    }

    private func cycleWidgetSize(_ id: TodayWidgetID) {
        guard let index = index(for: id) else { return }
        withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
            switch widgets[index].size {
            case .small: widgets[index].size = .wide
            case .wide: widgets[index].size = .large
            case .large: widgets[index].size = .small
            }
        }
        saveWidgets(widgets)
    }

    private func toggleWidgetVisibility(_ id: TodayWidgetID) {
        guard let index = index(for: id) else { return }
        withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
            widgets[index].isVisible.toggle()
        }
        saveWidgets(widgets)
    }

    @ViewBuilder private func dashboardWidget(_ widget: TodayWidgetConfig) -> some View {
        switch widget.id {
        case .sundayLiturgy:
            if let sundayService {
                NavigationLink {
                    DivineLiturgyView(date: now)
                } label: {
                    sundayLiturgyCard(sundayService, size: widget.size)
                }
                .buttonStyle(CalmCardStyle())
            }
        case .didaches:
            didachesTodayWidget(size: widget.size)
        case .dailyStories:
            dailyStoriesWidget(size: widget.size)
        case .continueReading:
            if let route = store.continueReading(), let book = store.book(id: route.bookID) {
                NavigationLink(value: route) {
                    continueCard(book: book, route: route, size: widget.size)
                }
                .buttonStyle(CalmCardStyle())
            }
        case .verse:
            if let vod = store.verseOfTheDay() {
                NavigationLink(value: ChapterRoute(bookID: vod.book.id, chapterNumber: vod.chapter.number)) {
                    verseOfTheDay(vod, size: widget.size)
                }.buttonStyle(.plain)
            }
        case .fasting:
            todayFastingWidget(size: widget.size)
        case .feastCalendar:
            feastCalendarCard(size: widget.size)
        case .saints:
            todaySaintChips(size: widget.size)
        case .streaks:
            streakGlance(size: widget.size)
        case .nearby:
            churchMapCard(size: widget.size)
        }
    }

    private func didachesTodayWidget(size: TodayWidgetSize) -> some View {
        DidachesTodayWidget(size: size, clip: dailyClip.clip)
    }

    private func dailyStoriesWidget(size: TodayWidgetSize) -> some View {
        DailyStoriesTodayWidget(size: size)
    }

    private func todayFastingWidget(size: TodayWidgetSize) -> some View {
        let calendar = Calendar.current
        let selectedDate = fastingSelectedDate ?? now
        let level = fastingWidgetLevel(for: selectedDate)
        let isToday = calendar.isDate(selectedDate, inSameDayAs: now)

        return VStack(alignment: .leading, spacing: 8) {
            NavigationLink {
                FastingCalendarView(date: selectedDate)
            } label: {
                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 6) {
                        Image(systemName: level.cardIcon)
                        Text(isToday ? (size == .small ? "ΝΗΣΤΕΙΑ" : "ΝΗΣΤΕΙΑ ΣΗΜΕΡΑ") : fastingDayLabel(selectedDate).uppercased())
                            .font(.system(size: 9, weight: .bold)).tracking(0.8)
                        Spacer(minLength: 0)
                        Image(systemName: "arrow.up.right").font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(Gild.accentForeground)
                    Text(fastingWidgetTitle(level))
                        .font(.system(size: size == .large ? 24 : 18, weight: .semibold, design: .serif))
                        .foregroundStyle(Paper.ink).lineLimit(2)
                        .minimumScaleFactor(0.85)
                    Text(level.cardGuidance)
                        .font(.system(size: size == .large ? 13 : size == .small ? 11 : 12))
                        .foregroundStyle(Paper.inkSoft).lineLimit(size == .wide ? 1 : 4)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
            }.buttonStyle(.plain)

            if size == .large {
                Divider()
                fastingMonthGrid(selectedDate: selectedDate)
            } else if size == .wide {
                HStack(spacing: 2) {
                    ForEach(0..<7, id: \.self) { offset in
                        let date = calendar.date(byAdding: .day, value: offset, to: now) ?? now
                        fastingDayPill(date: date, selectedDate: selectedDate)
                    }
                }
            } else {
                Spacer(minLength: 0)
            }
        }
        .padding(size == .small ? 14 : 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .todayLiquidGlass(cornerRadius: 22, tint: level.cardTint)
    }

    private func fastingWidgetTitle(_ level: FastingLevel) -> String {
        switch level {
        case .free: return "Χωρίς νηστεία"
        case .noMeat: return "Χωρίς κρέας"
        case .fish: return "Επιτρέπεται ψάρι"
        case .oilWine: return "Λάδι και κρασί"
        case .xerophagy: return "Ξηροφαγία"
        }
    }

    private func fastingWidgetLevel(for date: Date) -> FastingLevel {
        // The fasting engine uses UTC civil dates; do not pass local midnight,
        // which can otherwise resolve to the previous UTC day.
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return FastingCalendar.shared.status(for: Paschalion.cal.date(from: components) ?? date).level
    }

    private func fastingMonthGrid(selectedDate: Date) -> some View {
        let calendar = Calendar.current
        let start = calendar.dateInterval(of: .month, for: selectedDate)?.start ?? selectedDate
        let days = calendar.range(of: .day, in: .month, for: start)?.count ?? 30
        let leading = (calendar.component(.weekday, from: start) + 5) % 7
        let cells = ((leading + days + 6) / 7) * 7
        return VStack(spacing: 5) {
            HStack {
                Button { shiftFastingMonth(-1, from: start) } label: {
                    Image(systemName: "chevron.left").frame(width: 30, height: 26)
                }.accessibilityLabel("Προηγούμενος μήνας")
                Spacer(minLength: 0)
                Text(start.formatted(.dateTime.month(.wide).year().locale(Locale(identifier: "el_GR"))))
                    .font(.system(size: 13, weight: .semibold))
                Spacer(minLength: 0)
                Button { shiftFastingMonth(1, from: start) } label: {
                    Image(systemName: "chevron.right").frame(width: 30, height: 26)
                }.accessibilityLabel("Επόμενος μήνας")
            }.buttonStyle(.plain).foregroundStyle(Gild.accentForeground)
            HStack(spacing: 4) {
                ForEach(Array(["Δ", "Τ", "Τ", "Π", "Π", "Σ", "Κ"].enumerated()), id: \.offset) { _, day in
                    Text(day).font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Paper.inkMute).frame(maxWidth: .infinity)
                }
            }
            GeometryReader { geometry in
                let height = max(20, (geometry.size.height - CGFloat(cells / 7 - 1) * 4) / CGFloat(cells / 7))
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                    ForEach(0..<cells, id: \.self) { cell in
                        if cell >= leading, cell < leading + days {
                            let date = calendar.date(byAdding: .day, value: cell - leading, to: start) ?? start
                            let level = fastingWidgetLevel(for: date)
                            let selected = calendar.isDate(date, inSameDayAs: selectedDate)
                            Button { fastingSelectedDate = date } label: {
                                VStack(spacing: 2) {
                                    Text("\(cell - leading + 1)").font(.system(size: 11, weight: selected ? .bold : .medium))
                                    Circle().fill(level.cardTint).frame(width: 4, height: 4)
                                }
                                .foregroundStyle(selected ? Gild.accentForeground : Paper.ink)
                                .frame(maxWidth: .infinity).frame(height: height)
                                .background(level.cardTint.opacity(selected ? 0.24 : 0.09), in: RoundedRectangle(cornerRadius: 6))
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(selected ? Gild.accentForeground : Paper.hairline, lineWidth: selected ? 1.5 : 0.5))
                            }.buttonStyle(.plain)
                                .accessibilityLabel("\(fastingDayLabel(date)), \(fastingWidgetTitle(level))")
                                .accessibilityAddTraits(selected ? .isSelected : [])
                        } else {
                            Color.clear.frame(height: height)
                        }
                    }
                }
            }
            Text("Επίλεξε ημέρα για τον κανόνα νηστείας")
                .font(.system(size: 10)).foregroundStyle(Paper.inkMute)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.trailing, isEditingDashboard ? 30 : 0)
        }
    }

    private func shiftFastingMonth(_ offset: Int, from date: Date) {
        if let next = Calendar.current.date(byAdding: .month, value: offset, to: date) {
            fastingSelectedDate = next
        }
    }

    private func fastingOutlookRow(date: Date, selectedDate: Date) -> some View {
        let level = FastingCalendar.shared.status(for: date).level
        let selected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
        return Button {
            withAnimation(.easeInOut(duration: 0.18)) { fastingSelectedDate = date }
        } label: {
            HStack(spacing: 8) {
                Text(Calendar.current.isDate(date, inSameDayAs: now) ? "Σήμερα" : fastingDayLabel(date))
                    .font(.system(size: 11, weight: selected ? .bold : .medium))
                    .frame(width: 63, alignment: .leading)
                Image(systemName: level.cardIcon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(level.cardTint).frame(width: 16)
                Text(fastingWidgetTitle(level))
                    .font(.system(size: 12, weight: selected ? .semibold : .regular))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Image(systemName: selected ? "checkmark.circle.fill" : "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(selected ? Gild.accentForeground : Paper.inkMute)
            }
            .foregroundStyle(Paper.ink)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(level.cardTint.opacity(selected ? 0.14 : 0.04), in: RoundedRectangle(cornerRadius: 8))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(fastingDayLabel(date)), \(fastingWidgetTitle(level)). \(level.cardGuidance)")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func fastingMiniDayButton(date: Date, selectedDate: Date) -> some View {
        let status = FastingCalendar.shared.status(for: date)
        let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                fastingSelectedDate = date
            }
        } label: {
            Circle()
                .fill(isSelected ? status.level.cardTint : status.level.cardTint.opacity(0.34))
                .frame(width: isSelected ? 12 : 8, height: isSelected ? 12 : 8)
                .overlay(Circle().stroke(Paper.card.opacity(isSelected ? 0.75 : 0), lineWidth: 1.2))
        }
        .buttonStyle(.plain)
    }

    private func fastingDayLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "el_GR")
        f.dateFormat = "EEE d"
        return f.string(from: date)
    }

    private func fastingDayPill(date: Date, selectedDate: Date) -> some View {
        let status = FastingCalendar.shared.status(for: date)
        let day = Calendar.current.component(.day, from: date)
        let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                fastingSelectedDate = date
            }
        } label: {
            VStack(spacing: 3) {
                Text(weekdayLetter(date))
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(isSelected ? .white.opacity(0.85) : Paper.inkMute)
                Text("\(day)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(isSelected ? .white : Paper.ink)
                Circle()
                    .fill(status.level.cardTint)
                    .frame(width: 5, height: 5)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background(isSelected ? status.level.cardTint.opacity(0.9) : Paper.ink.opacity(0.05),
                        in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(isSelected ? Paper.gold : Paper.hairline, lineWidth: isSelected ? 1.4 : 1))
        }
        .buttonStyle(.plain)
    }

    private func weekdayLetter(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "el_GR")
        f.dateFormat = "EEEEE"
        return f.string(from: date)
    }

    private var monthFastCount: Int {
        let calendar = Calendar.current
        guard let interval = calendar.dateInterval(of: .month, for: now) else { return 0 }
        let days = calendar.dateComponents([.day], from: interval.start, to: interval.end).day ?? 0
        return (0..<days).filter { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: interval.start) else { return false }
            return FastingCalendar.shared.status(for: date).isFast
        }.count
    }

    private func widgetGlyph(_ icon: String) -> some View {
        Image(systemName: icon)
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(Paper.gold)
            .frame(width: 42, height: 42)
            .background(Paper.gold.opacity(0.13), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(Paper.gold.opacity(0.18), lineWidth: 1))
    }

    // Today's commemorations that exist in the catalogue, de-duplicated in order.
    private var todaysCatalogedSaints: [SaintEntry] {
        guard let feasts = feastCalendar.today()?.feasts else { return [] }
        var seen = Set<String>(); var result: [SaintEntry] = []
        for feast in feasts {
            guard let id = feast.saintId, !id.isEmpty, !seen.contains(id),
                  let saint = saintsStore.saint(byId: id) else { continue }
            seen.insert(id); result.append(saint)
        }
        return result
    }

    // A quiet, tappable row of the day's saints. Hidden when there are none.
    @ViewBuilder private func todaySaintChips(size: TodayWidgetSize) -> some View {
        let saints = todaysCatalogedSaints
        if !saints.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    widgetGlyph("seal.fill")
                    Spacer()
                    Text("\(saints.count)")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(Paper.ink)
                }

                Spacer(minLength: 0)

                if size == .small {
                    Text("Άγιοι ημέρας")
                        .font(.system(size: 17, weight: .semibold, design: .serif))
                        .foregroundStyle(Paper.ink)
                        .lineLimit(1)
                    Text(saints.first?.name ?? "")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Paper.inkMute)
                        .lineLimit(1)
                } else {
                    Text("ΑΓΙΟΙ ΤΗΣ ΗΜΕΡΑΣ")
                        .font(.system(size: 10, weight: .semibold)).tracking(2)
                        .foregroundStyle(Paper.gold)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(saints) { saint in
                                Button { selectedSaint = saint } label: { saintChip(saint) }
                                    .buttonStyle(.plain)
                            }
                        }
                    }
                    if size == .large, let featured = saints.first {
                        VStack(alignment: .leading, spacing: 4) {
                            if let rank = featured.rankTitle, !rank.isEmpty {
                                Text(rank)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(Paper.gold)
                                    .lineLimit(1)
                            }
                            if let line = featured.bio?.first(where: { !$0.isEmpty }) {
                                Text(line)
                                    .font(.system(size: 14, design: .serif))
                                    .foregroundStyle(Paper.ink)
                                    .lineLimit(3)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Text("Ο βίος του →")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Paper.gold)
                        }
                        .padding(.top, 4)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(size == .large ? 18 : 16)
            .todayLiquidGlass(cornerRadius: 22, highlighted: size != .small)
        }
    }

    private func saintChip(_ saint: SaintEntry) -> some View {
        HStack(spacing: 8) {
            SaintChipGlyph(icon: saint.icon)
            Text(saint.name)
                .font(.system(size: 14, design: .serif)).foregroundStyle(Paper.ink)
                .lineLimit(1)
            Image(systemName: "chevron.right").font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Paper.gold.opacity(0.7))
        }
        .padding(.horizontal, 14).padding(.vertical, 9)
        .background(Paper.card, in: Capsule())
        .overlay(Capsule().stroke(Paper.gold.opacity(0.30), lineWidth: 1))
    }

    private var todayString: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "el_GR")
        f.dateFormat = "EEEE, d MMMM"
        return f.string(from: Date())
    }

    private func continueCard(book: Book, route: ChapterRoute, size: TodayWidgetSize) -> some View {
        Group {
            if size == .small {
                VStack(alignment: .leading, spacing: 10) {
                    widgetGlyph("book.fill")
                    Spacer(minLength: 0)
                    Text("Συνέχεια")
                        .font(.system(size: 17, weight: .semibold, design: .serif))
                        .foregroundStyle(Paper.ink)
                    Text("\(book.titleGreek) \(route.chapterNumber)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Paper.inkMute)
                        .lineLimit(2).minimumScaleFactor(0.85)
                }
            } else if size == .wide {
                HStack(spacing: 16) {
                    widgetGlyph("book.fill")
                    VStack(alignment: .leading, spacing: 3) {
                        Text("ΣΥΝΕΧΕΙΑ ΑΝΑΓΝΩΣΗΣ")
                            .font(.system(size: 10, weight: .semibold)).tracking(2)
                            .foregroundStyle(Paper.gold)
                        Text("\(book.titleGreek) \(route.chapterNumber)")
                            .font(.system(size: 20, weight: .regular, design: .serif))
                            .foregroundStyle(Paper.ink)
                            .lineLimit(1)
                        if let opening = store.chapter(route)?.verses.first?.ancient {
                            Text(opening).font(.system(size: 13, design: .serif))
                                .foregroundStyle(Paper.inkSoft).lineLimit(2)
                                .padding(.top, 5)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Paper.inkMute.opacity(0.55))
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        widgetGlyph("book.fill")
                        Spacer()
                        Text("ΣΥΝΕΧΕΙΑ ΑΝΑΓΝΩΣΗΣ")
                            .font(.system(size: 10, weight: .semibold)).tracking(2)
                            .foregroundStyle(Paper.gold)
                    }
                    Text("\(book.titleGreek) \(route.chapterNumber)")
                        .font(.system(size: 24, weight: .regular, design: .serif))
                        .foregroundStyle(Paper.ink)
                        .lineLimit(1)
                    if let chapter = store.chapter(route) {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(Array(chapter.verses.prefix(4).enumerated()), id: \.offset) { index, verse in
                                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                                        Text("\(verse.number)").font(.caption2.monospacedDigit())
                                            .foregroundStyle(Paper.inkMute)
                                        Text(verse.ancient).font(.system(size: 16, design: .serif))
                                            .foregroundStyle(Paper.inkSoft).lineSpacing(4)
                                    }
                                }
                            }
                        }.frame(maxHeight: .infinity)
                    }
                    Spacer(minLength: 0)
                    HStack(spacing: 6) {
                        Text("Συνέχισε από εδώ")
                        Image(systemName: "chevron.right")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Paper.gold)
                }
            }
        }
        .padding(size == .large ? 20 : 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .todayLiquidGlass(cornerRadius: 22, highlighted: size != .small)
    }

    private func sundayLiturgyCard(_ package: SundayServicePackage, size: TodayWidgetSize) -> some View {
        Group {
            if size == .small {
                VStack(alignment: .leading, spacing: 10) {
                    widgetGlyph("cross.fill")
                    Spacer(minLength: 0)
                    Text("Κυριακή")
                        .font(.system(size: 18, weight: .semibold, design: .serif))
                        .foregroundStyle(Paper.ink)
                    Text("Λειτουργία")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Paper.inkMute)
                }
            } else if size == .wide {
                HStack(spacing: 16) {
                    widgetGlyph("cross.fill")
                    VStack(alignment: .leading, spacing: 4) {
                        Text("ΘΕΙΑ ΛΕΙΤΟΥΡΓΙΑ ΤΗΣ ΚΥΡΙΑΚΗΣ")
                            .font(.system(size: 10, weight: .bold)).tracking(1.4).foregroundStyle(Paper.gold)
                        Text("\(package.sunday.titleEl) · Ευαγγέλιον: \(package.services.divineLiturgy.gospel.displayEl)")
                            .font(.system(size: size == .large ? 17 : 15, design: .serif))
                            .foregroundStyle(Paper.ink)
                            .lineLimit(size == .large ? 3 : 2)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Paper.inkMute.opacity(0.55))
                }
            } else {
                VStack(alignment: .leading, spacing: 9) {
                    HStack {
                        widgetGlyph("cross.fill")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Paper.inkMute.opacity(0.55))
                    }
                    Text("ΘΕΙΑ ΛΕΙΤΟΥΡΓΙΑ ΤΗΣ ΚΥΡΙΑΚΗΣ")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.4)
                        .foregroundStyle(Paper.gold)
                    Text(package.sunday.titleEl)
                        .font(.system(size: 20, weight: .regular, design: .serif))
                        .foregroundStyle(Paper.ink)
                        .lineLimit(2)
                    VStack(alignment: .leading, spacing: 5) {
                        ForEach(liturgyPreviewLines(package), id: \.self) { line in
                            HStack(alignment: .top, spacing: 6) {
                                Circle()
                                    .fill(Paper.gold)
                                    .frame(width: 4, height: 4)
                                    .padding(.top, 7)
                                Text(line)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Paper.inkMute)
                                    .lineLimit(1)
                            }
                        }
                    }
                    if let apolytikion = sundayApolytikion(package) {
                        Divider()
                        ScrollView {
                        Text(apolytikion)
                            .font(.system(size: 13, design: .serif))
                            .foregroundStyle(Paper.ink.opacity(0.82))
                            .lineSpacing(4)
                        }.frame(maxHeight: .infinity)
                    }
                }
            }
        }
        .padding(size == .large ? 20 : 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .todayLiquidGlass(cornerRadius: 22, highlighted: size != .small)
    }

    private func liturgyPreviewLines(_ package: SundayServicePackage) -> [String] {
        var lines: [String] = []
        if let echos = package.services.divineLiturgy.echos {
            lines.append(echos.displayEl)
        }
        if let eothinon = package.services.divineLiturgy.eothinon {
            lines.append("Εωθινόν \(eothinon)")
        }
        lines.append("Ευαγγέλιον: \(package.services.divineLiturgy.gospel.displayEl)")
        return lines
    }

    private func sundayApolytikion(_ package: SundayServicePackage) -> String? {
        guard let repository = try? LiturgicalRepository.load(),
              let entry = repository.apolytikia?.entry(
                echosKey: package.services.divineLiturgy.echos?.key,
                sundayID: package.sunday.id
              ) else { return nil }
        return entry.textEl
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func loadSundayServiceFeature() {
        now = Date()
        guard LiturgicalFeatureWindow.shouldShowSundayLiturgy(at: now) else { sundayService = nil; return }
        do {
            sundayService = try ServiceAssembler.assemble(
                now, repository: LiturgicalRepository.load(), bible: store.bible
            )
        } catch { sundayService = nil }
    }

    private func verseOfTheDay(_ vod: (book: Book, chapter: Chapter, verse: Verse), size: TodayWidgetSize) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                widgetGlyph("book.closed.fill")
                Spacer()
                Text(size == .small ? "ΧΩΡΙΟ" : "ΧΩΡΙΟ ΗΜΕΡΑΣ")
                    .font(.system(size: 10, weight: .semibold)).tracking(2)
                    .foregroundStyle(Paper.gold)
            }
            if size == .small { Spacer(minLength: 0) }
            if size == .large {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(vod.verse.ancient)
                            .font(.system(size: 22, design: .serif)).lineSpacing(6)
                            .foregroundStyle(Paper.ink)
                        if let modern = vod.verse.modern, !modern.isEmpty {
                            Divider()
                            Text("ΣΤΑ ΝΕΑ ΕΛΛΗΝΙΚΑ")
                                .font(.system(size: 10, weight: .bold)).tracking(1)
                                .foregroundStyle(Gild.accentForeground)
                            Text(modern).font(.system(size: 16)).lineSpacing(4)
                                .foregroundStyle(Paper.inkSoft)
                        }
                    }
                }.frame(maxHeight: .infinity)
            } else {
            Text(vod.verse.ancient)
                .font(.system(size: size == .large ? 23 : (size == .wide ? 18 : 15), weight: .regular, design: .serif))
                .foregroundStyle(Paper.ink)
                .lineSpacing(size == .small ? 2 : 6)
                .lineLimit(size == .large ? 5 : (size == .wide ? 2 : 3))
                .fixedSize(horizontal: false, vertical: true)
            }
            Text("\(vod.book.titleGreek) \(vod.chapter.number)·\(vod.verse.number)")
                .font(.system(size: size == .small ? 10 : 12, weight: .semibold))
                .foregroundStyle(Paper.gold)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(size == .large ? 22 : 16)
        .frame(maxHeight: .infinity, alignment: .leading)
        .todayLiquidGlass(cornerRadius: 22, highlighted: size != .small)
    }

    private func streakGlance(size: TodayWidgetSize) -> some View {
        NavigationLink {
            StreakDashboardView(store: streaks)
        } label: {
            streakContent(size: size)
        }
        .buttonStyle(CalmCardStyle())
    }

    private func streakContent(size: TodayWidgetSize) -> some View {
        let completed = streaks.completedToday
        let count = streaks.globalCurrentStreak
        return ZStack(alignment: .bottomTrailing) {
            streakBackdrop(active: completed, size: size)

            if size == .large {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\(count)").font(.system(size: 46, weight: .bold, design: .rounded))
                            .foregroundStyle(streakWidgetGradient)
                        Text("ημέρες συνέπειας").font(.headline).foregroundStyle(Paper.ink)
                        Spacer(minLength: 0)
                        Image(systemName: "flame.fill").foregroundStyle(.orange)
                    }
                    todayStreakWeek
                    Divider()
                    Text("ΟΙ ΣΤΟΧΟΙ ΣΟΥ ΣΗΜΕΡΑ").font(.system(size: 10, weight: .bold)).tracking(1)
                        .foregroundStyle(Paper.inkSoft)
                    let statuses = streaks.goalStatuses(on: now)
                    if statuses.isEmpty {
                        Text("Πρόσθεσε έναν στόχο και ξεκίνησε με ένα μικρό βήμα.")
                            .font(.subheadline).foregroundStyle(Paper.inkSoft)
                    } else {
                        ForEach(Array(statuses.prefix(3).enumerated()), id: \.offset) { _, status in
                            HStack(spacing: 10) {
                                Image(systemName: status.isDone ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(status.isDone ? Color.green : Paper.inkMute)
                                Text(status.goal.title).font(.subheadline.weight(.medium))
                                    .foregroundStyle(Paper.ink).lineLimit(1)
                                Spacer(minLength: 0)
                                Text("\(streaks.progressToday(status.goal))/\(streaks.targetToday(status.goal))")
                                    .font(.caption.monospacedDigit()).foregroundStyle(Paper.inkSoft)
                            }
                        }
                    }
                    Spacer(minLength: 0)
                    Label("Όλοι οι στόχοι", systemImage: "arrow.up.right")
                        .font(.caption.weight(.semibold)).foregroundStyle(Gild.accentForeground)
                }.padding(20)
            } else if size == .small {
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 30, weight: .black))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(
                            completed ? Color(red: 1.0, green: 0.84, blue: 0.06) : Paper.inkMute.opacity(0.42),
                            completed ? Color(red: 1.0, green: 0.34, blue: 0.22) : Paper.inkMute.opacity(0.20)
                        )
                        .frame(width: 32, height: 32)
                    Spacer(minLength: 0)
                    Text("\(count)")
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .foregroundStyle(streakWidgetGradient)
                        .lineLimit(1)
                    Text("ημέρες συνέπειας")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(completed ? Color(red: 1.0, green: 0.42, blue: 0.24) : Paper.inkMute)
                        .lineLimit(2).minimumScaleFactor(0.9)
                }
                .padding(16)
            } else {
                HStack(spacing: 16) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: size == .large ? 56 : 42, weight: .black))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(
                            completed ? Color(red: 1.0, green: 0.84, blue: 0.06) : Paper.inkMute.opacity(0.42),
                            completed ? Color(red: 1.0, green: 0.34, blue: 0.22) : Paper.inkMute.opacity(0.20)
                        )
                        .frame(width: size == .large ? 82 : 64, height: size == .large ? 82 : 64)

                    VStack(alignment: .leading, spacing: size == .large ? 10 : 6) {
                        Text("GOALS")
                            .font(.system(size: 10, weight: .black))
                            .tracking(1.8)
                            .foregroundStyle(Color(red: 1.0, green: 0.42, blue: 0.24))
                        HStack(alignment: .firstTextBaseline, spacing: 7) {
                            Text("\(count)")
                                .font(.system(size: size == .large ? 48 : 34, weight: .black, design: .rounded))
                                .foregroundStyle(streakWidgetGradient)
                            Text("ημέρες")
                                .font(.system(size: size == .large ? 17 : 14, weight: .black, design: .rounded))
                                .foregroundStyle(Paper.ink)
                        }
                        if size == .large {
                            todayStreakWeek
                            Text(completed ? "\(streaks.completedGoalsToday) goals completed today." : "Create or check in a goal.")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Paper.inkMute)
                                .lineLimit(2)
                        } else {
                            todayStreakWeek
                            Text(completed ? "Ολοκληρώθηκαν σήμερα: \(streaks.completedGoalsToday)" : "Οι στόχοι σου για σήμερα")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Paper.inkMute)
                        }
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Paper.inkMute.opacity(0.55))
                }
                .padding(size == .large ? 18 : 16)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .todayLiquidGlass(cornerRadius: 22, highlighted: true, tint: Color(red: 1.0, green: 0.48, blue: 0.16).opacity(0.18))
    }

    private var todayStreakWeek: some View {
        HStack(spacing: 7) {
            ForEach(streaks.weekStatus(), id: \.date) { day in
                Circle()
                    .fill(day.isActive ? AnyShapeStyle(streakWidgetGradient) : AnyShapeStyle(Paper.ink.opacity(0.12)))
                    .frame(width: day.isToday ? 20 : 16, height: day.isToday ? 20 : 16)
                    .overlay {
                        if day.isActive {
                            Image(systemName: "checkmark")
                                .font(.system(size: 8, weight: .black))
                                .foregroundStyle(Color(red: 0.11, green: 0.11, blue: 0.11))
                        }
                    }
            }
        }
    }

    private var streakWidgetGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 1.0, green: 0.84, blue: 0.04),
                Color(red: 1.0, green: 0.50, blue: 0.12),
                Color(red: 1.0, green: 0.32, blue: 0.25)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func streakBackdrop(active: Bool, size: TodayWidgetSize) -> some View {
        ZStack(alignment: .bottomTrailing) {
            RadialGradient(
                colors: [
                    Color(red: 1.0, green: 0.55, blue: 0.12).opacity(active ? 0.20 : 0.08),
                    .clear
                ],
                center: .center,
                startRadius: 0,
                endRadius: size == .large ? 95 : 60
            )
                .frame(width: size == .large ? 190 : 120, height: size == .large ? 190 : 120)
                .offset(x: size == .large ? 48 : 38, y: size == .large ? 60 : 42)
            RadialGradient(
                colors: [
                    Color(red: 1.0, green: 0.16, blue: 0.16).opacity(active ? 0.10 : 0.03),
                    .clear
                ],
                center: .center,
                startRadius: 0,
                endRadius: size == .large ? 65 : 43
            )
                .frame(width: size == .large ? 130 : 86, height: size == .large ? 130 : 86)
                .offset(x: 22, y: 26)
        }
        .allowsHitTesting(false)
    }

    private func ascentContent(lesson: LessonContent?, size: TodayWidgetSize) -> some View {
        ZStack(alignment: .bottomTrailing) {
            ascentBackdrop(size: size)

            if size == .small {
                VStack(alignment: .leading, spacing: 10) {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 38, weight: .bold))
                        .foregroundStyle(Paper.gold)
                        .frame(width: 54, height: 54)
                        .shadow(color: Paper.gold.opacity(0.20), radius: 10, y: 4)
                    Spacer(minLength: 0)
                    Text("Άνοδος")
                        .font(.system(size: 18, weight: .semibold, design: .serif))
                        .foregroundStyle(Paper.ink)
                    Text("\(completedLessonCount) από \(max(ladderLessons.count, 1)) μαθήματα")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Paper.inkMute)
                        .lineLimit(1)
                }
                .padding(16)
            } else {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(Paper.gold.opacity(0.10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .stroke(Paper.gold.opacity(0.18), lineWidth: 1)
                            )
                        Image(systemName: "chart.bar.fill")
                            .font(.system(size: size == .large ? 48 : 36, weight: .bold))
                            .foregroundStyle(Paper.gold)
                            .shadow(color: Paper.gold.opacity(0.18), radius: 10, y: 4)
                    }
                    .frame(width: size == .large ? 104 : 78, height: size == .large ? 112 : 84)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("ΆΝΟΔΟΣ ΣΟΥ")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(2)
                            .foregroundStyle(Paper.gold)
                        if size == .large {
                            HStack(spacing: 6) {
                                ForEach(0..<4, id: \.self) { step in
                                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                                        .fill(step < max(1, Int(ceil(lessonProgressFraction * 4.0))) ? Paper.gold : Paper.ink.opacity(0.10))
                                        .frame(width: 18, height: CGFloat(5 + step * 4))
                                }
                            }
                            Text(activeVirtue.title)
                                .font(.system(size: 16, weight: .regular, design: .serif))
                                .foregroundStyle(Paper.ink)
                                .lineLimit(1)
                        }
                        Text(lesson?.title ?? "Το κίνητρο")
                            .font(.system(size: size == .large ? 22 : 18, weight: .regular, design: .serif))
                            .foregroundStyle(Paper.ink)
                            .lineLimit(size == .large ? 2 : 1)
                        ProgressBar(fraction: max(0.06, lessonProgressFraction))
                            .frame(height: 4)
                        HStack(spacing: 6) {
                            Text("Συνέχισε")
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Paper.gold)
                    }
                    Spacer(minLength: 0)
                }
                .padding(size == .large ? 18 : 16)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .todayLiquidGlass(cornerRadius: 22, highlighted: true, tint: Paper.gold.opacity(0.16))
    }

    private func ascentBackdrop(size: TodayWidgetSize) -> some View {
        ZStack(alignment: .bottomTrailing) {
            ForEach(0..<4, id: \.self) { step in
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Paper.gold.opacity(0.08 + Double(step) * 0.018))
                    .frame(width: size == .small ? 24 : 34, height: CGFloat(14 + step * 14))
                    .offset(x: CGFloat(-step * 18), y: CGFloat(-step * 7))
            }
            Circle()
                .fill(Paper.gold.opacity(0.08))
                .frame(width: size == .large ? 150 : 92, height: size == .large ? 150 : 92)
                .offset(x: size == .large ? 44 : 32, y: size == .large ? 52 : 34)
        }
        .allowsHitTesting(false)
    }

    private func feastCalendarCard(size: TodayWidgetSize) -> some View {
        NavigationLink {
            OrthodoxFeastCalendarView(service: feastCalendar)
        } label: {
            VStack(alignment: .leading, spacing: size == .small ? 8 : 14) {
                HStack(spacing: 12) {
                    calendarDateBadge(compact: size != .large)
                    if size != .small {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("ΕΟΡΤΟΛΟΓΙΟ").font(.system(size: 10, weight: .bold)).tracking(1)
                            Text("Οι μνήμες της ημέρας").font(.caption).foregroundStyle(Paper.inkSoft)
                        }.foregroundStyle(Gild.accentForeground)
                        Spacer(minLength: 0)
                        Image(systemName: "arrow.up.right").font(.caption)
                    }
                }
                if size == .small {
                    Text("Εορτολόγιο").font(.system(size: 16, weight: .semibold, design: .serif))
                    Text("\(feastCalendar.today()?.feasts.count ?? 0) μνήμες σήμερα")
                        .font(.system(size: 11)).foregroundStyle(Paper.inkSoft)
                        .lineLimit(3).minimumScaleFactor(0.9)
                } else {
                    Text(feastCalendar.today()?.feasts.first?.title.interfaceGreek ?? "Μνήμες ημέρας")
                        .font(.system(size: size == .large ? 22 : 17, weight: .semibold, design: .serif))
                        .lineLimit(size == .large ? 3 : 2)
                    if let names = feastCalendar.today()?.feasts.first(where: { !$0.namesCelebrated.isEmpty })?.namesCelebrated {
                        Text("Γιορτάζουν: " + names.prefix(size == .large ? 6 : 3).joined(separator: ", "))
                            .font(.caption).foregroundStyle(Paper.inkSoft).lineLimit(size == .large ? 2 : 1)
                    }
                    if size == .large {
                        Divider()
                        ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                        Text("ΤΙΣ ΕΠΟΜΕΝΕΣ ΗΜΕΡΕΣ").font(.system(size: 10, weight: .bold)).tracking(1)
                            .foregroundStyle(Gild.accentForeground)
                        ForEach(upcomingFeastRows(limit: 3), id: \.self) { row in
                            HStack(alignment: .top, spacing: 8) {
                                RoundedRectangle(cornerRadius: 2).fill(Paper.gold).frame(width: 3)
                                Text(row.interfaceGreek).font(.system(size: 13)).foregroundStyle(Paper.inkSoft)
                                    .lineLimit(2)
                            }.fixedSize(horizontal: false, vertical: true)
                        }
                        }
                        }.frame(maxHeight: .infinity)
                    }
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(Paper.ink)
            .padding(size == .small ? 14 : 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .todayLiquidGlass(cornerRadius: 22, tint: Paper.gold.opacity(0.2))
        }.buttonStyle(.plain)
    }

    private func calendarDateBadge(compact: Bool) -> some View {
        let day = Calendar.current.component(.day, from: now)
        let f = DateFormatter()
        f.locale = Locale(identifier: "el_GR")
        f.dateFormat = "MMM"
        return VStack(spacing: compact ? 0 : 2) {
            Text(f.string(from: now).uppercased())
                .font(.system(size: compact ? 8 : 9, weight: .black))
                .foregroundStyle(.white.opacity(0.88))
            Text("\(day)")
                .font(.system(size: compact ? 20 : 26, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(width: compact ? 34 : 42, height: compact ? 34 : 44)
        .background(Paper.gold, in: RoundedRectangle(cornerRadius: compact ? 14 : 17, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: compact ? 14 : 17, style: .continuous)
                .stroke(Color.white.opacity(0.28), lineWidth: 1)
        )
        .shadow(color: Paper.gold.opacity(0.18), radius: 10, y: 5)
    }

    private func calendarBackdrop(size: TodayWidgetSize) -> some View {
        ZStack(alignment: .bottomTrailing) {
            ForEach(0..<5, id: \.self) { line in
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(Paper.gold.opacity(0.06))
                    .frame(width: size == .large ? 120 : 92, height: 2)
                    .offset(x: 20, y: CGFloat(-line * 12 - 10))
            }
            Circle()
                .fill(Paper.gold.opacity(0.07))
                .frame(width: size == .large ? 150 : 105, height: size == .large ? 150 : 105)
                .offset(x: 44, y: 48)
        }
        .allowsHitTesting(false)
    }

    private func upcomingFeastRows(limit: Int) -> [String] {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return feastCalendar.upcomingFeasts(limit: limit + 4, from: now)
            .compactMap { day -> String? in
                guard let feast = day.majorFeast ?? day.feasts.first,
                      let date = formatter.date(from: day.date) else { return nil }
                let delta = calendar.dateComponents(
                    [.day],
                    from: calendar.startOfDay(for: now),
                    to: calendar.startOfDay(for: date)
                ).day ?? 0
                guard delta > 0 else { return nil }
                let when = delta == 1 ? "Αύριο" : "Σε \(delta) ημέρες"
                return "\(when): \(feast.title)"
            }
            .prefix(limit)
            .map { $0 }
    }

    private func churchMapCard(size: TodayWidgetSize) -> some View {
        Button {
            showChurchMap = true
        } label: {
            ZStack {
                Map(position: $churchPreviewCamera, interactionModes: [])
                    .allowsHitTesting(false)
                LinearGradient(
                    colors: [.black.opacity(0.10), .black.opacity(0.46)],
                    startPoint: .top, endPoint: .bottom
                )
                Image(systemName: "cross.fill")
                    .font(.system(size: size == .small ? 18 : 22, weight: .bold))
                    .foregroundStyle(Paper.gold)
                    .padding(size == .small ? 9 : 11)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay(Circle().stroke(Paper.gold.opacity(0.6), lineWidth: 1))
                    .shadow(color: .black.opacity(0.35), radius: 5, y: 2)
                VStack(alignment: .leading) {
                    Text("Κοντά σου")
                        .font(.system(size: size == .small ? 17 : 22, weight: .heavy))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.5), radius: 6, y: 1)
                    Spacer()
                    if size != .small {
                        Text("Ναοί κοντά σου")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.9))
                            .shadow(color: .black.opacity(0.5), radius: 5, y: 1)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(size == .large ? 18 : 15)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.15), lineWidth: 0.75)
            )
        }
        .buttonStyle(CalmCardStyle())
        .overlay(alignment: .topTrailing) {
            if size == .large {
                VStack(spacing: 8) {
                    Button { zoomChurchPreview(by: 0.5) } label: {
                        Image(systemName: "plus").frame(width: 40, height: 40)
                    }.accessibilityLabel("Μεγέθυνση χάρτη")
                    Button { zoomChurchPreview(by: 2) } label: {
                        Image(systemName: "minus").frame(width: 40, height: 40)
                    }.accessibilityLabel("Σμίκρυνση χάρτη")
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Paper.ink).buttonStyle(.plain)
                .background(Paper.card, in: Capsule())
                .padding(16)
            }
        }
        .matchedTransitionSource(id: "churchMap", in: mapZoom)
    }

    private func zoomChurchPreview(by factor: Double) {
        churchPreviewScale = min(0.4, max(0.003, churchPreviewScale * factor))
        churchPreviewCamera = .region(MKCoordinateRegion(center: previewRegion.center,
            span: MKCoordinateSpan(latitudeDelta: churchPreviewScale, longitudeDelta: churchPreviewScale)))
    }

    private var previewRegion: MKCoordinateRegion {
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.9838, longitude: 23.7275),
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
    }

    private func loadSavedWidgets() -> [TodayWidgetConfig] {
        guard let data = savedWidgetLayout.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([TodayWidgetConfig].self, from: data),
              !decoded.isEmpty else {
            return TodayWidgetConfig.defaultLayout
        }
        let known = Set(TodayWidgetID.allCases)
        let decodedKnown = decoded.filter { known.contains($0.id) && $0.id != .saints }
        let missing = TodayWidgetConfig.defaultLayout.filter { config in
            !decodedKnown.contains { $0.id == config.id }
        }
        return decodedKnown + missing
    }

    private func saveWidgets(_ widgets: [TodayWidgetConfig]) {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-UITestWidgetSize") { return }
        #endif
        guard let data = try? JSONEncoder().encode(widgets),
              let text = String(data: data, encoding: .utf8) else { return }
        savedWidgetLayout = text
    }
}

private struct DidachesTodayWidget: View {
    @ObservedObject private var player = HomilyPlayer.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private enum PlayerPane {
        case daily
        case resume
    }

    let size: TodayWidgetSize
    let clip: Homily?
    @State private var page = 0
    @State private var slideForward = true

    private var lastListened: LastListened.Snapshot? { LastListened.load() }
    private var progress: Double {
        guard let clip else { return 0 }
        return PlaybackProgress.fraction(for: clip.id, duration: clip.durationSeconds)
    }

    var body: some View {
        ZStack {
            VStack(spacing: 4) {
                stackedPlayers

                if size != .small { pageIndicator }
                if size == .large {
                    Divider().padding(.vertical, 8)
                    Button { goToPage(page == 0 ? 1 : 0) } label: {
                        HStack(spacing: 10) {
                            Image(systemName: page == 0 ? "clock.arrow.circlepath" : "sparkles")
                            VStack(alignment: .leading, spacing: 4) {
                                Text(page == 0 ? "Συνέχεια ακρόασης" : "Ομιλία ημέρας")
                                    .font(.caption.weight(.semibold)).foregroundStyle(didachesTint)
                                Text(title(for: page == 0 ? .resume : .daily))
                                    .font(.subheadline).foregroundStyle(Paper.ink).lineLimit(2)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right").font(.caption)
                        }.padding(.vertical, 8)
                    }.buttonStyle(.plain)
                    NavigationLink("Όλες οι ομιλίες", destination: DidachesLibraryView())
                        .font(.caption.weight(.semibold)).foregroundStyle(didachesTint)
                        .padding(.top, 8)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .todayLiquidGlass(cornerRadius: 22, highlighted: size != .small)
    }

    private var activePane: PlayerPane { page == 0 ? .daily : .resume }

    private var stackedPlayers: some View {
        ZStack {
            playerPage(activePane)
                .transition(pageTransition)
                .id(page)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: page)
        .simultaneousGesture(
            DragGesture(minimumDistance: 18)
                .onEnded { value in
                    guard abs(value.translation.width) > abs(value.translation.height) * 1.5 else { return }
                    if value.translation.width < -36, page == 0 {
                        goToPage(1)
                    } else if value.translation.width > 36, page == 1 {
                        goToPage(0)
                    }
                }
        )
    }

    private var pageTransition: AnyTransition {
        if slideForward {
            return .asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            )
        } else {
            return .asymmetric(
                insertion: .move(edge: .leading).combined(with: .opacity),
                removal: .move(edge: .trailing).combined(with: .opacity)
            )
        }
    }

    private func goToPage(_ target: Int) {
        guard target != page, (0...1).contains(target) else { return }
        slideForward = target > page
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) {
            page = target
        }
    }

    private var pageIndicator: some View {
        HStack(spacing: 6) {
            ForEach(0..<2, id: \.self) { index in
                Button { goToPage(index) } label: { Capsule()
                    .fill(index == page ? didachesTint : Paper.ink.opacity(0.14))
                    .frame(width: index == page ? 18 : 6, height: 6)
                    .frame(width: 36, height: 18)
                    .contentShape(Rectangle())
                }.buttonStyle(.plain)
                    .accessibilityLabel(index == 0 ? "Ομιλία ημέρας" : "Συνέχεια ακρόασης")
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var label: some View {
        Text("ΔΙΔΑΧΕΣ")
            .font(.system(size: 10, weight: .bold))
            .tracking(2)
            .foregroundStyle(didachesTint)
    }

    private var durationText: String? {
        guard let seconds = clip?.durationSeconds, seconds > 0 else { return nil }
        return "\(max(1, seconds / 60)) λεπτά"
    }

    private func title(for pane: PlayerPane) -> String {
        switch pane {
        case .daily:
            return clip?.title ?? "Ομιλία της ημέρας"
        case .resume:
            return lastListened?.homily.title ?? "Συνέχισε ακρόαση"
        }
    }

    private func subtitle(for pane: PlayerPane) -> String {
        switch pane {
        case .daily:
            return clip?.hook ?? "Μικρή στάση για σήμερα"
        case .resume:
            return lastListened?.context ?? "Η τελευταία σου ομιλία"
        }
    }

    private func detail(for pane: PlayerPane) -> String {
        switch pane {
        case .daily:
            return durationText ?? "Σύντομη ακρόαση"
        case .resume:
            guard let lastListened else { return "Δεν υπάρχει πρόσφατη ακρόαση" }
            let pct = Int(PlaybackProgress.fraction(for: lastListened.homily.id, duration: lastListened.homily.durationSeconds) * 100)
            return "\(pct)% ακούστηκε"
        }
    }

    private func fraction(for pane: PlayerPane) -> Double {
        let homily = pane == .daily ? clip : lastListened?.homily
        if let homily, player.current?.id == homily.id, player.duration > 0 {
            return min(1, max(0, player.currentTime / player.duration))
        }
        switch pane {
        case .daily:
            return progress
        case .resume:
            guard let lastListened else { return 0 }
            return PlaybackProgress.fraction(for: lastListened.homily.id, duration: lastListened.homily.durationSeconds)
        }
    }

    private func icon(for pane: PlayerPane) -> String {
        switch pane {
        case .daily: return "sparkles"
        case .resume: return "play.fill"
        }
    }

    private func label(for pane: PlayerPane) -> String {
        switch pane {
        case .daily: return "ΟΜΙΛΙΑ ΗΜΕΡΑΣ"
        case .resume: return "ΣΥΝΕΧΙΣΕ"
        }
    }

    private var didachesTint: Color {
        Color.adaptive(Color(red: 0.180, green: 0.455, blue: 0.720),
                       Color(red: 0.365, green: 0.650, blue: 0.920))
    }

    private func audioBadge(size: CGFloat = 62) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
                .fill(didachesTint.opacity(0.13))
            HStack(alignment: .center, spacing: 3) {
                ForEach(0..<5, id: \.self) { index in
                    Capsule()
                        .fill(index == 2 ? didachesTint : didachesTint.opacity(0.48))
                        .frame(width: 4, height: CGFloat([16, 26, 38, 22, 30][index]) * (size / 62))
                }
            }
        }
        .frame(width: size, height: size)
    }

    private func playButton(size: CGFloat) -> some View {
        Image(systemName: "play.fill")
            .font(.system(size: size * 0.42, weight: .black))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(didachesTint, in: Circle())
            .shadow(color: didachesTint.opacity(0.26), radius: 8, y: 3)
    }

    private func titleFontSize(for title: String) -> CGFloat {
        switch size {
        case .small:
            if title.count > 52 { return 10.8 }
            if title.count > 38 { return 11.6 }
            if title.count > 26 { return 12.4 }
            return 14
        case .wide:
            return title.count > 42 ? 15 : 17
        case .large:
            return title.count > 54 ? 17 : 20
        }
    }

    private func playerPage(_ pane: PlayerPane) -> some View {
        let homily = pane == .daily ? clip : lastListened?.homily
        let isPlaying = homily != nil && player.current?.id == homily?.id && player.isPlaying
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Button { goToPage(page == 0 ? 1 : 0) } label: {
                    HStack(spacing: 4) {
                        Text(label(for: pane)).font(.system(size: 9, weight: .bold)).tracking(0.4)
                        if size == .small { Image(systemName: "chevron.down").font(.system(size: 8)) }
                    }
                }.buttonStyle(.plain).foregroundStyle(didachesTint)
                    .accessibilityLabel("Εναλλαγή ομιλίας ημέρας και συνέχειας ακρόασης")
                Spacer(minLength: 0)
                Button { play(homily, context: label(for: pane)) } label: {
                    Image(systemName: "arrow.up.right").font(.system(size: 10, weight: .semibold))
                        .frame(width: 24, height: 24)
                }.buttonStyle(.plain).foregroundStyle(Paper.inkSoft)
                    .accessibilityLabel("Άνοιγμα ομιλίας").disabled(homily == nil)
            }
            HStack(alignment: .top, spacing: 12) {
                if size != .small { audioBadge(size: size == .large ? 64 : 40) }
                VStack(alignment: .leading, spacing: 6) {
                    Text(title(for: pane))
                        .font(.system(size: size == .large ? 23 : size == .small ? 13 : 14, weight: .semibold, design: .serif))
                        .foregroundStyle(Paper.ink).lineLimit(size == .large ? 4 : 3)
                        .minimumScaleFactor(0.9).layoutPriority(1)
                        .onTapGesture { play(homily, context: label(for: pane)) }
                    if size != .small {
                        Text(subtitle(for: pane)).font(.caption).foregroundStyle(Paper.inkSoft)
                            .lineLimit(size == .large ? 2 : 1)
                    }
                }
            }
            Spacer(minLength: 0)
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    ProgressBar(fraction: fraction(for: pane), tint: didachesTint).frame(height: 3)
                    if size != .small {
                        Text(detail(for: pane)).font(.caption2).foregroundStyle(Paper.inkSoft).lineLimit(1)
                    }
                }
                Button {
                    guard let homily else { return }
                    if homily.isVideo || homily.audioURL == nil {
                        play(homily, context: label(for: pane))
                    } else if player.current?.id == homily.id {
                        player.toggle()
                    } else {
                        player.open(homily, context: label(for: pane))
                    }
                } label: {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                        .frame(width: size == .small ? 32 : 38, height: size == .small ? 32 : 38)
                        .background(didachesTint, in: Circle())
                }.buttonStyle(.plain).disabled(homily == nil)
                    .accessibilityLabel(isPlaying ? "Παύση" : "Αναπαραγωγή")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func play(_ homily: Homily?, context: String) {
        guard let homily else { return }
        player.present(homily, context: context)
    }

}

private struct DailyStoriesTodayWidget: View {
    let size: TodayWidgetSize
    @ObservedObject private var store = ShortStoriesStore.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var page = 0
    @State private var openReader = false
    private var stories: [PatericStory] { store.daily(count: 3) }
    private var selectedIndex: Int { min(page, max(0, stories.count - 1)) }
    private var story: PatericStory? { stories.isEmpty ? nil : stories[selectedIndex] }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("ΓΕΡΟΝΤΙΚΟ", systemImage: "text.quote")
                    .font(.system(size: 9, weight: .bold)).tracking(1)
                Spacer(minLength: 0)
                Text("\(stories.isEmpty ? 0 : selectedIndex + 1)/\(stories.count)")
                    .font(.caption2.monospacedDigit())
                if size == .large {
                    Button { openReader = true } label: {
                        Image(systemName: "arrow.up.right").frame(width: 28, height: 28)
                    }.buttonStyle(.plain).disabled(stories.isEmpty)
                        .accessibilityLabel("Άνοιγμα ιστορίας")
                }
            }.foregroundStyle(Gild.accentForeground)

            Group {
                if size == .large {
                    ScrollView { storyContent }
                        .id(selectedIndex)
                } else {
                    Button { openReader = true } label: {
                        storyContent.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            .contentShape(Rectangle())
                    }
                        .buttonStyle(.plain).disabled(stories.isEmpty)
                        .accessibilityHint("Ανοίγει ολόκληρη την επιλεγμένη ιστορία")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            HStack(spacing: 4) {
                ForEach(stories.indices, id: \.self) { index in
                    Button { select(index) } label: {
                        Capsule().fill(index == selectedIndex ? Paper.gold : Paper.ink.opacity(0.15))
                            .frame(width: index == selectedIndex ? 16 : 5, height: 5)
                            .frame(minWidth: 24, minHeight: 30)
                    }.buttonStyle(.plain)
                        .accessibilityLabel("Ιστορία \(index + 1) από \(stories.count)")
                        .accessibilityAddTraits(index == selectedIndex ? .isSelected : [])
                }
                Spacer(minLength: 0)
                Button { select((selectedIndex + 1) % max(1, stories.count)) } label: {
                    Image(systemName: "arrow.right").font(.caption.weight(.semibold))
                        .frame(width: 30, height: 30)
                }.buttonStyle(.plain).foregroundStyle(Gild.accentForeground)
                    .accessibilityLabel("Επόμενη ιστορία").disabled(stories.count < 2)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .todayLiquidGlass(cornerRadius: 22, tint: Color.brown.opacity(0.45))
        .simultaneousGesture(DragGesture(minimumDistance: 24).onEnded { value in
            guard abs(value.translation.width) > abs(value.translation.height) * 1.5 else { return }
            select(selectedIndex + (value.translation.width < 0 ? 1 : -1))
        })
        .fullScreenCover(isPresented: $openReader) {
            StoryReaderView(stories: stories, startIndex: selectedIndex) { openReader = false }
        }
    }

    private var storyContent: some View {
    VStack(alignment: .leading, spacing: 8) {
        Text((story?.theme ?? story?.father ?? "Ιστορίες ημέρας").interfaceGreek)
            .font(.system(size: size == .large ? 24 : size == .small ? 15 : 17, weight: .semibold, design: .serif))
            .foregroundStyle(Paper.ink).lineLimit(size == .large ? nil : size == .wide ? 1 : 3)
            .minimumScaleFactor(0.9).layoutPriority(1)
        if size != .small {
            Text(story?.text ?? "Φόρτωση ιστοριών…")
                .font(.system(size: size == .large ? 17 : 13, design: .serif))
                .foregroundStyle(Paper.inkSoft)
                .lineSpacing(size == .large ? 5 : 2)
                .lineLimit(size == .large ? nil : 2)
        }
        if size == .large, let source = story?.reference {
            Text(source).font(.caption).foregroundStyle(Paper.inkMute).lineLimit(2)
        }
        if size == .large, let meaning = story?.meaning, !meaning.isEmpty {
            Divider()
            Text("ΓΙΑ ΣΚΕΨΗ").font(.system(size: 9, weight: .bold)).tracking(1)
                .foregroundStyle(Gild.accentForeground)
            Text(meaning).font(.system(size: 13, design: .serif))
                .foregroundStyle(Paper.inkSoft)
        }
    }
    }

    private func select(_ index: Int) {
        guard stories.indices.contains(index) else { return }
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.16)) { page = index }
    }
}


/// Planner changes stay in this subtree instead of rebuilding the hidden widgets.
private struct TodayPlannerPage: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var dayPlan = TodayDayPlanStore.shared
    @ObservedObject private var streaks = StreakStore.shared
    @ObservedObject private var categories = PlannerCategoryStore.shared
    @Binding var selectedJourneyDate: Date
    @Binding var headerCondensed: Bool
    let pagerCoordinator: TodayPagerCoordinator
    let bottomInset: CGFloat
    @State private var showDayAddMenu = false
    @State private var editingDayItem: DayPlanItem?
    @State private var inspectingDayGoal: DayPlanItem?
    @State private var promotingDayItem: DayPlanItem?
    @State private var draggingDayItemID: UUID?

    var body: some View {
        dailyJourneyPage
        .onAppear {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-UITestSeedLongDayPlan"),
               dayPlan.items(on: selectedJourneyDate).count < 30 {
                let samples = ["Πρωινή προσευχή", "Δέκα λεπτά ανάγνωσης", "Περίπατος στη φύση", "Τηλέφωνο στην οικογένεια", "Λίγη ησυχία", "Σημειώσεις από τη μελέτη"]
                for index in 0..<36 {
                    dayPlan.add(title: samples[index % samples.count], detail: "Μία μικρή στάση μέσα στην ημέρα.", kind: DayPlanKind.allCases[index % DayPlanKind.allCases.count], customKind: "", cadence: DayPlanCadence(), on: selectedJourneyDate)
                }
            }
            if ProcessInfo.processInfo.arguments.contains("-UITestSeedDayPlan"),
               dayPlan.items(on: selectedJourneyDate).isEmpty {
                dayPlan.add(
                    title: "Ένα λεπτό ησυχίας",
                    detail: "Σταμάτησε, ανάσανε και φύλαξε μία στιγμή.",
                    kind: .quiet,
                    customKind: "",
                    cadence: DayPlanCadence(),
                    on: selectedJourneyDate
                )
            }
            #endif
        }
        .sheet(isPresented: $showDayAddMenu) {
            TodayDayComposerSheet(
                date: selectedJourneyDate,
                goals: streaks.goals,
                linkedGoalIDs: Set(plannedItems.compactMap(\.linkedGoalID))
            ) { draft, goals in
                if let draft {
                    dayPlan.add(
                        title: draft.title, detail: draft.detail, kind: draft.kind,
                        customKind: draft.customKind, cadence: draft.cadence,
                        categoryID: draft.categoryID, colorID: draft.colorID,
                        on: selectedJourneyDate
                    )
                }
                for goal in goals {
                    dayPlan.addLinkedGoal(goal, on: selectedJourneyDate)
                }
            }
        }
        .sheet(item: $editingDayItem) { item in
            TodayDayComposerSheet(date: selectedJourneyDate, item: item) { draft, _ in
                guard let draft else { return }
                dayPlan.update(
                    item,
                    title: draft.title, detail: draft.detail, kind: draft.kind,
                    customKind: draft.customKind, cadence: draft.cadence,
                    categoryID: draft.categoryID, colorID: draft.colorID
                )
            }
        }
        .sheet(item: $inspectingDayGoal) { item in
            if let goalID = item.linkedGoalID {
                TodayLinkedGoalSheet(goalID: goalID, date: selectedJourneyDate, store: streaks)
            }
        }
        .sheet(item: $promotingDayItem) { item in
            TodayGoalPromotionSheet(item: item) { cadence, tintIndex, targetPerDay in
                guard let goal = addGoal(
                    fromTitle: item.title,
                    detail: item.detail,
                    kind: item.kind,
                    cadence: cadence,
                    tintIndex: tintIndex,
                    targetPerDay: targetPerDay
                ) else { return }
                dayPlan.link(item, to: goal)
                for key in item.completedDayKeys.sorted() {
                    let components = DateComponents(year: key / 10_000, month: (key / 100) % 100, day: key % 100)
                    if let date = Calendar.current.date(from: components) {
                        streaks.setPlannerCompletion(goalID: goal.id, completed: true, date: date)
                    }
                }
            }
        }
    }

    // MARK: - Your Day

    private var dailyJourneyPage: some View {
        let items = plannedItems
        return ScrollViewReader { scroll in
        ScrollView {
            // A single lazy container keeps off-screen rows out of the render
            // tree. The connector is drawn per row, not around the whole list.
            LazyVStack(alignment: .leading, spacing: 8) {
                Color.clear.frame(height: 82).id("planner.start")
                journeyDateRail.padding(.bottom, 6)
                if items.isEmpty {
                    emptyJourney
                } else {
                    goalJourneySummary.padding(.bottom, 6)
                    ForEach(items) { item in
                        SwipeDeleteContainer {
                            withAnimation(.smooth(duration: 0.22)) { dayPlan.delete(item) }
                        } content: {
                            journeyPlanRow(item)
                                .onDrag {
                                    draggingDayItemID = item.id
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    return NSItemProvider(object: item.id.uuidString as NSString)
                                }
                        }
                        .background(alignment: .leading) {
                            PlannerTimelineConnector(first: item.id == items.first?.id, last: item.id == items.last?.id)
                                .stroke(Paper.gold.opacity(0.16), lineWidth: 1)
                                .frame(width: 36)
                        }
                        .onDrop(of: [UTType.text], delegate: DayPlanDropDelegate(
                            targetID: item.id, date: selectedJourneyDate,
                            draggingID: $draggingDayItemID, store: dayPlan
                        ))
                        .padding(.horizontal, 20)
                    }
                    manageJourneyButton.padding(.top, 8)
                }
                // This is scrollable trailing space, not a viewport cutoff:
                // content still flows behind glass, while the last control can
                // be lifted above the expanded native tab bar.
                Color.clear.frame(height: max(bottomInset, 90) + 16).id("planner.end")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
        .onScrollPhaseChange { old, new, context in
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-UITestPlannerPerformance") {
                if !old.isScrolling && new.isScrolling { TodayTransitionFrameProbe.shared.start(name: "todayPlannerScroll") }
                if old.isScrolling && !new.isScrolling {
                    TodayTransitionFrameProbe.shared.stop()
                    UserDefaults.standard.set(context.geometry.contentOffset.y, forKey: "debug.todayPlannerScroll.offsetY")
                    UserDefaults.standard.set(context.geometry.contentSize.height, forKey: "debug.todayPlannerScroll.contentHeight")
                    UserDefaults.standard.set(context.geometry.containerSize.height, forKey: "debug.todayPlannerScroll.viewportHeight")
                }
            }
            #endif
        }
        .onScrollGeometryChange(for: Bool.self) { geometry in
            geometry.contentOffset.y + geometry.contentInsets.top > 28
        } action: { _, condensed in
            if pagerCoordinator.selectedPage == 0, headerCondensed != condensed { headerCondensed = condensed }
        }
        #if DEBUG
        .overlay(alignment: .topTrailing) {
            if ProcessInfo.processInfo.arguments.contains("-UITestPlannerPerformance") {
                HStack {
                    Button("QA ↑") { withAnimation(.linear(duration: 0.8)) { scroll.scrollTo("planner.start", anchor: .top) } }
                        .accessibilityLabel("QA planner top")
                    Button("QA ↓") { withAnimation(.linear(duration: 0.8)) { scroll.scrollTo("planner.end", anchor: .bottom) } }
                        .accessibilityLabel("QA planner bottom")
                }
                .font(.system(size: 10)).padding(8).background(Paper.card)
                .padding(.top, 78).padding(.trailing, 20)
            }
        }
        #endif
        }
    }

    private var plannedItems: [DayPlanItem] {
        dayPlan.items(on: selectedJourneyDate)
    }

    private var completedPlannedItems: Int {
        plannedItems.filter { item in
            if let goal = linkedGoal(for: item) { return streaks.isDone(goal, on: selectedJourneyDate) }
            return dayPlan.isComplete(item, on: selectedJourneyDate)
        }.count
    }

    private var emptyJourney: some View {
        VStack(alignment: .leading, spacing: 18) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 25, weight: .semibold))
                .foregroundStyle(Paper.gold)
                .frame(width: 54, height: 54)
                .background(Paper.gold.opacity(0.11), in: RoundedRectangle(cornerRadius: 18, style: .continuous))

            VStack(alignment: .leading, spacing: 7) {
                Text("Χτίσε την ημέρα σου")
                    .font(.system(size: 25, weight: .semibold, design: .serif))
                    .foregroundStyle(Paper.ink)
                Text("Μία μικρή δουλειά ή ένας στόχος σου. Διάλεξε ό,τι χωρά στην ημέρα σου.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Paper.inkMute)
                    .lineSpacing(3)
            }

            Button { showDayAddMenu = true } label: {
                Label("Πρόσθεσε μία στάση", systemImage: "plus.circle.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Paper.gold, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)

        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Paper.card.opacity(0.86), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(Paper.hairline, lineWidth: 0.8))
        .shadow(color: .black.opacity(0.045), radius: 14, y: 7)
        .padding(.horizontal, 20)
    }

    private var journeyDateRail: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(journeyRelativeDateTitle)
                        .font(.system(size: 30, weight: .semibold, design: .serif))
                        .foregroundStyle(Paper.ink)
                    Text(journeyLongDate)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Paper.inkMute)
                }
                Spacer()
                Button {
                    withAnimation(.smooth(duration: 0.28)) {
                        selectedJourneyDate = Calendar.current.startOfDay(for: Date())
                    }
                } label: {
                    Text("Σήμερα")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Calendar.current.isDateInToday(selectedJourneyDate) ? Paper.inkMute : Paper.gold)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 7)
                        .background(Paper.card.opacity(0.72), in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(Calendar.current.isDateInToday(selectedJourneyDate))
            }
            .padding(.horizontal, 22)

            HStack(spacing: 8) {
                Button { shiftJourneyDate(-1) } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 28, height: 48)
                }
                .buttonStyle(.plain)

                ForEach(journeyRailDates, id: \.self) { date in
                    journeyDayButton(date)
                }

                Button { shiftJourneyDate(1) } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 28, height: 48)
                }
                .buttonStyle(.plain)
            }
            .foregroundStyle(Paper.inkMute)
            .padding(.horizontal, 14)
        }
    }

    private var journeyRailDates: [Date] {
        (-2...2).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: selectedJourneyDate) }
    }

    private func journeyDayButton(_ date: Date) -> some View {
        let selected = Calendar.current.isDate(date, inSameDayAs: selectedJourneyDate)
        return Button {
            withAnimation(.smooth(duration: 0.25)) {
                selectedJourneyDate = Calendar.current.startOfDay(for: date)
            }
        } label: {
            VStack(spacing: 4) {
                Text(date.formatted(.dateTime.weekday(.narrow).locale(Locale(identifier: "el_GR"))))
                    .font(.system(size: 10, weight: .bold))
                Text(date.formatted(.dateTime.day()))
                    .font(.system(size: 17, weight: .bold, design: .rounded))
            }
            .foregroundStyle(selected ? Color.white : Paper.ink)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(selected ? Paper.gold : Paper.card.opacity(0.68), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(selected ? Color.white.opacity(0.18) : Paper.hairline, lineWidth: 0.75)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(date.formatted(date: .complete, time: .omitted))
    }

    private var goalJourneySummary: some View {
        let completed = completedPlannedItems
        let total = plannedItems.count
        let progress = total == 0 ? 0 : Double(completed) / Double(total)

        return HStack(spacing: 12) {
            ZStack {
                Circle().stroke(Paper.gold.opacity(0.14), lineWidth: 5)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Paper.gold, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(completed)/\(total)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Paper.ink)
            }
            .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 4) {
                Text(completed == total ? "Το πρόγραμμά σου ολοκληρώθηκε" : "Το πρόγραμμά σου")
                    .font(.system(size: 16, weight: .semibold, design: .serif))
                    .foregroundStyle(Paper.ink)
                Text(completed == 0 ? (total == 1 ? "Μία στάση γι᾽ αυτή την ημέρα." : "\(total) στάσεις γι᾽ αυτή την ημέρα.") : "\(completed) από \(total) ολοκληρώθηκαν.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Paper.inkMute)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
            Button { showDayAddMenu = true } label: {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Paper.gold)
                    .frame(width: 44, height: 44)
                    .background(Paper.gold.opacity(0.07), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Προσθήκη στην ημέρα")
        }
        .padding(12)
        .background(Paper.card.opacity(0.82), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Paper.hairline, lineWidth: 0.75))
        .padding(.horizontal, 20)
    }


    @ViewBuilder
    private func journeyPlanRow(_ item: DayPlanItem) -> some View {
        if let goal = linkedGoal(for: item) {
            journeyLinkedGoalRow(item, goal: goal)
        } else {
            journeyPersonalRow(item)
        }
    }

    private func journeyPersonalRow(_ item: DayPlanItem) -> some View {
        let complete = dayPlan.isComplete(item, on: selectedJourneyDate)
        let category = categories.category(id: item.categoryID)
        let tint = item.colorID.map(PlannerPalette.tint(for:)) ?? category?.tint ?? item.kind.tint

        return HStack(alignment: .center, spacing: 9) {
            journeyTimelineIcon(
                icon: complete ? "checkmark" : (category?.symbol ?? item.kind.icon),
                tint: complete ? journeySuccess : tint,
                complete: complete,
                emoji: complete ? "" : (category?.emoji ?? "")
            )

            HStack(spacing: 9) {
                Button { editingDayItem = item } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 7) {
                            Text(category?.name ?? item.kindTitle)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(complete ? journeySuccess : tint)
                                .lineLimit(1)
                            if item.cadence.type != .once {
                                Text(item.cadence.title)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(Paper.inkMute)
                                    .lineLimit(1)
                            }
                        }
                        Text(item.title)
                            .font(.system(size: 16, weight: .semibold, design: .serif))
                            .foregroundStyle(Paper.ink)
                            .lineLimit(2)
                        if !item.detail.isEmpty {
                            Text(item.detail)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Paper.inkMute)
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)

                Spacer(minLength: 4)

                HStack(spacing: 8) {
                    Button {
                        let completing = !complete
                        beginCompletionProbe()
                        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.36)) {
                            dayPlan.toggle(item, on: selectedJourneyDate)
                        }
                        if completing { completionHaptic() }
                    } label: {
                        Image(systemName: complete ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 21, weight: .semibold))
                            .foregroundStyle(complete ? journeySuccess : Paper.inkMute.opacity(0.42))
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(complete ? "Σήμανση ως ανολοκλήρωτο" : "Ολοκλήρωση")

                    journeyDragHandle(item)
                }
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 70, alignment: .leading)
            .background { journeyCompletionBackground(complete: complete, tint: tint) }
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke((complete ? journeySuccess : tint).opacity(complete ? 0.34 : 0.18), lineWidth: 0.8))
            .contextMenu {
                Button { editingDayItem = item } label: {
                    Label("Επεξεργασία", systemImage: "pencil")
                }
                Button { promotingDayItem = item } label: {
                    Label("Μετατροπή σε στόχο", systemImage: "flag.badge.plus")
                }
                Button(role: .destructive) { dayPlan.delete(item) } label: {
                    Label("Διαγραφή", systemImage: "trash")
                }
            }
        }
    }

    private func journeyLinkedGoalRow(_ item: DayPlanItem, goal: StreakGoal) -> some View {
        let complete = streaks.isDone(goal, on: selectedJourneyDate)
        let progress = streaks.progressToday(goal, date: selectedJourneyDate)
        let target = streaks.targetToday(goal)

        return HStack(alignment: .center, spacing: 9) {
            journeyTimelineIcon(icon: complete ? "checkmark" : goal.icon, tint: complete ? journeySuccess : goal.tint, complete: complete)

            HStack(spacing: 9) {
                Button { inspectingDayGoal = item } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Label("ΣΤΟΧΟΣ", systemImage: "link")
                                .font(.system(size: 8, weight: .bold))
                                .tracking(1.45)
                                .foregroundStyle(complete ? journeySuccess : goal.tint)
                            Text(goal.metric == .minutes ? "\(progress)/\(target)m" : "\(progress)/\(target)")
                                .font(.system(size: 8, weight: .bold, design: .rounded))
                                .foregroundStyle(Paper.inkMute)
                        }
                        Text(goal.title)
                            .font(.system(size: 16, weight: .semibold, design: .serif))
                            .foregroundStyle(Paper.ink)
                            .lineLimit(1)
                        if !goal.subtitle.isEmpty {
                            Text(goal.subtitle)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Paper.inkMute)
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)

                Button {
                    if complete && !goal.record.plannerCompletedDays.contains(StreakStore.dayStamp(selectedJourneyDate)) {
                        inspectingDayGoal = item
                        return
                    }
                    let completing = !complete
                    beginCompletionProbe()
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.36)) {
                        streaks.setPlannerCompletion(goalID: goal.id, completed: completing, date: selectedJourneyDate)
                    }
                    if completing { completionHaptic() }
                } label: {
                    Image(systemName: complete ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundStyle(complete ? journeySuccess : Paper.inkMute.opacity(0.42))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(complete ? (goal.record.plannerCompletedDays.contains(StreakStore.dayStamp(selectedJourneyDate)) ? "Αναίρεση ολοκλήρωσης στόχου" : "Λεπτομέρειες ολοκληρωμένου στόχου") : "Ολοκλήρωση στόχου")

                journeyDragHandle(item)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 70, alignment: .leading)
            .background { journeyCompletionBackground(complete: complete, tint: goal.tint) }
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke((complete ? journeySuccess : goal.tint).opacity(complete ? 0.34 : 0.12), lineWidth: 0.8))
            .contextMenu {
                Button { inspectingDayGoal = item } label: { Label("Λεπτομέρειες", systemImage: "info.circle") }
                Button(role: .destructive) { dayPlan.delete(item) } label: { Label("Αφαίρεση από την ημέρα", systemImage: "trash") }
            }
        }
    }

    private var journeySuccess: Color {
        Color(red: 0.20, green: 0.62, blue: 0.39)
    }

    private func journeyCompletionBackground(complete: Bool, tint: Color) -> some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        return ZStack(alignment: .leading) {
            shape.fill(Paper.card.opacity(0.88))
            shape.fill(LinearGradient(colors: [tint.opacity(complete ? 0 : 0.13), tint.opacity(complete ? 0 : 0.035)], startPoint: .topLeading, endPoint: .bottomTrailing))
            GeometryReader { geometry in
                Rectangle()
                    .fill(journeySuccess.opacity(0.18))
                    .frame(width: complete ? geometry.size.width : 0)
            }
            .clipShape(shape)
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.36), value: complete)
    }

    private func beginCompletionProbe() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-UITestPlannerPerformance") {
            TodayTransitionFrameProbe.shared.start(name: "todayPlannerCompletion")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.95) { TodayTransitionFrameProbe.shared.stop() }
        }
        #endif
    }

    private func completionHaptic() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }

    private func linkedGoal(for item: DayPlanItem) -> StreakGoal? {
        guard let goalID = item.linkedGoalID else { return nil }
        return streaks.goals.first { $0.id == goalID }
    }

    private func journeyTimelineIcon(icon: String, tint: Color, complete: Bool, emoji: String = "") -> some View {
        PlannerCategoryGlyph(symbol: icon, emoji: emoji)
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(complete ? Color.white : tint)
            .frame(width: 36, height: 36)
            .background(complete ? tint : Paper.card, in: Circle())
            .overlay(Circle().stroke(tint.opacity(0.32), lineWidth: 1))
            .zIndex(2)
    }

    private func journeyDragHandle(_ item: DayPlanItem) -> some View {
        Image(systemName: "line.3.horizontal")
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(Paper.inkMute.opacity(0.45))
            .frame(width: 22, height: 44)
            .contentShape(Rectangle())
            .accessibilityHidden(true)
    }

    private func addGoal(
        fromTitle title: String,
        detail: String,
        kind: DayPlanKind,
        cadence: GoalCadence,
        tintIndex: Int,
        targetPerDay: Int
    ) -> StreakGoal? {
        streaks.addGoal(
            title: title,
            subtitle: detail,
            cadence: cadence,
            source: .manual,
            icon: kind.icon,
            tintIndex: tintIndex,
            targetPerDay: targetPerDay
        )
    }

    private var manageJourneyButton: some View {
        Button { showDayAddMenu = true } label: {
            Label("Προσθήκη στην ημέρα", systemImage: "plus")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Paper.gold)
                .frame(maxWidth: .infinity, minHeight: 46)
                .background(Paper.card.opacity(0.76), in: Capsule())
                .overlay(Capsule().stroke(Paper.gold.opacity(0.14), lineWidth: 0.8))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
    }

    private var journeyRelativeDateTitle: String {
        if Calendar.current.isDateInToday(selectedJourneyDate) { return "Σήμερα" }
        if Calendar.current.isDateInYesterday(selectedJourneyDate) { return "Χθές" }
        if Calendar.current.isDateInTomorrow(selectedJourneyDate) { return "Αύριο" }
        return selectedJourneyDate.formatted(.dateTime.weekday(.wide).locale(Locale(identifier: "el_GR")))
            .capitalized
    }

    private var journeyLongDate: String {
        selectedJourneyDate.formatted(
            .dateTime.day().month(.wide).year().locale(Locale(identifier: "el_GR"))
        )
    }

    private func shiftJourneyDate(_ days: Int) {
        guard let date = Calendar.current.date(byAdding: .day, value: days, to: selectedJourneyDate) else { return }
        withAnimation(.smooth(duration: 0.25)) {
            selectedJourneyDate = Calendar.current.startOfDay(for: date)
        }
    }

}

private struct DayPlanDraft {
    let title: String
    let detail: String
    let kind: DayPlanKind
    let customKind: String
    let cadence: DayPlanCadence
    let categoryID: UUID?
    let colorID: String?
}

private struct PlannerTimelineConnector: Shape {
    let first: Bool
    let last: Bool
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: first ? rect.midY : -4))
        path.addLine(to: CGPoint(x: rect.midX, y: last ? rect.midY : rect.maxY + 4))
        return path
    }
}

/// One surface for a quick item, optional details, and any number of existing goals.
private struct TodayDayComposerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var categories = PlannerCategoryStore.shared
    let date: Date
    let item: DayPlanItem?
    let goals: [StreakGoal]
    let linkedGoalIDs: Set<UUID>
    let onSave: (DayPlanDraft?, [StreakGoal]) -> Void

    @State private var title: String
    @State private var detail: String
    @State private var kind: DayPlanKind
    @State private var customKind: String
    @State private var categoryID: UUID?
    @State private var colorID: String?
    @State private var categoryEditor: CategoryEditorSelection?
    @State private var cadenceType: DayPlanCadenceType
    @State private var weekdays: Set<Int>
    @State private var showDetails: Bool
    @State private var selectedGoalIDs: Set<UUID> = []
    @State private var goalSearch = ""
    @State private var detent: PresentationDetent = .height(540)
    @State private var saving = false
    private enum Field: Hashable { case title, search }
    @FocusState private var focusedField: Field?

    init(
        date: Date,
        item: DayPlanItem? = nil,
        goals: [StreakGoal] = [],
        linkedGoalIDs: Set<UUID> = [],
        onSave: @escaping (DayPlanDraft?, [StreakGoal]) -> Void
    ) {
        self.date = date
        self.item = item
        self.goals = goals
        self.linkedGoalIDs = linkedGoalIDs
        self.onSave = onSave
        _title = State(initialValue: item?.title ?? "")
        _detail = State(initialValue: item?.detail ?? "")
        _kind = State(initialValue: item?.kind ?? .personal)
        _customKind = State(initialValue: item?.customKind ?? "")
        _categoryID = State(initialValue: item?.categoryID)
        _colorID = State(initialValue: item?.colorID)
        _cadenceType = State(initialValue: item?.cadence.type ?? .once)
        _weekdays = State(initialValue: item?.cadence.weekdays ?? [])
        _showDetails = State(initialValue: item != nil)
    }

    private var trimmedTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var selectedCategory: PlannerCategory? { categories.category(id: categoryID) }
    private var entryTint: Color { colorID.map(PlannerPalette.tint(for:)) ?? selectedCategory?.tint ?? kind.tint }
    private struct CategoryEditorSelection: Identifiable, Hashable {
        var id = UUID()
        var category: PlannerCategory?
    }
    private var selectedGoals: [StreakGoal] {
        goals.filter { selectedGoalIDs.contains($0.id) && !linkedGoalIDs.contains($0.id) }
    }
    private var selectionCount: Int { selectedGoals.count + (trimmedTitle.isEmpty ? 0 : 1) }
    private var canSave: Bool {
        guard !saving, selectionCount > 0 else { return false }
        return trimmedTitle.isEmpty || cadenceType != .weekdays || !weekdays.isEmpty
    }
    private var visibleGoals: [StreakGoal] {
        let matching = goals.filter {
            goalSearch.isEmpty || $0.title.localizedStandardContains(goalSearch) ||
            $0.subtitle.localizedStandardContains(goalSearch)
        }
        // Retain the user's goal order within each group.
        return matching.filter { !linkedGoalIDs.contains($0.id) } + matching.filter { linkedGoalIDs.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(date.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(Locale(identifier: "el_GR"))))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Paper.gold)
                        if item == nil {
                            Text("Γράψε κάτι ή διάλεξε από τους στόχους σου.")
                                .font(.system(size: 13))
                                .foregroundStyle(Paper.inkMute)
                        }
                    }
                    entryCard
                    if item == nil { goalsSection }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 18)
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollIndicators(.hidden)
            .safeAreaInset(edge: .bottom, spacing: 0) { saveBar }
            .background(AppAtmosphere().ignoresSafeArea())
            .navigationTitle(item == nil ? "Προσθήκη στην ημέρα" : "Επεξεργασία")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.system(size: 13, weight: .semibold))
                    }
                    .tint(Paper.inkMute)
                    .accessibilityLabel("Κλείσιμο")
                }
            }
            .navigationDestination(item: $categoryEditor) { selection in
                PlannerCategoryEditor(category: selection.category, embedded: true) { category in
                    categoryID = category.id
                    kind = .other
                    customKind = category.name
                    colorID = nil
                }
            }
        }
        .presentationDetents([.height(540), .large], selection: $detent)
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(30)
        .onChange(of: focusedField) { _, field in
            if field != nil { detent = .large }
        }
        .onChange(of: categoryEditor) { _, selection in
            if selection != nil { detent = .large }
        }
    }

    private var entryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                PlannerCategoryGlyph(symbol: selectedCategory?.symbol ?? kind.icon, emoji: selectedCategory?.emoji ?? "")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(entryTint)
                    .frame(width: 38, height: 42)
                    .background(entryTint.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
                TextField("Τι θέλεις να κάνεις;", text: $title, axis: .vertical)
                    .font(.system(size: 19, weight: .medium, design: .serif))
                    .foregroundStyle(Paper.ink)
                    .lineLimit(1...3)
                    .padding(.vertical, 9)
                    .focused($focusedField, equals: .title)
                    .accessibilityIdentifier("dayComposer.title")
            }

            HStack(spacing: 8) {
                categoryMenu
                Menu {
                    Picker("Επανάληψη", selection: $cadenceType) {
                        ForEach(DayPlanCadenceType.allCases) { cadence in
                            Text(cadence.title).tag(cadence)
                        }
                    }
                } label: {
                    Label(cadenceType == .once ? "Μία φορά" : cadenceType.title, systemImage: "repeat")
                        .lineLimit(1)
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 11).frame(minHeight: 44)
                        .background(Paper.inkMute.opacity(0.06), in: Capsule())
                }
                .tint(Paper.inkMute)
                .accessibilityLabel("Επανάληψη")
            }

            if cadenceType == .weekdays {
                TodayWeekdayPicker(selection: $weekdays)
                if weekdays.isEmpty {
                    Text("Διάλεξε τουλάχιστον μία ημέρα.")
                        .font(.system(size: 11)).foregroundStyle(Paper.inkMute)
                }
            }

            Button {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                    showDetails.toggle()
                }
                if showDetails { detent = .large }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "slider.horizontal.3")
                    Text(showDetails ? "Λιγότερα" : "Σημείωση και εμφάνιση")
                    Spacer(minLength: 0)
                    Image(systemName: showDetails ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Paper.inkMute)
                .frame(minHeight: 30)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if showDetails {
                Divider().overlay(Paper.hairline)
                TextField("Σημείωση (προαιρετικό)", text: $detail, axis: .vertical)
                    .font(.system(size: 14))
                    .lineLimit(2...4)
                    .foregroundStyle(Paper.ink)

                cardColourPicker
            }
        }
        .padding(16)
        .background(Paper.card.opacity(0.9), in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(entryTint.opacity(0.18), lineWidth: 0.8))
    }

    private var categoryMenu: some View {
        Menu {
            Section("Κατηγορίες") {
                ForEach(DayPlanKind.allCases) { option in
                    Button {
                        kind = option; categoryID = nil; customKind = ""; colorID = nil
                    } label: { Label(option.title, systemImage: option.icon) }
                }
            }
            if !categories.categories.isEmpty {
                Section("Δικές σου κατηγορίες") {
                    ForEach(categories.categories) { category in
                        Button {
                            categoryID = category.id; kind = .other; customKind = category.name; colorID = nil
                        } label: {
                            Label(category.emoji.isEmpty ? category.name : "\(category.emoji) \(category.name)", systemImage: category.symbol)
                        }
                    }
                }
            }
            Section {
                Button {
                    focusedField = nil
                    categoryEditor = CategoryEditorSelection(category: nil)
                } label: { Label("Νέα κατηγορία", systemImage: "plus.circle") }
                if let selectedCategory {
                    Button {
                        focusedField = nil
                        categoryEditor = CategoryEditorSelection(category: selectedCategory)
                    } label: { Label("Επεξεργασία κατηγορίας", systemImage: "pencil") }
                }
            }
        } label: {
            HStack(spacing: 6) {
                PlannerCategoryGlyph(symbol: selectedCategory?.symbol ?? kind.icon, emoji: selectedCategory?.emoji ?? "")
                Text(selectedCategory?.name ?? (kind == .other && !customKind.isEmpty ? customKind : kind.title)).lineLimit(1)
                Image(systemName: "chevron.down").font(.system(size: 8, weight: .bold))
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(entryTint)
            .padding(.horizontal, 11).frame(minHeight: 44)
            .background(entryTint.opacity(0.09), in: Capsule())
        }
        .accessibilityLabel("Κατηγορία")
        .accessibilityValue(selectedCategory?.name ?? kind.title)
        .accessibilityIdentifier("dayComposer.category")
    }

    private var cardColourPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Χρώμα κάρτας").font(.system(size: 12, weight: .semibold))
                Spacer()
                Button("Της κατηγορίας") { colorID = nil }
                    .font(.system(size: 11, weight: .medium)).tint(entryTint)
                    .frame(minHeight: 44)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 4), spacing: 4) {
                ForEach(PlannerPalette.options) { option in
                    Button { colorID = option.id } label: {
                        Circle().fill(option.tint.opacity(0.65))
                            .frame(width: 26, height: 26)
                            .overlay {
                                if colorID == option.id {
                                    Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
                                }
                            }
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(option.name)
                    .accessibilityAddTraits(colorID == option.id ? .isSelected : [])
                }
            }
            Text("Η κατηγορία παραμένει η ίδια· το χρώμα αλλάζει μόνο αυτή την κάρτα.")
                .font(.system(size: 11)).foregroundStyle(Paper.inkMute)
        }
        .foregroundStyle(Paper.inkMute)
    }

    private var goalsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Από τους στόχους σου")
                    .font(.system(size: 17, weight: .semibold, design: .serif))
                    .foregroundStyle(Paper.ink)
                Spacer()
                if !selectedGoalIDs.isEmpty {
                    Text("\(selectedGoalIDs.count) επιλεγμένοι")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Paper.gold)
                }
            }

            if goals.isEmpty {
                Text("Οι στόχοι σου θα εμφανίζονται εδώ για γρήγορη προσθήκη.")
                    .font(.system(size: 13))
                    .foregroundStyle(Paper.inkMute)
                    .padding(.vertical, 8)
            } else {
                if goals.count > 6 {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                        TextField("Βρές έναν στόχο", text: $goalSearch)
                            .focused($focusedField, equals: .search)
                    }
                    .font(.system(size: 14))
                    .foregroundStyle(Paper.inkMute)
                    .padding(12)
                    .background(Paper.card.opacity(0.7), in: RoundedRectangle(cornerRadius: 14))
                }

                LazyVStack(spacing: 7) {
                    ForEach(visibleGoals) { goal in goalOption(goal) }
                }
                if visibleGoals.isEmpty {
                    Text("Δεν βρέθηκε στόχος.")
                        .font(.system(size: 13))
                        .foregroundStyle(Paper.inkMute)
                }
                Text("Διάλεξε όσους θέλεις. Η πρόοδος ενημερώνεται αυτόματα.")
                    .font(.system(size: 11))
                    .foregroundStyle(Paper.inkMute)
            }
        }
    }

    private func goalOption(_ goal: StreakGoal) -> some View {
        let added = linkedGoalIDs.contains(goal.id)
        let selected = selectedGoalIDs.contains(goal.id)
        return Button {
            focusedField = nil
            if selected { selectedGoalIDs.remove(goal.id) } else { selectedGoalIDs.insert(goal.id) }
            UISelectionFeedbackGenerator().selectionChanged()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: goal.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(goal.tint)
                    .frame(width: 36, height: 36)
                    .background(goal.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 11))
                VStack(alignment: .leading, spacing: 3) {
                    Text(goal.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Paper.ink)
                        .lineLimit(2)
                    if added {
                        Text("Ήδη στην ημέρα σου")
                            .font(.system(size: 11))
                            .foregroundStyle(Paper.inkMute)
                    } else if !goal.subtitle.isEmpty {
                        Text(goal.subtitle)
                            .font(.system(size: 11))
                            .foregroundStyle(Paper.inkMute)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: added || selected ? "checkmark.circle.fill" : "plus.circle")
                    .font(.system(size: 23, weight: .regular))
                    .foregroundStyle(added ? Paper.inkMute.opacity(0.5) : Paper.gold)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(selected ? Paper.gold.opacity(0.07) : Paper.card.opacity(0.76), in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(selected ? Paper.gold.opacity(0.3) : Paper.hairline, lineWidth: 0.8))
            .contentShape(RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
        .disabled(added)
        .accessibilityLabel(goal.title)
        .accessibilityValue(added ? "Ήδη στην ημέρα" : selected ? "Επιλεγμένο" : "Προσθήκη")
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    private var saveBar: some View {
        Button {
            guard canSave else { return }
            saving = true
            let draft: DayPlanDraft? = trimmedTitle.isEmpty ? nil : DayPlanDraft(
                title: trimmedTitle, detail: detail, kind: kind, customKind: customKind,
                cadence: DayPlanCadence(type: cadenceType, weekdays: weekdays),
                categoryID: categoryID, colorID: colorID
            )
            onSave(draft, selectedGoals)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            dismiss()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: item == nil ? "plus" : "checkmark")
                Text(item != nil ? "Αποθήκευση" : selectionCount > 1 ? "Προσθήκη \(selectionCount)" : "Προσθήκη")
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(canSave ? Color.white : Paper.inkMute)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(canSave ? Paper.gold : Paper.inkMute.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!canSave)
        .accessibilityIdentifier("dayComposer.save")
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(.ultraThinMaterial)
    }
}

private struct TodayWeekdayPicker: View {
    @Binding var selection: Set<Int>
    private let days: [(value: Int, label: String, name: String)] = [
        (2, "Δ", "Δευτέρα"), (3, "Τ", "Τρίτη"), (4, "Τ", "Τετάρτη"),
        (5, "Π", "Πέμπτη"), (6, "Π", "Παρασκευή"), (7, "Σ", "Σάββατο"), (1, "Κ", "Κυριακή")
    ]

    var body: some View {
        HStack(spacing: 5) {
            ForEach(days, id: \.value) { day in
                let selected = selection.contains(day.value)
                Button {
                    if selected { selection.remove(day.value) } else { selection.insert(day.value) }
                } label: {
                    Text(day.label)
                        .font(.system(size: 13, weight: .semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .foregroundStyle(selected ? Color.white : Paper.inkMute)
                        .background(selected ? Paper.gold : Paper.inkMute.opacity(0.07), in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(day.name)
                .accessibilityAddTraits(selected ? [.isSelected] : [])
            }
        }
    }
}

/// Goal details stay within Today and read the live shared Goal record.
private struct TodayLinkedGoalSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: StreakStore
    let goalID: UUID
    let date: Date

    init(goalID: UUID, date: Date, store: StreakStore) {
        self.goalID = goalID
        self.date = date
        self.store = store
    }

    private var goal: StreakGoal? { store.goals.first { $0.id == goalID } }

    var body: some View {
        NavigationStack {
            ScrollView {
                if let goal {
                    let complete = store.isDone(goal, on: date)
                    let manuallyCompleted = goal.record.plannerCompletedDays.contains(StreakStore.dayStamp(date))
                    VStack(alignment: .leading, spacing: 18) {
                        HStack(spacing: 14) {
                            Image(systemName: goal.icon)
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundStyle(goal.tint)
                                .frame(width: 52, height: 52)
                                .background(goal.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 17))
                            VStack(alignment: .leading, spacing: 5) {
                                Text(goal.title)
                                    .font(.system(size: 23, weight: .semibold, design: .serif))
                                    .foregroundStyle(Paper.ink)
                                Text(date.formatted(.dateTime.day().month(.wide).locale(Locale(identifier: "el_GR"))))
                                    .font(.system(size: 12))
                                    .foregroundStyle(Paper.inkMute)
                            }
                        }
                        if !goal.subtitle.isEmpty {
                            Text(goal.subtitle).font(.system(size: 15)).foregroundStyle(Paper.inkMute)
                        }
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text(complete ? "Ολοκληρώθηκε" : "Η πρόοδός σου")
                                Spacer()
                                Text("\(store.progressToday(goal, date: date))/\(store.targetToday(goal))\(goal.metric == .minutes ? "′" : "")")
                                    .monospacedDigit()
                            }
                            .font(.system(size: 13, weight: .semibold))
                            ProgressView(value: min(1, Double(store.progressToday(goal, date: date)) / Double(store.targetToday(goal))))
                                .tint(complete ? .green : goal.tint)
                        }
                        .foregroundStyle(Paper.ink)
                        .padding(16)
                        .background(Paper.card.opacity(0.85), in: RoundedRectangle(cornerRadius: 18))

                        Text(complete && !manuallyCompleted ? "Ολοκληρώθηκε από τη δραστηριότητά σου στην εφαρμογή." : "Η πρόοδός σου ενημερώνεται και στους Στόχους.")
                            .font(.system(size: 12))
                            .foregroundStyle(Paper.inkMute)

                        if !complete || manuallyCompleted {
                            Button {
                                store.setPlannerCompletion(goalID: goal.id, completed: !complete, date: date)
                                if !complete { UINotificationFeedbackGenerator().notificationOccurred(.success) }
                                dismiss()
                            } label: {
                                Label(complete ? "Αναίρεση ολοκλήρωσης" : "Ολοκληρώθηκε", systemImage: complete ? "arrow.uturn.backward" : "checkmark")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity, minHeight: 50)
                                    .background(complete ? Paper.gold : Color(red: 0.20, green: 0.62, blue: 0.39), in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(22)
                } else {
                    ContentUnavailableView("Ο στόχος δεν είναι πλέον διαθέσιμος", systemImage: "flag")
                }
            }
            .background(AppAtmosphere().ignoresSafeArea())
            .navigationTitle("Στην ημέρα σου")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Κλείσιμο") { dismiss() }.tint(Paper.gold)
                }
            }
        }
        .presentationDetents([.height(430), .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(30)
    }
}

private struct TodayGoalPromotionSheet: View {
    @Environment(\.dismiss) private var dismiss
    let item: DayPlanItem
    let onSave: (GoalCadence, Int, Int) -> Void

    @State private var cadenceType: GoalCadenceType
    @State private var weekdays: Set<Int>
    @State private var tintIndex: Int
    @State private var targetPerDay = 1

    private let colors: [Color] = [
        Color(red: 0.18, green: 0.48, blue: 0.55),
        Color(red: 0.43, green: 0.52, blue: 0.32),
        Color(red: 0.46, green: 0.20, blue: 0.28),
        Color(red: 0.48, green: 0.32, blue: 0.46),
        Color(red: 0.66, green: 0.48, blue: 0.20),
        Paper.gold
    ]

    init(item: DayPlanItem, onSave: @escaping (GoalCadence, Int, Int) -> Void) {
        self.item = item
        self.onSave = onSave
        let type: GoalCadenceType
        switch item.cadence.type {
        case .weekdays: type = .weekdays
        case .weekly: type = .weekly
        case .once, .daily: type = .daily
        }
        _cadenceType = State(initialValue: type)
        _weekdays = State(initialValue: item.cadence.weekdays)
        _tintIndex = State(initialValue: Self.defaultTint(for: item.kind))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Label {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.title).font(.headline)
                            if !item.detail.isEmpty { Text(item.detail).font(.caption).foregroundStyle(.secondary) }
                        }
                    } icon: {
                        Image(systemName: item.kind.icon)
                            .foregroundStyle(colors[tintIndex])
                    }
                } footer: {
                    Text("Θα προστεθεί στους Στόχους και θα παραμείνει στην ημέρα σου, με κοινή πρόοδο.")
                }

                Section("Ρυθμός στόχου") {
                    Picker("Συχνότητα", selection: $cadenceType) {
                        Text("Κάθε μέρα").tag(GoalCadenceType.daily)
                        Text("Μία φορά την εβδομάδα").tag(GoalCadenceType.weekly)
                        Text("Συγκεκριμένες ημέρες").tag(GoalCadenceType.weekdays)
                    }
                    .pickerStyle(.navigationLink)

                    if cadenceType == .weekdays {
                        HStack(spacing: 6) {
                            ForEach(GoalCadence.weekdayOptions, id: \.value) { day in
                                let selected = weekdays.contains(day.value)
                                Button {
                                    if selected { weekdays.remove(day.value) } else { weekdays.insert(day.value) }
                                } label: {
                                    Text(day.label.prefix(1))
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(selected ? Color.white : Paper.inkMute)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 34)
                                        .background(selected ? colors[tintIndex] : Paper.card, in: Circle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    Stepper("Φορές κάθε προγραμματισμένη ημέρα: \(targetPerDay)", value: $targetPerDay, in: 1...20)
                }

                Section("Χρώμα") {
                    HStack(spacing: 13) {
                        ForEach(Array(colors.enumerated()), id: \.offset) { index, color in
                            Button { tintIndex = index } label: {
                                Circle()
                                    .fill(color)
                                    .frame(width: 31, height: 31)
                                    .overlay(Circle().stroke(tintIndex == index ? Paper.ink : .clear, lineWidth: 3).padding(-3))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 5)
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppAtmosphere().ignoresSafeArea())
            .navigationTitle("Νέος στόχος")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Κλείσιμο") { dismiss() }.tint(Paper.gold) }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    onSave(GoalCadence(type: cadenceType, weekdays: weekdays), tintIndex, targetPerDay)
                    dismiss()
                } label: {
                    Label("Δημιουργία στόχου", systemImage: "flag")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(Paper.gold, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(cadenceType == .weekdays && weekdays.isEmpty)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
            }
        }
        .presentationDetents([.medium, .large])
    }

    private static func defaultTint(for kind: DayPlanKind) -> Int {
        switch kind {
        case .personal, .other: 0
        case .fasting: 1
        case .reading: 2
        case .quiet: 3
        case .church: 4
        case .prayer: 5
        }
    }
}

private struct SwipeDeleteContainer<Content: View>: View {
    let onDelete: () -> Void
    private let content: Content
    @State private var revealed = false
    @State private var dragOffset: CGFloat = 0

    init(onDelete: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.onDelete = onDelete
        self.content = content()
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            content
                .contentShape(Rectangle())
                .gesture(PlannerHorizontalSwipe { translation, ended, cancelled in
                    if ended {
                        if cancelled {
                            withAnimation(.smooth(duration: 0.2)) { dragOffset = 0 }
                        } else if translation < -132 {
                            dragOffset = 0
                            onDelete()
                        } else {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                                revealed = (revealed ? -74 : 0) + translation < -44
                                dragOffset = 0
                            }
                        }
                    } else {
                        dragOffset = translation
                    }
                })
                // Move the hit region with the card, not just its drawing.
                .offset(x: max(-88, min(0, (revealed ? -74 : 0) + dragOffset)))

            if revealed || dragOffset < -1 {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 74)
                        .frame(maxHeight: .infinity)
                        .background(Color.red, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .zIndex(1)
                .accessibilityLabel("Διαγραφή από την ημέρα")
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .onAppear { revealed = false }
        .accessibilityAction(named: Text("Διαγραφή από την ημέρα")) { onDelete() }
    }
}

/// Reject vertical pans before recognition, rather than after a SwiftUI drag
/// has already competed with the scroll view's gesture.
private struct PlannerHorizontalSwipe: UIGestureRecognizerRepresentable {
    let onChange: (CGFloat, Bool, Bool) -> Void

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return false }
            let velocity = pan.velocity(in: pan.view)
            return abs(velocity.x) > abs(velocity.y) * 1.4
        }
    }

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator { Coordinator() }

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let pan = UIPanGestureRecognizer()
        pan.maximumNumberOfTouches = 1
        pan.delegate = context.coordinator
        return pan
    }

    func handleUIGestureRecognizerAction(_ recognizer: UIPanGestureRecognizer, context: Context) {
        switch recognizer.state {
        case .began, .changed:
            onChange(recognizer.translation(in: recognizer.view).x, false, false)
        case .ended:
            onChange(recognizer.translation(in: recognizer.view).x, true, false)
        case .cancelled, .failed:
            onChange(0, true, true)
        default: break
        }
    }
}

private struct DayPlanDropDelegate: DropDelegate {
    let targetID: UUID
    let date: Date
    @Binding var draggingID: UUID?
    let store: TodayDayPlanStore

    func dropEntered(info: DropInfo) {
        guard let draggingID, draggingID != targetID else { return }
        withAnimation(.smooth(duration: 0.18)) {
            store.move(draggingID, before: targetID, on: date)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingID = nil
        return true
    }
}

struct AppAtmosphere: View {
    var body: some View {
        ZStack {
            Paper.bg

            LinearGradient(
                colors: [
                    Color.adaptive(
                        Color(red: 0.93, green: 0.95, blue: 0.94),
                        Color(red: 0.055, green: 0.071, blue: 0.096)
                    ),
                    Paper.bg,
                    Color.adaptive(
                        Color(red: 0.95, green: 0.92, blue: 0.87),
                        Color(red: 0.075, green: 0.068, blue: 0.088)
                    )
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [Paper.gold.opacity(0.09), Paper.gold.opacity(0)],
                center: .center,
                startRadius: 0,
                endRadius: 210
            )
                .frame(width: 420, height: 420)
                .offset(x: 170, y: -190)

            RadialGradient(
                colors: [
                    Color.adaptive(
                        Color(red: 0.44, green: 0.63, blue: 0.63).opacity(0.11),
                        Color(red: 0.18, green: 0.30, blue: 0.34).opacity(0.17)
                    ),
                    .clear
                ],
                center: .center,
                startRadius: 0,
                endRadius: 195
            )
                .frame(width: 390, height: 390)
                .offset(x: -180, y: 260)

            LinearGradient(
                colors: [.white.opacity(0.12), .clear, Paper.gold.opacity(0.025)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .allowsHitTesting(false)
    }
}

/// The same translucent continuation of `AppAtmosphere` on every root tab.
/// Keeping this in one place prevents Logos and Prayer from looking like a
/// separate sheet pasted over their content.
struct AppHeaderSurface: View {
    let condensed: Bool

    var body: some View {
        ZStack(alignment: .bottom) {
            Rectangle().fill(.ultraThinMaterial)
            LinearGradient(
                colors: [
                    Color.adaptive(
                        Color(red: 0.93, green: 0.95, blue: 0.94).opacity(condensed ? 0.58 : 0.30),
                        Color(red: 0.055, green: 0.071, blue: 0.096).opacity(condensed ? 0.58 : 0.30)
                    ),
                    Paper.bg.opacity(condensed ? 0.52 : 0.24)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Rectangle().fill(Paper.hairline).frame(height: 0.75)
        }
        .shadow(color: .black.opacity(condensed ? 0.08 : 0.02), radius: 14, y: 7)
        .ignoresSafeArea(edges: .top)
    }
}

@MainActor
private final class TodayPagerCoordinator {
    var selectedPage = 0
    var widgetRefreshTask: Task<Void, Never>?
}

/// Keeps a SwiftUI page mounted while changing only the hosting view's native
/// visibility. That avoids both an opacity compositing group (which changes
/// glass rendering) and a SwiftUI z-order/layout pass at switch time.
private struct TodayMountedPageHost<Content: View>: UIViewControllerRepresentable {
    let content: Content
    let isVisible: Bool
    var updatesContent = true

    final class Coordinator {
        var lastVisibility: Bool?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIViewController(context: Context) -> UIHostingController<Content> {
        let controller = UIHostingController(rootView: content)
        // The surrounding SwiftUI layout owns safe areas. A second set from
        // this embedded controller otherwise clips content above the tab glass.
        controller.safeAreaRegions = .keyboard
        controller.view.backgroundColor = .clear
        controller.view.isHidden = !isVisible
        context.coordinator.lastVisibility = isVisible
        return controller
    }

    func updateUIViewController(_ controller: UIHostingController<Content>, context: Context) {
        controller.view.isHidden = !isVisible

        // Hidden widgets don't need a layout pass for each planner update.
        // Refresh the incoming hierarchy under the fully opaque fade cover.
        if isVisible && updatesContent {
            controller.rootView = content
        }
        context.coordinator.lastVisibility = isVisible
    }
}

/// Owns the frequently-changing pager state outside `TodayView`. The two large
/// page trees are stored values here, so moving the switch no longer asks the
/// entire Today feature to rebuild itself.
private struct TodayPageSwitcher<DailyPage: View, DashboardPage: View, Header: View>: View {
    let coordinator: TodayPagerCoordinator
    let transitionTopInset: CGFloat
    let dailyPage: DailyPage
    let dashboardPage: DashboardPage
    let header: (Int, Bool, @escaping () -> Void) -> Header

    @State private var page = 0
    @State private var pendingPage: Int?
    @State private var transitionID = UUID()

    init(
        coordinator: TodayPagerCoordinator,
        transitionTopInset: CGFloat,
        dailyPage: DailyPage,
        dashboardPage: DashboardPage,
        @ViewBuilder header: @escaping (Int, Bool, @escaping () -> Void) -> Header
    ) {
        self.coordinator = coordinator
        self.transitionTopInset = transitionTopInset
        self.dailyPage = dailyPage
        self.dashboardPage = dashboardPage
        self.header = header
        _page = State(initialValue: coordinator.selectedPage)
    }

    var body: some View {
        ZStack(alignment: .top) {
            ZStack {
                TodayMountedPageHost(content: dailyPage, isVisible: page == 0, updatesContent: false)
                TodayMountedPageHost(content: dashboardPage, isVisible: page == 1)
            }
            .ignoresSafeArea(.container, edges: .bottom)

            if let destination = pendingPage {
                TodaySnapshotTransition(
                    swapPages: {
                        var transaction = Transaction()
                        transaction.disablesAnimations = true
                        withTransaction(transaction) {
                            page = destination
                            coordinator.selectedPage = destination
                        }
                    },
                    completion: {
                        pendingPage = nil
                        #if DEBUG
                        TodayTransitionFrameProbe.shared.stop()
                        if ProcessInfo.processInfo.arguments.contains("-UITestTodayTransitionTwice"),
                           !TodayTransitionAutomation.shared.didRunReverse {
                            TodayTransitionAutomation.shared.didRunReverse = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                                switchPage()
                            }
                        }
                        #endif
                    }
                )
                .id(transitionID)
                .padding(.top, transitionTopInset)
                .ignoresSafeArea(.container, edges: .bottom)
                .zIndex(5)
                .allowsHitTesting(true)
            }

            // The switch begins moving as soon as it is pressed, while the
            // content completes its fade underneath. Once the content swaps,
            // this value is unchanged, so the thumb never snaps mid-transition.
            header(pendingPage ?? page, pendingPage != nil, switchPage)
                .zIndex(10)
        }
        .background { AppAtmosphere().ignoresSafeArea() }
        .onAppear {
            #if DEBUG
            let arguments = ProcessInfo.processInfo.arguments
            if (arguments.contains("-UITestTodayTransition") || arguments.contains("-UITestTodayTransitionTwice")),
               !TodayTransitionAutomation.shared.didRun {
                TodayTransitionAutomation.shared.didRun = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    switchPage()
                }
            }
            #endif
        }
    }

    private func switchPage() {
        guard pendingPage == nil else { return }
        #if DEBUG
        TodayTransitionFrameProbe.shared.start()
        #endif
        transitionID = UUID()
        pendingPage = page == 0 ? 1 : 0
    }
}

/// Performs a short fade-through on Core Animation's compositor. The real page
/// trees remain mounted and are never animated frame by frame.
private struct TodaySnapshotTransition: UIViewRepresentable {
    let swapPages: () -> Void
    let completion: () -> Void

    func makeUIView(context: Context) -> TodaySnapshotTransitionView {
        let view = TodaySnapshotTransitionView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = true
        view.clipsToBounds = true
        return view
    }

    func updateUIView(_ uiView: TodaySnapshotTransitionView, context: Context) {
        uiView.startIfNeeded(
            backgroundColor: UIColor(Paper.bg),
            swapPages: swapPages,
            completion: completion
        )
    }
}

private final class TodaySnapshotTransitionView: UIView {
    private var hasStarted = false

    func startIfNeeded(
        backgroundColor: UIColor,
        swapPages: @escaping () -> Void,
        completion: @escaping () -> Void
    ) {
        guard !hasStarted else { return }
        hasStarted = true

        DispatchQueue.main.async { [weak self] in
            guard let self, !self.bounds.isEmpty else {
                swapPages()
                completion()
                return
            }

            self.backgroundColor = backgroundColor
            self.alpha = 0

            if UIAccessibility.isReduceMotionEnabled {
                swapPages()
                completion()
                return
            }

            UIView.animate(
                withDuration: 0.16,
                delay: 0,
                options: [.curveEaseInOut, .beginFromCurrentState, .allowUserInteraction],
                animations: { self.alpha = 1 },
                completion: { _ in
                swapPages()
                    UIView.animate(
                        withDuration: 0.20,
                        delay: 0,
                        options: [.curveEaseInOut, .beginFromCurrentState, .allowUserInteraction],
                        animations: { self.alpha = 0 },
                        completion: { _ in completion() }
                    )
                }
            )
        }
    }
}

#if DEBUG
@MainActor
private final class TodayTransitionAutomation {
    static let shared = TodayTransitionAutomation()
    var didRun = false
    var didRunReverse = false
}

/// Debug-only regression probe used by the simulator transition test. A gap
/// larger than one refresh interval means work on the main run loop skipped a
/// frame; this keeps the performance claim measurable rather than subjective.
@MainActor
private final class TodayTransitionFrameProbe: NSObject {
    static let shared = TodayTransitionFrameProbe()

    private var displayLink: CADisplayLink?
    private var lastTimestamp: CFTimeInterval?
    private var intervals: [CFTimeInterval] = []
    private var name = "todayTransition"

    func start(name: String = "todayTransition") {
        self.name = name
        displayLink?.invalidate()
        intervals.removeAll(keepingCapacity: true)
        lastTimestamp = nil
        let link = CADisplayLink(target: self, selector: #selector(tick(_:)))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 60, preferred: 60)
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
        let milliseconds = intervals.map { $0 * 1_000 }
        let maximum = milliseconds.max() ?? 0
        let average = milliseconds.isEmpty ? 0 : milliseconds.reduce(0, +) / Double(milliseconds.count)
        let missed = milliseconds.filter { $0 > 20 }.count
        UserDefaults.standard.set(milliseconds.count, forKey: "debug.\(name).frameCount")
        UserDefaults.standard.set(average, forKey: "debug.\(name).averageMilliseconds")
        UserDefaults.standard.set(maximum, forKey: "debug.\(name).maximumMilliseconds")
        UserDefaults.standard.set(missed, forKey: "debug.\(name).intervalsOver20Milliseconds")
        print(String(format: "[Klimax][\(name)] frames=%d average=%.2fms maximum=%.2fms intervalsOver20ms=%d", milliseconds.count, average, maximum, missed))
    }

    @objc private func tick(_ link: CADisplayLink) {
        if let lastTimestamp {
            intervals.append(link.timestamp - lastTimestamp)
        }
        lastTimestamp = link.timestamp
    }
}
#endif

private struct TodayWidgetGlyph: View {
    let icon: String
    var body: some View {
        Image(systemName: icon)
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(Paper.gold)
            .frame(width: 42, height: 42)
            .background(Paper.gold.opacity(0.13), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(Paper.gold.opacity(0.18), lineWidth: 1))
    }
}

private struct SaintChipGlyph: View {
    let icon: String?
    var body: some View {
        ZStack {
            Circle().fill(Paper.gold.opacity(0.14)).frame(width: 24, height: 24)
            if let icon, !icon.isEmpty, UIImage(named: icon) != nil {
                Image(icon).resizable().scaledToFill().frame(width: 24, height: 24).clipShape(Circle())
            } else {
                Image(systemName: "seal").font(.system(size: 11)).foregroundStyle(Paper.gold)
            }
        }
    }
}

private struct WidgetResizeHandle: View {
    let size: TodayWidgetSize
    var onResize: (TodayWidgetSize) -> Void
    @GestureState private var translation = CGSize.zero
    @State private var startingSize: TodayWidgetSize?

    private func target(_ delta: CGSize) -> TodayWidgetSize {
        switch startingSize ?? size {
        case .small:
            if delta.height > 65 { return .large }
            return delta.width > 35 ? .wide : .small
        case .wide:
            if delta.height > 35 { return .large }
            return delta.width < -35 ? .small : .wide
        case .large:
            if delta.width < -65 { return .small }
            return delta.height < -35 ? .wide : .large
        }
    }

    var body: some View {
        Image(systemName: "arrow.down.right.and.arrow.up.left")
            .font(.system(size: 12, weight: .bold)).foregroundStyle(Paper.ink)
            .frame(width: 36, height: 36)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .overlay(alignment: .topTrailing) {
                if translation != .zero {
                    Text(target(translation).title).font(.caption.weight(.semibold))
                        .padding(6).background(.regularMaterial, in: Capsule()).offset(y: -30)
                }
            }
            .offset(x: min(18, max(-18, translation.width * 0.15)), y: min(18, max(-18, translation.height * 0.15)))
            .highPriorityGesture(DragGesture(minimumDistance: 8, coordinateSpace: .global)
                .updating($translation) { value, state, _ in state = value.translation }
                .onChanged { value in
                    if startingSize == nil { startingSize = size }
                    let next = target(value.translation)
                    if next != size { onResize(next) }
                }
                .onEnded { value in
                    let next = target(value.translation)
                    if next != size { onResize(next) }
                    startingSize = nil
                })
            .onTapGesture {
                let sizes = TodayWidgetSize.allCases
                onResize(sizes[((sizes.firstIndex(of: size) ?? 0) + 1) % sizes.count])
            }
            .accessibilityLabel("Μέγεθος widget")
            .accessibilityValue(size.title)
            .accessibilityHint("Σύρε τη γωνία προς τα έξω ή προς τα μέσα")
            .accessibilityAdjustableAction { direction in
                let sizes = TodayWidgetSize.allCases
                let index = sizes.firstIndex(of: size) ?? 0
                let next = direction == .increment ? min(index + 1, sizes.count - 1) : max(index - 1, 0)
                onResize(sizes[next])
            }
            .contextMenu {
                ForEach(TodayWidgetSize.allCases) { option in
                    Button(option.title, systemImage: option.icon) { onResize(option) }
                }
            }
    }
}

private struct ReorderModifier: ViewModifier {
    let editing: Bool
    let widget: TodayWidgetConfig
    @Binding var widgets: [TodayWidgetConfig]
    @Binding var dragging: TodayWidgetID?
    @Binding var boardFrame: CGRect
    private var frames: [TodayWidgetID: CGRect] {
        let visible = widgets.filter(\.isVisible)
        let rects = TodayWidgetBoardLayout(sizes: visible.map(\.size), spacing: 20).frames(width: boardFrame.width)
        return Dictionary(uniqueKeysWithValues: zip(visible, rects).map {
            ($0.0.id, $0.1.offsetBy(dx: boardFrame.minX, dy: boardFrame.minY))
        })
    }
    var onReorder: ([TodayWidgetConfig]) -> Void
    @GestureState private var translation = CGSize.zero
    @State private var origin: CGPoint?
    @State private var lastTarget: TodayWidgetID?

    private var offset: CGSize {
        guard let origin, translation != .zero, let frame = frames[widget.id] else { return .zero }
        return CGSize(width: origin.x + translation.width - frame.minX,
                      height: origin.y + translation.height - frame.minY)
    }

    func body(content: Content) -> some View {
        if editing {
            content
                .contentShape(Rectangle())
                .offset(offset)
                .zIndex(offset == .zero ? 0 : 10)
                .gesture(DragGesture(minimumDistance: 12, coordinateSpace: .global)
                    .updating($translation) { value, state, _ in state = value.translation }
                    .onChanged { value in
                        if origin == nil { origin = frames[widget.id]?.origin; dragging = widget.id }
                        guard let target = frames.first(where: { $0.key != widget.id && $0.value.insetBy(dx: 12, dy: 12).contains(value.location) })?.key,
                              target != lastTarget,
                              let from = widgets.firstIndex(where: { $0.id == widget.id }),
                              let to = widgets.firstIndex(where: { $0.id == target }) else { return }
                        lastTarget = target
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                            let moved = widgets.remove(at: from)
                            widgets.insert(moved, at: to)
                        }
                        UISelectionFeedbackGenerator().selectionChanged()
                        onReorder(widgets)
                    }
                    .onEnded { _ in
                        origin = nil
                        lastTarget = nil
                        dragging = nil
                        onReorder(widgets)
                    })
        } else {
            content
        }
    }
}

private struct WidgetFramePreference: PreferenceKey {
    static var defaultValue: CGRect { .zero }
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

private struct WidgetDropDelegate: DropDelegate {
    let item: TodayWidgetID
    @Binding var widgets: [TodayWidgetConfig]
    @Binding var dragging: TodayWidgetID?
    var onReorder: ([TodayWidgetConfig]) -> Void

    func dropEntered(info: DropInfo) {
        guard let dragging, dragging != item,
              let from = widgets.firstIndex(where: { $0.id == dragging }),
              let to = widgets.firstIndex(where: { $0.id == item }) else { return }
        withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
            let moved = widgets.remove(at: from)
            widgets.insert(moved, at: to)
        }
        onReorder(widgets)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        dragging = nil
        onReorder(widgets)
        return true
    }
}

private extension View {
    // The real thing: native iOS 26 Liquid Glass, the same material as the floating
    // tab bar. A gentle tint keeps sacred text legible over it. Falls back to a plain
    // parchment surface on iOS 18.
    @ViewBuilder
    func todayLiquidGlass(
        cornerRadius: CGFloat,
        highlighted: Bool = false,
        tint: Color? = nil,
        interactive: Bool = false
    ) -> some View {
        if cornerRadius <= 0 {
            self
        } else {
            let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            let base = tint ?? Paper.card
            if !interactive {
                // Static surfaces keep widget text crisp and avoid a separate
                // live glass compositor for every tile while scrolling.
                self
                    .background {
                        shape.fill(Paper.card)
                            .overlay(shape.fill(LinearGradient(
                                colors: [(tint ?? Paper.gold).opacity(tint == nil ? 0.025 : 0.10), .clear],
                                startPoint: .topLeading, endPoint: .bottomTrailing)))
                    }
                    .overlay(shape.stroke(Paper.hairline, lineWidth: 0.75))
            } else if #available(iOS 26.0, *) {
                if interactive {
                    self
                        .glassEffect(
                            .regular
                                .tint(base.opacity(highlighted ? 0.25 : 0.17))
                                .interactive(),
                            in: shape
                        )
                } else {
                    self
                        .glassEffect(
                            .regular.tint(base.opacity(highlighted ? 0.55 : 0.42)),
                            in: shape
                        )
                }
            } else {
                self
                    .background(shape.fill(base.opacity(highlighted ? 0.94 : 0.88)))
                    .overlay(shape.stroke(Paper.hairline.opacity(highlighted ? 0.8 : 0.6),
                                          lineWidth: highlighted ? 1 : 0.75))
                    .shadow(color: .black.opacity(highlighted ? 0.06 : 0.025),
                            radius: highlighted ? 10 : 4, x: 0, y: highlighted ? 5 : 2)
            }
        }
    }
}
