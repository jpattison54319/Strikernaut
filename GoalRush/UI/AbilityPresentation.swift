import SwiftUI

enum AbilityPresentation {
    static func title(_ ability: AbilityKind) -> String {
        switch ability {
        case .powerDrive: "Power Drive"
        case .quickRelease: "Quick Release"
        case .throughBall: "Through Ball"
        case .curler: "Curler"
        case .oneTwo: "Wide Volley"
        case .cleanSheet: "Clean Sheet"
        case .secondWind: "Second Wind"
        case .gravityBoots: "Gravity Boots"
        case .meteorStrike: "Meteor Strike"
        case .goldenGoal: "Golden Goal"
        }
    }

    static func artAsset(_ ability: AbilityKind) -> String {
        switch ability {
        case .powerDrive: "AbilityPowerDrive"
        case .quickRelease: "AbilityQuickRelease"
        case .throughBall: "AbilityThroughBall"
        case .curler: "AbilityCurler"
        case .oneTwo: "AbilityWideVolley"
        case .cleanSheet: "AbilityCleanSheet"
        case .secondWind: "AbilitySecondWind"
        case .gravityBoots: "AbilityGravityBoots"
        case .meteorStrike: "AbilityMeteor"
        case .goldenGoal: "AbilityGoldenGoal"
        }
    }

    static func benefit(_ ability: AbilityKind) -> String {
        switch ability {
        case .powerDrive: "More ball damage."
        case .quickRelease: "Kick more often."
        case .throughBall: "Hit more targets per ball."
        case .curler: "Shots track nearby targets."
        case .oneTwo: "Cover more lanes."
        case .cleanSheet: "Block one hit."
        case .secondWind: "Heal now and after waves."
        case .gravityBoots: "Slow regular enemies and field objects."
        case .meteorStrike: "Drops a targeted damage meteor."
        case .goldenGoal: "Earn more Training Tokens."
        }
    }

    static func effect(
        for ability: AbilityKind,
        currentRank: Int,
        isEndless: Bool,
        baseKickInterval: Double
    ) -> AbilityEffectPresentation {
        let nextRank = isEndless ? currentRank + 1 : min(3, currentRank + 1)
        switch ability {
        case .powerDrive:
            let currentMultiplier = isEndless
                ? EndlessAbilityRules.powerDriveMultiplier(rank: currentRank)
                : pow(1.35, Double(currentRank))
            let nextMultiplier = isEndless
                ? EndlessAbilityRules.powerDriveMultiplier(rank: nextRank)
                : pow(1.35, Double(nextRank))
            return .init(
                metric: "Ball damage bonus",
                current: percentBonus(multiplier: currentMultiplier),
                next: percentBonus(multiplier: nextMultiplier),
                accent: GoalRushTheme.orange
            )
        case .quickRelease:
            return .init(
                metric: "Kick interval / power",
                current: intervalLabel(
                    rank: currentRank,
                    isEndless: isEndless,
                    base: baseKickInterval
                ),
                next: intervalLabel(
                    rank: nextRank,
                    isEndless: isEndless,
                    base: baseKickInterval
                ),
                accent: GoalRushTheme.cyan
            )
        case .throughBall:
            return .init(
                metric: "Targets hit per ball",
                current: GameNumberFormatter.compact(currentRank + 1),
                next: GameNumberFormatter.compact(nextRank + 1),
                accent: GoalRushTheme.positive
            )
        case .curler:
            return .init(
                metric: "Shot tracking",
                current: trackingLabel(rank: currentRank, isEndless: isEndless),
                next: trackingLabel(rank: nextRank, isEndless: isEndless),
                accent: GoalRushTheme.cyan
            )
        case .oneTwo:
            return .init(
                metric: "Kick pattern",
                current: volleyLabel(rank: currentRank, isEndless: isEndless),
                next: volleyLabel(rank: nextRank, isEndless: isEndless),
                accent: GoalRushTheme.gold
            )
        case .cleanSheet:
            return .init(
                metric: "Block gained now",
                current: "None",
                next: "+1 hit",
                accent: GoalRushTheme.blue
            )
        case .secondWind:
            return .init(
                metric: "Stamina now / each wave",
                current: recoveryLabel(
                    rank: currentRank,
                    isEndless: isEndless
                ),
                next: recoveryLabel(
                    rank: nextRank,
                    isEndless: isEndless
                ),
                accent: GoalRushTheme.positive
            )
        case .gravityBoots:
            return .init(
                metric: "Enemy speed reduction",
                current: slowLabel(rank: currentRank, isEndless: isEndless),
                next: slowLabel(rank: nextRank, isEndless: isEndless),
                accent: GoalRushTheme.cyan
            )
        case .meteorStrike:
            return .init(
                metric: "Targeted meteor",
                current: meteorLabel(
                    rank: currentRank,
                    isEndless: isEndless
                ),
                next: meteorLabel(
                    rank: nextRank,
                    isEndless: isEndless
                ),
                accent: GoalRushTheme.orange
            )
        case .goldenGoal:
            return .init(
                metric: "Token rewards",
                current: percentBonus(
                    multiplier: EconomyBalance.goldenGoalMultiplier(rank: currentRank)
                ),
                next: percentBonus(
                    multiplier: EconomyBalance.goldenGoalMultiplier(rank: nextRank)
                ),
                accent: GoalRushTheme.gold
            )
        }
    }

