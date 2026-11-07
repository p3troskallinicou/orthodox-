//
//  CharactersView.swift
//  Klimax
//

import SwiftUI

struct CharactersView: View {
    @ObservedObject private var store = CharacterProgressStore.shared

    private let columns = [
        GridItem(.adaptive(minimum: 158, maximum: 220), spacing: 14)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(CharacterCatalog.all) { character in
                        NavigationLink {
                            CharacterDetailView(character: character)
                        } label: {
                            CharacterCardView(
                                character: character,
                                progress: store.progress(for: character),
                                balance: store.currencyBalance,
                                isSelected: store.saveData.selectedCharacterID == character.id
                            )
                        }
                        .buttonStyle(CalmCardStyle())
                    }
                }
            }
            .padding(.horizontal, KSpace.gutter)
            .padding(.top, KSpace.lg)
            .padding(.bottom, KSpace.xxl)
        }
        .background(Paper.bg.ignoresSafeArea())
        .navigationTitle("Characters")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("COMPANIONS")
                    .font(KType.label(11))
                    .tracking(2.4)
                    .foregroundStyle(Gild.gold)
                Text("Characters")
                    .font(.system(size: 34, weight: .regular, design: .serif))
                    .foregroundStyle(Paper.ink)
                Text("Unlock, evolve, and dress your Ladder companion.")
                    .font(.system(size: 14, design: .serif))
                    .foregroundStyle(Paper.inkMute)
            }
            Spacer()
            currencyPill
        }
        .accessibilityElement(children: .combine)
    }

    private var currencyPill: some View {
        HStack(spacing: 7) {
            Image(systemName: "seal.fill")
                .font(.system(size: 13, weight: .semibold))
            Text("\(store.currencyBalance)")
                .font(.system(size: 15, weight: .semibold, design: .serif))
        }
        .foregroundStyle(Gild.onGold)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Gild.gold, in: Capsule())
        .accessibilityLabel("Gold balance \(store.currencyBalance)")
    }
}

private struct CharacterCardView: View {
    let character: GameCharacter
    let progress: PlayerCharacterProgress
    let balance: Int
    let isSelected: Bool

    private var locked: Bool { !progress.isUnlocked }
    private var canAfford: Bool { balance >= character.unlockPrice }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .topTrailing) {
                AnimatedCharacterView(
                    character: character,
                    evolutionLevel: progress.currentEvolutionLevel,
                    equippedSkinID: progress.equippedSkinID,
                    animationState: locked ? .locked : (isSelected ? .selected : .idle),
                    size: CGSize(width: 128, height: 132),
                    isLocked: locked
                )
                .frame(maxWidth: .infinity)

                statusBadge
            }
            .frame(height: 140)

            VStack(alignment: .leading, spacing: 5) {
                Text(character.name)
                    .font(.system(size: 20, weight: .regular, design: .serif))
                    .foregroundStyle(locked ? Paper.ink.opacity(0.58) : Paper.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(stageLine)
                    .font(KType.caption(12))
                    .foregroundStyle(Paper.inkMute)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    if locked {
                        Label("\(character.unlockPrice)", systemImage: "lock.fill")
                            .foregroundStyle(canAfford ? Gild.gold : Paper.lockedIcon)
                    } else if isSelected {
                        Label("Selected", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(Gild.gold)
                    } else {
                        Label("Unlocked", systemImage: "seal")
                            .foregroundStyle(Paper.inkMute)
                    }
                }
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 230, alignment: .topLeading)
        .background(Paper.card, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(cardStroke)
        .shadow(color: .black.opacity(0.045), radius: 9, x: 0, y: 5)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    @ViewBuilder
    private var statusBadge: some View {
        if locked {
            Image(systemName: "lock.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Paper.lockedIcon)
                .frame(width: 30, height: 30)
                .background(Paper.lockedFill, in: Circle())
        } else if isSelected {
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Gild.onGold)
                .frame(width: 30, height: 30)
                .background(Gild.gold, in: Circle())
        }
    }

    private var cardStroke: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .stroke(isSelected ? Gild.gold.opacity(0.85) : Paper.hairline, lineWidth: isSelected ? 1.5 : 1)
    }

    private var stageLine: String {
        let stage = character.stage(level: progress.currentEvolutionLevel)
        if progress.currentEvolutionLevel >= character.maxEvolutionLevel {
            return "\(stage.name) · Max Evolution"
        }
        return "\(stage.name) · Level \(progress.currentEvolutionLevel)"
    }

    private var accessibilityLabel: String {
        if locked {
            return "\(character.name), locked, costs \(character.unlockPrice) gold"
        }
        if isSelected {
            return "\(character.name), selected, \(stageLine)"
        }
        return "\(character.name), unlocked, \(stageLine)"
    }
}

