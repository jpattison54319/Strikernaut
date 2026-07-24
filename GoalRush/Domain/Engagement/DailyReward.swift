import Foundation

struct DailyRewardState: Codable, Equatable, Sendable {
    var lastClaimDay = ""
    var streak = 0
}

enum DailyRewardEngine {
    static let rewards = [40, 40, 80, 80, 140, 140, 250]

    static func collectionDay(forClaimCount claimCount: Int) -> Int {
        ((max(claimCount, 1) - 1) % rewards.count) + 1
    }

    static func reward(forStreakDay day: Int) -> Int {
        rewards[collectionDay(forClaimCount: day) - 1]
    }

    static func isClaimable(state: DailyRewardState, today: String) -> Bool {
        state.lastClaimDay != today
    }

    /// Returns the tokens awarded, or 0 when already claimed today.
    static func claim(state: inout DailyRewardState, today: String, yesterday: String) -> Int {
        guard state.lastClaimDay != today else { return 0 }
        state.streak = state.lastClaimDay == yesterday ? state.streak + 1 : 1
        state.lastClaimDay = today
        return reward(forStreakDay: state.streak)
    }

    static func dayString(for date: Date, calendar: Calendar = .current) -> String {
        let day = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", day.year ?? 0, day.month ?? 0, day.day ?? 0)
    }
}
