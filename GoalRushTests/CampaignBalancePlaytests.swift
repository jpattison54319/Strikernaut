import Testing
@testable import GoalRush

@MainActor
struct CampaignBalancePlaytests {
    private struct Outcome {
        let didWin: Bool
        let progress: Double
        let stamina: Double
        let elapsed: Double
    }

    private struct ProgressionProfile {
        let level: Int
        let underBudgetRank: Int
        let recoveryRank: Int
        let character: CharacterID
    }

    @Test func seededWorldFinalesRewardPermanentInvestment() {
        let profiles = [
            ProgressionProfile(
                level: 10,
                underBudgetRank: 0,
                recoveryRank: 3,
                character: .ace
            ),
            ProgressionProfile(
                level: 20,
                underBudgetRank: 3,
                recoveryRank: 5,
                character: .volt
            ),
            ProgressionProfile(
                level: 30,
                underBudgetRank: 5,
                recoveryRank: 8,
                character: .nova
            ),
            ProgressionProfile(
                level: 40,
                underBudgetRank: 7,
                recoveryRank: 10,
                character: .aegis
            ),
            ProgressionProfile(
                level: 50,
                underBudgetRank: 9,
                recoveryRank: 16,
                character: .gale
            ),
            ProgressionProfile(
                level: 60,
                underBudgetRank: 11,
                recoveryRank: 15,
                character: .halo
            ),
            ProgressionProfile(
                level: 70,
                underBudgetRank: 15,
                recoveryRank: 24,
                character: .aegis
            ),
        ]
        let seeds: [UInt64] = [11, 29, 47]
        var underBudgetWins = 0
        var recoveryWins = 0

        for profile in profiles {
            let underBudget = seeds.map {
                run(
                    level: profile.level,
                    permanentRank: profile.underBudgetRank,
                    seed: $0,
                    character: profile.character
                )
            }
            let recovered = seeds.map {
                run(
                    level: profile.level,
                    permanentRank: profile.recoveryRank,
                    seed: $0,
                    character: profile.character
                )
            }
            let underBudgetProgress = underBudget.reduce(0) { $0 + $1.progress }
            let recoveredProgress = recovered.reduce(0) { $0 + $1.progress }
            let profileUnderBudgetWins = underBudget.count(where: \.didWin)
            let profileRecoveryWins = recovered.count(where: \.didWin)
            underBudgetWins += profileUnderBudgetWins
            recoveryWins += profileRecoveryWins

            #expect(
                recoveredProgress > underBudgetProgress,
                "Level \(profile.level) must reward the recovery profile."
            )
            #expect(
                profileUnderBudgetWins < seeds.count,
                "Level \(profile.level) under-budget profile cannot sweep every seed."
            )
            #expect(
                profileRecoveryWins > 0,
                """
                Level \(profile.level) recovery profile must retain a winning seed. \
                Recovered progress: \(recovered.map(\.progress)); stamina: \
                \(recovered.map(\.stamina)); elapsed: \(recovered.map(\.elapsed)).
                """
            )
            #expect(profileRecoveryWins >= profileUnderBudgetWins)
        }

        #expect(recoveryWins > underBudgetWins)
    }

    @Test func moonReadyBuildCannotSkipTheCampaignToUranus() {
        let seeds: [UInt64] = [11, 29, 47]
        let moonReady = seeds.map {
            run(level: 20, permanentRank: 5, seed: $0)
        }
        let skippedToUranus = seeds.map {
            run(level: 51, permanentRank: 5, seed: $0)
        }
        let uranusRecovery = seeds.map {
            run(level: 51, permanentRank: 12, seed: $0)
        }

        #expect(
            moonReady.contains { $0.didWin },
            "A rank-5 balanced build must retain a winning Moon-finale seed."
        )
        #expect(
            skippedToUranus.allSatisfy { !$0.didWin },
            """
            A Moon-ready build cannot clear Uranus after a debug unlock. \
            Progress: \(skippedToUranus.map(\.progress)); stamina: \
            \(skippedToUranus.map(\.stamina)); elapsed: \
            \(skippedToUranus.map(\.elapsed)).
            """
        )
        #expect(
            uranusRecovery.contains { $0.didWin },
            """
            Uranus must remain beatable after permanent investment. \
            Progress: \(uranusRecovery.map(\.progress)); stamina: \
            \(uranusRecovery.map(\.stamina)); elapsed: \
            \(uranusRecovery.map(\.elapsed)).
            """
        )
        #expect(
            uranusRecovery.reduce(0) { $0 + $1.progress }
                > skippedToUranus.reduce(0) { $0 + $1.progress }
        )
    }

    private func run(
        level: Int,
        permanentRank: Int,
        seed: UInt64,
        character: CharacterID? = nil
    ) -> Outcome {
        var progress = PlayerProgress.newPlayer
        for track in UpgradeTrack.allCases {
            progress.setRank(permanentRank, for: track)
        }
        progress.selectedCharacter = character
            ?? representativeCharacter(entering: GameContent.level(level).world)
        let simulation = GameSimulation(
            level: GameContent.level(level),
            progress: progress,
            assistMode: false,
            seed: seed
        )
        let draftOrder: [AbilityKind] = [
            .throughBall,
            .oneTwo,
            .quickRelease,
            .powerDrive,
            .gravityBoots,
            .cleanSheet
        ]
        var draftIndex = 0

        for frame in 0..<9_000 {
            if simulation.snapshot.characterAbilityReady {
                _ = simulation.activateCharacterAbility()
            }
            if frame.isMultiple(of: 3) {
                aimRepresentativePlayer(simulation)
            }
            let events = simulation.update(delta: 0.05)
            for event in events {
                if case .checkpoint = event {
                    simulation.apply(draftOrder[draftIndex % draftOrder.count])
                    draftIndex += 1
                }
                if case .finished(let won) = event {
                    return Outcome(
                        didWin: won,
                        progress: won
                            ? Double(simulation.snapshot.waveCount + 1)
                            : Double(simulation.snapshot.wave)
                                + simulation.snapshot.waveObjectiveProgress,
                        stamina: simulation.snapshot.stamina,
                        elapsed: simulation.snapshot.elapsed
                    )
                }
            }
        }

        return Outcome(
            didWin: false,
            progress: Double(simulation.snapshot.wave)
                + simulation.snapshot.waveObjectiveProgress,
            stamina: simulation.snapshot.stamina,
            elapsed: simulation.snapshot.elapsed
        )
    }

    private func representativeCharacter(entering world: WorldID) -> CharacterID {
        switch world {
        case .earth: .ace
        case .moon: .volt
        case .mars: .nova
        case .jupiter: .aegis
        case .saturn: .gale
        case .uranus: .halo
        case .neptune: .flux
        }
    }

    private func aimRepresentativePlayer(_ simulation: GameSimulation) {
        let urgentHazards = simulation.snapshot.bossHazards.filter {
            $0.telegraphRemaining < 0.65 && !$0.isFinished
        }
        let immediateProjectiles = simulation.snapshot.projectiles.filter {
            $0.hostile && $0.position.y < 0.30 && $0.position.y > 0.12
        }
        if !urgentHazards.isEmpty || !immediateProjectiles.isEmpty {
            moveToSafestLane(
                simulation,
                hazards: urgentHazards,
                projectiles: immediateProjectiles
            )
            return
        }

        if let core = simulation.snapshot.targets.first(where: {
            if case .volatileCore = $0.kind { true } else { false }
        }) {
            simulation.setPlayerTarget(x: core.position.x)
            return
        }

        if let powerUp = simulation.snapshot.targets.first(where: {
            if case .powerUp = $0.kind { true } else { false }
        }) {
            simulation.setPlayerTarget(x: powerUp.position.x)
            return
        }

        let approachingProjectiles = simulation.snapshot.projectiles.filter {
            $0.hostile && $0.position.y < 0.46 && $0.position.y > 0.12
        }
        if !approachingProjectiles.isEmpty {
            moveToSafestLane(
                simulation,
                hazards: [],
                projectiles: approachingProjectiles
            )
            return
        }

        if let threat = simulation.snapshot.targets
            .filter({
                if case .enemy = $0.kind { true } else { false }
            })
            .min(by: { $0.position.y < $1.position.y }) {
            simulation.setPlayerTarget(x: threat.position.x)
        }
    }

    private func minimumDistance(
        from lane: Double,
        to hazards: [BossHazardState]
    ) -> Double {
        hazards.map { abs(lane - $0.position.x) - $0.halfWidth }.min() ?? 1
    }

    private func safetyScore(
        lane: Double,
        hazards: [BossHazardState],
        projectiles: [ProjectileState]
    ) -> Double {
        min(
            minimumDistance(from: lane, to: hazards),
            projectiles.map { abs(lane - $0.position.x) - 0.11 }.min() ?? 1
        )
    }

    private func moveToSafestLane(
        _ simulation: GameSimulation,
        hazards: [BossHazardState],
        projectiles: [ProjectileState]
    ) {
        let lanes = [-0.78, -0.39, 0.0, 0.39, 0.78]
        let safestLane = lanes.max { lhs, rhs in
            safetyScore(lane: lhs, hazards: hazards, projectiles: projectiles)
                < safetyScore(lane: rhs, hazards: hazards, projectiles: projectiles)
        } ?? 0
        simulation.setPlayerTarget(x: safestLane)
    }
}
