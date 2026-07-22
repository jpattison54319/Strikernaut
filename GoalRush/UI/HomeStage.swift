import SwiftUI

struct HomeStage: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let onDaily: () -> Void
    let onMissions: () -> Void

    var body: some View {
        let content = HomeStageContent(store: store)

        Group {
            if dynamicTypeSize.isAccessibilitySize {
                HomeAccessibilityStage(
                    content: content,
                    onDaily: onDaily,
                    onMissions: onMissions,
                    onPrimary: performPrimaryAction,
                    onCampaign: openCampaign,
                    onEndless: openEndless
                )
            } else {
                HomeCommandStage(
                    content: content,
                    onDaily: onDaily,
                    onMissions: onMissions,
                    onPrimary: performPrimaryAction,
                    onCampaign: openCampaign,
                    onEndless: openEndless
                )
            }
        }
    }

    private func performPrimaryAction() {
        store.uiAudio.play(.tap)
        switch HomePresentation.primaryAction(progress: store.progress) {
        case .campaign(let level): store.start(level: level)
        case .endless: store.route = .endless
        }
    }

    private func openCampaign() {
        store.uiAudio.play(.tap)
        store.route = .levels
    }

    private func openEndless() {
        store.uiAudio.play(.tap)
        store.route = .endless
    }
}
