import SwiftUI

struct OnboardingView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var page = 0

    private let pages: [(icon: String, accent: Color, title: String, message: String)] = [
        ("hand.draw.fill", GoalRushTheme.cyan, "Drag. Aim. Score.",
         "Slide your player across the lane — shots fire automatically at anything in your way."),
        ("sparkles", GoalRushTheme.gold, "Draft wild powers",
         "Every run, choose upgrades that stack into ridiculous builds. No two runs play the same."),
        ("arrow.up.circle.fill", GoalRushTheme.positive, "Get stronger forever",
         "Earn Training Tokens every run, build permanent upgrades, and unlock heroes with unique super abilities."),
    ]

    var body: some View {
        AtmosphericGameScreen(backgroundImage: "OnboardingHero") {
            VStack(spacing: GoalRushTheme.Metrics.standardSpacing) {
                skipBar

                if dynamicTypeSize.isAccessibilitySize {
                    ScrollView {
                        currentPageStage
                            .padding(.vertical, GoalRushTheme.Metrics.compactSpacing)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                } else {
                    TabView(selection: $page) {
                        ForEach(pages.indices, id: \.self) { index in
                            pageStage(at: index)
                                .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .always))
                    .indexViewStyle(.page(backgroundDisplayMode: .always))
                }

                Button(
                    page < pages.count - 1 ? "Continue" : "Kick Off",
                    systemImage: page < pages.count - 1 ? "arrow.right" : "play.fill",
                    action: advance
                )
                .buttonStyle(GameLaunchButtonStyle())
                .padding(.horizontal, GoalRushTheme.Metrics.horizontalPadding)
                .padding(.bottom, GoalRushTheme.Metrics.sectionSpacing)
                .accessibilityIdentifier("onboarding-next")
            }
        }
        .onChange(of: page) { _, _ in
            store.uiAudio.play(.whoosh, volume: 0.5, feedback: nil)
        }
    }

    private var skipBar: some View {
        HStack {
            GameStatusBadge(text: "\(page + 1) OF \(pages.count)", tone: .neutral)
            Spacer()
            if page < pages.count - 1 {
                Button("Skip", action: finish)
                    .font(GoalRushTheme.Typography.subheadlineEmphasized)
                    .foregroundStyle(.secondary)
                    .frame(minWidth: GoalRushTheme.Metrics.minimumTapTarget, minHeight: GoalRushTheme.Metrics.minimumTapTarget)
                    .accessibilityIdentifier("onboarding-skip")
            }
        }
        .padding(.horizontal, GoalRushTheme.Metrics.horizontalPadding)
        .padding(.top, GoalRushTheme.Metrics.compactSpacing)
    }

    private var currentPageStage: some View {
        pageStage(at: page)
    }

    private func pageStage(at index: Int) -> some View {
        OnboardingPageStage(
            icon: pages[index].icon,
            accent: pages[index].accent,
            title: pages[index].title,
            message: pages[index].message,
            usesFlexibleSpacing: !dynamicTypeSize.isAccessibilitySize
        )
        .padding(.horizontal, GoalRushTheme.Metrics.horizontalPadding)
    }

    private func advance() {
        if page < pages.count - 1 {
            store.uiAudio.play(.tap)
            withAnimation(reduceMotion ? nil : GoalRushTheme.Motion.transition) {
                page += 1
            }
        } else {
            finish()
        }
    }

    private func finish() {
        store.uiAudio.play(.fanfare, volume: 0.6)
        store.completeOnboarding()
        store.start(level: 1)
    }
}
