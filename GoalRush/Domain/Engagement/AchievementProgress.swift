import Foundation

struct AchievementProgress: Equatable, Sendable {
    let current: Int
    let goal: Int

    var completedAmount: Int {
        min(max(0, current), max(1, goal))
    }

    var fraction: Double {
        Double(completedAmount) / Double(max(1, goal))
    }

    var label: String {
        "\(GameNumberFormatter.compact(completedAmount)) / \(GameNumberFormatter.compact(max(1, goal)))"
    }

    var accessibilityLabel: String {
        "\(GameNumberFormatter.exact(completedAmount)) of \(GameNumberFormatter.exact(max(1, goal)))"
    }
}
