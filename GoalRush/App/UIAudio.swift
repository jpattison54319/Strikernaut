import AVFoundation
import Foundation

@MainActor
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

    var isEnabled: Bool
    private var pools: [Sound: [AVAudioPlayer]] = [:]
    private var indices: [Sound: Int] = [:]

    init(soundEnabled: Bool) {
        self.isEnabled = soundEnabled
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        for sound in Sound.allCases {
            guard let url = Bundle.main.url(forResource: sound.rawValue, withExtension: "wav") else { continue }
            pools[sound] = (0..<3).compactMap { _ in
                guard let player = try? AVAudioPlayer(contentsOf: url) else { return nil }
                player.prepareToPlay()
                return player
            }
        }
    }

    func play(_ sound: Sound, volume: Float = 1.0) {
        guard isEnabled, let players = pools[sound], !players.isEmpty else { return }
        let index = indices[sound, default: 0] % players.count
        let player = players[index]
        player.currentTime = 0
        player.volume = volume
        player.play()
        indices[sound] = index + 1
    }
}
