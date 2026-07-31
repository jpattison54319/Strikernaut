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
        let completedLevels = store.progress.levelRecords.values.filter(\.completed).count
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
            primaryEyebrow = "CAMPAIGN COMPLETE"
            primaryTitle = "Chase Your Endless Best"
        }

        dailySubtitle = store.isDailyRewardClaimable ? "Reward ready" : "Claimed today"
        dailyBadge = store.isDailyRewardClaimable ? "+\(store.nextDailyReward)" : nil
        missionsSubtitle = completedMissions > 0 ? "\(completedMissions) ready to claim" : "View objectives"
        missionBadge = completedMissions > 0 ? "\(completedMissions)" : nil
        campaignStatus = "\(completedLevels)/\(GameContent.levels.count) cleared"
        endlessStatus = endlessRecord.bestWave > 0
            ? "Best wave \(GameNumberFormatter.exact(endlessRecord.bestWave))"
            : "New run ready"
    }
}
