import Testing
@testable import GoalRush

@MainActor
struct EngagementTests {
    @Test func dailyRewardClaimAdvancesStreakAndPaysTableValue() {
        var state = DailyRewardState()
        let day1 = DailyRewardEngine.claim(state: &state, today: "2026-07-20", yesterday: "2026-07-19")
        #expect(day1 == 40)
        #expect(state.streak == 1)
        let day2 = DailyRewardEngine.claim(state: &state, today: "2026-07-21", yesterday: "2026-07-20")
        #expect(day2 == 60)
        #expect(state.streak == 2)
    }

    @Test func dailyRewardSameDayIsNoOpAndMissedDayResetsStreak() {
        var state = DailyRewardState(lastClaimDay: "2026-07-20", streak: 4)
        #expect(DailyRewardEngine.claim(state: &state, today: "2026-07-20", yesterday: "2026-07-19") == 0)
        #expect(state.streak == 4)
        #expect(!DailyRewardEngine.isClaimable(state: state, today: "2026-07-20"))
        let reward = DailyRewardEngine.claim(state: &state, today: "2026-07-25", yesterday: "2026-07-24")
        #expect(reward == 40)
        #expect(state.streak == 1)
    }

    @Test func dailyRewardCapsAtDaySevenValue() {
        #expect(DailyRewardEngine.reward(forStreakDay: 7) == 250)
        #expect(DailyRewardEngine.reward(forStreakDay: 30) == 250)
    }

    @Test func dailyMissionsAreDeterministicPerDayAndDistinct() {
        let first = MissionCatalog.dailyMissions(dayStamp: "2026-07-22", highestUnlockedLevel: 10)
        let second = MissionCatalog.dailyMissions(dayStamp: "2026-07-22", highestUnlockedLevel: 10)
        #expect(first == second)
        #expect(first.count == 3)
        #expect(Set(first.map(\.kind)).count == 3)
        let otherDay = MissionCatalog.dailyMissions(dayStamp: "2026-07-23", highestUnlockedLevel: 10)
        #expect(otherDay != first)
    }

    @Test func missionGoalsScaleWithCampaignProgress() {
        let early = MissionCatalog.dailyMissions(dayStamp: "2026-07-22", highestUnlockedLevel: 1)
        let late = MissionCatalog.dailyMissions(dayStamp: "2026-07-22", highestUnlockedLevel: 20)
        for kind in MissionKind.allCases {
            #expect(MissionCatalog.goal(for: kind, power: 0) <= MissionCatalog.goal(for: kind, power: 1))
        }
        #expect(early.allSatisfy { $0.goal > 0 && $0.reward > 0 })
        #expect(late.allSatisfy { $0.goal > 0 })
    }

    @Test func missionProgressFoldsRunResults() {
        var missions = [MissionState(kind: .defeatTargets, goal: 30, progress: 0, claimed: false, reward: 80),
                        MissionState(kind: .achieveCombo, goal: 10, progress: 0, claimed: false, reward: 90)]
        let result = RunResult(mode: .endless(world: .earth), didWin: false, tokensEarned: 50,
                               remainingStamina: 0, wave: 6, score: 5_000,
                               targetsDefeated: 22, bestCombo: 12)
        MissionCatalog.apply(result: result, to: &missions)
        #expect(missions[0].progress == 22)
        #expect(missions[1].progress == 12)
        #expect(missions[1].isComplete)
    }

    @Test func achievementEvaluationDerivesFromProgress() {
        var progress = PlayerProgress.newPlayer
        #expect(AchievementCatalog.evaluate(progress: progress).isEmpty)
        progress.levelRecords[1] = .init(completed: true, bestTokens: 50, bestStamina: 40)
        progress.lifetimeStats.totalTokensEarned = 1_200
        progress.lifetimeStats.bestCombo = 11
        progress.dailyReward.streak = 3
        let unlocked = AchievementCatalog.evaluate(progress: progress)
        #expect(unlocked.contains(.firstClear))
        #expect(unlocked.contains(.tokens1k))
        #expect(unlocked.contains(.combo10))
        #expect(unlocked.contains(.streak3))
        #expect(!unlocked.contains(.combo25))
    }
}
