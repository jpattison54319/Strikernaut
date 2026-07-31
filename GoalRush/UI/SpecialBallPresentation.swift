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
        case .gravityWell: "SoccerBallGravityVortex"
        case .ringReturn: "SoccerBallReturn"
        case .polarLink: "SoccerBallMagnet"
        case .undertow: "SoccerBallTidal"
        }
    }

    private static func benefit(for ability: TemporaryBallAbility) -> String {
        switch ability {
        case .volt:
            "Chains through every enemy; closer targets take more damage."
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
        case .gravityWell:
            "Pulls nearby targets inward, then deals area damage."
        case .ringReturn:
            "Survives hits, turns at the edge, and comes back."
        case .polarLink:
            "Marks a target so following balls home toward it."
        case .undertow:
            "Pushes regular enemies back and slows them to 55%; bosses resist."
        }
    }

    private static func effect(
        for ability: TemporaryBallAbility,
        currentRank: Int
    ) -> AbilityEffectPresentation {
        let potency = potencyEffect(
            for: ability,
            currentRank: currentRank
        )
        guard EndlessSpecialBallRules.isAvailable(ability) else {
            return potency
        }
        return .init(
            metric: potency.metric,
            current: potency.current,
            next: potency.next,
            accent: potency.accent,
            chanceCurrent: chanceLabel(rank: currentRank),
            chanceNext: chanceLabel(rank: currentRank + 1)
        )
    }

    private static func potencyEffect(
        for ability: TemporaryBallAbility,
        currentRank: Int
    ) -> AbilityEffectPresentation {
        let nextRank = currentRank + 1
        switch ability {
        case .volt:
            return .init(
                metric: "Minimum chain hit",
                current: percentageOrOff(
                    EndlessSpecialBallRules.voltDamageMultiplier(
                        recipientOffset: 0,
                        recipientCount: 1,
                        rank: currentRank
                    )
                ),
                next: percentageOrOff(
                    EndlessSpecialBallRules.voltDamageMultiplier(
                        recipientOffset: 0,
                        recipientCount: 1,
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
                metric: "Burn time / tick damage",
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
                metric: "Blast damage / reach",
                current: explosiveLabel(rank: currentRank),
                next: explosiveLabel(rank: nextRank),
                accent: GoalRushTheme.gold
            )
        case .split:
            return .init(
                metric: "Fragments / fragment damage",
                current: splitLabel(rank: currentRank),
                next: splitLabel(rank: nextRank),
                accent: GoalRushTheme.positive
            )
        case .gravityWell:
            return .init(
                metric: "Vortex damage / reach",
                current: gravityWellLabel(rank: currentRank),
                next: gravityWellLabel(rank: nextRank),
                accent: GoalRushTheme.marsViolet
            )
        case .ringReturn:
            return .init(
                metric: "Return damage / edge turns",
                current: ringReturnLabel(rank: currentRank),
                next: ringReturnLabel(rank: nextRank),
                accent: GoalRushTheme.gold
            )
        case .polarLink:
            return .init(
                metric: "Mark time / homing strength",
                current: magnetMarkLabel(rank: currentRank),
                next: magnetMarkLabel(rank: nextRank),
                accent: GoalRushTheme.cyan
            )
        case .undertow:
            return .init(
                metric: "Push distance / slow time",
                current: undertowLabel(rank: currentRank),
                next: undertowLabel(rank: nextRank),
                accent: GoalRushTheme.blue
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
        let reach = fieldPercentage(
            EndlessSpecialBallRules.explosionRadius(rank: rank)
        )
        return "\(percentageOrOff(EndlessSpecialBallRules.explosionDamageMultiplier(rank: rank))) • \(reach) field"
    }

    private static func splitLabel(rank: Int) -> String {
        guard rank > 0 else { return "Off" }
        let count = EndlessSpecialBallRules.splitProjectileCount(
            rank: rank,
            isCritical: false
        )
        return "\(GameNumberFormatter.compact(count)) • \(percentageOrOff(EndlessSpecialBallRules.splitDamageMultiplier(rank: rank)))"
    }

    private static func gravityWellLabel(rank: Int) -> String {
        guard rank > 0 else { return "Off" }
        let reach = fieldPercentage(
            EndlessSpecialBallRules.gravityWellRadius(rank: rank)
        )
        return "\(percentageOrOff(EndlessSpecialBallRules.gravityWellDamageMultiplier(rank: rank))) • \(reach) field"
    }

    private static func ringReturnLabel(rank: Int) -> String {
        guard rank > 0 else { return "Off" }
        let damage = percentageOrOff(
            EndlessSpecialBallRules.ringReturnDamageMultiplier(rank: rank)
        )
        let turns = EndlessSpecialBallRules.ringReturnPasses(rank: rank)
        return "\(damage) • \(GameNumberFormatter.compact(turns)) \(turns == 1 ? "turn" : "turns")"
    }

    private static func magnetMarkLabel(rank: Int) -> String {
        guard rank > 0 else { return "Off" }
        let duration = durationLabel(
            EndlessSpecialBallRules.polarLinkMarkDuration(rank: rank)
        )
        let homing = percentageOrOff(
            EndlessSpecialBallRules.polarLinkTurnRate(rank: rank) / 5.5
        )
        return "\(duration) • \(homing)"
    }

    private static func undertowLabel(rank: Int) -> String {
        guard rank > 0 else { return "Off" }
        let push = fieldPercentage(
            EndlessSpecialBallRules.undertowPush(rank: rank)
        )
        return "\(push) field • \(durationLabel(EndlessSpecialBallRules.undertowSlowDuration(rank: rank)))"
    }

    private static func chanceLabel(rank: Int) -> String {
        let chance = EndlessSpecialBallRules.triggerChance(rank: rank)
        return chance > 0
            ? "\(Int((chance * 100).rounded()))%"
            : "Off"
    }

    private static func durationOrOff(_ duration: TimeInterval) -> String {
        guard duration > 0 else { return "Off" }
        return durationLabel(duration)
    }

    private static func durationLabel(_ duration: TimeInterval) -> String {
        if duration >= 1_000, duration < Double(Int.max) {
            return "\(GameNumberFormatter.compact(Int(duration.rounded()))) sec"
        }
        return "\(duration.formatted(.number.precision(.fractionLength(2)))) sec"
    }

    private static func percentageOrOff(_ multiplier: Double) -> String {
        guard multiplier > 0 else { return "Off" }
        return "\(GameNumberFormatter.compact(Int((multiplier * 100).rounded())))%"
    }

    private static func fieldPercentage(_ normalizedDistance: Double) -> String {
        "\(GameNumberFormatter.compact(Int((normalizedDistance * 100).rounded())))%"
    }
}
