import AVFoundation
import CoreHaptics
import Foundation

@MainActor
final class GameAudio {
    private let effects = BufferedEffectPlayer()
    private var musicPlayers: [AVAudioPlayer] = []
    private var hapticEngine: CHHapticEngine?
    private var hapticPlayerPools: [
        GameHapticCue.Kind: [any CHHapticPatternPlayer]
    ] = [:]
    private var hapticPoolIndices: [GameHapticCue.Kind: Int] = [:]
    private var pendingHapticCues: [GameHapticCue] = []
    private let settings: GameSettings
    private let supportsHaptics: Bool
    private var isPreparing = false
    private var isPrepared = false
    private var isHapticEngineRunning = false
    private var isRestartingHaptics = false
    private var hapticRestartRequested = false
    private var acceptsHapticPlayback = true

    init(settings: GameSettings) {
        self.settings = settings
        self.supportsHaptics = CHHapticEngine.capabilitiesForHardware()
            .supportsHaptics
    }

    /// AVAudioPlayer and Core Haptics setup can synchronously decode files and
    /// start hardware services. Stage that work after the game view is visible,
    /// yielding between pools so entering a run never monopolizes the main actor.
    func prepare() async {
        guard !isPrepared, !isPreparing else { return }
        acceptsHapticPlayback = true
        isPreparing = true
        configureSession()
        await Task.yield()
        await configureHaptics()
        await preloadEffects()
        if settings.musicEnabled, !Task.isCancelled {
            await startMusic()
        }
        isPrepared = !Task.isCancelled
        isPreparing = false
    }

    func handle(_ events: [SimulationEvent]) {
        for event in events {
            handleAudio(for: event)
            if settings.hapticsEnabled, supportsHaptics {
                for cue in GameHapticPlanner.cues(for: event) {
                    playHaptic(cue)
                }
            }
        }
    }

    private func handleAudio(for event: SimulationEvent) {
        switch event {
        case .kick:
            play("kick", volume: 0.34)
        case .impact(let impact):
            if impact.delivery == .damageOverTime {
                play("impact", volume: 0.16)
            } else {
                play(
                    "impact",
                    volume: impact.isCritical || impact.isDefeating ? 0.62 : 0.30
                )
            }
        case .elementalReaction:
            break
        case .reward:
            play("coin", volume: 0.52)
        case .heal:
            play("heal", volume: 0.52)
        case .damage:
            play("impact", volume: 0.78)
        case .checkpoint:
            play("confirm", volume: 0.50)
        case .upgradeChosen:
            play("confirm", volume: 0.58)
        case .bossPhase:
            play("boss-phase", volume: 0.84)
        case .bossAttackTelegraphed:
            play("ui-whoosh", volume: 0.72)
        case .bossAttackActivated(let kind, _):
            play(kind == .meteorStrike ? "impact" : "boss-phase", volume: 0.74)
        case .waveCompleted:
            play("confirm", volume: 0.68)
        case .worldTransitioned:
            play("ui-whoosh", volume: 0.92)
            play("boss-phase", volume: 0.42)
        case .meteorKick:
            play("boss-phase", volume: 0.38)
        case .comboMilestone:
            play("ui-combo", volume: 0.45)
        case .comboChanged:
            break
        case .worldEffectActivated:
            play("ui-whoosh", volume: 0.72)
        case .worldEffectImpact:
            play("impact", volume: 0.76)
        case .volatileCoreNeutralized:
            play("confirm", volume: 0.62)
        case .volatileCoreDetonated:
            play("impact", volume: 0.88)
        case .temporaryAbilityActivated:
            play("confirm", volume: 0.72)
        case .characterAbilityActivated:
            play("boss-phase", volume: 0.78)
        case .characterAbilityTargets:
            break
        case .characterProjectileRicochet:
            play("impact", volume: 0.44)
        case .characterMeteorImpact:
            play("impact", volume: 0.92)
            play("boss-phase", volume: 0.24)
        case .characterShockwaveBurst:
            play("ui-whoosh", volume: 0.76)
        case .characterShockwaveHit:
            play("impact", volume: 0.22)
        case .characterAbilityEffect(let effect):
            switch effect {
            case .timeShatter:
                play("impact", volume: 0.84)
                play("ui-whoosh", volume: 0.42)
            case .galeLanding:
                play("impact", volume: 0.72)
            case .galeInterception:
                play("impact", volume: 0.92)
            case .haloContact:
                play("impact", volume: 0.34)
            case .magneticTrapSnap:
                play("impact", volume: 0.68)
                play("volt-chain", volume: 0.30)
            case .tidalLaunch(_, let round, _):
                play("ui-whoosh", volume: 0.52 + Float(round) * 0.08)
            case .tidalHit:
                play("impact", volume: 0.46)
            }
        case .specialBallEffect(let effect):
            switch effect {
            case .gravityVortex:
                play("ui-whoosh", volume: 0.56)
                play("impact", volume: 0.28)
            case .magnetMark:
                play("volt-chain", volume: 0.34)
            case .orbitRedirect:
                play("ui-whoosh", volume: 0.42)
            case .returnShot:
                play("ui-whoosh", volume: 0.46)
            case .solarPierce:
                play("impact", volume: 0.52)
            case .tidalPush:
                play("ui-whoosh", volume: 0.44)
            }
        case .voltChain:
            play("volt-chain", volume: 0.68)
        case .finished(let won):
            play(won ? "victory" : "defeat", volume: won ? 0.72 : 0.58)
        }
    }

