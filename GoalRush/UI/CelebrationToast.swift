import SwiftUI

struct CelebrationToast: View {
    let celebration: Celebration
    let dismiss: () -> Void
    @Environment(GameStore.self) private var store
    @State private var autoDismissTask: Task<Void, Never>?

    var body: some View {
        Button {
            store.uiAudio.requestFeedback(.selection)
            dismiss()
        } label: {
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
        }
        .buttonStyle(.plain)
        .contentShape(ComicPanelShape(cut: 10))
        .sensoryFeedback(.success, trigger: celebration)
        .onAppear {
            if case .achievement(let id) = celebration {
                AccessibilityNotification.Announcement("Achievement unlocked: \(AchievementCatalog.title(for: id))").post()
            }
            store.uiAudio.play(.fanfare, volume: 0.7, feedback: nil)
            autoDismissTask = Task {
                try? await Task.sleep(for: .seconds(3.5))
                guard !Task.isCancelled else { return }
                dismiss()
            }
        }
        .onDisappear { autoDismissTask?.cancel() }
    }
}
