import SwiftUI

struct CharacterRosterCard: View {
    let character: CharacterDefinition
    let isUnlocked: Bool
    let isSelected: Bool
    let select: () -> Void

    var body: some View {
        VStack(spacing: GoalRushTheme.Metrics.standardSpacing) {
            ZStack(alignment: .bottom) {
                accent.opacity(0.22)
                ComicInkTexture(opacity: 0.10)
                Image(character.assetStem + "Roster")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 230)
                    .saturation(isUnlocked ? 1 : 0)
                    .opacity(isUnlocked ? 1 : 0.45)
                    .accessibilityHidden(true)

                if !isUnlocked {
                    Label(character.unlockDescription, systemImage: "lock.fill")
                        .font(GoalRushTheme.Typography.subheadlineEmphasized)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 44)
                        .background(.black.opacity(0.86), in: ComicPanelShape(cut: 7))
                        .padding(.bottom, 12)
                }
            }
            .frame(maxWidth: .infinity)
            .clipShape(ComicPanelShape(cut: GoalRushTheme.Metrics.panelRadius))

            VStack(spacing: GoalRushTheme.Metrics.compactSpacing) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(character.name)
                            .font(GoalRushTheme.Typography.title2)
                        Text(character.role)
                            .font(GoalRushTheme.Typography.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if isSelected {
                        GameStatusBadge(text: "SELECTED", tone: .positive)
                    }
                }

                HStack(alignment: .top, spacing: GoalRushTheme.Metrics.standardSpacing) {
                    Image(systemName: abilityIcon)
                        .font(GoalRushTheme.Typography.title2)
                        .foregroundStyle(accent)
                        .frame(width: 48, height: 48)
                        .background(accent.opacity(0.14), in: .circle)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(character.abilityName)
                            .font(GoalRushTheme.Typography.headline)
                        Text(character.abilityDescription)
                            .font(GoalRushTheme.Typography.subheadline)
                            .foregroundStyle(.white.opacity(0.72))
                    }
                    Spacer(minLength: 0)
                }
            }

            Button(
                isSelected ? "Selected" : (isUnlocked ? "Play as \(character.name)" : character.unlockDescription),
                systemImage: isSelected ? "checkmark.circle.fill" : (isUnlocked ? "person.crop.circle.badge.checkmark" : "lock.fill"),
                action: select
            )
            .buttonStyle(GameLaunchButtonStyle())
            .disabled(!isUnlocked || isSelected)
            .accessibilityIdentifier("character-\(character.id.rawValue)")
        }
        .padding(GoalRushTheme.Metrics.standardSpacing)
        .gameSurface(.modal)
        .overlay {
            ComicPanelShape(cut: GoalRushTheme.Metrics.panelRadius)
                .stroke(isSelected ? accent : .white.opacity(0.10), lineWidth: isSelected ? 2 : 1)
        }
        .accessibilityElement(children: .contain)
    }

    private var accent: Color {
        Color(
            red: Double((character.accentHex >> 16) & 0xFF) / 255,
            green: Double((character.accentHex >> 8) & 0xFF) / 255,
            blue: Double(character.accentHex & 0xFF) / 255
        )
    }

    private var abilityIcon: String {
        switch character.ability {
        case .pinballBlitz: "arrow.left.and.right.circle.fill"
        case .timeBreak: "snowflake"
        case .meteorVolley: "meteor.fill"
        case .lastStand: "shield.lefthalf.filled"
        }
    }
}