    func updateIntensity(progress: Double, bossActive: Bool) {
        guard musicPlayers.count == 3 else { return }
        musicPlayers[0].volume = bossActive ? 0.10 : 0.28
        musicPlayers[1].volume = bossActive ? 0.18 : Float(min(0.30, max(0.05, progress * 0.28)))
        musicPlayers[2].volume = bossActive ? 0.32 : 0
    }

    func stop() {
        acceptsHapticPlayback = false
        hapticRestartRequested = false
        musicPlayers.forEach { $0.stop() }
        effects.stop()
        hapticEngine?.stop(completionHandler: nil)
        hapticEngine = nil
        hapticPlayerPools.removeAll(keepingCapacity: false)
        hapticPoolIndices.removeAll(keepingCapacity: false)
        pendingHapticCues.removeAll(keepingCapacity: false)
        isHapticEngineRunning = false
    }

    private func play(_ name: String, volume: Float) {
        if settings.soundEnabled {
            effects.play(name, volume: volume)
        }
    }

    private func preloadEffects() async {
        let poolSpecs: [BufferedEffectPlayer.PoolSpec] = [
            .init(name: "kick", resources: ["kick", "kick-2", "kick-3"], voiceCount: 6),
            .init(name: "impact", resources: ["impact", "impact-2", "impact-3"], voiceCount: 6),
            .init(name: "coin", resources: ["coin"], voiceCount: 4),
            .init(name: "heal", resources: ["heal"], voiceCount: 2),
            .init(name: "confirm", resources: ["confirm"], voiceCount: 2),
            .init(name: "victory", resources: ["victory"], voiceCount: 1),
            .init(name: "defeat", resources: ["defeat"], voiceCount: 1),
            .init(name: "boss-phase", resources: ["boss-phase"], voiceCount: 2),
            .init(name: "ui-combo", resources: ["ui-combo"], voiceCount: 3),
            .init(name: "ui-whoosh", resources: ["ui-whoosh"], voiceCount: 4),
            .init(name: "volt-chain", resources: ["volt-chain"], voiceCount: 3)
        ]
        await effects.prepare(specs: poolSpecs)
    }

    private func startMusic() async {
        let names = ["music-calm", "music-pressure", "music-boss"]
        for name in names where !Task.isCancelled {
            guard let url = Bundle.main.url(forResource: name, withExtension: "wav"),
                  let player = try? AVAudioPlayer(contentsOf: url) else { continue }
            player.numberOfLoops = -1
            player.volume = name == "music-calm" ? 0.28 : 0
            player.prepareToPlay()
            player.play()
            musicPlayers.append(player)
            await Task.yield()
        }
    }

