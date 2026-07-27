import AVFoundation
import CoreHaptics
import Foundation

@MainActor
final class GameAudio {
    private let effects = BufferedEffectPlayer()
    private var musicPlayers: [AVAudioPlayer] = []
    private var hapticEngine: CHHapticEngine?
    private var hapticPlayerPools: [HapticFeedback: [any CHHapticPatternPlayer]] = [:]
    private var hapticPoolIndices: [HapticFeedback: Int] = [:]
    private let settings: GameSettings
    private var isPreparing = false
    private var isPrepared = false

    init(settings: GameSettings) {
        self.settings = settings
    }

    /// AVAudioPlayer and Core Haptics setup can synchronously decode files and
    /// start hardware services. Stage that work after the game view is visible,
    /// yielding between pools so entering a run never monopolizes the main actor.
    func prepare() async {
        guard !isPrepared, !isPreparing else { return }
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
        var strongestFeedback: HapticFeedback?
        for event in events {
            let feedback = handleAudio(for: event)
            if let feedback, feedback.priority > (strongestFeedback?.priority ?? Int.min) {
                strongestFeedback = feedback
            }
        }
        if settings.hapticsEnabled, let strongestFeedback {
            playHaptic(strongestFeedback)
        }
    }

    private func handleAudio(for event: SimulationEvent) -> HapticFeedback? {
        switch event {
        case .kick: play("kick", volume: 0.34); return .kick
        case .impact(let impact):
            if impact.delivery == .damageOverTime {
                play("impact", volume: 0.16)
                return nil
            }
            play("impact", volume: impact.isCritical || impact.isDefeating ? 0.62 : 0.30)
            return impact.isCritical || impact.isDefeating ? .critical : .impact
        case .elementalReaction:
            return nil
        case .reward: play("coin", volume: 0.52); return .reward
        case .heal: play("heal", volume: 0.52); return .reward
        case .damage: play("impact", volume: 0.78); return .damage
        case .checkpoint: play("confirm", volume: 0.50); return .success
        case .upgradeChosen: play("confirm", volume: 0.58); return .success
        case .bossPhase: play("boss-phase", volume: 0.84); return .boss
        case .bossAttackTelegraphed:
            play("ui-whoosh", volume: 0.72)
            return .critical
        case .bossAttackActivated(let kind, _):
            play(kind == .meteorStrike ? "impact" : "boss-phase", volume: 0.74)
            return kind == .meteorStrike ? .meteor : .boss
        case .waveCompleted: play("confirm", volume: 0.68); return .success
        case .worldTransitioned:
            play("ui-whoosh", volume: 0.92)
            play("boss-phase", volume: 0.42)
            return .boss
        case .meteorKick: play("boss-phase", volume: 0.38); return .critical
        case .comboMilestone: play("ui-combo", volume: 0.45); return .reward
        case .comboChanged: return nil
        case .worldEffectActivated:
            play("ui-whoosh", volume: 0.72)
            return .critical
        case .worldEffectImpact:
            play("impact", volume: 0.76)
            return .damage
        case .volatileCoreNeutralized:
            play("confirm", volume: 0.62)
            return .success
        case .volatileCoreDetonated:
            play("impact", volume: 0.88)
            return .damage
        case .temporaryAbilityActivated: play("confirm", volume: 0.72); return .success
        case .characterAbilityActivated: play("boss-phase", volume: 0.78); return .critical
        case .characterAbilityTargets: return nil
        case .characterProjectileRicochet: play("impact", volume: 0.44); return .impact
        case .characterMeteorImpact:
            play("impact", volume: 0.92)
            play("boss-phase", volume: 0.24)
            return .meteor
        case .characterShockwaveBurst:
            play("ui-whoosh", volume: 0.76)
            return .shockwave
        case .characterShockwaveHit:
            play("impact", volume: 0.22)
            return nil
        case .voltChain:
            play("volt-chain", volume: 0.68)
            return .critical
        case .finished(let won):
            play(won ? "victory" : "defeat", volume: won ? 0.72 : 0.58)
            return won ? .success : .damage
        }
    }

    func updateIntensity(progress: Double, bossActive: Bool) {
        guard musicPlayers.count == 3 else { return }
        musicPlayers[0].volume = bossActive ? 0.10 : 0.28
        musicPlayers[1].volume = bossActive ? 0.18 : Float(min(0.30, max(0.05, progress * 0.28)))
        musicPlayers[2].volume = bossActive ? 0.32 : 0
    }

    func stop() {
        musicPlayers.forEach { $0.stop() }
        effects.stop()
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
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        hapticEngine = try? CHHapticEngine()
        try? await hapticEngine?.start()
        guard let hapticEngine else { return }
        for feedback in HapticFeedback.allCases {
            guard let pattern = try? CHHapticPattern(events: feedback.events, parameters: []) else { continue }
            let count = switch feedback {
            case .kick, .impact: 5
            default: 3
            }
            hapticPlayerPools[feedback] = (0..<count).compactMap { _ in
                try? hapticEngine.makePlayer(with: pattern)
            }
            await Task.yield()
        }
    }

    private func playHaptic(_ feedback: HapticFeedback) {
        guard let players = hapticPlayerPools[feedback], !players.isEmpty else { return }
        let index = hapticPoolIndices[feedback, default: 0] % players.count
        try? players[index].start(atTime: CHHapticTimeImmediate)
        hapticPoolIndices[feedback] = index + 1
    }
}

private enum HapticFeedback: CaseIterable {
    case kick
    case impact
    case critical
    case reward
    case damage
    case success
    case boss
    case meteor
    case shockwave

    var priority: Int {
        switch self {
        case .kick: -1
        case .impact: 0
        case .reward: 1
        case .success: 2
        case .critical: 3
        case .shockwave: 4
        case .damage: 5
        case .meteor: 6
        case .boss: 7
        }
    }

    var events: [CHHapticEvent] {
        switch self {
        case .kick:
            [transient(0.16, 0.82, at: 0)]
        case .impact:
            [transient(0.22, 0.72, at: 0)]
        case .critical:
            [transient(0.62, 0.92, at: 0), transient(0.30, 0.62, at: 0.055)]
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
