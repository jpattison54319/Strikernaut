import Testing
import UIKit
@testable import GoalRush

@MainActor
struct CampaignWorldTests {
    @Test func everyAuthoredWorldHasItsDistinctRuleAndContentPool() {
        #expect(GameContent.worlds.map(\.id) == WorldID.allCases)
        #expect(GameContent.world(.earth).rule == nil)
        #expect(GameContent.world(.moon).rule == .lunarCycle)
        #expect(GameContent.world(.mars).rule == .volatileCores)
        #expect(GameContent.world(.jupiter).rule == .windShear)
        #expect(GameContent.world(.saturn).rule == .ringSweep)
        #expect(GameContent.world(.uranus).rule == .cryoDrift)
        #expect(GameContent.world(.neptune).rule == .pressureTide)
        #expect(Set(GameContent.worlds.map(\.mapAsset)).count == 7)

        let powerPools = GameContent.worlds.map { Set($0.temporaryPowers) }
        #expect(powerPools.allSatisfy { $0.count == 3 })
        #expect(GameContent.worlds.allSatisfy { $0.endlessEnemies.count == 5 })
        #expect(GameContent.worlds.allSatisfy { $0.endlessObjects.count == 5 })
    }

    @Test func planetJourneyPaginatesAndContinuesToJupiter() {
        #expect(WorldJourneyCatalog.pageSize == 3)
        #expect(WorldJourneyCatalog.pages.count == 3)
        #expect(WorldJourneyCatalog.pages[0].compactMap(\.world) == [.earth, .moon, .mars])
        #expect(WorldJourneyCatalog.pages[1].compactMap(\.world) == [.jupiter, .saturn, .uranus])
        #expect(WorldJourneyCatalog.pages[2].map(\.id) == ["neptune", "andromeda"])
        #expect(WorldJourneyCatalog.pages[2][1].isFuture)
        #expect(WorldJourneyCatalog.pageIndicesTopToBottom == [2, 1, 0])
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
        #expect(CharacterCatalog.unlockedCharacters(for: progress) == [.ace, .volt, .nova, .aegis])

        for level in [40, 50, 60, 70] {
            progress.levelRecords[level] = .init(completed: true, bestTokens: 1, bestStamina: 1)
        }
        #expect(CharacterCatalog.unlockedCharacters(for: progress) == Set(CharacterID.allCases))
    }

    @Test func campaignContainsSevenContinuousTenLevelWorlds() {
        #expect(GameContent.levels.map(\.number) == Array(1...70))
        for (index, world) in GameContent.worlds.enumerated() {
            #expect(world.levelRange == (index * 10 + 1)...(index * 10 + 10))
            #expect(GameContent.levels(in: world.id).count == 10)
            #expect(GameContent.level(world.finalLevel).hasBoss)
        }
    }

    @Test func everyCampaignEnvironmentAndPlanetAssetIsBundled() {
        let assets = GameContent.worlds.flatMap {
            [$0.gameplayAsset, $0.mapAsset, $0.id.factionSigilAsset(isBoss: false), $0.id.factionSigilAsset(isBoss: true)]
        } + [
            "PlanetEarth", "PlanetMoon", "PlanetMars", "PlanetJupiter",
            "PlanetSaturn", "PlanetUranus", "PlanetNeptune"
        ]
        for asset in assets {
            #expect(UIImage(named: asset) != nil, "Missing production asset \(asset)")
        }
    }
}
