import Foundation

struct Vector2: Equatable, Sendable {
    var x: Double
    var y: Double
}

struct PlayerStats: Equatable, Sendable {
    let maxStamina: Double
    let movementResponse: Double
    let kickCooldown: Double
    let ballDamage: Double
    let ballSpeed: Double
    let criticalChance: Double
    let homingStrength: Double
    let startingShields: Int
    let extraPierce: Int
    let tokenMultiplier: Double

    init(progress: PlayerProgress) {
        maxStamina = 100 * (1 + 0.08 * Double(progress.rank(for: .conditioning)))
        movementResponse = 8 * (1 + 0.07 * Double(progress.rank(for: .footwork)))
        kickCooldown = UpgradeRules.kickCooldown(for: progress.rank(for: .tempo))
        ballDamage = 10 * (1 + 0.10 * Double(progress.rank(for: .impact)))
        ballSpeed = 0.88 * (1 + 0.06 * Double(progress.rank(for: .flight)))
        criticalChance = 0.05 + 0.03 * Double(progress.rank(for: .spin))
        homingStrength = 0
        startingShields = 0
        extraPierce = 0
        tokenMultiplier = 1
    }
}

struct TargetState: Identifiable, Equatable, Sendable {
    enum Kind: Hashable, Sendable {
        case enemy(EnemyKind)
        case fieldObject(FieldObjectKind)
        case powerUp(TemporaryBallAbility)
    }

    let id: Int
    var kind: Kind
    var position: Vector2
    var hitPoints: Double
    var maximumHitPoints: Double
    var phase: Double
    var bossTier: CampaignBossTier = .standard
    var burnRemaining: Double = 0
    var burnTickClock: Double = 0
    var freezeRemaining: Double = 0
    var reverseRemaining: Double = 0
    var stunRemaining: Double = 0
}

enum CharacterProjectileKind: Equatable, Sendable {
    case pinballBlitz
}

enum CharacterAttackKind: Equatable, Sendable {
    case meteor
    case shockwave
}

struct CharacterAttackState: Identifiable, Equatable, Sendable {
    let id: Int
    let kind: CharacterAttackKind
    var position: Vector2
    let startPosition: Vector2
    var destination: Vector2
    let targetID: Int?
    let damage: Double
    var delayRemaining: Double
    var elapsed: Double
    let duration: Double
    var width: Double
    var contactedTargetIDs: Set<Int> = []

    var progress: Double {
        guard duration > 0 else { return 1 }
        return min(1, max(0, elapsed / duration))
    }
}

struct ProjectileState: Identifiable, Equatable, Sendable {
    let id: Int
    var position: Vector2
    var velocity: Vector2
    var damage: Double
    var remainingPierces: Int
    var hostile: Bool
    var isCritical: Bool
    var temporaryAbility: TemporaryBallAbility?
    var canSplit: Bool
    var characterProjectile: CharacterProjectileKind? = nil
    var remainingLifetime: Double = .infinity
    var contactedTargetIDs: Set<Int> = []
}

struct SimulationSnapshot: Equatable, Sendable {
    var playerX: Double
    var stamina: Double
    var maxStamina: Double
    var elapsed: Double
    var duration: Double
    var tokens: Int
    var targets: [TargetState]
    var projectiles: [ProjectileState]
    var characterAttacks: [CharacterAttackState]
    var shieldCharges: Int
    var wave: Int
    var waveElapsed: Double
    var waveDuration: Double
    var score: Int
    var isEndless: Bool
    var combo: Int
    var comboFraction: Double
    var bestCombo: Int
    var targetsDefeated: Int
    var bossesDefeated: Int
    var waveCount: Int
    var activeTemporaryAbility: TemporaryBallAbility?
    var temporaryAbilityRemaining: Double
    var temporaryAbilityDuration: Double
    var characterAbilityCharge: Double
    var characterAbilityReady: Bool
}

struct HUDState: Equatable, Sendable {
    var stamina: Double
    var maxStamina: Double
    var elapsed: Double
    var duration: Double
    var tokens: Int
    var shieldCharges: Int
    var bossActive: Bool
    var wave: Int
    var waveElapsed: Double
    var waveDuration: Double
    var score: Int
    var isEndless: Bool
    var combo: Int
    var comboFraction: Double
    var waveCount: Int
    var activeTemporaryAbility: TemporaryBallAbility?
    var temporaryAbilityRemaining: Double
    var temporaryAbilityDuration: Double
    var characterAbilityCharge: Double
    var characterAbilityReady: Bool

    init(snapshot: SimulationSnapshot) {
        stamina = snapshot.stamina
        maxStamina = snapshot.maxStamina
        elapsed = snapshot.elapsed
        duration = snapshot.duration
        tokens = snapshot.tokens
        shieldCharges = snapshot.shieldCharges
        wave = snapshot.wave
        waveElapsed = snapshot.waveElapsed
        waveDuration = snapshot.waveDuration
        score = snapshot.score
        isEndless = snapshot.isEndless
        combo = snapshot.combo
        comboFraction = snapshot.comboFraction
        waveCount = snapshot.waveCount
        activeTemporaryAbility = snapshot.activeTemporaryAbility
        temporaryAbilityRemaining = snapshot.temporaryAbilityRemaining
        temporaryAbilityDuration = snapshot.temporaryAbilityDuration
        characterAbilityCharge = snapshot.characterAbilityCharge
        characterAbilityReady = snapshot.characterAbilityReady
        bossActive = snapshot.targets.contains { target in
            target.bossTier != .standard
        }
    }
}

enum SimulationEvent: Equatable, Sendable {
    case checkpoint(Int)
    case damage
    case kick
    case impact(Vector2, Double, DamageFlavor, Bool)
    case elementalReaction(Vector2)
    case reward(Int, Vector2)
    case heal(Double, Vector2)
    case abilityChosen(AbilityKind)
    case bossPhase(Int)
    case waveCompleted(Int)
    case meteorKick
    case comboChanged(Int)
    case comboMilestone(Int)
    case temporaryAbilityActivated(TemporaryBallAbility, TimeInterval, Vector2)
    case characterAbilityActivated(CharacterAbility)
    case characterAbilityTargets(CharacterAbility, [Vector2])
    case characterProjectileRicochet(Vector2)
    case characterMeteorImpact(Vector2)
    case characterShockwaveBurst(Vector2)
    case characterShockwaveHit(Vector2)
    case finished(Bool)
}

struct SeededGenerator: RandomNumberGenerator, Sendable {
    private var state: UInt64

    init(seed: UInt64) { state = seed == 0 ? 0x9E3779B97F4A7C15 : seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    mutating func unit() -> Double { Double(next() >> 11) / Double(1 << 53) }
}
