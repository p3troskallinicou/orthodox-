//
//  RootView.swift
//  Klimax
//
//  The glass tab bar carries only the five top-level sections. Saved items and
//  streaks live inside You (Profile), not in the bar.
//
//  iOS 26: the native Liquid Glass tab bar minimizes into a compact glass
//  capsule when the user scrolls down, and restores on scroll up
//  (`tabBarMinimizeBehavior(.onScrollDown)`). This is the native behaviour —
//  we don't build a custom bar. It only engages when a tab's content actually
//  scrolls (ScrollView/List overlaid by the bar). On iOS < 26 there is no glass
//  bar, so the behaviour is simply skipped and nothing changes.
//

import SwiftUI

private enum KlimaxTab: Hashable {
    case today, athosTV, logos, prayer, profile
}

private enum WidgetRoute: String, Identifiable {
    case sundayLiturgy, didaches, dailyStories, scripture, fasting
    case feastCalendar, saints, streaks, nearby, bibleJourney

    var id: String { rawValue }
}

struct RootView: View {
    // Shared with VirtueLessonsView's cards (matchedTransitionSource) and
    // the LessonContent destination below (navigationTransition) so tapping
    // a lesson zooms into it instead of a plain push.
    @Namespace private var lessonZoom
    private let audio = HomilyPlayer.shared
    @State private var hasCurrentAudio = HomilyPlayer.shared.current != nil
    @State private var presentedHomily: Homily?
    @State private var presentedHomilyContext = ""
    @StateObject private var streakCelebrations = StreakCelebrationCenter.shared
    @StateObject private var notebookNotices = NotebookNoticeCenter.shared
    @State private var selectedTab: KlimaxTab = .today
    @State private var widgetRoute: WidgetRoute?

    #if DEBUG
    init() {
        // Start in the real Athos navigation stack for first-play regression QA.
        if ProcessInfo.processInfo.arguments.contains("--athos-navigation-check") {
            _selectedTab = State(initialValue: .athosTV)
        }
    }
    #endif

