import Foundation

nonisolated struct EndlessRelic: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let acquiredAt: Date
    let sourceWaveMilestone: Int
    let newGamePlusCycle: Int
    let rarity: EndlessRelicRarity
    let primaryStat: EndlessRelicStat
    let affixes: [EndlessRelicAffix]

    init(
        id: UUID,
        acquiredAt: Date,
        sourceWaveMilestone: Int,
        newGamePlusCycle: Int = 0,
        rarity: EndlessRelicRarity,
        primaryStat: EndlessRelicStat,
        affixes: [EndlessRelicAffix]
    ) {
        self.id = id
        self.acquiredAt = acquiredAt
        self.sourceWaveMilestone = max(5, sourceWaveMilestone)
        self.newGamePlusCycle = max(0, newGamePlusCycle)
        self.rarity = rarity
        self.primaryStat = primaryStat
        self.affixes = affixes
    }

    var name: String {
        primaryStat.title
    }

    var scrapValue: Int { rarity.scrapValue }

    func value(for stat: EndlessRelicStat) -> Double {
        affixes.first(where: { $0.stat == stat })?.fraction ?? 0
    }

    func affix(for stat: EndlessRelicStat) -> EndlessRelicAffix? {
        affixes.first(where: { $0.stat == stat })
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case acquiredAt
        case sourceWaveMilestone
        case newGamePlusCycle
        case rarity
        case primaryStat
        case affixes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(UUID.self, forKey: .id),
            acquiredAt: try container.decode(Date.self, forKey: .acquiredAt),
            sourceWaveMilestone: try container.decode(
                Int.self,
                forKey: .sourceWaveMilestone
            ),
            newGamePlusCycle: try container.decodeIfPresent(
                Int.self,
                forKey: .newGamePlusCycle
            ) ?? 0,
            rarity: try container.decode(EndlessRelicRarity.self, forKey: .rarity),
            primaryStat: try container.decode(
                EndlessRelicStat.self,
                forKey: .primaryStat
            ),
            affixes: try container.decode(
                [EndlessRelicAffix].self,
                forKey: .affixes
            )
        )
    }
}
