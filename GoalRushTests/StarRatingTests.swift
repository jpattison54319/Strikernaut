import Foundation
import Testing
@testable import GoalRush

@MainActor
struct StarRatingTests {
    @Test func thresholdsArePinnedExactly() {
        #expect(StarRating.stars(staminaFraction: 0.70) == 3)
        #expect(StarRating.stars(staminaFraction: 1.0) == 3)
        #expect(StarRating.stars(staminaFraction: 0.69) == 2)
        #expect(StarRating.stars(staminaFraction: 0.35) == 2)
        #expect(StarRating.stars(staminaFraction: 0.34) == 1)
        #expect(StarRating.stars(staminaFraction: 0.0) == 1)
    }
}
