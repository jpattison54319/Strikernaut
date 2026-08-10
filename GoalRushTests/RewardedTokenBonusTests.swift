import Foundation
import Testing
@testable import GoalRush

@MainActor
struct RewardedTokenBonusTests {
    @Test func rewardedBonusCreditsHalfTheRunTokensExactlyOnce() throws {
        let (store, persistence) = makeStore()
        let result = RunResult(
            mode: .campaign(level: 1),
            didWin: false,
            tokensEarned: 101,
            remainingStamina: 0
        )
        store.finish(result)
        let displayedResult = try currentResult(in: store)

        #expect(store.rewardedTokenBonus(for: displayedResult) == 50)
        #expect(store.canOfferRewardedTokenBonus(for: displayedResult))
        #expect(store.claimRewardedTokenBonus(for: displayedResult) == 50)
        #expect(store.claimRewardedTokenBonus(for: displayedResult) == 0)
        #expect(store.progress.trainingTokens == 151)
        #expect(store.progress.lifetimeStats.totalTokensEarned == 101)
        #expect(try persistence.load().trainingTokens == 151)
    }

    @Test func campaignRetryKeepsTheRewardConsumedUntilHomeOrUpgrades() throws {
        let (store, _) = makeStore()
        let firstResult = RunResult(
            mode: .campaign(level: 3),
            didWin: false,
            tokensEarned: 100,
            remainingStamina: 0
        )
        store.finish(firstResult)
        #expect(store.claimRewardedTokenBonus(for: try currentResult(in: store)) == 50)

        store.continueAfterResult(try currentResult(in: store))
        store.finish(RunResult(
            mode: .campaign(level: 3),
            didWin: false,
            tokensEarned: 80,
            remainingStamina: 0
        ))
        #expect(!store.canOfferRewardedTokenBonus(for: try currentResult(in: store)))

        store.route = .upgrades
        store.start(level: 3)
        store.finish(RunResult(
            mode: .campaign(level: 3),
            didWin: false,
            tokensEarned: 60,
            remainingStamina: 0
        ))
        #expect(store.canOfferRewardedTokenBonus(for: try currentResult(in: store)))

        #expect(store.claimRewardedTokenBonus(for: try currentResult(in: store)) == 30)
        store.route = .home
        store.start(level: 3)
        store.finish(RunResult(
            mode: .campaign(level: 3),
            didWin: false,
            tokensEarned: 40,
            remainingStamina: 0
        ))
        #expect(store.canOfferRewardedTokenBonus(for: try currentResult(in: store)))
    }

    @Test func campaignWinBeginsANewRewardSessionForTheNextLevel() throws {
        let (store, _) = makeStore()
        store.progress.highestUnlockedLevel = 2
        store.finish(RunResult(
            mode: .campaign(level: 1),
            didWin: true,
            tokensEarned: 100,
            remainingStamina: 50
        ))
        let firstResult = try currentResult(in: store)
        #expect(store.claimRewardedTokenBonus(for: firstResult) == 50)

        store.continueAfterResult(firstResult)
        #expect(store.route == .playing(.campaign(level: 2)))
        store.finish(RunResult(
            mode: .campaign(level: 2),
            didWin: false,
            tokensEarned: 80,
            remainingStamina: 0
        ))
        #expect(store.canOfferRewardedTokenBonus(for: try currentResult(in: store)))
    }

    @Test func endlessRetriesShareOneRewardUntilTheSessionResets() throws {
        let (store, _) = makeStore()
        store.finish(RunResult(
            mode: .endless,
            didWin: false,
            tokensEarned: 200,
            remainingStamina: 0,
            wave: 8,
            score: 10_000
        ))
        let firstResult = try currentResult(in: store)
        #expect(store.claimRewardedTokenBonus(for: firstResult) == 100)

        store.continueAfterResult(firstResult)
        store.finish(RunResult(
            mode: .endless,
            didWin: false,
            tokensEarned: 160,
            remainingStamina: 0,
            wave: 6,
            score: 8_000
        ))
        #expect(!store.canOfferRewardedTokenBonus(for: try currentResult(in: store)))

        store.resetRewardedTokenBonusEligibility()
        #expect(store.canOfferRewardedTokenBonus(for: try currentResult(in: store)))
    }

    private func makeStore() -> (GameStore, FileProgressStore) {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let persistence = FileProgressStore(fileURL: directory.appending(path: "save.json"))
        let store = GameStore(
            progress: .newPlayer,
            settings: .init(),
            persistence: persistence
        )
        return (store, persistence)
    }

    private func currentResult(in store: GameStore) throws -> RunResult {
        if case .relicDrop(let result) = store.route {
            store.continueAfterRelicDrop(result)
        }
        guard case .result(let result) = store.route else {
            Issue.record("Expected a result route")
            throw MissingResultError()
        }
        return result
    }
}
