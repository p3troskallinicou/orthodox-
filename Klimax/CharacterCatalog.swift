//
//  CharacterCatalog.swift
//  Klimax
//

import Foundation

enum CharacterCatalog {
    static let defaultCharacterID = "theo"

    static let all: [GameCharacter] = [
        theo,
        seraphina,
        nikon
    ]

    static func character(id: String) -> GameCharacter? {
        all.first { $0.id == id }
    }

    static var defaultCharacter: GameCharacter {
        character(id: defaultCharacterID) ?? all[0]
    }

    static let theo = GameCharacter(
        id: "theo",
        name: "Theo",
        description: "A little bell-bearer whose courage grows into a gilded guardian of the Ladder.",
        unlockPrice: 0,
        evolutionStages: [
            CharacterEvolutionStage(
                id: "theo-stage-1",
                level: 1,
                name: "Baby Form",
                assetName: "character_theo_base",
                currencyCost: 0,
                requiredPlayerLevel: nil,
                requiredCharacterXP: nil,
                description: "Bright, curious, and ready for the first step.",
                animationOverrides: sampleAnimation(fallback: "character_theo_base", characterID: "theo", evolutionLevel: 1)
            ),
            CharacterEvolutionStage(
                id: "theo-stage-2",
                level: 2,
                name: "Middle Form",
                assetName: "character_theo_evolution_2",
                currencyCost: 100,
                requiredPlayerLevel: nil,
                requiredCharacterXP: 150,
                description: "The bell becomes armor, steady and watchful.",
                animationOverrides: sampleAnimation(fallback: "character_theo_evolution_2", characterID: "theo", evolutionLevel: 2)
            ),
            CharacterEvolutionStage(
                id: "theo-stage-3",
                level: 3,
                name: "End Form",
                assetName: "character_theo_evolution_3",
                currencyCost: 250,
                requiredPlayerLevel: nil,
                requiredCharacterXP: 400,
                description: "A full guardian form carrying the staff of ascent.",
                animationOverrides: sampleAnimation(fallback: "character_theo_evolution_3", characterID: "theo", evolutionLevel: 3)
            )
        ],
        skins: [
            CharacterSkin(id: "default", characterID: "theo", name: "Classic Theo", assetName: "character_theo_evolution_2", price: 0, requiredEvolutionLevel: nil, isDefault: true, animationOverrides: nil),
            CharacterSkin(id: "radiant", characterID: "theo", name: "Radiant Theo", assetName: "character_theo_skin_radiant", price: 200, requiredEvolutionLevel: 2, isDefault: false, animationOverrides: sampleAnimation(fallback: "character_theo_skin_radiant", characterID: "theo_skin_radiant", evolutionLevel: nil)),
            CharacterSkin(id: "shadow", characterID: "theo", name: "Shadow Theo", assetName: "character_theo_skin_shadow", price: 240, requiredEvolutionLevel: 2, isDefault: false, animationOverrides: sampleAnimation(fallback: "character_theo_skin_shadow", characterID: "theo_skin_shadow", evolutionLevel: nil)),
            CharacterSkin(id: "ember", characterID: "theo", name: "Ember Theo", assetName: "character_theo_skin_ember", price: 280, requiredEvolutionLevel: 2, isDefault: false, animationOverrides: sampleAnimation(fallback: "character_theo_skin_ember", characterID: "theo_skin_ember", evolutionLevel: nil))
        ],
        animationConfiguration: sampleAnimation(fallback: "character_theo_base", characterID: "theo", evolutionLevel: nil)
    )

    static let seraphina = GameCharacter(
        id: "seraphina",
        name: "Seraphina",
        description: "A warm placeholder companion for the next character drop.",
        unlockPrice: 160,
        evolutionStages: placeholderStages(characterID: "seraphina", title: "Lantern"),
        skins: placeholderSkins(characterID: "seraphina"),
        animationConfiguration: sampleAnimation(fallback: "character_placeholder_seraphina", characterID: "seraphina", evolutionLevel: nil)
    )

