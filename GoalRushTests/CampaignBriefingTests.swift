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

    @Test func everyDiscoveryIsFirstIntroducedOnItsLevel() {
        for level in GameContent.levels {
            let earlierLevels = GameContent.levels.filter { $0.number < level.number }

            for discovery in CampaignBriefingCatalog.discoveries(for: level) {
                switch discovery.subject {
                case .concept(let concept):
                    #expect(!earlierLevels.flatMap(\.concepts).contains(concept))
                case .enemy(let enemy):
                    #expect(!earlierLevels.flatMap(authoredEnemies(in:)).contains(enemy))
                case .fieldObject(let object):
                    #expect(!earlierLevels.flatMap(\.objects).contains(object))
                }
            }
        }
    }

    @Test func remixLevelsStartWithoutAnEmptyBriefing() {
        let levelsWithoutDiscoveries = GameContent.levels
            .filter { CampaignBriefingCatalog.discoveries(for: $0).isEmpty }
            .map(\.number)

        #expect(levelsWithoutDiscoveries == [7, 8, 9, 17, 18, 19, 27, 28, 29])
    }

    @Test func bossesAreIntroducedOnTheirCampaignLevels() {
        let earthBoss = CampaignBriefingCatalog.discoveries(for: GameContent.level(10))
        let moonBoss = CampaignBriefingCatalog.discoveries(for: GameContent.level(20))
        let marsBoss = CampaignBriefingCatalog.discoveries(for: GameContent.level(30))

        #expect(earthBoss.contains { $0.subject == .enemy(.titanKeeper) })
        #expect(moonBoss.contains { $0.subject == .enemy(.lunarWarden) })
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
            mode: .endless,
            progress: .newPlayer,
            settings: GameSettings()
        )

        #expect(remix.phase == .playing)
        guard case .draft = endless.phase else {
            Issue.record("Endless should still begin with its ability draft")
            return
        }
    }

    @Test func nextWaveHUDPublishesWhenTheDraftDismisses() {
        let session = GameSessionModel(
            mode: .endless,
            progress: .newPlayer,
            settings: GameSettings()
        )
        guard case .draft(let starterChoices) = session.phase,
              let starterChoice = starterChoices.first else {
            Issue.record("Endless should begin with an ability draft")
            return
        }
        session.choose(starterChoice)

        session.simulation.setWaveDefeatsForTesting(session.simulation.snapshot.waveEnemyQuota)
        session.update(currentTime: 1)

        #expect(session.snapshot.wave == 2)
        #expect(session.hudState.wave == 1)
        guard case .draft(let nextChoices) = session.phase,
              let nextChoice = nextChoices.first else {
            Issue.record("Clearing an Endless wave should open the next draft")
            return
        }

        session.choose(nextChoice)

        #expect(session.phase == .playing)
        #expect(session.hudState.wave == 2)
    }

    @Test func previouslySeenLevelStartsWithoutRepeatingItsBriefing() {
        var progress = PlayerProgress.newPlayer
        progress.seenCampaignBriefingLevels.insert(6)

        let session = GameSessionModel(
            mode: .campaign(level: 6),
            progress: progress,
            settings: GameSettings()
        )

        #expect(session.phase == .playing)
    }

    private func authoredEnemies(in level: LevelDefinition) -> [EnemyKind] {
        level.hasBoss
            ? level.enemies + [GameContent.world(level.world).boss]
            : level.enemies
    }
}
