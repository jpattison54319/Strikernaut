import Foundation

enum StarRating {
    static func stars(staminaFraction: Double) -> Int {
        if staminaFraction >= 0.70 { return 3 }
        if staminaFraction >= 0.35 { return 2 }
        return 1
    }
}
