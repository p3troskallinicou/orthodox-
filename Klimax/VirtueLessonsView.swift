//
//  VirtueLessonsView.swift
//  Klimax
//
//  Ὅ,τι βλέπεις ὅταν μπαίνεις σὲ μία βαθμίδα (π.χ. Ἀποταγή). Ξαναχτισμένο
//  γιὰ νὰ εἶναι συνέχεια τῆς σκάλας: ἴδια κεφαλίδα, καὶ τὰ μαθήματα ὡς
//  σκαλιὰ σὲ κάθετη ράγα, μὲ τὸ τρέχον νὰ «ἀναπνέει», τὰ κλειδωμένα σβηστά,
//  τὰ ὁλοκληρωμένα ἀναμμένα. Ἀκολουθεῖ light/dark ὅπως ὅλη ἡ ἐφαρμογή.
//
//  Ἡ πλοήγηση καὶ τὰ δεδομένα μένουν ἴδια: NavigationLink(value: lesson)
//  μὲ matchedTransitionSource, ὥστε τὸ zoom στὸν παίκτη μαθήματος νὰ δουλεύει.
//

import SwiftUI

struct VirtueLessonsView: View {
    let virtue: Virtue
    let zoom: Namespace.ID

    @ObservedObject private var progress = LessonProgressStore.shared

    private var sections: [LessonSection] { LessonContent.sections(forVirtue: virtue.id) }
    private var flatLessons: [LessonContent] { sections.flatMap(\.lessons) }
    private var doneCount: Int { flatLessons.filter { progress.isCompleted($0.id) }.count }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: KSpace.xl) {
                header

                if sections.isEmpty {
                    emptyState
                } else {
                    ForEach(sections) { section in
                        VStack(alignment: .leading, spacing: KSpace.sm) {
                            sectionHeader(section)
                            LazyVStack(spacing: 0) {
                                ForEach(Array(section.lessons.enumerated()), id: \.element.id) { i, lesson in
                                    let st = rowState(for: lesson)
                                    let first = i == 0
                                    let last  = i == section.lessons.count - 1
                                    if st == .locked {
                                        LessonRung(lesson: lesson, state: st, isFirst: first, isLast: last)
                                    } else {
                                        NavigationLink(value: lesson) {
                                            LessonRung(lesson: lesson, state: st, isFirst: first, isLast: last)
                                        }
                                        .buttonStyle(CalmCardStyle())
                                        .matchedTransitionSource(id: lesson.id, in: zoom)
                                    }
                                }
                            }
                        }
                    }
                }

                Spacer(minLength: KSpace.xl)
            }
            .padding(.top, KSpace.md)
            .padding(.bottom, KSpace.xl)
        }
        .background(Paper.bg.ignoresSafeArea())
    }

    // Κεφαλίδα, ἴδια γλώσσα μὲ τὴ σκάλα: eyebrow (ἡ βαθμίς), τίτλος, μιὰ
    // ἥσυχη γραμμή, καὶ λεπτὴ χρυσὴ πρόοδος.
    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(virtue.subtitle)
                .font(KType.label(12)).tracking(4)
                .foregroundStyle(Paper.gold)
            Text(virtue.title)
                .font(.system(size: 34, weight: .regular, design: .serif))
                .foregroundStyle(Paper.ink)
            Text("Ανέβα ένα σκαλί τη φορά.")
                .font(.system(size: 16, design: .serif))
                .foregroundStyle(Paper.inkMute)

            if !flatLessons.isEmpty {
                HStack(spacing: KSpace.sm) {
                    ProgressBar(fraction: Double(doneCount) / Double(max(flatLessons.count, 1)))
                        .frame(width: 120, height: 4)
                    Text("\(doneCount) από \(flatLessons.count)")
                        .font(KType.caption(12))
                        .foregroundStyle(Paper.inkMute)
                }
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, KSpace.gutter)
    }

    private func sectionHeader(_ section: LessonSection) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(section.title)
                .font(KType.label(12)).tracking(3)
                .foregroundStyle(Paper.gold)
            Text(section.subtitle)
                .font(.system(size: 15, design: .serif))
                .foregroundStyle(Paper.inkMute)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, KSpace.gutter)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "hourglass")
                .font(.system(size: 26))
                .foregroundStyle(Paper.gold.opacity(0.55))
            Text("Τα μαθήματα αυτής της βαθμίδας έρχονται σύντομα.")
                .font(.system(size: 16, design: .serif))
                .foregroundStyle(Paper.inkMute)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
        .padding(.horizontal, KSpace.gutter)
    }

    // Κλειδωμένο ἐκτὸς κι ἂν τὸ ἀμέσως προηγούμενο (στὴ σειρά) ὁλοκληρώθηκε.
    private func rowState(for lesson: LessonContent) -> LessonRowState {
        if progress.isCompleted(lesson.id) { return .completed }
        guard let idx = flatLessons.firstIndex(where: { $0.id == lesson.id }) else { return .locked }
        if idx == 0 { return .available }
        return progress.isCompleted(flatLessons[idx - 1].id) ? .available : .locked
    }
}

