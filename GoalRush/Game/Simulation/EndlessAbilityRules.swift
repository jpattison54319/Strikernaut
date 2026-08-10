import Foundation

enum EndlessAbilityRules {
    static let fullStrengthRank = 5
    static let minimumRenderedKickInterval = 0.14

    static func effectiveRank(_ rank: Int) -> Double {
        let safeRank = max(0, rank)
        guard safeRank > fullStrengthRank else { return Double(safeRank) }
        let ranksPastFullStrength = Double(safeRank - fullStrengthRank)
        return Double(fullStrengthRank)
            + Double(fullStrengthRank)
                * log1p(ranksPastFullStrength / Double(fullStrengthRank))
    }

    static func powerDriveMultiplier(rank: Int) -> Double {
        pow(1.25, effectiveRank(rank))
    }

    static func theoreticalKickInterval(base: Double, rank: Int) -> TimeInterval {
        base * pow(0.88, effectiveRank(rank))
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
        return 1.8 + effectiveRank(rank) * 1.7
    }

    static func gravitySpeedFactor(rank: Int) -> Double {
        1 / (1 + 0.07 * Double(max(0, rank)))
    }

    static func secondWindImmediateRecovery(rank: Int) -> Double {
        guard rank > 0 else { return 0 }
        return 10 + effectiveRank(rank) * 4
    }

    static func secondWindWaveRecovery(rank: Int) -> Double {
        guard rank > 0 else { return 0 }
        return 4 + effectiveRank(rank) * 3
    }

    static func meteorDamageMultiplier(rank: Int) -> Double {
        guard rank > 0 else { return 1 }
        return 1 + effectiveRank(rank) * 0.55
    }

    static func wideVolleySecondaryMastery(rank: Int) -> Double {
        guard rank > 3 else { return 1 }
        return 1 + (effectiveRank(rank) - 3) * 0.12
    }
}
