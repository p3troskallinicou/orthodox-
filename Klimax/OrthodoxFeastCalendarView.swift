//
//  OrthodoxFeastCalendarView.swift
//  Klimax
//
//  Ελληνορθόδοξο Εορτολόγιο. Tapping a day shows its commemorations; each
//  commemoration that is a catalogued saint (feast.saintId != nil) is now
//  tappable and opens the saint's page (Βίος / Ἀπολυτίκιον) in a self-contained
//  sheet — so the eortologio links straight into the Ἅγιοι catalogue without
//  having to live inside its NavigationStack.
//

import SwiftUI

struct OrthodoxFeastCalendarView: View {
    let service: OrthodoxFeastCalendarService
    @State private var displayedMonth = CalendarMonthLayout.start(of: Date(), calendar: OrthodoxFeastCalendarService.calendar)
    @State private var selectedDate = OrthodoxFeastCalendarService.calendar.startOfDay(for: Date())
    private var selectedDay: OrthodoxCalendarDay? { service.day(for: selectedDate) }
    @State private var query = ""
    @State private var showsSearch = false

    // Own copy of the saints catalogue, only for resolving a day's saintId to a
    // SaintEntry and opening its page. Loads Sanity→cache→bundle like elsewhere.
    @State private var saintsStore = SaintsStore.shared
    @State private var selectedSaint: SaintEntry?

