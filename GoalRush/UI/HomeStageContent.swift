struct HomeStageContent {
    let primaryEyebrow: String
    let primaryTitle: String
    let dailySubtitle: String
    let dailyBadge: String?
    let missionsSubtitle: String
    let missionBadge: String?
    let campaignStatus: String
    let endlessStatus: String

    init(store: GameStore) {
        let action = HomePresentation.primaryAction(progress: store.progress)
        let completedMissions = HomePresentation.completedMissionCount(store.progress.missions)
        let completedLevels = store.progress.currentCampaignClears.count
        let endlessRecord = store.progress.endlessRecord

        switch action {
        case .campaign(let levelNumber):
            primaryEyebrow = "NEXT MATCH"
            if let level = GameContent.levels.first(where: { $0.number == levelNumber }) {
                primaryTitle = "Level \(level.number): \(level.name)"
            } else {
                primaryTitle = "Continue Campaign"
            }
        case .endless:
            primaryEyebrow = store.progress.campaignCycle > 0
                ? "NG+\(store.progress.campaignCycle) COMPLETE"
                : "CAMPAIGN COMPLETE"
            primaryTitle = "Chase Your Endless Best"
        }

        dailySubtitle = store.isDailyRewardClaimable ? "Reward ready" : "Claimed today"
        dailyBadge = store.isDailyRewardClaimable ? "+\(store.nextDailyReward)" : nil
        missionsSubtitle = completedMissions > 0 ? "\(completedMissions) ready to claim" : "View objectives"
        missionBadge = completedMissions > 0 ? "\(completedMissions)" : nil
        let cycleLabel = store.progress.campaignCycle > 0
            ? "NG+\(store.progress.campaignCycle) · "
            : ""
        campaignStatus = "\(cycleLabel)\(completedLevels)/\(GameContent.levels.count) cleared"
        endlessStatus = endlessRecord.bestWave > 0
            ? "Best wave \(GameNumberFormatter.exact(endlessRecord.bestWave))"
            : "New run ready"
    }
}
