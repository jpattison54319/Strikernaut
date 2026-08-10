import Foundation
import Observation

@MainActor
@Observable
final class GameSessionModel {
    enum Phase: Equatable {
        case playing
        case paused
        case briefing([CampaignDiscovery])
        case draft([RunUpgradeChoice])
        case worldTransition(from: WorldID, to: WorldID, draft: [RunUpgradeChoice])
        case deathSaveOffer
        case deathSaveCountdown
        case finished
    }

    let mode: RunMode
    let campaignCycle: Int
    let runID: UUID
    let activeRelic: EndlessRelic?
    let level: LevelDefinition?
    let simulation: GameSimulation
    let character: CharacterDefinition
    var phase: Phase = .playing
    @ObservationIgnored private(set) var snapshot: SimulationSnapshot
    var hudState: HUDState
    @ObservationIgnored private(set) var eventPulse = 0
    @ObservationIgnored private(set) var lastEvent: SimulationEvent?
    @ObservationIgnored private(set) var recentEvents: [SimulationEvent] = []
    private(set) var didFinish = false
    private(set) var deathSaveWasUsed = false
    private(set) var deathSaveCountdownSeconds = 0
    private(set) var draftsChosen = 0
    private var random: SeededGenerator
    private var lastTime: TimeInterval?
    private var lastHUDPublishTime: TimeInterval = 0
    private var abilityCinematicRemaining: TimeInterval = 0
    @ObservationIgnored private var deathSaveCountdownRemaining: TimeInterval = 0
    private let allowsDebugAbilityCinematic: Bool
#if DEBUG
    private var debugAutoCharacterAbilityTime: TimeInterval?
    private var debugDidAutoActivateCharacterAbility = false
#endif

    convenience init(levelNumber: Int, progress: PlayerProgress, settings: GameSettings) {
        self.init(mode: .campaign(level: levelNumber), progress: progress, settings: settings)
    }