    var body: some View {
        Group {
            if !service.isLoaded {
                ProgressView().tint(Paper.gold)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 24) {
                        Group {
                            LiturgicalMonthCalendar(month: $displayedMonth, selected: $selectedDate, calendar: OrthodoxFeastCalendarService.calendar) { date in
                                guard let day = service.day(for: date) else { return [] }
                                var marks: [CalendarDayIndicator] = []
                                if day.majorFeast != nil {
                                    marks.append(CalendarDayIndicator(color: Paper.gold, label: "Εορτή / μνήμη"))
                                }
                                if day.feasts.contains(where: { !$0.namesCelebrated.isEmpty }) {
                                    marks.append(CalendarDayIndicator(color: .teal, label: "Ονομαστικές γιορτές"))
                                }
                                return marks
                            }
                            if let selectedDay { dayDetails(selectedDay) }
                            HStack(spacing: 18) {
                                Label {
                                    Text("Εορτή / μνήμη")
                                } icon: {
                                    Circle().fill(Paper.gold).frame(width: 5, height: 5)
                                }
                                Label {
                                    Text("Ονομαστικές γιορτές")
                                } icon: {
                                    Circle().fill(.teal).frame(width: 5, height: 5)
                                }
                            }
                            .font(.caption).foregroundStyle(Paper.inkSoft)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 32)
                    .frame(maxWidth: 680).frame(maxWidth: .infinity)
                }
            }
        }
        .modifier(CalendarScreenStyle(title: "Εορτολόγιο"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showsSearch = true } label: { Image(systemName: "magnifyingglass") }
                    .accessibilityLabel("Αναζήτηση γιορτής ή αγίου")
            }
            ToolbarItem(placement: .topBarTrailing) {
                CalendarTodayButton(month: $displayedMonth, selected: $selectedDate, calendar: OrthodoxFeastCalendarService.calendar)
            }
        }
        .task { await service.loadCalendar() }
        .task { await saintsStore.load() }
        .sheet(isPresented: $showsSearch, onDismiss: { query = "" }) {
            NavigationStack {
                ScrollView {
                    feastSearchResults.padding(20)
                }
                .modifier(CalendarScreenStyle(title: "Αναζήτηση"))
                .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always),
                            prompt: "Γιορτή ή άγιος")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Κλείσιμο") { showsSearch = false }
                    }
                }
            }
        }
        // Self-contained saint page. Its own NavigationStack so the title bar and
        // the close button render correctly regardless of where the calendar sits.
        .sheet(item: $selectedSaint) { saint in
            NavigationStack {
                SaintDetailView(saint: saint)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Κλείσιμο") { selectedSaint = nil }
                                .foregroundStyle(Paper.gold)
                        }
                    }
            }
        }
    }

    private var feastSearchResults: some View {
        let results = service.searchFeasts(query)
        let isEmptyQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return VStack(alignment: .leading, spacing: 10) {
            Text(isEmptyQuery ? "ΑΝΑΖΗΤΗΣΗ" : "ΑΠΟΤΕΛΕΣΜΑΤΑ")
                .font(.system(size: 10, weight: .semibold)).tracking(2.5)
                .foregroundStyle(Paper.gold)
                .padding(.horizontal, 4)

            if results.isEmpty {
                VStack(spacing: 9) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(Paper.gold.opacity(0.9))
                    Text(isEmptyQuery ? "Βρες μια γιορτή" : "Δεν βρέθηκε γιορτή")
                        .font(.system(size: 18, weight: .regular, design: .serif))
                        .foregroundStyle(Paper.ink)
                    Text(isEmptyQuery ? "Πληκτρολόγησε μια γιορτή ή το όνομα ενός αγίου." : "Δοκίμασε με λιγότερες λέξεις ή χωρίς τόνους.")
                        .font(.system(size: 12))
                        .foregroundStyle(Paper.inkMute)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
                .background(Paper.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(Paper.hairline, lineWidth: 1))
            } else {
                ForEach(results) { day in
                    Button {
                        if let date = service.date(for: day) {
                            displayedMonth = CalendarMonthLayout.start(of: date, calendar: OrthodoxFeastCalendarService.calendar)
                            selectedDate = date
                        }
                        query = ""
                        showsSearch = false
                    } label: {
                        feastSearchRow(day)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func feastSearchRow(_ day: OrthodoxCalendarDay) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(detailDate(day))
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(Paper.gold)
            Text(day.feasts.prefix(2).map(\.title).joined(separator: ", "))
                .font(.system(size: 18, weight: .regular, design: .serif))
                .foregroundStyle(Paper.ink)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            if let names = day.feasts.first(where: { !$0.namesCelebrated.isEmpty })?.namesCelebrated, !names.isEmpty {
                Text("Εορτάζουν: \(names.prefix(6).joined(separator: ", "))")
                    .font(.system(size: 12))
                    .foregroundStyle(Paper.inkMute)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Paper.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Paper.hairline, lineWidth: 1))
    }

    private func dayDetails(_ day: OrthodoxCalendarDay) -> some View {
        CalendarDayAgenda(date: selectedDate, calendar: OrthodoxFeastCalendarService.calendar) {
            if day.feasts.isEmpty {
                Text("Δεν υπάρχουν ακόμη καταχωρισμένες μνήμες για αυτή την ημέρα.")
                    .font(.subheadline).foregroundStyle(Paper.inkSoft)
            } else {
                ForEach(day.feasts) { feast in
                    CalendarAgendaRow(tint: feast.namesCelebrated.isEmpty ? Paper.gold : .teal) {
                        if let saint = resolvedSaint(for: feast) {
                            Button { selectedSaint = saint } label: {
                                feastBlock(feast, tappable: true)
                            }.buttonStyle(.plain)
                        } else {
                            feastBlock(feast, tappable: false)
                        }
                    }
                    if feast.id != day.feasts.last?.id {
                        Divider().overlay(Paper.hairline).padding(.leading, 61)
                    }
                }
            }
        }
    }

    // A single commemoration row. `tappable` adds a discreet gold chevron so the
    // reader knows the saint's page can be opened.
    @ViewBuilder private func feastBlock(_ feast: OrthodoxFeast, tappable: Bool) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Text(feast.title.interfaceGreek).font(.system(size: 17, weight: .semibold)).foregroundStyle(Paper.ink)
                    .multilineTextAlignment(.leading)
                Spacer()
                if tappable {
                    Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Paper.gold.opacity(0.7))
                } else {
                    Text(feast.kind == .movable ? "ΚΙΝΗΤΗ" : "ΣΤΑΘΕΡΗ")
                        .font(.system(size: 9, weight: .bold)).tracking(1).foregroundStyle(Paper.gold)
                }
            }
            if let category = feast.category, !category.isEmpty {
                Text(category.interfaceGreek).font(.system(size: 12, weight: .semibold)).foregroundStyle(Paper.inkMute)
            }
            if let description = feast.description {
                Text(description).font(.subheadline).foregroundStyle(Paper.inkMute)
                    .multilineTextAlignment(.leading)
            }
            if !feast.namesCelebrated.isEmpty {
                Text("Εορτάζουν: \(feast.namesCelebrated.joined(separator: ", "))")
                    .font(.system(size: 13)).foregroundStyle(Paper.inkMute)
                    .multilineTextAlignment(.leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    // Resolve a feast to a catalogued saint, if it carries a saintId and the
    // catalogue is loaded. nil → the row stays non-tappable.
    private func resolvedSaint(for feast: OrthodoxFeast) -> SaintEntry? {
        guard let id = feast.saintId, !id.isEmpty else { return nil }
        return saintsStore.saint(byId: id)
    }

    private func detailDate(_ day: OrthodoxCalendarDay) -> String {
        guard let date = service.date(for: day) else { return day.date }
        return CalendarMonthLayout.label(date, format: "EEEE, d MMMM yyyy", calendar: OrthodoxFeastCalendarService.calendar).capitalized
    }
}
