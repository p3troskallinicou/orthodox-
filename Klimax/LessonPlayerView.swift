//
//  LessonPlayerView.swift
//  Klimax
//
//  The lesson player, rebuilt from scratch. A short "ascent" of steps:
//  a quiet intro threshold (no wall of reading), then one exercise per
//  screen, then an illuminated close. The teaching now lives inside the
//  exercises and in the feedback that follows each answer, not in a summary.
//
//  Visual language is deliberately its OWN, unlike the Ἱστορίες reader:
//  no floating parchment card, no double gold border, no flip. Here the
//  screen itself is the surface, answers are ink tiles you tap, and the
//  feedback rises from the bottom as a sheet.
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers

// MARK: - Small shared helpers

extension Gild {
    /// A quiet, muted red-ochre for "incorrect" — never a harsh system red.
    static let error = Color(red: 0.55, green: 0.28, blue: 0.24)
    /// A muted verdigris green for "correct" — the copper-green pigment
    /// illuminators actually used alongside gold leaf, not a bright system
    /// green. Gold stays reserved for progress and things that are earned;
    /// green is specifically the "this answer is right" signal.
    static let success = Color(red: 0.47, green: 0.60, blue: 0.42)
}

enum Haptics {
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func error() { UINotificationFeedbackGenerator().notificationOccurred(.error) }
    static func light() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

/// Gentium Book Plus (SIL) — chosen specifically for full, verified
/// polytonic Greek coverage, unlike most system/UI serif fonts. Falls back
/// to the system serif until the fonts are bundled.
enum AppFont {
    static func serif(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        switch weight {
        case .semibold, .bold, .heavy, .black:
            return .custom("GentiumBookPlus-Bold", size: size)
        default:
            return .custom("Gentium Book Plus", size: size)
        }
    }
    static func serifItalic(size: CGFloat) -> Font {
        .custom("GentiumBookPlus-Italic", size: size)
    }
}

// MARK: - Convenience accessors on the exercise model

private extension Exercise {
    var explanationText: String {
        switch self {
        case .multipleChoice(_, _, _, _, let e): return e
        case .readingPassage(_, _, _, _, _, _, _, let e): return e
        case .trueFalse(_, _, _, let e): return e
        case .fillBlank(_, _, _, _, _, let e): return e
        case .match(_, _, _, let e): return e
        case .order(_, _, _, let e): return e
        case .annotated(let base, _): return base.explanationText
        }
    }
}

// MARK: - Lesson Player

struct LessonPlayerView: View {
    let lesson: LessonContent

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var progress = LessonProgressStore.shared

    @State private var step = 0            // 0 intro · 1...N exercises · N+1 closing
    @State private var retry = 0           // bumps to reset the same question after a fall
    @State private var streak = 0          // consecutive correct answers within the level
    @State private var correctCount = 0    // correct answers this run, for the completion reward
    @State private var contentOffset: CGFloat = 0
    @State private var cloudOpacity: Double = 0
    @State private var travel: Travel = .none
    @State private var lessonFinished = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let travelH: CGFloat = 1000
    private enum Travel: Equatable { case none, rising(from: Int, to: Int), falling(depth: Int) }

    private var n: Int { lesson.exercises.count }
    private var gradedExerciseCount: Int { lesson.exercises.filter(\.isGraded).count }

