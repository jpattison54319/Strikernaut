import Foundation

enum CampaignBalance {
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
        let levelIndex = Double(level.number - 1)
        let isBossWave = safeWave == level.waveCount
        let isMegaBoss = level.hasBoss && isBossWave
        return CampaignWaveDefinition(
            number: safeWave,
            totalWaves: level.waveCount,
            duration: level.waveDuration,
            healthMultiplier: baseHealthMultiplier(level: level) * pow(1.15, waveIndex),
            damageMultiplier: (1 + levelIndex * 0.028) * pow(1.075, waveIndex),
            speedMultiplier: baseSpeedMultiplier(level: level) * (1 + waveIndex * 0.045),
            spawnInterval: max(0.52, level.spawnInterval * pow(0.91, waveIndex)),
            boss: isBossWave
                ? (isMegaBoss
                    ? GameContent.world(level.world).boss
                    : miniBoss(for: level, wave: safeWave))
                : nil,
            bossTier: isBossWave ? (isMegaBoss ? .megaBoss : .miniBoss) : nil
        )
    }

    static func bossHealthMultiplier(tier: CampaignBossTier, wave: Int) -> Double {
        switch tier {
        case .standard: 1
        case .miniBoss: 5.2 + Double(max(0, wave - 1)) * 0.45
        case .megaBoss: 1.20
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
        pow(1.20, Double(max(0, count)))
    }

    private static func baseHealthMultiplier(level: LevelDefinition) -> Double {
        if level.number == 1 { return 0.78 }
        return 0.92 * pow(1.046, Double(level.number - 1))
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
