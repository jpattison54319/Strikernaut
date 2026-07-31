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
        ),
        CharacterDefinition(
            id: .gale,
            name: "Gale",
            role: "Storm Guardian",
            ability: .stormbreak,
            abilityName: "Stormbreak",
            abilityDescription: "Launch five giant bouncing storm balls and restore up to three enemy-intercepting orbiters.",
            unlockRequirement: .worldClear(.jupiter),
            accentHex: 0xF0A93B
        ),
        CharacterDefinition(
            id: .halo,
            name: "Halo",
            role: "Orbital Playmaker",
            ability: .ringRelay,
            abilityName: "Orbital Crown",
            abilityDescription: "Send a giant rotating crown of balls across the full field, crushing every enemy and hostile shot it touches.",
            unlockRequirement: .worldClear(.saturn),
            accentHex: 0xE7C761
        ),
        CharacterDefinition(
            id: .flux,
            name: "Flux",
            role: "Magnetic Trapper",
            ability: .poleShift,
            abilityName: "Polar Lockdown",
            abilityDescription: "Throw six magnetic spike traps that pull enemies in, pin them, and strike repeatedly.",
            unlockRequirement: .worldClear(.uranus),
            accentHex: 0x6FE7D4
        ),
        CharacterDefinition(
            id: .surge,
            name: "Surge",
            role: "Deep-Field Captain",
            ability: .tidalBreak,
            abilityName: "Tidal Break",
            abilityDescription: "Send three colossal full-field tsunamis that damage every enemy and drive the whole line back.",
            unlockRequirement: .worldClear(.neptune),
            accentHex: 0x23B8E5
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
