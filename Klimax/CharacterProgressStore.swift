//
//  CharacterProgressStore.swift
//  Klimax
//

import Foundation
import UIKit

enum CharacterTransactionError: LocalizedError, Equatable {
    case unknownCharacter
    case unknownSkin
    case lockedCharacter
    case alreadyAtMaxEvolution
    case insufficientCurrency(missing: Int)
    case negativeAmount
    case requirementNotMet(String)
    case persistenceFailed

    var errorDescription: String? {
        switch self {
        case .unknownCharacter:
            return "This character is not available yet."
        case .unknownSkin:
            return "This skin is not available yet."
        case .lockedCharacter:
            return "Unlock this character first."
        case .alreadyAtMaxEvolution:
            return "Max Evolution reached."
        case .insufficientCurrency(let missing):
            return "You need \(missing) more gold."
        case .negativeAmount:
            return "Invalid currency amount."
        case .requirementNotMet(let message):
            return message
        case .persistenceFailed:
            return "Progress could not be saved."
        }
    }
}

struct CharacterSaveData: Codable, Hashable {
    var version: Int
    var currencyBalance: Int
    var selectedCharacterID: String
    var progressByCharacterID: [String: PlayerCharacterProgress]

    static func initial(catalog: [GameCharacter] = CharacterCatalog.all) -> CharacterSaveData {
        var progress: [String: PlayerCharacterProgress] = [:]
        for character in catalog {
            progress[character.id] = PlayerCharacterProgress.startingProgress(
                for: character,
                unlocked: character.id == CharacterCatalog.defaultCharacterID
            )
        }

        return CharacterSaveData(
            version: 1,
            currencyBalance: 50,
            selectedCharacterID: CharacterCatalog.defaultCharacterID,
            progressByCharacterID: progress
        )
    }

    mutating func migrate(catalog: [GameCharacter] = CharacterCatalog.all) {
        version = max(version, 1)
        if currencyBalance < 0 { currencyBalance = 0 }

        for character in catalog {
            var progress = progressByCharacterID[character.id] ?? PlayerCharacterProgress.startingProgress(
                for: character,
                unlocked: character.id == CharacterCatalog.defaultCharacterID
            )

            if character.id == CharacterCatalog.defaultCharacterID {
                progress.isUnlocked = true
            }

            let defaultSkinID = character.defaultSkin?.id ?? "default"
            progress.ownedSkinIDs.insert(defaultSkinID)

            if !character.skins.contains(where: { $0.id == progress.equippedSkinID }) {
                progress.equippedSkinID = defaultSkinID
            }

            progress.currentEvolutionLevel = max(1, min(progress.currentEvolutionLevel, character.maxEvolutionLevel))
            progressByCharacterID[character.id] = progress
        }

        if CharacterCatalog.character(id: selectedCharacterID) == nil ||
            progressByCharacterID[selectedCharacterID]?.isUnlocked != true {
            selectedCharacterID = CharacterCatalog.defaultCharacterID
        }
    }
}

@MainActor
final class CharacterProgressStore: ObservableObject {
    static let shared = CharacterProgressStore()

    @Published private(set) var saveData: CharacterSaveData

    private let storageKey = "klimax.character.save.v1"
    private let userDefaults: UserDefaults

