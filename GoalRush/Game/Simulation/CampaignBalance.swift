import Foundation

enum CampaignBalance {
    static let bossArenaY = 0.70
    /// A Campaign draft is materially stronger than a small permanent-rank
    /// step. Through Ball and One-Two can nearly double useful field output,
    /// while Power Drive and Quick Release add 35% and about 22% respectively.
    /// Tuning later waves around 35% preserves a visible power-up advantage
    /// without letting the first good draft flatten the rest of the level.
    static let expectedDraftOffenseGrowth = 1.35
    /// Pierce and wide volleys dominate a crowd but do not multiply damage to
    /// one boss. Keep boss health tied to the smaller single-target draft gain.
    static let expectedBossDraftOffenseGrowth = 1.14
    static let landmarkWorldLevels = [5, 8, 10]
    static let representativeIncomingDamage = 14.0
    static let maximumEmptyFieldSpawnDelay = 0.55
    static let enemyStaggerInterval = 0.12

    static func waveCount(worldLevel: Int) -> Int {
        switch worldLevel {
        case ...3: 3
        case 4...7: 4
        default: 5
        }
    }

    static func wave(
        _ number: Int,
        for level: LevelDefinition,
        cycle: Int = 0
    ) -> CampaignWaveDefinition {
        let safeWave = min(max(number, 1), level.waveCount)
        let waveIndex = Double(safeWave - 1)
        let isBossWave = safeWave == level.waveCount
        let isMegaBoss = level.hasBoss && isBossWave
        let spawnInterval = spawnInterval(
            level: level,
            wave: safeWave,
            cycle: cycle
        )
        let uncappedSpeed = baseSpeedMultiplier(level: level, cycle: cycle)
            * (1 + waveIndex * 0.04)
        let speedMultiplier = cycle > 0
            ? min(2.25, uncappedSpeed)
            : uncappedSpeed
        return CampaignWaveDefinition(
            number: safeWave,
            totalWaves: level.waveCount,
            enemyQuota: isBossWave
                ? 1
                : regularEnemyQuota(wave: safeWave, for: level, cycle: cycle),
            healthMultiplier: regularHealthMultiplier(
                level: level,
                wave: safeWave,
                cycle: cycle
            ),
            damageMultiplier: damageMultiplier(
                level: level,
                wave: safeWave,
                cycle: cycle
            ),
            speedMultiplier: speedMultiplier,
            spawnInterval: spawnInterval,
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

    static func regularEnemyQuota(
        wave: Int,
        for level: LevelDefinition,
        cycle: Int = 0
    ) -> Int {
        let safeWave = min(max(wave, 1), level.waveCount)
        let worldIndex = WorldID.allCases.firstIndex(of: level.world) ?? 0
        let levelNumber = CampaignDifficulty.quotaLevel(
            cycle: cycle,
            levelNumber: level.number
        ) ?? Double(level.number)
        let base = 18
            + 2 * max(0, Int(levelNumber.rounded(.down)) - 1)
            + 3 * worldIndex
        let waveMultiplier = 1 + 0.18 * Double(max(0, safeWave - 1))
        return max(1, Int((Double(base) * waveMultiplier).rounded()))
    }

    static func enemyPackSize(
        wave: Int,
        for level: LevelDefinition,
        cycle: Int = 0
    ) -> Int {
        let safeWave = min(max(wave, 1), level.waveCount)
        let levelNumber = CampaignDifficulty.quotaLevel(
            cycle: cycle,
            levelNumber: level.number
        ) ?? Double(level.number)
        return min(
            16,
            1
                + max(0, Int(levelNumber.rounded(.down)) - 1) / 9
                + landmarkTier(worldLevel: level.worldLevel)
                + max(0, safeWave - 1)
        )
    }

    static func maximumActiveEnemies(
        wave: Int,
        for level: LevelDefinition,
        cycle: Int = 0
    ) -> Int {
        let levelNumber = CampaignDifficulty.quotaLevel(
            cycle: cycle,
            levelNumber: level.number
        ) ?? Double(level.number)
        return min(
            48,
            6
                + max(0, Int(levelNumber.rounded(.down)) - 1) / 2
                + landmarkTier(worldLevel: level.worldLevel)
                + 2 * max(0, wave - 1)
        )
    }

    /// Horde size can climb far beyond the number of readable projectiles.
    /// Ranged enemies still attack faster every level, while this cap prevents
    /// a large mixed pack from turning into an unavoidable solid wall.
    static func maximumHostileProjectiles(
        wave: Int,
        for level: LevelDefinition,
        cycle: Int = 0
    ) -> Int {
        let levelNumber = CampaignDifficulty.quotaLevel(
            cycle: cycle,
            levelNumber: level.number
        ) ?? Double(level.number)
        return min(
            10,
            3
                + max(0, Int(levelNumber.rounded(.down)) - 1) / 15
                + landmarkTier(worldLevel: level.worldLevel)
                + max(0, wave - 1) / 2
        )
    }

    static func reinforcementPulseSize(
        levelNumber: Int,
        cycle: Int = 0
    ) -> Int {
        let quotaLevel = CampaignDifficulty.quotaLevel(
            cycle: cycle,
            levelNumber: levelNumber
        ) ?? Double(levelNumber)
        return min(4, 2 + max(0, Int(quotaLevel.rounded(.down)) - 1) / 8)
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
            case .jupiter: 2.65
            case .saturn: 2.80
            case .uranus: 2.95
            case .neptune: 3.10
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
        pow(expectedDraftOffenseGrowth, Double(max(0, count)))
    }

    static func expectedBossOffenseMultiplier(afterUpgradeCount count: Int) -> Double {
        pow(expectedBossDraftOffenseGrowth, Double(max(0, count)))
    }

    static func cumulativeLandmarkCount(
        for level: LevelDefinition,
        cycle: Int = 0
    ) -> Int {
        if let count = CampaignDifficulty.landmarkCount(
            cycle: cycle,
            levelNumber: level.number
        ) {
            return count
        }
        let completedWorlds = max(0, (level.number - 1) / 10)
        let localLandmarks = landmarkWorldLevels.count {
            level.worldLevel >= $0
        }
        return completedWorlds * landmarkWorldLevels.count + localLandmarks
    }

    /// The equal-rank reference build used to tune Campaign. It is determined
    /// only by authored progress, never by the player's live loadout.
    ///
    /// Earth culminates at rank 4 so its back half teaches permanent
    /// investment. Later finales target ranks 5, 7, ... 15. Every level raises
    /// the reference, while Levels 5, 8, and 10 make the larger organic grind
    /// steps.
    static func targetPermanentRank(
        for level: LevelDefinition,
        cycle: Int = 0
    ) -> Double {
        if let rank = CampaignDifficulty.referenceRank(
            cycle: cycle,
            levelNumber: level.number
        ) {
            return rank
        }
        let worldIndex = WorldID.allCases.firstIndex(of: level.world) ?? 0
        let previousFinalRank = worldIndex == 1
            ? 4
            : 3 + 2 * Double(max(0, worldIndex - 1))
        let startRank = worldIndex == 0 ? 0 : previousFinalRank + 0.15
        let endRank = worldIndex == 0
            ? 4
            : 3 + 2 * Double(worldIndex)
        let fractions = [0.0, 0.08, 0.16, 0.25, 0.43, 0.52, 0.62, 0.79, 0.89, 1.0]
        let index = min(max(level.worldLevel, 1), fractions.count) - 1
        let fraction = fractions[index]
        return startRank + (endRank - startRank) * fraction
    }

    static func referenceDamagePerKick(
        for level: LevelDefinition,
        cycle: Int = 0
    ) -> Double {
        let rank = targetPermanentRank(for: level, cycle: cycle)
        let damage = referenceBallDamage(for: level, cycle: cycle)
        let expectedCriticalMultiplier = 1 + 0.05 + 0.03 * rank
        return damage * expectedCriticalMultiplier
    }

    static func referenceBallDamage(
        for level: LevelDefinition,
        cycle: Int = 0
    ) -> Double {
        10 * (1 + 0.10 * targetPermanentRank(for: level, cycle: cycle))
    }

    /// Expected single-target automatic-kick DPS for the reference build.
    /// Critical tiers have expectation `1 + criticalPower`, including overflow.
    static func referenceSingleTargetDPS(
        for level: LevelDefinition,
        cycle: Int = 0
    ) -> Double {
        let rank = targetPermanentRank(for: level, cycle: cycle)
        let cooldown = UpgradeRules.kickCooldown(for: rank)
        return referenceDamagePerKick(for: level, cycle: cycle) / cooldown
    }

    /// Boss health is reference DPS multiplied by a target time-to-defeat.
    /// The target rises across worlds so later bosses are tougher before their
    /// denser hazards, adds, and faster attacks are considered.
    static func bossHitPoints(
        tier: CampaignBossTier,
        wave: Int,
        for level: LevelDefinition,
        cycle: Int = 0
    ) -> Double {
        let draftAdjustedDPS = referenceSingleTargetDPS(
            for: level,
            cycle: cycle
        )
            * expectedBossOffenseMultiplier(afterUpgradeCount: max(0, wave - 1))
        let targetSeconds: Double = switch tier {
        case .standard:
            1
        case .miniBoss:
            7
                + 0.16 * max(
                    0,
                    (CampaignDifficulty.pressureLevel(
                        cycle: cycle,
                        levelNumber: level.number
                    ) ?? Double(level.number)) - 1
                )
                + 1.5 * Double(landmarkTier(worldLevel: level.worldLevel))
                + 0.5 * Double(max(0, wave - 3))
        case .megaBoss:
            megaBossTargetSeconds(for: level, cycle: cycle)
        }
        return draftAdjustedDPS * targetSeconds
    }

    private static func megaBossTargetSeconds(
        for level: LevelDefinition,
        cycle: Int
    ) -> Double {
        let base = 50
            + 1.5 * Double(WorldID.allCases.firstIndex(of: level.world) ?? 0)
        guard let pressure = CampaignDifficulty.pressureLevel(
            cycle: cycle,
            levelNumber: level.number
        ) else {
            return base
        }
        return 59 * (1 + 0.003 * max(0, pressure - 70))
    }

    static func attackCadenceMultiplier(
        level: LevelDefinition,
        wave: Int,
        cycle: Int = 0
    ) -> Double {
        let levelIndex = max(
            0,
            (CampaignDifficulty.pressureLevel(
                cycle: cycle,
                levelNumber: level.number
            ) ?? Double(level.number)) - 1
        )
        let landmarks = Double(cumulativeLandmarkCount(for: level, cycle: cycle))
        let waveIndex = Double(max(0, wave - 1))
        return 1 / (
            1
                + 0.006 * levelIndex
                + 0.015 * landmarks
                + 0.04 * waveIndex
        )
    }

    static func hostileProjectileSpeedMultiplier(
        level: LevelDefinition,
        wave: Int,
        cycle: Int = 0
    ) -> Double {
        let levelIndex = max(
            0,
            (CampaignDifficulty.pressureLevel(
                cycle: cycle,
                levelNumber: level.number
            ) ?? Double(level.number)) - 1
        )
        let value = 1
            + 0.006 * levelIndex
            + 0.012 * Double(cumulativeLandmarkCount(for: level, cycle: cycle))
            + 0.035 * Double(max(0, wave - 1))
        return cycle > 0 ? min(2.5, value) : value
    }

    static func bossSupportCapacity(for level: LevelDefinition) -> Int {
        let worldIndex = WorldID.allCases.firstIndex(of: level.world) ?? 0
        return min(
            6,
            2
                + worldIndex / 2
                + landmarkTier(worldLevel: level.worldLevel)
        )
    }

    static func bossSupportSpawnInterval(
        level: LevelDefinition,
        wave: Int,
        cycle: Int = 0
    ) -> TimeInterval {
        max(
            1.75,
            3.6 * attackCadenceMultiplier(
                level: level,
                wave: wave,
                cycle: cycle
            )
        )
    }

    /// Durability is independent from spawn density. Faster spawning and
    /// tougher enemies therefore compound instead of silently cancelling out.
    private static func regularHealthMultiplier(
        level: LevelDefinition,
        wave: Int,
        cycle: Int
    ) -> Double {
        let averageBaseHealth = level.enemies
            .map { CombatBalance.baseHealth($0) }
            .reduce(0, +) / Double(max(1, level.enemies.count))
        let openingDamageFraction = if cycle > 0 {
            4.0
                + 0.0003 * max(
                    0,
                    (CampaignDifficulty.pressureLevel(
                        cycle: cycle,
                        levelNumber: level.number
                    ) ?? 80) - 80
                )
                + 0.0003 * Double(
                    max(
                        0,
                        cumulativeLandmarkCount(
                            for: level,
                            cycle: cycle
                        ) - 24
                    )
                )
        } else if level.number < 5 {
            0.62 + 0.03 * Double(max(0, level.number - 1))
        } else {
            0.94
                + 0.0003 * max(
                    0,
                    (CampaignDifficulty.pressureLevel(
                        cycle: cycle,
                        levelNumber: level.number
                    ) ?? Double(level.number)) - 5
                )
                + 0.0003 * Double(
                    cumulativeLandmarkCount(for: level, cycle: cycle)
                )
        }
        let damageFraction = openingDamageFraction
            + 0.05 * Double(max(0, wave - 1))
        let targetAverageHealth = referenceBallDamage(for: level, cycle: cycle)
            * damageFraction
            * expectedOffenseMultiplier(afterUpgradeCount: max(0, wave - 1))
        return targetAverageHealth
            / averageBaseHealth
    }

    /// Actual post-cap damage rises every level. The authored raw damage is
    /// solved against baseline stamina so Conditioning remains a real survival
    /// upgrade instead of enemy damage silently cancelling the extra stamina.
    /// Exposure, spawn cadence, and hazard density never reduce severity.
    private static func damageMultiplier(
        level: LevelDefinition,
        wave: Int,
        cycle: Int
    ) -> Double {
        let levelIndex = max(
            0,
            (CampaignDifficulty.pressureLevel(
                cycle: cycle,
                levelNumber: level.number
            ) ?? Double(level.number)) - 1
        )
        let effectiveFraction =
            0.075
                + 0.002 * levelIndex
                + 0.0007 * Double(cumulativeLandmarkCount(for: level, cycle: cycle))
                + 0.005 * Double(max(0, wave - 1))
        let balanceStamina = 100.0
        let effectiveDamage = balanceStamina * min(0.245, effectiveFraction)
        let limit = balanceStamina * CombatBalance.incomingDamageLimitFraction
        let rawDamage = -limit * log1p(-effectiveDamage / limit)
        return rawDamage / representativeIncomingDamage
    }

    private static func baseSpeedMultiplier(
        level: LevelDefinition,
        cycle: Int
    ) -> Double {
        if cycle == 0, level.number == 1 { return 0.80 }
        let pressure = CampaignDifficulty.pressureLevel(
            cycle: cycle,
            levelNumber: level.number
        ) ?? Double(level.number)
        let value = pow(1.0065, max(0, pressure - 2))
            * pow(
                1.008,
                Double(cumulativeLandmarkCount(for: level, cycle: cycle))
            )
        return cycle > 0 ? min(2.25, value) : value
    }

    private static func spawnInterval(
        level: LevelDefinition,
        wave: Int,
        cycle: Int
    ) -> TimeInterval {
        let levelIndex = max(
            0,
            (CampaignDifficulty.pressureLevel(
                cycle: cycle,
                levelNumber: level.number
            ) ?? Double(level.number)) - 1
        )
        let pressureIndex =
            levelIndex
                + 1.5 * Double(cumulativeLandmarkCount(for: level, cycle: cycle))
                + openingCampaignPressureOffset(for: level)
        let continuousInterval = 1.55 * pow(0.9745, pressureIndex)
        let lateGameFloor = 0.60 * pow(0.9965, pressureIndex)
        let perEnemyInterval = max(continuousInterval, lateGameFloor)
            * pow(0.90, Double(max(0, wave - 1)))
        return max(
            0.32,
            perEnemyInterval * Double(
                enemyPackSize(wave: wave, for: level, cycle: cycle)
            )
        )
    }

    /// Earth has to teach permanent investment before the first world boss.
    /// This back-half ramp increases throughput instead of turning tutorial
    /// enemies into damage sponges, then remains part of the Campaign baseline.
    private static func openingCampaignPressureOffset(
        for level: LevelDefinition
    ) -> Double {
        switch level.number {
        case ...4: 0
        case 5: 1
        case 6: 2
        case 7: 3
        case 8: 5
        case 9: 7
        default: 8
        }
    }

    private static func miniBoss(for level: LevelDefinition, wave: Int) -> EnemyKind {
        let unlockedCount = min(level.enemies.count, max(1, wave))
        return level.enemies[max(0, unlockedCount - 1)]
    }
}
