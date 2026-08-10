import SwiftUI

struct RelicCompactEffectGrid: View {
    let affixes: [EndlessRelicAffix]
    var color: Color = .white

    private var columns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: 3),
            count: affixes.count > 1 ? 2 : 1
        )
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 2) {
            ForEach(affixes) { affix in
                Text(affix.compactText)
                    .font(GoalRushTheme.Typography.caption2)
                    .monospacedDigit()
                    .foregroundStyle(color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.58)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel(affix.accessibilityText)
            }
        }
    }
}
