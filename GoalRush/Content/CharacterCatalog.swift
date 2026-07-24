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
            unlockLevel: 1,
            accentHex: 0x18D7E8
        ),
        CharacterDefinition(
            id: .volt,
            name: "Volt",
            role: "Speed Specialist",
            ability: .timeBreak,
            abilityName: "Time Break",
            abilityDescription: "Freeze every enemy in place while your regular shots keep flying.",
            unlockLevel: 10,
            accentHex: 0x4BE6FF
        ),
        CharacterDefinition(
            id: .nova,
            name: "Nova",
            role: "Mars Demolition",
            ability: .meteorVolley,
            abilityName: "Meteor Volley",
            abilityDescription: "Call down tracked meteors that explode on impact across the field.",
            unlockLevel: 15,
            accentHex: 0xFF6A32
        ),
        CharacterDefinition(
            id: .aegis,
            name: "Aegis",
            role: "Guardian Captain",
            ability: .lastStand,
            abilityName: "Last Stand",
            abilityDescription: "Restore stamina, gain two shields, and unleash four stunning shockwave bursts.",
            unlockLevel: 20,
            accentHex: 0xFFC247
        )
    ]

    static func character(_ id: CharacterID) -> CharacterDefinition {
        characters.first { $0.id == id } ?? characters[0]
    }

    static func unlockedCharacters(for progress: PlayerProgress) -> Set<CharacterID> {
        Set(characters.compactMap { character in
            character.unlockLevel == 1 || progress.levelRecords[character.unlockLevel]?.completed == true
                ? character.id
                : nil
        })
    }
}
