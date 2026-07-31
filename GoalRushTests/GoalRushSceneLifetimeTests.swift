import Testing
@testable import GoalRush

@MainActor
struct GoalRushSceneLifetimeTests {
    @Test func sceneRetainsItsSessionUntilSpriteKitReleasesTheScene() {
        weak var retainedSession: GameSessionModel?
        var scene: GoalRushScene?

        do {
            let session = GameSessionModel(
                mode: .endless,
                progress: .newPlayer,
                settings: GameSettings()
            )
            retainedSession = session
            scene = GoalRushScene(
                session: session,
                reducedEffects: false
            )
        }

        #expect(retainedSession != nil)

        scene?.prepareForRemoval()
        scene = nil

        #expect(retainedSession == nil)
    }

    @Test(
        arguments: [
            RunMode.campaign(level: 1),
            RunMode.endless,
        ]
    )
    func rewardedContinueResumesAfterTemporaryFullScreenInterruption(
        mode: RunMode
    ) {
        let session = GameSessionModel(
            mode: mode,
            progress: .newPlayer,
            settings: GameSettings()
        )
        let scene = GoalRushScene(
            session: session,
            reducedEffects: false
        )
        var receivedReviveEvent = false
        scene.eventHandler = { events, _ in
            receivedReviveEvent = events.contains { event in
                if case .heal = event { true } else { false }
            }
        }

        session.forceDefeatForTesting()
        scene.synchronizePlayback(isPaused: true)

        #expect(scene.isPaused)
        #expect(session.continueAfterDeathSave())
        #expect(session.phase == .deathSaveCountdown)

        scene.synchronizePlayback(isPaused: false)
        for frame in 0..<190 {
            scene.update(Double(frame) / 60)
        }
        scene.update(190.0 / 60)

        #expect(!scene.isPaused)
        #expect(receivedReviveEvent)
        #expect(session.phase == .playing)
        #expect(session.snapshot.elapsed > 0)
    }

    @Test func permanentRemovalCannotBeAccidentallyResumed() {
        let session = GameSessionModel(
            mode: .campaign(level: 1),
            progress: .newPlayer,
            settings: GameSettings()
        )
        let scene = GoalRushScene(
            session: session,
            reducedEffects: false
        )

        scene.prepareForRemoval()
        scene.synchronizePlayback(isPaused: false)

        #expect(scene.isPaused)
        #expect(scene.eventHandler == nil)
    }

    @Test func takingDamageShowsAHighContrastFullScreenBorder() throws {
        let session = GameSessionModel(
            mode: .campaign(level: 1),
            progress: .newPlayer,
            settings: GameSettings()
        )
        session.startCampaignLevel()
        let scene = GoalRushScene(
            session: session,
            reducedEffects: false
        )
        session.simulation.spawnHostileProjectileForTesting(
            x: session.snapshot.playerX,
            y: 0.139
        )

        scene.update(0)

        let feedback = try #require(
            scene.childNode(withName: "player-damage-feedback")
        )
        #expect(feedback.childNode(withName: "damage-border-contrast") != nil)
        #expect(feedback.childNode(withName: "damage-border-red") != nil)
        #expect(feedback.childNode(withName: "damage-border-highlight") != nil)
        #expect(feedback.action(forKey: "damage-pulse") != nil)
    }
}
