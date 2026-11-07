import SwiftUI
import UIKit

private struct PrayerInvitation: Identifiable {
    let id = UUID()
    let kind: PrayerInvitationKind
    let imageName: String
    let prayer: Prayer
    let categories: [PrayerCategory]
    let isPreview: Bool
}

/// Retain the former 94% sheet's resting top edge, but draw only one card.
/// Widening preserves the photo card's proportions and extends its bottom.
struct PrayerInvitationCardLayout {
    let frame: CGRect

    init(viewport: CGSize, safeAreaTop: CGFloat, safeAreaBottom: CGFloat, isLiquidGlass: Bool) {
        let sheetInset: CGFloat = isLiquidGlass ? 8 : 0
        let sheetWidth = min(viewport.width, 640)
        let width = sheetWidth - sheetInset * 2
        let sheetScale = width / sheetWidth
        let formerContentHeight = (viewport.height - safeAreaTop - safeAreaBottom) * 0.94
        let top = viewport.height - sheetInset - (formerContentHeight + safeAreaBottom) * sheetScale
        let formerCardWidth = min(sheetWidth - 24, 600) * sheetScale
        let formerCardHeight = max(240, formerContentHeight - 60) * sheetScale
        let height = min(formerCardHeight * width / formerCardWidth, viewport.height - top - 24)
        frame = CGRect(x: (viewport.width - width) / 2, y: top, width: width, height: height)
    }
}

/// App entry only, not tab switches, Control Centre, or returning from a sheet.
/// Snoozes are in-app reminders: while active, or on the next eligible opening.
struct PrayerEntryPresentation: ViewModifier {
    var isBlocked: Bool
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var invitation: PrayerInvitation?
    @State private var entryPending = true
    @State private var wake = 0
    private let schedule = PrayerInvitationSchedule()

    func body(content: Content) -> some View {
        content
            .fullScreenCover(item: $invitation, onDismiss: { wake += 1 }) { item in
                // A transparent modal has no native glass sheet behind our card.
                // Read safe areas before extending the canvas; otherwise the
                // top inset is lost and the card jumps upwards.
                GeometryReader { geometry in
                    let viewport = CGSize(width: geometry.size.width, height: geometry.size.height + geometry.safeAreaInsets.top + geometry.safeAreaInsets.bottom)
                    let layout = PrayerInvitationCardLayout(viewport: viewport, safeAreaTop: geometry.safeAreaInsets.top, safeAreaBottom: geometry.safeAreaInsets.bottom, isLiquidGlass: usesLiquidGlass)
                    ZStack(alignment: .top) {
                        Color.black.opacity(0.22)
                            .contentShape(Rectangle())
                            .onTapGesture(perform: close)
                            .accessibilityHidden(true)

                        PrayerInvitationView(invitation: item, close: close) { date in
                            schedule.snooze(item.kind, until: date, at: Date())
                            close()
                        }
                        .frame(width: layout.frame.width, height: layout.frame.height)
                        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 34, style: .continuous).strokeBorder(.white.opacity(0.2), lineWidth: 0.5))
                        .shadow(color: .black.opacity(0.24), radius: 22, y: 12)
                        .padding(.top, layout.frame.minY)
                    }
                    .frame(width: viewport.width, height: viewport.height)
                    .offset(y: -geometry.safeAreaInsets.top)
                }
                .presentationBackground(.clear)
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .background { entryPending = true }
            }
            .task(id: "\(scenePhase)-\(wake)") {
                guard scenePhase == .active, invitation == nil else { return }
                if entryPending {
                    entryPending = false
                    await presentIfEligible(allowFirst: true)
                }
                guard invitation == nil else { return }
                if let reminder = schedule.nextReminder(at: Date()) {
                    do {
                        try await Task.sleep(for: .seconds(max(0.5, reminder.timeIntervalSinceNow)))
                        try Task.checkCancellation()
                        await presentIfEligible(allowFirst: false)
                    } catch { /* Leaving the app cancels the wait; the date stays saved. */ }
                }
            }
    }

    private var usesLiquidGlass: Bool {
        if #available(iOS 26.0, *) { return true }
        return false
    }

    private func close() {
        withAnimation(.easeOut(duration: 0.25)) { invitation = nil }
        wake += 1
    }

    @MainActor private func presentIfEligible(allowFirst: Bool) async {
        // Let app entry/navigation settle. Never put an invitation over another
        // reader, permission prompt, video player, or editor.
        for _ in 0..<20 {
            do { try await Task.sleep(for: .milliseconds(500)) } catch { return }
            guard scenePhase == .active, !Task.isCancelled else { return }
            #if DEBUG
            let previewKind = ProcessInfo.processInfo.arguments
                .first(where: { $0.hasPrefix("--prayer-invitation=") })
                .flatMap { PrayerInvitationKind(rawValue: String($0.dropFirst("--prayer-invitation=".count))) }
            #else
            let previewKind: PrayerInvitationKind? = nil
            #endif
            guard let kind = previewKind ?? schedule.pending(at: Date(), allowFirstPresentation: allowFirst) else { return }
            guard !isBlocked, let root = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive })?
                .windows.first(where: \.isKeyWindow)?.rootViewController,
                root.presentedViewController == nil else { continue }
            guard let data = try? PrayerStore.loadBundled(),
                  let prayer = data.categories.flatMap(\.prayers).first(where: { $0.id == kind.prayerID }),
                  prayer.isReadable else { return }
            if previewKind == nil { schedule.markPresented(kind, at: Date()) }
            withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(response: 0.46, dampingFraction: 0.9)) {
                invitation = PrayerInvitation(kind: kind, imageName: kind.imageName(at: Date()), prayer: prayer, categories: data.categories, isPreview: previewKind != nil)
            }
            return
        }
    }
}

