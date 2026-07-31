import Foundation

/// Shared, player-independent combat values used by both runtime simulation and
/// offline economy projections. Keeping these values here prevents reward and
/// difficulty calculations from silently describing different enemies.
enum CombatBalance {
    static let baselineStamina = 100.0
    static let incomingDamageLimitFraction = 0.25

    static func baseHealth(_ kind: EnemyKind) -> Double {
        switch kind {
        case .coneRunner, .regolithRunner, .dustSprite, .cloudRunner, .ringRunner,
             .frostSprinter, .mistRunner:
            10
        case .dummyDefender, .eclipseKeeper, .roverRaider, .pressureBrute,
             .iceMason, .tiltBrute, .currentBrute:
            24
        case .tackleBot, .lunarHopper, .craterCrawler, .vortexSkimmer,
             .shepherdDrone, .auroraDrifter, .squallRay:
            18
        case .keeperDrone, .orbitDrone, .saucerKeeper, .stormKeeper,
             .haloKeeper, .polarKeeper, .tridentKeeper:
            42
        case .ballLauncher, .gravityStriker, .plasmaStriker, .boltStriker,
             .shardStriker, .magnetStriker, .pressureStriker:
            28
        case .titanKeeper:
            720
        case .lunarWarden:
            820
        case .marsColossus:
            900
        case .tempestRegent:
            1_020
        case .crownSovereign:
            1_150
        case .axisPrime:
            1_300
        case .abyssalMonarch:
            1_480
        }
    }

    static func tokenValue(_ kind: EnemyKind) -> Int {
        switch kind {
        case .coneRunner, .regolithRunner, .dustSprite, .cloudRunner, .ringRunner,
             .frostSprinter, .mistRunner:
            2
        case .dummyDefender, .eclipseKeeper, .roverRaider, .pressureBrute,
             .iceMason, .tiltBrute, .currentBrute:
            4
        case .tackleBot, .lunarHopper, .craterCrawler, .vortexSkimmer,
             .shepherdDrone, .auroraDrifter, .squallRay:
            5
        case .keeperDrone, .orbitDrone, .saucerKeeper, .stormKeeper,
             .haloKeeper, .polarKeeper, .tridentKeeper:
            7
        case .ballLauncher, .gravityStriker, .plasmaStriker, .boltStriker,
             .shardStriker, .magnetStriker, .pressureStriker:
            8
        case .titanKeeper:
            150
        case .lunarWarden:
            165
        case .marsColossus:
            180
        case .tempestRegent:
            200
        case .crownSovereign:
            220
        case .axisPrime:
            240
        case .abyssalMonarch:
            265
        }
    }

    /// Smoothly approaches 25% of baseline stamina instead of snapping at it.
    ///
    /// `effective = L * (1 - exp(-raw / L))`, where
    /// `L = 0.25 * min(maxStamina, baselineStamina)`.
    ///
    /// Small hits remain nearly unchanged because the derivative at zero is 1,
    /// while arbitrarily large single sources can never exceed `L`. Conditioning
    /// therefore buys more actual hits instead of also raising the damage cap.
    static func effectiveIncomingDamage(
        rawDamage: Double,
        maxStamina: Double
    ) -> Double {
        let raw = max(0, rawDamage)
        let limit = min(max(0, maxStamina), baselineStamina)
            * incomingDamageLimitFraction
        guard raw > 0, limit > 0 else { return 0 }
        return limit * (1 - exp(-raw / limit))
    }
}

/// Keeps character supers at a stable cadence as wave quotas grow.
///
/// A reference wave contains 1.25 full charges, so the first super becomes
/// available around 80% objective progress. Boss damage can contribute at most
/// half a charge across the full health bar. Ultimate-origin damage is excluded
/// by the simulation so an ability cannot recharge itself.
enum CharacterAbilityChargeBalance {
    static let fullCharge = 100.0
    static let targetChargesPerWave = 1.25
    static let fieldObjectChargeFraction = 0.25
    static let bossDamageChargeBudget = 50.0

    static func enemyDefeatCharge(referenceQuota: Int) -> Double {
        fullCharge
            * targetChargesPerWave
            / Double(max(1, referenceQuota))
    }

    static func fieldObjectDefeatCharge(referenceQuota: Int) -> Double {
        enemyDefeatCharge(referenceQuota: referenceQuota)
            * fieldObjectChargeFraction
    }

    static func bossDamageCharge(
        damage: Double,
        maximumHitPoints: Double
    ) -> Double {
        guard maximumHitPoints > 0 else { return 0 }
        return bossDamageChargeBudget
            * min(max(0, damage), maximumHitPoints)
            / maximumHitPoints
    }
}

/// Token formulas shared by Campaign, Endless, UI presentation, and balance
/// tests. Projections intentionally exclude optional objects and random mission
/// rewards, so they describe the repeatable progression floor.
enum EconomyBalance {
    static let campaignWorldRewardGrowth = 1.55
    static let campaignLevelRewardGrowth = 0.06
    static let campaignBossRewardMultiplier = 1.25
    static let campaignReplayFraction = 0.42
    static let endlessRewardExponent = 0.32
    static let goldenGoalLogCoefficient = 0.42

