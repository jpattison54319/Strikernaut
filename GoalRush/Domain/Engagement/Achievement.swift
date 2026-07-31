import Foundation

enum AchievementID: String, Codable, CaseIterable, Sendable {
    case firstClear
    case earthWorldClear, moonWorldClear, marsWorldClear
    case jupiterWorldClear, saturnWorldClear, uranusWorldClear, neptuneWorldClear
    case newGamePlusStarted, newGamePlusCleared
    case wave5, wave10, wave20, wave50, wave100
    case tokens1k, tokens10k
    case combo10, combo25
    case firstUpgrade, maxTrack
    case bronzePrestige, silverPrestige, goldPrestige, platinumPrestige, diamondPrestige
    case firstGear, fullEarthSet, fullMoonSet, fullMarsSet, fullRoster
    case aceAbilityDefeats, voltAbilityDefeats, novaAbilityDefeats, aegisAbilityDefeats
    case galeAbilityDefeats, haloAbilityDefeats, fluxAbilityDefeats, surgeAbilityDefeats
    case streak3, streak7
}

enum AchievementCatalog {
    static let characterAbilityDefeatGoal = 50

    /// Display order for the Trophies screen.
    static let ordered: [AchievementID] = [
        .firstClear, .firstUpgrade, .firstGear, .combo10, .streak3,
        .earthWorldClear, .aceAbilityDefeats, .wave5, .tokens1k, .fullEarthSet,
        .moonWorldClear, .voltAbilityDefeats, .wave10, .fullMoonSet,
        .marsWorldClear, .novaAbilityDefeats, .combo25, .tokens10k, .fullMarsSet,
        .maxTrack, .bronzePrestige, .aegisAbilityDefeats, .wave20, .streak7,
        .jupiterWorldClear, .galeAbilityDefeats, .silverPrestige,
        .saturnWorldClear, .haloAbilityDefeats, .wave50,
        .uranusWorldClear, .fluxAbilityDefeats, .goldPrestige,
        .neptuneWorldClear, .newGamePlusStarted, .surgeAbilityDefeats,
        .wave100, .fullRoster, .newGamePlusCleared,
        .platinumPrestige, .diamondPrestige
    ]

    /// Derives every earned achievement from progress (idempotent).
    static func evaluate(progress: PlayerProgress) -> Set<AchievementID> {
        var unlocked: Set<AchievementID> = []
        if progress.levelRecords[1]?.completed == true { unlocked.insert(.firstClear) }
        if progress.levelRecords[GameContent.world(.earth).finalLevel]?.completed == true { unlocked.insert(.earthWorldClear) }
        if progress.levelRecords[GameContent.world(.moon).finalLevel]?.completed == true { unlocked.insert(.moonWorldClear) }
        if progress.levelRecords[GameContent.world(.mars).finalLevel]?.completed == true { unlocked.insert(.marsWorldClear) }
        if progress.levelRecords[GameContent.world(.jupiter).finalLevel]?.completed == true { unlocked.insert(.jupiterWorldClear) }
        if progress.levelRecords[GameContent.world(.saturn).finalLevel]?.completed == true { unlocked.insert(.saturnWorldClear) }
        if progress.levelRecords[GameContent.world(.uranus).finalLevel]?.completed == true { unlocked.insert(.uranusWorldClear) }
        if progress.levelRecords[GameContent.world(.neptune).finalLevel]?.completed == true { unlocked.insert(.neptuneWorldClear) }
        if progress.campaignCycle >= 1 { unlocked.insert(.newGamePlusStarted) }
        if progress.highestCompletedCampaignCycle >= 1 {
            unlocked.insert(.newGamePlusCleared)
        }
        let bestWave = progress.endlessRecord.bestWave
        if bestWave >= 5 { unlocked.insert(.wave5) }
        if bestWave >= 10 { unlocked.insert(.wave10) }
        if bestWave >= 20 { unlocked.insert(.wave20) }
        if bestWave >= 50 { unlocked.insert(.wave50) }
        if bestWave >= 100 { unlocked.insert(.wave100) }
        if progress.lifetimeStats.totalTokensEarned >= 1_000 { unlocked.insert(.tokens1k) }
        if progress.lifetimeStats.totalTokensEarned >= 10_000 { unlocked.insert(.tokens10k) }
        if progress.lifetimeStats.bestCombo >= 10 { unlocked.insert(.combo10) }
        if progress.lifetimeStats.bestCombo >= 25 { unlocked.insert(.combo25) }
        if progress.lifetimeStats.upgradesPurchased >= 1 { unlocked.insert(.firstUpgrade) }
        if UpgradeTrack.allCases.contains(where: { progress.rank(for: $0) >= UpgradeRules.masteryRank }) { unlocked.insert(.maxTrack) }
        let highestPrestige = UpgradeTrack.allCases.map(progress.prestigeCount(for:)).max() ?? 0
        if highestPrestige >= UpgradePrestigeTier.bronze.rawValue { unlocked.insert(.bronzePrestige) }
        if highestPrestige >= UpgradePrestigeTier.silver.rawValue { unlocked.insert(.silverPrestige) }
        if highestPrestige >= UpgradePrestigeTier.gold.rawValue { unlocked.insert(.goldPrestige) }
        if highestPrestige >= UpgradePrestigeTier.platinum.rawValue { unlocked.insert(.platinumPrestige) }
        if highestPrestige >= UpgradePrestigeTier.diamond.rawValue { unlocked.insert(.diamondPrestige) }
        if progress.unlockedCharacters.count >= 2 { unlocked.insert(.firstGear) }
        if progress.unlockedCharacters.contains(.volt) { unlocked.insert(.fullEarthSet) }
        if progress.unlockedCharacters.contains(.nova) { unlocked.insert(.fullMoonSet) }
        if progress.unlockedCharacters.contains(.aegis) { unlocked.insert(.fullMarsSet) }
        if progress.unlockedCharacters.isSuperset(of: Set(CharacterID.allCases)) { unlocked.insert(.fullRoster) }
        for (character, achievement) in characterAbilityAchievements {
            if progress.lifetimeStats.abilityDefeats(for: character) >= characterAbilityDefeatGoal {
                unlocked.insert(achievement)
            }
        }
        if progress.dailyReward.streak >= 3 { unlocked.insert(.streak3) }
        if progress.dailyReward.streak >= 7 { unlocked.insert(.streak7) }
        return unlocked
    }