    var body: some View {
        base
            .fullScreenCover(item: $presentedHomily, onDismiss: {
                audio.fullScreenHomily = nil
            }) { ep in
                HomilyPlayerView(episode: ep, context: presentedHomilyContext)
            }
            .onReceive(audio.$current) { current in
                hasCurrentAudio = current != nil
            }
            .onReceive(audio.$fullScreenHomily) { homily in
                guard let homily else {
                    presentedHomily = nil
                    return
                }
                presentedHomilyContext = audio.contextTitle
                presentedHomily = homily
            }
            .overlay(alignment: .top) {
                if let celebration = streakCelebrations.celebration {
                    StreakCelebrationView(celebration: celebration) {
                        streakCelebrations.dismiss(celebration.id)
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    .zIndex(100)
                }
            }
            .animation(.spring(response: 0.34, dampingFraction: 0.86), value: streakCelebrations.celebration?.id)
            .alert(item: $notebookNotices.notice) { notice in
                Alert(
                    title: Text(notice.title),
                    message: Text("Μπορείς να τη βρεις στο Σημειωματάριο."),
                    dismissButton: .default(Text("Τέλος"))
                )
            }
            .onOpenURL(perform: openWidgetURL)
            .sheet(item: $widgetRoute) { route in
                NavigationStack {
                    widgetDestination(route)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Κλείσιμο") { widgetRoute = nil }
                            }
                        }
                }
            }
            .modifier(PrayerEntryPresentation(isBlocked: presentedHomily != nil || widgetRoute != nil || notebookNotices.notice != nil))
    }

    @ViewBuilder private var base: some View {
        // Playback must never choose a different TabView branch: doing so
        // destroys every NavigationStack on the first play (and on Stop).
        if #available(iOS 26.1, *) {
            tabView
                .tabBarMinimizeBehavior(.onScrollDown)
                .tabViewBottomAccessory(isEnabled: hasCurrentAudio) { HomilyMiniBar() }
        } else if #available(iOS 26.0, *) {
            tabView
                .tabBarMinimizeBehavior(.onScrollDown)
                .tabViewBottomAccessory {
                    if hasCurrentAudio { HomilyMiniBar() }
                }
        } else {
            tabView
                .safeAreaInset(edge: .bottom) {
                    if hasCurrentAudio { HomilyMiniBar(glassWrapped: true) }
                }
        }
    }

    private var tabView: some View {
        TabView(selection: $selectedTab) {
            // 1 · Today — the calm home
            NavigationStack {
                TodayView()
                    .navigationDestination(for: ChapterRoute.self) { ChapterReadingView(route: $0) }
            }
            .tabItem { Label("Today", systemImage: "sunrise.fill") }
            .tag(KlimaxTab.today)

            // 2 · Athos TV — bundled catalogue with foreground YouTube playback
            NavigationStack {
                AthosTVView()
            }
            .tabItem {
                Label {
                    Text("Athos TV")
                } icon: {
                    Image("AthosTVMark")
                }
            }
            .tag(KlimaxTab.athosTV)

            // 3 · Λόγος — Scripture, Saints, Gerontikon, and Bible learning
            NavigationStack {
                LogosLibraryView()
                    .navigationDestination(for: Book.self) { BookChaptersView(book: $0) }
                    .navigationDestination(for: ChapterRoute.self) { ChapterReadingView(route: $0) }
                    .navigationDestination(for: Virtue.self) { VirtueLessonsView(virtue: $0, zoom: lessonZoom) }
                    .navigationDestination(for: LessonContent.self) { lesson in
                        LessonPlayerView(lesson: lesson)
                            .navigationTransition(.zoom(sourceID: lesson.id, in: lessonZoom))
                            .toolbar(.hidden, for: .navigationBar)
                    }
                    .navigationDestination(for: Saint.self) { SaintTeachingsView(saint: $0) }
                    .navigationDestination(for: TeachingRoute.self) {
                        LessonView(teaching: $0.teaching, saint: $0.saint)
                    }
                    .navigationDestination(for: SaintRank.self) { SaintCategoryView(rank: $0) }
                    .navigationDestination(for: SaintEntry.self) { SaintDetailView(saint: $0) }
            }
            .tabItem { Label("Λόγος", systemImage: "book.closed.fill") }
            .tag(KlimaxTab.logos)

            // 4 · Προσευχή — Prayer
            NavigationStack {
                PrayerLibraryView()
            }
            .tabItem { Label("Prayer", systemImage: "flame.fill") }
            .tag(KlimaxTab.prayer)

            // 5 · You — Profile: saved progress, wallet, and active character
            NavigationStack {
                ProfileView()
                    .navigationDestination(for: Book.self) { BookChaptersView(book: $0) }
                    .navigationDestination(for: ChapterRoute.self) { ChapterReadingView(route: $0) }
            }
            .tabItem { Label("You", systemImage: "person.fill") }
            .tag(KlimaxTab.profile)
        }
        .tint(Gild.gold)
    }

    private func openWidgetURL(_ url: URL) {
        guard url.scheme == "klimax", url.host == "widget" else { return }
        let topic = url.pathComponents.dropFirst().first ?? ""
        switch topic {
        case "sundayLiturgy": selectedTab = .today; widgetRoute = .sundayLiturgy
        case "didaches": selectedTab = .logos; widgetRoute = .didaches
        case "dailyStories": selectedTab = .logos; widgetRoute = .dailyStories
        case "continueReading", "verse": selectedTab = .logos; widgetRoute = .scripture
        case "fasting": selectedTab = .today; widgetRoute = .fasting
        case "feastCalendar": selectedTab = .today; widgetRoute = .feastCalendar
        case "saints": selectedTab = .logos; widgetRoute = .saints
        case "streaks": selectedTab = .profile; widgetRoute = .streaks
        case "nearby": selectedTab = .today; widgetRoute = .nearby
        case "bibleJourney": selectedTab = .logos; widgetRoute = .bibleJourney
        case "iconostasis": selectedTab = .profile; widgetRoute = nil
        default: selectedTab = .today
        }
    }

    @ViewBuilder
    private func widgetDestination(_ route: WidgetRoute) -> some View {
        switch route {
        case .sundayLiturgy:
            DivineLiturgyView(date: Date())
        case .didaches:
            DidachesLibraryView()
        case .dailyStories:
            ShortStoriesSectionView(topInset: 12)
                .navigationTitle("Γεροντικό")
        case .scripture:
            ScriptureLibraryView()
        case .fasting:
            FastingCalendarView(date: Date())
        case .feastCalendar:
            WidgetFeastCalendarDestination()
        case .saints:
            SaintsCatalogView()
        case .streaks:
            StreakDashboardView(store: .shared)
        case .nearby:
            ChurchMapView()
        case .bibleJourney:
            LadderView()
        }
    }
}

private struct WidgetFeastCalendarDestination: View {
    @State private var service = OrthodoxFeastCalendarService()

    var body: some View {
        OrthodoxFeastCalendarView(service: service)
            .task { await service.loadCalendar() }
    }
}

private enum LogosSection: String, CaseIterable, Identifiable {
    case scripture
    case saints
    case sayings
    case gerontikon
    case ladder

