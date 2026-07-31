import Foundation

nonisolated enum CharacterID: String, Codable, CaseIterable, Identifiable, Sendable {
    case ace
    case volt
    case nova
    case aegis
    case gale
    case halo
    case flux
    case surge

    var id: String { rawValue }
}
