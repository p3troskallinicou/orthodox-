//
//  LadderView.swift  ·  Klimax
//
//  Η παλιά «Κλῖμαξ» έγινε Βιβλική Πορεία: μια διαδραστική διαδρομή
//  μαθημάτων πάνω στην Αγία Γραφή. Το όνομα του view μένει προσωρινά ίδιο
//  ώστε τα παλιά navigation routes να συνεχίσουν να λειτουργούν.
//

import SwiftUI

struct LadderView: View {
    var topInset: CGFloat = 0

    @ObservedObject private var lessonProgress = LessonProgressStore.shared
    @ObservedObject private var playerProgress = PlayerProgressStore.shared
    @State private var showingUnitNavigator = false

    private let units = ScriptureCourse.units

    private var allLessons: [ScripturePathLesson] { units.flatMap(\.lessons) }

    private var completedCount: Int {
        allLessons.filter { lessonProgress.isCompleted($0.content.id) }.count
    }

    private var nextLesson: ScripturePathLesson? {
        allLessons.first { !lessonProgress.isCompleted($0.content.id) } ?? allLessons.last
    }

    private var mascotMood: ScriptureMascotMood {
        if !allLessons.isEmpty, completedCount == allLessons.count { return .celebrating }
        if completedCount > 0, playerProgress.currentStreak == 0 { return .thinking }
        return .ready
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 28) {
                    courseHeader

                    ForEach(Array(units.enumerated()), id: \.element.id) { unitIndex, unit in
                        ScriptureUnitView(
                            unit: unit,
                            unitIndex: unitIndex,
                            stateForLesson: state(for:),
                            onShowUnits: { showingUnitNavigator = true }
                        )
                        .id(unit.id)
                    }

                    Text("Νέες ενότητες θα ανοίγουν σταδιακά καθώς η πορεία μεγαλώνει.")
                        .font(.system(size: 13, weight: .medium, design: .serif))
                        .foregroundStyle(Paper.inkMute)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 42)
                        .padding(.top, 4)

                    Spacer(minLength: 42)
                }
                .padding(.top, topInset + 18)
            }
            .background(Color.clear)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingUnitNavigator) {
                ScriptureUnitNavigator(units: units) { unitID in
                    showingUnitNavigator = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
                        withAnimation(.easeInOut(duration: 0.45)) {
                            proxy.scrollTo(unitID, anchor: .top)
                        }
                    }
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(Paper.bg)
            }
        }
        .onAppear {
            NodeMemoryStore.shared.register(ScriptureCourse.memoryNodes)
            syncScriptureWidget()
        }
        .onChange(of: completedCount) { _, _ in
            syncScriptureWidget()
        }
    }

    private var courseHeader: some View {
        VStack(spacing: 18) {
            HStack(spacing: 0) {
                courseStat(icon: "flame.fill", value: "\(playerProgress.currentStreak)", label: "σειρά", color: Color(red: 0.90, green: 0.46, blue: 0.18))
                Rectangle().fill(Paper.hairline).frame(width: 1, height: 28)
                courseStat(icon: "checkmark.seal.fill", value: "\(completedCount)", label: "μαθήματα", color: Gild.gold)
                Rectangle().fill(Paper.hairline).frame(width: 1, height: 28)
                courseStat(icon: "sparkles", value: "\(playerProgress.totalXP)", label: "XP", color: Color(red: 0.24, green: 0.55, blue: 0.70))
            }
            .padding(.vertical, 12)
            .background(Paper.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Gild.gold.opacity(0.14), lineWidth: 0.75)
            }
            .shadow(color: Color.black.opacity(0.045), radius: 14, y: 5)

            VStack(alignment: .leading, spacing: 6) {
                Text("ΜΑΘΕ ΤΗΝ ΑΓΙΑ ΓΡΑΦΗ")
                    .font(.system(size: 11, weight: .black))
                    .tracking(2.6)
                    .foregroundStyle(Paper.gold)
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Βιβλική Πορεία")
                            .font(.system(size: 35, weight: .semibold, design: .serif))
                            .foregroundStyle(Paper.ink)
                        Text("Μικρά μαθήματα, ερωτήσεις και επαναλήψεις — από τη Γένεση έως το Ευαγγέλιο.")
                            .font(.system(size: 16, design: .serif))
                            .foregroundStyle(Paper.inkMute)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)

                    Image(mascotMood.assetName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 102, height: 116)
                        .accessibilityLabel(mascotMood == .celebrating ? "Η μασκότ πανηγυρίζει" : "Η μασκότ της Βιβλικής Πορείας")
                }

                HStack(spacing: 9) {
                    ProgressBar(fraction: Double(completedCount) / Double(max(allLessons.count, 1)))
                        .frame(height: 7)
                    Text("\(completedCount)/\(allLessons.count)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(Paper.inkMute)
                }
                .padding(.top, 8)

                NavigationLink {
                    ScriptureAchievementsView(totalLessonCount: allLessons.count)
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Gild.gold.opacity(0.10))
                            Circle()
                                .stroke(Gild.gold.opacity(0.20), lineWidth: 0.75)
                            Image(systemName: "trophy.fill")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Gild.gold)
                        }
                        .frame(width: 38, height: 38)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("ΕΠΙΤΕΥΓΜΑΤΑ")
                                .font(.system(size: 10, weight: .bold))
                                .tracking(1.35)
                                .foregroundStyle(Paper.gold)
                            Text("Δες τα ορόσημα της πορείας σου")
                                .font(.system(size: 13, weight: .medium, design: .serif))
                                .foregroundStyle(Paper.inkSoft)
                        }

                        Spacer(minLength: 0)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Paper.inkMute)
                    }
                    .padding(.horizontal, 13)
                    .padding(.vertical, 10)
                    .background(Paper.card, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .stroke(Gild.gold.opacity(0.14), lineWidth: 0.75)
                    }
                }
                .buttonStyle(CalmCardStyle())
                .padding(.top, 7)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 20)
    }

    private func syncScriptureWidget() {
        guard let lesson = nextLesson else { return }
        let unitTitle = units.first(where: { unit in
            unit.lessons.contains(where: { $0.id == lesson.id })
        })?.title ?? "Βιβλική Πορεία"
        let isComplete = !allLessons.isEmpty && completedCount == allLessons.count
        WidgetSharedStore.updateScriptureJourney(
            ScriptureJourneyWidgetInfo(
                lessonTitle: lesson.content.title,
                unitTitle: unitTitle,
                completedLessons: completedCount,
                totalLessons: allLessons.count,
                currentStep: 0,
                totalSteps: lesson.content.exercises.count,
                streak: playerProgress.currentStreak,
                mood: mascotMood,
                message: isComplete ? "Ολοκλήρωσες τη διαθέσιμη πορεία!" : "Συνέχισε από εκεί που έμεινες."
            )
        )
    }

    private func courseStat(icon: String, value: String, label: String, color: Color) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(Paper.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(label)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(Paper.inkMute)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func state(for lesson: ScripturePathLesson) -> ScripturePathState {
        if lessonProgress.isCompleted(lesson.content.id) { return .completed }
        guard let index = allLessons.firstIndex(where: { $0.id == lesson.id }) else { return .locked }
        if index == 0 { return .current }
        return lessonProgress.isCompleted(allLessons[index - 1].content.id) ? .current : .locked
    }
}