    var body: some View {
        ZStack {
            Paper.bg.ignoresSafeArea()

            content
                .offset(y: contentOffset)

            if travel != .none {
                TravelLayer(mode: travelMode)
                    .opacity(cloudOpacity)
                    .allowsHitTesting(false)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .onAppear { ScriptureLearningActivityManager.shared.start(lesson: lesson) }
        .onDisappear {
            if !lessonFinished { ScriptureLearningActivityManager.shared.pause() }
        }
    }

    @ViewBuilder private var content: some View {
        if step == 0 {
            IntroThreshold(lesson: lesson, onStart: { advance(correct: true) }, onClose: { dismiss() })
        } else if step <= n, let ex = lesson.exercises[safe: step - 1] {
            ExercisePlay(
                exercise: ex,
                index: step - 1,
                total: n,
                onClose: { dismiss() },
                onContinue: { wasCorrect in advance(correct: wasCorrect) },
                streak: streak
            )
            .id("\(ex.id)#\(retry)")
        } else {
            ClosingRite(lesson: lesson, onFinish: { dismiss() })
                .onAppear {
                    lessonFinished = true
                    let firstTime = !progress.isCompleted(lesson.id)
                    PlayerProgressStore.shared.completeLesson(
                        lessonID: lesson.id,
                        exerciseCount: gradedExerciseCount,
                        correctAnswers: correctCount,
                        firstTime: firstTime
                    )
                    progress.markCompleted(lesson.id)
                    ScriptureLearningActivityManager.shared.complete()
                }
        }
    }

    private var travelMode: TravelLayer.Mode {
        switch travel {
        case .rising(let f, let t): return .rise(from: f, to: t, total: n)
        case .falling(let d):       return .fall(depth: d)
        case .none:                 return .rise(from: 0, to: 0, total: n)
        }
    }

    // MARK: travel orchestration (fast · slow · fast)

    private func advance(correct: Bool) {
        guard travel == .none else { return }          // ignore taps mid-flight
        if step >= 1, let currentExercise = lesson.exercises[safe: step - 1], currentExercise.isGraded {
            if correct { correctCount += 1 }
            streak = correct ? streak + 1 : 0   // count real answers, not passive cards or the intro
            if let nodeID = currentExercise.metadata.nodeId {
                NodeMemoryStore.shared.record(nodeID: nodeID, correct: correct)
            }
            ScriptureLearningActivityManager.shared.update(
                step: correct ? step : max(0, step - 1),
                correct: correct
            )
        } else if step >= 1 {
            ScriptureLearningActivityManager.shared.update(step: step, correct: nil)
        }
        if reduceMotion {
            if correct { step += 1 } else { retry += 1 }
            return
        }
        if correct { beginRise() } else { beginFall() }
    }

    /// The ascent, sequenced strictly so the two layers never overlap:
    /// 1. old content drops away fast · clouds fade in
    /// 2. a calm beat inside the clouds (the vertical progress badge is the focus)
    /// 3. clouds fully clear
    /// 4. only then the next question settles up into place from below
    private func beginRise() {
        // ascent: the whole scene travels downward so the viewport reads as rising. Old content
        // drops off the bottom, then the next question comes down from above into place.
        beginTravel(mode: .rising(from: step, to: step + 1),
                    exit: travelH, enterFrom: -travelH,
                    exitDur: 0.34, hold: 0.9) { self.step += 1 }
    }

    private func beginFall() {
        let depth = step
        let fall = min(0.42 + Double(depth) * 0.12, 1.15)   // height ∝ how far climbed
        // fall: old content drops down and off the bottom, the retry drops in from the top
        beginTravel(mode: .falling(depth: depth),
                    exit: travelH, enterFrom: -travelH,
                    exitDur: fall, hold: 0.7) { self.retry += 1 }
    }

    /// Shared four beat choreography. `exit` is where the current content leaves,
    /// `enterFrom` is the off screen side the new content travels in from. The swap
    /// and the reposition both happen while the content is off screen behind the
    /// opaque clouds, so the two layers never overlap.
    private func beginTravel(mode: Travel, exit: CGFloat, enterFrom: CGFloat,
                             exitDur: Double, hold: Double, swap: @escaping () -> Void) {
        let reveal = 0.8          // clouds thin and drift on while the new content travels through them

        travel = mode
        cloudOpacity = 0

        withAnimation(.easeIn(duration: exitDur)) { contentOffset = exit }   // fast start: content leaves
        withAnimation(.easeOut(duration: 0.22)) { cloudOpacity = 1 }         // clouds close over the scene

        DispatchQueue.main.asyncAfter(deadline: .now() + exitDur) {
            swap()                              // change question while off screen, behind the clouds
            var tx = Transaction()
            tx.disablesAnimations = true
            withTransaction(tx) { contentOffset = enterFrom }   // wait just off screen, instantly

            DispatchQueue.main.asyncAfter(deadline: .now() + hold) {          // slow middle: badge is legible
                // One motion: the clouds dissolve and keep drifting while the new content travels in
                // through them on the very same curve. The entrance is part of the cloud transition,
                // not a separate step tacked on after.
                withAnimation(.easeInOut(duration: reveal)) {
                    cloudOpacity = 0
                    contentOffset = 0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + reveal) {
                    travel = .none
                }
            }
        }
    }
}

// MARK: - Intro threshold (sets intention, no reading wall)

private struct IntroThreshold: View {
    let lesson: LessonContent
    var onStart: () -> Void
    var onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Paper.inkMute)
                        .padding(10)
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)

            Spacer()

            VStack(spacing: 14) {
                Image(ScriptureMascotMood.ready.assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 154, height: 164)
                    .accessibilityLabel("Η μασκότ της Βιβλικής Πορείας")
                Text(lesson.title)
                    .font(AppFont.serif(size: 34, weight: .bold))
                    .foregroundStyle(Paper.ink)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Rectangle().fill(Gild.gold.opacity(0.5)).frame(width: 44, height: 1)
                Text("\(lesson.exercises.count) βήματα")
                    .font(.system(size: 13, weight: .medium)).tracking(1)
                    .foregroundStyle(Paper.inkMute)
            }
            .padding(.horizontal, 40)

            Spacer()

            PrimaryButton(title: "Ξεκίνα", action: onStart)
                .padding(.horizontal, 22)
                .padding(.bottom, 28)
        }
    }
}

// MARK: - Tactile building blocks (pressable depth, game feel)

private let goldBase  = Gild.goldRing
private let errorBase = Color(red: 0.40, green: 0.18, blue: 0.15)

private enum GreekIndex {
    static let letters = ["Α", "Β", "Γ", "Δ", "Ε", "Ϛ", "Ζ", "Η"]
    static func at(_ i: Int) -> String { letters[safe: i] ?? "\(i + 1)" }
}

/// A button that sits on a solid coloured ledge and presses down onto it when tapped.
/// The ledge is a hard, zero blur shadow, so it works with any content height.
private struct TactileStyle: ButtonStyle {
    var face: Color
    var base: Color
    var stroke: Color = .clear
    var corner: CGFloat = 18
    var depth: CGFloat = 5
    var lineWidth: CGFloat = 1.5

    func makeBody(configuration c: Configuration) -> some View {
        c.label
            .background(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .fill(Paper.card)                       // opaque backing: the ledge never bleeds through
                    .overlay(
                        RoundedRectangle(cornerRadius: corner, style: .continuous).fill(face)
                    )
                    .shadow(color: base, radius: 0, x: 0, y: c.isPressed ? 0 : depth)
            )
            .offset(y: c.isPressed ? depth : 0)
            .animation(.easeOut(duration: 0.09), value: c.isPressed)
    }
}

/// The primary chunky action button (start · check · continue).
private struct PrimaryButton: View {
    let title: String
    var enabled: Bool = true
    var tint: Color = Gild.gold
    var ledge: Color = goldBase
    var ink: Color = Gild.onGold
    var action: () -> Void

    var body: some View {
        Button(action: { if enabled { action() } }) {
            Text(title)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(enabled ? ink : Paper.inkMute)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
        }
        .buttonStyle(TactileStyle(
            face: enabled ? tint : Paper.hairline.opacity(0.5),
            base: enabled ? ledge : .clear,
            corner: 18,
            depth: enabled ? 5 : 0))
        .disabled(!enabled)
        .padding(.bottom, enabled ? 5 : 0)   // reserve the ledge height
    }
}

