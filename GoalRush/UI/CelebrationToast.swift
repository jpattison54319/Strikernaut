import SwiftUI

struct CelebrationToast: View {
    let celebration: Celebration
    let dismiss: () -> Void
    @Environment(GameStore.self) private var store
    @State private var autoDismissTask: Task<Void, Never>?

    var body: some View {
        Group {
            switch celebration {
            case .achievement(let id):
                ToastBanner(
                    icon: AchievementCatalog.icon(for: id),
                    title: "ACHIEVEMENT UNLOCKED",
                    subtitle: AchievementCatalog.title(for: id),
                    accent: GoalRushTheme.gold
                )
            }
        }
        .contentShape(ComicPanelShape(cut: 10))
        .onTapGesture { dismiss() }
        .sensoryFeedback(.success, trigger: celebration)
        .onAppear {
            if case .achievement(let id) = celebration {
                AccessibilityNotification.Announcement("Achievement unlocked: \(AchievementCatalog.title(for: id))").post()
            }
            store.uiAudio.play(.fanfare, volume: 0.7)
            autoDismissTask = Task {
                try? await Task.sleep(for: .seconds(3.5))
                guard !Task.isCancelled else { return }
                dismiss()
            }
        }
        .onDisappear { autoDismissTask?.cancel() }
        .accessibilityAddTraits(.isButton)
    }
}
