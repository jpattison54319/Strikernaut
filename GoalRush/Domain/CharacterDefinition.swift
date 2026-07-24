import Foundation

struct CharacterDefinition: Identifiable, Equatable, Sendable {
    let id: CharacterID
    let name: String
    let role: String
    let ability: CharacterAbility
    let abilityName: String
    let abilityDescription: String
    let unlockLevel: Int
    let accentHex: UInt

    var assetStem: String {
        "Character\(id.rawValue.prefix(1).uppercased())\(id.rawValue.dropFirst())"
    }

    var unlockDescription: String {
        unlockLevel == 1 ? "Available from the start" : "Clear Level \(unlockLevel)"
    }
}