private struct Badge: View {
    let text: String
    var bg: Color
    var fg: Color
    var body: some View {
        Text(text)
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(fg)
            .frame(width: 30, height: 30)
            .background(Circle().fill(bg))
    }
}

/// A short horizontal shake. Drive animatableData from 0 to N (number of shakes).
private struct Shake: GeometryEffect {
    var amount: CGFloat = 7
    var animatableData: CGFloat
    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: amount * sin(animatableData * .pi * 2), y: 0))
    }
}

// MARK: - Language toggle (original vs translation, remembered across questions)

private struct LangToggle: View {
    @Binding var showTranslation: Bool
    var body: some View {
        HStack(spacing: 8) {
            pill("Πρωτότυπο", active: !showTranslation) { showTranslation = false }
            pill("Μετάφραση", active: showTranslation) { showTranslation = true }
        }
    }
    private func pill(_ title: String, active: Bool, _ tap: @escaping () -> Void) -> some View {
        Button(action: tap) {
            Text(title)
                .font(.system(size: 12, weight: .semibold)).tracking(1)
                .foregroundStyle(active ? Gild.onGold : Paper.inkMute)
                .padding(.horizontal, 14).padding(.vertical, 7)
                .background(Capsule().fill(active ? Gild.gold : Color.clear))
                .overlay(Capsule().stroke(Paper.inkMute.opacity(0.3), lineWidth: active ? 0 : 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - One exercise

private struct ExercisePlay: View {
    let exercise: Exercise
    let index: Int
    let total: Int
    var onClose: () -> Void
    var onContinue: (Bool) -> Void
    var streak: Int = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var submitted = false
    @State private var correct = false
    @State private var selected: Int? = nil          // single-select
    @State private var shuf: [Int] = []              // shuffled slots (match rights / order items)
    @State private var optOrder: [Int] = []          // shuffled display order for single-select options
    @State private var order: [Int] = []             // order: tapped slots, in order
    @State private var assigned: [Int: Int] = [:]    // match: leftIndex -> right slot
    @State private var selLeft: Int? = nil           // match: currently picked left

    // progress bar + feedback beats
    @State private var barFill: CGFloat = 0
    @State private var barPulse = false
    @State private var wrongShake: CGFloat = 0
    @State private var glow = false
    @State private var charged = false            // the streak aura, may switch on mid-question
    @State private var revealedVerses: Set<Int> = []
    @State private var patristicLayer: PatristicLayer?

    // remembers the reader's language choice across questions and launches
    @AppStorage("klimax.showTranslation") private var showTranslation = false

    private let electrifyAt = 3
    private var startsCharged: Bool { streak >= electrifyAt }
    private var activeExercise: Exercise { exercise.unwrapped }
    private var cardKind: LessonCardKind? { exercise.metadata.cardKind }
    private var isPassiveCard: Bool { cardKind == .keimeno || cardKind == .siopi }

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                topBar
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        stemView
                        if !isPassiveCard {
                            optionsView
                                .modifier(Shake(animatableData: wrongShake))
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 10)
                    .padding(.bottom, 150)
                }
            }

            if isPassiveCard {
                continueBar.transition(.opacity)
            } else if submitted {
                feedbackSheet.transition(.move(edge: .bottom))
            } else {
                checkBar.transition(.opacity)
            }
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.86), value: submitted)
        .onAppear(perform: prepare)
        .sheet(item: $patristicLayer) { layer in
            PatristicLayerSheet(layer: layer, metadata: exercise.metadata)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(Paper.bg)
        }
    }

    // MARK: chrome

