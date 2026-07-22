import Foundation

enum GearID: String, Codable, CaseIterable, Identifiable, Sendable {
    case earthVisor
    case earthJersey
    case earthGloves
    case earthGuards
    case earthCleats
    case marsLens
    case marsCore
    case marsGauntlets
    case marsGuards
    case marsBoots

    var id: String { rawValue }
}
