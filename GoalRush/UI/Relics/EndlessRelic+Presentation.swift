import Foundation

extension EndlessRelicAffix {
    nonisolated var compactText: String {
        "+\(formattedPercent)% \(stat.compactEffectTitle)"
    }

    nonisolated var accessibilityText: String {
        "\(stat.title), plus \(formattedPercent) \(stat.unitDescription)"
    }

    private nonisolated var formattedPercent: String {
        if percent.rounded() == percent {
            return percent.formatted(
                .number.precision(.fractionLength(0))
            )
        }
        return percent.formatted(
            .number.precision(.fractionLength(0...1))
        )
    }
}

extension EndlessRelicStat {
    nonisolated var compactEffectTitle: String {
        switch self {
        case .attackDamage: "Damage"
        case .maximumStamina: "Stamina"
        case .kickRate: "Kick"
        case .movementResponse: "Move"
        case .ballSpeed: "Ball"
        case .criticalChance: "Crit"
        case .heroChargeRate: "Hero"
        case .trainingTokenGain: "Coins"
        }
    }
}
