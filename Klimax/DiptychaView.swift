import SwiftUI
import UniformTypeIdentifiers

struct DiptychaView: View {
    let document: DeisisDocument

    @Environment(DiptychaStore.self) private var store
    @State private var editor: DiptychaEditorContext?
    @State private var draggedEntryID: UUID?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                intro

                ForEach(DiptychaCategory.allCases) { category in
                    categorySection(category)
                }

                Spacer(minLength: 28)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
        }
        .background(Paper.bg.ignoresSafeArea())
        .navigationTitle("Δίπτυχα")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    editor = .new(category: .zontes)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundStyle(Paper.gold)
                        .frame(width: 38, height: 38)
                        .contentShape(Circle())
                        .glassChrome(in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Προσθήκη ονόματος")
            }
        }
        .sheet(item: $editor) { context in
            DiptychaEditorView(document: document, context: context) { name, category, note, grammar in
                switch context {
                case .new:
                    store.add(name: name, category: category, note: note, prayerGrammar: grammar)
                case .edit(let entry):
                    store.update(entry, name: name, category: category, note: note, prayerGrammar: grammar)
                }
                editor = nil
            }
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(document.title)
                .font(.custom("GFSDidot-Regular", size: 30))
                .foregroundStyle(Paper.ink)
            Text("Τα ονόματα μένουν μόνο στη συσκευή σου και μπορούν να ενσωματώνονται στην προσευχή.")
                .font(.custom("GentiumBookPlus-Italic", size: 14))
                .foregroundStyle(Paper.inkMute)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.bottom, 4)
    }

    @ViewBuilder
    private func categorySection(_ category: DiptychaCategory) -> some View {
        let entries = store.entries(in: category)
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 10) {
                Text(label(for: category))
                    .font(.custom("GFSDidot-Regular", size: 23))
                    .foregroundStyle(Paper.ink)

                Spacer()

                Button {
                    editor = .new(category: category)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(Paper.gold)
                        .frame(width: 34, height: 34)
                        .contentShape(Circle())
                        .glassChrome(in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Προσθήκη στην κατηγορία \(label(for: category))")
            }

            if entries.isEmpty {
                Text("Κανένα όνομα ακόμη.")
                    .font(.custom("GentiumBookPlus-Italic", size: 15))
                    .foregroundStyle(Paper.inkMute)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 18)
                    .background(Paper.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            } else {
                VStack(spacing: 8) {
                    ForEach(entries) { entry in
                        DiptychaSwipeRow(entry: entry) {
                            editor = .edit(entry)
                        } onDelete: {
                            store.delete(entry)
                        }
                        .onDrag {
                            draggedEntryID = entry.id
                            return NSItemProvider(object: entry.id.uuidString as NSString)
                        }
                        .onDrop(
                            of: [UTType.text],
                            delegate: DiptychaDropDelegate(
                                target: entry,
                                category: category,
                                draggedEntryID: $draggedEntryID,
                                store: store
                            )
                        )
                    }
                }
            }
        }
    }

    private func label(for category: DiptychaCategory) -> String {
        document.nameFormulas[category.rawValue]?.label ?? category.rawValue
    }
}

private enum DiptychaEditorContext: Identifiable {
    case new(category: DiptychaCategory)
    case edit(DiptychaEntry)

    var id: String {
        switch self {
        case .new(let category): return "new.\(category.rawValue)"
        case .edit(let entry): return entry.id.uuidString
        }
    }

    var entry: DiptychaEntry? {
        if case .edit(let entry) = self { return entry }
        return nil
    }

    var initialCategory: DiptychaCategory {
        switch self {
        case .new(let category): return category
        case .edit(let entry): return entry.category
        }
    }
}