private struct PrayerInvitationView: View {
    let invitation: PrayerInvitation
    let close: () -> Void
    let snooze: (Date) -> Void
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @State private var isReading = false
    @State private var atEnd = false
    @State private var completed = false
    @State private var linkedPrayer: PrayerRoute?
    @State private var showCustomReminder = false
    @State private var reminderTime = Date().addingTimeInterval(45 * 60)
    @Namespace private var completionMotion

    private var motion: Animation { reduceMotion ? .easeOut(duration: 0.18) : .smooth(duration: 0.42) }
    private var readerColor: Color { colorScheme == .dark ? Color(red: 0.07, green: 0.085, blue: 0.10) : Color(red: 0.98, green: 0.975, blue: 0.955) }
    private var ink: Color { colorScheme == .dark ? .white.opacity(0.94) : Color(red: 0.15, green: 0.14, blue: 0.12) }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Image(invitation.imageName)
                    .resizable().scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .overlay {
                        LinearGradient(stops: [.init(color: .black.opacity(0.14), location: 0), .init(color: .clear, location: 0.35), .init(color: .black.opacity(0.12), location: 0.5), .init(color: .black.opacity(0.85), location: 1)], startPoint: .top, endPoint: .bottom)
                            .opacity(isReading ? 0 : 1)
                    }
                    .overlay {
                        // One stationary material, not a blur on every paragraph
                        // or a per-frame animated blur radius.
                        Rectangle().fill(.regularMaterial)
                            .overlay(readerColor.opacity(reduceTransparency ? 1 : 0.76))
                            .opacity(isReading ? 1 : 0)
                    }

