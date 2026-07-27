import Foundation

struct EndlessRecord: Codable, Equatable, Sendable {
    var bestWave: Int
    var bestScore: Int
    var lastWave: Int?
    var lastScore: Int?

    static let empty = EndlessRecord(
        bestWave: 0,
        bestScore: 0,
        lastWave: nil,
        lastScore: nil
    )

    init(
        bestWave: Int,
        bestScore: Int,
        lastWave: Int? = nil,
        lastScore: Int? = nil
    ) {
        self.bestWave = bestWave
        self.bestScore = bestScore
        self.lastWave = lastWave
        self.lastScore = lastScore
    }

    private enum CodingKeys: String, CodingKey {
        case bestWave
        case bestScore
        case lastWave
        case lastScore
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        bestWave = try container.decodeIfPresent(Int.self, forKey: .bestWave) ?? 0
        bestScore = try container.decodeIfPresent(Int.self, forKey: .bestScore) ?? 0
        lastWave = try container.decodeIfPresent(Int.self, forKey: .lastWave)
        lastScore = try container.decodeIfPresent(Int.self, forKey: .lastScore)
    }
}
