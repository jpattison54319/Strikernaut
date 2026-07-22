import Foundation

enum EndlessRules {
    static let waveDuration = 24.0

    static func healthMultiplier(wave: Int) -> Double {
        let index = Double(max(0, wave - 1))
        return pow(1.065, index) * (1 + 0.035 * index)
    }

    static func damageMultiplier(wave: Int) -> Double {
        pow(1.035, Double(max(0, wave - 1)))
    }

    static func speedMultiplier(wave: Int) -> Double {
        1 + log2(Double(max(1, wave)) + 1) * 0.08
    }

    static func spawnInterval(wave: Int) -> Double {
        max(0.32, 1.35 * pow(0.975, Double(max(0, wave - 1))))
    }

    static func packSize(wave: Int) -> Int {
        min(4, 1 + max(0, wave - 1) / 15)
    }

    static func waveClearScore(wave: Int) -> Int {
        500 * max(1, wave)
    }
}
