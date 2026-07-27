import SwiftUI

enum SpecialBallPresentation {
    static func presentation(
        for ability: TemporaryBallAbility,
        currentRank: Int
    ) -> RunUpgradePresentation {
        .init(
            title: TemporaryAbilityRules.title(for: ability),
            artAsset: artAsset(for: ability),
            benefit: benefit(for: ability),
            effect: effect(for: ability, currentRank: currentRank)
        )
    }

    private static func artAsset(for ability: TemporaryBallAbility) -> String {
        switch ability {
        case .rapidFire: "SoccerBallRapidFire"
        case .explosive: "SoccerBallExplosive"
        case .fire: "SoccerBallFire"
        case .ice: "SoccerBallIce"
        case .reverse: "SoccerBallReverse"
        case .split: "SoccerBallSplit"
        case .heatSeeking: "AbilityCurler"
        case .orbitShot: "AbilityShockwave"
        case .solarPierce: "AbilityThroughBall"
        case .volt: "SoccerBallVolt"
        }
    }

    private static func benefit(for ability: TemporaryBallAbility) -> String {
        switch ability {
        case .volt:
            "Shots chain through enemies."
        case .ice:
            "Shots freeze targets."
        case .fire:
            "Shots burn targets."
        case .reverse:
            "Shots drive targets backward."
        case .explosive:
            "Shots blast nearby targets."
        case .split:
            "Shots burst into fragments."
        case .rapidFire, .heatSeeking, .orbitShot, .solarPierce:
            ""
        }
    }

    private static func effect(
        for ability: TemporaryBallAbility,
        currentRank: Int
    ) -> AbilityEffectPresentation {
        let nextRank = currentRank + 1
        switch ability {
        case .volt:
            return .init(
                metric: "First chain hit",
                current: percentageOrOff(
                    EndlessSpecialBallRules.voltDamageMultiplier(
                        recipientOffset: 0,
                        rank: currentRank
                    )
                ),
                next: percentageOrOff(
                    EndlessSpecialBallRules.voltDamageMultiplier(
                        recipientOffset: 0,
                        rank: nextRank
                    )
                ),
                accent: GoalRushTheme.cyan
            )
        case .ice:
            return .init(
                metric: "Freeze duration",
                current: durationOrOff(
                    EndlessSpecialBallRules.iceDuration(rank: currentRank)
                ),
                next: durationOrOff(
                    EndlessSpecialBallRules.iceDuration(rank: nextRank)
                ),
                accent: GoalRushTheme.cyan
            )
        case .fire:
            return .init(
                metric: "Burn duration / tick",
                current: fireLabel(rank: currentRank),
                next: fireLabel(rank: nextRank),
                accent: GoalRushTheme.orange
            )
        case .reverse:
            return .init(
                metric: "Reverse duration",
                current: durationOrOff(
                    EndlessSpecialBallRules.reverseDuration(rank: currentRank)
                ),
                next: durationOrOff(
                    EndlessSpecialBallRules.reverseDuration(rank: nextRank)
                ),
                accent: GoalRushTheme.marsViolet
            )
        case .explosive:
            return .init(
                metric: "Blast damage / radius",
                current: explosiveLabel(rank: currentRank),
                next: explosiveLabel(rank: nextRank),
                accent: GoalRushTheme.gold
            )
        case .split:
            return .init(
                metric: "Fragments / damage",
                current: splitLabel(rank: currentRank),
                next: splitLabel(rank: nextRank),
                accent: GoalRushTheme.positive
            )
        case .rapidFire, .heatSeeking, .orbitShot, .solarPierce:
            return .init(
                metric: "",
                current: "",
                next: "",
                accent: GoalRushTheme.blue
            )
        }
    }

    private static func fireLabel(rank: Int) -> String {
        guard rank > 0 else { return "Off" }
        return "\(durationLabel(EndlessSpecialBallRules.fireDuration(rank: rank))) • \(percentageOrOff(EndlessSpecialBallRules.fireTickDamageMultiplier(rank: rank)))"
    }

    private static func explosiveLabel(rank: Int) -> String {
        guard rank > 0 else { return "Off" }
        let radius = EndlessSpecialBallRules.explosionRadius(rank: rank)
            .formatted(.number.precision(.fractionLength(2)))
        return "\(percentageOrOff(EndlessSpecialBallRules.explosionDamageMultiplier(rank: rank))) • \(radius)"
    }

    private static func splitLabel(rank: Int) -> String {
        guard rank > 0 else { return "Off" }
        let count = EndlessSpecialBallRules.splitProjectileCount(
            rank: rank,
            isCritical: false
        )
        return "\(count) • \(percentageOrOff(EndlessSpecialBallRules.splitDamageMultiplier(rank: rank)))"
    }

    private static func durationOrOff(_ duration: TimeInterval) -> String {
        guard duration > 0 else { return "Off" }
        return durationLabel(duration)
    }

    private static func durationLabel(_ duration: TimeInterval) -> String {
        "\(duration.formatted(.number.precision(.fractionLength(2)))) sec"
    }

    private static func percentageOrOff(_ multiplier: Double) -> String {
        guard multiplier > 0 else { return "Off" }
        return "\(Int((multiplier * 100).rounded()))%"
    }
}
