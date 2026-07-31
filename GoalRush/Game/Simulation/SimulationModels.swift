import Foundation

struct Vector2: Equatable, Sendable {
    var x: Double
    var y: Double
}

nonisolated struct PlayerStats: Codable, Equatable, Sendable {
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
    let characterAbilityChargeMultiplier: Double

    @MainActor
    init(progress: PlayerProgress, mode: RunMode? = nil) {
        let relic = mode?.isEndless == true
            ? progress.endlessRecord.equippedRelic
            : nil
        maxStamina = 100
            * (1 + 0.08 * Double(progress.rank(for: .conditioning)))
            * (1 + (relic?.value(for: .maximumStamina) ?? 0))
        movementResponse = 8
            * (1 + 0.07 * Double(progress.rank(for: .footwork)))
            * (1 + (relic?.value(for: .movementResponse) ?? 0))
        kickCooldown = UpgradeRules.kickCooldown(for: progress.rank(for: .tempo))
            / (1 + (relic?.value(for: .kickRate) ?? 0))
        ballDamage = 10
            * (1 + 0.10 * Double(progress.rank(for: .impact)))
            * (1 + (relic?.value(for: .attackDamage) ?? 0))
        ballSpeed = 0.88
            * (1 + 0.06 * Double(progress.rank(for: .flight)))
            * (1 + (relic?.value(for: .ballSpeed) ?? 0))
        criticalChance = 0.05
            + 0.03 * Double(progress.rank(for: .spin))
            + (relic?.value(for: .criticalChance) ?? 0)
        homingStrength = 0
        startingShields = 0
        extraPierce = 0
        tokenMultiplier = 1 + (relic?.value(for: .trainingTokenGain) ?? 0)
        characterAbilityChargeMultiplier =
            1 + (relic?.value(for: .heroChargeRate) ?? 0)
    }

    private enum CodingKeys: String, CodingKey {
        case maxStamina
        case movementResponse
        case kickCooldown
        case ballDamage
        case ballSpeed
        case criticalChance
        case homingStrength
        case startingShields
        case extraPierce
        case tokenMultiplier
        case characterAbilityChargeMultiplier
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        maxStamina = try container.decode(Double.self, forKey: .maxStamina)
        movementResponse = try container.decode(Double.self, forKey: .movementResponse)
        kickCooldown = try container.decode(Double.self, forKey: .kickCooldown)
        ballDamage = try container.decode(Double.self, forKey: .ballDamage)
        ballSpeed = try container.decode(Double.self, forKey: .ballSpeed)
        criticalChance = try container.decode(Double.self, forKey: .criticalChance)
        homingStrength = try container.decode(Double.self, forKey: .homingStrength)
        startingShields = try container.decode(Int.self, forKey: .startingShields)
        extraPierce = try container.decode(Int.self, forKey: .extraPierce)
        tokenMultiplier = try container.decode(Double.self, forKey: .tokenMultiplier)
        characterAbilityChargeMultiplier = try container.decodeIfPresent(
            Double.self,
            forKey: .characterAbilityChargeMultiplier
        ) ?? 1
    }
}

struct TargetState: Identifiable, Equatable, Sendable {
    enum Kind: Hashable, Sendable {
        case enemy(EnemyKind)
        case fieldObject(FieldObjectKind)
        case powerUp(TemporaryBallAbility)
        case volatileCore
    }

    let id: Int
    var kind: Kind
    var position: Vector2
    var hitPoints: Double
    var maximumHitPoints: Double
    var shieldHitPoints: Double = 0
    var maximumShieldHitPoints: Double = 0
    var phase: Double
    var bossMovementPhase: Double = 0
    var bossTier: CampaignBossTier = .standard
    var waveRole: WaveEnemyRole = .quota
    var burnRemaining: Double = 0
    var burnTickClock: Double = 0
    var burnTickDamage: Double = 0
    var freezeRemaining: Double = 0
    var reverseRemaining: Double = 0
    var stunRemaining: Double = 0
    var tidalSlowRemaining: Double = 0
    var undertowSlowRemaining: Double = 0
    var magnetRemaining: Double = 0
    var magnetTurnRate: Double = 0
    var gravityPullCenter: Vector2?
    var gravityPullRemaining: Double = 0
    var gravityPullStrength: Double = 0

    var isShielded: Bool {
        shieldHitPoints > 0
    }
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
    let awardsAbilityCharge: Bool
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
    var endlessEffects: Set<TemporaryBallAbility> = []
    var characterProjectile: CharacterProjectileKind? = nil
    var remainingLifetime: Double = .infinity
    var contactedTargetIDs: Set<Int> = []
    var orbitChainsRemaining: Int = 0
    var hasTriggeredVoltChain = false
    var ringReturnDamage: Double? = nil

