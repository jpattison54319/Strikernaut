import SwiftUI

struct CampaignLandmarkNode: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let level: LevelDefinition
    let symbol: String
    let record: LevelRecord?
    let maximumStamina: Double
    let isUnlocked: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 3) {
                ZStack {
                    Ellipse()
                        .fill(.black.opacity(0.38))
                        .frame(width: level.hasBoss ? 88 : 70, height: level.hasBoss ? 28 : 22)
                        .offset(y: 27)

                    Image(systemName: symbol)
                        .font(.system(size: level.hasBoss ? 50 : 38, weight: .bold))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(
                            isUnlocked ? level.world.accentColor : .white.opacity(0.28),
                            isUnlocked ? GoalRushTheme.navy : .black.opacity(0.50)
                        )
                        .offset(y: -14)
                        .shadow(color: isCurrent ? level.world.accentColor.opacity(0.70) : .clear, radius: 12)

                    Text("\(level.worldLevel)")
                        .font(GoalRushTheme.Typography.metric(size: level.hasBoss ? 24 : 20, relativeTo: .title2))
                        .foregroundStyle(isUnlocked ? GoalRushTheme.navy : .white)
                        .frame(width: level.hasBoss ? 50 : 44, height: level.hasBoss ? 50 : 44)
                        .background(isUnlocked ? level.world.accentColor : .black.opacity(0.78), in: .circle)
                        .overlay {
                            Circle()
                                .stroke(.white.opacity(isUnlocked ? 0.88 : 0.36), lineWidth: 3)
                        }
                        .offset(y: 18)

                    if !isUnlocked {
                        Image(systemName: "lock.fill")
                            .font(GoalRushTheme.Typography.subheadlineEmphasized)
                            .foregroundStyle(.white)
                            .frame(width: 30, height: 30)
                            .background(.black.opacity(0.82), in: .circle)
                            .offset(x: 26, y: 1)
                    }
                }
                .frame(width: 92, height: 82)

                HStack(spacing: 3) {
                    ForEach(0..<3, id: \.self) { index in
                        Image(systemName: index < stars ? "star.fill" : "star")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(isUnlocked ? GoalRushTheme.gold : .white.opacity(0.28))
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(.black.opacity(0.62), in: .capsule)
                .accessibilityHidden(true)

                Text(level.name)
                    .font(GoalRushTheme.Typography.captionEmphasized)
                    .foregroundStyle(isUnlocked ? .white : .white.opacity(0.50))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 116)
                    .shadow(color: .black, radius: 2, x: 0, y: 1)
            }
            .frame(width: 124, height: 132)
            .scaleEffect(isCurrent && !reduceMotion ? 1.04 : 1)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isCurrent)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("level-\(level.number)")
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(isUnlocked ? "Starts the challenge" : unlockHint)
    }

    private var isCurrent: Bool {
        isUnlocked && record?.completed != true
    }

    private var stars: Int {
        guard record?.completed == true, maximumStamina > 0 else { return 0 }
        return StarRating.stars(
            staminaFraction: min(1, (record?.bestStamina ?? 0) / maximumStamina)
        )
    }

    private var unlockHint: String {
        level.worldLevel == 1
            ? "Clear the previous world first"
            : "Clear challenge \(level.worldLevel - 1) first"
    }

    private var accessibilityLabel: String {
        if !isUnlocked {
            return "Challenge \(level.worldLevel), \(level.name), locked"
        }
        if record?.completed == true {
            return "Challenge \(level.worldLevel), \(level.name), completed, \(stars) of 3 stars"
        }
        return "Challenge \(level.worldLevel), \(level.name), ready"
    }
}
