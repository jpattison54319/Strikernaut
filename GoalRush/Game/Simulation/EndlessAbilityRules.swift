import Foundation

enum EndlessAbilityRules {
    static let minimumRenderedKickInterval = 0.14

    static func theoreticalKickInterval(base: Double, rank: Int) -> TimeInterval {
        base * pow(0.88, Double(max(0, rank)))
    }

    static func renderedKickInterval(base: Double, rank: Int) -> TimeInterval {
        max(
            minimumRenderedKickInterval,
            theoreticalKickInterval(base: base, rank: rank)
        )
    }

    static func quickReleaseDamageMultiplier(base: Double, rank: Int) -> Double {
        let theoretical = theoreticalKickInterval(base: base, rank: rank)
        guard theoretical < minimumRenderedKickInterval else { return 1 }
        return minimumRenderedKickInterval / theoretical
    }

    static func curlerTurnRate(rank: Int) -> Double {
        guard rank > 0 else { return 0 }
        return 1.8 + Double(rank) * 1.7
    }

    static func gravitySpeedFactor(rank: Int) -> Double {
        1 / (1 + 0.07 * Double(max(0, rank)))
    }
}
