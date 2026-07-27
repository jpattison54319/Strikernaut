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
        #expect(UIImage(named: "GameplayArena")?.size == CGSize(width: 1024, height: 1536))
        #expect(UIImage(named: "MarsArena")?.size == CGSize(width: 1024, height: 1536))
        #expect(UIImage(named: "MenuHero")?.size == CGSize(width: 1024, height: 1536))
        #expect(UIImage(named: "TrainingToken")?.size == CGSize(width: 512, height: 512))
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

    private static let projectileNames = [
        "SoccerBall",
        "SoccerBallExplosive",
        "SoccerBallFire",
        "SoccerBallIce",
        "SoccerBallRapidFire",
        "SoccerBallReverse",
        "SoccerBallSplit"
    ]

    private static let factionSigilNames = [
        "EarthFactionSigil",
        "EarthBossFactionSigil",
        "MoonFactionSigil",
        "MoonBossFactionSigil",
        "MarsFactionSigil",
        "MarsBossFactionSigil"
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
        + [
            "AbilityMeteor",
            "AbilityMeteorImpact",
            "AbilityShockwave",
            "DailyChest",
            "GameplayArena",
            "MarsArena",
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