    private var topBar: some View {
        HStack(spacing: 14) {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Paper.inkMute)
                    .padding(8)
            }
            progressBar
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .padding(.bottom, 10)
    }

    private var progressBar: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let fillW = max(9, w * barFill)
            ZStack(alignment: .leading) {
                // a soft glow that breathes AROUND the bar while the streak is alive
                if charged {
                    Capsule()
                        .fill(Gild.gold)
                        .frame(width: fillW, height: 9)
                        .scaleEffect(x: 1.02, y: glow ? 2.6 : 1.9, anchor: .center)
                        .blur(radius: glow ? 11 : 7)
                        .opacity(glow ? 0.7 : 0.4)
                }
                Capsule().fill(Paper.hairline).frame(height: 9)
                Capsule()
                    .fill(charged ? Gild.goldBright : Gild.gold)
                    .frame(width: fillW, height: 9)
                    .overlay(alignment: .trailing) {
                        if charged {
                            // the charged head at the tip of progress
                            Circle()
                                .fill(Color.white.opacity(0.92))
                                .frame(width: 12, height: 12)
                                .blur(radius: 1.5)
                                .opacity(glow ? 1 : 0.5)
                        }
                    }
                    .scaleEffect(x: 1, y: barPulse ? 1.7 : 1, anchor: .center)
            }
        }
        .frame(height: 9)
    }

    // MARK: stem

    @ViewBuilder private var stemView: some View {
        if cardKind == .keimeno, let reading = readingPayload {
            scriptureTextCard(source: reading.source, passage: reading.passage, gloss: reading.gloss)
        } else if cardKind == .siopi, let reading = readingPayload {
            silenceCard(source: reading.source, passage: reading.passage)
        } else {
            switch activeExercise {
            case .multipleChoice(_, let p, _, _, _):
                promptText(p)
            case .trueFalse(_, let s, _, _):
                eyebrow("ΑΛΗΘΕΣ Ή ΨΕΥΔΕΣ"); promptText(s)
            case .fillBlank(_, let before, let after, _, _, _):
                eyebrow("ΣΥΜΠΛΗΡΩΣΕ"); fillStem(before, after)
            case .readingPassage(_, let src, let passage, let gloss, let q, _, _, _):
                passageBlock(source: src, passage: passage, gloss: gloss); promptText(q)
            case .match(_, let ins, _, _):
                eyebrow("ΤΑΙΡΙΑΞΕ"); promptText(ins)
            case .order(_, let p, _, _):
                eyebrow("ΒΑΛΕ ΣΕ ΣΕΙΡΑ"); promptText(p)
            case .annotated:
                EmptyView()
            }
        }
    }

    private var readingPayload: (source: String, passage: String, gloss: String)? {
        if case .readingPassage(_, let source, let passage, let gloss, _, _, _, _) = activeExercise {
            return (source, passage, gloss)
        }
        return nil
    }

    private func eyebrow(_ t: String) -> some View {
        Text(t).font(.system(size: 12, weight: .semibold)).tracking(3).foregroundStyle(Gild.gold)
    }

    private func promptText(_ t: String) -> some View {
        Text(t)
            .font(AppFont.serif(size: 24, weight: .regular))
            .foregroundStyle(Paper.ink)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func fillStem(_ before: String, _ after: String) -> some View {
        let fill = selected.flatMap { singleOptions?[safe: $0] }
        return (
            Text(before)
            + Text(fill == nil ? "  ____  " : "  \(fill!)  ")
                .foregroundColor(Gild.gold)
            + Text(after)
        )
        .font(AppFont.serif(size: 23))
        .foregroundColor(Paper.ink)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func passageBlock(source: String, passage: String, gloss: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            LangToggle(showTranslation: $showTranslation)
            Text(showTranslation ? gloss : passage)
                .font(AppFont.serif(size: 19))
                .foregroundStyle(Paper.ink)
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)
            Text(source)
                .font(.system(size: 12)).foregroundStyle(Paper.inkMute)
        }
        .padding(.leading, 16)
        .overlay(Rectangle().fill(Gild.gold.opacity(0.55)).frame(width: 2), alignment: .leading)
    }

    private func scriptureTextCard(source: String, passage: String, gloss: String) -> some View {
        let verses = passage.components(separatedBy: .newlines).filter { !$0.isEmpty }
        let translations = gloss.components(separatedBy: .newlines).filter { !$0.isEmpty }

        return VStack(alignment: .leading, spacing: 17) {
            VStack(alignment: .leading, spacing: 5) {
                eyebrow("ΙΕΡΟ ΚΕΙΜΕΝΟ")
                Text("Άγγιξε κάθε στίχο για να φανερωθεί η νεοελληνική απόδοση.")
                    .font(.system(size: 12, weight: .medium, design: .serif))
                    .foregroundStyle(Paper.inkMute)
            }

            VStack(spacing: 0) {
                ForEach(verses.indices, id: \.self) { verseIndex in
                    Button {
                        withAnimation(.easeInOut(duration: 0.22)) {
                            if revealedVerses.contains(verseIndex) {
                                revealedVerses.remove(verseIndex)
                            } else {
                                revealedVerses.insert(verseIndex)
                            }
                        }
                        Haptics.light()
                    } label: {
                        VStack(alignment: .leading, spacing: 9) {
                            HStack(alignment: .firstTextBaseline, spacing: 10) {
                                Text(verses[verseIndex])
                                    .font(AppFont.serif(size: 20))
                                    .foregroundStyle(Paper.ink)
                                    .lineSpacing(6)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                Image(systemName: revealedVerses.contains(verseIndex) ? "chevron.up" : "text.bubble")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(Gild.gold)
                            }

                            if revealedVerses.contains(verseIndex), let translation = translations[safe: verseIndex] {
                                Text(translation)
                                    .font(AppFont.serif(size: 17))
                                    .foregroundStyle(Paper.inkSoft)
                                    .lineSpacing(4)
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                        .padding(.horizontal, 17)
                        .padding(.vertical, 16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if verseIndex < verses.count - 1 {
                        Rectangle().fill(Paper.hairline).frame(height: 0.75)
                    }
                }
            }
            .background(Paper.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Gild.gold.opacity(0.16), lineWidth: 0.75)
            }

            if !source.isEmpty {
                Text(source)
                    .font(.system(size: 11, weight: .medium, design: .serif))
                    .foregroundStyle(Paper.inkMute)
            }
        }
    }

    private func silenceCard(source: String, passage: String) -> some View {
        VStack(spacing: 24) {
            Spacer(minLength: 42)

            LessonOrthodoxCrossMark(color: Gild.gold)
                .frame(width: 30, height: 38)

            Text(passage)
                .font(AppFont.serif(size: 26))
                .foregroundStyle(Paper.ink)
                .multilineTextAlignment(.center)
                .lineSpacing(7)
                .fixedSize(horizontal: false, vertical: true)

            Rectangle()
                .fill(Gild.gold.opacity(0.34))
                .frame(width: 42, height: 1)

            if !source.isEmpty {
                Text(source)
                    .font(.system(size: 12, weight: .medium, design: .serif))
                    .foregroundStyle(Paper.inkMute)
                    .multilineTextAlignment(.center)
            }

            Text("Μείνε λίγο με τη φράση πριν συνεχίσεις.")
                .font(.system(size: 12, design: .serif))
                .foregroundStyle(Paper.inkMute.opacity(0.75))
                .padding(.top, 4)

            Spacer(minLength: 24)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
    }

    // MARK: options

    @ViewBuilder private var optionsView: some View {
        if let opts = singleOptions {
            let slots = optOrder.isEmpty ? Array(opts.indices) : optOrder
            VStack(spacing: 12) {
                ForEach(slots.indices, id: \.self) { slot in
                    let orig = slots[slot]
                    optionTile(opts[safe: orig] ?? "", orig, slot: slot)
                }
            }
        } else {
            switch activeExercise {
            case .match(_, _, let pairs, _): matchView(pairs)
            case .order(_, _, let items, _): orderView(items)
            default: EmptyView()
            }
        }
    }

    private func optionTile(_ text: String, _ i: Int, slot: Int) -> some View {
        let chosen = selected == i
        let showCorrect = submitted && correctIndex == i
        let showWrong = submitted && chosen && correctIndex != i
        let dim = submitted && !showCorrect && !chosen
        let c = tileColors(chosen: chosen, correct: showCorrect, wrong: showWrong)
        return Button {
            if !submitted { selected = i; Haptics.light() }
        } label: {
            HStack(spacing: 14) {
                Badge(text: GreekIndex.at(slot), bg: c.badgeBg, fg: c.badgeFg)
                Text(text)
                    .font(AppFont.serif(size: 18))
                    .foregroundStyle(Paper.ink)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if showCorrect { Image(systemName: "checkmark").font(.system(size: 15, weight: .bold)).foregroundStyle(Gild.success) }
                if showWrong { Image(systemName: "xmark").font(.system(size: 15, weight: .bold)).foregroundStyle(Gild.error) }
            }
            .padding(.horizontal, 16).padding(.vertical, 17)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(TactileStyle(face: c.face, base: c.base, stroke: c.stroke, corner: 18, depth: 5))
        .opacity(dim ? 0.5 : 1)
        .scaleEffect(showCorrect ? 1.03 : 1)
        .animation(.spring(response: 0.32, dampingFraction: 0.5), value: submitted)
        .disabled(submitted)
        .padding(.bottom, 5)   // room for the ledge
    }

    private struct TileColors { var face: Color; var base: Color; var stroke: Color; var badgeBg: Color; var badgeFg: Color }

    private func tileColors(chosen: Bool, correct: Bool, wrong: Bool) -> TileColors {
        if correct { return TileColors(face: Gild.success.opacity(0.16), base: Gild.success.opacity(0.6), stroke: Gild.success, badgeBg: Gild.success, badgeFg: .white) }
        if wrong   { return TileColors(face: Gild.error.opacity(0.16),   base: Gild.error.opacity(0.6),   stroke: Gild.error,   badgeBg: Gild.error,   badgeFg: .white) }
        if chosen  { return TileColors(face: Gild.gold.opacity(0.16),    base: goldBase.opacity(0.9),     stroke: Gild.gold,    badgeBg: Gild.gold,    badgeFg: Gild.onGold) }
        return TileColors(face: Paper.card, base: Paper.hairline, stroke: Paper.hairline, badgeBg: Paper.hairline.opacity(0.7), badgeFg: Paper.inkMute)
    }

    // MARK: match

    private func matchView(_ pairs: [MatchPair]) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 10) {
                ForEach(pairs.indices, id: \.self) { i in
                    matchTile(text: pairs[i].left,
                              badge: assigned[i].map { _ in i + 1 },
                              selected: selLeft == i,
                              state: matchLeftState(i)) {
                        if !submitted { selLeft = (selLeft == i ? nil : i); Haptics.light() }
                    }
                }
            }
            VStack(spacing: 10) {
                ForEach(shuf.indices, id: \.self) { s in
                    let owner = assigned.first(where: { $0.value == s })?.key
                    matchTile(text: pairs[safe: shuf[safe: s] ?? -1]?.right ?? "",
                              badge: owner.map { $0 + 1 },
                              selected: false,
                              state: matchRightState(s)) {
                        guard !submitted, let l = selLeft else { return }
                        assigned = assigned.filter { $0.value != s }   // free that slot
                        assigned[l] = s
                        selLeft = nil
                        Haptics.light()
                    }
                }
            }
        }
    }

    private func matchLeftState(_ i: Int) -> TileState {
        guard submitted, let s = assigned[i] else { return .plain }
        return (shuf[safe: s] == i) ? .correct : .wrong
    }
    private func matchRightState(_ s: Int) -> TileState {
        guard submitted, let owner = assigned.first(where: { $0.value == s })?.key else { return .plain }
        return (shuf[safe: s] == owner) ? .correct : .wrong
    }

    // MARK: order

    private func orderView(_ items: [String]) -> some View {
        VStack(spacing: 10) {
            ForEach(shuf.indices, id: \.self) { s in
                let pos = order.firstIndex(of: s)
                matchTile(text: items[safe: shuf[safe: s] ?? -1] ?? "",
                          badge: pos.map { $0 + 1 },
                          selected: false,
                          state: orderState(s, pos)) {
                    guard !submitted else { return }
                    if let p = pos {
                        order.removeSubrange(p..<order.count)   // tap again to undo from here
                    } else {
                        order.append(s)
                    }
                    Haptics.light()
                }
            }
        }
    }

    private func orderState(_ s: Int, _ pos: Int?) -> TileState {
        guard submitted, let p = pos else { return .plain }
        return (shuf[safe: s] == p) ? .correct : .wrong
    }

    // A shared chip used by match and order (badge + text, tappable, pressable)
    private func matchTile(text: String, badge: Int?, selected: Bool, state: TileState, tap: @escaping () -> Void) -> some View {
        let c = chipColors(selected: selected, state: state)
        return Button(action: tap) {
            HStack(spacing: 10) {
                if let b = badge {
                    Badge(text: "\(b)", bg: c.badgeBg, fg: c.badgeFg)
                }
                Text(text)
                    .font(AppFont.serif(size: 16)).foregroundStyle(Paper.ink)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 14).padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(TactileStyle(face: c.face, base: c.base, stroke: c.stroke, corner: 14, depth: 4))
        .disabled(submitted)
        .padding(.bottom, 4)
    }

    private func chipColors(selected: Bool, state: TileState) -> TileColors {
        switch state {
        case .correct: return TileColors(face: Gild.success.opacity(0.14), base: Gild.success.opacity(0.5), stroke: Gild.success, badgeBg: Gild.success, badgeFg: .white)
        case .wrong:   return TileColors(face: Gild.error.opacity(0.14),   base: Gild.error.opacity(0.5),   stroke: Gild.error,   badgeBg: Gild.error,   badgeFg: .white)
        case .plain:
            if selected { return TileColors(face: Gild.gold.opacity(0.12), base: goldBase.opacity(0.7), stroke: Gild.gold, badgeBg: Gild.gold, badgeFg: Gild.onGold) }
            return TileColors(face: Paper.card, base: Paper.hairline, stroke: Paper.hairline, badgeBg: Gild.gold, badgeFg: Gild.onGold)
        }
    }

    // MARK: bottom bar + feedback

    private var checkBar: some View {
        PrimaryButton(title: "Έλεγξε", enabled: canCheck, action: check)
            .padding(.horizontal, 22)
            .padding(.bottom, 24)
    }

    private var continueBar: some View {
        PrimaryButton(title: "Συνέχισε", action: { onContinue(true) })
            .padding(.horizontal, 22)
            .padding(.bottom, 24)
    }

    private var feedbackSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image((correct ? ScriptureMascotMood.celebrating : .thinking).assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 54, height: 58)
                    .accessibilityHidden(true)
                Image(systemName: correct ? "checkmark.seal.fill" : "arrow.uturn.backward.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(correct ? Gild.success : Gild.error)
                Text(correct ? "Σωστά" : "Σκέψου το ξανά")
                    .font(AppFont.serif(size: 21, weight: .bold))
                    .foregroundStyle(correct ? Gild.success : Gild.error)
            }
            Text(exercise.explanationText)
                .font(AppFont.serif(size: 16))
                .foregroundStyle(Paper.ink)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            if exercise.metadata.hasPatristicLayers {
                HStack(spacing: 10) {
                    if !(exercise.metadata.ektenis ?? "").isEmpty {
                        patristicButton("Γιατί", symbol: "text.magnifyingglass", layer: .ektenis)
                    }
                    if !(exercise.metadata.prototypo ?? "").isEmpty {
                        patristicButton("Πρωτότυπο", symbol: "character.book.closed.fill", layer: .prototypo)
                    }
                }
            }

            PrimaryButton(
                title: correct ? (index + 1 < total ? "Συνέχισε" : "Ολοκλήρωσε") : "Δοκίμασε ξανά",
                tint: correct ? Gild.gold : Gild.error,
                ledge: correct ? goldBase : errorBase,
                ink: correct ? Gild.onGold : .white,
                action: { onContinue(correct) }
            )
            .padding(.top, 4)
        }
        .padding(20)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Paper.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(LinearGradient(colors: [Gild.gold.opacity(0.14), .clear], startPoint: .top, endPoint: .center))
                )
                .ignoresSafeArea(edges: .bottom)
        )
        .shadow(color: .black.opacity(0.14), radius: 22, x: 0, y: -6)
    }

    private func patristicButton(_ title: String, symbol: String, layer: PatristicLayer) -> some View {
        Button {
            patristicLayer = layer
            Haptics.light()
        } label: {
            Label(title, systemImage: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Paper.gold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Gild.gold.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Gild.gold.opacity(0.18), lineWidth: 0.75)
                }
        }
        .buttonStyle(.plain)
    }

    // MARK: logic

    private var singleOptions: [String]? {
        switch activeExercise {
        case .multipleChoice(_, _, let o, _, _): return o
        case .trueFalse: return ["Αληθές", "Ψευδές"]
        case .fillBlank(_, _, _, _, let o, _): return o
        case .readingPassage(_, _, _, _, _, let o, _, _): return o
        default: return nil
        }
    }
    private var correctIndex: Int? {
        switch activeExercise {
        case .multipleChoice(_, _, _, let a, _): return a
        case .trueFalse(_, _, let a, _): return a ? 0 : 1
        case .fillBlank(_, _, _, let ans, let o, _): return o.firstIndex(of: ans)
        case .readingPassage(_, _, _, _, _, _, let a, _): return a
        default: return nil
        }
    }

    private var canCheck: Bool {
        switch activeExercise {
        case .match(_, _, let pairs, _): return assigned.count == pairs.count
        case .order(_, _, let items, _): return order.count == items.count
        default: return selected != nil
        }
    }

    private func prepare() {
        switch activeExercise {
        case .order(_, _, let items, _): if shuf.isEmpty { shuf = Array(0..<items.count).shuffled() }
        case .match(_, _, let pairs, _): if shuf.isEmpty { shuf = Array(0..<pairs.count).shuffled() }
        default: break
        }
        if optOrder.isEmpty, let o = singleOptions {
            if case .trueFalse = activeExercise { optOrder = Array(0..<o.count) }
            else { optOrder = Array(0..<o.count).shuffled() }
        }
        barFill = total > 0 ? CGFloat(index) / CGFloat(total) : 0
        charged = startsCharged
        if charged { startGlow() }
    }

    private func startGlow() {
        guard !reduceMotion else { return }
        withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { glow = true }
    }

    private func check() {
        guard canCheck else { return }
        switch activeExercise {
        case .match(_, _, let pairs, _):
            correct = pairs.indices.allSatisfy { i in assigned[i].map { shuf[safe: $0] == i } ?? false }
        case .order(_, _, let items, _):
            correct = (0..<items.count).allSatisfy { k in shuf[safe: order[safe: k] ?? -1] == k }
        default:
            correct = (selected == correctIndex)
        }
        submitted = true
        if correct {
            Haptics.success()
            // the bar advances and gives a small pulse: the reward beat, right now
            withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) {
                barFill = total > 0 ? CGFloat(index + 1) / CGFloat(total) : 1
            }
            // the streak ignites at this exact moment, not after the ascent
            if (streak + 1) >= electrifyAt && !charged {
                withAnimation(.easeOut(duration: 0.3)) { charged = true }
                startGlow()
            }
            if !reduceMotion {
                withAnimation(.easeOut(duration: 0.16)) { barPulse = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                    withAnimation(.easeIn(duration: 0.26)) { barPulse = false }
                }
            }
        } else {
            Haptics.error()
            // a short, contained shake: recognisable but gentle, never a harsh error
            if !reduceMotion {
                wrongShake = 0
                withAnimation(.easeInOut(duration: 0.42)) { wrongShake = 3 }
            }
        }
    }
}

