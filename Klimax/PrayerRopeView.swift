import SwiftUI
import UIKit

/// Dedicated, local prayer tool. The existing Prayer library owns navigation chrome.
struct PrayerRopeView: View {
    @Binding var focused: Bool
    @Environment(DiptychaStore.self) private var names
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var model = PrayerRopeStore()
    @State private var editing = false
    @State private var replaceSession = false
    @State private var busy = false
    @State private var displayCount = 0
    @State private var movement: CGFloat = 0
    @State private var motionID: UUID?
    @State private var fadesOpeningKnot = false
    @FocusState private var knotFocused: Bool

    private var curve: Animation? { reduceMotion ? nil : .timingCurve(0.22, 0.75, 0.22, 1, duration: 0.48) }
    private var needsReview: Bool { model.session?.needsReview(using: names.entries) ?? false }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    if let session = model.session, !editing {
                        sessionView(session, availableHeight: geometry.size.height, availableWidth: geometry.size.width)
                    } else {
                        setup
                    }
                    if let issue = model.storageIssue {
                        Text(issue).font(.footnote).foregroundStyle(Paper.inkSoft).padding()
                            .accessibilityLabel(issue)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
                .padding(.top, focused ? 8 : 82)
                .padding(.bottom, focused ? 20 : 100)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Paper.bg)
        }
        .confirmationDialog("Να αντικατασταθεί η αποθηκευμένη προσευχή με νέα;", isPresented: $replaceSession, titleVisibility: .visible) {
            Button("Έναρξη νέας προσευχής", role: .destructive) { start() }
            Button("Ακύρωση", role: .cancel) { }
        }
        .onAppear {
            displayCount = model.session?.count ?? 0
            // An interrupted movement was already persisted; don't replay its haptic.
            _ = model.consumeMilestone()
            focused = !editing && (model.session?.focused ?? false)
        }
        .onChange(of: model.draft) { _, _ in model.save() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { completeMovement(feedback: false); model.save() }
        }
        .onDisappear {
            completeMovement(feedback: false); model.save(); focused = false
        }
    }

    private var setup: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("ΜΙΑ ΗΣΥΧΗ ΣΤΙΓΜΗ").font(.system(size: 10, weight: .semibold)).tracking(1.5).foregroundStyle(Paper.gold)
                Text("Κομποσχοίνι").font(.custom("GFSDidot-Regular", size: 30))
                Text("Ένας κόμπος, μία ευχή.").foregroundStyle(Paper.inkMute)
            }
            if let session = model.session {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Η προσευχή σου έχει αποθηκευτεί · \(session.count) / \(session.draft.length)").font(.footnote)
                    Button("Συνέχεια") { resume() }.buttonStyle(.bordered)
                }.frame(maxWidth: .infinity, alignment: .leading).padding(16).background(Paper.card, in: RoundedRectangle(cornerRadius: 18))
            }
            VStack(alignment: .leading, spacing: 12) {
                sectionTitle("Για ποιον προσεύχομαι")
                ForEach(PrayerRopeIntention.allCases) { intention in
                    Button {
                        model.draft.intention = intention; model.draft.selectedIDs = []
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: model.draft.intention == intention ? "largecircle.fill.circle" : "circle")
                                .foregroundStyle(Paper.gold)
                            Text(intention.title).font(.system(size: 14))
                            Spacer()
                        }.padding(15).frame(minHeight: 50).background(Paper.card, in: RoundedRectangle(cornerRadius: 16))
                    }.buttonStyle(.plain).accessibilityValue(model.draft.intention == intention ? "Επιλεγμένο" : "")
                }
            }
            if let category = model.draft.intention.category { namesPicker(category) }
            VStack(alignment: .leading, spacing: 12) {
                sectionTitle("Κόμποι ανά κύκλο")
                Picker("Κόμποι ανά κύκλο", selection: $model.draft.length) {
                    ForEach(PrayerRopeDraft.lengths, id: \.self) { Text("\($0)").tag($0) }
                }.pickerStyle(.segmented)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Η ΕΥΧΗ").font(.caption2).foregroundStyle(Paper.inkMute)
                if let prayer = model.draft.prayer(using: names.entries) {
                    Text(prayer).font(.custom("GFSDidot-Regular", size: 23)).fixedSize(horizontal: false, vertical: true)
                } else if model.draft.selectedIDs.isEmpty {
                    Text("Επίλεξε ένα ή περισσότερα ονόματα για να εμφανιστεί η ευχή.")
                        .font(.footnote).foregroundStyle(Paper.inkSoft)
                } else {
                    Text("Επιβεβαίωσε μία φορά το γένος και την κλίση των επιλεγμένων ονομάτων. Μετά θα εμφανιστεί η ευχή και θα μπορείς να ξεκινήσεις.")
                        .font(.footnote).foregroundStyle(Paper.inkSoft)
                    if let document = DeisisCatalog.document {
                        ForEach(model.draft.selected(from: names.entries).filter { $0.prayerGrammar?.isValid != true }) { entry in
                            NavigationLink {
                                DiptychaView(document: document, initialEditingID: entry.id, opensPrayerGrammar: true)
                            } label: {
                                Label("Επιβεβαίωση για \(entry.name)", systemImage: "pencil")
                                    .font(.footnote).frame(minHeight: 44)
                            }.buttonStyle(.bordered)
                        }
                    }
                }
            }
            Button(model.session == nil ? "Έναρξη προσευχής" : "Έναρξη νέας προσευχής") {
                if model.session == nil { start() } else { replaceSession = true }
            }
            .buttonStyle(PrayerRopeStartButtonStyle())
            .disabled(model.draft.prayer(using: names.entries) == nil)
            Text("Τα ονόματα και η πρόοδος παραμένουν μόνο στη συσκευή σου.")
                .font(.footnote).foregroundStyle(Paper.inkMute)
        }.foregroundStyle(Paper.ink).padding(.top, 14)
    }

    private func namesPicker(_ category: DiptychaCategory) -> some View {
        let entries = names.entries(in: category)
        let all = !entries.isEmpty && entries.allSatisfy { model.draft.selectedIDs.contains($0.id) }
        return VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Ονόματα από τα Δίπτυχα")
            Button(all ? "Αποεπιλογή όλων" : "Επιλογή όλων") {
                model.draft.selectedIDs = all ? [] : entries.map(\.id)
            }.font(.footnote).disabled(entries.isEmpty)
            if entries.isEmpty { Text("Δεν υπάρχουν ονόματα σε αυτή την κατηγορία.").font(.footnote).foregroundStyle(Paper.inkMute) }
            ForEach(entries) { entry in
                let selected = model.draft.selectedIDs.contains(entry.id)
                Button {
                    if selected { model.draft.selectedIDs.removeAll { $0 == entry.id } }
                    else { model.draft.selectedIDs.append(entry.id) }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: selected ? "checkmark.circle.fill" : "circle").foregroundStyle(Paper.gold)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.name)
                            if entry.prayerGrammar?.isValid != true {
                                Text("Χρειάζεται επιβεβαίωση κλίσης").font(.caption).foregroundStyle(Paper.inkMute)
                            }
                        }
                        Spacer()
                    }.frame(minHeight: 44)
                }.buttonStyle(.plain).accessibilityValue(selected ? "Επιλεγμένο" : "")
            }
            if let document = DeisisCatalog.document {
                NavigationLink { DiptychaView(document: document) } label: {
                    Label("Άνοιγμα Διπτύχων", systemImage: "chevron.right").font(.footnote).frame(minHeight: 44)
                }
            }
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text).font(.custom("GFSDidot-Regular", size: 21))
    }

    private func sessionView(_ session: PrayerRopeSession, availableHeight: CGFloat, availableWidth: CGFloat) -> some View {
        VStack(spacing: 8) {
            HStack {
                if focused {
                    Button { withAnimation(curve) { focused = false; model.setFocused(false) } } label: {
                        Image(systemName: "chevron.left").frame(width: 44, height: 44)
                    }.accessibilityLabel("Επιστροφή στην κανονική προβολή")
                }
                Text(session.draft.intention.title.uppercased())
                    .font(.system(size: 10, weight: .semibold)).tracking(1).frame(maxWidth: .infinity)
                Button { edit() } label: { Image(systemName: "slider.horizontal.3").frame(width: 44, height: 44) }
                    .accessibilityLabel("Ρυθμίσεις της προσευχής").disabled(busy)
            }.buttonStyle(.plain).foregroundStyle(Paper.inkSoft)
            if session.draft.showsPrayer {
                ScrollView {
                    Text(session.prayer).font(.custom("GFSDidot-Regular", size: 22)).multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity)
                }.frame(height: prayerHeight(session.prayer, width: availableWidth - 40))
                    .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
            }
            Button(session.draft.showsPrayer ? "Απόκρυψη ευχής" : "Εμφάνιση ευχής") {
                withAnimation(curve) { model.togglePrayer() }
            }.font(.caption2).foregroundStyle(Paper.inkMute).frame(minHeight: 32)
            PrayerRopeStage(count: displayCount, movement: movement, openingFades: fadesOpeningKnot)
                .frame(height: max(300, availableHeight - (focused ? 230 : 330) - (session.draft.showsPrayer ? 35 : 0)))
                .overlay(alignment: .bottom) {
                    // The knot itself is the control. One ended gesture yields at most one advance.
                    Color.clear.frame(width: 150, height: 104).contentShape(Rectangle())
                        .offset(y: -100)
                        .gesture(DragGesture(minimumDistance: 0).onEnded { value in
                            let x = abs(value.translation.width), y = value.translation.height
                            if (x < 10 && abs(y) < 10) || (y > 28 && y > x * 1.2) { advance() }
                        })
                        .allowsHitTesting(!busy && !session.isComplete && !needsReview)
                        .accessibilityHidden(session.isComplete || needsReview)
                        .accessibilityElement().accessibilityLabel("Επόμενος κόμπος — πάτησε τον κάτω κόμπο ή σύρε απαλά προς τα κάτω")
                        .accessibilityAddTraits(.isButton)
                        .accessibilityAction { advance() }
                        .accessibilityAction(named: Text("Επόμενος κόμπος")) { advance() }
                        .focusable().focused($knotFocused).focusEffectDisabled()
                        .onKeyPress(.space) { advance(); return .handled }
                        .onKeyPress(.return) { advance(); return .handled }
                        .accessibilityValue("\(session.count) από \(session.draft.length)")
                }
                .padding(.horizontal, -20)
            Text("Πάτησε τον κάτω κόμπο ή σύρε προς τα κάτω").font(.system(size: 10)).foregroundStyle(Paper.inkMute)
            Text("\(session.count) / \(session.draft.length)").font(.system(size: 13).monospacedDigit()).foregroundStyle(Paper.inkSoft)
                .accessibilityLabel("\(session.count) από \(session.draft.length) κόμπους")
            if session.isComplete && !busy {
                Text("Ο κύκλος ολοκληρώθηκε.").font(.custom("GFSDidot-Regular", size: 20)).padding(.top, 10)
                HStack {
                    Button("Νέος κύκλος") {
                        if needsReview { edit() } else {
                            model.restart(using: names.entries); resetMovement(); withAnimation(curve) { focused = false }
                        }
                    }
                    Button("Ολοκλήρωση") { model.finish(); resetMovement(); focused = false }
                }.buttonStyle(.bordered)
            } else if needsReview {
                Text("Τα επιλεγμένα ονόματα άλλαξαν στα Δίπτυχα. Η αποθηκευμένη ευχή διατηρείται. Έλεγξε τα ονόματα πριν συνεχίσεις.")
                    .font(.footnote).multilineTextAlignment(.center).foregroundStyle(Paper.inkSoft)
                Button("Έλεγχος ονομάτων") { edit() }.buttonStyle(.bordered)
            }
            Button("Αποθήκευση και επιστροφή") { completeMovement(feedback: false); edit() }
                .font(.footnote).frame(minHeight: 44).foregroundStyle(Paper.inkSoft)
        }.foregroundStyle(Paper.ink)
    }

    private func prayerHeight(_ text: String, width: CGFloat) -> CGFloat {
        let font = UIFont(name: "GFSDidot-Regular", size: 22) ?? UIFont.preferredFont(forTextStyle: .title3)
        let bounds = (text as NSString).boundingRect(with: CGSize(width: max(160, width), height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: [.font: font], context: nil)
        return min(145, max(32, ceil(bounds.height) + 8))
    }

    private func start() {
        guard model.start(using: names.entries) else { return }
        editing = false; resetMovement(); focused = false
    }
    private func edit() {
        guard !busy else { return }
        model.edit(); editing = true; withAnimation(curve) { focused = false }
    }
    private func resume() {
        editing = false; resetMovement()
        withAnimation(curve) { focused = model.session?.focused ?? false }
    }
    private func advance() {
        guard !busy, !editing, scenePhase == .active, model.advance(using: names.entries) else { return }
        busy = true; let token = UUID(); motionID = token
        withAnimation(curve) { focused = true }
        let animation: Animation = reduceMotion ? .linear(duration: 0.07) : .timingCurve(0.24, 0.64, 0.22, 1, duration: 0.43)
        withAnimation(animation, completionCriteria: .logicallyComplete) {
            movement = 128; fadesOpeningKnot = displayCount == 0
        } completion: {
            guard motionID == token else { return }
            completeMovement(feedback: scenePhase == .active)
        }
    }
    private func completeMovement(feedback: Bool) {
        guard busy else { return }
        let milestone = model.consumeMilestone()
        resetMovement()
        guard feedback else { return }
        if milestone == .completion { UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.7) }
        else if milestone == .midpoint { UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.4) }
        else { UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.12) }
    }
    private func resetMovement() {
        var transaction = Transaction(); transaction.disablesAnimations = true
        withTransaction(transaction) {
            displayCount = model.session?.count ?? 0; movement = 0; fadesOpeningKnot = false
            busy = false; motionID = nil
        }
    }
}

