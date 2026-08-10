import Foundation

nonisolated struct EndlessRelicAffix: Codable, Equatable, Identifiable, Sendable {
    let stat: EndlessRelicStat
    let basisPoints: Int

    var id: EndlessRelicStat { stat }
    var fraction: Double { Double(basisPoints) / 10_000 }
    var percent: Double { Double(basisPoints) / 100 }

    init(stat: EndlessRelicStat, basisPoints: Int) {
        self.stat = stat
        self.basisPoints = max(0, basisPoints)
    }
}
