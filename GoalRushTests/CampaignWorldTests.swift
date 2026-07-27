import Testing
import UIKit
@testable import GoalRush

@MainActor
struct CampaignWorldTests {
    @Test func onlyFutureWorldsHaveDistinctRules() {
        #expect(GameContent.worlds.map(\.id) == [.earth, .moon, .mars])
        #expect(GameContent.world(.earth).rule == nil)
        #expect(GameContent.world(.moon).rule == .lunarCycle)
        #expect(GameContent.world(.mars).rule == .volatileCores)
        #expect(Set(GameContent.worlds.map(\.mapAsset)).count == 3)

        let powerPools = GameContent.worlds.map { Set($0.temporaryPowers) }
        #expect(powerPools.allSatisfy { $0.count == 3 })
        #expect(powerPools[0].isDisjoint(with: powerPools[1]))
        #expect(powerPools[1].isDisjoint(with: powerPools[2]))
        #expect(powerPools[0].isDisjoint(with: powerPools[2]))
    }

    @Test func planetJourneyPaginatesAndContinuesToJupiter() {
        #expect(WorldJourneyCatalog.pageSize == 3)
        #expect(WorldJourneyCatalog.pages.count == 2)
        #expect(WorldJourneyCatalog.pages[0].compactMap(\.world) == [.earth, .moon, .mars])
        #expect(WorldJourneyCatalog.pages[1].map(\.id) == ["jupiter"])
        #expect(WorldJourneyCatalog.pages[1][0].isFuture)
        #expect(WorldJourneyCatalog.pageIndicesTopToBottom == [1, 0])
    }

    @Test func everyWorldMapHasTenOrderedLandmarks() {
        for world in WorldID.allCases {
            let map = WorldMapCatalog.map(for: world)
            #expect(map.placements.count == 10)
            #expect(map.placements.map(\.levelNumber) == Array(GameContent.world(world).levelRange))
            #expect(map.placements.allSatisfy { (0...1).contains($0.x) && (0...1).contains($0.y) })
        }
    }

    @Test func worldFinalesUnlockTheThematicHeroInSequence() {
        var progress = PlayerProgress.newPlayer
        #expect(CharacterCatalog.unlockedCharacters(for: progress) == [.ace])

        progress.levelRecords[10] = .init(completed: true, bestTokens: 1, bestStamina: 1)
        #expect(CharacterCatalog.unlockedCharacters(for: progress) == [.ace, .volt])

        progress.levelRecords[20] = .init(completed: true, bestTokens: 1, bestStamina: 1)
        #expect(CharacterCatalog.unlockedCharacters(for: progress) == [.ace, .volt, .nova])

        progress.levelRecords[30] = .init(completed: true, bestTokens: 1, bestStamina: 1)
        #expect(CharacterCatalog.unlockedCharacters(for: progress) == Set(CharacterID.allCases))
    }

    @Test func everyCampaignEnvironmentAndPlanetAssetIsBundled() {
        let assets = [
            "GameplayArena", "MoonArena", "MarsArena",
            "EarthWorldMap", "MoonWorldMap", "MarsWorldMap",
            "PlanetEarth", "PlanetMoon", "PlanetMars", "PlanetJupiter"
        ]
        for asset in assets {
            #expect(UIImage(named: asset) != nil, "Missing production asset \(asset)")
        }
    }
}
