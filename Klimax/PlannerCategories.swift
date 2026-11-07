import SwiftUI
import Combine

/// A reusable appearance, independent of a task's recurrence or goal linkage.
struct PlannerCategory: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var symbol: String = "sparkles"
    var emoji: String = ""
    var colorID: String = "burgundy"

    var tint: Color { PlannerPalette.tint(for: colorID) }

    /// Character, rather than Unicode-scalar, truncation preserves joined emoji
    /// such as a family, a flag, or a person with a skin-tone modifier.
    static func singleEmoji(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let character = trimmed.first else { return "" }
        let scalars = character.unicodeScalars
        let isEmoji = scalars.contains { $0.properties.isEmojiPresentation }
            || (scalars.count > 1 && scalars.contains { $0.properties.isEmoji })
        return isEmoji ? String(character) : ""
    }
}

enum PlannerPalette {
    struct Option: Identifiable {
        let id: String
        let name: String
        let tint: Color
    }

    /// Stable IDs are stored; colour values can evolve without breaking saved tasks.
    static let options: [Option] = [
        Option(id: "burgundy", name: "Βυσσινί", tint: .adaptive(
            Color(red: 0.43, green: 0.19, blue: 0.29), Color(red: 0.85, green: 0.51, blue: 0.62))),
        Option(id: "rose", name: "Ροδί", tint: .adaptive(
            Color(red: 0.65, green: 0.34, blue: 0.37), Color(red: 0.92, green: 0.62, blue: 0.63))),
        Option(id: "amber", name: "Κεχριμπαρί", tint: .adaptive(
            Color(red: 0.60, green: 0.40, blue: 0.17), Color(red: 0.89, green: 0.71, blue: 0.43))),
        Option(id: "sage", name: "Φασκόμηλο", tint: .adaptive(
            Color(red: 0.35, green: 0.46, blue: 0.30), Color(red: 0.66, green: 0.77, blue: 0.59))),
        Option(id: "teal", name: "Πετρόλ", tint: .adaptive(
            Color(red: 0.22, green: 0.48, blue: 0.47), Color(red: 0.49, green: 0.76, blue: 0.74))),
        Option(id: "blue", name: "Μπλέ", tint: .adaptive(
            Color(red: 0.29, green: 0.46, blue: 0.64), Color(red: 0.57, green: 0.73, blue: 0.91))),
        Option(id: "lavender", name: "Λεβάντα", tint: .adaptive(
            Color(red: 0.48, green: 0.39, blue: 0.63), Color(red: 0.75, green: 0.66, blue: 0.90))),
        Option(id: "stone", name: "Πέτρα", tint: .adaptive(
            Color(red: 0.46, green: 0.43, blue: 0.39), Color(red: 0.74, green: 0.71, blue: 0.65)))
    ]

    static func tint(for id: String) -> Color {
        options.first(where: { $0.id == id })?.tint ?? options[0].tint
    }
}

@MainActor
final class PlannerCategoryStore: ObservableObject {
    static let shared = PlannerCategoryStore()
    @Published private(set) var categories: [PlannerCategory] = []
    private let defaults: UserDefaults
    private let storageKey = "today.categories.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode([PlannerCategory].self, from: data) {
            categories = saved
        }
    }

    func category(id: UUID?) -> PlannerCategory? {
        guard let id else { return nil }
        return categories.first { $0.id == id }
    }

    func hasDuplicateName(_ name: String, excluding id: UUID? = nil) -> Bool {
        let normalized = Self.normalizedName(name)
        return categories.contains {
            $0.id != id && Self.normalizedName($0.name) == normalized
        }
    }

    /// A single publication per save avoids invalidating the planner repeatedly.
    func save(_ category: PlannerCategory) {
        var sanitized = category
        sanitized.name = category.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sanitized.name.isEmpty, sanitized.name.count <= 40,
              !hasDuplicateName(sanitized.name, excluding: category.id) else { return }
        sanitized.emoji = PlannerCategory.singleEmoji(from: category.emoji)
        if sanitized.symbol.isEmpty { sanitized.symbol = "sparkles" }
        if !PlannerPalette.options.contains(where: { $0.id == sanitized.colorID }) {
            sanitized.colorID = PlannerPalette.options[0].id
        }
        var updated = categories
        if let index = updated.firstIndex(where: { $0.id == sanitized.id }) {
            updated[index] = sanitized
        } else {
            updated.append(sanitized)
        }
        guard let data = try? JSONEncoder().encode(updated) else { return }
        defaults.set(data, forKey: storageKey)
        categories = updated
    }

    private static func normalizedName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
                     locale: Locale(identifier: "el_GR"))
    }
}