private enum PatristicLayer: String, Identifiable {
    case ektenis
    case prototypo

    var id: String { rawValue }
    var title: String { self == .ektenis ? "Γιατί" : "Πρωτότυπο" }
    var eyebrow: String { self == .ektenis ? "ΠΑΤΕΡΙΚΗ ΕΞΗΓΗΣΗ" : "ΠΑΤΕΡΙΚΟ ΚΕΙΜΕΝΟ" }
}

private struct PatristicLayerSheet: View {
    let layer: PatristicLayer
    let metadata: ExerciseMetadata

    @Environment(\.dismiss) private var dismiss

    private var text: String {
        switch layer {
        case .ektenis: metadata.ektenis ?? ""
        case .prototypo: metadata.prototypo ?? ""
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(layer.eyebrow)
                        .font(.system(size: 9, weight: .black))
                        .tracking(1.7)
                        .foregroundStyle(Paper.gold)
                    Text(layer.title)
                        .font(AppFont.serif(size: 26, weight: .bold))
                        .foregroundStyle(Paper.ink)
                }

                Spacer()

                Button("Κλείσιμο") { dismiss() }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Paper.gold)
            }
            .padding(.horizontal, 22)
            .padding(.top, 20)
            .padding(.bottom, 14)

            Rectangle().fill(Paper.hairline).frame(height: 0.75)

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text(text)
                        .font(AppFont.serif(size: layer == .prototypo ? 19 : 18))
                        .foregroundStyle(Paper.ink)
                        .lineSpacing(layer == .prototypo ? 7 : 5)
                        .fixedSize(horizontal: false, vertical: true)

                    if !metadata.sources.isEmpty {
                        sourceWitnesses
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 20)
                .padding(.bottom, 36)
            }
        }
    }

    @ViewBuilder
    private var sourceWitnesses: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(metadata.sources.count == 1 ? "ΜΑΡΤΥΡΙΑ" : "ΔΥΟ ΜΑΡΤΥΡΙΕΣ")
                .font(.system(size: 9, weight: .black))
                .tracking(1.65)
                .foregroundStyle(Paper.inkMute)

            if metadata.sources.count == 2 {
                HStack(alignment: .top, spacing: 10) {
                    ForEach(metadata.sources) { source in
                        sourceCard(source)
                            .frame(maxWidth: .infinity, alignment: .top)
                    }
                }
            } else {
                ForEach(metadata.sources) { source in
                    sourceCard(source)
                }
            }
        }
    }

    private func sourceCard(_ source: PatristicSource) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(source.father)
                .font(AppFont.serif(size: 15, weight: .bold))
                .foregroundStyle(Paper.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(source.work)
                .font(AppFont.serifItalic(size: 13))
                .foregroundStyle(Paper.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            Text([source.homily, source.pg].filter { !$0.isEmpty }.joined(separator: " · "))
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Paper.inkMute)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
        .background(Paper.card, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(Gild.gold.opacity(0.14), lineWidth: 0.75)
        }
    }
}

