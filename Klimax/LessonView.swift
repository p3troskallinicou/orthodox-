//
//  LessonView.swift
//  Klimax
//
//  The reading surface for a single teaching from the Fathers. A calm serif
//  column; the read → reflect flow grows here later.
//

import SwiftUI

struct LessonView: View {
    let teaching: Teaching
    let saint: Saint

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 7) {
                    Text(teaching.subtitle)
                        .font(.system(size: 11, weight: .semibold)).tracking(3)
                        .foregroundStyle(Paper.gold)
                    Text(teaching.title)
                        .font(.system(size: 30, weight: .regular, design: .serif))
                        .foregroundStyle(Paper.ink)
                    Text("\(saint.name) · \(teaching.source)")
                        .font(.system(size: 13))
                        .foregroundStyle(Paper.inkMute)
                }
                .padding(.top, 10)

                Divider().overlay(Paper.hairline)

                Text(teaching.body)
                    .font(.system(size: 20, weight: .regular, design: .serif))
                    .foregroundStyle(Paper.ink)
                    .lineSpacing(7)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 28)
            .padding(.top, 8)
            .padding(.bottom, 48)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Paper.bg.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }
}