/// The caller supplies the font, foreground style, and container dimensions.
struct PlannerCategoryGlyph: View {
    let symbol: String
    let emoji: String

    var body: some View {
        if !emoji.isEmpty {
            Text(emoji)
        } else {
            Image(systemName: symbol.isEmpty ? "sparkles" : symbol)
        }
    }
}

struct PlannerCategoryEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var store = PlannerCategoryStore.shared
    private let categoryID: UUID
    private let isEditing: Bool
    private let embedded: Bool
    private let onSave: (PlannerCategory) -> Void
    @State private var name: String
    @State private var symbol: String
    @State private var emoji: String
    @State private var colorID: String
    @State private var glyphMode: GlyphMode
    @State private var saving = false
    @FocusState private var focusedField: Field?

    private enum Field: Hashable { case name, emoji }
    private enum GlyphMode: String, CaseIterable, Identifiable {
        case symbol, emoji
        var id: Self { self }
        var title: String { self == .symbol ? "Σύμβολο" : "Emoji" }
    }
    private struct SymbolOption: Identifiable {
        let id: String
        let name: String
    }
    private static let symbols: [SymbolOption] = [
        .init(id: "sparkles", name: "Λάμψη"),
        .init(id: "heart.fill", name: "Καρδιά"),
        .init(id: "hands.sparkles.fill", name: "Προσευχή"),
        .init(id: "book.closed.fill", name: "Βιβλίο"),
        .init(id: "leaf.fill", name: "Φύλλο"),
        .init(id: "sun.max.fill", name: "Ήλιος"),
        .init(id: "moon.stars.fill", name: "Νύχτα"),
        .init(id: "building.columns.fill", name: "Εκκλησία"),
        .init(id: "house.fill", name: "Σπίτι"),
        .init(id: "person.2.fill", name: "Άνθρωποι"),
        .init(id: "figure.walk", name: "Περπάτημα"),
        .init(id: "cup.and.saucer.fill", name: "Διάλειμμα"),
        .init(id: "pencil", name: "Γραφή"),
        .init(id: "paintpalette.fill", name: "Δημιουργία"),
        .init(id: "music.note", name: "Μουσική"),
        .init(id: "headphones", name: "Ακρόαση"),
        .init(id: "briefcase.fill", name: "Εργασία"),
        .init(id: "graduationcap.fill", name: "Μάθηση"),
        .init(id: "fork.knife", name: "Φαγητό"),
        .init(id: "drop.fill", name: "Νερό"),
        .init(id: "gift.fill", name: "Δώρο"),
        .init(id: "phone.fill", name: "Τηλέφωνο"),
        .init(id: "pawprint.fill", name: "Ζώα"),
        .init(id: "star.fill", name: "Αστέρι")
    ]
    private let emojiSuggestions = ["🌿", "🙏", "📚", "🏡", "💛", "☕"]

    init(category: PlannerCategory? = nil, embedded: Bool = false,
         onSave: @escaping (PlannerCategory) -> Void) {
        categoryID = category?.id ?? UUID()
        isEditing = category != nil
        self.embedded = embedded
        self.onSave = onSave
        _name = State(initialValue: category?.name ?? "")
        _symbol = State(initialValue: category?.symbol ?? "sparkles")
        _emoji = State(initialValue: category?.emoji ?? "")
        _colorID = State(initialValue: category?.colorID ?? "burgundy")
        _glyphMode = State(initialValue: category?.emoji.isEmpty == false ? .emoji : .symbol)
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var chosenEmoji: String { glyphMode == .emoji ? PlannerCategory.singleEmoji(from: emoji) : "" }
    private var tint: Color { PlannerPalette.tint(for: colorID) }
    private var duplicateName: Bool { store.hasDuplicateName(trimmedName, excluding: categoryID) }
    private var canSave: Bool {
        !saving && !trimmedName.isEmpty && trimmedName.count <= 40 && !duplicateName
            && (glyphMode == .symbol || !chosenEmoji.isEmpty)
    }

    var body: some View {
        if embedded {
            editorContent
        } else {
            NavigationStack { editorContent }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(30)
        }
    }

    private var editorContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                preview
                nameField
                symbolPicker
                colorPicker
                if isEditing {
                    Text("Η αλλαγή θα φανεί σε όλα τα βήματα αυτής της κατηγορίας.")
                        .font(.system(size: 12))
                        .foregroundStyle(Paper.inkMute)
                }
            }
            .padding(20)
        }
        .scrollDismissesKeyboard(.interactively)
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom, spacing: 0) { saveBar }
        .background(AppAtmosphere().ignoresSafeArea())
        .navigationTitle(isEditing ? "Επεξεργασία κατηγορίας" : "Νέα κατηγορία")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 13, weight: .semibold))
                }
                .tint(Paper.inkMute)
                .accessibilityLabel("Κλείσιμο χωρίς αποθήκευση")
            }
        }
    }

    private var preview: some View {
        HStack(spacing: 12) {
            PlannerCategoryGlyph(symbol: symbol, emoji: chosenEmoji)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 40, height: 40)
                .background(Paper.card, in: Circle())
                .overlay(Circle().stroke(tint.opacity(0.25), lineWidth: 1))
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(trimmedName.isEmpty ? "Η ΚΑΤΗΓΟΡΙΑ ΣΟΥ" : trimmedName.uppercased(with: Locale(identifier: "el_GR")))
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.1)
                        .foregroundStyle(tint)
                        .lineLimit(1)
                    Text("Ένα βήμα στην ημέρα σου")
                        .font(.system(size: 16, weight: .semibold, design: .serif))
                        .foregroundStyle(Paper.ink)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
                Image(systemName: "circle")
                    .font(.system(size: 22, weight: .light))
                    .foregroundStyle(tint.opacity(0.5))
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 19)
                    .fill(Paper.card)
                    .overlay {
                        RoundedRectangle(cornerRadius: 19)
                            .fill(LinearGradient(colors: [tint.opacity(0.14), tint.opacity(0.04)],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing))
                    }
            }
            .overlay(RoundedRectangle(cornerRadius: 19).stroke(tint.opacity(0.2), lineWidth: 0.8))
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: colorID)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Προεπισκόπηση: \(trimmedName.isEmpty ? "Νέα κατηγορία" : trimmedName)")
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Όνομα")
            TextField("π.χ. Οικογένεια, Δημιουργία", text: $name)
                .font(.system(size: 17))
                .foregroundStyle(Paper.ink)
                .padding(14)
                .background(Paper.card.opacity(0.9), in: RoundedRectangle(cornerRadius: 15))
                .overlay(RoundedRectangle(cornerRadius: 15).stroke(Paper.hairline, lineWidth: 0.8))
                .focused($focusedField, equals: .name)
                .submitLabel(.done)
                .onSubmit { focusedField = nil }
                .accessibilityLabel("Όνομα κατηγορίας")
                .accessibilityIdentifier("plannerCategory.name")
            if duplicateName && !trimmedName.isEmpty {
                Text("Υπάρχει ήδη κατηγορία με αυτό το όνομα.")
                    .font(.system(size: 12))
                    .foregroundStyle(Paper.gold)
            } else if trimmedName.count > 40 {
                Text("Κράτησε το όνομα έως 40 χαρακτήρες.")
                    .font(.system(size: 12))
                    .foregroundStyle(Paper.gold)
            }
        }
    }

    private var symbolPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionTitle("Εικονίδιο")
                Spacer()
                HStack(spacing: 2) {
                    ForEach(GlyphMode.allCases) { mode in
                        Button {
                            focusedField = nil
                            glyphMode = mode
                        } label: {
                            Text(mode.title)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(glyphMode == mode ? Paper.ink : Paper.inkMute)
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .background(glyphMode == mode ? Paper.card : .clear,
                                            in: RoundedRectangle(cornerRadius: 12))
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(mode.title)
                        .accessibilityAddTraits(glyphMode == mode ? .isSelected : [])
                        .accessibilityIdentifier("plannerCategory.glyphMode.\(mode.rawValue)")
                    }
                }
                .padding(3)
                .background(Paper.hairline, in: RoundedRectangle(cornerRadius: 15))
                .frame(maxWidth: 190)
            }

            if glyphMode == .symbol {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: 8)], spacing: 8) {
                    ForEach(Self.symbols) { option in
                        glyphButton(symbol: option.id, emoji: "", label: option.name,
                                    selected: symbol == option.id) {
                            focusedField = nil
                            symbol = option.id
                        }
                    }
                }
            } else {
                HStack(spacing: 14) {
                    TextField("🌿", text: $emoji)
                        .font(.system(size: 30))
                        .multilineTextAlignment(.center)
                        .frame(width: 66, height: 54)
                        .background(Paper.card, in: RoundedRectangle(cornerRadius: 15))
                        .overlay(RoundedRectangle(cornerRadius: 15).stroke(tint.opacity(0.3), lineWidth: 1))
                        .focused($focusedField, equals: .emoji)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .accessibilityLabel("Το emoji της κατηγορίας")
                        .accessibilityIdentifier("plannerCategory.emoji")
                        .onChange(of: emoji) { _, value in
                            let first = String(value.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1))
                            if first != value { emoji = first }
                        }
                    Text("Διάλεξε ένα emoji από το πληκτρολόγιο ή από τα παρακάτω.")
                        .font(.system(size: 12))
                        .foregroundStyle(Paper.inkMute)
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: 8)], spacing: 8) {
                    ForEach(emojiSuggestions, id: \.self) { suggestion in
                        glyphButton(symbol: "", emoji: suggestion, label: suggestion,
                                    selected: chosenEmoji == suggestion) {
                            focusedField = nil
                            emoji = suggestion
                        }
                    }
                }
                if !emoji.isEmpty && chosenEmoji.isEmpty {
                    Text("Χρησιμοποίησε ένα emoji ή διάλεξε Σύμβολο.")
                        .font(.system(size: 12))
                        .foregroundStyle(Paper.gold)
                }
            }
        }
    }

    private func glyphButton(symbol: String, emoji: String, label: String, selected: Bool,
                             action: @escaping () -> Void) -> some View {
        Button(action: action) {
            PlannerCategoryGlyph(symbol: symbol, emoji: emoji)
                .font(.system(size: emoji.isEmpty ? 20 : 25, weight: .medium))
                .foregroundStyle(selected ? tint : Paper.inkSoft)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(selected ? tint.opacity(0.13) : Paper.card.opacity(0.7),
                            in: RoundedRectangle(cornerRadius: 13))
                .overlay {
                    RoundedRectangle(cornerRadius: 13)
                        .stroke(selected ? tint.opacity(0.7) : Paper.hairline, lineWidth: selected ? 1.5 : 0.7)
                }
                .contentShape(RoundedRectangle(cornerRadius: 13))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var colorPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Χρώμα")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 58), spacing: 8)], spacing: 8) {
                ForEach(PlannerPalette.options) { option in
                    Button {
                        focusedField = nil
                        colorID = option.id
                    } label: {
                        VStack(spacing: 5) {
                            Circle()
                                .fill(option.tint.opacity(0.9))
                                .frame(width: 32, height: 32)
                                .overlay {
                                    if colorID == option.id {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundStyle(Paper.card)
                                    }
                                }
                                .padding(4)
                                .overlay(Circle().stroke(colorID == option.id ? option.tint : .clear, lineWidth: 1.5))
                            Text(option.name)
                                .font(.system(size: 10, weight: colorID == option.id ? .semibold : .regular))
                                .foregroundStyle(Paper.inkSoft)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                        }
                        .frame(maxWidth: .infinity, minHeight: 62)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Χρώμα \(option.name)")
                    .accessibilityAddTraits(colorID == option.id ? .isSelected : [])
                    .accessibilityIdentifier("plannerCategory.color.\(option.id)")
                }
            }
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Paper.ink)
    }

    private var saveBar: some View {
        Button {
            guard canSave else { return }
            saving = true
            focusedField = nil
            let category = PlannerCategory(id: categoryID, name: trimmedName, symbol: symbol,
                                           emoji: chosenEmoji, colorID: colorID)
            store.save(category)
            if let saved = store.category(id: categoryID) {
                onSave(saved)
                dismiss()
            } else {
                saving = false
            }
        } label: {
            Label(isEditing ? "Αποθήκευση αλλαγών" : "Δημιουργία κατηγορίας",
                  systemImage: isEditing ? "checkmark" : "plus")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(canSave ? Paper.card : Paper.inkMute)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(canSave ? Paper.gold : Paper.hairline, in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!canSave)
        .accessibilityIdentifier("plannerCategory.save")
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(.ultraThinMaterial)
    }
}
