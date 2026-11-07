import ActivityKit
import Foundation

struct ScriptureLearningAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var currentStep: Int
        var totalSteps: Int
        var mood: ScriptureMascotMood
        var message: String
        var isComplete: Bool
    }

    var lessonID: String
    var lessonTitle: String
    var unitTitle: String
}

#if WIDGET_EXTENSION
import SwiftUI
import WidgetKit

private let scriptureWine = Color(red: 63.0 / 255.0, green: 1.0 / 255.0, blue: 18.0 / 255.0)
private let scriptureParchment = Color(red: 0.97, green: 0.94, blue: 0.87)

private struct ScriptureMascotImage: View {
    let mood: ScriptureMascotMood
    let size: CGFloat

    var body: some View {
        Image(mood.assetName)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

// MARK: Home Screen + Lock Screen widget

private struct ScriptureJourneyEntry: TimelineEntry {
    let date: Date
    let info: ScriptureJourneyWidgetInfo
}

private struct ScriptureJourneyProvider: TimelineProvider {
    func placeholder(in context: Context) -> ScriptureJourneyEntry {
        .init(date: Date(), info: .sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (ScriptureJourneyEntry) -> Void) {
        completion(.init(date: Date(), info: WidgetSharedStore.load().scriptureJourney ?? .sample))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ScriptureJourneyEntry>) -> Void) {
        let entry = ScriptureJourneyEntry(
            date: Date(),
            info: WidgetSharedStore.load().scriptureJourney ?? .sample
        )
        completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(30 * 60))))
    }
}

private struct ScriptureJourneyWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: ScriptureJourneyEntry

    var body: some View {
        Group {
            switch family {
            case .accessoryInline:
                Text("Βιβλικὴ Πορεία · \(entry.info.lessonTitle)")
            case .accessoryCircular:
                ZStack {
                    AccessoryWidgetBackground()
                    ScriptureMascotImage(mood: entry.info.mood, size: 47)
                }
            case .accessoryRectangular:
                HStack(spacing: 7) {
                    ScriptureMascotImage(mood: entry.info.mood, size: 47)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.info.unitTitle.uppercased())
                            .font(.system(size: 9, weight: .bold))
                        Text(entry.info.message)
                            .font(.system(size: 11, weight: .semibold, design: .serif))
                            .lineLimit(2)
                    }
                }
            case .systemSmall:
                smallView
            default:
                wideView
            }
        }
        .widgetURL(URL(string: "klimax://widget/bibleJourney"))
    }

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("ΒΙΒΛΙΚΗ ΠΟΡΕΙΑ")
                        .font(.system(size: 9, weight: .black))
                        .tracking(1.1)
                        .foregroundStyle(scriptureWine)
                    Text(entry.info.unitTitle)
                        .font(.system(size: 17, weight: .bold, design: .serif))
                        .foregroundStyle(.primary)
                }
                Spacer(minLength: 0)
                Text("\(entry.info.completedLessons)/\(entry.info.totalLessons)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            ScriptureMascotImage(mood: entry.info.mood, size: 78)
                .frame(maxWidth: .infinity)

            Text(entry.info.message)
                .font(.system(size: 11, weight: .semibold, design: .serif))
                .foregroundStyle(.primary.opacity(0.78))
                .lineLimit(2)
        }
        .padding(14)
    }

    private var wideView: some View {
        HStack(spacing: 16) {
            ScriptureMascotImage(mood: entry.info.mood, size: family == .systemLarge ? 150 : 104)

            VStack(alignment: .leading, spacing: 7) {
                Text("ΒΙΒΛΙΚΗ ΠΟΡΕΙΑ · \(entry.info.unitTitle.uppercased())")
                    .font(.system(size: 9, weight: .black))
                    .tracking(1.1)
                    .foregroundStyle(scriptureWine)
                Text(entry.info.lessonTitle)
                    .font(.system(size: family == .systemLarge ? 24 : 19, weight: .bold, design: .serif))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                Text(entry.info.message)
                    .font(.system(size: 13, weight: .medium, design: .serif))
                    .foregroundStyle(.secondary)
                    .lineLimit(family == .systemLarge ? 3 : 2)
                ProgressView(value: entry.info.progress)
                    .tint(scriptureWine)
                if family == .systemLarge {
                    Label("\(entry.info.streak) ἡμέρες συνέπειας", systemImage: "flame.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(scriptureWine)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(family == .systemLarge ? 20 : 16)
    }
}

struct ScriptureJourneyWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "Klimax.ScriptureJourney", provider: ScriptureJourneyProvider()) { entry in
            ScriptureJourneyWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    LinearGradient(
                        colors: [scriptureParchment, scriptureParchment.opacity(0.88)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
        }
        .configurationDisplayName("Βιβλικὴ Πορεία")
        .description("Τὸ ἐπόμενο μάθημα καὶ ἡ μασκότ τῆς πορείας σου.")
        .supportedFamilies([
            .systemSmall, .systemMedium, .systemLarge,
            .accessoryInline, .accessoryCircular, .accessoryRectangular
        ])
    }
}

// MARK: Live Activity + Dynamic Island

struct ScriptureLearningLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ScriptureLearningAttributes.self) { context in
            HStack(spacing: 14) {
                ScriptureMascotImage(mood: context.state.mood, size: 82)

                VStack(alignment: .leading, spacing: 5) {
                    Text(context.attributes.unitTitle.uppercased())
                        .font(.system(size: 9, weight: .black))
                        .tracking(1.2)
                        .foregroundStyle(scriptureWine)
                    Text(context.attributes.lessonTitle)
                        .font(.system(size: 16, weight: .bold, design: .serif))
                        .lineLimit(1)
                    Text(context.state.message)
                        .font(.system(size: 12, weight: .medium, design: .serif))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    ProgressView(value: progress(context.state))
                        .tint(scriptureWine)
                }
                Spacer(minLength: 0)
            }
            .padding(15)
            .activityBackgroundTint(scriptureParchment)
            .activitySystemActionForegroundColor(scriptureWine)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    ScriptureMascotImage(mood: context.state.mood, size: 56)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(context.state.currentStep)/\(context.state.totalSteps)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(scriptureWine)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.lessonTitle)
                        .font(.system(size: 14, weight: .semibold, design: .serif))
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 5) {
                        ProgressView(value: progress(context.state)).tint(scriptureWine)
                        Text(context.state.message)
                            .font(.system(size: 11, weight: .medium, design: .serif))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            } compactLeading: {
                ScriptureMascotImage(mood: context.state.mood, size: 28)
            } compactTrailing: {
                Text("\(context.state.currentStep)/\(context.state.totalSteps)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
            } minimal: {
                ScriptureMascotImage(mood: context.state.mood, size: 28)
            }
            .widgetURL(URL(string: "klimax://widget/bibleJourney"))
            .keylineTint(scriptureWine)
        }
    }

    private func progress(_ state: ScriptureLearningAttributes.ContentState) -> Double {
        guard state.totalSteps > 0 else { return 0 }
        return min(1, max(0, Double(state.currentStep) / Double(state.totalSteps)))
    }
}
#endif