    init(
        mode: RunMode,
        progress: PlayerProgress,
        settings: GameSettings,
        checkpoint: RunCheckpoint? = nil
    ) {
        self.mode = mode
        self.campaignCycle = mode.isEndless
            ? 0
            : max(0, checkpoint?.campaignCycle ?? progress.campaignCycle)
        self.runID = checkpoint?.runID ?? UUID()
        self.activeRelic = checkpoint?.activeRelic
            ?? (mode.isEndless ? progress.endlessRecord.equippedRelic : nil)
        self.level = mode.campaignLevel.map(GameContent.level)
        self.character = CharacterCatalog.character(
            checkpoint?.simulation.characterID ?? progress.selectedCharacter
        )
        let argumentSeed = ProcessInfo.processInfo.arguments.value(after: "--fixed-seed").flatMap(UInt64.init)
        let modeSeed: UInt64 = switch mode {
        case .campaign(let level):
            UInt64(
                level * 10_007
                    + progress.trainingTokens
                    + campaignCycle * 1_000_003
            )
        case .endless: UInt64(progress.trainingTokens + 77)
        }
        let seed = argumentSeed ?? modeSeed
        self.simulation = GameSimulation(
            mode: mode,
            progress: progress,
            campaignCycle: campaignCycle,
            assistMode: settings.assistMode,
            seed: seed,
            checkpoint: checkpoint?.simulation
        )
        self.snapshot = simulation.snapshot
        self.hudState = HUDState(snapshot: simulation.snapshot)
        self.random = checkpoint?.sessionRandom
            ?? SeededGenerator(seed: seed ^ 0xA11B1E)
        self.allowsDebugAbilityCinematic = !settings.reducedFlashes
        self.deathSaveWasUsed = checkpoint?.deathSaveWasUsed ?? false
        self.draftsChosen = checkpoint?.draftsChosen ?? 0

#if DEBUG
        if checkpoint == nil {
            if let rawAbility = ProcessInfo.processInfo.arguments.value(after: "--temporary-ability"),
               let ability = TemporaryBallAbility(rawValue: rawAbility) {
                simulation.activateTemporaryAbility(ability)
                snapshot = simulation.snapshot
                hudState = HUDState(snapshot: simulation.snapshot)
            }
            if ProcessInfo.processInfo.arguments.contains("--character-ability-ready") {
                simulation.fullyChargeCharacterAbilityForTesting()
                snapshot = simulation.snapshot
                hudState = HUDState(snapshot: simulation.snapshot)
            }
            if let rawDelay = ProcessInfo.processInfo.arguments.value(after: "--auto-character-ability-after"),
               let delay = TimeInterval(rawDelay) {
                debugAutoCharacterAbilityTime = max(0, delay)
            }
        }
#endif

        if let checkpoint {
            switch checkpoint.intermission {
            case .draft(let choices):
                phase = .draft(choices)
            case .worldTransition(let from, let to, let draft):
                phase = .worldTransition(from: from, to: to, draft: draft)
            }
        } else if mode.isEndless {
            phase = .draft(makeDraft())
        } else if let level, !progress.seenCampaignBriefingLevels.contains(level.number) {
            let discoveries = CampaignBriefingCatalog.discoveries(for: level)
            if !discoveries.isEmpty {
                phase = .briefing(discoveries)
            }
        }
#if DEBUG
        if checkpoint == nil {
            if ProcessInfo.processInfo.arguments.contains("--show-draft") {
                phase = .draft(
                    mode.isEndless
                        ? [.specialBall(.volt), .specialBall(.ice), .specialBall(.split)]
                        : [.ability(.oneTwo), .ability(.quickRelease), .ability(.powerDrive)]
                )
            }
            if mode.isEndless,
               ProcessInfo.processInfo.arguments.contains("--audit-draft") {
                phase = .draft([
                    .specialBall(.ice),
                    .specialBall(.polarLink),
                    .specialBall(.gravityWell),
                ])
            }
            if ProcessInfo.processInfo.arguments.contains("--auto-kick-off") {
                if case .briefing = phase {
                    phase = .playing
                } else if case .draft(let choices) = phase, let choice = choices.first {
                    simulation.apply(choice)
                    snapshot = simulation.snapshot
                    hudState = HUDState(snapshot: simulation.snapshot)
                    phase = .playing
                }
            }
            if mode.isEndless,
               ProcessInfo.processInfo.arguments.contains("--world-transition-preview") {
                let fromWave = max(1, snapshot.wave - 1)
                phase = .worldTransition(
                    from: EndlessRules.world(for: fromWave),
                    to: snapshot.world,
                    draft: makeDraft()
                )
            }
            if ProcessInfo.processInfo.arguments.contains("--death-save-preview") {
                simulation.setTokensForTesting(100)
                handleForcedDefeatForTesting()
            }
        }
#endif
    }

    var levelNumber: Int? { level?.number }
    var isStarterDraft: Bool { mode.isEndless && snapshot.elapsed == 0 }
    var world: WorldDefinition { GameContent.world(snapshot.world) }

    func makeRunCheckpoint(
        creditedRunTokens: Int,
        previous: RunCheckpoint?,
        savedAt: Date = .now
    ) -> RunCheckpoint? {
        guard snapshot.wave > 1 else { return nil }

        let intermission: RunCheckpointIntermission
        switch phase {
        case .draft(let choices):
            intermission = .draft(choices)
        case .worldTransition(let from, let to, let draft):
            intermission = .worldTransition(
                from: from,
                to: to,
                draft: draft
            )
        default:
            return nil
        }

        return RunCheckpoint(
            schemaVersion: RunCheckpoint.currentSchemaVersion,
            runID: runID,
            mode: mode,
            campaignCycle: campaignCycle,
            activeRelic: activeRelic,
            savedAt: savedAt,
            revision: (previous?.revision ?? 0) + 1,
            simulation: simulation.makeRunCheckpoint(),
            intermission: intermission,
            sessionRandom: random,
            draftsChosen: draftsChosen,
            deathSaveWasUsed: deathSaveWasUsed,
            creditedRunTokens: max(
                previous?.creditedRunTokens ?? 0,
                creditedRunTokens
            )
        )
    }

