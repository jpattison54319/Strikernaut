import Testing
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
        #expect(UIImage(named: "GameplayArena")?.size == CGSize(width: 1024, height: 1536))
        #expect(UIImage(named: "MarsArena")?.size == CGSize(width: 1024, height: 1536))
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
        + [
            "AbilityMeteor",
            "AbilityMeteorImpact",
            "AbilityShockwave",
            "DailyChest",
            "GameplayArena",
            "MarsArena",
            "MenuHero",
            "OnboardingHero",
            "UpgradeBay"
        ]
}
