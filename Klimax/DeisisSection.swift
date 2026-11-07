import Foundation
import SwiftUI

enum DeisisBlockType: String, Codable {
    case rubric
    case petitionSet
    case prayer
}

struct DeisisDocument: Codable {
    let id: String
    let type: String
    let slug: String
    let title: String
    let subtitle: String
    let language: String
    let source: String
    let noteInternal: String?
    let placements: [DeisisPlacement]
    let blocks: [DeisisBlock]
    let nameFormulas: [String: DeisisNameFormula]
    let parameters: DeisisParameters

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case type = "_type"
        case slug, title, subtitle, language, source, placements, blocks, parameters
        case noteInternal = "note_internal"
        case nameFormulas = "name_formulas"
    }

    static func loadBundled(bundle: Bundle = .main) throws -> DeisisDocument {
        guard let url = bundle.url(forResource: "deiseis_kosmou", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try JSONDecoder().decode(Self.self, from: Data(contentsOf: url))
    }
}

struct DeisisPlacement: Codable, Hashable {
    let service: String
    let anchorAfter: String
    let anchorBefore: String
    let label: String

    enum CodingKeys: String, CodingKey {
        case service, label
        case anchorAfter = "anchor_after"
        case anchorBefore = "anchor_before"
    }
}

struct DeisisBlock: Codable, Identifiable {
    let id: String
    let type: DeisisBlockType
    let text: String?
    let heading: String?
    let source: String?
    let optional: Bool?
    let response: String?
    let namesSlot: String?
    let items: [DeisisBlockItem]?

    enum CodingKeys: String, CodingKey {
        case id, type, text, heading, source, optional, response, items
        case namesSlot = "names_slot"
    }
}

struct DeisisBlockItem: Codable, Identifiable {
    let id: String
    let text: String
    let namesSlot: String?
    let kind: String?
    let tone: String?

    enum CodingKeys: String, CodingKey {
        case id, text, kind, tone
        case namesSlot = "names_slot"
    }
}

struct DeisisNameFormula: Codable {
    let label: String
    let prefix: String
    let suffix: String?
    let singularPrefix: String
    let singularSuffix: String?
    let source: String?

    enum CodingKeys: String, CodingKey {
        case label, prefix, suffix, source
        case singularPrefix = "singular_prefix"
        case singularSuffix = "singular_suffix"
    }
}

struct DeisisParameters: Codable {
    let hierarch: DeisisHierarchParameter
}

struct DeisisHierarchParameter: Codable {
    let `default`: String
    let options: [DeisisHierarchOption]
    let note: String?
}

struct DeisisHierarchOption: Codable {
    let region: String
    let value: String
}

struct DeisisInsertion {
    let placement: DeisisPlacement
    let index: Int
}

enum DeisisPlacementEngine {
    static func insertion(
        anchors: [String: Int]?,
        document: DeisisDocument,
        bodyCount: Int
    ) -> DeisisInsertion? {
        guard let anchors else { return nil }
        for placement in document.placements {
            guard let after = anchors[placement.anchorAfter],
                  let before = anchors[placement.anchorBefore],
                  after >= 0,
                  before > after,
                  before < bodyCount else {
                continue
            }
            return DeisisInsertion(placement: placement, index: after + 1)
        }
        return nil
    }
}

enum DeisisCatalog {
    static let document = try? DeisisDocument.loadBundled()
}

struct DeisisSection: View {
    let document: DeisisDocument
    let placement: DeisisPlacement

    @Environment(DiptychaStore.self) private var diptycha
    @State private var includesNames: Bool

