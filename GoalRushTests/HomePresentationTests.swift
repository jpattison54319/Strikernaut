import Testing
@testable import GoalRush

@MainActor
struct HomePresentationTests {
    @Test func newPlayerTargetsLevelOne() {
        #expect(HomePresentation.primaryAction(progress: .newPlayer) == .campaign(level: 1))
    }

    @Test func firstUnlockedIncompleteLevelWins() {
        var progress = PlayerProgress.newPlayer
        progress.highestUnlockedLevel = 4
        progress.levelRecords[1] = .init(completed: true, bestTokens: 1, bestStamina: 1)
        progress.levelRecords[2] = .init(completed: true, bestTokens: 1, bestStamina: 1)

        #expect(HomePresentation.primaryAction(progress: progress) == .campaign(level: 3))
    }

    @Test func completedCampaignTargetsEndless() {
        var progress = PlayerProgress.newPlayer
        progress.highestUnlockedLevel = GameContent.levels.count
        for level in GameContent.levels {
            progress.levelRecords[level.number] = .init(completed: true, bestTokens: 1, bestStamina: 1)
        }

        #expect(HomePresentation.primaryAction(progress: progress) == .endless)
    }

    @Test func missionCountIncludesOnlyCompletedUnclaimedMissions() {
        let missions = [
            MissionState(kind: .defeatTargets, goal: 10, progress: 10, claimed: false, reward: 80),
            MissionState(kind: .earnTokens, goal: 100, progress: 50, claimed: false, reward: 80),
            MissionState(kind: .reachWave, goal: 4, progress: 4, claimed: true, reward: 100),
        ]

        #expect(HomePresentation.completedMissionCount(missions) == 1)
    }

    @Test func missionClaimControlMeetsMinimumTapTarget() {
        #expect(MissionRow.minimumClaimHeight >= GoalRushTheme.Metrics.minimumTapTarget)
    }

    @Test func dailyCelebrationRequiresAClaimAndAllowsReducedFlashesToSuppressIt() {
        #expect(!HomePresentation.showsDailyCelebration(claimedReward: nil, reducedFlashes: false))
        #expect(HomePresentation.showsDailyCelebration(claimedReward: 40, reducedFlashes: false))
        #expect(!HomePresentation.showsDailyCelebration(claimedReward: 40, reducedFlashes: true))
    }
}
