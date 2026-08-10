import Foundation

struct EndlessRecord: Codable, Equatable, Sendable {
    var bestWave: Int
    var bestScore: Int
    var lastWave: Int?
    var lastScore: Int?
    var relics: [EndlessRelic]
    var equippedRelicID: UUID?
    var scrap: Int
    var lastRewardedRunID: UUID?

    static let empty = EndlessRecord(
        bestWave: 0,
        bestScore: 0,
        lastWave: nil,
        lastScore: nil,
        relics: [],
        equippedRelicID: nil,
        scrap: 0,
        lastRewardedRunID: nil
    )

    init(
        bestWave: Int,
        bestScore: Int,
        lastWave: Int? = nil,
        lastScore: Int? = nil,
        relics: [EndlessRelic] = [],
        equippedRelicID: UUID? = nil,
        scrap: Int = 0,
        lastRewardedRunID: UUID? = nil
    ) {
        self.bestWave = bestWave
        self.bestScore = bestScore
        self.lastWave = lastWave
        self.lastScore = lastScore
        self.relics = relics
        self.equippedRelicID = equippedRelicID
        self.scrap = max(0, scrap)
        self.lastRewardedRunID = lastRewardedRunID
        reconcileRelics()
    }

    var equippedRelic: EndlessRelic? {
        guard let equippedRelicID else { return nil }
        return relics.first(where: { $0.id == equippedRelicID })
    }

    mutating func reconcileRelics() {
        var seenIDs = Set<UUID>()
        relics = relics.filter { seenIDs.insert($0.id).inserted }
        scrap = max(0, scrap)
        if equippedRelic == nil {
            equippedRelicID = nil
        }
    }

    private enum CodingKeys: String, CodingKey {
        case bestWave
        case bestScore
        case lastWave
        case lastScore
        case relics
        case equippedRelicID
        case scrap
        case lastRewardedRunID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        bestWave = try container.decodeIfPresent(Int.self, forKey: .bestWave) ?? 0
        bestScore = try container.decodeIfPresent(Int.self, forKey: .bestScore) ?? 0
        lastWave = try container.decodeIfPresent(Int.self, forKey: .lastWave)
        lastScore = try container.decodeIfPresent(Int.self, forKey: .lastScore)
        relics = try container.decodeIfPresent([EndlessRelic].self, forKey: .relics) ?? []
        equippedRelicID = try container.decodeIfPresent(UUID.self, forKey: .equippedRelicID)
        scrap = try container.decodeIfPresent(Int.self, forKey: .scrap) ?? 0
        lastRewardedRunID = try container.decodeIfPresent(UUID.self, forKey: .lastRewardedRunID)
        reconcileRelics()
    }
}
