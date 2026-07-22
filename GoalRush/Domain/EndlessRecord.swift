import Foundation

struct EndlessRecord: Codable, Equatable, Sendable {
    var bestWave: Int
    var bestScore: Int

    static let empty = EndlessRecord(bestWave: 0, bestScore: 0)
}
