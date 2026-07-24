import SwiftUI

struct UpgradeEffect: Equatable {
    let metric: String
    let current: String
    let next: String
    let improvement: String
}

enum UpgradePresentation {
    static func accent(for track: UpgradeTrack) -> Color {
        switch track {
        case .conditioning: GoalRushTheme.positive
        case .footwork: GoalRushTheme.cyan
        case .tempo: GoalRushTheme.gold
        case .impact: GoalRushTheme.orange
        case .flight: GoalRushTheme.blue
        case .spin: Color(red: 0.66, green: 0.36, blue: 1)
        }
    }

    static func icon(for track: UpgradeTrack) -> String {
        switch track {
        case .conditioning: "heart.fill"
        case .footwork: "figure.run"
        case .tempo: "metronome.fill"
        case .impact: "burst.fill"
        case .flight: "wind"
        case .spin: "sparkles"
        }
    }

    static func benefit(for track: UpgradeTrack) -> String {
        switch track {
        case .conditioning: "Take more hits."
        case .footwork: "Change lanes faster."
        case .tempo: "Kick more often."
        case .impact: "Deal more ball damage."
        case .flight: "Balls reach targets faster."
        case .spin: "Land more double-damage hits."
        }
    }

    static func systemLabel(for track: UpgradeTrack) -> String {
        switch track.category {
        case .player: "PLAYER SYSTEM"
        case .ball: "BALL SYSTEM"
        }
    }

    static func effect(for track: UpgradeTrack, rank: Int) -> UpgradeEffect {
        let nextRank = rank + 1
        switch track {
        case .conditioning:
            return .init(metric: "Maximum stamina", current: "\(stamina(rank))", next: "\(stamina(nextRank))", improvement: "+\(stamina(nextRank) - stamina(rank)) stamina")
        case .footwork:
            return .init(metric: "Movement bonus", current: "+\(rank * 7)%", next: "+\(nextRank * 7)%", improvement: "+7% lane response")
        case .tempo:
            let currentRate = kicksPerMinute(rank)
            let nextRate = kicksPerMinute(nextRank)
            return .init(metric: "Automatic kicks", current: "\(currentRate)/min", next: "\(nextRate)/min", improvement: "+\(nextRate - currentRate) kicks/min")
        case .impact:
            return .init(metric: "Ball damage", current: damage(rank), next: damage(nextRank), improvement: "+10% base damage")
        case .flight:
            return .init(metric: "Ball flight speed", current: "+\(rank * 6)%", next: "+\(nextRank * 6)%", improvement: "+6% flight speed")
        case .spin:
            return .init(
                metric: "Critical power",
                current: "\(5 + rank * 3)%",
                next: "\(5 + nextRank * 3)%",
                improvement: "+3% critical power"
            )
        }
    }

    private static func stamina(_ rank: Int) -> Int { Int((100 * (1 + 0.08 * Double(rank))).rounded()) }
    private static func kicksPerMinute(_ rank: Int) -> Int { Int((60 / UpgradeRules.kickCooldown(for: rank)).rounded()) }
    private static func damage(_ rank: Int) -> String { (10 * (1 + 0.10 * Double(rank))).formatted(.number.precision(.fractionLength(1))) }
}
