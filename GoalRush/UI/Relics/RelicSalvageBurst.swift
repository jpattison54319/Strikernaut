import SwiftUI

struct RelicSalvageBurst: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let scrap: Int
    @State private var isExpanded = false

    var body: some View {
        ZStack {
            ForEach(0..<10, id: \.self) { index in
                Image(systemName: index.isMultiple(of: 2) ? "sparkle" : "diamond.fill")
                    .font(.system(size: index.isMultiple(of: 2) ? 18 : 11, weight: .black))
                    .foregroundStyle(index.isMultiple(of: 3) ? GoalRushTheme.cyan : GoalRushTheme.gold)
                    .offset(y: isExpanded && !reduceMotion ? -82 : -18)
                    .rotationEffect(.degrees(Double(index) * 36))
                    .opacity(isExpanded ? 0 : 1)
                    .scaleEffect(isExpanded ? 1.2 : 0.35)
            }

            VStack(spacing: 4) {
                Image(systemName: "arrow.3.trianglepath")
                    .font(.system(size: 28, weight: .black))
                Text("+\(GameNumberFormatter.compact(scrap)) Scrap")
                    .font(GoalRushTheme.Typography.title2)
            }
            .foregroundStyle(GoalRushTheme.navy)
            .padding(.horizontal, 24)
            .frame(minHeight: 92)
            .background(GoalRushTheme.gold, in: ComicPanelShape(cut: 12))
            .overlay {
                ComicPanelShape(cut: 12)
                    .stroke(GoalRushTheme.ink, lineWidth: 3)
            }
            .scaleEffect(isExpanded && !reduceMotion ? 1.05 : 0.82)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(GameNumberFormatter.exact(scrap)) Scrap recovered"
        )
        .onAppear {
            withAnimation(
                reduceMotion ? .easeOut(duration: 0.16) : .spring(duration: 0.52, bounce: 0.46)
            ) {
                isExpanded = true
            }
        }
    }
}