                if isReading {
                    reader
                        .transition(reduceMotion ? .opacity : .asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .trailing).combined(with: .opacity)))
                } else {
                    cover
                        .transition(reduceMotion ? .opacity : .asymmetric(insertion: .move(edge: .leading).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
                }
            }
            .clipped()
        }
        .overlay(alignment: .topTrailing) {
            Button(action: close) {
                Image(systemName: "xmark").font(.system(size: 16, weight: .semibold))
                    .frame(width: 44, height: 44)
                    // Semantic ink lets Liquid Glass adapt to the actual
                    // backdrop instead of forcing white over bright photos.
                    .foregroundStyle(.primary)
                    .glassCircleFallback(shape: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Κλείσιμο")
            .accessibilityIdentifier("prayer.invitation.close")
            .padding(18)
        }
        .sensoryFeedback(.success, trigger: completed)
        .task(id: completed) {
            guard completed else { return }
            try? await Task.sleep(for: .milliseconds(850))
            guard !Task.isCancelled else { return }
            close()
        }
        .sheet(isPresented: Binding(get: { linkedPrayer != nil }, set: { if !$0 { linkedPrayer = nil } })) {
            if let route = linkedPrayer {
            NavigationStack {
                PrayerReadingView(route: route, categories: invitation.categories)
                    .navigationDestination(for: PrayerRoute.self) { PrayerReadingView(route: $0, categories: invitation.categories) }
                    .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Τέλος") { linkedPrayer = nil } } }
            }
            }
        }
        .sheet(isPresented: $showCustomReminder) {
            NavigationStack {
                VStack(spacing: 18) {
                    DatePicker("Ώρα υπενθύμισης", selection: $reminderTime, in: Date()...Date().addingTimeInterval(24 * 60 * 60), displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.compact)
                        .padding(20)
                        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 18))
                    Text("Θα εμφανιστεί μέσα στην εφαρμογή εκείνη την ώρα ή την επόμενη φορά που θα την ανοίξεις.")
                        .font(.subheadline).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Spacer(minLength: 0)
                }
                .padding(24)
                .navigationTitle("Υπενθύμιση")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Άκυρο") { showCustomReminder = false } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Ορισμός") { showCustomReminder = false; snooze(reminderTime) }
                            .disabled(reminderTime <= Date())
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }

    private var cover: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 72)
            Text(invitation.kind == .morning ? "ΣΤΟ ΞΕΚΙΝΗΜΑ ΤΗΣ ΜΕΡΑΣ" : "ΣΤΟ ΚΛΕΙΣΙΜΟ ΤΗΣ ΜΕΡΑΣ")
                .font(.system(size: 11, weight: .semibold)).tracking(2)
                .foregroundStyle(.white.opacity(0.8))
                .padding(.bottom, 16)
            Text(invitation.kind.coverTitle)
                .font(.custom("GFSDidot", size: 48, relativeTo: .largeTitle))
                .lineSpacing(1)
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text(invitation.kind.subtitle)
                .font(.system(.body, design: .serif))
                .foregroundStyle(.white.opacity(0.86))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 14)
            HStack(alignment: .center) {
                reminderMenu
                Spacer(minLength: 12)
                Button {
                    withAnimation(motion) { isReading = true }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 64, height: 64)
                        .glassCircleFallback(shape: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Έναρξη προσευχής")
                .accessibilityIdentifier("prayer.invitation.start")
            }
            .padding(.top, 30)
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 30)
    }

    private var reminderMenu: some View {
        Menu {
            ForEach([15, 30, 60], id: \.self) { minutes in
                Button("Σε \(minutes) λεπτά") { snooze(Date().addingTimeInterval(Double(minutes) * 60)) }
            }
            Button("Άλλο…") {
                reminderTime = Date().addingTimeInterval(45 * 60)
                showCustomReminder = true
            }
            Text("Υπενθύμιση μέσα στην εφαρμογή, όσο είναι ανοιχτή ή στην επόμενη είσοδο.")
        } label: {
            Label("Αργότερα", systemImage: "clock")
                .font(.system(.subheadline, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 17).frame(minHeight: 46)
                .glassCircleFallback(shape: Capsule())
        }
        .accessibilityLabel("Υπενθύμισέ μου αργότερα")
        .accessibilityIdentifier("prayer.invitation.remind")
    }

    private var reader: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    withAnimation(motion) { isReading = false; atEnd = false }
                } label: {
                    Image(systemName: "chevron.left").font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(ink).frame(width: 44, height: 44)
                        .glassCircleFallback(shape: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Πίσω στην εικόνα")
                Spacer()
            }
            .padding(18)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    Text(invitation.kind.title)
                        .font(.custom("GFSDidot", size: 32, relativeTo: .title))
                        .foregroundStyle(ink)
                        .padding(.bottom, 8)
                        .accessibilityAddTraits(.isHeader)
                    ForEach(Array(invitation.prayer.body.enumerated()), id: \.offset) { index, paragraph in
                        paragraphView(paragraph)
                        if let document = DeisisCatalog.document,
                           let insertion = DeisisPlacementEngine.insertion(anchors: invitation.prayer.anchors, document: document, bodyCount: invitation.prayer.body.count),
                           insertion.index == index + 1 {
                            DeisisSection(document: document, placement: insertion.placement)
                        }
                    }
                    // Keep this space stable so docking never changes content
                    // height, triggers a scroll loop, or covers the final line.
                    Color.clear.frame(height: 72)
                        .overlay {
                            if atEnd {
                                completionButton
                                    .matchedGeometryEffect(id: "complete", in: completionMotion)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)
                        .id("prayer-end")
                }
                .padding(.horizontal, 28)
                .padding(.top, 10).padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .onScrollGeometryChange(for: Bool.self) { geometry in
                geometry.contentSize.height > 0 && geometry.visibleRect.maxY >= geometry.contentSize.height - 24
            } action: { _, reachedEnd in
                withAnimation(motion) { atEnd = reachedEnd }
            }
            .overlay(alignment: .bottomTrailing) {
                if !atEnd {
                    completionButton
                        .matchedGeometryEffect(id: "complete", in: completionMotion)
                        .padding(.trailing, 22).padding(.bottom, 18)
                }
            }
        }
    }

    private var completionButton: some View {
        Button {
            guard !completed else { return }
            if !invitation.isPreview, !PrayerPracticeMemory.didPray(prayerID: invitation.prayer.id) {
                PrayerPracticeMemory.markPrayed(prayerID: invitation.prayer.id)
                StreakStore.shared.record(.prayer, itemID: invitation.prayer.id)
            }
            withAnimation(motion) { completed = true }
        } label: {
            Image(systemName: completed ? "checkmark.circle.fill" : "checkmark")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(completed ? Color.green : ink)
                .frame(width: 62, height: 62)
                .glassCircleFallback(shape: Circle())
        }
        .buttonStyle(.plain)
        .disabled(completed)
        .accessibilityLabel(completed ? "Η προσευχή ολοκληρώθηκε" : "Ολοκλήρωση προσευχής")
        .accessibilityIdentifier(atEnd ? "prayer.invitation.complete.end" : "prayer.invitation.complete.floating")
    }

    @ViewBuilder private func paragraphView(_ text: String) -> some View {
        if text.hasPrefix("@link:") {
            let parts = text.dropFirst(6).split(separator: "|", maxSplits: 1)
            if let targetID = parts.first,
               let category = invitation.categories.first(where: { $0.prayers.contains(where: { $0.id == targetID }) }),
               let target = category.prayers.first(where: { $0.id == targetID }) {
                Button { linkedPrayer = PrayerRoute(category: category, prayer: target) } label: {
                    HStack {
                        Text(parts.count > 1 ? String(parts[1]).interfaceGreek : target.titleGreek.interfaceGreek)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                    }
                    .font(.body).foregroundStyle(ink)
                    .padding(16).background(ink.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
            }
        } else if text.hasPrefix("@h:") || text.hasPrefix("@m:") || text.hasPrefix("@r:") {
            Text(String(text.dropFirst(3)))
                .font(.system(text.hasPrefix("@h:") ? .headline : .subheadline, design: .serif))
                .foregroundStyle(ink.opacity(0.74))
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, text.hasPrefix("@h:") ? 12 : 0)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            Text(text)
                .font(.custom("GentiumBookPlus-Regular", size: 22, relativeTo: .body))
                .lineSpacing(7)
                .foregroundStyle(ink)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
    }
}
