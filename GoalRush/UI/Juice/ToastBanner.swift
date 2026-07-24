import SwiftUI

struct ToastBanner: View {
    let icon: String
    let title: String
    let subtitle: String
    var accent: Color = GoalRushTheme.gold

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .accessibilityHidden(true)
                .font(GoalRushTheme.Typography.title3)
                .foregroundStyle(GoalRushTheme.navy)
                .frame(width: 40, height: 40)
                .background(accent, in: .circle)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(GoalRushTheme.Typography.subheadlineEmphasized)
                Text(subtitle).font(GoalRushTheme.Typography.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(GoalRushTheme.surfaceRaised.opacity(0.97), in: ComicPanelShape(cut: 10))
        .background {
            ComicPanelShape(cut: 10)
                .fill(GoalRushTheme.ink)
                .offset(x: 4, y: 5)
        }
        .overlay {
            ComicPanelShape(cut: 10)
                .stroke(accent.opacity(0.62), lineWidth: 2)
        }
        .padding(.horizontal, 16)
        .accessibilityElement(children: .combine)
    }
}
