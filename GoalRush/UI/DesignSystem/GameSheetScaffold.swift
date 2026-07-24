import SwiftUI

struct GameSheetScaffold<Content: View>: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let subtitle: String?
    @ViewBuilder let content: Content

    init(title: String, subtitle: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: GoalRushTheme.Metrics.sectionSpacing) {
                    VStack(alignment: .leading, spacing: GoalRushTheme.Metrics.compactSpacing) {
                        Text(title)
                            .font(GoalRushTheme.Typography.display)
                            .foregroundStyle(.white)

                        if let subtitle, !subtitle.isEmpty {
                            Text(subtitle)
                                .font(GoalRushTheme.Typography.subheadline)
                                .foregroundStyle(.white.opacity(0.72))
                        }
                    }

                    content
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, GoalRushTheme.Metrics.horizontalPadding)
                .padding(.vertical, GoalRushTheme.Metrics.sectionSpacing)
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(GoalRushTheme.navy.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
        }
        .tint(GoalRushTheme.cyan)
        .presentationBackground(GoalRushTheme.navy)
    }
}