    func update(currentTime: TimeInterval) {
        let realDelta = max(
            0,
            lastTime.map { currentTime - $0 } ?? 1.0 / 60.0
        )
        lastTime = currentTime
        if phase == .deathSaveCountdown {
            updateDeathSaveCountdown(
                delta: min(realDelta, 1.0 / 20.0)
            )
            return
        }
        guard phase == .playing else { return }
        let isPlayingAbilityCinematic = abilityCinematicRemaining > 0
        abilityCinematicRemaining = max(
            0,
            abilityCinematicRemaining - realDelta
        )
        let delta = isPlayingAbilityCinematic ? realDelta * 0.22 : realDelta
        var events = simulation.update(delta: delta)
#if DEBUG
        if !debugDidAutoActivateCharacterAbility,
           let activationTime = debugAutoCharacterAbilityTime,
           simulation.snapshot.elapsed >= activationTime {
            debugDidAutoActivateCharacterAbility = true
            let abilityEvents = simulation.activateCharacterAbility()
            if !abilityEvents.isEmpty, allowsDebugAbilityCinematic {
                abilityCinematicRemaining = 0.18
            }
            events.append(contentsOf: abilityEvents)
        }
#endif
        snapshot = simulation.snapshot
        recentEvents = events
        if !events.isEmpty { eventPulse += 1 }
        // SpriteKit consumes every simulation snapshot and event directly. Publishing
        // the SwiftUI HUD on every kick/impact needlessly rebuilt a material-heavy
        // overlay in the middle of the render frame, which showed up as a visible
        // hitch. Ten updates per second keeps counters fluid without coupling them
        // to the much hotter simulation event stream.
        let beginsIntermission = events.contains { event in
            switch event {
            case .checkpoint, .worldTransitioned:
                true
            default:
                false
            }
        }
        let endsRun = events.contains { event in
            if case .finished = event { true } else { false }
        }
        // Keep the completed wave visible beneath the draft. `choose(_:)`
        // publishes the already-advanced simulation snapshot as the draft
        // dismisses, so the player actually sees the wave counter roll into
        // the next value instead of having that animation hidden by the
        // intermission.
        if endsRun
            || (!beginsIntermission && currentTime - lastHUDPublishTime >= 0.10) {
            hudState = HUDState(snapshot: snapshot)
            lastHUDPublishTime = currentTime
        }
        for event in events { handle(event) }
    }

    func setPlayerTarget(_ x: Double) { simulation.setPlayerTarget(x: x) }

    func activateCharacterAbility(cinematic: Bool) {
        guard phase == .playing else { return }
        let events = simulation.activateCharacterAbility()
        guard !events.isEmpty else { return }
        if cinematic {
            abilityCinematicRemaining = 0.18
        }
        snapshot = simulation.snapshot
        hudState = HUDState(snapshot: snapshot)
        recentEvents = events
        lastEvent = events.last
        eventPulse += 1
    }

    func startCampaignLevel() {
        guard case .briefing = phase else { return }
        phase = .playing
        lastTime = nil
    }

    func choose(_ choice: RunUpgradeChoice) {
        draftsChosen += 1
        let previousStamina = simulation.snapshot.stamina
        simulation.apply(choice)
        snapshot = simulation.snapshot
        hudState = HUDState(snapshot: snapshot)
        recentEvents = [.upgradeChosen(choice)]
        if snapshot.stamina > previousStamina {
            recentEvents.append(.heal(snapshot.stamina - previousStamina, .init(x: snapshot.playerX, y: 0.16)))
        }
        lastEvent = .upgradeChosen(choice)
        eventPulse += 1
        phase = .playing
        lastTime = nil
    }

