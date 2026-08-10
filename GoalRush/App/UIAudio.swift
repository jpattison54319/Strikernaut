import AVFoundation
import Foundation
import Observation

@MainActor
@Observable
final class UIAudio {
    enum Sound: String, CaseIterable {
        case tap = "ui-tap"
        case whoosh = "ui-whoosh"
        case purchase = "ui-purchase"
        case claim = "ui-claim"
        case fanfare = "ui-fanfare"
        case draft = "ui-draft"
        case locked = "ui-locked"
        case combo = "ui-combo"
    }

    enum Feedback {
        case selection
        case success
        case warning
        case impact
    }

    var isEnabled: Bool
    var isHapticsEnabled: Bool
    private(set) var selectionFeedbackPulse = 0
    private(set) var successFeedbackPulse = 0
    private(set) var warningFeedbackPulse = 0
    private(set) var impactFeedbackPulse = 0
    @ObservationIgnored private var pools: [Sound: [AVAudioPlayer]] = [:]
    @ObservationIgnored private var indices: [Sound: Int] = [:]
    @ObservationIgnored private var isPreparing = false

    init(soundEnabled: Bool, hapticsEnabled: Bool) {
        self.isEnabled = soundEnabled
        self.isHapticsEnabled = hapticsEnabled
    }

    /// Prepares UI sounds without delaying initial view construction. Missing
    /// sounds are intentionally skipped until ready rather than decoded inside
    /// a button action, keeping interaction latency deterministic.
    func prepare() async {
        guard pools.isEmpty, !isPreparing else { return }
        isPreparing = true
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        await Task.yield()
        for sound in Sound.allCases {
            guard !Task.isCancelled else { break }
            guard let url = Bundle.main.url(forResource: sound.rawValue, withExtension: "wav") else { continue }
            pools[sound] = (0..<3).compactMap { _ in
                guard let player = try? AVAudioPlayer(contentsOf: url) else { return nil }
                player.prepareToPlay()
                return player
            }
            await Task.yield()
        }
        isPreparing = false
    }

    func play(_ sound: Sound, volume: Float = 1.0) {
        requestFeedback(sound.defaultFeedback)
        playSound(sound, volume: volume)
    }

    func play(_ sound: Sound, volume: Float = 1.0, feedback: Feedback?) {
        if let feedback {
            requestFeedback(feedback)
        }
        playSound(sound, volume: volume)
    }

    func requestFeedback(_ feedback: Feedback) {
        guard isHapticsEnabled else { return }
        switch feedback {
        case .selection: selectionFeedbackPulse &+= 1
        case .success: successFeedbackPulse &+= 1
        case .warning: warningFeedbackPulse &+= 1
        case .impact: impactFeedbackPulse &+= 1
        }
    }

    private func playSound(_ sound: Sound, volume: Float) {
        guard isEnabled, let players = pools[sound], !players.isEmpty else { return }
        let index = indices[sound, default: 0] % players.count
        let player = players[index]
        player.currentTime = 0
        player.volume = volume
        player.play()
        indices[sound] = index + 1
    }
}

private extension UIAudio.Sound {
    var defaultFeedback: UIAudio.Feedback {
        switch self {
        case .tap, .whoosh: .selection
        case .purchase, .claim, .fanfare: .success
        case .locked: .warning
        case .draft, .combo: .impact
        }
    }
}
