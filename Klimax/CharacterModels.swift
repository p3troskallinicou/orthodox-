//
//  CharacterModels.swift
//  Klimax
//

import Foundation

enum CharacterAnimationState: String, Codable, CaseIterable, Hashable {
    case idle
    case breathing
    case walking
    case running
    case tapped
    case selected
    case unlocked
    case evolving
    case skinPurchased
    case victory
    case locked
}

struct CharacterAnimationConfiguration: Codable, Hashable {
    var idleFrames: [String]
    var walkFrames: [String]
    var runFrames: [String]
    var tapFrames: [String]
    var unlockFrames: [String]
    var evolutionFrames: [String]
    var victoryFrames: [String]
    var selectedFrames: [String]
    var skinPurchasedFrames: [String]
    var idleFrameDuration: Double
    var actionFrameDuration: Double
    var supportsLayeredAnimation: Bool
    var staticFallbackAssetName: String

    static func staticOnly(fallback: String) -> CharacterAnimationConfiguration {
        CharacterAnimationConfiguration(
            idleFrames: [],
            walkFrames: [],
            runFrames: [],
            tapFrames: [],
            unlockFrames: [],
            evolutionFrames: [],
            victoryFrames: [],
            selectedFrames: [],
            skinPurchasedFrames: [],
            idleFrameDuration: 0.18,
            actionFrameDuration: 0.12,
            supportsLayeredAnimation: false,
            staticFallbackAssetName: fallback
        )
    }

    func frames(for state: CharacterAnimationState) -> [String] {
        switch state {
        case .idle, .breathing:
            return idleFrames
        case .walking:
            return walkFrames
        case .running:
            return runFrames.isEmpty ? walkFrames : runFrames
        case .tapped:
            return tapFrames
        case .selected:
            return selectedFrames
        case .unlocked:
            return unlockFrames
        case .evolving:
            return evolutionFrames
        case .skinPurchased:
            return skinPurchasedFrames
        case .victory:
            return victoryFrames
        case .locked:
            return []
        }
    }

    func frameDuration(for state: CharacterAnimationState) -> Double {
        switch state {
        case .idle, .breathing, .walking, .running:
            return idleFrameDuration
        default:
            return actionFrameDuration
        }
    }
}

struct GameCharacter: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let description: String
    let unlockPrice: Int
    let evolutionStages: [CharacterEvolutionStage]
    let skins: [CharacterSkin]
    let animationConfiguration: CharacterAnimationConfiguration

    var defaultSkin: CharacterSkin? {
        skins.first(where: \.isDefault) ?? skins.first
    }

    func stage(level: Int) -> CharacterEvolutionStage {
        evolutionStages
            .sorted { $0.level < $1.level }
            .last { $0.level <= level } ?? evolutionStages.sorted { $0.level < $1.level }.first!
    }

    func nextStage(after level: Int) -> CharacterEvolutionStage? {
        evolutionStages
            .sorted { $0.level < $1.level }
            .first { $0.level > level }
    }

    var maxEvolutionLevel: Int {
        evolutionStages.map(\.level).max() ?? 1
    }
}

struct CharacterEvolutionStage: Identifiable, Codable, Hashable {
    let id: String
    let level: Int
    let name: String
    let assetName: String
    let currencyCost: Int
    let requiredPlayerLevel: Int?
    let requiredCharacterXP: Int?
    let description: String?
    let animationOverrides: CharacterAnimationConfiguration?
}

struct CharacterSkin: Identifiable, Codable, Hashable {
    let id: String
    let characterID: String
    let name: String
    let assetName: String
    let price: Int
    let requiredEvolutionLevel: Int?
    let isDefault: Bool
    let animationOverrides: CharacterAnimationConfiguration?
}

struct PlayerCharacterProgress: Codable, Hashable {
    let characterID: String
    var isUnlocked: Bool
    var currentEvolutionLevel: Int
    var characterXP: Int
    var ownedSkinIDs: Set<String>
    var equippedSkinID: String

    static func startingProgress(for character: GameCharacter, unlocked: Bool) -> PlayerCharacterProgress {
        let defaultSkinID = character.defaultSkin?.id ?? "default"
        return PlayerCharacterProgress(
            characterID: character.id,
            isUnlocked: unlocked,
            currentEvolutionLevel: 1,
            characterXP: 0,
            ownedSkinIDs: [defaultSkinID],
            equippedSkinID: defaultSkinID
        )
    }
}

struct CharacterResolvedArtwork: Hashable {
    let assetName: String
    let configuration: CharacterAnimationConfiguration
    let isSkin: Bool
}

enum CharacterArtworkResolver {
    static func resolve(character: GameCharacter, progress: PlayerCharacterProgress) -> CharacterResolvedArtwork {
        let skin = character.skins.first { $0.id == progress.equippedSkinID && progress.ownedSkinIDs.contains($0.id) }
        let stage = character.stage(level: progress.currentEvolutionLevel)

        if let skin, !skin.isDefault {
            return CharacterResolvedArtwork(
                assetName: skin.assetName,
                configuration: skin.animationOverrides ?? stage.animationOverrides ?? character.animationConfiguration,
                isSkin: true
            )
        }

        return CharacterResolvedArtwork(
            assetName: stage.assetName,
            configuration: stage.animationOverrides ?? character.animationConfiguration,
            isSkin: false
        )
    }
}