private struct PrayerRopeStage: View {
    let count: Int
    let movement: CGFloat
    let openingFades: Bool
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        GeometryReader { geometry in
            let anchor = geometry.size.height - 152
            ZStack(alignment: .topLeading) {
                // One continuous cord. Knot PNGs contain only wool, without duplicated tails.
                Capsule().fill(LinearGradient(colors: [.black, Color(white: scheme == .dark ? 0.21 : 0.14), .black], startPoint: .leading, endPoint: .trailing))
                    .frame(width: 6, height: count == 0 ? 544 : 1050)
                    .position(x: geometry.size.width / 2, y: anchor - 500 + (count == 0 ? 272 : 525))
                ForEach(-3...3, id: \.self) { position in
                    if position <= count {
                        let variant = ((position - count) % 3 + 3) % 3
                        Image("PrayerRopeKnot").resizable().frame(width: 110, height: 146)
                            .scaleEffect(x: variant == 1 ? -1 : 1, y: 1)
                            .rotationEffect(.degrees(variant == 1 ? 2 : variant == 2 ? -2 : 0))
                            .brightness(scheme == .dark ? 0.05 : 0)
                            .shadow(color: .black.opacity(0.2), radius: 4, x: 3, y: 6)
                            .opacity(count == 0 && position == 0 && openingFades ? 0 : 1)
                            .position(x: geometry.size.width / 2, y: anchor + CGFloat(position) * 128)
                    }
                }
                if count == 0 {
                    Image("PrayerRopeCross").resizable().frame(width: 120, height: 120)
                        .brightness(scheme == .dark ? 0.05 : 0)
                        .shadow(color: .black.opacity(0.2), radius: 3, x: 2, y: 4)
                        .position(x: geometry.size.width / 2, y: anchor + 84)
                }
            }
            .offset(y: movement)
            .frame(width: geometry.size.width, height: geometry.size.height)
            .mask {
                LinearGradient(stops: [
                    .init(color: .clear, location: 0), .init(color: .black, location: 0.12),
                    .init(color: .black, location: count == 0 ? 0.97 : max(0.13, (anchor + 30) / geometry.size.height)),
                    .init(color: .clear, location: count == 0 ? 1 : max(0.14, (anchor + 85) / geometry.size.height))
                ], startPoint: .top, endPoint: .bottom)
            }
            .accessibilityHidden(true)
        }.clipped()
    }
}

/// Explicit colours prevent inherited paper ink from tinting a prominent label.
private struct PrayerRopeStartButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(isEnabled ? Color.white : Paper.inkSoft)
            .padding(.horizontal, 18).frame(minHeight: 44)
            .background(isEnabled ? Paper.gold : Paper.ink.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Paper.hairline, lineWidth: 0.5))
            .opacity(configuration.isPressed && isEnabled ? 0.85 : 1)
    }
}