    private init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        if let data = userDefaults.data(forKey: storageKey),
           var decoded = try? JSONDecoder().decode(CharacterSaveData.self, from: data) {
            decoded.migrate()
            saveData = decoded
        } else {
            saveData = CharacterSaveData.initial()
        }
        persist()
    }

    var currencyBalance: Int { saveData.currencyBalance }

    var selectedCharacter: GameCharacter {
        CharacterCatalog.character(id: saveData.selectedCharacterID) ?? CharacterCatalog.defaultCharacter
    }

    var selectedProgress: PlayerCharacterProgress {
        progress(for: selectedCharacter)
    }

    func progress(for character: GameCharacter) -> PlayerCharacterProgress {
        saveData.progressByCharacterID[character.id] ??
            PlayerCharacterProgress.startingProgress(
                for: character,
                unlocked: character.id == CharacterCatalog.defaultCharacterID
            )
    }

    func resolvedArtwork(for character: GameCharacter) -> CharacterResolvedArtwork {
        let progress = progress(for: character)
        return resolvedArtwork(for: character, progress: progress)
    }

    func resolvedArtwork(for character: GameCharacter, progress: PlayerCharacterProgress) -> CharacterResolvedArtwork {
        CharacterArtworkResolver.resolve(character: character, progress: progress)
    }

    func canAfford(_ amount: Int) -> Bool {
        amount >= 0 && saveData.currencyBalance >= amount
    }

    func addCurrency(_ amount: Int) throws {
        guard amount >= 0 else { throw CharacterTransactionError.negativeAmount }
        saveData.currencyBalance += amount
        try persistOrThrow()
    }

    /// Legacy compatibility hook. Lesson completion no longer feeds character XP.
    func addCharacterXP(_ amount: Int) {
        guard amount > 0 else { return }
        var progress = self.progress(for: selectedCharacter)
        progress.characterXP += amount
        saveData.progressByCharacterID[selectedCharacter.id] = progress
        persist()
    }

    func spendCurrency(_ amount: Int) throws {
        guard amount >= 0 else { throw CharacterTransactionError.negativeAmount }
        guard saveData.currencyBalance >= amount else {
            throw CharacterTransactionError.insufficientCurrency(missing: amount - saveData.currencyBalance)
        }
        saveData.currencyBalance -= amount
    }

    func unlock(characterID: String) throws {
        guard let character = CharacterCatalog.character(id: characterID) else {
            throw CharacterTransactionError.unknownCharacter
        }

        var progress = self.progress(for: character)
        guard !progress.isUnlocked else { return }
        try spendCurrency(character.unlockPrice)
        progress.isUnlocked = true
        saveData.progressByCharacterID[character.id] = progress
        try persistOrThrow()
    }

    func select(characterID: String) throws {
        guard let character = CharacterCatalog.character(id: characterID) else {
            throw CharacterTransactionError.unknownCharacter
        }
        let progress = progress(for: character)
        guard progress.isUnlocked else { throw CharacterTransactionError.lockedCharacter }
        guard saveData.selectedCharacterID != characterID else { return }
        saveData.selectedCharacterID = characterID
        try persistOrThrow()
    }

    func evolve(characterID: String) throws {
        guard let character = CharacterCatalog.character(id: characterID) else {
            throw CharacterTransactionError.unknownCharacter
        }

        var progress = self.progress(for: character)
        guard progress.isUnlocked else { throw CharacterTransactionError.lockedCharacter }
        guard let nextStage = character.nextStage(after: progress.currentEvolutionLevel) else {
            throw CharacterTransactionError.alreadyAtMaxEvolution
        }

        if let requiredXP = nextStage.requiredCharacterXP, progress.characterXP < requiredXP {
            throw CharacterTransactionError.requirementNotMet("This form needs \(requiredXP) character XP.")
        }

        try spendCurrency(nextStage.currencyCost)
        progress.currentEvolutionLevel = nextStage.level
        saveData.progressByCharacterID[character.id] = progress
        try persistOrThrow()
    }

    func purchaseSkin(characterID: String, skinID: String) throws {
        guard let character = CharacterCatalog.character(id: characterID) else {
            throw CharacterTransactionError.unknownCharacter
        }
        guard let skin = character.skins.first(where: { $0.id == skinID }) else {
            throw CharacterTransactionError.unknownSkin
        }

        var progress = self.progress(for: character)
        guard progress.isUnlocked else { throw CharacterTransactionError.lockedCharacter }
        guard !progress.ownedSkinIDs.contains(skinID) else { return }

        if let requiredLevel = skin.requiredEvolutionLevel,
           progress.currentEvolutionLevel < requiredLevel {
            throw CharacterTransactionError.requirementNotMet("Requires evolution level \(requiredLevel).")
        }

        try spendCurrency(skin.price)
        progress.ownedSkinIDs.insert(skinID)
        saveData.progressByCharacterID[character.id] = progress
        try persistOrThrow()
    }

    func equipSkin(characterID: String, skinID: String) throws {
        guard let character = CharacterCatalog.character(id: characterID) else {
            throw CharacterTransactionError.unknownCharacter
        }
        guard character.skins.contains(where: { $0.id == skinID }) else {
            throw CharacterTransactionError.unknownSkin
        }

        var progress = self.progress(for: character)
        guard progress.isUnlocked else { throw CharacterTransactionError.lockedCharacter }
        guard progress.ownedSkinIDs.contains(skinID) else {
            throw CharacterTransactionError.requirementNotMet("Purchase this skin first.")
        }
        guard progress.equippedSkinID != skinID else { return }

        progress.equippedSkinID = skinID
        saveData.progressByCharacterID[character.id] = progress
        try persistOrThrow()
    }

    private func persistOrThrow() throws {
        guard persist() else { throw CharacterTransactionError.persistenceFailed }
    }

    @discardableResult
    private func persist() -> Bool {
        guard let data = try? JSONEncoder().encode(saveData) else { return false }
        userDefaults.set(data, forKey: storageKey)
        return true
    }
}

enum CharacterFeedback {
    static func selection() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
}