// MARK: - Achievements

/// The records and award definitions are intentionally local to this screen.
/// They provide a complete interface now, while making the final catalogue and
/// unlocking rules straightforward to replace when the product list is ready.
private struct ScriptureAchievementsView: View {
    let totalLessonCount: Int

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var progress = PlayerProgressStore.shared
    @State private var selectedAward: ScriptureAchievement?

    private let grid = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    private var records: [ScripturePersonalRecord] {
        let bestAccuracy = progress.save.lessonRecords.values.map(\.bestAccuracy).max() ?? 0
        return [
            .init(
                id: "best-streak",
                eyebrow: "ΣΥΝΕΠΕΙΑ",
                value: "\(progress.bestStreak)",
                title: "Μεγαλύτερη σειρά",
                detail: progress.bestStreak == 1 ? "1 συνεχόμενη ημέρα" : "\(progress.bestStreak) συνεχόμενες ημέρες",
                symbol: "flame.fill",
                tint: Color(red: 0.72, green: 0.30, blue: 0.20)
            ),
            .init(
                id: "lessons",
                eyebrow: "ΜΕΛΕΤΗ",
                value: "\(progress.completedLessonCount)",
                title: "Μαθήματα",
                detail: "από \(totalLessonCount) διαθέσιμα",
                symbol: "book.closed.fill",
                tint: Color(red: 0.25, green: 0.45, blue: 0.58)
            ),
            .init(
                id: "accuracy",
                eyebrow: "ΑΚΡΙΒΕΙΑ",
                value: bestAccuracy > 0 ? "\(Int((bestAccuracy * 100).rounded()))%" : "—",
                title: "Καλύτερη επίδοση",
                detail: bestAccuracy > 0 ? "σε μία άσκηση" : "Μετά το πρώτο μάθημα",
                symbol: "scope",
                tint: Color(red: 0.40, green: 0.48, blue: 0.31)
            )
        ]
    }

    private var awards: [ScriptureAchievement] {
        let records = progress.save.lessonRecords
        let highAccuracyCount = records.values.filter { $0.bestAccuracy >= 0.90 }.count
        let masteredCount = records.values.filter { $0.masteryState == .mastered }.count
        let gospelCount = records.filter { key, value in
            key.hasPrefix("bible-gospel-") && value.timesCompleted > 0
        }.count

        return [
            .init(id: "first-step", title: "Πρώτο Βήμα", subtitle: "Ολοκλήρωσε το πρώτο μάθημα", current: progress.completedLessonCount, target: 1, symbol: "figure.walk", tint: Color(red: 0.43, green: 0.53, blue: 0.40)),
            .init(id: "pentateuch", title: "Στην Πεντάτευχο", subtitle: "Ολοκλήρωσε τρία βιβλικά μαθήματα", current: progress.completedLessonCount, target: 3, symbol: "text.book.closed.fill", tint: Color(red: 0.30, green: 0.49, blue: 0.62)),
            .init(id: "steady", title: "Σταθερός Μαθητής", subtitle: "Μελέτησε για επτά συνεχόμενες ημέρες", current: progress.bestStreak, target: 7, symbol: "flame.fill", tint: Color(red: 0.67, green: 0.31, blue: 0.21)),
            .init(id: "listener", title: "Προσεκτικός Ακροατής", subtitle: "Πέτυχε 90% σε τρία μαθήματα", current: highAccuracyCount, target: 3, symbol: "ear.fill", tint: Color(red: 0.48, green: 0.37, blue: 0.60)),
            .init(id: "return", title: "Επιστροφή στο Κείμενο", subtitle: "Μελέτησε ξανά πέντε μαθήματα", current: max(0, progress.lessonPracticeCount - progress.completedLessonCount), target: 5, symbol: "arrow.counterclockwise", tint: Color(red: 0.64, green: 0.45, blue: 0.24)),
            .init(id: "memory", title: "Μνήμη Λόγου", subtitle: "Φθάσε σε κατοχή τριών μαθημάτων", current: masteredCount, target: 3, symbol: "brain.head.profile", tint: Color(red: 0.31, green: 0.52, blue: 0.49)),
            .init(id: "gospel", title: "Οδοιπόρος του Ευαγγελίου", subtitle: "Ολοκλήρωσε την πρώτη ευαγγελική ενότητα", current: gospelCount, target: 3, symbol: "cross.case.fill", tint: Gild.goldBright),
            .init(id: "path", title: "Όλη η Πορεία", subtitle: "Ολοκλήρωσε όλα τα διαθέσιμα μαθήματα", current: progress.completedLessonCount, target: max(totalLessonCount, 1), symbol: "map.fill", tint: Color(red: 0.29, green: 0.38, blue: 0.55))
        ]
    }

