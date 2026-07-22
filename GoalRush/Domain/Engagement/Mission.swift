import Foundation

enum MissionKind: String, Codable, CaseIterable, Sendable {
    case defeatTargets, earnTokens, reachWave, clearLevels, draftAbilities
    case winWithStamina, achieveCombo, defeatBosses, playEndlessRuns, earnScore
}

struct MissionState: Codable, Equatable, Sendable, Identifiable {
    var kind: MissionKind
    var goal: Int
    var progress: Int
    var claimed: Bool
    var reward: Int
    var id: String { kind.rawValue }
    var isComplete: Bool { progress >= goal }
    var fraction: Double { min(1, Double(progress) / Double(max(1, goal))) }
}

enum MissionCatalog {
    /// Deterministic 3-mission set per local day; identical on every device.
    static func dailyMissions(dayStamp: String, highestUnlockedLevel: Int) -> [MissionState] {
        let digits = dayStamp.filter(\.isNumber)
        var random = SeededGenerator(seed: (UInt64(digits) ?? 1) &* 9_973 &+ 11)
        let power = min(1.0, Double(max(1, highestUnlockedLevel)) / 20.0)
        var pool = MissionKind.allCases
        var missions: [MissionState] = []
        while missions.count < 3, !pool.isEmpty {
            let index = Int(random.next() % UInt64(pool.count))
            let kind = pool.remove(at: index)
            missions.append(MissionState(kind: kind, goal: goal(for: kind, power: power),
                                         progress: 0, claimed: false, reward: reward(for: kind)))
        }
        return missions
    }

    static func goal(for kind: MissionKind, power: Double) -> Int {
        let scaled = { (base: Double, extra: Double) in max(1, Int((base + extra * power).rounded())) }
        switch kind {
        case .defeatTargets: return scaled(25, 35)
        case .earnTokens: return scaled(150, 250)
        case .reachWave: return scaled(4, 4)
        case .clearLevels: return scaled(1, 1)
        case .draftAbilities: return scaled(3, 3)
        case .winWithStamina: return 1
        case .achieveCombo: return scaled(6, 8)
        case .defeatBosses: return 1
        case .playEndlessRuns: return 2
        case .earnScore: return scaled(20_000, 60_000)
        }
    }

    static func reward(for kind: MissionKind) -> Int {
        switch kind {
        case .defeatTargets, .earnTokens: 80
        case .reachWave, .clearLevels: 100
        case .draftAbilities: 60
        case .winWithStamina, .achieveCombo, .earnScore: 90
        case .defeatBosses: 120
        case .playEndlessRuns: 70
        }
    }

    static func apply(result: RunResult, to missions: inout [MissionState]) {
        for index in missions.indices where !missions[index].isComplete {
            switch missions[index].kind {
            case .defeatTargets: missions[index].progress += result.targetsDefeated
            case .earnTokens: missions[index].progress += result.tokensEarned
            case .reachWave: if result.mode.isEndless { missions[index].progress = max(missions[index].progress, result.wave) }
            case .clearLevels: if result.didWin, !result.mode.isEndless { missions[index].progress += 1 }
            case .draftAbilities: missions[index].progress += result.abilitiesDrafted
            case .winWithStamina: if result.didWin && result.staminaFraction >= 0.5 { missions[index].progress += 1 }
            case .achieveCombo: missions[index].progress = max(missions[index].progress, result.bestCombo)
            case .defeatBosses: missions[index].progress += result.bossesDefeated
            case .playEndlessRuns: if result.mode.isEndless { missions[index].progress += 1 }
            case .earnScore: missions[index].progress = max(missions[index].progress, result.score)
            }
        }
    }

    static func title(for kind: MissionKind) -> String {
        switch kind {
        case .defeatTargets: "Target Practice"
        case .earnTokens: "Token Run"
        case .reachWave: "Wave Rider"
        case .clearLevels: "Campaign Push"
        case .draftAbilities: "Power Hungry"
        case .winWithStamina: "Untouchable"
        case .achieveCombo: "Combo King"
        case .defeatBosses: "Giant Slayer"
        case .playEndlessRuns: "Marathon"
        case .earnScore: "High Scorer"
        }
    }

    static func icon(for kind: MissionKind) -> String {
        switch kind {
        case .defeatTargets: "target"
        case .earnTokens: "hexagon.fill"
        case .reachWave: "flag.checkered"
        case .clearLevels: "map.fill"
        case .draftAbilities: "sparkles"
        case .winWithStamina: "heart.fill"
        case .achieveCombo: "bolt.fill"
        case .defeatBosses: "crown.fill"
        case .playEndlessRuns: "infinity"
        case .earnScore: "trophy.fill"
        }
    }

    static func goalText(for kind: MissionKind, goal: Int) -> String {
        switch kind {
        case .defeatTargets: "Defeat \(goal) targets"
        case .earnTokens: "Earn \(goal) tokens"
        case .reachWave: "Reach wave \(goal)"
        case .clearLevels: "Clear \(goal) level\(goal == 1 ? "" : "s")"
        case .draftAbilities: "Draft \(goal) powers"
        case .winWithStamina: "Win with 50%+ stamina"
        case .achieveCombo: "Reach a ×\(goal) combo"
        case .defeatBosses: "Defeat a boss"
        case .playEndlessRuns: "Play \(goal) Endless runs"
        case .earnScore: "Score \(goal.formatted()) in a run"
        }
    }
}
