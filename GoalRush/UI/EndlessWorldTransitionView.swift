import SwiftUI

struct EndlessWorldTransitionView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let from: WorldID
    let to: WorldID
    let hapticsEnabled: Bool
    let onComplete: () -> Void

    @State private var departingOffset = 0.0
    @State private var departingOpacity = 1.0
    @State private var arrivingOffset = -430.0
    @State private var arrivingOpacity = 0.0
    @State private var arrivingScale = 0.92
    @State private var impactGlow = 0.0
    @State private var overlayOpacity = 1.0
    @State private var didSlam = false

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            Circle()
                .stroke(.white.opacity(0.20), lineWidth: 3)
                .frame(width: 250, height: 250)
                .scaleEffect(0.72 + impactGlow * 0.52)
                .opacity(impactGlow)
                .accessibilityHidden(true)

            Text(GameContent.world(from).name)
                .font(GoalRushTheme.Typography.display(size: 58, relativeTo: .largeTitle))
                .foregroundStyle(.white)
                .offset(y: departingOffset)
                .opacity(departingOpacity)
                .accessibilityHidden(true)

            Text(GameContent.world(to).name)
                .font(GoalRushTheme.Typography.display(size: 64, relativeTo: .largeTitle))
                .foregroundStyle(.white)
                .scaleEffect(arrivingScale)
                .offset(y: arrivingOffset)
                .opacity(arrivingOpacity)
                .shadow(color: to.accentColor.opacity(0.72), radius: 20)
                .accessibilityHidden(true)
        }
        .opacity(overlayOpacity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "Leaving \(GameContent.world(from).name). Entering \(GameContent.world(to).name)."
        )
        .accessibilityIdentifier("endless-world-transition")
        .sensoryFeedback(trigger: didSlam) { _, slammed in
            guard slammed, hapticsEnabled, !reduceMotion else { return nil }
            return .impact(weight: .heavy, intensity: 1)
        }
        .task {
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 350 : 620))
            guard !Task.isCancelled else { return }
            beginTransition()
        }
    }

    private func beginTransition() {
        if reduceMotion {
            withAnimation(.easeOut(duration: 0.22)) {
                departingOpacity = 0
                arrivingOpacity = 1
                arrivingOffset = 0
                arrivingScale = 1
            } completion: {
                finishAfterHold()
            }
            return
        }

        withAnimation(.easeIn(duration: 0.34)) {
            departingOffset = 470
            departingOpacity = 0
        } completion: {
            arrivingOpacity = 1
            withAnimation(.spring(duration: 0.48, bounce: 0.12)) {
                arrivingOffset = 0
                arrivingScale = 1.10
            } completion: {
                didSlam = true
                withAnimation(.spring(duration: 0.20, bounce: 0.44)) {
                    arrivingScale = 1
                    impactGlow = 1
                } completion: {
                    withAnimation(.easeOut(duration: 0.34)) {
                        impactGlow = 0
                    } completion: {
                        finishAfterHold()
                    }
                }
            }
        }
    }

    private func finishAfterHold() {
        Task {
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 500 : 680))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.18)) {
                overlayOpacity = 0
            } completion: {
                onComplete()
            }
        }
    }
}
