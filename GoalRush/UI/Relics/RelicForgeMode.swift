import Foundation

enum RelicForgeMode: String, CaseIterable, Identifiable {
    case random
    case focused

    var id: Self { self }

    var title: String {
        switch self {
        case .random: "Random"
        case .focused: "Focused"
        }
    }

    var systemImage: String {
        switch self {
        case .random: "dice.fill"
        case .focused: "scope"
        }
    }

    var cost: Int {
        switch self {
        case .random: EndlessRelicRules.randomForgeCost
        case .focused: EndlessRelicRules.focusedForgeCost
        }
    }
}
