import SwiftUI

struct ToastBanner: View {
    let icon: String
    let title: String
    let subtitle: String
    var accent: Color = GoalRushTheme.gold

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3.bold())
                .foregroundStyle(GoalRushTheme.navy)
                .frame(width: 40, height: 40)
                .background(accent, in: .circle)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.bold())
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: .capsule)
        .overlay { Capsule().stroke(accent.opacity(0.45)) }
        .shadow(color: accent.opacity(0.25), radius: 14, y: 6)
        .padding(.horizontal, 16)
        .accessibilityElement(children: .combine)
    }
}
