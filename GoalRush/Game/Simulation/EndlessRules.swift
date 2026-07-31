import Foundation

enum EndlessRules {
    static let wavesPerWorld = 10
    static let worldClearTokenBonus = 325
    private static let baselineBallDamage = 10.0
    private static let baselineCriticalPower = 0.05
    private static let baselineKickCooldown = 1.12
    private static let baselineStamina = 100.0

    static var worldSequence: [WorldID] {
        let authoredWorlds = GameContent.worlds.map(\.id)
        return authoredWorlds.isEmpty ? [.earth] : authoredWorlds
    }

    static func world(for wave: Int) -> WorldID {
        let sequence = worldSequence
        return sequence[chapterIndex(for: wave) % sequence.count]
    }

    static func chapterIndex(for wave: Int) -> Int {
        max(0, wave - 1) / wavesPerWorld
    }

    static func waveInWorld(for wave: Int) -> Int {
        max(0, wave - 1) % wavesPerWorld + 1
    }

    static func worldTransition(after completedWave: Int) -> (from: WorldID, to: WorldID)? {
        let safeWave = max(1, completedWave)
        guard safeWave.isMultiple(of: wavesPerWorld) else { return nil }
        let from = world(for: safeWave)
        let to = world(for: safeWave + 1)
        guard from != to else { return nil }
        return (from, to)
    }

    static func isBossWave(_ wave: Int) -> Bool {
        max(1, wave).isMultiple(of: 5)
    }

    static func enemyQuota(wave: Int) -> Int {
        let safeWave = max(1, wave)
        let index = safeWave - 1
        return 18
            + Int((1.5 * Double(index)).rounded(.down))
            + 3 * chapterIndex(for: safeWave)
    }

    static func maximumActiveEnemies(wave: Int) -> Int {
        min(24, 7 + max(0, wave - 1) / 3)
    }

    static func maximumHostileProjectiles(wave: Int) -> Int {
        min(12, 4 + max(0, wave - 1) / 5)
    }

    static func startingOffenseFactor(stats: PlayerStats) -> Double {
        let damageRatio = max(0, stats.ballDamage) / baselineBallDamage
        let criticalRatio = max(0, 1 + stats.criticalChance)
            / (1 + baselineCriticalPower)
        let cadenceRatio = baselineKickCooldown
            / max(.leastNonzeroMagnitude, stats.kickCooldown)
        return sqrt(max(1, damageRatio * criticalRatio * cadenceRatio))
    }

    static func startingSurvivalFactor(stats: PlayerStats) -> Double {
        sqrt(max(1, max(0, stats.maxStamina) / baselineStamina))
    }

    static func healthMultiplier(
        wave: Int,
        startingOffenseFactor: Double = 1
    ) -> Double {
        let index = Double(max(0, wave - 1))
        let marsFinaleIndex = Double(wavesPerWorld * 3 - 1)
        let curve: Double
        if index <= marsFinaleIndex {
            curve = pow(1.075, index) * (1 + 0.0375 * index)
        } else {
            let marsFinaleHealth = pow(1.075, marsFinaleIndex)
                * (1 + 0.0375 * marsFinaleIndex)
            curve = marsFinaleHealth
                * pow(1.085, index - marsFinaleIndex)
                * (1 + 0.04 * index)
                / (1 + 0.04 * marsFinaleIndex)
        }
        return max(1, startingOffenseFactor)
            * curve
    }

    static func damageMultiplier(
        wave: Int,
        startingSurvivalFactor: Double = 1
    ) -> Double {
        let index = Double(max(0, wave - 1))
        let marsFinaleIndex = Double(wavesPerWorld * 3 - 1)
        let curve = if index <= marsFinaleIndex {
            pow(1.0425, index)
        } else {
            pow(1.0425, marsFinaleIndex)
                * pow(1.05, index - marsFinaleIndex)
        }
        return max(1, startingSurvivalFactor)
            * curve
    }

    static func speedMultiplier(wave: Int) -> Double {
        1 + log2(Double(max(1, wave)) + 1) * 0.11
    }

    static func attackCadenceMultiplier(wave: Int) -> Double {
        1 / (1 + 0.025 * Double(max(0, wave - 1)))
    }

    static func hostileProjectileSpeedMultiplier(wave: Int) -> Double {
        1 + 0.018 * Double(max(0, wave - 1))
    }

    static func spawnInterval(wave: Int) -> Double {
        max(0.22, 0.95 * pow(0.965, Double(max(0, wave - 1))))
    }

    static func packSize(wave: Int) -> Int {
        min(6, 1 + max(0, wave - 1) / 7)
    }

    static func enemyPool(wave: Int) -> [EnemyKind] {
        let ordered = GameContent.world(world(for: wave)).endlessEnemies
        let completedCircuits = chapterIndex(for: wave)
            / max(1, worldSequence.count)
        let count = completedCircuits > 0
            ? ordered.count
            : min(ordered.count, 1 + (waveInWorld(for: wave) - 1) / 2)
        return Array(ordered.prefix(count))
    }

    /// Endless bosses use their own durability curve rather than inheriting
    /// Campaign's world-finale multiplier. The opening boss is deliberately
    /// approachable after four drafts, while later bosses continue scaling
    /// without a terminal cap.
    static func bossHealthMultiplier(wave: Int) -> Double {
        0.70 + 0.015 * Double(max(0, wave - 5))
    }

    static func bossReinforcementWaveSize(wave: Int) -> Int {
        min(4, 2 + max(0, wave - 1) / 20)
    }

    static func bossDirectDamageWindow(wave: Int) -> TimeInterval {
        max(3.25, 5.0 - 0.025 * Double(max(0, wave - 5)))
    }

    static func regularShieldSpawnChance(wave: Int) -> Double {
        guard wave >= 11 else { return 0 }
        return 0.80 * (1 - exp(-Double(wave - 10) / 25))
    }

    static func regularShieldHealthFraction(wave: Int) -> Double {
        guard wave >= 11 else { return 0 }
        return 0.20 + 0.60 * (1 - exp(-Double(wave - 10) / 40))
    }

    static func bossShieldSpawnChance(wave: Int) -> Double {
        guard wave >= 25 else { return 0 }
        return 0.35 * (1 - exp(-Double(wave - 20) / 50))
    }

    static func bossShieldHealthFraction(wave: Int) -> Double {
        guard wave >= 25 else { return 0 }
        return 0.12 + 0.28 * (1 - exp(-Double(wave - 20) / 60))
    }

    static func waveClearScore(wave: Int) -> Int {
        500 * max(1, wave)
    }

    static func waveClearTokenBase(wave: Int) -> Int {
        let safeWave = max(1, wave)
        let worldClearBonus = safeWave.isMultiple(of: wavesPerWorld)
            ? worldClearTokenBonus
            : 0
        return max(4, safeWave * 2) + worldClearBonus
    }

    static func enemyTokenBaseFloor(baseValue: Int, wave: Int) -> Int {
        max(0, baseValue) + min(2, chapterIndex(for: wave))
    }
}