struct CharacterDetailView: View {
    let character: GameCharacter

    @ObservedObject private var store = CharacterProgressStore.shared
    @State private var animationState: CharacterAnimationState = .idle
    @State private var pendingAction: CharacterPendingAction?
    @State private var errorMessage: String?

    private var progress: PlayerCharacterProgress {
        store.progress(for: character)
    }

    private var stage: CharacterEvolutionStage {
        character.stage(level: progress.currentEvolutionLevel)
    }

    private var nextStage: CharacterEvolutionStage? {
        character.nextStage(after: progress.currentEvolutionLevel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                hero
                actionPanel
                evolutionSection
                skinsSection
            }
            .padding(.horizontal, KSpace.gutter)
            .padding(.top, KSpace.lg)
            .padding(.bottom, KSpace.xxl)
        }
        .background(Paper.bg.ignoresSafeArea())
        .navigationTitle(character.name)
        .navigationBarTitleDisplayMode(.inline)
        .alert(item: $pendingAction) { action in
            Alert(
                title: Text(action.title),
                message: Text(action.message),
                primaryButton: .default(Text(action.confirmTitle)) {
                    run(action)
                },
                secondaryButton: .cancel()
            )
        }
        .alert("Character Update", isPresented: errorBinding) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 16) {
            ZStack(alignment: .bottomTrailing) {
                AnimatedCharacterView(
                    character: character,
                    evolutionLevel: progress.currentEvolutionLevel,
                    equippedSkinID: progress.equippedSkinID,
                    animationState: animationState,
                    size: CGSize(width: 240, height: 260),
                    isLocked: !progress.isUnlocked
                )
                .frame(maxWidth: .infinity)

                currencyPill
            }
            .frame(maxWidth: .infinity, minHeight: 276)

            VStack(alignment: .leading, spacing: 7) {
                Text(character.name)
                    .font(.system(size: 34, weight: .regular, design: .serif))
                    .foregroundStyle(Paper.ink)
                Text(character.description)
                    .font(.system(size: 15, design: .serif))
                    .foregroundStyle(Paper.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                Text("\(stage.name) · \(progress.equippedSkinID.capitalized) Skin")
                    .font(KType.caption(12))
                    .foregroundStyle(Gild.gold)
            }
        }
    }

    private var actionPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(progress.isUnlocked ? "UNLOCKED" : "LOCKED")
                        .font(KType.label(10))
                        .tracking(2)
                        .foregroundStyle(Gild.gold)
                    Text(progress.isUnlocked ? "Ready for the Ladder" : "Costs \(character.unlockPrice) gold")
                        .font(.system(size: 17, design: .serif))
                        .foregroundStyle(Paper.ink)
                }
                Spacer()
                AscentDots(total: character.maxEvolutionLevel, reached: progress.currentEvolutionLevel)
            }

            HStack(spacing: 10) {
                if progress.isUnlocked {
                    Button {
                        selectCharacter()
                    } label: {
                        Label(isSelected ? "Selected" : "Select", systemImage: isSelected ? "checkmark.seal.fill" : "person.crop.circle.badge.checkmark")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(isSelected)
                    .buttonStyle(CharacterPrimaryButtonStyle(disabled: isSelected))
                } else {
                    Button {
                        pendingAction = .unlock(character: character)
                    } label: {
                        Label("Unlock", systemImage: "lock.open.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(CharacterPrimaryButtonStyle(disabled: !store.canAfford(character.unlockPrice)))
                    .disabled(!store.canAfford(character.unlockPrice))
                }
            }
        }
        .padding(16)
        .background(Paper.card, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Paper.hairline, lineWidth: 1))
    }

    private var evolutionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Evolution")

            ForEach(character.evolutionStages.sorted { $0.level < $1.level }) { candidate in
                EvolutionStageRow(
                    stage: candidate,
                    isCurrent: candidate.level == progress.currentEvolutionLevel,
                    isReached: candidate.level <= progress.currentEvolutionLevel,
                    canAfford: store.canAfford(candidate.currencyCost)
                )
            }

            if let nextStage {
                Button {
                    pendingAction = .evolve(character: character, stage: nextStage)
                } label: {
                    Label("Evolve to \(nextStage.name)", systemImage: "sparkles")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(CharacterPrimaryButtonStyle(disabled: !canEvolve(to: nextStage)))
                .disabled(!canEvolve(to: nextStage))
                .accessibilityHint(evolutionHint(for: nextStage))
            } else {
                Text("Max Evolution")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Gild.gold)
                    .padding(.vertical, 8)
            }
        }
    }

    private var skinsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Skins")

            ForEach(character.skins) { skin in
                SkinRow(
                    character: character,
                    skin: skin,
                    progress: progress,
                    balance: store.currencyBalance,
                    animationState: progress.equippedSkinID == skin.id ? .selected : .idle,
                    buy: { pendingAction = .buySkin(character: character, skin: skin) },
                    equip: { equip(skin) }
                )
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(KType.label(11))
            .tracking(2.5)
            .foregroundStyle(Gild.gold)
    }

    private var currencyPill: some View {
        HStack(spacing: 7) {
            Image(systemName: "seal.fill")
            Text("\(store.currencyBalance)")
        }
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(Gild.onGold)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Gild.gold, in: Capsule())
    }

    private var isSelected: Bool {
        store.saveData.selectedCharacterID == character.id
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }

    private func canEvolve(to stage: CharacterEvolutionStage) -> Bool {
        progress.isUnlocked &&
            progress.currentEvolutionLevel + 1 == stage.level &&
            store.canAfford(stage.currencyCost) &&
            (stage.requiredCharacterXP == nil || progress.characterXP >= stage.requiredCharacterXP!)
    }

    private func evolutionHint(for stage: CharacterEvolutionStage) -> String {
        if !progress.isUnlocked { return "Unlock this character first." }
        if !store.canAfford(stage.currencyCost) { return "You need more gold." }
        return "Costs \(stage.currencyCost) gold."
    }

    private func selectCharacter() {
        perform {
            try store.select(characterID: character.id)
            CharacterFeedback.selection()
            play(.selected)
        }
    }

    private func equip(_ skin: CharacterSkin) {
        perform {
            try store.equipSkin(characterID: character.id, skinID: skin.id)
            CharacterFeedback.selection()
            play(.selected)
        }
    }

    private func run(_ action: CharacterPendingAction) {
        switch action.kind {
        case .unlock:
            perform {
                try store.unlock(characterID: character.id)
                CharacterFeedback.success()
                play(.unlocked)
            }
        case .evolve:
            perform {
                try store.evolve(characterID: character.id)
                CharacterFeedback.success()
                play(.evolving)
            }
        case .buySkin(let skinID):
            perform {
                try store.purchaseSkin(characterID: character.id, skinID: skinID)
                try store.equipSkin(characterID: character.id, skinID: skinID)
                CharacterFeedback.success()
                play(.skinPurchased)
            }
        }
    }

    private func perform(_ operation: () throws -> Void) {
        do {
            try operation()
        } catch {
            CharacterFeedback.warning()
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func play(_ state: CharacterAnimationState) {
        animationState = .idle
        Task {
            try? await Task.sleep(for: .milliseconds(30))
            animationState = state
            try? await Task.sleep(for: .seconds(1.4))
            animationState = .idle
        }
    }
}

private struct EvolutionStageRow: View {
    let stage: CharacterEvolutionStage
    let isCurrent: Bool
    let isReached: Bool
    let canAfford: Bool

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(isReached ? Gild.gold : Paper.lockedFill)
                Image(systemName: isReached ? "checkmark" : "lock")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(isReached ? Gild.onGold : Paper.lockedIcon)
            }
            .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(stage.name)
                    .font(.system(size: 16, design: .serif))
                    .foregroundStyle(Paper.ink)
                Text(isCurrent ? "Current form" : costLine)
                    .font(KType.caption(12))
                    .foregroundStyle(isCurrent || canAfford ? Paper.inkMute : Paper.lockedIcon)
            }
            Spacer()
            Text("Lv \(stage.level)")
                .font(KType.caption(12))
                .foregroundStyle(Paper.inkMute)
        }
        .padding(12)
        .background(Paper.card, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Paper.hairline, lineWidth: 1))
    }

    private var costLine: String {
        stage.currencyCost == 0 ? "Base form" : "\(stage.currencyCost) gold"
    }
}

