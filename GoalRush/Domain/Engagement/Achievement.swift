import Foundation

enum AchievementID: String, Codable, CaseIterable, Sendable {
    case firstClear, earthWorldClear, marsWorldClear
    case wave5, wave10, wave20
    case tokens1k, tokens10k
    case combo10, combo25
    case firstUpgrade, maxTrack
    case firstGear, fullEarthSet, fullMarsSet
    case streak3, streak7
}

enum AchievementCatalog {
    /// Display order for the Trophies screen.
    static let ordered: [AchievementID] = [
        .firstClear, .firstUpgrade, .firstGear, .combo10, .streak3,
        .earthWorldClear, .wave5, .tokens1k, .fullEarthSet,
        .marsWorldClear, .wave10, .combo25, .tokens10k, .fullMarsSet,
        .wave20, .maxTrack, .streak7
    ]

    /// Derives every earned achievement from progress (idempotent).
    static func evaluate(progress: PlayerProgress) -> Set<AchievementID> {
        var unlocked: Set<AchievementID> = []
        if progress.levelRecords[1]?.completed == true { unlocked.insert(.firstClear) }
        if progress.levelRecords[GameContent.world(.earth).finalLevel]?.completed == true { unlocked.insert(.earthWorldClear) }
        if progress.levelRecords[GameContent.world(.mars).finalLevel]?.completed == true { unlocked.insert(.marsWorldClear) }
        let bestWave = progress.endlessRecords.values.map(\.bestWave).max() ?? 0
        if bestWave >= 5 { unlocked.insert(.wave5) }
        if bestWave >= 10 { unlocked.insert(.wave10) }
        if bestWave >= 20 { unlocked.insert(.wave20) }
        if progress.lifetimeStats.totalTokensEarned >= 1_000 { unlocked.insert(.tokens1k) }
        if progress.lifetimeStats.totalTokensEarned >= 10_000 { unlocked.insert(.tokens10k) }
        if progress.lifetimeStats.bestCombo >= 10 { unlocked.insert(.combo10) }
        if progress.lifetimeStats.bestCombo >= 25 { unlocked.insert(.combo25) }
        if progress.lifetimeStats.upgradesPurchased >= 1 { unlocked.insert(.firstUpgrade) }
        if UpgradeTrack.allCases.contains(where: { progress.rank(for: $0) >= UpgradeRules.masteryRank }) { unlocked.insert(.maxTrack) }
        if progress.unlockedCharacters.count >= 2 { unlocked.insert(.firstGear) }
        if progress.unlockedCharacters.contains(.volt) { unlocked.insert(.fullEarthSet) }
        if progress.unlockedCharacters.contains(.aegis) { unlocked.insert(.fullMarsSet) }
        if progress.dailyReward.streak >= 3 { unlocked.insert(.streak3) }
        if progress.dailyReward.streak >= 7 { unlocked.insert(.streak7) }
        return unlocked
    }

    static func title(for id: AchievementID) -> String {
        switch id {
        case .firstClear: "First Whistle"
        case .earthWorldClear: "Earth Champion"
        case .marsWorldClear: "Mars Conqueror"
        case .wave5: "Warming Up"
        case .wave10: "Double Digits"
        case .wave20: "Unstoppable"
        case .tokens1k: "Token Collector"
        case .tokens10k: "Token Tycoon"
        case .combo10: "On Fire"
        case .combo25: "Inferno"
        case .firstUpgrade: "First Steps"
        case .maxTrack: "Peak Performance"
        case .firstGear: "New Teammate"
        case .fullEarthSet: "Volt Unleashed"
        case .fullMarsSet: "Full Roster"
        case .streak3: "Regular"
        case .streak7: "Dedicated"
        }
    }

    static func subtitle(for id: AchievementID) -> String {
        switch id {
        case .firstClear: "Clear your first level"
        case .earthWorldClear: "Clear the Earth world"
        case .marsWorldClear: "Clear the Mars world"
        case .wave5: "Reach wave 5 in Endless"
        case .wave10: "Reach wave 10 in Endless"
        case .wave20: "Reach wave 20 in Endless"
        case .tokens1k: "Earn 1,000 lifetime tokens"
        case .tokens10k: "Earn 10,000 lifetime tokens"
        case .combo10: "Reach a ×10 combo"
        case .combo25: "Reach a ×25 combo"
        case .firstUpgrade: "Buy your first upgrade"
        case .maxTrack: "Reach mastery rank 5 in any upgrade track"
        case .firstGear: "Unlock your first new character"
        case .fullEarthSet: "Unlock Volt"
        case .fullMarsSet: "Unlock every character"
        case .streak3: "Claim 3 daily rewards in a row"
        case .streak7: "Claim 7 daily rewards in a row"
        }
    }

    static func icon(for id: AchievementID) -> String {
        switch id {
        case .firstClear: "flag.checkered"
        case .earthWorldClear: "globe.americas.fill"
        case .marsWorldClear: "circle.grid.cross.fill"
        case .wave5, .wave10, .wave20: "infinity"
        case .tokens1k, .tokens10k: "hexagon.fill"
        case .combo10, .combo25: "bolt.fill"
        case .firstUpgrade: "arrow.up.circle.fill"
        case .maxTrack: "star.fill"
        case .firstGear: "person.crop.circle.badge.plus"
        case .fullEarthSet, .fullMarsSet: "crown.fill"
        case .streak3, .streak7: "flame.fill"
        }
    }
}
