//
//  SaintsMenuView.swift
//  Klimax
//

import SwiftUI
import UIKit

struct SaintsMenuView: View {
    let virtue: Virtue
    private var saints: [Saint] { Saint.all(for: virtue) }

    private var featured: Saint? { saints.first }
    private var rest: [Saint] { Array(saints.dropFirst()) }

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 7) {
                    Text(virtue.subtitle)
                        .font(.system(size: 12, weight: .semibold)).tracking(4)
                        .foregroundStyle(Paper.gold)
                    Text(virtue.title)
                        .font(.system(size: 34, weight: .regular, design: .serif))
                        .foregroundStyle(Paper.ink)
                }
                .padding(.horizontal, 24)
                .padding(.top, 6)

                if let featured, let teaching = featured.teachings.first {
                    sectionLabel("CONTINUE")
                    NavigationLink(value: TeachingRoute(saint: featured, teaching: teaching)) {
                        FeaturedCard(saint: featured, teaching: teaching)
                    }
                    .buttonStyle(CalmCardStyle())
                    .padding(.horizontal, 20)
                }

                sectionLabel("THE SAINTS")
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(rest) { saint in
                        NavigationLink(value: saint) {
                            SaintTile(saint: saint)
                        }
                        .buttonStyle(CalmCardStyle())
                    }
                }
                .padding(.horizontal, 20)

                Spacer(minLength: 28)
            }
            .padding(.top, 10)
        }
        .background(Paper.bg.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold)).tracking(2)
            .foregroundStyle(Paper.inkMute)
            .padding(.horizontal, 24)
    }
}

// MARK: - Featured (square image left, info right)

private struct FeaturedCard: View {
    let saint: Saint
    let teaching: Teaching

    private var side: CGFloat { UIScreen.main.bounds.width * 0.52 }

    var body: some View {
        HStack(spacing: 0) {
            SaintPortrait(saint: saint)
                .frame(width: side, height: side)
                .clipped()

            VStack(alignment: .leading, spacing: 6) {
                Text("CONTINUE")
                    .font(.system(size: 10, weight: .semibold)).tracking(2)
                    .foregroundStyle(Paper.gold)
                Text(teaching.title)
                    .font(.system(size: 19, weight: .regular, design: .serif))
                    .foregroundStyle(Paper.ink)
                    .lineLimit(3)
                    .minimumScaleFactor(0.8)
                    .fixedSize(horizontal: false, vertical: true)
                Text(saint.name)
                    .font(.system(size: 13))
                    .foregroundStyle(Paper.inkMute)
                    .lineLimit(2)
                Spacer(minLength: 0)
                Text(teaching.source)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Paper.inkMute.opacity(0.8))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
        }
        .frame(height: side)
        .frame(maxWidth: .infinity)
        .background(Paper.card)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Paper.hairline, lineWidth: 1))
        .shadow(color: .black.opacity(0.06), radius: 14, x: 0, y: 8)
    }
}

// MARK: - Saint tile (square)

private struct SaintTile: View {
    let saint: Saint

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.clear)
                .aspectRatio(1.0, contentMode: .fit)
                .overlay { SaintPortrait(saint: saint) }
                .clipped()

            VStack(alignment: .leading, spacing: 3) {
                Text(saint.name)
                    .font(.system(size: 15, weight: .regular, design: .serif))
                    .foregroundStyle(Paper.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .fixedSize(horizontal: false, vertical: true)
                Text(saint.epithet)
                    .font(.system(size: 11))
                    .foregroundStyle(Paper.inkMute)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Text("\(saint.teachings.count) teachings")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Paper.gold.opacity(0.95))
                    .padding(.top, 1)
            }
            .frame(maxWidth: .infinity, minHeight: 78, alignment: .topLeading)
            .padding(.horizontal, 13)
            .padding(.vertical, 12)
        }
        .background(Paper.card)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Paper.hairline, lineWidth: 1))
        .shadow(color: .black.opacity(0.05), radius: 12, x: 0, y: 6)
    }
}

// MARK: - Shared portrait (real image if present, else illuminated initial)

private struct SaintPortrait: View {
    let saint: Saint

    var body: some View {
        if let ui = UIImage(named: "saint_\(saint.id)") {
            Image(uiImage: ui).resizable().scaledToFill()
        } else {
            GeometryReader { geo in
                ZStack {
                    LinearGradient(
                        colors: [Color(red: 0.953, green: 0.914, blue: 0.820),
                                 Color(red: 0.878, green: 0.788, blue: 0.596)],
                        startPoint: .top, endPoint: .bottom)
                    Text(monogram(saint))
                        .font(.system(size: min(geo.size.width, geo.size.height) * 0.42,
                                      weight: .regular, design: .serif))
                        .foregroundStyle(Gild.goldRing.opacity(0.9))
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
    }
}

private func monogram(_ saint: Saint) -> String {
    let name = saint.name
    let abba = "Ἀββᾶς "
    if name.hasPrefix(abba), let c = name.dropFirst(abba.count).first { return String(c) }
    if let firstWord = name.split(separator: " ").first, let c = firstWord.first { return String(c) }
    return String(name.first ?? "·")
}
