//
//  VirtueLibraryView.swift
//  Klimax
//
//  The virtues, as soft cards, listed in the order of the Ladder (ascending —
//  from the first struggles toward Love at the summit). The title now lives in
//  LadderView (above the Ἀρετές/Ἅγιοι toggle), so this view is just the list.
//  Humility is active and in progress; the rest wait.
//

import SwiftUI

struct VirtueLibraryView: View {
    private let virtues = Virtue.all

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                ForEach(virtues) { virtue in
                    if virtue.isAvailable {
                        NavigationLink(value: virtue) { VirtueCard(virtue: virtue) }
                            .buttonStyle(CalmCardStyle())
                    } else {
                        VirtueCard(virtue: virtue).opacity(0.6)
                    }
                }
                Spacer(minLength: 28)
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
        }
        .background(Paper.bg.ignoresSafeArea())
    }
}

private struct VirtueCard: View {
    let virtue: Virtue
    private var inProgress: Bool { virtue.isAvailable && virtue.completed > 0 }

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().fill(Paper.gold.opacity(virtue.isAvailable ? 0.14 : 0.07))
                Image(systemName: virtue.icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(virtue.isAvailable ? Paper.gold : Paper.inkMute)
            }
            .frame(width: 50, height: 50)

            VStack(alignment: .leading, spacing: 4) {
                Text(virtue.title)
                    .font(.system(size: 21, weight: .regular, design: .serif))
                    .foregroundStyle(Paper.ink)
                Text(virtue.subtitle)
                    .font(.system(size: 11, weight: .semibold)).tracking(1.5)
                    .foregroundStyle(Paper.inkMute)

                if inProgress {
                    ProgressBar(fraction: Double(virtue.completed) / Double(max(virtue.total, 1)))
                        .frame(height: 4).padding(.top, 5)
                    Text("\(virtue.completed) of \(virtue.total)")
                        .font(.system(size: 11)).foregroundStyle(Paper.inkMute).padding(.top, 2)
                }
            }

            Spacer()

            if virtue.isAvailable {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Paper.inkMute.opacity(0.55))
            } else {
                Text("SOON")
                    .font(.system(size: 10, weight: .semibold)).tracking(1)
                    .foregroundStyle(Paper.inkMute.opacity(0.7))
            }
        }
        .padding(16)
        .background(Paper.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
            .stroke(inProgress ? Paper.gold.opacity(0.35) : Paper.hairline, lineWidth: 1))
        .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 5)
    }
}
