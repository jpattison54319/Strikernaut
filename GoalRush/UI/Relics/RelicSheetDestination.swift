import Foundation

enum RelicSheetDestination: Identifiable {
    case detail(EndlessRelic)
    case reveal(EndlessRelic)

    var id: String {
        switch self {
        case .detail(let relic): "detail-\(relic.id.uuidString)"
        case .reveal(let relic): "reveal-\(relic.id.uuidString)"
        }
    }
}
