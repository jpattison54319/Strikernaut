import Testing
@testable import GoalRush

@MainActor
struct CampaignBriefingTests {
    @Test func everyAuthoredDiscoveryAppearsExactlyOnce() {
        let discoveries = GameContent.levels.flatMap(CampaignBriefingCatalog.discoveries(for:))
        let enemyIDs = discoveries.compactMap { discovery -> String? in
            guard case .enemy(let enemy) = discovery.subject else { return nil }
            return enemy.rawValue
        }
        let objectIDs = discoveries.compactMap { discovery -> String? in
            guard case .fieldObject(let object) = discovery.subject else { return nil }
            return object.rawValue
        }
        let conceptIDs = discoveries.compactMap { discovery -> String? in
            guard case .concept(let concept) = discovery.subject else { return nil }
            return concept.rawValue
        }

        #expect(enemyIDs.count == Set(enemyIDs).count)
        #expect(objectIDs.count == Set(objectIDs).count)
        #expect(conceptIDs.count == Set(conceptIDs).count)
        #expect(Set(enemyIDs) == Set(EnemyKind.allCases.map(\.rawValue)))
        #expect(Set(objectIDs) == Set(FieldObjectKind.allCases.map(\.rawValue)))
        #expect(Set(conceptIDs) == Set(CampaignConcept.allCases.map(\.rawValue)))
    }

    @Test func remixLevelsStartWithoutAnEmptyBriefing() {
        let levelsWithoutDiscoveries = GameContent.levels
            .filter { CampaignBriefingCatalog.discoveries(for: $0).isEmpty }
            .map(\.number)

        #expect(levelsWithoutDiscoveries == [7, 8, 9, 17, 18, 19])
    }

    @Test func bossesAreIntroducedOnTheirCampaignLevels() {
        let earthBoss = CampaignBriefingCatalog.discoveries(for: GameContent.level(10))
        let marsBoss = CampaignBriefingCatalog.discoveries(for: GameContent.level(20))

        #expect(earthBoss.contains { $0.subject == .enemy(.titanKeeper) })
        #expect(marsBoss.contains { $0.subject == .enemy(.marsColossus) })
    }

    @Test func briefingPausesNewCampaignContentUntilKickOff() {
        let session = GameSessionModel(
            mode: .campaign(level: 6),
            progress: .newPlayer,
            settings: GameSettings()
        )

        guard case .briefing(let discoveries) = session.phase else {
            Issue.record("Level 6 should open with a briefing")
            return
        }
        #expect(discoveries.contains { $0.subject == .enemy(.ballLauncher) })
        #expect(session.snapshot.elapsed == 0)

        session.startCampaignLevel()
        #expect(session.phase == .playing)
    }

    @Test func briefingsStayOutOfEndlessAndCampaignRemixes() {
        let remix = GameSessionModel(
            mode: .campaign(level: 7),
            progress: .newPlayer,
            settings: GameSettings()
        )
        let endless = GameSessionModel(
            mode: .endless(world: .mars),
            progress: .newPlayer,
            settings: GameSettings()
        )

        #expect(remix.phase == .playing)
        guard case .draft = endless.phase else {
            Issue.record("Endless should still begin with its ability draft")
            return
        }
    }
}
