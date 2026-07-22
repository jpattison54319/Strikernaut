import SwiftUI

struct OnboardingView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var page = 0

    private let pages: [(icon: String, accent: Color, title: String, message: String)] = [
        ("hand.draw.fill", GoalRushTheme.cyan, "Drag. Aim. Score.",
         "Slide your player across the lane — shots fire automatically at anything in your way."),
        ("sparkles", GoalRushTheme.gold, "Draft wild powers",
         "Every run, choose upgrades that stack into ridiculous builds. No two runs play the same."),
        ("arrow.up.circle.fill", GoalRushTheme.positive, "Get stronger forever",
         "Earn Training Tokens every run and spend them on permanent upgrades, gear, and glory."),
    ]

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [GoalRushTheme.navy, GoalRushTheme.blue.opacity(0.30), GoalRushTheme.navy],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                HStack {
                    Spacer()
                    if page < pages.count - 1 {
                        Button("Skip") { finish() }
                            .font(.subheadline.bold())
                            .foregroundStyle(.secondary)
                            .frame(minWidth: 44, minHeight: 44)
                            .accessibilityIdentifier("onboarding-skip")
                    }
                }
                .padding(.horizontal, 16)

                TabView(selection: $page) {
                    ForEach(pages.indices, id: \.self) { index in
                        VStack(spacing: 22) {
                            Spacer()
                            Image(systemName: pages[index].icon)
                                .font(.system(size: 84, weight: .bold))
                                .foregroundStyle(pages[index].accent)
                                .shadow(color: pages[index].accent.opacity(0.4), radius: 24)
                            VStack(spacing: 10) {
                                Text(pages[index].title)
                                    .font(.largeTitle.bold())
                                    .multilineTextAlignment(.center)
                                Text(pages[index].message)
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: 300)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 24)
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))
                .onChange(of: page) { _, _ in store.uiAudio.play(.whoosh, volume: 0.5) }

                Button(page < pages.count - 1 ? "Continue" : "Kick Off", systemImage: page < pages.count - 1 ? "arrow.right" : "play.fill") {
                    if page < pages.count - 1 {
                        store.uiAudio.play(.tap)
                        withAnimation(reduceMotion ? nil : .snappy) { page += 1 }
                    } else {
                        finish()
                    }
                }
                .buttonStyle(PrimaryGameButton())
                .padding(.horizontal, 24)
                .padding(.bottom, 30)
                .accessibilityIdentifier("onboarding-next")
            }
        }
    }

    private func finish() {
        store.uiAudio.play(.fanfare, volume: 0.6)
        store.completeOnboarding()
        store.start(level: 1)
    }
}
