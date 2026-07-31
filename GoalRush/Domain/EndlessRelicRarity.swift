import Foundation

nonisolated enum EndlessRelicRarity: String, Codable, CaseIterable, Comparable, Sendable {
    case common
    case uncommon
    case rare
    case epic
    case legendary

    var title: String {
        rawValue.capitalized
    }

    var affixCount: Int {
        switch self {
        case .common, .uncommon: 1
        case .rare: 2
        case .epic: 3
        case .legendary: 4
        }
    }

    var valueMultiplier: Double {
        switch self {
        case .common: 1
        case .uncommon: 1.35
        case .rare: 1.75
        case .epic: 2.20
        case .legendary: 2.80
        }
    }

    var scrapValue: Int {
        switch self {
        case .common: 5
        case .uncommon: 10
        case .rare: 15
        case .epic: 25
        case .legendary: 35
        }
    }

    var diamondCount: Int {
        Self.allCases.firstIndex(of: self).map { $0 + 1 } ?? 1
    }

    static func < (lhs: EndlessRelicRarity, rhs: EndlessRelicRarity) -> Bool {
        lhs.diamondCount < rhs.diamondCount
    }
}