private struct DiptychaEditorView: View {
    let document: DeisisDocument
    let context: DiptychaEditorContext
    let onSave: (String, DiptychaCategory, String?, PrayerNameGrammar?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var category: DiptychaCategory
    @State private var note: String
    @State private var grammarGender: PrayerNameGrammar.Gender?
    @State private var accusative: String
    @State private var genitive: String
    @State private var grammarConfirmed: Bool
    @FocusState private var nameFocused: Bool

    init(
        document: DeisisDocument,
        context: DiptychaEditorContext,
        onSave: @escaping (String, DiptychaCategory, String?, PrayerNameGrammar?) -> Void
    ) {
        self.document = document
        self.context = context
        self.onSave = onSave
        _name = State(initialValue: context.entry?.name ?? "")
        _category = State(initialValue: context.initialCategory)
        _note = State(initialValue: context.entry?.note ?? "")
        _grammarGender = State(initialValue: context.entry?.prayerGrammar?.gender)
        _accusative = State(initialValue: context.entry?.prayerGrammar?.accusative ?? "")
        _genitive = State(initialValue: context.entry?.prayerGrammar?.genitive ?? "")
        _grammarConfirmed = State(initialValue: context.entry?.prayerGrammar?.isValid == true)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    fieldTitle("Όνομα")
                    VStack(alignment: .trailing, spacing: 6) {
                        TextField("Όνομα", text: Binding(
                            get: { name },
                            set: { name = String($0.prefix(40)) }
                        ))
                        .font(.custom("Gentium Book Plus", size: 19))
                        .foregroundStyle(Paper.ink)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled(false)
                        .focused($nameFocused)
                        .padding(.horizontal, 15)
                        .frame(height: 52)
                        .background(Paper.card, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 17, style: .continuous)
                                .stroke(Paper.hairline, lineWidth: 1)
                        )

                        Text("\(name.count) / 40")
                            .font(.system(size: 11, weight: .heavy))
                            .foregroundStyle(Paper.inkMute)
                    }

                    fieldTitle("Κατηγορία")
                    Picker("Κατηγορία", selection: $category) {
                        ForEach(DiptychaCategory.allCases) { option in
                            Text(label(for: option)).tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                    .font(.system(size: 15, weight: .heavy))
                    .tint(Paper.gold)
                    .padding(.horizontal, 15)
                    .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                    .background(Paper.card, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 17, style: .continuous)
                            .stroke(Paper.hairline, lineWidth: 1)
                    )

                    prayerGrammarEditor

                    fieldTitle("Σημείωση")
                    TextEditor(text: $note)
                        .font(.custom("Gentium Book Plus", size: 17))
                        .foregroundStyle(Paper.ink)
                        .scrollContentBackground(.hidden)
                        .padding(10)
                        .frame(minHeight: 120)
                        .background(Paper.card, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 17, style: .continuous)
                                .stroke(Paper.hairline, lineWidth: 1)
                        )
                }
                .padding(20)
            }
            .background(Paper.bg.ignoresSafeArea())
            .navigationTitle(context.entry == nil ? "Νέο όνομα" : "Επεξεργασία")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Άκυρο") { dismiss() }
                        .font(.system(size: 15, weight: .heavy))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Αποθήκευση") {
                        onSave(name, category, note, confirmedGrammar)
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .heavy))
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear { nameFocused = context.entry == nil }
            .onChange(of: name) { _, _ in grammarConfirmed = false }
            .onChange(of: grammarGender) { _, _ in grammarConfirmed = false }
            .onChange(of: accusative) { _, _ in grammarConfirmed = false }
            .onChange(of: genitive) { _, _ in grammarConfirmed = false }
        }
        .presentationBackground(.ultraThinMaterial)
    }

    private var confirmedGrammar: PrayerNameGrammar? {
        guard grammarConfirmed, let gender = grammarGender else { return nil }
        let value = PrayerNameGrammar(gender: gender,
            accusative: accusative.trimmingCharacters(in: .whitespacesAndNewlines),
            genitive: genitive.trimmingCharacters(in: .whitespacesAndNewlines))
        return value.isValid ? value : nil
    }

    private var prayerGrammarEditor: some View {
        DisclosureGroup("Κλίση ονόματος για το κομποσχοίνι") {
            VStack(alignment: .leading, spacing: 14) {
                Text("Προαιρετικό για τα Δίπτυχα. Απαιτείται για την προσωπική ευχή στο κομποσχοίνι. Δεν μαντεύουμε τις καταλήξεις.")
                    .font(.footnote).foregroundStyle(Paper.inkMute)
                Picker("Γραμματικό γένος", selection: $grammarGender) {
                    Text("Επίλεξε").tag(nil as PrayerNameGrammar.Gender?)
                    Text("Αρσενικό").tag(PrayerNameGrammar.Gender?.some(.masculine))
                    Text("Θηλυκό").tag(PrayerNameGrammar.Gender?.some(.feminine))
                }
                VStack(alignment: .leading) {
                    Text("Αιτιατική · π.χ. Γεώργιο / Μαρία").font(.caption)
                    TextField("Αιτιατική", text: $accusative).textFieldStyle(.roundedBorder)
                }
                VStack(alignment: .leading) {
                    Text("Γενική · π.χ. Γεωργίου / Μαρίας").font(.caption)
                    TextField("Γενική", text: $genitive).textFieldStyle(.roundedBorder)
                }
                Toggle("Επιβεβαιώνω το γένος και τις σωστές κλίσεις του ονόματος.", isOn: $grammarConfirmed)
                    .font(.footnote)
                    .disabled(grammarGender == nil || accusative.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || genitive.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }.padding(.top, 12)
        }.tint(Paper.gold)
    }

    private func fieldTitle(_ value: String) -> some View {
        Text(value)
            .font(.system(size: 13, weight: .heavy))
            .foregroundStyle(Paper.inkSoft)
    }

    private func label(for category: DiptychaCategory) -> String {
        document.nameFormulas[category.rawValue]?.label ?? category.rawValue
    }
}