    private var unlockedCount: Int { awards.filter(\.isUnlocked).count }

    var body: some View {
        VStack(spacing: 0) {
            navigationHeader

            ScrollView {
                VStack(alignment: .leading, spacing: 30) {
                    overview
                    personalRecords
                    awardsGrid
                }
                .padding(.bottom, 44)
            }
        }
        .background(Paper.bg.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .sheet(item: $selectedAward) { award in
            ScriptureAchievementDetail(achievement: award)
                .presentationDetents([.height(390)])
                .presentationDragIndicator(.visible)
                .presentationBackground(Paper.bg)
        }
    }

    private var navigationHeader: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Paper.ink)
                    .frame(width: 40, height: 40)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)

            Spacer()

            Text("Επιτεύγματα")
                .font(.system(size: 20, weight: .semibold, design: .serif))
                .foregroundStyle(Paper.ink)

            Spacer()

            Color.clear.frame(width: 40, height: 40)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Paper.bg.opacity(0.96))
        .overlay(alignment: .bottom) {
            Rectangle().fill(Paper.hairline).frame(height: 0.75)
        }
    }

    private var overview: some View {
        HStack(spacing: 18) {
            ZStack {
                Circle()
                    .stroke(Paper.hairline, lineWidth: 7)
                Circle()
                    .trim(from: 0, to: Double(unlockedCount) / Double(max(awards.count, 1)))
                    .stroke(Gild.gold, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 1) {
                    Text("\(unlockedCount)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(Paper.ink)
                    Text("από \(awards.count)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Paper.inkMute)
                }
            }
            .frame(width: 82, height: 82)

            VStack(alignment: .leading, spacing: 5) {
                Text("Η ΠΟΡΕΙΑ ΣΟΥ")
                    .font(.system(size: 10, weight: .black))
                    .tracking(1.8)
                    .foregroundStyle(Paper.gold)
                Text("Σημεία μελέτης")
                    .font(.system(size: 25, weight: .semibold, design: .serif))
                    .foregroundStyle(Paper.ink)
                Text("Μικρά ορόσημα που θυμίζουν τη συνέπεια και την πρόοδό σου στη Γραφή.")
                    .font(.system(size: 13, design: .serif))
                    .foregroundStyle(Paper.inkMute)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(18)
        .background(Paper.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Gild.gold.opacity(0.15), lineWidth: 0.75)
        }
        .shadow(color: Color.black.opacity(0.045), radius: 16, y: 6)
        .padding(.horizontal, 20)
        .padding(.top, 22)
    }

    private var personalRecords: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("Προσωπικά ρεκόρ", subtitle: "Οι καλύτερες στιγμές της μελέτης σου")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(records) { record in
                        ScriptureRecordCard(record: record)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private var awardsGrid: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("Διακρίσεις", subtitle: "Πάτησε μία διάκριση για περισσότερες πληροφορίες")

            LazyVGrid(columns: grid, spacing: 14) {
                ForEach(awards) { award in
                    Button {
                        selectedAward = award
                    } label: {
                        ScriptureAchievementCard(achievement: award)
                    }
                    .buttonStyle(CalmCardStyle())
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private func sectionTitle(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 25, weight: .semibold, design: .serif))
                .foregroundStyle(Paper.ink)
            Text(subtitle)
                .font(.system(size: 12, design: .serif))
                .foregroundStyle(Paper.inkMute)
        }
        .padding(.horizontal, 20)
    }
}

private struct ScripturePersonalRecord: Identifiable {
    let id: String
    let eyebrow: String
    let value: String
    let title: String
    let detail: String
    let symbol: String
    let tint: Color
}

private struct ScriptureAchievement: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let current: Int
    let target: Int
    let symbol: String
    let tint: Color

    var fraction: Double { Double(min(current, target)) / Double(max(target, 1)) }
    var isUnlocked: Bool { current >= target }
}

private struct ScriptureRecordCard: View {
    let record: ScripturePersonalRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(record.eyebrow)
                    .font(.system(size: 9, weight: .black))
                    .tracking(1.35)
                    .foregroundStyle(record.tint)
                Spacer()
                Image(systemName: record.symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(record.tint)
            }

            Spacer()

            Text(record.value)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(Paper.ink)
                .minimumScaleFactor(0.7)

            Text(record.title)
                .font(.system(size: 14, weight: .semibold, design: .serif))
                .foregroundStyle(Paper.ink)
                .lineLimit(1)
            Text(record.detail)
                .font(.system(size: 10, weight: .medium, design: .serif))
                .foregroundStyle(Paper.inkMute)
                .lineLimit(2)
                .padding(.top, 3)
        }
        .padding(15)
        .frame(width: 166, height: 168, alignment: .leading)
        .background(Paper.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(record.tint.opacity(0.17), lineWidth: 0.8)
        }
    }
}

