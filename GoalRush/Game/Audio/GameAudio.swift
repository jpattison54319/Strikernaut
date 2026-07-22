import AVFoundation
import CoreHaptics
import Foundation

@MainActor
final class GameAudio {
    private var effectPools: [String: [AVAudioPlayer]] = [:]
    private var effectPoolIndices: [String: Int] = [:]
    private var musicPlayers: [AVAudioPlayer] = []
    private var hapticEngine: CHHapticEngine?
    private var hapticPlayerPools: [HapticFeedback: [any CHHapticPatternPlayer]] = [:]
    private var hapticPoolIndices: [HapticFeedback: Int] = [:]
    private let settings: GameSettings

    init(settings: GameSettings) {
        self.settings = settings
        configureSession()
        configureHaptics()
        preloadEffects()
        if settings.musicEnabled { startMusic() }
    }

    func handle(_ event: SimulationEvent) {
        switch event {
        case .kick: play("kick", volume: 0.34, feedback: .kick)
        case .impact(_, let critical): play("impact", volume: critical ? 0.58 : 0.28, feedback: critical ? .critical : .impact)
        case .reward: play("coin", volume: 0.52, feedback: .reward)
        case .heal: play("heal", volume: 0.52, feedback: .reward)
        case .damage: play("impact", volume: 0.78, feedback: .damage)
        case .checkpoint: play("confirm", volume: 0.50, feedback: .success)
        case .abilityChosen: play("confirm", volume: 0.58, feedback: .success)
        case .bossPhase: play("boss-phase", volume: 0.84, feedback: .boss)
        case .waveCompleted: play("confirm", volume: 0.68, feedback: .success)
        case .meteorKick: play("boss-phase", volume: 0.38, feedback: .critical)
        case .comboMilestone: play("ui-combo", volume: 0.45, feedback: .reward)
        case .comboChanged: break
        case .finished(let won): play(won ? "victory" : "defeat", volume: won ? 0.72 : 0.58, feedback: won ? .success : .damage)
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
        effectPools.values.flatMap { $0 }.forEach { $0.stop() }
    }

    private func play(_ name: String, volume: Float, feedback: HapticFeedback) {
        if settings.soundEnabled, let players = effectPools[name], !players.isEmpty {
            let index = effectPoolIndices[name, default: 0] % players.count
            let player = players[index]
            player.currentTime = 0
            player.volume = volume
            player.play()
            effectPoolIndices[name] = index + 1
        }
        if settings.hapticsEnabled { playHaptic(feedback) }
    }

    private func preloadEffects() {
        let poolSizes = [
            "kick": 4,
            "impact": 6,
            "coin": 4,
            "heal": 2,
            "confirm": 2,
            "victory": 1,
            "defeat": 1,
            "boss-phase": 2,
            "ui-combo": 3
        ]
        for (name, count) in poolSizes {
            guard let url = Bundle.main.url(forResource: name, withExtension: "wav") else { continue }
            effectPools[name] = (0..<count).compactMap { _ in
                guard let player = try? AVAudioPlayer(contentsOf: url) else { return nil }
                player.prepareToPlay()
                return player
            }
        }
    }

    private func startMusic() {
        let names = ["music-calm", "music-pressure", "music-boss"]
        musicPlayers = names.compactMap { name in
            guard let url = Bundle.main.url(forResource: name, withExtension: "wav"), let player = try? AVAudioPlayer(contentsOf: url) else { return nil }
            player.numberOfLoops = -1
            player.volume = name == "music-calm" ? 0.28 : 0
            player.prepareToPlay()
            player.play()
            return player
        }
    }

    private func configureSession() {
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    private func configureHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        hapticEngine = try? CHHapticEngine()
        try? hapticEngine?.start()
        guard let hapticEngine else { return }
        for feedback in HapticFeedback.allCases {
            guard let pattern = try? CHHapticPattern(events: feedback.events, parameters: []) else { continue }
            let count = feedback == .impact ? 5 : 3
            hapticPlayerPools[feedback] = (0..<count).compactMap { _ in
                try? hapticEngine.makePlayer(with: pattern)
            }
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

    var events: [CHHapticEvent] {
        switch self {
        case .kick:
            [transient(0.30, 0.48, at: 0), transient(0.16, 0.85, at: 0.035)]
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
