import SwiftUI

struct AbilityEffectPresentation {
    let metric: String
    let current: String
    let next: String
    let accent: Color
    let chanceCurrent: String?
    let chanceNext: String?

    init(
        metric: String,
        current: String,
        next: String,
        accent: Color,
        chanceCurrent: String? = nil,
        chanceNext: String? = nil
    ) {
        self.metric = metric
        self.current = current
        self.next = next
        self.accent = accent
        self.chanceCurrent = chanceCurrent
        self.chanceNext = chanceNext
    }
}

struct RunUpgradePresentation {
    let title: String
    let artAsset: String
    let benefit: String
    let effect: AbilityEffectPresentation

    static func rankLabel(forCurrentRank currentRank: Int) -> String {
        if currentRank == 0 {
            return "NEW • RANK 1"
        }
        if currentRank >= 1_000 {
            return "RANK \(GameNumberFormatter.compact(currentRank)) → NEXT"
        }
        return "RANK \(currentRank) → \(currentRank + 1)"
    }
}
