import SwiftUI

struct CharacterAbilityButton: View {
    let character: CharacterDefinition
    let charge: Double
    let isReady: Bool
    let activate: () -> Void

    var body: some View {
        Button(character.abilityName, systemImage: "bolt.fill", action: activate)
            .labelStyle(CharacterAbilityLabelStyle(
                character: character,
                charge: charge,
                isReady: isReady
            ))
            .disabled(!isReady)
            .accessibilityValue(isReady ? "Ready" : "\(Int(charge)) percent charged")
            .accessibilityHint(isReady ? "Activates \(character.abilityDescription)" : "Defeat enemies to build charge")
            .accessibilityIdentifier("character-ability")
    }
}

private struct CharacterAbilityLabelStyle: LabelStyle {
    let character: CharacterDefinition
    let charge: Double
    let isReady: Bool

    func makeBody(configuration: Configuration) -> some View {
        VStack(spacing: 5) {
            ZStack {
                Circle()
                    .fill(.black.opacity(0.78))
                Circle()
                    .stroke(.white.opacity(0.18), lineWidth: 5)
                Circle()
                    .trim(from: 0, to: min(1, max(0, charge / 100)))
                    .stroke(
                        isReady ? GoalRushTheme.gold : GoalRushTheme.cyan,
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                CharacterAbilityIcon(ability: character.ability, isReady: isReady)
            }
            .frame(width: 70, height: 70)
            .shadow(color: (isReady ? GoalRushTheme.gold : GoalRushTheme.cyan).opacity(isReady ? 0.65 : 0.25), radius: 13)

            Text(isReady ? "READY" : "\(Int(charge))%")
                .font(.caption2.bold())
                .foregroundStyle(isReady ? GoalRushTheme.gold : .white)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(.black.opacity(0.72), in: .capsule)
        }
        .contentShape(.rect)
    }
}
