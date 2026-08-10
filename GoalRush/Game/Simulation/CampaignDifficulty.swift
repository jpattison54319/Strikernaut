import Foundation

enum CampaignDifficulty {
    static func referenceRank(cycle: Int, levelNumber: Int) -> Double? {
        guard cycle > 0 else { return nil }
        let safeCycle = Double(cycle)
        let cycleStart = 32
            + Double(cycle - 1) * (22.7 + 3.45 * safeCycle)
        let perLevel = 0.30 + 0.10 * safeCycle
        return cycleStart
            + perLevel * Double(max(0, levelNumber - 1))
    }

    static func pressureLevel(cycle: Int, levelNumber: Int) -> Double? {
        guard cycle > 0 else { return nil }
        let safeCycle = Double(cycle)
        let cycleStart = 80
            + Double(cycle - 1) * (113.5 + 17.25 * safeCycle)
        let perLevel = 1.5 + 0.5 * safeCycle
        return cycleStart
            + perLevel * Double(max(0, levelNumber - 1))
    }

    static func quotaLevel(cycle: Int, levelNumber: Int) -> Double? {
        guard let pressure = pressureLevel(
            cycle: cycle,
            levelNumber: levelNumber
        ) else {
            return nil
        }
        return 70 + 0.45 * (pressure - 70)
    }

    static func landmarkCount(cycle: Int, levelNumber: Int) -> Int? {
        guard let pressure = pressureLevel(
            cycle: cycle,
            levelNumber: levelNumber
        ) else {
            return nil
        }
        let virtualLevel = max(1, Int(pressure.rounded(.down)))
        let completedWorlds = max(0, (virtualLevel - 1) / 10)
        let worldLevel = (virtualLevel - 1) % 10 + 1
        let localLandmarks = CampaignBalance.landmarkWorldLevels.count {
            worldLevel >= $0
        }
        return completedWorlds * CampaignBalance.landmarkWorldLevels.count
            + localLandmarks
    }

    static func equivalentShieldWave(cycle: Int, levelNumber: Int) -> Int? {
        guard cycle > 0 else { return nil }
        let safeCycle = Double(cycle)
        let cycleStart = 15
            + Double(cycle - 1) * (32.6 + 6.9 * safeCycle)
        let perLevel = 0.4 + 0.2 * safeCycle
        return max(
            1,
            Int((cycleStart
                + perLevel * Double(max(0, levelNumber - 1))).rounded(.down))
        )
    }

    static func regularShieldExpectedHealthMultiplier(
        cycle: Int,
        levelNumber: Int
    ) -> Double {
        guard let wave = equivalentShieldWave(
            cycle: cycle,
            levelNumber: levelNumber
        ) else {
            return 1
        }
        return 1
            + EndlessRules.regularShieldSpawnChance(wave: wave)
                * EndlessRules.regularShieldHealthFraction(wave: wave)
    }

    static func bossShieldExpectedHealthMultiplier(
        cycle: Int,
        levelNumber: Int
    ) -> Double {
        guard let wave = equivalentShieldWave(
            cycle: cycle,
            levelNumber: levelNumber
        ) else {
            return 1
        }
        return 1
            + EndlessRules.bossShieldSpawnChance(wave: wave)
                * EndlessRules.bossShieldHealthFraction(wave: wave)
                * 3
    }

    static func scaledCompletionBonus(_ base: Int, cycle: Int) -> Int {
        guard cycle > 0 else { return max(0, base) }
        let scaled = Double(max(0, base))
            * (1 + 0.75 * Double(cycle))
        return Int((scaled / 5).rounded()) * 5
    }
}
