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
    let loadout: GearLoadout
    var phase: Phase = .playing
    @ObservationIgnored private(set) var snapshot: SimulationSnapshot
    var hudState: HUDState
    var eventPulse = 0
    var lastEvent: SimulationEvent?
    var recentEvents: [SimulationEvent] = []
    private(set) var didFinish = false
    private var random: SeededGenerator
    private var lastTime: TimeInterval?
    private var lastHUDPublishTime: TimeInterval = 0

    convenience init(levelNumber: Int, progress: PlayerProgress, settings: GameSettings) {
        self.init(mode: .campaign(level: levelNumber), progress: progress, settings: settings)
    }

    init(mode: RunMode, progress: PlayerProgress, settings: GameSettings) {
        self.mode = mode
        self.level = mode.campaignLevel.map(GameContent.level)
        self.world = GameContent.world(mode.world)
        self.loadout = progress.loadout
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

        if mode.isEndless {
            phase = .draft(makeDraft())
        } else if let level {
            let discoveries = CampaignBriefingCatalog.discoveries(for: level)
            if !discoveries.isEmpty {
                phase = .briefing(discoveries)
            }
        }
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--show-draft") {
            phase = .draft(mode.isEndless ? [.oneTwo, .meteorStrike, .goldenGoal] : [.oneTwo, .quickRelease, .powerDrive])
        }
#endif
    }

    var levelNumber: Int? { level?.number }
    var isStarterDraft: Bool { mode.isEndless && snapshot.elapsed == 0 }

    func update(currentTime: TimeInterval) {
        guard phase == .playing else { lastTime = currentTime; return }
        let delta = lastTime.map { currentTime - $0 } ?? 1.0 / 60.0
        lastTime = currentTime
        let events = simulation.update(delta: delta)
        snapshot = simulation.snapshot
        recentEvents = events
        if !events.isEmpty { eventPulse += 1 }
        if currentTime - lastHUDPublishTime >= 0.10 || !events.isEmpty {
            hudState = HUDState(snapshot: snapshot)
            lastHUDPublishTime = currentTime
        }
        for event in events { handle(event) }
    }

    func setPlayerTarget(_ x: Double) { simulation.setPlayerTarget(x: x) }

    func startCampaignLevel() {
        guard case .briefing = phase else { return }
        phase = .playing
        lastTime = nil
    }

    func choose(_ ability: AbilityKind) {
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
