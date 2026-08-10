import SwiftUI

struct AbilityDraftHeader: View {
    let eyebrow: String
    let title: String
    let scope: String

    var body: some View {
        VStack(spacing: 3) {
            Text(eyebrow)
                .font(GoalRushTheme.Typography.captionEmphasized)
                .foregroundStyle(GoalRushTheme.gold)

            Text(title)
                .font(GoalRushTheme.Typography.display(size: 34))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.75)

            Rectangle()
                .fill(GoalRushTheme.gold)
                .frame(width: 58, height: 3)
                .rotationEffect(.degrees(-1.5))
                .accessibilityHidden(true)

            Text(scope)
                .font(GoalRushTheme.Typography.captionEmphasized)
                .foregroundStyle(GoalRushTheme.paper.opacity(0.72))
        }
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}