    static let nikon = GameCharacter(
        id: "nikon",
        name: "Nikon",
        description: "A premium placeholder guardian reserved for later art.",
        unlockPrice: 420,
        evolutionStages: placeholderStages(characterID: "nikon", title: "Guardian"),
        skins: placeholderSkins(characterID: "nikon"),
        animationConfiguration: sampleAnimation(fallback: "character_placeholder_nikon", characterID: "nikon", evolutionLevel: nil)
    )

    static func sampleAnimation(fallback: String, characterID: String, evolutionLevel: Int?) -> CharacterAnimationConfiguration {
        let prefix: String
        if let evolutionLevel {
            prefix = "character_\(characterID)_evolution_\(evolutionLevel)"
        } else {
            prefix = "character_\(characterID)"
        }

        return CharacterAnimationConfiguration(
            idleFrames: (1...4).map { "\(prefix)_idle_\(String(format: "%02d", $0))" },
            walkFrames: (1...6).map { "\(prefix)_walk_\(String(format: "%02d", $0))" },
            runFrames: (1...6).map { "\(prefix)_run_\(String(format: "%02d", $0))" },
            tapFrames: (1...3).map { "\(prefix)_tap_\(String(format: "%02d", $0))" },
            unlockFrames: (1...4).map { "\(prefix)_unlock_\(String(format: "%02d", $0))" },
            evolutionFrames: (1...4).map { "\(prefix)_evolve_\(String(format: "%02d", $0))" },
            victoryFrames: (1...3).map { "\(prefix)_victory_\(String(format: "%02d", $0))" },
            selectedFrames: (1...3).map { "\(prefix)_selected_\(String(format: "%02d", $0))" },
            skinPurchasedFrames: (1...4).map { "\(prefix)_skin_purchased_\(String(format: "%02d", $0))" },
            idleFrameDuration: 0.22,
            actionFrameDuration: 0.12,
            supportsLayeredAnimation: true,
            staticFallbackAssetName: fallback
        )
    }

    private static func placeholderStages(characterID: String, title: String) -> [CharacterEvolutionStage] {
        [
            CharacterEvolutionStage(id: "\(characterID)-stage-1", level: 1, name: "\(title) I", assetName: "character_placeholder_\(characterID)", currencyCost: 0, requiredPlayerLevel: nil, requiredCharacterXP: nil, description: "Placeholder base form.", animationOverrides: nil),
            CharacterEvolutionStage(id: "\(characterID)-stage-2", level: 2, name: "\(title) II", assetName: "character_placeholder_\(characterID)", currencyCost: 150, requiredPlayerLevel: nil, requiredCharacterXP: 0, description: "Placeholder evolved form.", animationOverrides: nil),
            CharacterEvolutionStage(id: "\(characterID)-stage-3", level: 3, name: "\(title) III", assetName: "character_placeholder_\(characterID)", currencyCost: 340, requiredPlayerLevel: nil, requiredCharacterXP: 0, description: "Placeholder final form.", animationOverrides: nil)
        ]
    }

    private static func placeholderSkins(characterID: String) -> [CharacterSkin] {
        [
            CharacterSkin(id: "default", characterID: characterID, name: "Default", assetName: "character_placeholder_\(characterID)", price: 0, requiredEvolutionLevel: nil, isDefault: true, animationOverrides: nil),
            CharacterSkin(id: "ivory", characterID: characterID, name: "Ivory", assetName: "character_placeholder_\(characterID)", price: 140, requiredEvolutionLevel: 1, isDefault: false, animationOverrides: nil),
            CharacterSkin(id: "midnight", characterID: characterID, name: "Midnight", assetName: "character_placeholder_\(characterID)", price: 210, requiredEvolutionLevel: 2, isDefault: false, animationOverrides: nil)
        ]
    }
}