private struct ScriptureAchievementCard: View {
    let achievement: ScriptureAchievement

    var body: some View {
        VStack(spacing: 12) {
            achievementMedallion

            VStack(spacing: 4) {
                Text(achievement.title)
                    .font(.system(size: 15, weight: .semibold, design: .serif))
                    .foregroundStyle(Paper.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                Text(achievement.isUnlocked ? "Ολοκληρώθηκε" : "\(min(achievement.current, achievement.target)) από \(achievement.target)")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(achievement.isUnlocked ? achievement.tint : Paper.inkMute)
            }

            ProgressBar(fraction: achievement.fraction, tint: achievement.isUnlocked ? achievement.tint : Paper.inkMute.opacity(0.45))
                .frame(height: 4)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, minHeight: 218)
        .background(Paper.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(achievement.isUnlocked ? achievement.tint.opacity(0.22) : Paper.hairline, lineWidth: 0.8)
        }
    }

    private var achievementMedallion: some View {
        ZStack {
            Circle()
                .fill(achievement.isUnlocked ? achievement.tint.opacity(0.13) : Paper.lockedFill)
            Circle()
                .stroke(achievement.isUnlocked ? achievement.tint.opacity(0.34) : Paper.lockedRing, lineWidth: 1)
            Circle()
                .inset(by: 7)
                .stroke(achievement.isUnlocked ? achievement.tint.opacity(0.16) : Paper.lockedRing.opacity(0.65), lineWidth: 0.75)

            Image(systemName: achievement.isUnlocked ? achievement.symbol : "lock.fill")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(achievement.isUnlocked ? achievement.tint : Paper.lockedIcon)

            if achievement.isUnlocked {
                ZStack {
                    Circle().fill(Paper.card)
                    OrthodoxCrossMark(color: achievement.tint)
                        .frame(width: 13, height: 16)
                        .scaleEffect(0.45)
                }
                .frame(width: 23, height: 23)
                .overlay(Circle().stroke(achievement.tint.opacity(0.28), lineWidth: 0.75))
                .offset(x: 29, y: 29)
            }
        }
        .frame(width: 84, height: 84)
    }
}

private struct ScriptureAchievementDetail: View {
    let achievement: ScriptureAchievement

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 18) {
            HStack {
                Spacer()
                Button("Κλείσιμο") { dismiss() }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Paper.gold)
            }

            ZStack {
                Circle()
                    .fill(achievement.tint.opacity(achievement.isUnlocked ? 0.14 : 0.06))
                Circle()
                    .stroke(achievement.tint.opacity(achievement.isUnlocked ? 0.34 : 0.13), lineWidth: 1)
                Image(systemName: achievement.isUnlocked ? achievement.symbol : "lock.fill")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(achievement.isUnlocked ? achievement.tint : Paper.lockedIcon)
            }
            .frame(width: 92, height: 92)

            VStack(spacing: 7) {
                Text(achievement.title)
                    .font(.system(size: 25, weight: .semibold, design: .serif))
                    .foregroundStyle(Paper.ink)
                    .multilineTextAlignment(.center)
                Text(achievement.subtitle)
                    .font(.system(size: 15, design: .serif))
                    .foregroundStyle(Paper.inkMute)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 7) {
                HStack {
                    Text(achievement.isUnlocked ? "Ολοκληρώθηκε" : "Πρόοδος")
                    Spacer()
                    Text("\(min(achievement.current, achievement.target))/\(achievement.target)")
                }
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(achievement.isUnlocked ? achievement.tint : Paper.inkMute)

                ProgressBar(fraction: achievement.fraction, tint: achievement.tint)
                    .frame(height: 6)
            }
            .padding(.top, 4)
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

// MARK: - Unit and path

private enum ScripturePathState { case completed, current, locked }

private struct ScriptureCourseUnit: Identifiable {
    let id: String
    let number: Int
    let corpus: String
    let title: String
    let subtitle: String
    let tint: Color
    let deepTint: Color
    let lessons: [ScripturePathLesson]
}

private struct ScripturePathLesson: Identifiable {
    let id: String
    let icon: String
    let content: LessonContent
}

private struct ScriptureUnitView: View {
    let unit: ScriptureCourseUnit
    let unitIndex: Int
    let stateForLesson: (ScripturePathLesson) -> ScripturePathState
    let onShowUnits: () -> Void

    private let rowHeight: CGFloat = 126

    var body: some View {
        VStack(spacing: 18) {
            unitBanner.padding(.horizontal, 20)

            GeometryReader { proxy in
                let points = unit.lessons.indices.map { index in
                    CGPoint(
                        x: proxy.size.width / 2 + horizontalOffset(for: index),
                        y: CGFloat(index) * rowHeight + 42
                    )
                }

                ZStack(alignment: .topLeading) {
                    pathLine(points: points)

                    ForEach(Array(unit.lessons.enumerated()), id: \.element.id) { index, lesson in
                        ScriptureLessonNode(
                            lesson: lesson,
                            state: stateForLesson(lesson),
                            tint: unit.tint,
                            deepTint: unit.deepTint
                        )
                        .position(
                            x: points[index].x,
                            y: CGFloat(index) * rowHeight + 59
                        )
                    }
                }
            }
            .frame(height: CGFloat(unit.lessons.count) * rowHeight)
        }
    }

