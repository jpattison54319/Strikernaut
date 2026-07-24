import Foundation

enum CharacterID: String, Codable, CaseIterable, Identifiable, Sendable {
    case ace
    case volt
    case nova
    case aegis

    var id: String { rawValue }
}