    var ballEffects: Set<TemporaryBallAbility> {
        guard let temporaryAbility else { return endlessEffects }
        return endlessEffects.union([temporaryAbility])
    }

    func hasEffect(_ ability: TemporaryBallAbility) -> Bool {
        temporaryAbility == ability || endlessEffects.contains(ability)
    }
}

struct GaleBounceState: Identifiable, Equatable, Sendable {
    let id: Int
    let activationID: Int
    let lane: Int
    let startPosition: Vector2
    let destinationX: Double
    var position: Vector2
    var previousPosition: Vector2
    var elapsed: Double
    let duration: Double
    var completedLandings: Int

    var progress: Double {
        guard duration > 0 else { return 1 }
        return min(1, max(0, elapsed / duration))
    }

    var visualHeight: Double {
        abs(sin(progress * .pi * 4))
    }
}

struct GaleInterceptorState: Identifiable, Equatable, Sendable {
    let id: Int
    let targetID: Int
    let startPosition: Vector2
    var position: Vector2
    var elapsed: Double
    let duration: Double
    let damage: Double

    var progress: Double {
        guard duration > 0 else { return 1 }
        return min(1, max(0, elapsed / duration))
    }
}

struct HaloRingState: Identifiable, Equatable, Sendable {
    let id: Int
    let startX: Double
    var center: Vector2
    var previousCenter: Vector2
    var elapsed: Double
    let duration: Double
    let radius: Double
    let damage: Double
    var targetHitCounts: [Int: Int] = [:]
    var targetContactCooldowns: [Int: Double] = [:]

    var progress: Double {
        guard duration > 0 else { return 1 }
        return min(1, max(0, elapsed / duration))
    }
}

struct MagneticTrapState: Identifiable, Equatable, Sendable {
    let id: Int
    let startPosition: Vector2
    let landingPosition: Vector2
    var position: Vector2
    var targetID: Int?
    var delayRemaining: Double
    var flightElapsed: Double
    let flightDuration: Double
    var armedRemaining: Double
    var captureRemaining: Double
    var tickClock: Double
    var ticksRemaining: Int
    let tickDamage: Double
    var hasLanded: Bool
    var controlBlockedByShield: Bool = false

    var flightProgress: Double {
        guard flightDuration > 0 else { return 1 }
        return min(1, max(0, flightElapsed / flightDuration))
    }
}

enum TidalLane: Int, CaseIterable, Equatable, Sendable {
    case left = -1
    case middle = 0
    case right = 1
}

struct TidalWaveState: Identifiable, Equatable, Sendable {
    let id: Int
    let lane: TidalLane
    let round: Int
    var positionY: Double
    var previousPositionY: Double
    var delayRemaining: Double
    var elapsed: Double
    var hasLaunched: Bool = false
    let duration: Double
    let damage: Double
    let push: Double
    var contactedTargetIDs: Set<Int> = []

    var progress: Double {
        guard duration > 0 else { return 1 }
        return min(1, max(0, elapsed / duration))
    }

    var centerX: Double { 0 }
    var halfWidth: Double { 0.94 }
}

struct SimulationSnapshot: Equatable, Sendable {
    var world: WorldID
    var playerX: Double
    var stamina: Double
    var maxStamina: Double
    var elapsed: Double
    var tokens: Int
    var targets: [TargetState]
    var projectiles: [ProjectileState]
    var characterAttacks: [CharacterAttackState]
    var galeBounces: [GaleBounceState]
    var galeInterceptors: [GaleInterceptorState]
    var haloRings: [HaloRingState]
    var magneticTraps: [MagneticTrapState]
    var tidalWaves: [TidalWaveState]
    var bossHazards: [BossHazardState]
    var galeOrbitCount: Int
    var shieldCharges: Int
    var wave: Int
    var waveElapsed: Double
    var waveDefeats: Int
    var waveEnemyQuota: Int
    var isBossWave: Bool
    var score: Int
    var isEndless: Bool
    var combo: Int
    var comboFraction: Double
    var bestCombo: Int
    var targetsDefeated: Int
    var characterAbilityDefeats: Int
    var bossesDefeated: Int
    var waveCount: Int
    var activeTemporaryAbility: TemporaryBallAbility?
    var temporaryAbilityRemaining: Double
    var temporaryAbilityDuration: Double
    var characterAbilityCharge: Double
    var characterAbilityReady: Bool

    var remainingEnemies: Int {
        max(0, waveEnemyQuota - waveDefeats)
    }

