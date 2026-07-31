import Testing
import SpriteKit
import UIKit
@testable import GoalRush

@MainActor
struct VisualThemeTests {
    @Test func bundledComicFontsAreRegistered() {
        let names = [
            "BarlowCondensed-BlackItalic",
            "BarlowCondensed-Bold",
            "BarlowSemiCondensed-SemiBold",
            "BarlowSemiCondensed-Medium"
        ]

        for name in names {
            #expect(UIFont(name: name, size: 18) != nil, "Missing registered font \(name)")
        }
    }

    @Test func everyProductionIllustrationLoadsFromTheAssetCatalog() {
        for name in Self.productionAssetNames {
            #expect(UIImage(named: name) != nil, "Missing production artwork \(name)")
        }
    }

    @Test func everyRunUpgradeUsesCustomArtwork() {
        let abilityAssets = AbilityKind.allCases.map(AbilityPresentation.artAsset)

        #expect(abilityAssets.count == AbilityKind.allCases.count)
        #expect(Set(abilityAssets).count == abilityAssets.count)
        #expect(abilityAssets.allSatisfy { UIImage(named: $0) != nil })

        let specialBallAssets = EndlessSpecialBallRules.abilities.map {
            SpecialBallPresentation.presentation(
                for: $0,
                currentRank: 0
            ).artAsset
        }
        #expect(
            specialBallAssets.allSatisfy { UIImage(named: $0) != nil }
        )
    }

    @Test func runUpgradeOnlyUsesNewBeforeItsFirstRank() {
        #expect(
            RunUpgradePresentation.rankLabel(forCurrentRank: 0)
                == "NEW • RANK 1"
        )
        #expect(
            RunUpgradePresentation.rankLabel(forCurrentRank: 1)
                == "RANK 1 → 2"
        )
        #expect(
            RunUpgradePresentation.rankLabel(forCurrentRank: 7)
                == "RANK 7 → 8"
        )
    }

    @Test func gameplayArtRetainsContractDimensions() {
        for name in Self.characterAndWorldObjectNames {
            #expect(UIImage(named: name)?.size == CGSize(width: 512, height: 512), "\(name) changed size")
        }
        for name in Self.projectileNames {
            #expect(UIImage(named: name)?.size == CGSize(width: 384, height: 384), "\(name) changed size")
        }
        for name in Self.factionSigilNames {
            #expect(UIImage(named: name)?.size == CGSize(width: 512, height: 512), "\(name) changed size")
        }
        for name in Self.arenaAndMapNames {
            #expect(UIImage(named: name)?.size == CGSize(width: 1024, height: 1536), "\(name) changed size")
        }
        for name in Self.planetNames {
            #expect(UIImage(named: name)?.size == CGSize(width: 1254, height: 1254), "\(name) changed size")
        }
        #expect(UIImage(named: "MenuHero")?.size == CGSize(width: 1024, height: 1536))
        #expect(UIImage(named: "TrainingToken")?.size == CGSize(width: 512, height: 512))
    }

    @Test func everyCharacterUsesDistinctRosterAndGameplayArtwork() {
        let rosterArtwork = CharacterID.allCases.compactMap { character in
            UIImage(named: CharacterCatalog.character(character).assetStem + "Roster")?
                .pngData()
        }
        let gameplayArtwork = CharacterID.allCases.compactMap { character in
            UIImage(named: CharacterCatalog.character(character).assetStem + "Gameplay")?
                .pngData()
        }

        #expect(rosterArtwork.count == CharacterID.allCases.count)
        #expect(gameplayArtwork.count == CharacterID.allCases.count)
        #expect(Set(rosterArtwork).count == rosterArtwork.count)
        #expect(Set(gameplayArtwork).count == gameplayArtwork.count)
    }

    @Test func characterSilhouettesRemainDistinctAndAlphaSafe() {
        for suffix in ["Roster", "Gameplay"] {
            let masks = CharacterID.allCases.compactMap { character -> (CharacterID, [UInt8])? in
                let name = CharacterCatalog.character(character).assetStem + suffix
                guard let image = UIImage(named: name),
                      let mask = Self.alphaMask(for: image) else {
                    return nil
                }
                return (character, mask)
            }

            #expect(masks.count == CharacterID.allCases.count)

            for (character, mask) in masks {
                let coverage = Double(mask.reduce(0) { $0 + Int($1) }) / Double(mask.count)
                #expect(coverage > 0.08, "\(character) \(suffix) has too little visible artwork")
                #expect(coverage < 0.35, "\(character) \(suffix) exceeds the sprite safe area")
                #expect(mask[0] == 0)
                #expect(mask[63] == 0)
                #expect(mask[64 * 63] == 0)
                #expect(mask[(64 * 64) - 1] == 0)
            }

            for firstIndex in masks.indices {
                for secondIndex in masks.indices where secondIndex > firstIndex {
                    let first = masks[firstIndex]
                    let second = masks[secondIndex]
                    let difference = zip(first.1, second.1).reduce(0) {
                        $0 + ($1.0 == $1.1 ? 0 : 1)
                    }
                    let differenceRatio = Double(difference) / Double(first.1.count)
                    #expect(
                        differenceRatio > 0.025,
                        "\(first.0) and \(second.0) \(suffix) silhouettes are too similar"
                    )
                }
            }
        }
    }

    @Test func moonEnemiesUseUniqueMoonArtwork() {
        let moonEnemies: [EnemyKind] = [
            .regolithRunner,
            .lunarHopper,
            .orbitDrone,
            .eclipseKeeper,
            .gravityStriker,
            .lunarWarden
        ]
        let assetNames = moonEnemies.compactMap { GameNodeFactory.renderedEnemyAssetNames[$0] }

        #expect(assetNames.count == moonEnemies.count)
        #expect(Set(assetNames).count == moonEnemies.count)
        #expect(assetNames.allSatisfy { $0.hasPrefix("Moon") })
        #expect(assetNames.allSatisfy { !Self.earthEnemyNames.contains($0) })
    }

    @Test func rewardBurstUsesOneAnimatedTokenPerRewardWithoutANumberLabel() {
        let session = GameSessionModel(
            mode: .campaign(level: 1),
            progress: .newPlayer,
            settings: GameSettings()
        )
        let scene = GoalRushScene(session: session, reducedEffects: false)

        scene.spawnRewardForTesting(value: 10, from: .init(x: 180, y: 380))

        #expect(scene.rewardTokensForTesting.count == 10)
        #expect(scene.rewardTokensForTesting.allSatisfy {
            $0.action(forKey: "reward-flight") != nil
        })
        #expect(scene.rewardTokensForTesting.allSatisfy { !($0 is SKLabelNode) })
    }

    @Test func rewardStreamScalesModestlyWithoutBecomingLongRunning() {
        let lowDuration = GoalRushScene.rewardStreamDuration(for: 2)
        let mediumDuration = GoalRushScene.rewardStreamDuration(for: 10)
        let highDuration = GoalRushScene.rewardStreamDuration(for: 180)

        #expect(abs(lowDuration - 0.12) < 0.0001)
        #expect((0.35...0.37).contains(mediumDuration))
        #expect(highDuration > mediumDuration)
        #expect(highDuration <= 1.20)
        #expect(
            abs(
                GoalRushScene.rewardFlightDelay(
                    index: 179,
                    count: 180,
                    streamDuration: highDuration
                ) - highDuration
            ) < 0.0001
        )
        #expect(
            GoalRushScene.rewardFlightDelay(
                index: 1,
                count: 180,
                streamDuration: highDuration
            ) < GoalRushScene.rewardFlightDelay(
                index: 1,
                count: 10,
                streamDuration: mediumDuration
            )
        )
    }

    @Test func defeatingEnemiesFragmentByOutcomeAndKickTheCamera() {
        let session = GameSessionModel(
            mode: .campaign(level: 1),
            progress: .newPlayer,
            settings: GameSettings()
        )
        let scene = GoalRushScene(session: session, reducedEffects: false)
        let target = TargetState(
            id: 7_001,
            kind: .enemy(.coneRunner),
            position: .init(x: 0.1, y: 0.45),
            hitPoints: 0,
            maximumHitPoints: 10,
            phase: 0
        )
        scene.handleImpactForTesting(
            ImpactEvent(
                targetID: target.id,
                position: target.position,
                impulse: .init(x: 0.6, y: 0.8),
                damage: 10,
                flavor: .standard,
                isCritical: false,
                isDefeating: true,
                delivery: .direct
            ),
            target: target
        )

        #expect(scene.defeatFragmentsForTesting.count == 4)
        #expect(scene.defeatFragmentsForTesting.allSatisfy { $0.texture != nil })
        #expect(scene.hasImpactCameraKickForTesting)
    }

    @Test func criticalAndReducedEffectsUseAppropriateDefeatBursts() {
        let session = GameSessionModel(
            mode: .campaign(level: 1),
            progress: .newPlayer,
            settings: GameSettings()
        )
        let target = TargetState(
            id: 7_002,
            kind: .enemy(.dummyDefender),
            position: .init(x: -0.1, y: 0.45),
            hitPoints: 0,
            maximumHitPoints: 10,
            phase: 0
        )
        let impact = ImpactEvent(
            targetID: target.id,
            position: target.position,
            impulse: .init(x: -0.4, y: 0.9),
            damage: 14,
            flavor: .ice,
            isCritical: true,
            isDefeating: true,
            delivery: .direct
        )

        let fullScene = GoalRushScene(session: session, reducedEffects: false)
        fullScene.handleImpactForTesting(impact, target: target)
        #expect(fullScene.defeatFragmentsForTesting.count == 6)
        #expect(fullScene.criticalImpactRingsForTesting.count == 1)
        #expect(fullScene.hasImpactCameraKickForTesting)

        let reducedScene = GoalRushScene(session: session, reducedEffects: true)
        reducedScene.handleImpactForTesting(impact, target: target)
        #expect(reducedScene.defeatFragmentsForTesting.count == 1)
        #expect(!reducedScene.hasImpactCameraKickForTesting)
    }

    @Test func voltChainBuildsDistinctThreeLayerLightningVeins() {
        let session = GameSessionModel(
            mode: .campaign(level: 1),
            progress: .newPlayer,
            settings: GameSettings()
        )
        let scene = GoalRushScene(session: session, reducedEffects: false)
        var arcs: [VoltArc] = []
        for order in 1...7 {
            let source = Vector2(x: Double(order - 1) * 0.02, y: 0.35)
            let destination = Vector2(
                x: Double(order) * 0.08 - 0.32,
                y: 0.42 + Double(order) * 0.04
            )
            let generation = Int(log2(Double(order)).rounded(.down)) + 1
            arcs.append(VoltArc(
                source: source,
                targetID: 8_000 + order,
                destination: destination,
                generation: generation,
                recipientOrder: order,
                damage: Double(order),
                isDefeating: false
            ))
        }
        scene.handleVoltChainForTesting(VoltChainEvent(
            originTargetID: 7_999,
            origin: .init(x: 0, y: 0.35),
            arcs: arcs
        ))

        #expect(scene.voltArcsForTesting.count == 7)
        #expect(scene.voltArcsForTesting.allSatisfy {
            $0.childNode(withName: "volt-glow") is SKShapeNode
                && $0.childNode(withName: "volt-body") is SKShapeNode
                && $0.childNode(withName: "volt-core") is SKShapeNode
        })
        let pathBoxes = scene.voltArcsForTesting.compactMap {
            ($0.childNode(withName: "volt-core") as? SKShapeNode)?.path?.boundingBox
        }
        #expect(Set(pathBoxes.map { "\($0.minX),\($0.minY),\($0.maxX),\($0.maxY)" }).count > 1)
    }

    private static func alphaMask(for image: UIImage, side: Int = 64) -> [UInt8]? {
        guard let source = image.cgImage else { return nil }

        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        let rendered = pixels.withUnsafeMutableBytes { storage -> Bool in
            guard let context = CGContext(
                data: storage.baseAddress,
                width: side,
                height: side,
                bitsPerComponent: 8,
                bytesPerRow: side * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else {
                return false
            }

            context.interpolationQuality = .high
            context.clear(CGRect(x: 0, y: 0, width: side, height: side))
            context.draw(source, in: CGRect(x: 0, y: 0, width: side, height: side))
            return true
        }

        guard rendered else { return nil }
        return stride(from: 3, to: pixels.count, by: 4).map { pixels[$0] > 16 ? 1 : 0 }
    }

    private static let projectileNames = [
        "SoccerBall",
        "SoccerBallExplosive",
        "SoccerBallFire",
        "SoccerBallIce",
        "SoccerBallRapidFire",
        "SoccerBallReverse",
        "SoccerBallSplit",
        "SoccerBallVolt"
    ]

    private static let factionSigilNames = [
        "EarthFactionSigil",
        "EarthBossFactionSigil",
        "MoonFactionSigil",
        "MoonBossFactionSigil",
        "MarsFactionSigil",
        "MarsBossFactionSigil",
        "JupiterFactionSigil",
        "JupiterBossFactionSigil",
        "SaturnFactionSigil",
        "SaturnBossFactionSigil",
        "UranusFactionSigil",
        "UranusBossFactionSigil",
        "NeptuneFactionSigil",
        "NeptuneBossFactionSigil"
    ]

    private static let arenaAndMapNames = [
        "GameplayArena",
        "MoonArena",
        "MarsArena",
        "JupiterArena",
        "SaturnArena",
        "UranusArena",
        "NeptuneArena",
        "EarthWorldMap",
        "MoonWorldMap",
        "MarsWorldMap",
        "JupiterWorldMap",
        "SaturnWorldMap",
        "UranusWorldMap",
        "NeptuneWorldMap"
    ]

    private static let planetNames = [
        "PlanetEarth",
        "PlanetMoon",
        "PlanetMars",
        "PlanetJupiter",
        "PlanetSaturn",
        "PlanetUranus",
        "PlanetNeptune"
    ]

    private static let characterAndWorldObjectNames = [
        "CharacterAceGameplay",
        "CharacterAceKickContact",
        "CharacterAceKickFollowThrough",
        "CharacterAceKickRecovery",
        "CharacterAceKickSwing",
        "CharacterAceKickWindup",
        "CharacterAceRigBase",
        "CharacterAceRigRightLeg",
        "CharacterAceRoster",
        "CharacterAegisGameplay",
        "CharacterAegisRoster",
        "CharacterNovaGameplay",
        "CharacterNovaRoster",
        "CharacterVoltGameplay",
        "CharacterVoltRoster",
        "CharacterFluxGameplay",
        "CharacterFluxRoster",
        "CharacterGaleGameplay",
        "CharacterGaleRoster",
        "CharacterHaloGameplay",
        "CharacterHaloRoster",
        "CharacterSurgeGameplay",
        "CharacterSurgeRoster",
        "EarthAegisKeeper",
        "EarthBallCart",
        "EarthBallLauncher",
        "EarthBlockerDefender",
        "EarthConeBarricade",
        "EarthEquipmentTrunk",
        "EarthScoutRunner",
        "EarthTackleBot",
        "EarthTacticsBoard",
        "EarthTitanKeeper",
        "EarthWaterCooler",
        "MoonEclipseKeeper",
        "MoonGravityStriker",
        "MoonLunarHopper",
        "MoonLunarWarden",
        "MoonOrbitDrone",
        "MoonRegolithRunner",
        "MarsArtifactVault",
        "MarsColossus",
        "MarsCraterCrawler",
        "MarsCrystalBarricade",
        "MarsDustSprite",
        "MarsHoloGate",
        "MarsMeteorCrate",
        "MarsOxygenPod",
        "MarsPlasmaStriker",
        "MarsRoverRaider",
        "MarsSaucerKeeper"
    ]

    private static let productionAssetNames = characterAndWorldObjectNames
        + projectileNames
        + factionSigilNames
        + arenaAndMapNames
        + planetNames
        + [
            "AbilityCleanSheet",
            "AbilityCurler",
            "AbilityGoldenGoal",
            "AbilityGravityBoots",
            "AbilityMeteor",
            "AbilityMeteorImpact",
            "AbilityPowerDrive",
            "AbilityQuickRelease",
            "AbilitySecondWind",
            "AbilityShockwave",
            "AbilityThroughBall",
            "AbilityWideVolley",
            "DailyChest",
            "MenuHero",
            "OnboardingHero",
            "TrainingToken",
            "UpgradeBay"
        ]

    private static let earthEnemyNames: Set<String> = [
        "EarthScoutRunner",
        "EarthBlockerDefender",
        "EarthTackleBot",
        "EarthAegisKeeper",
        "EarthBallLauncher",
        "EarthTitanKeeper"
    ]
}
