import Foundation

struct LifetimeStats: Codable, Equatable, Sendable {
    var totalTokensEarned: Int
    var totalRuns: Int
    var totalWavesCleared: Int
    var totalTargetsDefeated: Int
    var bossesDefeated: Int
    var bestCombo: Int
    var upgradesPurchased: Int
    var characterAbilityDefeats: [CharacterID: Int]

    init(
        totalTokensEarned: Int = 0,
        totalRuns: Int = 0,
        totalWavesCleared: Int = 0,
        totalTargetsDefeated: Int = 0,
        bossesDefeated: Int = 0,
        bestCombo: Int = 0,
        upgradesPurchased: Int = 0,
        characterAbilityDefeats: [CharacterID: Int] = [:]
    ) {
        self.totalTokensEarned = totalTokensEarned
        self.totalRuns = totalRuns
        self.totalWavesCleared = totalWavesCleared
        self.totalTargetsDefeated = totalTargetsDefeated
        self.bossesDefeated = bossesDefeated
        self.bestCombo = bestCombo
        self.upgradesPurchased = upgradesPurchased
        self.characterAbilityDefeats = characterAbilityDefeats
    }

    func abilityDefeats(for character: CharacterID) -> Int {
        max(0, characterAbilityDefeats[character, default: 0])
    }

    var totalCharacterAbilityDefeats: Int {
        CharacterID.allCases.reduce(0) {
            $0 + abilityDefeats(for: $1)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case totalTokensEarned
        case totalRuns
        case totalWavesCleared
        case totalTargetsDefeated
        case bossesDefeated
        case bestCombo
        case upgradesPurchased
        case characterAbilityDefeats
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        totalTokensEarned = try container.decodeIfPresent(Int.self, forKey: .totalTokensEarned) ?? 0
        totalRuns = try container.decodeIfPresent(Int.self, forKey: .totalRuns) ?? 0
        totalWavesCleared = try container.decodeIfPresent(Int.self, forKey: .totalWavesCleared) ?? 0
        totalTargetsDefeated = try container.decodeIfPresent(Int.self, forKey: .totalTargetsDefeated) ?? 0
        bossesDefeated = try container.decodeIfPresent(Int.self, forKey: .bossesDefeated) ?? 0
        bestCombo = try container.decodeIfPresent(Int.self, forKey: .bestCombo) ?? 0
        upgradesPurchased = try container.decodeIfPresent(Int.self, forKey: .upgradesPurchased) ?? 0
        characterAbilityDefeats = try container.decodeIfPresent(
            [CharacterID: Int].self,
            forKey: .characterAbilityDefeats
        ) ?? [:]
    }
}