private struct DiptychaSwipeRow: View {
    let entry: DiptychaEntry
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var restingOffset: CGFloat = 0
    @GestureState private var dragOffset: CGFloat = 0

    private let deleteWidth: CGFloat = 76

    var body: some View {
        ZStack(alignment: .trailing) {
            Button(action: onDelete) {
                Image(systemName: "trash.fill")
                    .font(.system(size: 17, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(width: deleteWidth)
                    .frame(maxHeight: .infinity)
                    .background(Color.red.opacity(0.88))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Διαγραφή")

            HStack(spacing: 12) {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(Paper.gold.opacity(0.72))

                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.name)
                        .font(.custom("Gentium Book Plus", size: 18))
                        .foregroundStyle(Paper.ink)
                    if let note = entry.note, !note.isEmpty {
                        Text(note)
                            .font(.custom("GentiumBookPlus-Italic", size: 13))
                            .foregroundStyle(Paper.inkMute)
                            .lineLimit(1)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(Paper.inkMute.opacity(0.6))
            }
            .padding(.horizontal, 15)
            .frame(minHeight: 58)
            .background(Paper.card)
            .contentShape(Rectangle())
            .offset(x: max(-deleteWidth, min(0, restingOffset + dragOffset)))
            .onTapGesture {
                if restingOffset == 0 { onEdit() }
                else { withAnimation(.snappy) { restingOffset = 0 } }
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 14)
                    .updating($dragOffset) { value, state, _ in
                        guard abs(value.translation.width) > abs(value.translation.height) else { return }
                        state = value.translation.width
                    }
                    .onEnded { value in
                        guard abs(value.translation.width) > abs(value.translation.height) else { return }
                        withAnimation(.snappy) {
                            restingOffset = value.translation.width < -34 ? -deleteWidth : 0
                        }
                    }
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .stroke(Paper.hairline, lineWidth: 1)
                .allowsHitTesting(false)
        )
    }
}

private struct DiptychaDropDelegate: DropDelegate {
    let target: DiptychaEntry
    let category: DiptychaCategory
    @Binding var draggedEntryID: UUID?
    let store: DiptychaStore

    func dropEntered(info: DropInfo) {
        guard let movingID = draggedEntryID else { return }
        store.move(movingID, before: target.id, in: category)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedEntryID = nil
        return true
    }
}