    static func progress(
        for id: AchievementID,
        playerProgress: PlayerProgress
    ) -> AchievementProgress? {
        let lifetime = playerProgress.lifetimeStats
        let bestWave = playerProgress.endlessRecord.bestWave
        let highestRank = UpgradeTrack.allCases.map(playerProgress.rank(for:)).max() ?? 0
        let highestPrestige = UpgradeTrack.allCases.map(playerProgress.prestigeCount(for:)).max() ?? 0

        return switch id {
        case .wave5: AchievementProgress(current: bestWave, goal: 5)
        case .wave10: AchievementProgress(current: bestWave, goal: 10)
        case .wave20: AchievementProgress(current: bestWave, goal: 20)
        case .wave50: AchievementProgress(current: bestWave, goal: 50)
        case .wave100: AchievementProgress(current: bestWave, goal: 100)
        case .tokens1k: AchievementProgress(current: lifetime.totalTokensEarned, goal: 1_000)
        case .tokens10k: AchievementProgress(current: lifetime.totalTokensEarned, goal: 10_000)
        case .combo10: AchievementProgress(current: lifetime.bestCombo, goal: 10)
        case .combo25: AchievementProgress(current: lifetime.bestCombo, goal: 25)
        case .firstUpgrade: AchievementProgress(current: lifetime.upgradesPurchased, goal: 1)
        case .maxTrack: AchievementProgress(current: highestRank, goal: UpgradeRules.masteryRank)
        case .bronzePrestige:
            AchievementProgress(current: highestPrestige, goal: UpgradePrestigeTier.bronze.rawValue)
        case .silverPrestige:
            AchievementProgress(current: highestPrestige, goal: UpgradePrestigeTier.silver.rawValue)
        case .goldPrestige:
            AchievementProgress(current: highestPrestige, goal: UpgradePrestigeTier.gold.rawValue)
        case .platinumPrestige:
            AchievementProgress(current: highestPrestige, goal: UpgradePrestigeTier.platinum.rawValue)
        case .diamondPrestige:
            AchievementProgress(current: highestPrestige, goal: UpgradePrestigeTier.diamond.rawValue)
        case .firstGear:
            AchievementProgress(current: max(0, playerProgress.unlockedCharacters.count - 1), goal: 1)
        case .fullRoster:
            AchievementProgress(
                current: playerProgress.unlockedCharacters.intersection(Set(CharacterID.allCases)).count,
                goal: CharacterID.allCases.count
            )
        case .aceAbilityDefeats:
            abilityProgress(for: .ace, lifetime: lifetime)
        case .voltAbilityDefeats:
            abilityProgress(for: .volt, lifetime: lifetime)
        case .novaAbilityDefeats:
            abilityProgress(for: .nova, lifetime: lifetime)
        case .aegisAbilityDefeats:
            abilityProgress(for: .aegis, lifetime: lifetime)
        case .galeAbilityDefeats:
            abilityProgress(for: .gale, lifetime: lifetime)
        case .haloAbilityDefeats:
            abilityProgress(for: .halo, lifetime: lifetime)
        case .fluxAbilityDefeats:
            abilityProgress(for: .flux, lifetime: lifetime)
        case .surgeAbilityDefeats:
            abilityProgress(for: .surge, lifetime: lifetime)
        case .streak3:
            AchievementProgress(current: playerProgress.dailyReward.streak, goal: 3)
        case .streak7:
            AchievementProgress(current: playerProgress.dailyReward.streak, goal: 7)
        case .newGamePlusCleared:
            AchievementProgress(
                current: playerProgress.highestCompletedCampaignCycle >= 1
                    ? GameContent.levels.count
                    : playerProgress.currentCampaignClears.count,
                goal: GameContent.levels.count
            )
        case .firstClear, .earthWorldClear, .moonWorldClear, .marsWorldClear,
             .jupiterWorldClear, .saturnWorldClear, .uranusWorldClear, .neptuneWorldClear,
             .newGamePlusStarted, .fullEarthSet, .fullMoonSet, .fullMarsSet:
            nil
        }
    }