private struct LessonOrthodoxCrossMark: View {
    let color: Color

    var body: some View {
        ZStack {
            Capsule().fill(color).frame(width: 4, height: 34)
            Capsule().fill(color).frame(width: 14, height: 3).offset(y: -11)
            Capsule().fill(color).frame(width: 26, height: 4).offset(y: -4)
            Capsule()
                .fill(color)
                .frame(width: 18, height: 3)
                .rotationEffect(.degrees(-14))
                .offset(y: 10)
        }
        .accessibilityHidden(true)
    }
}

private enum TileState: Equatable { case plain, correct, wrong }

// MARK: - Illuminated closing

private struct ClosingRite: View {
    let lesson: LessonContent
    var onFinish: () -> Void
    @State private var bloom = false
    @AppStorage("klimax.showTranslation") private var showTranslation = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [Gild.gold.opacity(0.28), .clear],
                                         center: .center, startRadius: 4, endRadius: 150))
                    .frame(width: 260, height: 260)
                    .scaleEffect(bloom ? 1 : 0.6)
                    .opacity(bloom ? 1 : 0)
                Image(ScriptureMascotMood.celebrating.assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 172, height: 184)
                    .scaleEffect(bloom ? 1 : 0.7)
            }
            VStack(spacing: 14) {
                Text("Ολοκλήρωσες το μάθημα")
                    .font(.system(size: 12, weight: .semibold)).tracking(3)
                    .foregroundStyle(Gild.gold)
                if !lesson.closing.gloss.isEmpty {
                    LangToggle(showTranslation: $showTranslation)
                }
                Text((showTranslation && !lesson.closing.gloss.isEmpty) ? lesson.closing.gloss : lesson.closing.text)
                    .font(AppFont.serif(size: 22))
                    .foregroundStyle(Paper.ink)
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
                    .fixedSize(horizontal: false, vertical: true)
                if !lesson.closing.source.isEmpty {
                    Text(lesson.closing.source)
                        .font(.system(size: 13)).foregroundStyle(Paper.inkMute)
                }
            }
            .padding(.horizontal, 30)
            .padding(.top, 10)
            Spacer()
            Button(action: onFinish) {
                Text("Τελείωσε")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Gild.onGold)
                    .frame(maxWidth: .infinity).frame(height: 56)
                    .background(Gild.gold, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 24)
        }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.8)) { bloom = true }
        }
    }
}