    private var unitBanner: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                Text("ΕΝΟΤΗΤΑ \(unit.number) · \(unit.corpus.uppercased())")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.8)
                    .foregroundStyle(Gild.gold.opacity(0.88))
                Text(unit.title)
                    .font(.system(size: 22, weight: .semibold, design: .serif))
                    .foregroundStyle(Color.white.opacity(0.96))
                Text(unit.subtitle)
                    .font(.system(size: 12, weight: .medium, design: .serif))
                    .foregroundStyle(Color.white.opacity(0.65))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Button(action: onShowUnits) {
                Image(systemName: "list.bullet")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.88))
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 0.75)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Όλες οι ενότητες")
        }
        .padding(.horizontal, 19)
        .padding(.vertical, 17)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [unit.deepTint, unit.deepTint.opacity(0.82)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Gild.gold.opacity(0.18), lineWidth: 0.75)
        }
        .shadow(color: unit.deepTint.opacity(0.22), radius: 18, y: 8)
    }

    private func horizontalOffset(for index: Int) -> CGFloat {
        let pattern: [CGFloat] = [-54, 22, 62, 6]
        let base = pattern[index % pattern.count]
        return unitIndex.isMultiple(of: 2) ? base : -base
    }

    private func pathLine(points: [CGPoint]) -> some View {
        Path { path in
            guard let first = points.first else { return }
            path.move(to: first)
            for index in 1..<points.count {
                let previous = points[index - 1]
                let current = points[index]
                let middleY = (previous.y + current.y) / 2
                path.addCurve(
                    to: current,
                    control1: CGPoint(x: previous.x, y: middleY),
                    control2: CGPoint(x: current.x, y: middleY)
                )
            }
        }
        .stroke(unit.tint.opacity(0.18), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [2, 8]))
    }
}

private struct ScriptureUnitNavigator: View {
    let units: [ScriptureCourseUnit]
    let onSelect: (String) -> Void

    @ObservedObject private var progress = LessonProgressStore.shared

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 5) {
                Text("ΕΝΟΤΗΤΕΣ")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(2.4)
                    .foregroundStyle(Paper.gold)
                Text("Βιβλική Πορεία")
                    .font(.system(size: 25, weight: .semibold, design: .serif))
                    .foregroundStyle(Paper.ink)
            }
            .padding(.top, 22)
            .padding(.bottom, 16)

            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(units) { unit in
                        Button {
                            onSelect(unit.id)
                        } label: {
                            HStack(spacing: 14) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                                        .fill(unit.deepTint)
                                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                                        .stroke(unit.tint.opacity(0.42), lineWidth: 0.75)
                                    Text("\(unit.number)")
                                        .font(.system(size: 18, weight: .semibold, design: .serif))
                                        .foregroundStyle(Color.white.opacity(0.92))
                                }
                                .frame(width: 46, height: 46)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(unit.title)
                                        .font(.system(size: 17, weight: .semibold, design: .serif))
                                        .foregroundStyle(Paper.ink)
                                        .lineLimit(1)
                                    Text(unit.corpus)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(Paper.inkMute)
                                }

                                Spacer(minLength: 0)

                                VStack(alignment: .trailing, spacing: 4) {
                                    Text("\(completedLessons(in: unit))/\(unit.lessons.count)")
                                        .font(.system(size: 11, weight: .bold, design: .rounded))
                                        .foregroundStyle(completedLessons(in: unit) > 0 ? unit.tint : Paper.inkMute)
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(Paper.inkMute.opacity(0.65))
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(Paper.card, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 17, style: .continuous)
                                    .stroke(Paper.hairline, lineWidth: 0.75)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 30)
            }
        }
    }

    private func completedLessons(in unit: ScriptureCourseUnit) -> Int {
        unit.lessons.filter { progress.isCompleted($0.content.id) }.count
    }
}

private struct ScriptureLessonNode: View {
    let lesson: ScripturePathLesson
    let state: ScripturePathState
    let tint: Color
    let deepTint: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        Group {
            if state == .locked {
                nodeContent
            } else {
                NavigationLink(value: lesson.content) { nodeContent }
                    .buttonStyle(.plain)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(lesson.content.title)
        .accessibilityValue(accessibilityState)
    }

    private var nodeContent: some View {
        VStack(spacing: 9) {
            ZStack {
                if state == .current {
                    Circle()
                        .stroke(tint.opacity(0.18), lineWidth: 8)
                        .frame(width: 88, height: 88)
                        .scaleEffect(pulse ? 1.025 : 0.975)
                }

                Circle()
                    .fill(nodeColor)
                    .frame(width: 72, height: 72)
                    .shadow(color: shadowColor, radius: state == .locked ? 3 : 10, y: state == .locked ? 2 : 5)

                Circle()
                    .stroke(nodeBorderColor, lineWidth: state == .current ? 2 : 1)
                    .frame(width: 72, height: 72)

                Circle()
                    .stroke(Color.white.opacity(state == .locked ? 0.08 : 0.14), lineWidth: 0.75)
                    .frame(width: 62, height: 62)

                if state == .current {
                    OrthodoxCrossMark(color: nodeIconColor)
                        .frame(width: 30, height: 36)
                } else {
                    Image(systemName: nodeIcon)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(nodeIconColor)
                }
            }
            .frame(width: 96, height: 82)

            if state == .current {
                VStack(spacing: 2) {
                    Text("ΕΠΟΜΕΝΟ ΜΑΘΗΜΑ")
                        .font(.system(size: 8, weight: .bold))
                        .tracking(1.25)
                        .foregroundStyle(tint)
                    Text(lesson.content.title)
                        .font(.system(size: 13, weight: .semibold, design: .serif))
                        .foregroundStyle(Paper.ink)
                        .lineLimit(1)
                }
            }
        }
        .frame(width: 174, height: 118, alignment: .top)
        .onAppear {
            guard state == .current, !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) { pulse = true }
        }
    }

