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
        case .gravityBoots: "Slow every threat."
        case .meteorStrike: "Periodic critical power shot."
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
            let base = isEndless ? 1.25 : 1.35
            return .init(
                metric: "Ball damage bonus",
                current: percentBonus(multiplier: pow(base, Double(currentRank))),
                next: percentBonus(multiplier: pow(base, Double(nextRank))),
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
                current: "\(currentRank + 1)",
                next: "\(nextRank + 1)",
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
                current: volleyLabel(rank: currentRank),
                next: volleyLabel(rank: nextRank),
                accent: GoalRushTheme.gold
            )
        case .cleanSheet:
            return .init(
                metric: "Blocks earned this run",
                current: "\(currentRank)",
                next: "\(nextRank)",
                accent: GoalRushTheme.blue
            )
        case .secondWind:
            return .init(
                metric: "Stamina now / each wave",
                current: currentRank == 0
                    ? "None"
                    : "+\(10 + currentRank * 4) / +\(4 + currentRank * 3)",
                next: "+\(10 + nextRank * 4) / +\(4 + nextRank * 3)",
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
                metric: "Meteor kick",
                current: meteorLabel(rank: currentRank),
                next: meteorLabel(rank: nextRank),
                accent: GoalRushTheme.orange
            )
        case .goldenGoal:
            return .init(
                metric: "Token rewards",
                current: "+\(currentRank * 15)%",
                next: "+\(nextRank * 15)%",
                accent: GoalRushTheme.gold
            )
        }
    }

    private static func percentBonus(multiplier: Double) -> String {
        "+\(Int(((multiplier - 1) * 100).rounded()))%"
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
            return "\(rate.formatted(.number.precision(.fractionLength(1)))) steering"
        }
        return ["Off", "Light", "Strong", "Elite"][min(rank, 3)]
    }

    private static func volleyLabel(rank: Int) -> String {
        if rank <= 3 {
            return [
                "1 straight ball",
                "2-ball spread",
                "3-ball spread",
                "4-ball wide spread",
            ][max(rank, 0)]
        }
        return "4 balls • +\((rank - 3) * 12)% side damage"
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

    private static func meteorLabel(rank: Int) -> String {
        guard rank > 0 else { return "Off" }
        let interval = max(2, 7 - min(rank, 5))
        return "Every \(interval) kicks • +\(rank * 55)%"
    }
}
