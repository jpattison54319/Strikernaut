import Foundation

nonisolated struct EndlessRelic: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let acquiredAt: Date
    let sourceWaveMilestone: Int
    let rarity: EndlessRelicRarity
    let primaryStat: EndlessRelicStat
    let affixes: [EndlessRelicAffix]

    init(
        id: UUID,
        acquiredAt: Date,
        sourceWaveMilestone: Int,
        rarity: EndlessRelicRarity,
        primaryStat: EndlessRelicStat,
        affixes: [EndlessRelicAffix]
    ) {
        self.id = id
        self.acquiredAt = acquiredAt
        self.sourceWaveMilestone = max(5, sourceWaveMilestone)
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
}
