import Testing
@testable import GoalRush

@MainActor
struct GameHapticPlannerTests {
    @Test func everyBurnDamageTickProducesItsOwnFireCue() {
        let impact = ImpactEvent(
            targetID: 1,
            position: .init(x: 0, y: 0.4),
            impulse: .init(x: 0, y: 0),
            damage: 4,
            flavor: .fire,
            isCritical: false,
            isDefeating: false,
            delivery: .damageOverTime
        )

        let cues = [
            SimulationEvent.impact(impact),
            .impact(impact),
            .impact(impact),
        ].flatMap(GameHapticPlanner.cues)

        #expect(cues == [
            .init(.fire),
            .init(.fire),
            .init(.fire),
        ])
    }

    @Test func everyVoltArcProducesAnElectricCueAtItsGenerationDelay() {
        let chain = VoltChainEvent(
            originTargetID: 1,
            origin: .init(x: 0, y: 0.3),
            arcs: [
                .init(
                    source: .init(x: 0, y: 0.3),
                    targetID: 2,
                    destination: .init(x: -0.2, y: 0.5),
                    generation: 1,
                    recipientOrder: 1,
                    damage: 2,
                    isDefeating: false
                ),
                .init(
                    source: .init(x: -0.2, y: 0.5),
                    targetID: 3,
                    destination: .init(x: 0.2, y: 0.6),
                    generation: 2,
                    recipientOrder: 2,
                    damage: 3,
                    isDefeating: false
                ),
                .init(
                    source: .init(x: -0.2, y: 0.5),
                    targetID: 4,
                    destination: .init(x: 0.4, y: 0.7),
                    generation: 2,
                    recipientOrder: 3,
                    damage: 4,
                    isDefeating: false
                ),
            ]
        )

        let cues = GameHapticPlanner.cues(for: .voltChain(chain))

        #expect(cues.count == chain.arcs.count)
        #expect(cues.allSatisfy { $0.kind == .electric })
        #expect(cues.map(\.delay) == [0, 0.07, 0.07])
    }

    @Test func elementalDirectHitsUseDistinctHapticKinds() {
        let flavors: [(DamageFlavor, GameHapticCue.Kind)] = [
            (.fire, .fire),
            (.ice, .ice),
            (.reverse, .reverse),
            (.volt, .electric),
            (.explosive, .explosive),
            (.split, .impact),
        ]

        for (flavor, kind) in flavors {
            let impact = ImpactEvent(
                targetID: 1,
                position: .init(x: 0, y: 0.4),
                impulse: .init(x: 0, y: 1),
                damage: 10,
                flavor: flavor,
                isCritical: false,
                isDefeating: false,
                delivery: .direct
            )
            #expect(
                GameHapticPlanner.cues(for: .impact(impact))
                    == [.init(kind)]
            )
        }
    }

    @Test func everyRenderedGameplayEffectProducesAHapticCue() {
        let position = Vector2(x: 0, y: 0.4)
        let impact = ImpactEvent(
            targetID: 1,
            position: position,
            impulse: .init(x: 0, y: 1),
            damage: 10,
            flavor: .standard,
            isCritical: false,
            isDefeating: false,
            delivery: .direct
        )
        let chain = VoltChainEvent(
            originTargetID: 1,
            origin: position,
            arcs: [
                .init(
                    source: position,
                    targetID: 2,
                    destination: .init(x: 0.2, y: 0.6),
                    generation: 1,
                    recipientOrder: 1,
                    damage: 2,
                    isDefeating: false
                )
            ]
        )
        let renderedEvents: [SimulationEvent] = [
            .kick,
            .impact(impact),
            .elementalReaction(position),
            .reward(1, position),
            .heal(1, position),
            .damage,
            .checkpoint(1),
            .upgradeChosen(.ability(.powerDrive)),
            .bossPhase(2),
            .bossAttackTelegraphed(.orbitalLaser),
            .bossAttackActivated(.orbitalLaser, position),
            .waveCompleted(1),
            .worldTransitioned(from: .earth, to: .moon),
            .meteorKick,
            .comboMilestone(10),
            .worldEffectActivated(.lunarCycle, position),
            .worldEffectImpact(.lunarCycle, position),
            .volatileCoreNeutralized(position),
            .volatileCoreDetonated(position),
            .temporaryAbilityActivated(.fire, 4, position),
            .characterAbilityActivated(.pinballBlitz),
            .characterProjectileRicochet(position),
            .characterMeteorImpact(position),
            .characterShockwaveBurst(position),
            .characterShockwaveHit(position),
            .specialBallEffect(.gravityVortex(position: position, radius: 0.42)),
            .specialBallEffect(.magnetMark(position: position, duration: 1.4)),
            .specialBallEffect(.orbitRedirect(position: position)),
            .specialBallEffect(.returnShot(position: position)),
            .specialBallEffect(.solarPierce(position: position)),
            .specialBallEffect(.tidalPush(position: position)),
            .voltChain(chain),
            .finished(true),
            .finished(false),
        ]

        for event in renderedEvents {
            #expect(
                !GameHapticPlanner.cues(for: event).isEmpty,
                "Expected a haptic cue for \(event)."
            )
        }
    }
}