    private var nodeIcon: String {
        switch state {
        case .completed: "checkmark"
        case .current: "cross"
        case .locked: "lock.fill"
        }
    }

    private var nodeColor: Color {
        switch state {
        case .completed: deepTint.opacity(0.88)
        case .current: tint
        case .locked: Paper.card
        }
    }

    private var nodeBorderColor: Color {
        switch state {
        case .completed: tint.opacity(0.58)
        case .current: Color.white.opacity(0.36)
        case .locked: Paper.lockedRing
        }
    }

    private var nodeIconColor: Color {
        switch state {
        case .completed: Color.white.opacity(0.88)
        case .current: Color.white.opacity(0.94)
        case .locked: Paper.lockedIcon
        }
    }

    private var shadowColor: Color {
        state == .locked ? Color.black.opacity(0.04) : deepTint.opacity(0.34)
    }

    private var accessibilityState: String {
        switch state {
        case .completed: "Ολοκληρωμένο μάθημα"
        case .current: "Διαθέσιμο μάθημα"
        case .locked: "Κλειδωμένο μάθημα"
        }
    }
}

/// Three-bar Orthodox cross: a short title bar, the principal beam and the
/// slanted footrest. Drawn natively so it remains crisp at every Dynamic Type
/// and display scale without introducing another glossy image asset.
private struct OrthodoxCrossMark: View {
    let color: Color

