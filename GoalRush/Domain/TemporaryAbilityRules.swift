import Foundation

enum TemporaryAbilityRules {
    static let voltSpawnChance = 0.15

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
        case .volt: 7
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
        case .volt: "Volt Ball"
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
        case .volt: "bolt.horizontal.fill"
        }
    }

    static func spawnedAbility(
        worldPowers: [TemporaryBallAbility],
        universalRoll: Double,
        worldRoll: Double
    ) -> TemporaryBallAbility {
        guard universalRoll >= voltSpawnChance, !worldPowers.isEmpty else {
            return .volt
        }
        let clampedRoll = min(0.999_999, max(0, worldRoll))
        return worldPowers[Int(clampedRoll * Double(worldPowers.count))]
    }
}
