import Foundation

struct GameHapticCue: Equatable, Sendable {
    enum Kind: CaseIterable, Hashable, Sendable {
        case kick
        case impact
        case critical
        case fire
        case ice
        case reverse
        case electric
        case explosive
        case reward
        case damage
        case success
        case boss
        case meteor
        case shockwave
    }

    let kind: Kind
    let delay: TimeInterval

    init(_ kind: Kind, delay: TimeInterval = 0) {
        self.kind = kind
        self.delay = delay
    }
}

enum GameHapticPlanner {
    static func cues(for event: SimulationEvent) -> [GameHapticCue] {
        switch event {
        case .kick:
            [.init(.kick)]
        case .impact(let impact):
            [.init(kind(for: impact))]
        case .elementalReaction:
            [.init(.impact)]
        case .reward, .heal, .comboMilestone:
            [.init(.reward)]
        case .damage, .worldEffectImpact, .volatileCoreDetonated:
            [.init(.damage)]
        case .checkpoint, .upgradeChosen, .waveCompleted,
             .temporaryAbilityActivated, .volatileCoreNeutralized:
            [.init(.success)]
        case .bossPhase, .worldTransitioned:
            [.init(.boss)]
        case .bossAttackTelegraphed, .worldEffectActivated,
             .characterAbilityActivated:
            [.init(.critical)]
        case .bossAttackActivated(let kind, _):
            [.init(kind == .meteorStrike ? .meteor : .boss)]
        case .meteorKick, .characterMeteorImpact:
            [.init(.meteor)]
        case .characterProjectileRicochet:
            [.init(.impact)]
        case .characterShockwaveBurst:
            [.init(.shockwave)]
        case .characterShockwaveHit:
            [.init(.impact)]
        case .characterAbilityEffect(let effect):
            switch effect {
            case .timeShatter:
                [.init(.ice)]
            case .galeLanding:
                [.init(.explosive)]
            case .galeInterception:
                [.init(.critical)]
            case .haloContact:
                [.init(.impact)]
            case .magneticTrapSnap:
                [.init(.reverse)]
            case .tidalLaunch:
                [.init(.shockwave)]
            case .tidalHit:
                [.init(.impact)]
            }
        case .specialBallEffect(let effect):
            switch effect {
            case .gravityVortex:
                [.init(.explosive)]
            case .magnetMark:
                [.init(.electric)]
            case .orbitRedirect:
                [.init(.impact)]
            case .returnShot:
                [.init(.impact)]
            case .solarPierce:
                [.init(.critical)]
            case .tidalPush:
                [.init(.shockwave)]
            }
        case .voltChain(let chain):
            chain.arcs.map { arc in
                .init(
                    .electric,
                    delay: Double(max(0, arc.generation - 1)) * 0.07
                )
            }
        case .finished(let won):
            [.init(won ? .success : .damage)]
        case .comboChanged, .characterAbilityTargets:
            []
        }
    }

    private static func kind(for impact: ImpactEvent) -> GameHapticCue.Kind {
        if impact.delivery == .damageOverTime {
            return impact.flavor == .fire ? .fire : .impact
        }
        return switch impact.flavor {
        case .fire:
            .fire
        case .ice:
            .ice
        case .reverse:
            .reverse
        case .volt:
            .electric
        case .explosive:
            .explosive
        case .standard, .split:
            impact.isCritical || impact.isDefeating ? .critical : .impact
        }
    }
}
