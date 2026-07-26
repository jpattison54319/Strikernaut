import Foundation

enum TemporaryAbilityRules {
    static func duration(for ability: TemporaryBallAbility) -> TimeInterval {
        switch ability {
        case .rapidFire: 7
        case .explosive: 9
        case .fire: 10
        case .ice: 8
        case .reverse: 8
        case .split: 9
        case .heatSeeking: 9
        case .orbitShot: 9
        case .solarPierce: 8
        }
    }

    static func title(for ability: TemporaryBallAbility) -> String {
        switch ability {
        case .rapidFire: "Rapid Fire"
        case .explosive: "Explosive Balls"
        case .fire: "Fire Balls"
        case .ice: "Ice Balls"
        case .reverse: "Reverse Balls"
        case .split: "Split Shot"
        case .heatSeeking: "Heat Seeking"
        case .orbitShot: "Orbit Shot"
        case .solarPierce: "Solar Pierce"
        }
    }

    static func icon(for ability: TemporaryBallAbility) -> String {
        switch ability {
        case .rapidFire: "bolt.fill"
        case .explosive: "burst.fill"
        case .fire: "flame.fill"
        case .ice: "snowflake"
        case .reverse: "arrow.uturn.backward.circle.fill"
        case .split: "circle.hexagongrid.fill"
        case .heatSeeking: "scope"
        case .orbitShot: "circle.dotted.circle.fill"
        case .solarPierce: "sun.max.trianglebadge.exclamationmark.fill"
        }
    }
}
