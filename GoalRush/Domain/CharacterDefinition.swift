import Foundation

enum CharacterUnlockRequirement: Equatable, Sendable {
    case starter
    case worldClear(WorldID)
}

struct CharacterDefinition: Identifiable, Equatable, Sendable {
    let id: CharacterID
    let name: String
    let role: String
    let ability: CharacterAbility
    let abilityName: String
    let abilityDescription: String
    let unlockRequirement: CharacterUnlockRequirement
    let accentHex: UInt

    var assetStem: String {
        "Character\(id.rawValue.prefix(1).uppercased())\(id.rawValue.dropFirst())"
    }

    var unlockDescription: String {
        switch unlockRequirement {
        case .starter:
            "Available from the start"
        case .worldClear(let world):
            "Clear \(GameContent.world(world).name)"
        }
    }
}
