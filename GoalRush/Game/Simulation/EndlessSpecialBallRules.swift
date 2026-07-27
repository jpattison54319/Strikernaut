import Foundation

enum EndlessSpecialBallRules {
    static let campaignEquivalentRank = 5
    static let abilities: [TemporaryBallAbility] = [
        .volt,
        .ice,
        .fire,
        .reverse,
        .explosive,
        .split,
    ]

    static func isAvailable(_ ability: TemporaryBallAbility) -> Bool {
        abilities.contains(ability)
    }

    static func scale(rank: Int) -> Double {
        guard rank > 0 else { return 0 }
        return sqrt(Double(rank) / Double(campaignEquivalentRank))
    }

    static func selectedAbility(
        ranks: [TemporaryBallAbility: Int],
        roll: Double
    ) -> TemporaryBallAbility? {
        let owned = abilities.filter { ranks[$0, default: 0] > 0 }
        guard !owned.isEmpty else { return nil }
        let clampedRoll = min(0.999_999, max(0, roll))
        return owned[Int(clampedRoll * Double(owned.count))]
    }

    static func voltDamageMultiplier(recipientOffset: Int, rank: Int) -> Double {
        (0.15 + Double(max(0, recipientOffset)) * 0.05) * scale(rank: rank)
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
}
