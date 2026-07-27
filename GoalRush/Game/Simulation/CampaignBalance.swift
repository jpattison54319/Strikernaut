import Foundation

enum CampaignBalance {
    static let bossArenaY = 0.70
    static let waveHealthGrowth = 1.15
    static let landmarkHealthGrowth = 1.08
    static let landmarkDamageGrowth = 1.025
    static let landmarkSpawnPressure = 0.96

    static func waveCount(worldLevel: Int) -> Int {
        switch worldLevel {
        case ...3: 3
        case 4...7: 4
        default: 5
        }
    }

    static func wave(_ number: Int, for level: LevelDefinition) -> CampaignWaveDefinition {
        let safeWave = min(max(number, 1), level.waveCount)
        let waveIndex = Double(safeWave - 1)
        let worldLevelIndex = Double(level.worldLevel - 1)
        let landmarkIndex = Double(landmarkTier(worldLevel: level.worldLevel))
        let worldIndex = Double(WorldID.allCases.firstIndex(of: level.world) ?? 0)
        let isBossWave = safeWave == level.waveCount
        let isMegaBoss = level.hasBoss && isBossWave
        return CampaignWaveDefinition(
            number: safeWave,
            totalWaves: level.waveCount,
            enemyQuota: isBossWave ? 1 : regularEnemyQuota(wave: safeWave, for: level),
            healthMultiplier: baseHealthMultiplier(level: level)
                * pow(landmarkHealthGrowth, landmarkIndex)
                * pow(waveHealthGrowth, waveIndex),
            damageMultiplier: baseDamageMultiplier(world: level.world)
                * (1 + worldLevelIndex * 0.015)
                * pow(landmarkDamageGrowth, landmarkIndex)
                * pow(1.07, waveIndex),
            speedMultiplier: baseSpeedMultiplier(level: level)
                * pow(1.10, worldIndex)
                * (1 + waveIndex * 0.05),
            spawnInterval: max(
                0.60,
                continuousSpawnInterval(levelNumber: level.number)
                    * pow(0.90, worldIndex)
                    * pow(landmarkSpawnPressure, landmarkIndex)
                    * pow(0.91, waveIndex)
            ),
            boss: isBossWave
                ? (isMegaBoss
                    ? GameContent.world(level.world).boss
                    : miniBoss(for: level, wave: safeWave))
                : nil,
            bossTier: isBossWave ? (isMegaBoss ? .megaBoss : .miniBoss) : nil
        )
    }

    static func landmarkTier(worldLevel: Int) -> Int {
        switch worldLevel {
        case ...4: 0
        case 5...7: 1
        default: 2
        }
    }

    static func regularEnemyQuota(wave: Int, for level: LevelDefinition) -> Int {
        let safeWave = min(max(wave, 1), level.waveCount)
        let worldIndex = WorldID.allCases.firstIndex(of: level.world) ?? 0
        let base = 18
            + Int((0.9 * Double(max(0, level.number - 1))).rounded())
            + 3 * worldIndex
        let waveMultiplier = 1 + 0.12 * Double(max(0, safeWave - 1))
        return max(1, Int((Double(base) * waveMultiplier).rounded()))
    }

    static func maximumActiveEnemies(wave: Int, world: WorldID) -> Int {
        let worldIndex = WorldID.allCases.firstIndex(of: world) ?? 0
        return min(8, 4 + worldIndex + max(0, wave - 1) / 2)
    }

    static func reinforcementPulseSize(levelNumber: Int) -> Int {
        min(4, 2 + max(0, levelNumber - 1) / 8)
    }

    static func bossHealthMultiplier(
        tier: CampaignBossTier,
        wave: Int,
        world: WorldID
    ) -> Double {
        switch tier {
        case .standard: 1
        case .miniBoss: 5.2 + Double(max(0, wave - 1)) * 0.45
        case .megaBoss:
            switch world {
            case .earth: 2.50
            case .moon: 2.30
            case .mars: 2.50
            }
        }
    }

    static func bossScale(tier: CampaignBossTier) -> Double {
        switch tier {
        case .standard: 1
        case .miniBoss: 1.52
        case .megaBoss: 1.90
        }
    }

    static func bossMovementRate(tier: CampaignBossTier) -> Double {
        switch tier {
        case .standard: 1
        case .miniBoss: 0.52
        case .megaBoss: 0.31
        }
    }

    static func expectedOffenseMultiplier(afterUpgradeCount count: Int) -> Double {
        pow(1.14, Double(max(0, count)))
    }

    private static func continuousSpawnInterval(levelNumber: Int) -> Double {
        1.55 * pow(0.985, Double(max(0, levelNumber - 1)))
    }

    private static func baseHealthMultiplier(level: LevelDefinition) -> Double {
        if level.number == 1 { return 0.78 }
        let worldBase = switch level.world {
        case .earth: 0.92
        case .moon: 1.60
        case .mars: 2.80
        }
        return worldBase * pow(1.030, Double(level.worldLevel - 1))
    }

    private static func baseDamageMultiplier(world: WorldID) -> Double {
        switch world {
        case .earth: 1
        case .moon: 1.34
        case .mars: 1.75
        }
    }

    private static func baseSpeedMultiplier(level: LevelDefinition) -> Double {
        if level.number == 1 { return 0.80 }
        return 1 + min(0.34, Double(level.number - 1) * 0.018)
    }

    private static func miniBoss(for level: LevelDefinition, wave: Int) -> EnemyKind {
        let unlockedCount = min(level.enemies.count, max(1, wave))
        return level.enemies[max(0, unlockedCount - 1)]
    }
}