    static func campaignFirstClearBonus(
        world: WorldID,
        worldLevel: Int,
        hasBoss: Bool
    ) -> Int {
        let worldIndex = Double(WorldID.allCases.firstIndex(of: world) ?? 0)
        let levelIndex = Double(max(0, worldLevel - 1))
        let bossMultiplier = hasBoss ? campaignBossRewardMultiplier : 1
        let raw = 100
            * pow(campaignWorldRewardGrowth, worldIndex)
            * (1 + campaignLevelRewardGrowth * levelIndex)
            * bossMultiplier
        return rounded(raw, toMultipleOf: 5)
    }

    static func campaignReplayBonus(
        world: WorldID,
        worldLevel: Int,
        hasBoss: Bool
    ) -> Int {
        rounded(
            Double(campaignFirstClearBonus(
                world: world,
                worldLevel: worldLevel,
                hasBoss: hasBoss
            )) * campaignReplayFraction,
            toMultipleOf: 5
        )
    }

    /// Endless reward growth is uncapped but sublinear:
    /// `(1 + (wave - 1) / 10)^0.32`.
    static func endlessWaveRewardMultiplier(wave: Int) -> Double {
        pow(
            1 + Double(max(0, wave - 1)) / 10,
            endlessRewardExponent
        )
    }

    /// Golden Goal has diminishing returns while remaining uncapped:
    /// `1 + 0.42 * ln(1 + rank)`.
    static func goldenGoalMultiplier(rank: Int) -> Double {
        1 + goldenGoalLogCoefficient * log1p(Double(max(0, rank)))
    }

    static func tokenReward(
        baseValue: Int,
        isEndless: Bool,
        wave: Int,
        goldenGoalRank: Int,
        playerMultiplier: Double = 1
    ) -> Int {
        let waveMultiplier = isEndless
            ? endlessWaveRewardMultiplier(wave: wave)
            : 1
        let value = Double(max(0, baseValue))
            * max(0, playerMultiplier)
            * goldenGoalMultiplier(rank: goldenGoalRank)
            * waveMultiplier
        return max(1, Int(value.rounded()))
    }

    static func expectedCampaignCombatTokens(for level: LevelDefinition) -> Double {
        let averageEnemyValue = level.enemies
            .map { Double(CombatBalance.tokenValue($0)) }
            .reduce(0, +) / Double(max(1, level.enemies.count))
        let regularWaveValue = (1..<level.waveCount).reduce(0.0) { total, wave in
            total + Double(CampaignBalance.regularEnemyQuota(wave: wave, for: level))
                * averageEnemyValue
        }
        let finalWave = CampaignBalance.wave(level.waveCount, for: level)
        let bossValue = finalWave.boss.map { boss in
            let base = CombatBalance.tokenValue(boss)
            return Double(finalWave.bossTier == .miniBoss ? base * 5 : base)
        } ?? 0
        return regularWaveValue + bossValue
    }

    static func expectedCampaignTokens(
        throughLevel levelNumber: Int,
        includeFirstClearBonuses: Bool = true
    ) -> Double {
        GameContent.levels
            .prefix(max(0, min(levelNumber, GameContent.levels.count)))
            .reduce(0) { total, level in
                total
                    + expectedCampaignCombatTokens(for: level)
                    + (includeFirstClearBonuses ? Double(level.firstClearBonus) : 0)
            }
    }

    static func expectedEndlessTokens(
        throughWave finalWave: Int,
        goldenGoalRank: Int = 0
    ) -> Double {
        guard finalWave > 0 else { return 0 }
        return (1...finalWave).reduce(0) { total, wave in
            let combatReward: Double
            if EndlessRules.isBossWave(wave) {
                let boss = GameContent.world(EndlessRules.world(for: wave)).boss
                combatReward = Double(tokenReward(
                    baseValue: CombatBalance.tokenValue(boss),
                    isEndless: true,
                    wave: wave,
                    goldenGoalRank: goldenGoalRank
                ))
            } else {
                let pool = EndlessRules.enemyPool(wave: wave)
                let averageReward = pool
                    .map {
                        Double(tokenReward(
                            baseValue: CombatBalance.tokenValue($0),
                            isEndless: true,
                            wave: wave,
                            goldenGoalRank: goldenGoalRank
                        ))
                    }
                    .reduce(0, +) / Double(max(1, pool.count))
                combatReward = Double(EndlessRules.enemyQuota(wave: wave))
                    * averageReward
            }
            let clearReward = tokenReward(
                baseValue: EndlessRules.waveClearTokenBase(wave: wave),
                isEndless: true,
                wave: wave,
                goldenGoalRank: goldenGoalRank
            )
            return total + combatReward + Double(clearReward)
        }
    }

    private static func rounded(_ value: Double, toMultipleOf multiple: Int) -> Int {
        Int((value / Double(multiple)).rounded()) * multiple
    }
}
