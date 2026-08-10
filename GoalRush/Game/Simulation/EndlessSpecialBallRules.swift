import Foundation

enum EndlessSpecialBallRules {
    static let campaignEquivalentRank = 5
    static let chancePerRank = 0.10
    static let abilities: [TemporaryBallAbility] = [
        .volt,
        .ice,
        .fire,
        .reverse,
        .explosive,
        .split,
        .gravityWell,
        .ringReturn,
        .polarLink,
        .undertow,
    ]

    static func isAvailable(_ ability: TemporaryBallAbility) -> Bool {
        abilities.contains(ability)
    }

    static func triggerChance(rank: Int) -> Double {
        min(1, Double(max(0, rank)) * chancePerRank)
    }

    static func triggeredEffects(
        ranks: [TemporaryBallAbility: Int],
        rolls: [TemporaryBallAbility: Double]
    ) -> Set<TemporaryBallAbility> {
        Set(abilities.filter { ability in
            let chance = triggerChance(rank: ranks[ability, default: 0])
            let roll = min(0.999_999, max(0, rolls[ability, default: 1]))
            return chance > roll
        })
    }

    static func scale(rank: Int) -> Double {
        guard rank > 0 else { return 0 }
        return sqrt(Double(rank) / Double(campaignEquivalentRank))
    }

    static func voltDamageMultiplier(
        recipientOffset: Int,
        recipientCount: Int,
        rank: Int
    ) -> Double {
        let safeCount = max(1, recipientCount)
        let safeOffset = min(max(0, recipientOffset), safeCount - 1)
        let reverseOffset = safeCount - safeOffset - 1
        return (0.15 + Double(reverseOffset) * 0.05)
            * scale(rank: rank)
    }

    static func iceDuration(rank: Int) -> TimeInterval {
        1.7 * scale(rank: rank)
    }

    static func fireDuration(rank: Int) -> TimeInterval {
        4 * scale(rank: rank)
    }

    static func fireTickDamageMultiplier(rank: Int) -> Double {
        0.18 * scale(rank: rank)
    }

    static func reverseDuration(rank: Int) -> TimeInterval {
        2.8 * scale(rank: rank)
    }

    static func explosionDamageMultiplier(rank: Int) -> Double {
        0.55 * scale(rank: rank)
    }

    static func explosionRadius(rank: Int) -> Double {
        guard rank > 0 else { return 0 }
        return 0.28 * pow(
            Double(rank) / Double(campaignEquivalentRank),
            0.25
        )
    }

    static func splitProjectileCount(rank: Int, isCritical: Bool) -> Int {
        guard rank > 0 else { return 0 }
        let normalCount = 1 + Int((4 * scale(rank: rank)).rounded(.down))
        return normalCount + (isCritical ? 3 : 0)
    }

    static func splitDamageMultiplier(rank: Int) -> Double {
        0.42 * scale(rank: rank)
    }

    static func gravityWellDamageMultiplier(rank: Int) -> Double {
        0.38 * scale(rank: rank)
    }

    static func gravityWellRadius(rank: Int) -> Double {
        guard rank > 0 else { return 0 }
        return 0.42 * pow(Double(rank) / Double(campaignEquivalentRank), 0.18)
    }

    static func gravityWellPullStrength(rank: Int) -> Double {
        6.5 * scale(rank: rank)
    }

    static let gravityWellPullDuration: TimeInterval = 0.55

    static func ringReturnPasses(rank: Int) -> Int {
        guard rank > 0 else { return 0 }
        return 1 + max(0, rank - 1) / campaignEquivalentRank
    }

    static func ringReturnDamageMultiplier(rank: Int) -> Double {
        scale(rank: rank)
    }

    static func polarLinkTurnRate(rank: Int) -> Double {
        5.5 * scale(rank: rank)
    }

    static func polarLinkMarkDuration(rank: Int) -> TimeInterval {
        1.4 * scale(rank: rank)
    }

    static func undertowPush(rank: Int) -> Double {
        0.14 * scale(rank: rank)
    }

    static func undertowSlowDuration(rank: Int) -> TimeInterval {
        0.55 * scale(rank: rank)
    }

    static let undertowSpeedFactor = 0.55
}