    static func closestIncomplete(
        in playerProgress: PlayerProgress,
        limit: Int = 3
    ) -> [AchievementID] {
        guard limit > 0 else { return [] }
        let unlocked = playerProgress.unlockedAchievements.union(
            evaluate(progress: playerProgress)
        )
        let displayOrder = Dictionary(
            uniqueKeysWithValues: ordered.enumerated().map { ($1, $0) }
        )

        return Array(
            ordered
                .filter { !unlocked.contains($0) }
                .sorted { lhs, rhs in
                    let lhsProgress = progress(
                        for: lhs,
                        playerProgress: playerProgress
                    )
                    let rhsProgress = progress(
                        for: rhs,
                        playerProgress: playerProgress
                    )

                    if lhsProgress?.fraction != rhsProgress?.fraction {
                        return (lhsProgress?.fraction ?? -1)
                            > (rhsProgress?.fraction ?? -1)
                    }

                    let lhsRemaining = lhsProgress.map {
                        max(0, $0.goal - $0.completedAmount)
                    } ?? .max
                    let rhsRemaining = rhsProgress.map {
                        max(0, $0.goal - $0.completedAmount)
                    } ?? .max
                    if lhsRemaining != rhsRemaining {
                        return lhsRemaining < rhsRemaining
                    }

                    return displayOrder[lhs, default: .max]
                        < displayOrder[rhs, default: .max]
                }
                .prefix(limit)
        )
    }

    static func title(for id: AchievementID) -> String {
        switch id {
        case .firstClear: "First Whistle"
        case .earthWorldClear: "Earth Champion"
        case .moonWorldClear: "Lunar Champion"
        case .marsWorldClear: "Mars Conqueror"
        case .jupiterWorldClear: "Stormbreaker"
        case .saturnWorldClear: "Ringmaster"
        case .uranusWorldClear: "Axis Victor"
        case .neptuneWorldClear: "Depths Conquered"
        case .newGamePlusStarted: "Back to Earth"
        case .newGamePlusCleared: "Ascendant Champion"
        case .wave5: "Warming Up"
        case .wave10: "Double Digits"
        case .wave20: "Unstoppable"
        case .wave50: "Deep Run"
        case .wave100: "Beyond the Horizon"
        case .tokens1k: "Token Collector"
        case .tokens10k: "Token Tycoon"
        case .combo10: "On Fire"
        case .combo25: "Inferno"
        case .firstUpgrade: "First Steps"
        case .maxTrack: "Building Momentum"
        case .bronzePrestige: "Bronze Standard"
        case .silverPrestige: "Silver Standard"
        case .goldPrestige: "Golden Standard"
        case .platinumPrestige: "Platinum Standard"
        case .diamondPrestige: "Diamond Standard"
        case .firstGear: "New Teammate"
        case .fullEarthSet: "Volt Unleashed"
        case .fullMoonSet: "Nova Unleashed"
        case .fullMarsSet: "Aegis Unleashed"
        case .fullRoster: "Full Roster"
        case .aceAbilityDefeats: "Bank Shot"
        case .voltAbilityDefeats: "Frozen Finish"
        case .novaAbilityDefeats: "Meteor Shower"
        case .aegisAbilityDefeats: "Shock and Awe"
        case .galeAbilityDefeats: "Storm Chaser"
        case .haloAbilityDefeats: "Full Orbit"
        case .fluxAbilityDefeats: "No Escape"
        case .surgeAbilityDefeats: "High-Water Mark"
        case .streak3: "Regular"
        case .streak7: "Dedicated"
        }
    }