    var id: String { rawValue }

    var title: String {
        switch self {
        case .scripture: "Αγία Γραφή"
        case .saints: "Άγιοι"
        case .sayings: "Λόγοι Αγίων"
        case .gerontikon: "Γεροντικόν"
        case .ladder: "Βιβλική Πορεία"
        }
    }

    var icon: String {
        switch self {
        case .scripture: "book.closed.fill"
        case .saints: "person.2.fill"
        case .sayings: "quote.opening"
        case .gerontikon: "text.quote"
        case .ladder: "map.fill"
        }
    }
}

private struct LogosLibraryView: View {
    @State private var selectedSection: LogosSection = .scripture
    @State private var headerCondensed = false
    @ObservedObject private var reader = ReaderPresenter.shared

    var body: some View {
        ZStack {
            AppAtmosphere().ignoresSafeArea()

            sectionContent
                .id(selectedSection)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea(.container, edges: .bottom)

            VStack {
                sectionMenu
                Spacer()
            }
            .zIndex(1)

            StoryReaderView(
                stories: reader.stories,
                startIndex: reader.startIndex,
                isOpen: reader.isOpen
            ) {
                reader.close()
            }
            .zIndex(2)
            .allowsHitTesting(reader.isOpen)
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 8)
                .onChanged { value in
                    let shouldCondense = value.translation.height < -6
                    let shouldExpand = value.translation.height > 18
                    guard shouldCondense || shouldExpand else { return }
                    let nextValue = shouldCondense
                    guard headerCondensed != nextValue else { return }
                    withAnimation(.smooth(duration: 0.28)) {
                        headerCondensed = nextValue
                    }
                }
        )
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(reader.isOpen ? .hidden : .automatic, for: .tabBar)
    }

    private var sectionMenu: some View {
        HStack(spacing: 14) {
            Menu {
                ForEach(LogosSection.allCases) { section in
                    Button {
                        withAnimation(.smooth(duration: 0.30)) {
                            selectedSection = section
                        }
                    } label: {
                        Label {
                            Text(section.title)
                        } icon: {
                            Image(systemName: selectedSection == section ? "checkmark" : section.icon)
                        }
                    }
                }
            } label: {
                HStack(spacing: 9) {
                    Text(selectedSection.title)
                        .font(.system(size: headerCondensed ? 21 : 25, weight: .bold, design: .serif))
                        .foregroundStyle(Paper.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Paper.inkMute)
                        .padding(.top, 3)
                }
                .padding(.leading, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Επιλογή ενότητας")
            .accessibilityValue(selectedSection.title)

            Spacer(minLength: 8)

            Image(systemName: selectedSection.icon)
                .font(.system(size: headerCondensed ? 14 : 16, weight: .semibold))
                .foregroundStyle(Paper.gold)
                .frame(width: headerCondensed ? 36 : 42, height: headerCondensed ? 36 : 42)
                .logosSectionGlass()
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 20)
        .frame(height: headerCondensed ? 58 : 76)
        .background { AppHeaderSurface(condensed: headerCondensed) }
        .animation(.smooth(duration: 0.28), value: headerCondensed)
    }

    @ViewBuilder
    private var sectionContent: some View {
        switch selectedSection {
        case .scripture:
            ScriptureLibraryView()
        case .saints:
            SaintsCatalogView()
        case .sayings:
            SaintSayingsView()
        case .gerontikon:
            ShortStoriesSectionView()
        case .ladder:
            LadderView(topInset: 82)
        }
    }
}

private struct LogosBlockRiseModifier: ViewModifier {
    let order: Int
    @State private var isSettled = false

    func body(content: Content) -> some View {
        content
            .opacity(isSettled ? 1 : 0)
            .offset(y: isSettled ? 0 : 24)
            .onAppear {
                guard !isSettled else { return }
                withAnimation(
                    .easeOut(duration: 0.30)
                        .delay(Double(min(order, 8)) * 0.055)
                ) {
                    isSettled = true
                }
            }
    }
}

extension View {
    func logosBlockRise(_ order: Int) -> some View {
        modifier(LogosBlockRiseModifier(order: order))
    }

    @ViewBuilder
    func logosSectionGlass() -> some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)

        if #available(iOS 26.0, *) {
            self.glassEffect(
                .regular,
                in: shape
            )
        } else {
            self
                .background(.thinMaterial, in: shape)
                .overlay(
                    shape.stroke(
                        Color.adaptive(.white.opacity(0.52), Color.white.opacity(0.10)),
                        lineWidth: 0.5
                    )
                    .allowsHitTesting(false)
                )
        }
    }
}