    init(document: DeisisDocument, placement: DeisisPlacement) {
        self.document = document
        self.placement = placement
        _includesNames = State(initialValue: UserDefaults.standard.bool(forKey: Self.preferenceKey(placement)))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            controls

            ForEach(document.blocks) { block in
                blockView(block)
            }

            Text(document.source)
                .font(.custom("GentiumBookPlus-Italic", size: 12))
                .foregroundStyle(Paper.inkMute.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Paper.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Paper.gold.opacity(0.24), lineWidth: 1)
                )
        )
        .onChange(of: includesNames) { _, newValue in
            UserDefaults.standard.set(newValue, forKey: Self.preferenceKey(placement))
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text(document.title)
                    .font(.custom("GFSDidot-Regular", size: 28))
                    .foregroundStyle(Paper.ink)
                Text(document.subtitle)
                    .font(.custom("GentiumBookPlus-Italic", size: 14))
                    .foregroundStyle(Paper.inkMute)
            }

            Spacer(minLength: 10)

            NavigationLink {
                DiptychaView(document: document)
            } label: {
                Image(systemName: "person.2.badge.plus")
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(Paper.gold)
                    .frame(width: 42, height: 42)
                    .contentShape(Circle())
                    .glassChrome(in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Δίπτυχα")
        }
    }

    private var controls: some View {
        Toggle(isOn: $includesNames) {
            Text("Ένωσε τα δίπτυχά σου")
                .font(.system(size: 14, weight: .heavy))
                .foregroundStyle(Paper.ink)
        }
        .tint(Paper.gold)
        .padding(.horizontal, 14)
        .frame(minHeight: 48)
        .glassChrome(in: RoundedRectangle(cornerRadius: 17, style: .continuous))
    }

    @ViewBuilder
    private func blockView(_ block: DeisisBlock) -> some View {
        switch block.type {
        case .rubric:
            if let text = block.text {
                sacredText(resolving: text, size: 14, italic: true)
                    .foregroundStyle(Paper.inkMute.opacity(0.78))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }

        case .petitionSet:
            VStack(alignment: .leading, spacing: 13) {
                ForEach(block.items ?? []) { item in
                    VStack(alignment: .leading, spacing: 5) {
                        sacredText(resolving: item.text)
                        insertedNames(for: item.namesSlot)
                    }
                }

                if let response = block.response {
                    sacredText(resolving: response, size: 19, italic: true)
                        .padding(.top, 2)
                }
            }

        case .prayer:
            VStack(alignment: .leading, spacing: 12) {
                if let heading = block.heading {
                    Text(heading)
                        .font(.custom("GFSDidot-Regular", size: 22))
                        .foregroundStyle(Paper.ink)
                }

                if let source = block.source {
                    Text(source)
                        .font(.custom("GentiumBookPlus-Italic", size: 12))
                        .foregroundStyle(Paper.inkMute.opacity(0.78))
                }

                if let text = block.text {
                    sacredText(resolving: text)
                } else {
                    ForEach(block.items ?? []) { item in
                        VStack(alignment: .leading, spacing: 5) {
                            if let tone = item.tone {
                                Text(tone)
                                    .font(.custom("GentiumBookPlus-Italic", size: 13))
                                    .foregroundStyle(Paper.gold.opacity(0.84))
                            }
                            sacredText(resolving: item.text)
                            insertedNames(for: item.namesSlot)
                        }
                    }
                }

                insertedNames(for: block.namesSlot)
            }
        }
    }

    private func sacredText(resolving text: String, size: CGFloat = 18, italic: Bool = false) -> some View {
        Text(resolved(text))
            .font(.custom(italic ? "GentiumBookPlus-Italic" : "Gentium Book Plus", size: size))
            .foregroundStyle(Paper.ink)
            .lineSpacing(7)
            .fixedSize(horizontal: false, vertical: true)
            .textSelection(.enabled)
    }

    @ViewBuilder
    private func insertedNames(for slot: String?) -> some View {
        if includesNames, let line = namesLine(for: slot) {
            Text(line)
                .font(.custom("Gentium Book Plus", size: 17))
                .foregroundStyle(Paper.gold)
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
    }

    private func namesLine(for slot: String?) -> String? {
        guard let slot,
              let category = DiptychaCategory(rawValue: slot),
              let formula = document.nameFormulas[slot] else {
            return nil
        }

        var categories = [category]
        let presentSlots = Set(document.blocks.flatMap { block in
            [block.namesSlot].compactMap { $0 } + (block.items ?? []).compactMap(\.namesSlot)
        })
        if category == .zontes {
            if !presentSlots.contains(DiptychaCategory.astheneis.rawValue) {
                categories.append(.astheneis)
            }
            if !presentSlots.contains(DiptychaCategory.odoiporountes.rawValue) {
                categories.append(.odoiporountes)
            }
        }

        let names = categories.flatMap { diptycha.entries(in: $0).map(\.name) }
        guard !names.isEmpty else { return nil }
        if names.count == 1 {
            return formula.singularPrefix + names[0] + (formula.singularSuffix ?? "")
        }
        return formula.prefix + names.joined(separator: "· ") + (formula.suffix ?? "")
    }

    private func resolved(_ text: String) -> String {
        text.replacingOccurrences(of: "{hierarch}", with: hierarchValue)
    }

    private var hierarchValue: String {
        let savedRegion = UserDefaults.standard.string(forKey: "liturgical.region")
        let currentRegion = Locale.current.region?.identifier
        let region = savedRegion ?? currentRegion
        return document.parameters.hierarch.options.first { $0.region == region }?.value
            ?? document.parameters.hierarch.default
    }

    private static func preferenceKey(_ placement: DeisisPlacement) -> String {
        "deiseis.includeDiptycha.\(placement.service)"
    }
}
