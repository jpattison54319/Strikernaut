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
        let gear = GearCatalog.modifiers(for: progress.loadout)
        maxStamina = 100 * (1 + 0.08 * Double(progress.rank(for: .conditioning))) + gear.staminaBonus
        movementResponse = 8 * (1 + 0.07 * Double(progress.rank(for: .footwork))) * gear.movementMultiplier
        kickCooldown = 1.12 * pow(0.88, Double(progress.rank(for: .tempo))) * gear.kickCooldownMultiplier
        ballDamage = 10 * (1 + 0.10 * Double(progress.rank(for: .impact))) * gear.damageMultiplier
        ballSpeed = 0.88 * (1 + 0.06 * Double(progress.rank(for: .flight))) * gear.ballSpeedMultiplier
        criticalChance = min(0.85, 0.05 + 0.03 * Double(progress.rank(for: .spin)) + gear.criticalChanceBonus)
        homingStrength = gear.homingStrength
        startingShields = gear.startingShields
        extraPierce = gear.extraPierce
        tokenMultiplier = gear.tokenMultiplier
    }
}

struct TargetState: Identifiable, Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case enemy(EnemyKind)
        case fieldObject(FieldObjectKind)
    }

    let id: Int
    var kind: Kind
    var position: Vector2
    var hitPoints: Double
    var maximumHitPoints: Double
    var phase: Double
}

struct ProjectileState: Identifiable, Equatable, Sendable {
    let id: Int
    var position: Vector2
    var velocity: Vector2
    var damage: Double
    var remainingPierces: Int
    var hostile: Bool
    var isCritical: Bool
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
        bossActive = snapshot.targets.contains { target in
            guard case .enemy(let enemy) = target.kind else { return false }
            return enemy == .titanKeeper || enemy == .marsColossus
        }
    }
}

enum SimulationEvent: Equatable, Sendable {
    case checkpoint(Int)
    case damage
    case kick
    case impact(Vector2, Bool)
    case reward(Int, Vector2)
    case heal(Double, Vector2)
    case abilityChosen(AbilityKind)
    case bossPhase(Int)
    case waveCompleted(Int)
    case meteorKick
    case comboChanged(Int)
    case comboMilestone(Int)
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
