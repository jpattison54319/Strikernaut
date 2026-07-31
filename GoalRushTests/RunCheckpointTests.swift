import Foundation
import Testing
@testable import GoalRush

@MainActor
struct RunCheckpointTests {
    @Test func campaignCheckpointRestoresAtNextWaveDraft() throws {
        var progress = PlayerProgress.newPlayer
        progress.seenCampaignBriefingLevels.insert(1)
        progress.selectedCharacter = .volt
        let session = GameSessionModel(
            mode: .campaign(level: 1),
            progress: progress,
            settings: GameSettings()
        )
        session.simulation.apply(.powerDrive)

        completeCurrentWave(in: session)

        let checkpoint = try #require(
            session.makeRunCheckpoint(
                creditedRunTokens: session.snapshot.tokens,
                previous: nil
            )
        )
        let restored = GameSessionModel(
            mode: .campaign(level: 1),
            progress: .newPlayer,
            settings: GameSettings(),
            checkpoint: checkpoint
        )

        #expect(checkpoint.wave == 2)
        #expect(restored.snapshot.wave == 2)
        #expect(restored.snapshot.targets.isEmpty)
        #expect(restored.snapshot.projectiles.isEmpty)
        #expect(restored.character.id == .volt)
        #expect(restored.simulation.abilityRank(.powerDrive) == 1)
        #expect(restored.phase == session.phase)
    }

    @Test func endlessCheckpointRestoresWorldTransitionAndRunUpgrades() throws {
        let session = makePlayingEndlessSession()
        session.simulation.apply(.specialBall(.volt))
        session.simulation.setEndlessWaveForTesting(10)

        completeCurrentWave(in: session)

        let checkpoint = try #require(
            session.makeRunCheckpoint(
                creditedRunTokens: session.snapshot.tokens,
                previous: nil
            )
        )
        let restored = GameSessionModel(
            mode: .endless,
            progress: .newPlayer,
            settings: GameSettings(),
            checkpoint: checkpoint
        )

        #expect(checkpoint.wave == 11)
        #expect(restored.snapshot.wave == 11)
        #expect(restored.snapshot.world == EndlessRules.world(for: 11))
        #expect(restored.simulation.specialBallRank(.volt) == 1)
        #expect(restored.phase == session.phase)
        guard case .worldTransition = restored.phase else {
            Issue.record("Expected the recovered Endless run to replay its world transition")
            return
        }
    }

    @Test func firstWaveNeverProducesCheckpoint() {
        let campaign = GameSessionModel(
            mode: .campaign(level: 1),
            progress: .newPlayer,
            settings: GameSettings()
        )
        let endless = GameSessionModel(
            mode: .endless,
            progress: .newPlayer,
            settings: GameSettings()
        )

        #expect(
            campaign.makeRunCheckpoint(
                creditedRunTokens: 0,
                previous: nil
            ) == nil
        )
        #expect(
            endless.makeRunCheckpoint(
                creditedRunTokens: 0,
                previous: nil
            ) == nil
        )
    }

    @Test func restoredDeathSaveUsageCannotBeClaimedAgain() throws {
        let session = makePlayingEndlessSession()
        completeCurrentWave(in: session)
        let checkpoint = try #require(
            session.makeRunCheckpoint(
                creditedRunTokens: 40,
                previous: nil
            )
        )
        let updated = checkpoint.updatingRunMetadata(
            creditedRunTokens: 65,
            deathSaveWasUsed: true
        )
        let restored = GameSessionModel(
            mode: .endless,
            progress: .newPlayer,
            settings: GameSettings(),
            checkpoint: updated
        )

        restored.forceDefeatForTesting()

        #expect(updated.creditedRunTokens == 65)
        #expect(restored.deathSaveWasUsed)
        #expect(restored.phase == .finished)
    }

    @Test func storeKeepsModesSeparateAndDeletesOnlyRequestedRun() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = RunCheckpointStore(directoryURL: directory)
        let campaign = try makeCheckpoint(mode: .campaign(level: 1))
        let endless = try makeCheckpoint(mode: .endless)

        try await store.save(campaign)
        try await store.save(endless)

        #expect(await store.load(for: .campaign(level: 1)) == campaign)
        #expect(await store.load(for: .endless) == endless)

        try await store.delete(for: .campaign(level: 1))

        #expect(await store.load(for: .campaign(level: 1)) == nil)
        #expect(await store.load(for: .endless) == endless)
    }

    @Test func newerCheckpointRevisionCannotBeOverwrittenByOlderWrite() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = RunCheckpointStore(directoryURL: directory)
        let original = try makeCheckpoint(mode: .endless)
        let newer = original.updatingRunMetadata(
            creditedRunTokens: original.creditedRunTokens + 25,
            deathSaveWasUsed: true
        )

        try await store.save(newer)
        try await store.save(original)

        #expect(await store.load(for: .endless) == newer)
    }

    @Test func deathInvalidatesResumeUntilRewardedContinueIsPersisted() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = RunCheckpointStore(directoryURL: directory)
        let checkpoint = try makeCheckpoint(mode: .endless)

        try await store.save(checkpoint)
        try await store.invalidateAfterDeath(for: .endless)

        #expect(await store.load(for: .endless) == nil)

        let rewardedContinue = checkpoint.updatingRunMetadata(
            creditedRunTokens: checkpoint.creditedRunTokens,
            deathSaveWasUsed: true
        )
        try await store.save(rewardedContinue)

        let restored = await store.load(for: .endless)
        #expect(restored == rewardedContinue)
        #expect(restored?.deathSaveWasUsed == true)
    }

    private func makeCheckpoint(mode: RunMode) throws -> RunCheckpoint {
        let session: GameSessionModel
        switch mode {
        case .campaign(let level):
            var progress = PlayerProgress.newPlayer
            progress.seenCampaignBriefingLevels.insert(level)
            session = GameSessionModel(
                mode: mode,
                progress: progress,
                settings: GameSettings()
            )
        case .endless:
            session = makePlayingEndlessSession()
        }
        completeCurrentWave(in: session)
        return try #require(
            session.makeRunCheckpoint(
                creditedRunTokens: session.snapshot.tokens,
                previous: nil
            )
        )
    }

    private func makePlayingEndlessSession() -> GameSessionModel {
        let session = GameSessionModel(
            mode: .endless,
            progress: .newPlayer,
            settings: GameSettings()
        )
        if case .draft(let choices) = session.phase,
           let first = choices.first {
            session.choose(first)
        }
        return session
    }

    private func completeCurrentWave(in session: GameSessionModel) {
        session.completeCurrentWaveForTesting()
    }
}
