import ActivityKit
import Foundation

@MainActor
final class ScriptureLearningActivityManager {
    static let shared = ScriptureLearningActivityManager()

    private var activity: Activity<ScriptureLearningAttributes>?
    private var lessonID: String?
    private var lessonTitle = ""
    private var unitTitle = "Βιβλική Πορεία"
    private var totalSteps = 0

    private init() {}

    func start(lesson: LessonContent) {
        lessonID = lesson.id
        lessonTitle = lesson.title
        unitTitle = Self.unitTitle(for: lesson.id)
        totalSteps = lesson.exercises.count

        let state = ScriptureLearningAttributes.ContentState(
            currentStep: 0,
            totalSteps: totalSteps,
            mood: .ready,
            message: "Έτοιμος για το μάθημα;",
            isComplete: false
        )
        syncWidget(state: state)

        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        Task {
            if let activity {
                await activity.end(
                    ActivityContent(state: state, staleDate: nil),
                    dismissalPolicy: .immediate
                )
            }
            do {
                let attributes = ScriptureLearningAttributes(
                    lessonID: lesson.id,
                    lessonTitle: lesson.title,
                    unitTitle: unitTitle
                )
                activity = try Activity.request(
                    attributes: attributes,
                    content: ActivityContent(state: state, staleDate: Date().addingTimeInterval(60 * 30)),
                    pushType: nil
                )
            } catch {
                #if DEBUG
                print("[ScriptureActivity] Δεν ξεκίνησε Live Activity: \(error)")
                #endif
            }
        }
    }

    func update(step: Int, correct: Bool?) {
        let mood: ScriptureMascotMood
        let message: String
        switch correct {
        case true:
            mood = .celebrating
            message = "Μπράβο — συνέχισε έτσι!"
        case false:
            mood = .thinking
            message = "Δές το ξανά· είσαι κοντά."
        case nil:
            mood = .ready
            message = "Συνέχισε στο επόμενο βήμα."
        }

        let state = ScriptureLearningAttributes.ContentState(
            currentStep: min(max(step, 0), totalSteps),
            totalSteps: totalSteps,
            mood: mood,
            message: message,
            isComplete: false
        )
        syncWidget(state: state)
        guard let activity else { return }
        Task {
            await activity.update(
                ActivityContent(state: state, staleDate: Date().addingTimeInterval(60 * 30))
            )
        }
    }

    func complete() {
        let state = ScriptureLearningAttributes.ContentState(
            currentStep: totalSteps,
            totalSteps: totalSteps,
            mood: .celebrating,
            message: "Ολοκλήρωσες το μάθημα!",
            isComplete: true
        )
        syncWidget(state: state)
        guard let activity else { return }
        Task {
            await activity.end(
                ActivityContent(state: state, staleDate: nil),
                dismissalPolicy: .after(Date().addingTimeInterval(60 * 5))
            )
            self.activity = nil
        }
    }

    func pause() {
        guard let activity else { return }
        let state = ScriptureLearningAttributes.ContentState(
            currentStep: 0,
            totalSteps: totalSteps,
            mood: .thinking,
            message: "Το μάθημα σε περιμένει.",
            isComplete: false
        )
        syncWidget(state: state)
        Task {
            await activity.end(
                ActivityContent(state: state, staleDate: nil),
                dismissalPolicy: .immediate
            )
            self.activity = nil
        }
    }

    private func syncWidget(state: ScriptureLearningAttributes.ContentState) {
        let old = WidgetSharedStore.load().scriptureJourney ?? .sample
        WidgetSharedStore.updateScriptureJourney(
            ScriptureJourneyWidgetInfo(
                lessonTitle: lessonTitle,
                unitTitle: unitTitle,
                completedLessons: old.completedLessons,
                totalLessons: old.totalLessons,
                currentStep: state.currentStep,
                totalSteps: state.totalSteps,
                streak: PlayerProgressStore.shared.currentStreak,
                mood: state.mood,
                message: state.message
            )
        )
    }

    private static func unitTitle(for lessonID: String) -> String {
        if lessonID.hasPrefix("genesis") || lessonID.hasPrefix("bible-abraham") { return "Γένεσις" }
        if lessonID.hasPrefix("bible-exodus") { return "Έξοδος" }
        if lessonID.hasPrefix("bible-gospel") { return "Ευαγγέλια" }
        return "Βιβλική Πορεία"
    }
}
