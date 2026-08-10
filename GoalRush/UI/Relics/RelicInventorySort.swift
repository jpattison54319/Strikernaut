import Foundation

enum RelicInventorySort: String, CaseIterable, Identifiable {
    case newest
    case rarity
    case sourceWave

    var id: String { rawValue }

    var title: String {
        switch self {
        case .newest: "Newest"
        case .rarity: "Rarity"
        case .sourceWave: "Source Wave"
        }
    }
}
