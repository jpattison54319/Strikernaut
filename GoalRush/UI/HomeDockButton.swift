import SwiftUI

struct HomeDockButton: View {
    let title: String
    let systemImage: String
    let identifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.headline.bold())
                Text(title)
                    .font(.caption.bold())
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity, minHeight: GoalRushTheme.Metrics.minimumTapTarget)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .accessibilityIdentifier(identifier)
    }
}
