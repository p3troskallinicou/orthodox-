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
    @State private var newName = ""
    @State private var nameQuery = ""
    @State private var showsAllNames = false
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
                .padding(.bottom, 16)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if let session = model.session, !editing {
                    sessionFooter(session)
                        .padding(16)
                        .athosGlass(in: RoundedRectangle(cornerRadius: 26), interactive: false)
                        .padding(.horizontal, 16).padding(.vertical, 8)
                } else {
                    setupFooter
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color.clear)
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
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("ΜΙΑ ΗΣΥΧΗ ΣΤΙΓΜΗ").font(.system(size: 10, weight: .semibold)).tracking(1.5).foregroundStyle(Paper.gold)
                    Text("Ένας κόμπος, μία ευχή.").font(.system(size: 27, weight: .medium, design: .serif))
                    Text("Διάλεξε για ποιον θέλεις να προσευχηθείς.").font(.subheadline).foregroundStyle(Paper.inkSoft)
                }
                Spacer(minLength: 0)
                Image("PrayerRopeCross").resizable().scaledToFit().frame(width: 64, height: 78).accessibilityHidden(true)
            }
            if let session = model.session {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Η προσευχή σου έχει αποθηκευτεί · \(session.count) / \(session.draft.length)").font(.footnote)
                    Button("Συνέχεια") { resume() }.buttonStyle(.bordered).tint(Paper.gold)
                }.frame(maxWidth: .infinity, alignment: .leading).padding(16)
                    .athosGlass(in: RoundedRectangle(cornerRadius: 22), interactive: false)
            }
            VStack(alignment: .leading, spacing: 12) {
                sectionTitle("Για ποιον προσεύχομαι")
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(PrayerRopeIntention.allCases) { intention in
                        intentionButton(intention)
                    }
                }
                if let category = model.draft.intention.category { namesPicker(category) }
            }
            VStack(alignment: .leading, spacing: 12) {
                sectionTitle("Κόμποι ανά κύκλο")
                Picker("Κόμποι ανά κύκλο", selection: $model.draft.length) {
                    ForEach(PrayerRopeDraft.lengths, id: \.self) { Text("\($0)").tag($0) }
                }.pickerStyle(.segmented)
            }.padding(18).athosGlass(in: RoundedRectangle(cornerRadius: 24), interactive: false)
            VStack(alignment: .leading, spacing: 8) {
                Label("Η ευχή σου", systemImage: "text.quote").font(.caption.weight(.semibold)).foregroundStyle(Paper.gold)
                if let prayer = model.draft.prayer(using: names.entries) {
                    Text(prayer).font(.custom("GFSDidot-Regular", size: 23)).fixedSize(horizontal: false, vertical: true)
                } else if model.draft.selectedIDs.isEmpty {
                    Text("Επίλεξε ένα ή περισσότερα ονόματα για να εμφανιστεί η ευχή.")
                        .font(.footnote).foregroundStyle(Paper.inkSoft)
                } else {
                    Text("Συμπλήρωσε το γένος στο επιλεγμένο όνομα για να διαμορφωθεί η ευχή.")
                        .font(.footnote).foregroundStyle(Paper.inkSoft)
                }
            }.frame(maxWidth: .infinity, alignment: .leading).padding(20)
                .athosGlass(in: RoundedRectangle(cornerRadius: 24), interactive: false)
        }.foregroundStyle(Paper.ink).padding(.top, 14)
    }

    private var setupFooter: some View {
        VStack(spacing: 9) {
            Button(model.session == nil ? "Έναρξη προσευχής" : "Έναρξη νέας προσευχής") {
                if model.session == nil { start() } else { replaceSession = true }
            }
            .buttonStyle(PrayerRopeStartButtonStyle())
            .disabled(model.draft.prayer(using: names.entries) == nil)
            .accessibilityIdentifier("rope.start")
            Label("Μόνο στη συσκευή σου", systemImage: "lock")
                .font(.caption2).foregroundStyle(Paper.inkSoft)
        }.padding(14).athosGlass(in: RoundedRectangle(cornerRadius: 26), interactive: false)
            .padding(.horizontal, 16).padding(.vertical, 8)
    }

    private func intentionButton(_ intention: PrayerRopeIntention) -> some View {
        let selected = model.draft.intention == intention
        let icon: String = switch intention {
        case .myself: "person"
        case .living: "person.2"
        case .sick: "heart"
        case .departed: "cross"
        }
        return Button {
            guard !selected else { return }
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                model.draft.intention = intention; model.draft.selectedIDs = []
                newName = ""; nameQuery = ""; showsAllNames = false
            }
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: icon).font(.system(size: 20, weight: .medium))
                    Spacer()
                    Image(systemName: "checkmark.circle.fill").opacity(selected ? 1 : 0)
                }.foregroundStyle(Paper.gold)
                Text(intention.title).font(.system(size: 13, weight: selected ? .semibold : .medium))
                    .multilineTextAlignment(.leading).foregroundStyle(Paper.ink)
            }.frame(maxWidth: .infinity, minHeight: 65, alignment: .leading).padding(15)
                .athosGlass(in: RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Paper.gold.opacity(selected ? 0.6 : 0), lineWidth: 1))
        }.buttonStyle(.plain).accessibilityAddTraits(selected ? .isSelected : [])
            .accessibilityIdentifier("rope.intention.\(intention.rawValue)")
    }

    private func namesPicker(_ category: DiptychaCategory) -> some View {
        let entries = names.entries(in: category)
        let filtered = nameQuery.isEmpty ? entries : entries.filter { $0.name.localizedStandardContains(nameQuery) }
        let visible = showsAllNames || !nameQuery.isEmpty ? filtered : Array(filtered.prefix(5))
        let all = !entries.isEmpty && entries.allSatisfy { model.draft.selectedIDs.contains($0.id) }
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Ονόματα").font(.headline)
                Text("\(model.draft.selectedIDs.count) επιλεγμένα").font(.caption).foregroundStyle(Paper.inkSoft)
                Spacer()
                if !entries.isEmpty {
                    Button(all ? "Κανένα" : "Όλα") { model.draft.selectedIDs = all ? [] : entries.map(\.id) }
                        .font(.footnote.weight(.semibold)).tint(Paper.gold).frame(minHeight: 44)
                }
            }
            if entries.count > 5 {
                HStack {
                    Image(systemName: "magnifyingglass")
                    TextField("Βρες όνομα", text: $nameQuery).autocorrectionDisabled()
                }.font(.subheadline).padding(12).background(.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 14))
            }
            if entries.isEmpty {
                Text("Πρόσθεσε το πρώτο όνομα εδώ. Θα είναι διαθέσιμο και στα Δίπτυχα.")
                    .font(.footnote).foregroundStyle(Paper.inkSoft)
            }
            ForEach(visible) { entry in
                let selected = model.draft.selectedIDs.contains(entry.id)
                VStack(alignment: .leading, spacing: 8) {
                    Button {
                        if selected { model.draft.selectedIDs.removeAll { $0 == entry.id } }
                        else { model.draft.selectedIDs.append(entry.id) }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: selected ? "checkmark.circle.fill" : "circle").foregroundStyle(Paper.gold)
                            Text(entry.name).font(.subheadline)
                            Spacer()
                        }.frame(minHeight: 44)
                    }.buttonStyle(.plain).accessibilityValue(selected ? "Επιλεγμένο" : "")
                        .accessibilityIdentifier("rope.name.\(entry.id)")
                    if selected && entry.resolvedPrayerGrammar == nil {
                        Picker("Γένος για \(entry.name)", selection: Binding<PrayerNameGrammar.Gender?>(
                            get: { entry.prayerGender },
                            set: { gender in
                                guard let gender else { return }
                                let manual = entry.prayerGrammar?.gender == gender ? entry.prayerGrammar : nil
                                names.update(entry, name: entry.name, category: entry.category, note: entry.note,
                                             prayerGrammar: manual, prayerGender: gender)
                            }
                        )) {
                            Text("Επίλεξε").tag(nil as PrayerNameGrammar.Gender?)
                            Text("Άνδρας").tag(PrayerNameGrammar.Gender?.some(.masculine))
                            Text("Γυναίκα").tag(PrayerNameGrammar.Gender?.some(.feminine))
                        }.pickerStyle(.segmented)
                    }
                }
            }

            if filtered.count > 5 && nameQuery.isEmpty {
                Button(showsAllNames ? "Λιγότερα ονόματα" : "Όλα τα ονόματα (\(entries.count))") {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { showsAllNames.toggle() }
                }.font(.footnote).tint(Paper.gold).frame(minHeight: 44)
            }
            Divider().opacity(0.6)
            HStack(spacing: 10) {
                TextField("Πρόσθεσε όνομα", text: $newName).textInputAutocapitalization(.words)
                    .submitLabel(.done).onSubmit { addName(in: category) }
                    .accessibilityIdentifier("rope.newName")
                Button { addName(in: category) } label: {
                    Image(systemName: "plus").font(.system(size: 17, weight: .semibold))
                        .frame(width: 44, height: 44).foregroundStyle(Paper.gold).athosGlass(in: Circle())
                }.disabled(newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityLabel("Προσθήκη και επιλογή ονόματος").accessibilityIdentifier("rope.addName")
            }.font(.subheadline)
            Text("Συνδέεται με τα Δίπτυχα — χωρίς να φύγεις από εδώ.").font(.caption2).foregroundStyle(Paper.inkSoft)
        }.padding(18).athosGlass(in: RoundedRectangle(cornerRadius: 24), interactive: false)
    }

    private func addName(in category: DiptychaCategory) {
        let clean = String(newName.trimmingCharacters(in: .whitespacesAndNewlines).prefix(40))
        guard !clean.isEmpty else { return }
        // Select an existing exact name instead of silently creating duplicates.
        let existing = names.entries(in: category).first { $0.name.compare(clean, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }
        if let id = existing?.id ?? names.add(name: clean, category: category, note: nil) {
            if !model.draft.selectedIDs.contains(id) { model.draft.selectedIDs.append(id) }
            newName = ""; nameQuery = ""; showsAllNames = true
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
                    }.athosGlass(in: Circle()).accessibilityLabel("Επιστροφή στην κανονική προβολή")
                }
                Text(session.draft.intention.title.uppercased())
                    .font(.system(size: 10, weight: .semibold)).tracking(1).frame(maxWidth: .infinity)
                Button { edit() } label: { Image(systemName: "slider.horizontal.3").frame(width: 44, height: 44) }
                    .athosGlass(in: Circle()).accessibilityLabel("Ρυθμίσεις της προσευχής").disabled(busy)
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
            PrayerRopeStage(count: displayCount, length: session.draft.length, movement: movement)
                .frame(height: max(300, availableHeight - (focused ? 230 : 330) - (session.draft.showsPrayer ? 35 : 0)))
                .overlay(alignment: .bottom) {
                    // The knot itself is the control. One ended gesture yields at most one advance.
                    Color.clear.frame(width: 150, height: 104).contentShape(Rectangle())
                        .offset(y: -100)
                        .gesture(DragGesture(minimumDistance: 0).onEnded { value in
                            let x = abs(value.translation.width), y = value.translation.height
                            if (x < 10 && abs(y) < 10) || (y > 28 && y > x * 1.2) { advance() }
                        })
                        .allowsHitTesting(!busy && !needsReview)
                        .accessibilityHidden(needsReview)
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

        }.foregroundStyle(Paper.ink)
    }

    private func sessionFooter(_ session: PrayerRopeSession) -> some View {
        VStack(spacing: 8) {
            Text("Πάτησε τον κάτω κόμπο ή σύρε προς τα κάτω").font(.system(size: 10)).foregroundStyle(Paper.inkMute)
            Text("\(session.count) / \(session.draft.length)").font(.system(size: 13).monospacedDigit()).foregroundStyle(Paper.inkSoft)
                .accessibilityLabel("\(session.count) από \(session.draft.length) κόμπους")
            if needsReview {
                Text("Τα επιλεγμένα ονόματα άλλαξαν στα Δίπτυχα. Η αποθηκευμένη ευχή διατηρείται. Έλεγξε τα ονόματα πριν συνεχίσεις.")
                    .font(.footnote).multilineTextAlignment(.center).foregroundStyle(Paper.inkSoft)
                Button("Έλεγχος ονομάτων") { edit() }.buttonStyle(.bordered)
            }
            Button("Αποθήκευση και επιστροφή") { completeMovement(feedback: false); edit() }
                .font(.footnote).frame(minHeight: 44).foregroundStyle(Paper.inkSoft)
            Button("Ολοκλήρωση προσευχής") {
                completeMovement(feedback: false)
                model.finish(); resetMovement(); focused = false
            }.font(.footnote).frame(minHeight: 44)
        }
        .foregroundStyle(Paper.ink)
        .fixedSize(horizontal: false, vertical: true)
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
            movement = 128
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
            displayCount = model.session?.count ?? 0; movement = 0
            busy = false; motionID = nil
        }
    }
}

