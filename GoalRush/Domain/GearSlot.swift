import Foundation

enum GearSlot: String, Codable, CaseIterable, Identifiable, Sendable {
    case head
    case torso
    case hands
    case legs
    case feet

    var id: String { rawValue }

    var title: String {
        switch self {
        case .head: "Head"
        case .torso: "Torso"
        case .hands: "Arms"
        case .legs: "Legs"
        case .feet: "Feet"
        }
    }

    var icon: String {
        switch self {
        case .head: "eyeglasses"
        case .torso: "tshirt.fill"
        case .hands: "figure.arms.open"
        case .legs: "figure.run"
        case .feet: "shoe.fill"
        }
    }
}