    static func subtitle(for id: AchievementID) -> String {
        switch id {
        case .firstClear: "Clear your first level"
        case .earthWorldClear: "Clear the Earth world"
        case .moonWorldClear: "Clear the Moon world"
        case .marsWorldClear: "Clear the Mars world"
        case .jupiterWorldClear: "Clear the Jupiter world"
        case .saturnWorldClear: "Clear the Saturn world"
        case .uranusWorldClear: "Clear the Uranus world"
        case .neptuneWorldClear: "Clear the Neptune world"
        case .newGamePlusStarted: "Begin New Game+"
        case .newGamePlusCleared: "Clear every world in New Game+"
        case .wave5: "Reach wave 5 in Endless"
        case .wave10: "Reach wave 10 in Endless"
        case .wave20: "Reach wave 20 in Endless"
        case .wave50: "Reach wave 50 in Endless"
        case .wave100: "Reach wave 100 in Endless"
        case .tokens1k: "Earn 1,000 tokens in runs"
        case .tokens10k: "Earn 10,000 tokens in runs"
        case .combo10: "Reach a ×10 combo"
        case .combo25: "Reach a ×25 combo"
        case .firstUpgrade: "Buy your first upgrade"
        case .maxTrack: "Reach rank 5 in any upgrade track"
        case .bronzePrestige: "Earn Bronze on any upgrade track"
        case .silverPrestige: "Earn Silver on any upgrade track"
        case .goldPrestige: "Earn Gold on any upgrade track"
        case .platinumPrestige: "Earn Platinum on any upgrade track"
        case .diamondPrestige: "Earn Diamond on any upgrade track"
        case .firstGear: "Unlock your first new character"
        case .fullEarthSet: "Unlock Volt"
        case .fullMoonSet: "Unlock Nova"
        case .fullMarsSet: "Unlock Aegis"
        case .fullRoster: "Unlock every character"
        case .aceAbilityDefeats: "Defeat 50 enemies with Pinball Blitz"
        case .voltAbilityDefeats: "Defeat 50 enemies during Time Break"
        case .novaAbilityDefeats: "Defeat 50 enemies with Meteor Volley"
        case .aegisAbilityDefeats: "Defeat 50 enemies with Last Stand shockwaves"
        case .galeAbilityDefeats: "Defeat 50 enemies with Stormbreak"
        case .haloAbilityDefeats: "Defeat 50 enemies with Orbital Crown"
        case .fluxAbilityDefeats: "Defeat 50 enemies with Polar Lockdown traps"
        case .surgeAbilityDefeats: "Defeat 50 enemies with Tidal Break"
        case .streak3: "Claim 3 daily rewards in a row"
        case .streak7: "Claim 7 daily rewards in a row"
        }
    }

    static func icon(for id: AchievementID) -> String {
        switch id {
        case .firstClear: "flag.checkered"
        case .earthWorldClear: "globe.americas.fill"
        case .moonWorldClear: "moon.stars.fill"
        case .marsWorldClear: "circle.grid.cross.fill"
        case .jupiterWorldClear: "cloud.bolt.fill"
        case .saturnWorldClear: "circle.dashed"
        case .uranusWorldClear: "snowflake"
        case .neptuneWorldClear: "water.waves"
        case .newGamePlusStarted: "arrow.clockwise.circle.fill"
        case .newGamePlusCleared: "trophy.fill"
        case .wave5, .wave10, .wave20, .wave50, .wave100: "infinity"
        case .tokens1k, .tokens10k: "hexagon.fill"
        case .combo10, .combo25: "bolt.fill"
        case .firstUpgrade: "arrow.up.circle.fill"
        case .maxTrack: "star.fill"
        case .bronzePrestige, .silverPrestige, .goldPrestige, .platinumPrestige,
             .diamondPrestige: "medal.fill"
        case .firstGear: "person.crop.circle.badge.plus"
        case .fullEarthSet, .fullMoonSet, .fullMarsSet, .fullRoster: "crown.fill"
        case .aceAbilityDefeats: "circle.hexagongrid.fill"
        case .voltAbilityDefeats: "timer"
        case .novaAbilityDefeats: "meteor.fill"
        case .aegisAbilityDefeats: "shield.fill"
        case .galeAbilityDefeats: "wind"
        case .haloAbilityDefeats: "circle.dashed"
        case .fluxAbilityDefeats: "wave.3.right"
        case .surgeAbilityDefeats: "water.waves"
        case .streak3, .streak7: "flame.fill"
        }
    }

    private static let characterAbilityAchievements: [CharacterID: AchievementID] = [
        .ace: .aceAbilityDefeats,
        .volt: .voltAbilityDefeats,
        .nova: .novaAbilityDefeats,
        .aegis: .aegisAbilityDefeats,
        .gale: .galeAbilityDefeats,
        .halo: .haloAbilityDefeats,
        .flux: .fluxAbilityDefeats,
        .surge: .surgeAbilityDefeats
    ]

    private static func abilityProgress(
        for character: CharacterID,
        lifetime: LifetimeStats
    ) -> AchievementProgress {
        AchievementProgress(
            current: lifetime.abilityDefeats(for: character),
            goal: characterAbilityDefeatGoal
        )
    }
}
