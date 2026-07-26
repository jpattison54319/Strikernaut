import Testing
@testable import GoalRush

@MainActor
struct UIAudioFeedbackTests {
    @Test func buttonSoundRequestsMappedHapticWhenSoundIsDisabled() {
        let audio = UIAudio(soundEnabled: false, hapticsEnabled: true)

        audio.play(.tap)
        audio.play(.purchase)
        audio.play(.locked)
        audio.play(.combo)

        #expect(audio.selectionFeedbackPulse == 1)
        #expect(audio.successFeedbackPulse == 1)
        #expect(audio.warningFeedbackPulse == 1)
        #expect(audio.impactFeedbackPulse == 1)
    }

    @Test func hapticPreferencePreventsFeedbackPulses() {
        let audio = UIAudio(soundEnabled: true, hapticsEnabled: false)

        audio.play(.tap)
        audio.requestFeedback(.success)

        #expect(audio.selectionFeedbackPulse == 0)
        #expect(audio.successFeedbackPulse == 0)
    }

    @Test func appearanceSoundCanExplicitlyAvoidButtonFeedback() {
        let audio = UIAudio(soundEnabled: false, hapticsEnabled: true)

        audio.play(.fanfare, feedback: nil)

        #expect(audio.successFeedbackPulse == 0)
    }
}
