//
//  TodayPagerView.swift
//  Klimax
//
//  Wraps TodayView and ChurchMapView in a horizontal pager. Today is the
//  default page; swipe right reveals the church map, which sits on the
//  leading side. The map carries its own back button because MapKit's own
//  pan gesture competes with the page swipe once you're touching the map,
//  so swipe alone isn't a reliable way back.
//

import SwiftUI

struct TodayPagerView: View {
    @State private var selectedPage = 1

    var body: some View {
        TabView(selection: $selectedPage) {
            ChurchMapView()
                .tag(0)

            TodayView()
                .tag(1)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .overlay(alignment: .leading) {
            if selectedPage == 1 {
                hint
            }
        }
        .overlay(alignment: .topLeading) {
            if selectedPage == 0 {
                backButton
            }
        }
    }

    private var hint: some View {
        Image(systemName: "mappin.circle.fill")
            .font(.system(size: 18))
            .foregroundStyle(Paper.inkMute)
            .padding(10)
            .background(Paper.bg, in: Circle())
            .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
            .padding(.leading, 6)
            .allowsHitTesting(false)
    }

    private var backButton: some View {
        Button {
            withAnimation { selectedPage = 1 }
        } label: {
            Image(systemName: "chevron.left")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Paper.ink)
                .padding(10)
                .background(Paper.bg, in: Circle())
                .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
        }
        .padding(.top, 8)
        .padding(.leading, 16)
    }
}
