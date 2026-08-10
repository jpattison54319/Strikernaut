import Foundation

nonisolated enum EndlessRelicStat: String, Codable, CaseIterable, Identifiable, Sendable {
    case attackDamage
    case maximumStamina
    case kickRate
    case movementResponse
    case ballSpeed
    case criticalChance
    case heroChargeRate
    case trainingTokenGain

    var id: String { rawValue }

    var title: String {
        switch self {
        case .attackDamage: "Attack Damage"
        case .maximumStamina: "Maximum Stamina"
        case .kickRate: "Kick Rate"
        case .movementResponse: "Movement Response"
        case .ballSpeed: "Ball Speed"
        case .criticalChance: "Critical Chance"
        case .heroChargeRate: "Hero Charge Rate"
        case .trainingTokenGain: "Training Token Gain"
        }
    }

    var shortTitle: String {
        switch self {
        case .maximumStamina: "Max Stamina"
        case .movementResponse: "Movement"
        case .criticalChance: "Critical Chance"
        case .heroChargeRate: "Hero Charge"
        case .trainingTokenGain: "Token Gain"
        default: title
        }
    }

    var systemImage: String {
        switch self {
        case .attackDamage: "burst.fill"
        case .maximumStamina: "heart.fill"
        case .kickRate: "bolt.fill"
        case .movementResponse: "figure.run"
        case .ballSpeed: "speedometer"
        case .criticalChance: "scope"
        case .heroChargeRate: "star.circle.fill"
        case .trainingTokenGain: "hexagon.fill"
        }
    }

    var basePercent: Double {
        switch self {
        case .attackDamage: 5
        case .maximumStamina: 6
        case .kickRate: 3
        case .movementResponse: 6
        case .ballSpeed: 5
        case .criticalChance: 2
        case .heroChargeRate: 6
        case .trainingTokenGain: 8
        }
    }

    var unitDescription: String {
        self == .criticalChance ? "percentage points" : "percent"
    }
}
