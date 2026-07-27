import Testing
@testable import GoalRush

@MainActor
struct CampaignBalancePlaytests {
    private struct Outcome {
        let didWin: Bool
        let progress: Double
    }

    private struct LandmarkProfile {
        let level: Int
        let underBudgetRank: Int
        let recoveryRank: Int
    }

    @Test func seededLandmarkRunsRewardPermanentInvestment() {
        let profiles = [
            LandmarkProfile(level: 5, underBudgetRank: 0, recoveryRank: 1),
            LandmarkProfile(level: 8, underBudgetRank: 1, recoveryRank: 2),
            LandmarkProfile(level: 10, underBudgetRank: 2, recoveryRank: 3),
            LandmarkProfile(level: 15, underBudgetRank: 4, recoveryRank: 5),
            LandmarkProfile(level: 18, underBudgetRank: 6, recoveryRank: 7),
            LandmarkProfile(level: 20, underBudgetRank: 7, recoveryRank: 8),
            LandmarkProfile(level: 25, underBudgetRank: 7, recoveryRank: 9),
            LandmarkProfile(level: 28, underBudgetRank: 9, recoveryRank: 11),
            LandmarkProfile(level: 30, underBudgetRank: 10, recoveryRank: 12)
        ]
        let seeds: [UInt64] = [11, 29, 47]
        var underBudgetWins = 0
        var recoveryWins = 0

        for profile in profiles {
            let underBudget = seeds.map {
                run(level: profile.level, permanentRank: profile.underBudgetRank, seed: $0)
            }
            let recovered = seeds.map {
                run(level: profile.level, permanentRank: profile.recoveryRank, seed: $0)
            }
            let underBudgetProgress = underBudget.reduce(0) { $0 + $1.progress }
            let recoveredProgress = recovered.reduce(0) { $0 + $1.progress }
            let profileUnderBudgetWins = underBudget.count(where: \.didWin)
            let profileRecoveryWins = recovered.count(where: \.didWin)
            underBudgetWins += profileUnderBudgetWins
            recoveryWins += profileRecoveryWins

            #expect(recoveredProgress > underBudgetProgress)
            #expect(profileUnderBudgetWins < seeds.count)
            #expect(profileRecoveryWins > 0)
            #expect(profileRecoveryWins >= profileUnderBudgetWins)
        }

        #expect(underBudgetWins <= seeds.count * 3)
        #expect(recoveryWins > underBudgetWins)
    }

    private func run(level: Int, permanentRank: Int, seed: UInt64) -> Outcome {
        var progress = PlayerProgress.newPlayer
        for track in UpgradeTrack.allCases {
            progress.setRank(permanentRank, for: track)
        }
        let simulation = GameSimulation(
            level: GameContent.level(level),
            progress: progress,
            assistMode: false,
            seed: seed
        )
        let draftOrder: [AbilityKind] = [
            .powerDrive,
            .quickRelease,
            .throughBall,
            .curler,
            .oneTwo,
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
                                + simulation.snapshot.waveObjectiveProgress
                    )
                }
            }
        }

        return Outcome(
            didWin: false,
            progress: Double(simulation.snapshot.wave)
                + simulation.snapshot.waveObjectiveProgress
        )
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