    func togglePause() {
        switch phase {
        case .playing:
            phase = .paused
        case .paused:
            phase = .playing
        default:
            return
        }
        lastTime = nil
    }

    func completeWorldTransition() {
        guard case .worldTransition(_, _, let draft) = phase else { return }
        phase = .draft(draft)
        lastTime = nil
    }

    @discardableResult
    func continueAfterDeathSave() -> Bool {
        guard phase == .deathSaveOffer,
              !deathSaveWasUsed,
              let restoredStamina = simulation.reviveAfterDeathSave() else {
            return false
        }

        deathSaveWasUsed = true
        snapshot = simulation.snapshot
        hudState = HUDState(snapshot: snapshot)
        recentEvents = [
            .heal(
                restoredStamina,
                .init(x: snapshot.playerX, y: 0.16)
            ),
        ]
        lastEvent = recentEvents.last
        eventPulse += 1
        deathSaveCountdownRemaining = DeathSaveRules.resumeCountdownDuration
        deathSaveCountdownSeconds = Int(
            ceil(DeathSaveRules.resumeCountdownDuration)
        )
        phase = .deathSaveCountdown
        lastTime = nil
        return true
    }

    func declineDeathSave() {
        guard phase == .deathSaveOffer else { return }
        phase = .finished
        didFinish = true
    }

#if DEBUG
    func forceDefeatForTesting() {
        handleForcedDefeatForTesting()
    }

    func completeCurrentWaveForTesting() {
        let events = simulation.completeCurrentWaveForTesting()
        snapshot = simulation.snapshot
        hudState = HUDState(snapshot: snapshot)
        recentEvents = events
        if !events.isEmpty { eventPulse += 1 }
        for event in events {
            handle(event)
        }
    }
#endif

    private func handle(_ event: SimulationEvent) {
        lastEvent = event
        switch event {
        case .checkpoint:
            phase = .draft(makeDraft())
        case .worldTransitioned(let from, let to):
            phase = .worldTransition(from: from, to: to, draft: makeDraft())
        case .finished(let didWin):
            if !didWin && !deathSaveWasUsed {
                phase = .deathSaveOffer
            } else {
                phase = .finished
                didFinish = true
            }
        default:
            break
        }
    }

    private func updateDeathSaveCountdown(delta: TimeInterval) {
        deathSaveCountdownRemaining = max(
            0,
            deathSaveCountdownRemaining - delta
        )
        let secondsRemaining = Int(
            ceil(deathSaveCountdownRemaining)
        )
        if secondsRemaining != deathSaveCountdownSeconds {
            deathSaveCountdownSeconds = secondsRemaining
        }
        guard deathSaveCountdownRemaining == 0 else { return }

        phase = .playing
        lastTime = nil
    }

#if DEBUG
    private func handleForcedDefeatForTesting() {
        let events = simulation.forceDefeatForTesting()
        snapshot = simulation.snapshot
        hudState = HUDState(snapshot: snapshot)
        recentEvents = events
        if !events.isEmpty { eventPulse += 1 }
        for event in events {
            handle(event)
        }
    }
#endif

    private func makeDraft() -> [RunUpgradeChoice] {
        var pool: [RunUpgradeChoice]
        if mode.isEndless {
            pool = RunUpgradeChoice.endlessPool
        } else {
            pool = [.powerDrive, .quickRelease, .throughBall, .curler, .oneTwo, .cleanSheet]
                .filter { simulation.abilityRank($0) < 3 }
                .map(RunUpgradeChoice.ability)
        }
        var choices: [RunUpgradeChoice] = []
        while choices.count < min(3, pool.count) {
            let index = Int(random.next() % UInt64(pool.count))
            choices.append(pool.remove(at: index))
        }
        return choices
    }
}

private extension Array where Element == String {
    func value(after key: String) -> String? {
        guard let index = firstIndex(of: key), indices.contains(index + 1) else { return nil }
        return self[index + 1]
    }
}