// MARK: - Ἕνα μάθημα ὡς σκαλὶ στὴ ράγα

private struct LessonRung: View {
    let lesson: LessonContent
    let state: LessonRowState
    let isFirst: Bool
    let isLast: Bool

    var body: some View {
        HStack(spacing: KSpace.md) {
            rail
            VStack(alignment: .leading, spacing: 3) {
                Text(lesson.title)
                    .font(.system(size: 18, weight: .regular, design: .serif))
                    .foregroundStyle(state == .locked ? Paper.ink.opacity(0.4) : Paper.ink)
                Text("\(lesson.exercises.count) ασκήσεις")
                    .font(KType.caption(12))
                    .foregroundStyle(state == .locked ? Paper.lockedIcon : Paper.inkMute)
            }
            Spacer(minLength: 0)
            if state == .completed {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Paper.inkMute.opacity(0.5))
            } else if state == .available {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Gild.gold.opacity(0.8))
            }
        }
        .frame(maxWidth: .infinity, minHeight: 70, alignment: .leading)
        .padding(.horizontal, KSpace.gutter)
        .contentShape(Rectangle())
    }

    private var rail: some View {
        ZStack {
            VStack(spacing: 0) {
                Rectangle().fill(Gild.gold.opacity(0.22)).frame(width: 2)
                    .opacity(isFirst ? 0 : 1)
                Rectangle().fill(Gild.gold.opacity(0.22)).frame(width: 2)
                    .opacity(isLast ? 0 : 1)
            }
            node
        }
        .frame(width: 46)
    }

    @ViewBuilder private var node: some View {
        switch state {
        case .completed:
            ZStack {
                Circle().fill(Gild.gold)
                Image(systemName: "checkmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Gild.onGold)
            }
            .frame(width: 34, height: 34)
        case .available:
            LessonBreathingNode()
        case .locked:
            ZStack {
                Circle().fill(Paper.lockedFill)
                Circle().strokeBorder(Paper.lockedRing, lineWidth: 1)
                Image(systemName: "lock.fill")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Paper.lockedIcon)
            }
            .frame(width: 30, height: 30)
        }
    }
}

// MARK: - Τὸ τρέχον μάθημα «ἀναπνέει» (σέβεται τὸ Reduce Motion)

private struct LessonBreathingNode: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        ZStack {
            Circle().fill(Gild.gold.opacity(0.12))
                .frame(width: 46, height: 46)
                .scaleEffect(pulse ? 1.06 : 0.94)
            Circle().fill(Paper.bg).frame(width: 38, height: 38)
            Circle().strokeBorder(Gild.gold, lineWidth: 2).frame(width: 38, height: 38)
            Image(systemName: "book.closed.fill")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Gild.gold)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(KMotion.breathe.repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}
