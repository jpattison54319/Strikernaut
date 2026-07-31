import Foundation

struct RunResult: Equatable, Sendable {
    let runID: UUID
    let mode: RunMode
    let didWin: Bool
    let tokensEarned: Int
    let remainingStamina: Double
    let wave: Int
    let score: Int
    var characterEarned: CharacterID?
    var targetsDefeated: Int
    var bossesDefeated: Int
    var bestCombo: Int
    var abilitiesDrafted: Int
    var character: CharacterID?
    var characterAbilityDefeats: Int
    var staminaFraction: Double
    var isFirstClear: Bool
    var newBestWave: Bool
    var newBestScore: Bool
    var relicEarned: EndlessRelic?

    var world: WorldID {
        if mode.isEndless {
            return EndlessRules.world(for: max(1, wave))
        }
        return mode.world
    }

    init(
        runID: UUID = UUID(),
        mode: RunMode,
        didWin: Bool,
        tokensEarned: Int,
        remainingStamina: Double,
        wave: Int = 0,
        score: Int = 0,
        characterEarned: CharacterID? = nil,
        targetsDefeated: Int = 0,
        bossesDefeated: Int = 0,
        bestCombo: Int = 0,
        abilitiesDrafted: Int = 0,
        character: CharacterID? = nil,
        characterAbilityDefeats: Int = 0,
        staminaFraction: Double = 0,
        isFirstClear: Bool = false,
        newBestWave: Bool = false,
        newBestScore: Bool = false,
        relicEarned: EndlessRelic? = nil
    ) {
        self.runID = runID
        self.mode = mode
        self.didWin = didWin
        self.tokensEarned = tokensEarned
        self.remainingStamina = remainingStamina
        self.wave = wave
        self.score = score
        self.characterEarned = characterEarned
        self.targetsDefeated = targetsDefeated
        self.bossesDefeated = bossesDefeated
        self.bestCombo = bestCombo
        self.abilitiesDrafted = abilitiesDrafted
        self.character = character
        self.characterAbilityDefeats = characterAbilityDefeats
        self.staminaFraction = staminaFraction
        self.isFirstClear = isFirstClear
        self.newBestWave = newBestWave
        self.newBestScore = newBestScore
        self.relicEarned = relicEarned
    }

    init(level: Int, didWin: Bool, tokensEarned: Int, remainingStamina: Double) {
        self.init(mode: .campaign(level: level), didWin: didWin, tokensEarned: tokensEarned, remainingStamina: remainingStamina)
    }
}
