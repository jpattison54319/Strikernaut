import Foundation

enum CharacterCatalog {
    static let characters: [CharacterDefinition] = [
        CharacterDefinition(
            id: .ace,
            name: "Ace",
            role: "All-Round Striker",
            ability: .pinballBlitz,
            abilityName: "Pinball Blitz",
            abilityDescription: "Launch three blazing balls that ricochet across the entire field.",
            unlockRequirement: .starter,
            accentHex: 0x18D7E8
        ),
        CharacterDefinition(
            id: .volt,
            name: "Volt",
            role: "Speed Specialist",
            ability: .timeBreak,
            abilityName: "Time Break",
            abilityDescription: "Bend lunar gravity and freeze every threat while your regular shots keep flying.",
            unlockRequirement: .worldClear(.earth),
            accentHex: 0x4BE6FF
        ),
        CharacterDefinition(
            id: .nova,
            name: "Nova",
            role: "Mars Demolition",
            ability: .meteorVolley,
            abilityName: "Meteor Volley",
            abilityDescription: "Call down tracked meteors that explode on impact across the field.",
            unlockRequirement: .worldClear(.moon),
            accentHex: 0xFF6A32
        ),
        CharacterDefinition(
            id: .aegis,
            name: "Aegis",
            role: "Guardian Captain",
            ability: .lastStand,
            abilityName: "Last Stand",
            abilityDescription: "Restore stamina, gain two shields, and unleash four stunning shockwave bursts.",
            unlockRequirement: .worldClear(.mars),
            accentHex: 0xFFC247
        )
    ]

    static func character(_ id: CharacterID) -> CharacterDefinition {
        characters.first { $0.id == id } ?? characters[0]
    }

    static func unlockedCharacters(for progress: PlayerProgress) -> Set<CharacterID> {
        Set(characters.compactMap { character in
            switch character.unlockRequirement {
            case .starter:
                character.id
            case .worldClear(let world):
                progress.levelRecords[GameContent.world(world).finalLevel]?.completed == true
                    ? character.id
                    : nil
            }
        })
    }

    static func reward(for world: WorldID) -> CharacterDefinition? {
        characters.first { $0.unlockRequirement == .worldClear(world) }
    }
}
