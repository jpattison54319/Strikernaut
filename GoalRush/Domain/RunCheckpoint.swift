import Foundation

nonisolated struct RunCheckpoint: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let runID: UUID
    let mode: RunMode
    let activeRelic: EndlessRelic?
    let savedAt: Date
    let revision: Int
    let simulation: RunSimulationCheckpoint
    let intermission: RunCheckpointIntermission
    let sessionRandom: SeededGenerator
    let draftsChosen: Int
    let deathSaveWasUsed: Bool
    let creditedRunTokens: Int

    var wave: Int { simulation.snapshot.wave }

    func updatingRunMetadata(
        creditedRunTokens: Int,
        deathSaveWasUsed: Bool,
        savedAt: Date = .now
    ) -> RunCheckpoint {
        RunCheckpoint(
            schemaVersion: schemaVersion,
            runID: runID,
            mode: mode,
            activeRelic: activeRelic,
            savedAt: savedAt,
            revision: revision + 1,
            simulation: simulation,
            intermission: intermission,
            sessionRandom: sessionRandom,
            draftsChosen: draftsChosen,
            deathSaveWasUsed: deathSaveWasUsed,
            creditedRunTokens: max(self.creditedRunTokens, creditedRunTokens)
        )
    }
}

nonisolated enum RunCheckpointIntermission: Codable, Equatable, Sendable {
    case draft([RunUpgradeChoice])
    case worldTransition(from: WorldID, to: WorldID, draft: [RunUpgradeChoice])
}

nonisolated struct RunSimulationCheckpoint: Codable, Equatable, Sendable {
    let mode: RunMode
    let stats: PlayerStats
    let characterID: CharacterID
    let assistMode: Bool
    let random: SeededGenerator
    let targetPlayerX: Double
    let kickClock: Double
    let nextIdentifier: Int
    let abilities: [AbilityKind: Int]
    let specialBallRanks: [TemporaryBallAbility: Int]
    let deathSaveDamageGraceRemaining: Double
    let nextPowerUpDefeat: Int
    let kickCount: Int
    let comboCount: Int
    let worldEffectElapsed: Double
    let nextLunarEffectTime: Double
    let pendingLunarDebrisStrikes: Int
    let lunarDebrisClock: Double
    let marsDefeatCount: Int
    let characterAnchorRemaining: Double
    let snapshot: RunWaveSnapshot
}

nonisolated struct RunWaveSnapshot: Codable, Equatable, Sendable {
    let world: WorldID
    let playerX: Double
    let stamina: Double
    let maxStamina: Double
    let elapsed: Double
    let tokens: Int
    let galeOrbitCount: Int
    let shieldCharges: Int
    let wave: Int
    let waveEnemyQuota: Int
    let isBossWave: Bool
    let score: Int
    let isEndless: Bool
    let combo: Int
    let comboFraction: Double
    let bestCombo: Int
    let targetsDefeated: Int
    let characterAbilityDefeats: Int
    let bossesDefeated: Int
    let waveCount: Int
    let activeTemporaryAbility: TemporaryBallAbility?
    let temporaryAbilityRemaining: Double
    let temporaryAbilityDuration: Double
    let characterAbilityCharge: Double
    let characterAbilityReady: Bool

    @MainActor
    init(snapshot: SimulationSnapshot) {
        world = snapshot.world
        playerX = snapshot.playerX
        stamina = snapshot.stamina
        maxStamina = snapshot.maxStamina
        elapsed = snapshot.elapsed
        tokens = snapshot.tokens
        galeOrbitCount = snapshot.galeOrbitCount
        shieldCharges = snapshot.shieldCharges
        wave = snapshot.wave
        waveEnemyQuota = snapshot.waveEnemyQuota
        isBossWave = snapshot.isBossWave
        score = snapshot.score
        isEndless = snapshot.isEndless
        combo = snapshot.combo
        comboFraction = snapshot.comboFraction
        bestCombo = snapshot.bestCombo
        targetsDefeated = snapshot.targetsDefeated
        characterAbilityDefeats = snapshot.characterAbilityDefeats
        bossesDefeated = snapshot.bossesDefeated
        waveCount = snapshot.waveCount
        activeTemporaryAbility = snapshot.activeTemporaryAbility
        temporaryAbilityRemaining = snapshot.temporaryAbilityRemaining
        temporaryAbilityDuration = snapshot.temporaryAbilityDuration
        characterAbilityCharge = snapshot.characterAbilityCharge
        characterAbilityReady = snapshot.characterAbilityReady
    }

    @MainActor
    var simulationSnapshot: SimulationSnapshot {
        SimulationSnapshot(
            world: world,
            playerX: playerX,
            stamina: stamina,
            maxStamina: maxStamina,
            elapsed: elapsed,
            tokens: tokens,
            targets: [],
            projectiles: [],
            characterAttacks: [],
            galeBounces: [],
            galeInterceptors: [],
            haloRings: [],
            magneticTraps: [],
            tidalWaves: [],
            bossHazards: [],
            galeOrbitCount: galeOrbitCount,
            shieldCharges: shieldCharges,
            wave: wave,
            waveElapsed: 0,
            waveDefeats: 0,
            waveEnemyQuota: waveEnemyQuota,
            isBossWave: isBossWave,
            score: score,
            isEndless: isEndless,
            combo: combo,
            comboFraction: comboFraction,
            bestCombo: bestCombo,
            targetsDefeated: targetsDefeated,
            characterAbilityDefeats: characterAbilityDefeats,
            bossesDefeated: bossesDefeated,
            waveCount: waveCount,
            activeTemporaryAbility: activeTemporaryAbility,
            temporaryAbilityRemaining: temporaryAbilityRemaining,
            temporaryAbilityDuration: temporaryAbilityDuration,
            characterAbilityCharge: characterAbilityCharge,
            characterAbilityReady: characterAbilityReady
        )
    }
}
