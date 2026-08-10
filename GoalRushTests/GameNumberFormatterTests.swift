import Testing
@testable import GoalRush

@MainActor
struct GameNumberFormatterTests {
    @Test func keepsSmallValuesExact() {
        #expect(GameNumberFormatter.compact(0) == "0")
        #expect(GameNumberFormatter.compact(999) == "999")
        #expect(GameNumberFormatter.compact(-42) == "-42")
    }

    @Test func abbreviatesLargeValuesAcrossDisplayTiers() {
        #expect(GameNumberFormatter.compact(1_000) == "1K")
        #expect(GameNumberFormatter.compact(1_250) == "1.3K")
        #expect(GameNumberFormatter.compact(12_340) == "12.3K")
        #expect(GameNumberFormatter.compact(123_400) == "123K")
        #expect(GameNumberFormatter.compact(1_000_000) == "1M")
        #expect(GameNumberFormatter.compact(1_000_000_000) == "1B")
        #expect(GameNumberFormatter.compact(1_000_000_000_000) == "1T")
        #expect(GameNumberFormatter.compact(1_000_000_000_000_000) == "1Qa")
        #expect(GameNumberFormatter.compact(1_000_000_000_000_000_000) == "1Qi")
        #expect(GameNumberFormatter.compact(Int.max) == "9.2Qi")
        #expect(GameNumberFormatter.compact(Int.min) == "-9.2Qi")
    }

    @Test func promotesRoundedValuesToTheNextTier() {
        #expect(GameNumberFormatter.compact(999_500) == "1M")
        #expect(GameNumberFormatter.compact(999_500_000) == "1B")
        #expect(GameNumberFormatter.compact(-1_250_000) == "-1.3M")
    }

    @Test func highUpgradeRanksStayCompactWithoutHidingTheNextStep() {
        #expect(
            RunUpgradePresentation.rankLabel(forCurrentRank: 12_500)
                == "RANK 12.5K → NEXT"
        )
    }
}