private struct PrayerRopeStage: View {
    let count: Int
    let length: Int
    let movement: CGFloat
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        GeometryReader { geometry in
            let anchor = geometry.size.height - 152
            ZStack(alignment: .topLeading) {
                // One continuous cord. Knot PNGs contain only wool, without duplicated tails.
                Capsule().fill(LinearGradient(colors: [.black, Color(white: scheme == .dark ? 0.21 : 0.14), .black], startPoint: .leading, endPoint: .trailing))
                    .frame(width: 6, height: 1050)
                    .position(x: geometry.size.width / 2, y: anchor + 25)
                ForEach(-3...3, id: \.self) { position in
                    if (count - position) % length == 0 {
                        Image("PrayerRopeCross").resizable().frame(width: 120, height: 120)
                            .brightness(scheme == .dark ? 0.05 : 0)
                            .shadow(color: .black.opacity(0.2), radius: 3, x: 2, y: 4)
                            .position(x: geometry.size.width / 2, y: anchor + CGFloat(position) * 128)
                    } else {
                        let variant = ((count - position) % length + length) % length % 3
                        Image("PrayerRopeKnot").resizable().frame(width: 110, height: 146)
                            .scaleEffect(x: variant == 1 ? -1 : 1, y: 1)
                            .rotationEffect(.degrees(variant == 1 ? 2 : variant == 2 ? -2 : 0))
                            .brightness(scheme == .dark ? 0.05 : 0)
                            .shadow(color: .black.opacity(0.2), radius: 4, x: 3, y: 6)
                            .position(x: geometry.size.width / 2, y: anchor + CGFloat(position) * 128)
                    }
                }
            }
            .offset(y: movement)
            .frame(width: geometry.size.width, height: geometry.size.height)
            .mask {
                LinearGradient(stops: [
                    .init(color: .clear, location: 0), .init(color: .black, location: 0.12),
                    .init(color: .black, location: max(0.13, (anchor + 30) / geometry.size.height)),
                    .init(color: .clear, location: max(0.14, (anchor + 85) / geometry.size.height))
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
            .padding(.horizontal, 18).frame(maxWidth: .infinity, minHeight: 48)
            .background(isEnabled ? Paper.gold : Paper.ink.opacity(0.08), in: Capsule())
            .overlay(Capsule().stroke(Paper.hairline, lineWidth: 0.5))
            .opacity(configuration.isPressed && isEnabled ? 0.85 : 1)
    }
}