private struct SkinRow: View {
    let character: GameCharacter
    let skin: CharacterSkin
    let progress: PlayerCharacterProgress
    let balance: Int
    let animationState: CharacterAnimationState
    let buy: () -> Void
    let equip: () -> Void

    private var owned: Bool { progress.ownedSkinIDs.contains(skin.id) }
    private var equipped: Bool { progress.equippedSkinID == skin.id }
    private var requirementMet: Bool {
        guard let required = skin.requiredEvolutionLevel else { return true }
        return progress.currentEvolutionLevel >= required
    }
    private var affordable: Bool { balance >= skin.price }

    var body: some View {
        HStack(spacing: 12) {
            AnimatedCharacterView(
                character: character,
                evolutionLevel: progress.currentEvolutionLevel,
                equippedSkinID: skin.id,
                animationState: animationState,
                size: CGSize(width: 72, height: 82),
                isLocked: !owned && !skin.isDefault,
                allowsTapReaction: false
            )
            .frame(width: 82, height: 88)

            VStack(alignment: .leading, spacing: 4) {
                Text(skin.name)
                    .font(.system(size: 17, design: .serif))
                    .foregroundStyle(Paper.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                Text(statusLine)
                    .font(KType.caption(12))
                    .foregroundStyle(statusColor)
                    .lineLimit(2)
            }

            Spacer()

            if equipped {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(Gild.gold)
                    .accessibilityLabel("Equipped")
            } else if owned {
                Button(action: equip) {
                    Image(systemName: "checkmark.circle")
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Equip \(skin.name)")
            } else {
                Button(action: buy) {
                    Image(systemName: "seal")
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.borderless)
                .disabled(!requirementMet || !affordable)
                .accessibilityLabel("Buy \(skin.name) for \(skin.price) gold")
            }
        }
        .padding(12)
        .background(Paper.card, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(equipped ? Gild.gold.opacity(0.75) : Paper.hairline, lineWidth: equipped ? 1.4 : 1))
    }

    private var statusLine: String {
        if equipped { return "Equipped" }
        if owned { return "Owned" }
        if !requirementMet, let required = skin.requiredEvolutionLevel {
            return "Requires evolution level \(required)"
        }
        return "\(skin.price) gold"
    }

    private var statusColor: Color {
        if equipped { return Gild.gold }
        if owned { return Paper.inkMute }
        return affordable && requirementMet ? Gild.gold : Paper.lockedIcon
    }
}

private struct CharacterPrimaryButtonStyle: ButtonStyle {
    var disabled: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(disabled ? Paper.inkMute : Gild.onGold)
            .padding(.vertical, 12)
            .background(disabled ? Paper.lockedFill : Gild.gold, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(KMotion.press, value: configuration.isPressed)
    }
}

private enum CharacterPendingKind: Hashable {
    case unlock
    case evolve
    case buySkin(String)
}

private struct CharacterPendingAction: Identifiable {
    let id = UUID()
    let kind: CharacterPendingKind
    let title: String
    let message: String
    let confirmTitle: String

    static func unlock(character: GameCharacter) -> CharacterPendingAction {
        CharacterPendingAction(
            kind: .unlock,
            title: "Unlock \(character.name)?",
            message: "Spend \(character.unlockPrice) gold to permanently unlock this character.",
            confirmTitle: "Unlock"
        )
    }

    static func evolve(character: GameCharacter, stage: CharacterEvolutionStage) -> CharacterPendingAction {
        CharacterPendingAction(
            kind: .evolve,
            title: "Evolve \(character.name)?",
            message: "Spend \(stage.currencyCost) gold to reach \(stage.name).",
            confirmTitle: "Evolve"
        )
    }

    static func buySkin(character: GameCharacter, skin: CharacterSkin) -> CharacterPendingAction {
        CharacterPendingAction(
            kind: .buySkin(skin.id),
            title: "Buy \(skin.name)?",
            message: "Spend \(skin.price) gold to purchase and equip this skin.",
            confirmTitle: "Buy"
        )
    }
}

#Preview("Characters") {
    NavigationStack {
        CharactersView()
    }
}

#Preview("Theo Detail") {
    NavigationStack {
        CharacterDetailView(character: CharacterCatalog.theo)
    }
}
