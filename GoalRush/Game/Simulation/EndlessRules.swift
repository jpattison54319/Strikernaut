import Foundation

enum EndlessRules {
    static let wavesPerWorld = 10

    static var worldSequence: [WorldID] {
        let authoredWorlds = GameContent.worlds.map(\.id)
        return authoredWorlds.isEmpty ? [.earth] : authoredWorlds
    }

    static func world(for wave: Int) -> WorldID {
        let sequence = worldSequence
        return sequence[chapterIndex(for: wave) % sequence.count]
    }

    static func chapterIndex(for wave: Int) -> Int {
        max(0, wave - 1) / wavesPerWorld
    }

    static func waveInWorld(for wave: Int) -> Int {
        max(0, wave - 1) % wavesPerWorld + 1
    }

    static func worldTransition(after completedWave: Int) -> (from: WorldID, to: WorldID)? {
        let safeWave = max(1, completedWave)
        guard safeWave.isMultiple(of: wavesPerWorld) else { return nil }
        let from = world(for: safeWave)
        let to = world(for: safeWave + 1)
        guard from != to else { return nil }
        return (from, to)
    }

    static func isBossWave(_ wave: Int) -> Bool {
        max(1, wave).isMultiple(of: 5)
    }

    static func enemyQuota(wave: Int) -> Int {
        let safeWave = max(1, wave)
        return 18 + safeWave - 1 + 2 * chapterIndex(for: safeWave)
    }

    static func maximumActiveEnemies(wave: Int) -> Int {
        min(10, 5 + chapterIndex(for: wave))
    }

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