    private func configureSession() {
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    private func configureHaptics() async {
        guard acceptsHapticPlayback,
              supportsHaptics,
              hapticEngine == nil else {
            return
        }
        do {
            let engine = try CHHapticEngine()
            engine.isAutoShutdownEnabled = false
            installHapticRecoveryHandlers(on: engine)
            hapticEngine = engine
            try await engine.start()
            guard acceptsHapticPlayback else {
                engine.stop(completionHandler: nil)
                hapticEngine = nil
                return
            }
            isHapticEngineRunning = true
            await rebuildHapticPlayers(using: engine)
        } catch {
            isHapticEngineRunning = false
        }
    }

    func resumeHaptics() async {
        guard settings.hapticsEnabled,
              acceptsHapticPlayback,
              supportsHaptics,
              !isRestartingHaptics else {
            return
        }
        isRestartingHaptics = true
        hapticRestartRequested = false
        defer { isRestartingHaptics = false }

        if hapticEngine == nil {
            await configureHaptics()
        } else if let hapticEngine {
            do {
                try await hapticEngine.start()
                guard acceptsHapticPlayback else {
                    hapticEngine.stop(completionHandler: nil)
                    return
                }
                isHapticEngineRunning = true
                if hapticPlayerPools.isEmpty {
                    await rebuildHapticPlayers(using: hapticEngine)
                }
            } catch {
                isHapticEngineRunning = false
            }
        }

        guard isHapticEngineRunning, !pendingHapticCues.isEmpty else {
            return
        }
        let queuedCues = pendingHapticCues
        pendingHapticCues.removeAll(keepingCapacity: true)
        for cue in queuedCues {
            playHaptic(cue)
        }
    }

    private func installHapticRecoveryHandlers(on engine: CHHapticEngine) {
        engine.stoppedHandler = { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.isHapticEngineRunning = false
                self?.scheduleHapticRestart()
            }
        }
        engine.resetHandler = { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isHapticEngineRunning = false
                self.hapticPlayerPools.removeAll(keepingCapacity: true)
                self.hapticPoolIndices.removeAll(keepingCapacity: true)
                self.scheduleHapticRestart()
            }
        }
    }

    private func rebuildHapticPlayers(using engine: CHHapticEngine) async {
        hapticPlayerPools.removeAll(keepingCapacity: true)
        hapticPoolIndices.removeAll(keepingCapacity: true)
        for kind in GameHapticCue.Kind.allCases {
            guard let pattern = try? CHHapticPattern(
                events: kind.events,
                parameters: []
            ) else {
                continue
            }
            hapticPlayerPools[kind] = (0..<kind.poolSize).compactMap { _ in
                try? engine.makePlayer(with: pattern)
            }
            await Task.yield()
        }
    }

    private func playHaptic(_ cue: GameHapticCue) {
        guard isHapticEngineRunning,
              let hapticEngine,
              let players = hapticPlayerPools[cue.kind],
              !players.isEmpty else {
            queueHaptic(cue)
            scheduleHapticRestart()
            return
        }
        let index = hapticPoolIndices[cue.kind, default: 0] % players.count
        let startTime = cue.delay > 0
            ? hapticEngine.currentTime + cue.delay
            : CHHapticTimeImmediate
        do {
            try players[index].start(atTime: startTime)
            hapticPoolIndices[cue.kind] = index + 1
        } catch {
            queueHaptic(cue)
            isHapticEngineRunning = false
            scheduleHapticRestart()
        }
    }

    private func queueHaptic(_ cue: GameHapticCue) {
        guard acceptsHapticPlayback else { return }
        pendingHapticCues.append(cue)
        let maximumQueuedCues = 96
        if pendingHapticCues.count > maximumQueuedCues {
            pendingHapticCues.removeFirst(
                pendingHapticCues.count - maximumQueuedCues
            )
        }
    }

    private func scheduleHapticRestart() {
        guard settings.hapticsEnabled,
              acceptsHapticPlayback,
              !isRestartingHaptics,
              !hapticRestartRequested else {
            return
        }
        hapticRestartRequested = true
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(150))
            await self?.resumeHaptics()
        }
    }
}

private extension GameHapticCue.Kind {
    var poolSize: Int {
        switch self {
        case .electric:
            32
        case .kick, .impact, .fire:
            10
        default:
            5
        }
    }

    var events: [CHHapticEvent] {
        switch self {
        case .kick:
            // The previous 0.16 pulse was effectively imperceptible on-device
            // beside the kick audio. Keep this crisp and lighter than major
            // combat feedback, but strong enough to register as a real kick.
            [transient(0.34, 0.90, at: 0)]
        case .impact:
            [transient(0.22, 0.72, at: 0)]
        case .critical:
            [transient(0.62, 0.92, at: 0), transient(0.30, 0.62, at: 0.055)]
        case .fire:
            [transient(0.24, 0.58, at: 0)]
        case .ice:
            [transient(0.38, 0.96, at: 0), transient(0.18, 0.84, at: 0.045)]
        case .reverse:
            [transient(0.30, 0.34, at: 0), transient(0.18, 0.22, at: 0.065)]
        case .electric:
            [transient(0.34, 1.0, at: 0)]
        case .explosive:
            [transient(0.72, 0.38, at: 0), transient(0.28, 0.18, at: 0.055)]
        case .reward:
            [transient(0.30, 0.88, at: 0), transient(0.20, 0.95, at: 0.05)]
        case .damage:
            [transient(0.90, 0.30, at: 0)]
        case .success:
            [transient(0.35, 0.65, at: 0), transient(0.45, 0.82, at: 0.09)]
        case .boss:
            [transient(1.0, 0.22, at: 0), transient(0.75, 0.38, at: 0.13)]
        case .meteor:
            [
                transient(0.95, 0.32, at: 0),
                transient(0.62, 0.20, at: 0.045),
                transient(0.34, 0.14, at: 0.11)
            ]
        case .shockwave:
            [
                transient(0.58, 0.76, at: 0),
                transient(0.34, 0.58, at: 0.075),
                transient(0.18, 0.42, at: 0.15)
            ]
        }
    }

    private func transient(_ intensity: Float, _ sharpness: Float, at time: TimeInterval) -> CHHapticEvent {
        CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
            ],
            relativeTime: time
        )
    }
}