    var body: some View {
        ZStack {
            Capsule()
                .fill(color)
                .frame(width: 4, height: 34)

            Capsule()
                .fill(color)
                .frame(width: 14, height: 3)
                .offset(y: -11)

            Capsule()
                .fill(color)
                .frame(width: 26, height: 4)
                .offset(y: -4)

            Capsule()
                .fill(color)
                .frame(width: 18, height: 3)
                .rotationEffect(.degrees(-14))
                .offset(y: 10)
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Initial Bible curriculum

private enum ScriptureCourse {
    private static let genesisPackage: BibleChapterPackage? = {
        guard let url = Bundle.main.url(forResource: "genesis-1", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(BibleChapterPackage.self, from: data)
    }()

    static let memoryNodes: [BibleMemoryNode] = genesisPackage?.nodes ?? []

    static let units: [ScriptureCourseUnit] = genesisUnits + [
        .init(
            id: "exodus-freedom", number: 2, corpus: "Παλαιὰ Διαθήκη",
            title: "Ἔξοδος", subtitle: "Ἀπὸ τὴ δουλεία στὴν ἐλευθερία",
            tint: Color(red: 0.68, green: 0.49, blue: 0.30), deepTint: Color(red: 0.29, green: 0.19, blue: 0.10),
            lessons: [
                pathLesson(
                    id: "bible-exodus-01", index: 7, title: "Ἡ φλεγομένη βάτος", icon: "flame.fill", source: "Ἔξοδος 3, 1–14",
                    passage: "Ἐγώ εἰμι ὁ ὤν.",
                    gloss: "Ο Θεός αποκαλύπτεται στον Μωυσή και τον καλεί να υπηρετήσει την απελευθέρωση του λαού.",
                    question: "Ποιος καλείται μέσα από τη φλεγόμενη βάτο;",
                    options: ["Ὁ Ἀβραάμ", "Ὁ Μωυσῆς", "Ὁ Δαβίδ", "Ὁ Ἠλίας"], answer: 1,
                    statement: "Η βάτος καίγεται αλλά δεν κατακαίεται.", truth: true,
                    explanation: "Το παράδοξο σημείο τραβά την προσοχή του Μωυσή και εισάγει τη θεία κλήση."
                ),
                pathLesson(
                    id: "bible-exodus-02", index: 8, title: "Τὸ Πάσχα", icon: "door.left.hand.open", source: "Ἔξοδος 12, 1–14",
                    passage: "Καὶ ἔσται ἡ ἡμέρα ὑμῖν αὕτη μνημόσυνον.",
                    gloss: "Το Πάσχα γίνεται μνήμη απελευθέρωσης και πέρασμα από τη δουλεία σε νέα ζωή.",
                    question: "Τι σημαίνει κυρίως το Πάσχα στην Έξοδο;",
                    options: ["Λήθη του παρελθόντος", "Πέρασμα και απελευθέρωση", "Αλλαγή εποχής", "Αρχή πολέμου"], answer: 1,
                    statement: "Η ημέρα του Πάσχα δίνεται ως μνημόσυνο για τις επόμενες γενιές.", truth: true,
                    explanation: "Η βιβλική μνήμη δεν είναι απλή ανάμνηση· κάνει την απελευθέρωση σημείο ταυτότητας και ελπίδας."
                ),
                pathLesson(
                    id: "bible-exodus-03", index: 9, title: "Ἡ Διαθήκη τοῦ Σινᾶ", icon: "text.book.closed.fill", source: "Ἔξοδος 20, 1–17",
                    passage: "Ἐγώ εἰμι Κύριος ὁ Θεός σου, ὅστις ἐξήγαγόν σε ἐκ γῆς Αἰγύπτου.",
                    gloss: "Οι εντολές δίνονται μετά την απελευθέρωση και περιγράφουν πώς ζει ένας ελεύθερος λαός σε σχέση με τον Θεό και τον πλησίον.",
                    question: "Τι προηγείται στην αφήγηση πριν από τις εντολές;",
                    options: ["Η απελευθέρωση από την Αίγυπτο", "Η βασιλεία του Δαβίδ", "Η Βαβυλώνια αιχμαλωσία", "Η οικοδόμηση του Ναού"], answer: 0,
                    statement: "Οι εντολές εμφανίζονται αποκομμένες από την απελευθέρωση.", truth: false,
                    explanation: "Η εισαγωγή θυμίζει πρώτα τη σωτηρία· η υπεύθυνη ζωή ακολουθεί ως απάντηση."
                )
            ]
        ),
        .init(
            id: "gospel-arrival", number: 3, corpus: "Καινὴ Διαθήκη",
            title: "Εὐαγγέλια", subtitle: "Ὁ Λόγος ἔγινε σάρκα",
            tint: Color(red: 0.55, green: 0.45, blue: 0.61), deepTint: Color(red: 0.24, green: 0.17, blue: 0.29),
            lessons: [
                pathLesson(
                    id: "bible-gospel-01", index: 10, title: "Γένοιτό μοι", icon: "hands.sparkles.fill", source: "Κατὰ Λουκᾶν 1, 26–38",
                    passage: "Ἰδοὺ ἡ δούλη Κυρίου· γένοιτό μοι κατὰ τὸ ῥῆμά σου.",
                    gloss: "Η Θεοτόκος απαντά ελεύθερα στην κλήση του Θεού με εμπιστοσύνη και διαθεσιμότητα.",
                    question: "Ποια είναι η απάντηση της Μαρίας στον Ευαγγελισμό;",
                    options: ["Φυγή", "Γένοιτό μοι", "Αμφισβήτηση χωρίς απάντηση", "Σιωπηλή άρνηση"], answer: 1,
                    statement: "Η απάντηση της Θεοτόκου παρουσιάζεται ως ελεύθερη συγκατάθεση.", truth: true,
                    explanation: "Το «γένοιτό μοι» είναι η προσωπική και ελεύθερη αποδοχή του θελήματος του Θεού."
                ),
                pathLesson(
                    id: "bible-gospel-02", index: 11, title: "Ὁ Λόγος ἐσκήνωσεν", icon: "star.circle.fill", source: "Κατὰ Ἰωάννην 1, 1–14",
                    passage: "Καὶ ὁ Λόγος σὰρξ ἐγένετο καὶ ἐσκήνωσεν ἐν ἡμῖν.",
                    gloss: "Ο αιώνιος Λόγος εισέρχεται πραγματικά στην ανθρώπινη ιστορία και κατοικεί ανάμεσά μας.",
                    question: "Τι δηλώνει ο Ιωάννης ότι έγινε ο Λόγος;",
                    options: ["Ἄγγελος", "Σάρξ", "Νόμος", "Σύμβολο"], answer: 1,
                    statement: "Ο ευαγγελιστής περιγράφει τον Λόγο ως μακρινό από την ανθρώπινη ζωή.", truth: false,
                    explanation: "Το «ἐσκήνωσεν ἐν ἡμῖν» εκφράζει εγγύτητα, πραγματική παρουσία και κοινωνία."
                ),
                pathLesson(
                    id: "bible-gospel-03", index: 12, title: "Μετανοεῖτε καὶ πιστεύετε", icon: "checkmark.seal.fill", source: "Κατὰ Μᾶρκον 1, 14–20",
                    passage: "Πεπλήρωται ὁ καιρὸς καὶ ἤγγικεν ἡ βασιλεία τοῦ Θεοῦ.",
                    gloss: "Η δημόσια δράση του Χριστού αρχίζει με κάλεσμα για αλλαγή νου, πίστη και μαθητεία.",
                    question: "Ποιο είναι το διπλό κάλεσμα στην αρχή του κατά Μάρκον;",
                    options: ["Μετανοείτε και πιστεύετε", "Κρύβεστε και περιμένετε", "Κρίνετε και απομακρύνεστε", "Ταξιδεύετε και πολεμάτε"], answer: 0,
                    statement: "Η μαθητεία αρχίζει με ανταπόκριση στο κάλεσμα του Χριστού.", truth: true,
                    explanation: "Μετά το κήρυγμα της Βασιλείας ακολουθεί αμέσως η κλήση των πρώτων μαθητών."
                )
            ]
        )
    ]

    private static var genesisUnits: [ScriptureCourseUnit] {
        guard let package = genesisPackage else { return [] }

        let palette = (
            tint: Color(red: 0.46, green: 0.58, blue: 0.43),
            deep: Color(red: 0.16, green: 0.25, blue: 0.17)
        )
        let icons = ["light.max", "person.crop.circle.fill"]
        var lessonIndex = 1
        var lessons: [ScripturePathLesson] = []

        for (unitIndex, unit) in package.units.enumerated() {
            for lesson in unit.lessons.sorted(by: { $0.order < $1.order }) {
                let source = "\(package.chapterTitle) · \(package.sourceText)"
                let content = LessonContent(
                    id: lesson.id,
                    index: lessonIndex,
                    title: lesson.title,
                    teaching: LessonTeaching(
                        title: lesson.title,
                        body: unit.liturgical,
                        sources: [source]
                    ),
                    exercises: lesson.cards,
                    closing: Closing(
                        type: "scripture",
                        text: package.chapterTitle,
                        gloss: "",
                        source: package.sourceText
                    ),
                    xp: 0
                )
                lessons.append(
                    ScripturePathLesson(
                        id: lesson.id,
                        icon: icons[unitIndex % icons.count],
                        content: content
                    )
                )
                lessonIndex += 1
            }
        }

        lessons.append(contentsOf: [
            pathLesson(
                id: "bible-abraham-01", index: lessonIndex, title: "Ἔξελθε", icon: "figure.walk", source: "Γένεσις 12, 1–4",
                passage: "Ἔξελθε ἐκ τῆς γῆς σου… εἰς τὴν γῆν, ἣν ἄν σοι δείξω.",
                gloss: "Η πορεία του Αβραάμ αρχίζει με εμπιστοσύνη πριν ακόμη γνωρίζει ολόκληρο τον δρόμο.",
                question: "Τι ζητά πρώτα ο Θεός από τον Αβραάμ;",
                options: ["Να οικοδομήσει πόλη", "Να εξέλθει από τη γη του", "Να γίνει βασιλιάς", "Να επιστρέψει στην Αίγυπτο"], answer: 1,
                statement: "Ο Αβραάμ γνωρίζει εξαρχής κάθε λεπτομέρεια της πορείας.", truth: false,
                explanation: "Η κλήση προηγείται της πλήρους γνώσης· γι’ αυτό η απάντηση του Αβραάμ είναι πράξη πίστεως."
            ),
            pathLesson(
                id: "bible-abraham-02", index: lessonIndex + 1, title: "Ἡ ἐπαγγελία", icon: "star.fill", source: "Γένεσις 15, 1–6",
                passage: "Ἀνάβλεψον δὴ εἰς τὸν οὐρανὸν καὶ ἀρίθμησον τοὺς ἀστέρας.",
                gloss: "Οι αστέρες γίνονται σημείο μιας υπόσχεσης που υπερβαίνει όσα ο Αβραάμ μπορεί να δει τώρα.",
                question: "Ποιο σημείο χρησιμοποιείται για την επαγγελία των απογόνων;",
                options: ["Οι λίθοι", "Οι αστέρες", "Τα κύματα", "Τα δέντρα"], answer: 1,
                statement: "Η πίστη του Αβραάμ συνδέεται με την εμπιστοσύνη στην επαγγελία.", truth: true,
                explanation: "Η περικοπή υπογραμμίζει ότι ο Αβραάμ εμπιστεύεται τον Θεό παρά την ανθρώπινη αδυναμία."
            ),
            pathLesson(
                id: "bible-abraham-03", index: lessonIndex + 2, title: "Πίστις δοκιμαζομένη", icon: "checkmark.seal.fill", source: "Γένεσις 22, 1–14",
                passage: "Νῦν ἔγνων ὅτι φοβῇ σὺ τὸν Θεόν.",
                gloss: "Η δύσκολη αφήγηση κορυφώνεται όχι στον θάνατο, αλλά στην επέμβαση του Θεού και στην ανανέωση της εμπιστοσύνης.",
                question: "Πώς ολοκληρώνεται η δοκιμασία στο όρος;",
                options: ["Με εγκατάλειψη", "Με θεϊκή επέμβαση", "Με πόλεμο", "Με επιστροφή στην Αίγυπτο"], answer: 1,
                statement: "Το κέντρο της περικοπής είναι ότι ο Θεός προμηθεύει τη λύση.", truth: true,
                explanation: "Το όνομα του τόπου συνδέεται με το «Κύριος εἶδεν» — ο Θεός βλέπει και προνοεί."
            )
        ])

        return [
            ScriptureCourseUnit(
                id: package.book,
                number: 1,
                corpus: "Παλαιὰ Διαθήκη",
                title: package.bookTitle,
                subtitle: "Ἀπὸ τὴ δημιουργία στὴν κλήση τοῦ Ἀβραάμ",
                tint: palette.tint,
                deepTint: palette.deep,
                lessons: lessons
            )
        ]
    }

    private static func pathLesson(
        id: String, index: Int, title: String, icon: String, source: String,
        passage: String, gloss: String, question: String, options: [String], answer: Int,
        statement: String, truth: Bool, explanation: String
    ) -> ScripturePathLesson {
        let content = LessonContent(
            id: id,
            index: index,
            title: title,
            teaching: LessonTeaching(title: title, body: gloss, sources: [source]),
            exercises: [
                .readingPassage(
                    id: "\(id)-passage", source: source, passage: passage, gloss: gloss,
                    question: question, options: options, answerIndex: answer, explanation: explanation
                ),
                .trueFalse(id: "\(id)-truth", statement: statement, answer: truth, explanation: explanation),
                .multipleChoice(
                    id: "\(id)-review",
                    prompt: "Ποια πρόταση συνοψίζει καλύτερα το μάθημα;",
                    options: [gloss, "Η περικοπή δεν συνδέεται με την υπόλοιπη βιβλική ιστορία.", "Το κείμενο ενδιαφέρεται μόνο για χρονολογίες."],
                    answerIndex: 0,
                    explanation: explanation
                )
            ],
            closing: Closing(type: "scripture", text: passage, gloss: gloss, source: source),
            xp: 20
        )
        return ScripturePathLesson(id: id, icon: icon, content: content)
    }
}
