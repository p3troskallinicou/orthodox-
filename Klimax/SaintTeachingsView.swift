//
//  SaintTeachingsView.swift
//  Klimax
//
//  One saint's teachings as a quiet numbered list. Tapping a teaching opens it
//  in the reading surface.
//

import SwiftUI

struct SaintTeachingsView: View {
    let saint: Saint

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 7) {
                    Text(saint.epithet.uppercased())
                        .font(.system(size: 11, weight: .semibold)).tracking(3)
                        .foregroundStyle(Paper.gold)
                    Text(saint.name)
                        .font(.system(size: 30, weight: .regular, design: .serif))
                        .foregroundStyle(Paper.ink)
                }
                .padding(.horizontal, 24)
                .padding(.top, 6)

                VStack(spacing: 14) {
                    ForEach(Array(saint.teachings.enumerated()), id: \.element.id) { index, teaching in
                        NavigationLink(value: TeachingRoute(saint: saint, teaching: teaching)) {
                            HStack(spacing: 16) {
                                Text("\(index + 1)")
                                    .font(.system(size: 18, weight: .regular, design: .serif))
                                    .foregroundStyle(Paper.gold)
                                    .frame(width: 30)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(teaching.title)
                                        .font(.system(size: 19, weight: .regular, design: .serif))
                                        .foregroundStyle(Paper.ink)
                                    Text(teaching.source)
                                        .font(.system(size: 12))
                                        .foregroundStyle(Paper.inkMute)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Paper.inkMute.opacity(0.5))
                            }
                            .padding(16)
                            .background(Paper.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(Paper.hairline, lineWidth: 1))
                            .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 5)
                        }
                        .buttonStyle(CalmCardStyle())
                    }
                }
                .padding(.horizontal, 20)

                Spacer(minLength: 28)
            }
            .padding(.top, 8)
        }
        .background(Paper.bg.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }
}
