import SwiftUI

struct RunLaunchView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let mode: RunMode
    let progress: PlayerProgress
    let settings: GameSettings

    @State private var launchState = LaunchState.loading
    @State private var isStartingOver = false

    var body: some View {
        Group {
            switch launchState {
            case .loading:
                loadingView
            case .offer(let checkpoint):
                RunResumePromptView(
                    checkpoint: checkpoint,
                    isStartingOver: isStartingOver,
                    continueRun: {
                        store.uiAudio.play(.tap)
                        withLaunchAnimation {
                            launchState = .playing(checkpoint)
                        }
                    },
                    startOver: {
                        startOver(checkpoint: checkpoint)
                    }
                )
            case .playing(let checkpoint):
                GameContainerView(
                    mode: mode,
                    progress: progress,
                    settings: settings,
                    checkpoint: checkpoint
                )
            }
        }
        .task {
            guard case .loading = launchState else { return }
#if DEBUG
            if ProcessInfo.processInfo.arguments.contains(
                "--run-checkpoint-preview"
            ), let checkpoint = makePreviewCheckpoint() {
                launchState = .offer(checkpoint)
                return
            }
#endif
            let checkpoint = await store.runCheckpointStore.load(
                for: mode,
                campaignCycle: mode.isEndless ? nil : progress.campaignCycle
            )
            guard !Task.isCancelled else { return }
            launchState = checkpoint.map(LaunchState.offer) ?? .playing(nil)
        }
    }

    private var loadingView: some View {
        ZStack {
            GoalRushTheme.navy.ignoresSafeArea()
            ProgressView("Checking current run…")
                .font(GoalRushTheme.Typography.headline)
                .tint(GoalRushTheme.gold)
                .foregroundStyle(.white)
                .accessibilityIdentifier("run-checkpoint-loading")
        }
    }

    private func startOver(checkpoint: RunCheckpoint) {
        guard !isStartingOver else { return }
        store.uiAudio.play(.tap)
        isStartingOver = true
        Task {
            try? await store.runCheckpointStore.delete(for: checkpoint.mode)
            guard !Task.isCancelled else { return }
            isStartingOver = false
            withLaunchAnimation {
                launchState = .playing(nil)
            }
        }
    }

    private func withLaunchAnimation(_ update: () -> Void) {
        if reduceMotion {
            update()
        } else {
            withAnimation(GoalRushTheme.Motion.transition, update)
        }
    }

#if DEBUG
    private func makePreviewCheckpoint() -> RunCheckpoint? {
        let session = GameSessionModel(
            mode: mode,
            progress: progress,
            settings: settings
        )
        if case .briefing = session.phase {
            session.startCampaignLevel()
        } else if case .draft(let choices) = session.phase,
                  let first = choices.first {
            session.choose(first)
        }
        switch mode {
        case .campaign:
            session.simulation.setCampaignWaveForTesting(2)
        case .endless:
            session.simulation.setEndlessWaveForTesting(6)
        }
        session.simulation.setTokensForTesting(128)
        session.completeCurrentWaveForTesting()
        return session.makeRunCheckpoint(
            creditedRunTokens: session.snapshot.tokens,
            previous: nil
        )
    }
#endif
}

private extension RunLaunchView {
    enum LaunchState {
        case loading
        case offer(RunCheckpoint)
        case playing(RunCheckpoint?)
    }
}
