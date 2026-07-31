import Foundation

nonisolated enum EndlessRelicRules {
    static let randomForgeCost = 40
    static let focusedForgeCost = 80

    static func completedWaves(fromWaveReached wave: Int) -> Int {
        max(0, wave - 1)
    }

    static func rewardMilestone(forWaveReached wave: Int) -> Int? {
        milestone(forCompletedWaves: completedWaves(fromWaveReached: wave))
    }

    static func forgeMilestone(forBestWaveReached wave: Int) -> Int? {
        milestone(forCompletedWaves: completedWaves(fromWaveReached: wave))
    }

    static func milestone(forCompletedWaves completedWaves: Int) -> Int? {
        guard completedWaves >= 5 else { return nil }
        return (completedWaves / 5) * 5
    }

    static func waveScale(at milestone: Int) -> Double {
        1 + 0.05 * Double(max(0, milestone - 5) / 5)
    }

    static func rarityOdds(at sourceWaveMilestone: Int) -> [EndlessRelicRarity: Int] {
        let milestone = max(5, sourceWaveMilestone)
        let thresholds: [(Int, [Int])] = [
            (5, [70, 25, 5, 0, 0]),
            (10, [58, 30, 10, 2, 0]),
            (20, [43, 34, 17, 5, 1]),
            (30, [30, 34, 25, 9, 2]),
            (50, [18, 30, 32, 16, 4]),
            (70, [10, 24, 36, 23, 7]),
            (100, [5, 15, 38, 30, 12]),
        ]
        var values = thresholds.last(where: { $0.0 <= milestone })?.1
            ?? thresholds[0].1

        if milestone > 100 {
            var shifts = (milestone - 100) / 20
            while shifts > 0 {
                guard let sourceIndex = values[..<4].firstIndex(where: { $0 > 0 }) else {
                    break
                }
                values[sourceIndex] -= 1
                values[4] += 1
                shifts -= 1
            }
        }

        return Dictionary(
            uniqueKeysWithValues: zip(EndlessRelicRarity.allCases, values)
        )
    }

    static func runReward(
        runID: UUID,
        waveReached: Int,
        acquiredAt: Date = .now
    ) -> EndlessRelic? {
        guard let milestone = rewardMilestone(forWaveReached: waveReached) else {
            return nil
        }
        return roll(
            id: runID,
            acquiredAt: acquiredAt,
            sourceWaveMilestone: milestone,
            guaranteedPrimary: nil,
            seed: stableSeed(for: runID, namespace: "run-\(milestone)")
        )
    }

    static func forgeRoll(
        id: UUID = UUID(),
        acquiredAt: Date = .now,
        sourceWaveMilestone: Int,
        focusedStat: EndlessRelicStat?
    ) -> EndlessRelic {
        roll(
            id: id,
            acquiredAt: acquiredAt,
            sourceWaveMilestone: sourceWaveMilestone,
            guaranteedPrimary: focusedStat,
            seed: stableSeed(
                for: id,
                namespace: "forge-\(sourceWaveMilestone)-\(focusedStat?.rawValue ?? "random")"
            )
        )
    }

    static func roll(
        id: UUID,
        acquiredAt: Date,
        sourceWaveMilestone: Int,
        guaranteedPrimary: EndlessRelicStat?,
        seed: UInt64
    ) -> EndlessRelic {
        let milestone = max(5, (sourceWaveMilestone / 5) * 5)
        var random = SeededGenerator(seed: seed)
        let rarity = rollRarity(at: milestone, using: &random)
        var availableStats = EndlessRelicStat.allCases
        let primary: EndlessRelicStat
        if let guaranteedPrimary {
            primary = guaranteedPrimary
            availableStats.removeAll { $0 == guaranteedPrimary }
        } else {
            let index = Int(random.next() % UInt64(availableStats.count))
            primary = availableStats.remove(at: index)
        }

        var affixes = [
            makeAffix(
                stat: primary,
                rarity: rarity,
                milestone: milestone,
                factorRange: 0.90...1.10,
                using: &random
            ),
        ]
        while affixes.count < rarity.affixCount, !availableStats.isEmpty {
            let index = Int(random.next() % UInt64(availableStats.count))
            let stat = availableStats.remove(at: index)
            affixes.append(
                makeAffix(
                    stat: stat,
                    rarity: rarity,
                    milestone: milestone,
                    factorRange: 0.65...0.85,
                    using: &random
                )
            )
        }

        return EndlessRelic(
            id: id,
            acquiredAt: acquiredAt,
            sourceWaveMilestone: milestone,
            rarity: rarity,
            primaryStat: primary,
            affixes: affixes
        )
    }

    static func stableSeed(for id: UUID, namespace: String) -> UInt64 {
        var hash: UInt64 = 1_469_598_103_934_665_603
        for byte in "\(id.uuidString.lowercased())|\(namespace)".utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return hash
    }

    private static func rollRarity(
        at milestone: Int,
        using random: inout SeededGenerator
    ) -> EndlessRelicRarity {
        let roll = Int(random.next() % 100)
        let odds = rarityOdds(at: milestone)
        var upperBound = 0
        for rarity in EndlessRelicRarity.allCases {
            upperBound += odds[rarity, default: 0]
            if roll < upperBound { return rarity }
        }
        return .common
    }

    private static func makeAffix(
        stat: EndlessRelicStat,
        rarity: EndlessRelicRarity,
        milestone: Int,
        factorRange: ClosedRange<Double>,
        using random: inout SeededGenerator
    ) -> EndlessRelicAffix {
        let factor = factorRange.lowerBound
            + (factorRange.upperBound - factorRange.lowerBound) * random.unit()
        let percent = stat.basePercent
            * rarity.valueMultiplier
            * waveScale(at: milestone)
            * factor
        let basisPoints = Int((percent * 10).rounded()) * 10
        return EndlessRelicAffix(stat: stat, basisPoints: basisPoints)
    }
}