// MARK: - Travel layer: clouds you rise through (or fall past)

private struct TravelLayer: View {
    enum Mode: Equatable {
        case rise(from: Int, to: Int, total: Int)
        case fall(depth: Int)
    }
    let mode: Mode

    @State private var drift = false     // cloud motion
    @State private var reveal = false    // badge / message reveal

    private var goingUp: Bool { if case .rise = mode { return true } else { return false } }

    // x (0..1), y (0..1), width, height, opacity
    private let clouds: [(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, o: Double)] = [
        (0.20, 0.16, 250, 96, 0.55),
        (0.74, 0.30, 290, 112, 0.46),
        (0.44, 0.50, 350, 132, 0.52),
        (0.16, 0.66, 230, 90, 0.44),
        (0.82, 0.60, 270, 100, 0.48),
        (0.50, 0.84, 310, 118, 0.50)
    ]

    var body: some View {
        GeometryReader { geo in
            let H = geo.size.height
            let dist = H * 0.95
            let dir: CGFloat = goingUp ? 1 : -1     // rise: clouds fall past · fall: clouds rush up
            ZStack {
                ForEach(clouds.indices, id: \.self) { i in
                    let c = clouds[i]
                    Ellipse()
                        .fill(Color.white)
                        .frame(width: c.w, height: c.h)
                        .blur(radius: 30)
                        .opacity(c.o)
                        .position(
                            x: c.x * geo.size.width,
                            y: c.y * H + (drift ? dir * dist : -dir * dist)
                        )
                }
                badge
            }
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0)) { drift = true }
            reveal = true
        }
    }

    @ViewBuilder private var badge: some View {
        switch mode {
        case .rise(let from, let to, let total):
            VStack(spacing: 6) {
                // top: destination question (or the seal on the final step)
                if to > total {
                    Image(systemName: "seal.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(Gild.success)
                        .scaleEffect(reveal ? 1 : 0.5)
                        .opacity(reveal ? 1 : 0)
                        .animation(.spring(response: 0.55, dampingFraction: 0.6).delay(0.64), value: reveal)
                } else {
                    Text("\(to)")
                        .font(AppFont.serif(size: 78, weight: .bold))
                        .foregroundStyle(Gild.success)
                        .scaleEffect(reveal ? 1 : 0.6)
                        .opacity(reveal ? 1 : 0)
                        .animation(.spring(response: 0.55, dampingFraction: 0.6).delay(0.64), value: reveal)
                }

                chevronStack

                // bottom: the question just completed
                if from >= 1 {
                    Text("\(from)")
                        .font(AppFont.serif(size: 78, weight: .bold))
                        .foregroundStyle(Gild.success.opacity(0.85))
                        .opacity(reveal ? 1 : 0)
                        .animation(.easeOut(duration: 0.3).delay(0.05), value: reveal)
                }
            }

        case .fall:
            Text("Δοκίμασε ξανά")
                .font(AppFont.serif(size: 36, weight: .bold))
                .foregroundStyle(Gild.error)
                .opacity(reveal ? 1 : 0)
                .scaleEffect(reveal ? 1 : 0.8)
                .animation(.easeOut(duration: 0.38).delay(0.12), value: reveal)
        }
    }

    // Three chevrons pointing up, revealing from the bottom upward.
    private var chevronStack: some View {
        VStack(spacing: -2) {
            ForEach(0..<3, id: \.self) { i in
                Image(systemName: "chevron.up")
                    .font(.system(size: 42, weight: .bold))
                    .foregroundStyle(Gild.success)
                    .opacity(reveal ? 1 : 0)
                    .offset(y: reveal ? 0 : 12)
                    .animation(.easeOut(duration: 0.32).delay(0.22 + Double(2 - i) * 0.13), value: reveal)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Lesson row state + card (used by the lessons list)

enum LessonRowState { case locked, available, completed }

struct LessonRowCard: View {
    let lesson: LessonContent
    var state: LessonRowState = .available

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().fill(iconBg)
                Image(systemName: iconName).foregroundStyle(iconColor)
            }
            .frame(width: 50, height: 50)

            VStack(alignment: .leading, spacing: 4) {
                Text(lesson.title)
                    .font(AppFont.serif(size: 19, weight: .regular))
                    .foregroundStyle(state == .locked ? Paper.inkMute : Paper.ink)
                Text("\(lesson.exercises.count) ασκήσεις")
                    .font(.system(size: 12)).foregroundStyle(Paper.inkMute)
            }
            Spacer()
            if state == .completed {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Gild.success)
            } else if state == .available {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Paper.inkMute.opacity(0.55))
            }
        }
        .padding(16)
        .background(Paper.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Paper.hairline, lineWidth: 1))
        .shadow(color: .black.opacity(state == .locked ? 0 : 0.04), radius: 10, x: 0, y: 5)
        .opacity(state == .locked ? 0.55 : 1)
    }

    private var iconName: String {
        switch state {
        case .locked: return "lock.fill"
        case .completed: return "checkmark"
        case .available: return "book.closed.fill"
        }
    }
    private var iconBg: Color { state == .locked ? Paper.hairline : Paper.gold.opacity(0.14) }
    private var iconColor: Color { state == .locked ? Paper.inkMute : Paper.gold }
}

// MARK: - Preview

#Preview("Παίκτης μαθήματος · Αποταγή") {
    NavigationStack {
        LessonPlayerView(lesson: .sampleApotage)
    }
}
