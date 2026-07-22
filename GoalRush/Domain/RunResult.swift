import Foundation

struct RunResult: Equatable, Sendable {
    let mode: RunMode
    let didWin: Bool
    let tokensEarned: Int
    let remainingStamina: Double
    let wave: Int
    let score: Int
    var gearEarned: [GearID]

    init(
        mode: RunMode,
        didWin: Bool,
        tokensEarned: Int,
        remainingStamina: Double,
        wave: Int = 0,
        score: Int = 0,
        gearEarned: [GearID] = []
    ) {
        self.mode = mode
        self.didWin = didWin
        self.tokensEarned = tokensEarned
        self.remainingStamina = remainingStamina
        self.wave = wave
        self.score = score
        self.gearEarned = gearEarned
    }

    init(level: Int, didWin: Bool, tokensEarned: Int, remainingStamina: Double) {
        self.init(mode: .campaign(level: level), didWin: didWin, tokensEarned: tokensEarned, remainingStamina: remainingStamina)
    }
}
