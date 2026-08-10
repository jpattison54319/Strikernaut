import Testing
@testable import GoalRush

@MainActor
struct DeathSaveTests {
    @Test func campaignFirstDeathOffersSaveBeforeFinalLoss() {
        let session = makeSession(mode: .campaign(level: 1))

        session.forceDefeatForTesting()

        #expect(session.phase == .deathSaveOffer)
        #expect(!session.deathSaveWasUsed)
        #expect(!session.didFinish)

        session.declineDeathSave()

        #expect(session.phase == .finished)
        #expect(session.didFinish)
        #expect(session.lastEvent == .finished(false))
    }

    @Test func endlessFirstDeathOffersSaveBeforeFinalLoss() {
        let session = makeSession(mode: .endless)

        session.forceDefeatForTesting()

        #expect(session.phase == .deathSaveOffer)
        #expect(!session.deathSaveWasUsed)
        #expect(!session.didFinish)
    }

    @Test func rewardedContinueRevivesSameRunOnlyOnce() {
        let session = makeSession(mode: .endless)
        session.simulation.setEndlessWaveForTesting(7)
        session.simulation.setWaveDefeatsForTesting(3)
        session.simulation.setTokensForTesting(80)
        session.forceDefeatForTesting()

        #expect(session.continueAfterDeathSave())
        #expect(session.phase == .deathSaveCountdown)
        #expect(session.deathSaveCountdownSeconds == 3)
        #expect(session.deathSaveWasUsed)
        #expect(session.snapshot.wave == 7)
        #expect(session.snapshot.waveDefeats == 3)
        #expect(session.snapshot.tokens == 80)
        #expect(
            abs(
                session.snapshot.stamina
                    - session.snapshot.maxStamina * DeathSaveRules.restoredStaminaFraction
            ) < 0.0001
        )

        advanceThroughDeathSaveCountdown(session)
        session.forceDefeatForTesting()

        #expect(session.phase == .finished)
        #expect(session.didFinish)
    }

    @Test(
        arguments: [
            RunMode.campaign(level: 1),
            RunMode.endless,
        ]
    )
    func rewardedContinueFreezesForThreeSecondsBeforeShieldedPlay(
        mode: RunMode
    ) {
        let session = makeSession(mode: mode)
        session.forceDefeatForTesting()
        #expect(session.continueAfterDeathSave())
        let elapsedBeforeCountdown = session.snapshot.elapsed

        for frame in 0..<170 {
            session.update(currentTime: Double(frame) / 60)
        }

        #expect(session.phase == .deathSaveCountdown)
        #expect(session.deathSaveCountdownSeconds == 1)
        #expect(session.snapshot.elapsed == elapsedBeforeCountdown)
        #expect(
            session.simulation.deathSaveDamageGraceRemainingForTesting
                == DeathSaveRules.damageGracePeriod
        )

        var frame = 170
        while session.phase == .deathSaveCountdown, frame < 200 {
            session.update(currentTime: Double(frame) / 60)
            frame += 1
        }

        #expect(session.phase == .playing)
        #expect(session.deathSaveCountdownSeconds == 0)
        #expect(session.snapshot.elapsed == elapsedBeforeCountdown)
        #expect(
            session.simulation.deathSaveDamageGraceRemainingForTesting
                == DeathSaveRules.damageGracePeriod
        )

        session.update(currentTime: Double(frame) / 60)

        #expect(session.snapshot.elapsed > elapsedBeforeCountdown)
        #expect(
            session.simulation.deathSaveDamageGraceRemainingForTesting
                < DeathSaveRules.damageGracePeriod
        )
    }

    @Test func fullRestartRearmsDeathSave() {
        let firstAttempt = makeSession(mode: .campaign(level: 2))
        firstAttempt.forceDefeatForTesting()
        #expect(firstAttempt.continueAfterDeathSave())

        let restartedAttempt = makeSession(mode: .campaign(level: 2))
        restartedAttempt.forceDefeatForTesting()

        #expect(restartedAttempt.phase == .deathSaveOffer)
        #expect(!restartedAttempt.deathSaveWasUsed)
    }

    @Test func revivalClearsIncomingThreatsAndProvidesDamageGrace() {
        let simulation = GameSimulation(
            mode: .endless,
            progress: .newPlayer,
            assistMode: false,
            seed: 41
        )
        simulation.spawnHostileProjectileForTesting(x: 0, y: 0.16)
        _ = simulation.forceDefeatForTesting()

        let restoredStamina = simulation.reviveAfterDeathSave()

        #expect(restoredStamina != nil)
        #expect(simulation.snapshot.projectiles.isEmpty)

        simulation.spawnHostileProjectileForTesting(
            x: simulation.snapshot.playerX,
            y: 0.16,
            damage: 100
        )
        _ = simulation.update(delta: 0.05)

        #expect(simulation.snapshot.stamina == restoredStamina)
    }

    @Test(
        arguments: [
            RunMode.campaign(level: 1),
            RunMode.endless,
        ]
    )
    func lethalDamageAtFractionalStaminaEndsTheRun(mode: RunMode) {
        let simulation = GameSimulation(
            mode: mode,
            progress: .newPlayer,
            assistMode: false,
            seed: 91
        )
        simulation.setStaminaForTesting(0.5)
        simulation.spawnHostileProjectileForTesting(
            x: simulation.snapshot.playerX,
            y: 0.16,
            damage: 100
        )

        let events = simulation.update(delta: 0.05)

        #expect(simulation.snapshot.stamina == 0)
        #expect(events.contains(.finished(false)))
    }

    @Test(
        arguments: [
            RunMode.campaign(level: 1),
            RunMode.endless,
        ]
    )
    func lethalFramePublishesZeroStaminaBeforeDeathSaveOffer(mode: RunMode) {
        let session = makeSession(mode: mode)
        switch mode {
        case .campaign:
            session.startCampaignLevel()
        case .endless:
            session.choose(.ability(.powerDrive))
        }
        session.simulation.setStaminaForTesting(9)
        session.update(currentTime: 1)

        #expect(session.hudState.stamina == 9)

        session.simulation.spawnHostileProjectileForTesting(
            x: session.snapshot.playerX,
            y: 0.16,
            damage: 100
        )
        session.update(currentTime: 1.05)

        #expect(session.phase == .deathSaveOffer)
        #expect(session.snapshot.stamina == 0)
        #expect(session.hudState.stamina == 0)
    }

    @Test func positiveFractionalStaminaNeverDisplaysAsZero() {
        #expect(CompactStaminaBar.displayValue(for: 0) == 0)
        #expect(CompactStaminaBar.displayValue(for: 0.01) == 1)
        #expect(CompactStaminaBar.displayValue(for: 0.99) == 1)
        #expect(CompactStaminaBar.displayValue(for: 1.99) == 1)
        #expect(CompactStaminaBar.displayValue(for: 37.9) == 37)
    }

    private func makeSession(mode: RunMode) -> GameSessionModel {
        GameSessionModel(
            mode: mode,
            progress: .newPlayer,
            settings: GameSettings()
        )
    }

    private func advanceThroughDeathSaveCountdown(
        _ session: GameSessionModel
    ) {
        var frame = 0
        while session.phase == .deathSaveCountdown, frame < 200 {
            session.update(currentTime: Double(frame) / 60)
            frame += 1
        }
        #expect(session.phase == .playing)
    }
}
