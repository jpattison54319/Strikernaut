import Foundation
import Observation

@MainActor
@Observable
final class GameSessionModel {
    enum Phase: Equatable {
        case playing
        case paused
        case briefing([CampaignDiscovery])
        case draft([AbilityKind])
        case finished
    }

    let mode: RunMode
    let level: LevelDefinition?
    let world: WorldDefinition
    let simulation: GameSimulation
    let character: CharacterDefinition
    var phase: Phase = .playing
    @ObservationIgnored private(set) var snapshot: SimulationSnapshot
    var hudState: HUDState
    @ObservationIgnored private(set) var eventPulse = 0
    @ObservationIgnored private(set) var lastEvent: SimulationEvent?
    @ObservationIgnored private(set) var recentEvents: [SimulationEvent] = []
    private(set) var didFinish = false
    private(set) var draftsChosen = 0
    private var random: SeededGenerator
    private var lastTime: TimeInterval?
    private var lastHUDPublishTime: TimeInterval = 0
#if DEBUG
    private var debugAutoCharacterAbilityTime: TimeInterval?
    private var debugDidAutoActivateCharacterAbility = false
#endif

    convenience init(levelNumber: Int, progress: PlayerProgress, settings: GameSettings) {
        self.init(mode: .campaign(level: levelNumber), progress: progress, settings: settings)
    }

    init(mode: RunMode, progress: PlayerProgress, settings: GameSettings) {
        self.mode = mode
        self.level = mode.campaignLevel.map(GameContent.level)
        self.world = GameContent.world(mode.world)
        self.character = CharacterCatalog.character(progress.selectedCharacter)
        let argumentSeed = ProcessInfo.processInfo.arguments.value(after: "--fixed-seed").flatMap(UInt64.init)
        let modeSeed: UInt64 = switch mode {
        case .campaign(let level): UInt64(level * 10_007 + progress.trainingTokens)
        case .endless(let world): UInt64((WorldID.allCases.firstIndex(of: world) ?? 0) * 90_001 + progress.trainingTokens + 77)
        }
        let seed = argumentSeed ?? modeSeed
        self.simulation = GameSimulation(mode: mode, progress: progress, assistMode: settings.assistMode, seed: seed)
        self.snapshot = simulation.snapshot
        self.hudState = HUDState(snapshot: simulation.snapshot)
        self.random = SeededGenerator(seed: seed ^ 0xA11B1E)

#if DEBUG
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
#endif

        if mode.isEndless {
            phase = .draft(makeDraft())
        } else if let level, !progress.seenCampaignBriefingLevels.contains(level.number) {
            let discoveries = CampaignBriefingCatalog.discoveries(for: level)
            if !discoveries.isEmpty {
                phase = .briefing(discoveries)
            }
        }
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--show-draft") {
            phase = .draft(mode.isEndless ? [.oneTwo, .meteorStrike, .goldenGoal] : [.oneTwo, .quickRelease, .powerDrive])
        }
        if ProcessInfo.processInfo.arguments.contains("--auto-kick-off") {
            if case .briefing = phase {
                phase = .playing
            } else if case .draft(let abilities) = phase, let ability = abilities.first {
                simulation.apply(ability)
                snapshot = simulation.snapshot
                hudState = HUDState(snapshot: simulation.snapshot)
                phase = .playing
            }
        }
#endif
    }

    var levelNumber: Int? { level?.number }
    var isStarterDraft: Bool { mode.isEndless && snapshot.elapsed == 0 }

    func update(currentTime: TimeInterval) {
        guard phase == .playing else { lastTime = currentTime; return }
        let delta = lastTime.map { currentTime - $0 } ?? 1.0 / 60.0
        lastTime = currentTime
        var events = simulation.update(delta: delta)
#if DEBUG
        if !debugDidAutoActivateCharacterAbility,
           let activationTime = debugAutoCharacterAbilityTime,
           simulation.snapshot.elapsed >= activationTime {
            debugDidAutoActivateCharacterAbility = true
            events.append(contentsOf: simulation.activateCharacterAbility())
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
        if currentTime - lastHUDPublishTime >= 0.10 {
            hudState = HUDState(snapshot: snapshot)
            lastHUDPublishTime = currentTime
        }
        for event in events { handle(event) }
    }

    func setPlayerTarget(_ x: Double) { simulation.setPlayerTarget(x: x) }

    func activateCharacterAbility() {
        guard phase == .playing else { return }
        let events = simulation.activateCharacterAbility()
        guard !events.isEmpty else { return }
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

    func choose(_ ability: AbilityKind) {
        draftsChosen += 1
        let previousStamina = simulation.snapshot.stamina
        simulation.apply(ability)
        snapshot = simulation.snapshot
        hudState = HUDState(snapshot: snapshot)
        recentEvents = [.abilityChosen(ability)]
        if snapshot.stamina > previousStamina {
            recentEvents.append(.heal(snapshot.stamina - previousStamina, .init(x: snapshot.playerX, y: 0.16)))
        }
        lastEvent = .abilityChosen(ability)
        eventPulse += 1
        phase = .playing
        lastTime = nil
    }

    func togglePause() {
        phase = phase == .paused ? .playing : .paused
        lastTime = nil
    }

    private func handle(_ event: SimulationEvent) {
        lastEvent = event
        switch event {
        case .checkpoint:
            phase = .draft(makeDraft())
        case .finished:
            phase = .finished
            didFinish = true
        default:
            break
        }
    }

    private func makeDraft() -> [AbilityKind] {
        var pool: [AbilityKind]
        if mode.isEndless {
            pool = AbilityKind.allCases
        } else {
            pool = [.powerDrive, .quickRelease, .throughBall, .curler, .oneTwo, .cleanSheet]
                .filter { simulation.abilityRank($0) < 3 }
        }
        var choices: [AbilityKind] = []
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