    private static func percentBonus(multiplier: Double) -> String {
        "+\(GameNumberFormatter.compact(Int(((multiplier - 1) * 100).rounded())))%"
    }

    private static func intervalLabel(
        rank: Int,
        isEndless: Bool,
        base: Double
    ) -> String {
        if isEndless {
            let interval = EndlessAbilityRules.renderedKickInterval(
                base: base,
                rank: rank
            )
            let multiplier = EndlessAbilityRules.quickReleaseDamageMultiplier(
                base: base,
                rank: rank
            )
            let intervalText = interval.formatted(
                .number.precision(.fractionLength(2))
            )
            guard multiplier > 1.000_001 else { return "\(intervalText) sec" }
            return "\(intervalText) sec • \(percentBonus(multiplier: multiplier)) power"
        }

        let interval = max(0.14, base * pow(0.82, Double(rank)))
        return "\(interval.formatted(.number.precision(.fractionLength(2)))) sec"
    }

    private static func trackingLabel(rank: Int, isEndless: Bool) -> String {
        guard rank > 0 else { return "Off" }
        if isEndless {
            let rate = EndlessAbilityRules.curlerTurnRate(rank: rank)
            return "\(displayNumber(rate, fractionLength: 1)) steering"
        }
        return ["Off", "Light", "Strong", "Elite"][min(rank, 3)]
    }

    private static func volleyLabel(rank: Int, isEndless: Bool) -> String {
        if isEndless {
            return rank == 0
                ? "1 straight ball"
                : "\(GameNumberFormatter.compact(rank + 1))-ball spread"
        }
        if rank <= 3 {
            return [
                "1 straight ball",
                "2-ball spread",
                "3-ball spread",
                "4-ball wide spread",
            ][max(rank, 0)]
        }
        return "4-ball wide spread"
    }

    private static func slowLabel(rank: Int, isEndless: Bool) -> String {
        let factor = isEndless
            ? EndlessAbilityRules.gravitySpeedFactor(rank: rank)
            : 0.35 + 0.65 * pow(0.90, Double(rank))
        let percentage = (1 - factor) * 100
        if isEndless {
            return "\(percentage.formatted(.number.precision(.fractionLength(1))))% slower"
        }
        return "\(Int(percentage.rounded()))% slower"
    }

    private static func recoveryLabel(
        rank: Int,
        isEndless: Bool
    ) -> String {
        guard rank > 0 else { return "None" }
        if isEndless {
            let immediate = displayNumber(
                EndlessAbilityRules.secondWindImmediateRecovery(rank: rank),
                fractionLength: 1
            )
            let eachWave = displayNumber(
                EndlessAbilityRules.secondWindWaveRecovery(rank: rank),
                fractionLength: 1
            )
            return "+\(immediate) / +\(eachWave)"
        }
        return "+\(10 + rank * 4) / +\(4 + rank * 3)"
    }

    private static func meteorLabel(rank: Int, isEndless: Bool) -> String {
        guard rank > 0 else { return "Off" }
        let interval = max(2, 7 - min(rank, 5))
        if isEndless {
            let percentage = displayNumber(
                (EndlessAbilityRules.meteorDamageMultiplier(rank: rank) - 1)
                    * 100,
                fractionLength: 1
            )
            return "Every \(interval) kicks • +\(percentage)%"
        }
        return "Every \(interval) kicks • +\(GameNumberFormatter.compact(rank * 55))%"
    }

    private static func displayNumber(
        _ value: Double,
        fractionLength: Int
    ) -> String {
        if value.magnitude >= 1_000,
           value > Double(Int.min),
           value < Double(Int.max) {
            return GameNumberFormatter.compact(Int(value.rounded()))
        }
        return value.formatted(
            .number.precision(.fractionLength(fractionLength))
        )
    }
}