    var waveObjectiveProgress: Double {
        if isBossWave,
           let boss = targets.first(where: {
               $0.waveRole == .boss || $0.bossTier != .standard
           }) {
            return min(
                1,
                max(0, 1 - boss.hitPoints / max(1, boss.maximumHitPoints))
            )
        }
        guard waveEnemyQuota > 0 else { return 0 }
        return min(1, max(0, Double(waveDefeats) / Double(waveEnemyQuota)))
    }
}

struct HUDState: Equatable, Sendable {
    var world: WorldID
    var stamina: Double
    var maxStamina: Double
    var elapsed: Double
    var tokens: Int
    var shieldCharges: Int
    var wave: Int
    var waveDefeats: Int
    var waveEnemyQuota: Int
    var remainingEnemies: Int
    var isBossWave: Bool
    var waveObjectiveProgress: Double
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
        world = snapshot.world
        stamina = snapshot.stamina
        maxStamina = snapshot.maxStamina
        elapsed = snapshot.elapsed
        tokens = snapshot.tokens
        shieldCharges = snapshot.shieldCharges
        wave = snapshot.wave
        waveDefeats = snapshot.waveDefeats
        waveEnemyQuota = snapshot.waveEnemyQuota
        remainingEnemies = snapshot.remainingEnemies
        isBossWave = snapshot.isBossWave
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
        waveObjectiveProgress = snapshot.waveObjectiveProgress
    }
}

enum ImpactDelivery: Equatable, Sendable {
    case direct
    case area
    case damageOverTime
}

struct ImpactEvent: Equatable, Sendable {
    let targetID: Int
    let position: Vector2
    let impulse: Vector2
    let damage: Double
    let flavor: DamageFlavor
    let isCritical: Bool
    let isDefeating: Bool
    let delivery: ImpactDelivery
}

struct VoltArc: Equatable, Sendable {
    let source: Vector2
    let targetID: Int
    let destination: Vector2
    let generation: Int
    let recipientOrder: Int
    let damage: Double
    let isDefeating: Bool
}

struct VoltChainEvent: Equatable, Sendable {
    let originTargetID: Int
    let origin: Vector2
    let arcs: [VoltArc]
}

enum CharacterAbilityEffect: Equatable, Sendable {
    case timeShatter([Vector2])
    case galeLanding(Vector2, variant: Int)
    case galeInterception(Vector2)
    case haloContact(Vector2)
    case magneticTrapSnap(Vector2)
    case tidalLaunch(TidalLane, round: Int, position: Vector2)
    case tidalHit(Vector2)
}

enum SpecialBallEffectEvent: Equatable, Sendable {
    case gravityVortex(position: Vector2, radius: Double)
    case magnetMark(position: Vector2, duration: TimeInterval)
    case orbitRedirect(position: Vector2)
    case returnShot(position: Vector2)
    case solarPierce(position: Vector2)
    case tidalPush(position: Vector2)
}

enum SimulationEvent: Equatable, Sendable {
    case checkpoint(Int)
    case damage
    case kick
    case impact(ImpactEvent)
    case enemyShieldBroken(Vector2)
    case enemyShieldRefreshed(Vector2)
    case elementalReaction(Vector2)
    case reward(Int, Vector2)
    case heal(Double, Vector2)
    case upgradeChosen(RunUpgradeChoice)
    case bossPhase(Int)
    case bossAttackTelegraphed(BossAttackKind)
    case bossAttackActivated(BossAttackKind, Vector2)
    case waveCompleted(Int)
    case worldTransitioned(from: WorldID, to: WorldID)
    case meteorKick
    case comboChanged(Int)
    case comboMilestone(Int)
    case worldEffectActivated(WorldRule, Vector2)
    case worldEffectImpact(WorldRule, Vector2)
    case volatileCoreNeutralized(Vector2)
    case volatileCoreDetonated(Vector2)
    case temporaryAbilityActivated(TemporaryBallAbility, TimeInterval, Vector2)
    case characterAbilityActivated(CharacterAbility)
    case characterAbilityTargets(CharacterAbility, [Vector2])
    case characterProjectileRicochet(Vector2)
    case characterMeteorImpact(Vector2)
    case characterShockwaveBurst(Vector2)
    case characterShockwaveHit(Vector2)
    case characterAbilityEffect(CharacterAbilityEffect)
    case specialBallEffect(SpecialBallEffectEvent)
    case voltChain(VoltChainEvent)
    case finished(Bool)
}

nonisolated struct SeededGenerator: Codable, Equatable, RandomNumberGenerator, Sendable {
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
