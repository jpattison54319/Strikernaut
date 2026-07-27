import XCTest

@MainActor
final class GoalRushUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testHomeLevelAndUpgradeNavigation() {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-save", "--currency", "500"]
        app.launch()

        XCTAssertTrue(app.buttons["play"].waitForExistence(timeout: 3))
        let brand = app.descendants(matching: .any)["home-brand"]
        XCTAssertTrue(brand.exists)
        XCTAssertTrue(brand.label.contains("STRIKERNAUT"))
        XCTAssertTrue(app.buttons["continue-hero"].exists)
        XCTAssertTrue(app.buttons["trophies"].exists)
        XCTAssertTrue(app.buttons["characters"].exists)
        XCTAssertTrue(app.buttons["upgrades"].exists)

        app.buttons["trophies"].tap()
        XCTAssertTrue(app.buttons["progress-trophies"].waitForExistence(timeout: 2))
        app.buttons["Home"].tap()

        app.buttons["play"].tap()
        XCTAssertTrue(app.buttons["planet-earth"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["planet-moon"].exists)
        XCTAssertTrue(app.buttons["planet-mars"].exists)
        app.buttons["planet-earth"].tap()
        XCTAssertTrue(app.buttons["level-1"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["level-2"].label.localizedCaseInsensitiveContains("locked"))
        app.buttons["level-1"].tap()
        XCTAssertFalse(app.otherElements["level-preview"].exists)
        XCTAssertTrue(app.buttons["briefing-start"].waitForExistence(timeout: 2))
        app.buttons["briefing-start"].tap()
        XCTAssertTrue(app.buttons["pause"].waitForExistence(timeout: 2))
        app.buttons["pause"].tap()
        XCTAssertTrue(app.buttons["pause-home"].waitForExistence(timeout: 2))
        app.buttons["pause-home"].tap()
        XCTAssertTrue(app.buttons["play"].waitForExistence(timeout: 2))

        app.buttons["play"].tap()
        XCTAssertTrue(app.buttons["planet-earth"].waitForExistence(timeout: 2))
        app.buttons["planet-earth"].tap()
        XCTAssertTrue(app.buttons["level-1"].waitForExistence(timeout: 2))
        app.buttons["level-1"].tap()
        XCTAssertFalse(app.buttons["briefing-start"].exists)
        XCTAssertTrue(app.buttons["pause"].waitForExistence(timeout: 2))
        app.buttons["pause"].tap()
        XCTAssertTrue(app.buttons["pause-home"].waitForExistence(timeout: 2))
        app.buttons["pause-home"].tap()
        XCTAssertTrue(app.buttons["play"].waitForExistence(timeout: 2))

        app.buttons["upgrades"].tap()
        XCTAssertTrue(app.otherElements["upgrade-impact"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["upgrade-purchase-impact"].waitForExistence(timeout: 2))
    }

    func testPlanetPaginationRevealsFutureJupiterAndReturns() {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-save", "--screen", "planets"]
        app.launch()

        let earth = app.buttons["planet-earth"]
        XCTAssertTrue(earth.waitForExistence(timeout: 3))
        XCTAssertTrue(earth.isHittable)
        let jupiter = app.buttons["planet-jupiter"]
        XCTAssertTrue(jupiter.exists)
        XCTAssertFalse(jupiter.isHittable)
        let jupiterYBeforePaging = jupiter.frame.midY

        let next = app.buttons["planet-page-next"]
        XCTAssertTrue(next.exists)
        next.tap()
        XCTAssertTrue(jupiter.waitForExistence(timeout: 2))
        XCTAssertTrue(jupiter.isHittable)
        XCTAssertGreaterThan(
            jupiter.frame.midY,
            jupiterYBeforePaging,
            "Jupiter should enter from above as the journey progresses upward."
        )

        let previous = app.buttons["planet-page-previous"]
        XCTAssertTrue(previous.isEnabled)
        previous.tap()
        XCTAssertTrue(earth.waitForExistence(timeout: 2))
        XCTAssertTrue(earth.isHittable)
    }

    func testUpgradesPurchaseDirectlyFromMainScreen() {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-save", "--currency", "500", "--screen", "upgrades"]
        app.launch()

        XCTAssertFalse(app.otherElements["upgrade-detail"].exists)
        let impactTrack = app.otherElements["upgrade-impact"]
        let upgradeList = app.scrollViews.firstMatch
        for _ in 0..<12 where !impactTrack.exists {
            upgradeList.swipeUp()
        }
        XCTAssertTrue(impactTrack.waitForExistence(timeout: 2))
        let purchase = app.buttons["upgrade-purchase-impact"]
        XCTAssertTrue(purchase.waitForExistence(timeout: 2))
        XCTAssertEqual(purchase.label, "Upgrade Impact for 100 Training Tokens")
        XCTAssertTrue(app.staticTexts["WORKSHOP RESERVES"].exists)
        XCTAssertTrue(app.staticTexts["upgrade-rank-impact"].exists)

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Earth Robot Upgrade Bay"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        purchase.tap()

        let nextCost = NSPredicate(format: "label == %@", "Upgrade Impact for 225 Training Tokens")
        expectation(for: nextCost, evaluatedWith: purchase)
        waitForExpectations(timeout: 2)
        XCTAssertFalse(app.otherElements["upgrade-detail"].exists)
    }

    func testLevelTenPrestigeAddsBronzeBadge() {
        let app = XCUIApplication()
        app.launchArguments = [
            "--reset-save", "--currency", "5000",
            "--screen", "upgrades", "--upgrade-level", "10"
        ]
        app.launch()

        let impactTrack = app.otherElements["upgrade-impact"]
        let upgradeList = app.scrollViews.firstMatch
        for _ in 0..<12 where !impactTrack.exists {
            upgradeList.swipeUp()
        }
        XCTAssertTrue(impactTrack.waitForExistence(timeout: 2))

        let prestige = app.buttons["upgrade-purchase-impact"]
        XCTAssertTrue(prestige.waitForExistence(timeout: 2))
        XCTAssertEqual(prestige.label, "Prestige Impact for 2,600 Training Tokens")
        XCTAssertTrue(prestige.isEnabled)
        prestige.tap()

        let nextLevel = NSPredicate(format: "label == %@", "Upgrade Impact for 1,300 Training Tokens")
        expectation(for: nextLevel, evaluatedWith: prestige)
        waitForExpectations(timeout: 2)
        XCTAssertTrue(
            app.descendants(matching: .any)["upgrade-prestige-bronze"].waitForExistence(timeout: 2)
        )
        Thread.sleep(forTimeInterval: 1)

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Bronze Prestige Upgrade Card"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    func testHomeProgressivelyDisclosesMissionDetails() {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-save", "--currency", "500"]
        app.launch()

        XCTAssertTrue(app.otherElements["home-root"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["missions"].exists)
        XCTAssertEqual(app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", "mission-")).count, 0)

        app.buttons["missions"].tap()
        XCTAssertTrue(app.otherElements["missions-sheet"].waitForExistence(timeout: 2))
        XCTAssertGreaterThan(app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", "mission-")).count, 0)
    }

    func testSettingsExposeAccessibilityControls() {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-save"]
        app.launch()
        app.buttons["settings"].tap()
        XCTAssertTrue(app.buttons["settings-accessibility"].waitForExistence(timeout: 2))
        app.buttons["settings-accessibility"].tap()
        XCTAssertTrue(app.switches["Assist Mode"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.switches["Reduce Flashes"].exists)
    }

    func testDirectLevelLaunchCanPauseAndResume() {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-save", "--level", "1", "--fixed-seed", "42"]
        app.launch()
        XCTAssertTrue(app.buttons["Kick Off"].waitForExistence(timeout: 3))
        app.buttons["Kick Off"].tap()
        XCTAssertTrue(app.buttons["pause"].waitForExistence(timeout: 3))
        app.buttons["pause"].tap()
        XCTAssertTrue(app.buttons["pause-continue"].waitForExistence(timeout: 2))
        app.buttons["pause-continue"].tap()
        XCTAssertTrue(app.buttons["pause"].waitForExistence(timeout: 2))
    }

    func testChargedCharacterAbilityCanBeActivatedInLivePlay() {
        let app = XCUIApplication()
        app.launchArguments = [
            "--reset-save", "--level", "1", "--fixed-seed", "42",
            "--character", "ace", "--character-ability-ready"
        ]
        app.launch()
        XCTAssertTrue(app.buttons["Kick Off"].waitForExistence(timeout: 3))
        app.buttons["Kick Off"].tap()
        let ability = app.buttons["character-ability"]
        XCTAssertTrue(ability.waitForExistence(timeout: 3))
        XCTAssertTrue(ability.isEnabled)
        ability.tap()
        XCTAssertFalse(ability.isEnabled)
        Thread.sleep(forTimeInterval: 0.35)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Ace Pinball Blitz In Flight"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    func testEveryCharacterKickFramesRenderInLivePlay() {
        for character in ["ace", "volt", "nova", "aegis"] {
            let app = XCUIApplication()
            app.launchArguments = [
                "--reset-save", "--level", "1", "--fixed-seed", "42",
                "--character", character
            ]
            app.launch()
            XCTAssertTrue(app.buttons["Kick Off"].waitForExistence(timeout: 3))
            app.buttons["Kick Off"].tap()
            XCTAssertTrue(app.buttons["pause"].waitForExistence(timeout: 3))

            Thread.sleep(forTimeInterval: 1.02)
            for frame in 1...3 {
                let screenshot = XCTAttachment(screenshot: app.screenshot())
                screenshot.name = "\(character.capitalized) Live Kick Frame \(frame)"
                screenshot.lifetime = .keepAlways
                add(screenshot)
                Thread.sleep(forTimeInterval: 0.055)
            }
            app.terminate()
        }
    }

    func testEveryCharacterAbilityHasLiveVisualFeedback() {
        for character in ["volt", "nova", "aegis"] {
            let app = XCUIApplication()
            app.launchArguments = [
                "--reset-save", "--level", "1", "--fixed-seed", "42", "--boss-preview",
                "--character", character, "--character-ability-ready"
            ]
            app.launch()
            XCTAssertTrue(app.buttons["Kick Off"].waitForExistence(timeout: 3))
            app.buttons["Kick Off"].tap()
            XCTAssertTrue(app.buttons["character-ability"].waitForExistence(timeout: 3))
            Thread.sleep(forTimeInterval: 0.45)
            app.buttons["character-ability"].tap()
            Thread.sleep(forTimeInterval: character == "nova" ? 0.58 : 0.12)

            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.name = character == "nova"
                ? "Nova Character Ability In Flight"
                : "\(character.capitalized) Character Ability"
            screenshot.lifetime = .keepAlways
            add(screenshot)
            if character == "nova" {
                Thread.sleep(forTimeInterval: 0.14)
                let impact = XCTAttachment(screenshot: app.screenshot())
                impact.name = "Nova Character Ability Impact"
                impact.lifetime = .keepAlways
                add(impact)
            }
            app.terminate()
        }
    }

    func testPauseShowsOnlyContinueHomeAndRetry() {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-save", "--level", "1", "--fixed-seed", "42"]
        app.launch()

        let kickOff = app.buttons["Kick Off"]
        XCTAssertTrue(kickOff.waitForExistence(timeout: 3))
        kickOff.tap()

        let pause = app.buttons["pause"]
        XCTAssertTrue(pause.waitForExistence(timeout: 3))
        pause.tap()

        XCTAssertTrue(app.staticTexts["Run Paused"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["pause-continue"].exists)
        XCTAssertTrue(app.buttons["pause-home"].exists)
        XCTAssertTrue(app.buttons["pause-retry"].exists)
        XCTAssertFalse(app.buttons["pause-missions"].exists)
        XCTAssertFalse(app.buttons["End Run"].exists)
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "tokens earned")).firstMatch.exists)

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Simplified Pause Modal"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    func testPauseHomeAndRetryActWithoutConfirmation() {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-save", "--level", "1", "--fixed-seed", "42"]
        app.launch()
        app.buttons["Kick Off"].tap()
        XCTAssertTrue(app.buttons["pause"].waitForExistence(timeout: 3))
        app.buttons["pause"].tap()
        app.buttons["pause-home"].tap()

        XCTAssertTrue(app.otherElements["home-root"].waitForExistence(timeout: 2))
        XCTAssertEqual(app.alerts.count, 0)
        XCTAssertEqual(app.sheets.count, 0)

        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["Kick Off"].waitForExistence(timeout: 3))
        app.buttons["Kick Off"].tap()
        XCTAssertTrue(app.buttons["pause"].waitForExistence(timeout: 3))
        app.buttons["pause"].tap()
        app.buttons["pause-retry"].tap()

        XCTAssertTrue(app.buttons["Kick Off"].waitForExistence(timeout: 2))
        XCTAssertEqual(app.alerts.count, 0)
        XCTAssertEqual(app.sheets.count, 0)
    }

    func testCampaignIntroducesNewEnemyBeforePlay() {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-save", "--level", "6", "--fixed-seed", "42"]
        app.launch()

        XCTAssertTrue(app.buttons["Kick Off"].waitForExistence(timeout: 3))
        let launcher = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "Ball Launcher"))
            .firstMatch
        XCTAssertTrue(launcher.exists)
        app.buttons["Kick Off"].tap()
        XCTAssertTrue(app.buttons["pause"].waitForExistence(timeout: 2))
    }

    func testCampaignHUDShowsWaveCountAndTemporaryPowerTimer() {
        let app = XCUIApplication()
        app.launchArguments = [
            "--reset-save",
            "--level", "1",
            "--fixed-seed", "42",
            "--temporary-ability", "ice"
        ]
        app.launch()

        XCTAssertTrue(app.buttons["Kick Off"].waitForExistence(timeout: 3))
        app.buttons["Kick Off"].tap()

        let objective = app.otherElements["wave-objective"]
        XCTAssertTrue(objective.waitForExistence(timeout: 3))
        XCTAssertEqual(objective.label, "Wave 1 of 3, 18 enemies remaining")
        let timer = app.otherElements["temporary-ability-timer"]
        XCTAssertTrue(timer.waitForExistence(timeout: 2))
        XCTAssertEqual(timer.label, "Ice Balls")

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Campaign Wave HUD and Temporary Power"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    func testFireBallProjectileKeepsTheSoccerBallReadable() {
        let app = XCUIApplication()
        app.launchArguments = [
            "--reset-save",
            "--level", "1",
            "--fixed-seed", "42",
            "--temporary-ability", "fire"
        ]
        app.launch()

        XCTAssertTrue(app.buttons["Kick Off"].waitForExistence(timeout: 3))
        app.buttons["Kick Off"].tap()

        let timer = app.otherElements["temporary-ability-timer"]
        XCTAssertTrue(timer.waitForExistence(timeout: 2))
        XCTAssertEqual(timer.label, "Fire Balls")

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Fire Soccer Ball Projectile"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    func testVoltBallChainsEnemySwarmInNormalAndReducedEffectsModes() {
        for reducedEffects in [false, true] {
            let app = XCUIApplication()
            app.launchArguments = [
                "--reset-save",
                "--level", "1",
                "--fixed-seed", "607",
                "--temporary-ability", "volt",
                "--enemy-swarm-preview",
                "--auto-kick-off"
            ]
            if reducedEffects {
                app.launchArguments.append("--reduced-effects")
            }
            app.launch()

            let timer = app.otherElements["temporary-ability-timer"]
            XCTAssertTrue(timer.waitForExistence(timeout: 3))
            XCTAssertEqual(timer.label, "Volt Ball")
            XCTAssertTrue(app.buttons["pause"].waitForExistence(timeout: 3))
            sleep(3)

            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.name = reducedEffects
                ? "Volt Ball Chain - Reduced Effects"
                : "Volt Ball Chain - Animated"
            screenshot.lifetime = .keepAlways
            add(screenshot)
            app.terminate()
        }
    }

    func testElementalStatusEffectsRenderOnLiveEnemyModels() {
        for ability in ["ice", "fire", "reverse"] {
            let app = XCUIApplication()
            app.launchArguments = [
                "--reset-save",
                "--level", "4",
                "--fixed-seed", "42",
                "--temporary-ability", ability,
                "--status-effect-preview", ability
            ]
            app.launch()

            XCTAssertTrue(app.buttons["Kick Off"].waitForExistence(timeout: 3))
            app.buttons["Kick Off"].tap()
            XCTAssertTrue(app.buttons["pause"].waitForExistence(timeout: 2))
            sleep(4)

            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.name = switch ability {
            case "ice": "Frozen Enemy Model Effect"
            case "fire": "Burning Enemy Model Effect"
            default: "Reversed Enemy Model Effect"
            }
            screenshot.lifetime = .keepAlways
            add(screenshot)
            app.terminate()
        }
    }

    func testHeatSeekingPowerReplacesCurveMaster() {
        let app = XCUIApplication()
        app.launchArguments = [
            "--reset-save",
            "--level", "4",
            "--fixed-seed", "42",
            "--temporary-ability", "heatSeeking"
        ]
        app.launch()
        app.buttons["Kick Off"].tap()

        let timer = app.otherElements["temporary-ability-timer"]
        XCTAssertTrue(timer.waitForExistence(timeout: 3))
        XCTAssertEqual(timer.label, "Heat Seeking")
        XCTAssertFalse(app.staticTexts["Curve Master"].exists)
    }

    func testPowerUpTargetAppearsAsATrophy() {
        let app = XCUIApplication()
        app.launchArguments = [
            "--reset-save",
            "--level", "1",
            "--fixed-seed", "42",
            "--power-up-preview"
        ]
        app.launch()

        XCTAssertTrue(app.buttons["Kick Off"].waitForExistence(timeout: 3))
        app.buttons["Kick Off"].tap()
        XCTAssertTrue(app.buttons["pause"].waitForExistence(timeout: 2))

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "One Hit Power Up Trophy"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    func testCampaignWaveClearOffersUpgradeAndFinalWaveShowsMegaBoss() {
        let app = XCUIApplication()
        app.launchArguments = [
            "--reset-save",
            "--level", "1",
            "--fixed-seed", "42",
            "--wave-complete-preview"
        ]
        app.launch()
        app.buttons["Kick Off"].tap()

        XCTAssertTrue(app.staticTexts["PICK A POWER"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["WAVE 2 OF 3"].exists)
        let choices = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "ability-")
        )
        XCTAssertEqual(choices.count, 3)
        for index in 0..<choices.count {
            XCTAssertTrue(choices.element(boundBy: index).isHittable)
        }
        let draftScreenshot = XCTAttachment(screenshot: app.screenshot())
        draftScreenshot.name = "Ability Choice Card Deck"
        draftScreenshot.lifetime = .keepAlways
        add(draftScreenshot)

        app.terminate()
        app.launchArguments = [
            "--reset-save",
            "--level", "10",
            "--fixed-seed", "42",
            "--campaign-wave", "5",
            "--boss-preview"
        ]
        app.launch()
        app.buttons["Kick Off"].tap()

        let bossObjective = app.otherElements["wave-objective"]
        XCTAssertTrue(bossObjective.waitForExistence(timeout: 3))
        XCTAssertEqual(
            bossObjective.label,
            "Wave 5 of 5, boss objective, 1 enemy remaining"
        )
        XCTAssertTrue(app.otherElements["boss-health"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["WORLD BOSS"].exists)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Earth Mega Boss Wave"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    func testRoundEightOpeningWaveNeverShowsABossObjective() {
        let app = XCUIApplication()
        app.launchArguments = [
            "--reset-save",
            "--level", "8",
            "--fixed-seed", "42",
            "--campaign-wave", "1",
            "--boss-preview"
        ]
        app.launch()
        let kickOff = app.buttons["Kick Off"]
        if kickOff.waitForExistence(timeout: 1) {
            kickOff.tap()
        }

        XCTAssertTrue(app.buttons["pause"].waitForExistence(timeout: 3))
        let objective = app.otherElements["wave-objective"]
        XCTAssertTrue(objective.waitForExistence(timeout: 3))
        XCTAssertTrue(objective.label.contains("Wave 1 of 5"))
        XCTAssertTrue(objective.label.contains("enemies remaining"))
        XCTAssertFalse(objective.label.contains("boss objective"))
    }

    func testComboFloatsBelowHUDAsABareCount() {
        let app = XCUIApplication()
        app.launchArguments = [
            "--reset-save",
            "--level", "8",
            "--fixed-seed", "42",
            "--combo-preview", "7"
        ]
        app.launch()

        let combo = app.otherElements["combo-meter"]
        XCTAssertTrue(combo.waitForExistence(timeout: 3))
        XCTAssertEqual(combo.label, "Combo times 7")
        XCTAssertFalse(app.staticTexts["COMBO"].exists)
        XCTAssertTrue(app.otherElements["gameplay-status-bar"].exists)
        XCTAssertTrue(app.otherElements["stamina-meter"].exists)

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Compact HUD With Bare Combo"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    func testLevelSixFinalWaveBossUsesOnlyItsInWorldHealthPlate() {
        let app = XCUIApplication()
        app.launchArguments = [
            "--reset-save",
            "--level", "6",
            "--fixed-seed", "42",
            "--campaign-wave", "4",
            "--boss-preview"
        ]
        app.launch()
        app.buttons["Kick Off"].tap()

        let objective = app.otherElements["wave-objective"]
        XCTAssertTrue(objective.waitForExistence(timeout: 3))
        XCTAssertTrue(objective.label.contains("boss objective"))
        XCTAssertTrue(app.otherElements["boss-health"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["WAVE BOSS"].exists)

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Level Six Wave Boss"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    func testWorldEffectsNeverAddPersistentHUD() {
        let app = XCUIApplication()
        app.launchArguments = [
            "--reset-save",
            "--level", "1",
            "--fixed-seed", "42"
        ]
        app.launch()
        app.buttons["Kick Off"].tap()

        XCTAssertTrue(app.buttons["pause"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.otherElements["world-effect"].exists)

        app.terminate()
        app.launchArguments = [
            "--reset-save",
            "--level", "11",
            "--fixed-seed", "42"
        ]
        app.launch()
        app.buttons["Kick Off"].tap()

        XCTAssertTrue(app.buttons["pause"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.otherElements["world-effect"].exists)

        app.terminate()
        app.launchArguments = [
            "--reset-save",
            "--level", "21",
            "--fixed-seed", "42"
        ]
        app.launch()
        app.buttons["Kick Off"].tap()

        XCTAssertTrue(app.buttons["pause"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.otherElements["world-effect"].exists)
    }

    func testEarthEnemyArtPreviewCapturesEveryRole() {
        let previews: [(level: Int, wave: Int, name: String)] = [
            (1, 3, "Scout Runner"),
            (2, 3, "Blocker Defender"),
            (3, 3, "Tackle Bot"),
            (4, 4, "Aegis Keeper"),
            (6, 4, "Ball Launcher"),
            (10, 5, "Titan Keeper")
        ]

        for preview in previews {
            let app = XCUIApplication()
            app.launchArguments = [
                "--reset-save",
                "--level", "\(preview.level)",
                "--fixed-seed", "42",
                "--campaign-wave", "\(preview.wave)",
                "--boss-preview"
            ]
            app.launch()

            let kickOff = app.buttons["Kick Off"]
            XCTAssertTrue(kickOff.waitForExistence(timeout: 3))
            kickOff.tap()
            XCTAssertTrue(app.buttons["pause"].waitForExistence(timeout: 3))

            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.name = "Earth Enemy - \(preview.name)"
            screenshot.lifetime = .keepAlways
            add(screenshot)
            app.terminate()
        }
    }

    func testMarsEnemyArtPreviewCapturesEveryRole() {
        let previews: [(level: Int, wave: Int, name: String)] = [
            (11, 3, "Dust Sprite"),
            (12, 3, "Rover Raider"),
            (13, 3, "Crater Crawler"),
            (14, 4, "Saucer Keeper"),
            (16, 4, "Plasma Striker"),
            (20, 5, "Mars Colossus")
        ]

        for preview in previews {
            let app = XCUIApplication()
            app.launchArguments = [
                "--reset-save",
                "--level", "\(preview.level)",
                "--fixed-seed", "42",
                "--campaign-wave", "\(preview.wave)",
                "--boss-preview"
            ]
            app.launch()

            let kickOff = app.buttons["Kick Off"]
            XCTAssertTrue(kickOff.waitForExistence(timeout: 3))
            kickOff.tap()
            XCTAssertTrue(app.buttons["pause"].waitForExistence(timeout: 3))

            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.name = "Mars Enemy - \(preview.name)"
            screenshot.lifetime = .keepAlways
            add(screenshot)
            app.terminate()
        }
    }

    func testMarsColossusSupportsEveryModelBoundStatusEffect() {
        for ability in ["ice", "fire", "reverse"] {
            let app = XCUIApplication()
            app.launchArguments = [
                "--reset-save",
                "--level", "20",
                "--fixed-seed", "42",
                "--campaign-wave", "5",
                "--boss-preview",
                "--temporary-ability", ability,
                "--status-effect-preview", ability
            ]
            app.launch()

            XCTAssertTrue(app.buttons["Kick Off"].waitForExistence(timeout: 3))
            app.buttons["Kick Off"].tap()
            XCTAssertTrue(app.buttons["pause"].waitForExistence(timeout: 3))
            sleep(2)

            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.name = switch ability {
            case "ice": "Mars Colossus Frozen"
            case "fire": "Mars Colossus Burning"
            default: "Mars Colossus Reversed"
            }
            screenshot.lifetime = .keepAlways
            add(screenshot)
            app.terminate()
        }
    }

    func testEndlessStartsWithPowerDraftThenCanPause() {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-save", "--fixed-seed", "42"]
        app.launch()
        XCTAssertTrue(app.buttons["endless"].waitForExistence(timeout: 3))
        app.buttons["endless"].tap()
        XCTAssertTrue(app.buttons["start-endless"].waitForExistence(timeout: 2))
        app.buttons["start-endless"].tap()
        let ability = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "ability-")).firstMatch
        XCTAssertTrue(ability.waitForExistence(timeout: 3))
        ability.tap()
        XCTAssertTrue(app.buttons["pause"].waitForExistence(timeout: 2))
        app.buttons["pause"].tap()
        XCTAssertTrue(app.buttons["pause-continue"].waitForExistence(timeout: 2))
    }

    func testCharacterRosterSelectsAnUnlockedHero() {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-save", "--unlock-characters", "--screen", "characters"]
        app.launch()
        let nova = app.buttons["character-nova"]
        XCTAssertTrue(nova.waitForExistence(timeout: 3))
        nova.tap()
        XCTAssertEqual(nova.label, "Selected")
    }

    func testCharacterRosterExplainsLockedHeroes() {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-save", "--screen", "characters"]
        app.launch()
        XCTAssertTrue(app.buttons["character-ace"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Clear Earth"].exists)
    }

    func testProgressProgressivelyDisclosesTrophies() {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-save", "--screen", "trophies"]
        app.launch()

        let trophies = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "trophy-"))
        XCTAssertEqual(trophies.count, 0)
        XCTAssertFalse(app.buttons["progress-streak"].exists)
        let trophiesCategory = app.buttons["progress-trophies"]
        XCTAssertTrue(trophiesCategory.waitForExistence(timeout: 2))
        trophiesCategory.tap()
        XCTAssertTrue(trophies.firstMatch.waitForExistence(timeout: 2))
        XCTAssertGreaterThan(trophies.count, 0)
    }

    func testUnlockedMarsPlanetOpensItsWorldMap() {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-save", "--unlock-worlds", "--screen", "levels"]
        app.launch()

        let mars = app.buttons["planet-mars"]
        XCTAssertTrue(mars.waitForExistence(timeout: 3))
        XCTAssertTrue(mars.isEnabled)
        mars.tap()
        XCTAssertTrue(app.staticTexts["Mars"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["level-21"].exists)
    }

    func testCampaignLevelShowsPreviewBeforeLaunch() {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-save", "--screen", "levels"]
        app.launch()

        XCTAssertFalse(app.otherElements["level-preview"].exists)
        XCTAssertTrue(app.buttons["planet-earth"].waitForExistence(timeout: 3))
        app.buttons["planet-earth"].tap()
        let lockedLevel = app.buttons["level-2"]
        XCTAssertTrue(lockedLevel.waitForExistence(timeout: 2))
        XCTAssertTrue(
            lockedLevel.label.localizedCaseInsensitiveContains("locked"),
            "Unexpected locked level label: \(lockedLevel.label)"
        )
        app.buttons["level-1"].tap()
        XCTAssertTrue(app.otherElements["level-preview"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["level-preview-play"].exists)
    }

    func testEndlessHubIsMinimalAndStartsOnEarth() {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-save", "--screen", "endless", "--fixed-seed", "42"]
        app.launch()

        XCTAssertTrue(app.otherElements["endless-last-run"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.otherElements["endless-best"].exists)
        XCTAssertFalse(app.staticTexts["World Circuit"].exists)
        XCTAssertFalse(app.staticTexts["New power after every wave"].exists)
        XCTAssertFalse(app.buttons["Rules"].exists)
        let start = app.buttons["start-endless"]
        XCTAssertEqual(start.label, "Start Endless")
        start.tap()

        let ability = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "ability-")).firstMatch
        XCTAssertTrue(ability.waitForExistence(timeout: 3))
        ability.tap()

        let objective = app.otherElements["wave-objective"]
        XCTAssertTrue(objective.waitForExistence(timeout: 2))
        XCTAssertEqual(objective.label, "Wave 1, 18 enemies remaining")

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Unified Endless Earth Opening"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    func testEndlessHubShowsPreviousAndBestRunStats() {
        let app = XCUIApplication()
        app.launchArguments = [
            "--reset-save", "--screen", "endless", "--endless-records"
        ]
        app.launch()

        let lastRun = app.otherElements["endless-last-run"]
        let best = app.otherElements["endless-best"]
        XCTAssertTrue(lastRun.waitForExistence(timeout: 3))
        XCTAssertEqual(lastRun.value as? String, "Wave 17, score 216,750")
        XCTAssertTrue(best.exists)
        XCTAssertEqual(best.value as? String, "Wave 24, score 384,500")
        XCTAssertEqual(app.buttons["start-endless"].label, "Start Endless")

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Minimal Endless Hub With Records"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    func testEndlessEnemyCounterAdvancesAfterInitialDraft() {
        let app = XCUIApplication()
        app.launchArguments = [
            "--reset-save", "--endless",
            "--fixed-seed", "42", "--enemy-swarm-preview"
        ]
        app.launch()

        let ability = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "ability-")).firstMatch
        XCTAssertTrue(ability.waitForExistence(timeout: 3))
        ability.tap()

        let objective = app.otherElements["wave-objective"]
        XCTAssertTrue(objective.waitForExistence(timeout: 2))
        let authoredStartingLabel = "Wave 1, 18 enemies remaining"
        expectation(
            for: NSPredicate(format: "label != %@", authoredStartingLabel),
            evaluatedWith: objective
        )
        waitForExpectations(timeout: 6)
        XCTAssertTrue(objective.label.hasPrefix("Wave 1, "))
        XCTAssertTrue(objective.label.hasSuffix(" enemies remaining"))
    }

    func testEndlessWorldTransitionHandsEarthOffToMoonBeforeDraft() {
        let app = XCUIApplication()
        app.launchArguments = [
            "--reset-save", "--endless", "--endless-wave", "11",
            "--world-transition-preview", "--fixed-seed", "42"
        ]
        app.launch()

        let transition = app.otherElements["endless-world-transition"]
        XCTAssertTrue(transition.waitForExistence(timeout: 3))
        XCTAssertEqual(transition.label, "Leaving Earth. Entering Moon.")

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Earth To Moon World Transition"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        let ability = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "ability-")
        ).firstMatch
        XCTAssertTrue(ability.waitForExistence(timeout: 5))
        XCTAssertFalse(transition.exists)
        ability.tap()

        let objective = app.otherElements["wave-objective"]
        XCTAssertTrue(objective.waitForExistence(timeout: 2))
        XCTAssertTrue(objective.label.hasPrefix("Wave 11, "))
    }

    func testOnboardingShowsOnceAndStartsFirstLevel() {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-onboarding", "--fixed-seed", "42"]
        app.launch()
        let next = app.buttons["onboarding-next"]
        XCTAssertTrue(next.waitForExistence(timeout: 3))
        next.tap()
        XCTAssertTrue(app.staticTexts["Draft wild powers"].waitForExistence(timeout: 2))
        XCTAssertTrue(next.waitForExistence(timeout: 2))
        next.tap()
        XCTAssertTrue(app.staticTexts["Get stronger forever"].waitForExistence(timeout: 2))
        XCTAssertTrue(next.waitForExistence(timeout: 2))
        next.tap() // "Kick Off" on the final page
        XCTAssertTrue(app.buttons["pause"].waitForExistence(timeout: 5) || app.buttons["Kick Off"].waitForExistence(timeout: 2))
    }

    func testDailyChestClaimsAndPaysTokens() {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-save", "--currency", "0"]
        app.launch()
        let chest = app.buttons["daily-chest"]
        XCTAssertTrue(chest.waitForExistence(timeout: 3))
        chest.tap()

        XCTAssertFalse(app.buttons["daily-collect"].exists)
        let currentDay = app.buttons["daily-reward-day-1"]
        XCTAssertTrue(currentDay.waitForExistence(timeout: 3))
        XCTAssertTrue(currentDay.isHittable)
        for day in 1...7 {
            XCTAssertTrue(app.descendants(matching: .any)["daily-reward-day-\(day)"].exists)
        }
        for day in 2...7 {
            XCTAssertFalse(app.buttons["daily-reward-day-\(day)"].exists)
        }
        let rewardBoardScreenshot = XCTAttachment(screenshot: app.screenshot())
        rewardBoardScreenshot.name = "Daily Reward Board"
        rewardBoardScreenshot.lifetime = .keepAlways
        add(rewardBoardScreenshot)

        currentDay.tap()

        XCTAssertFalse(app.buttons["daily-reward-day-1"].exists)
        let collectedDay = app.otherElements["daily-reward-day-1"]
        XCTAssertTrue(collectedDay.waitForExistence(timeout: 2))
        XCTAssertTrue(collectedDay.label.contains("collected"))
        XCTAssertTrue(chest.waitForExistence(timeout: 2))
    }

    func testEndlessResultShowsNewBestBadge() {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-save", "--screen", "result-endless"]
        app.launch()
        XCTAssertTrue(app.staticTexts["result-new-best"].waitForExistence(timeout: 3)
                      || app.otherElements["result-new-best"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["result-primary"].waitForExistence(timeout: 2))
    }

    func testCampaignResultOmitsMissionProgressAndSavedConfirmation() {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-save", "--screen", "result-world"]
        app.launch()

        XCTAssertTrue(app.buttons["result-primary"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["result-more-upgrades"].exists)
        XCTAssertTrue(app.buttons["result-more-map"].exists)
        XCTAssertTrue(app.buttons["result-more-home"].exists)
        XCTAssertFalse(app.buttons["result-more-characters"].exists)
        XCTAssertFalse(app.staticTexts["Mission progress"].exists)
        XCTAssertFalse(app.staticTexts["Progress and rewards saved"].exists)
        XCTAssertFalse(
            app.staticTexts.matching(
                NSPredicate(format: "label CONTAINS[c] %@", "claim on Home")
            ).firstMatch.exists
        )
    }

    func testCampaignLossUsesClearGameOverHeadline() {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-save", "--screen", "result-loss"]
        app.launch()

        let title = app.staticTexts["result-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 3))
        XCTAssertEqual(title.label, "GAME OVER")
        XCTAssertFalse(app.staticTexts["RUN ENDED"].exists)
    }

    func testResultExposesOnlyUpgradesMapAndHomeDestinations() {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-save", "--screen", "result-endless"]
        app.launch()

        XCTAssertTrue(app.buttons["result-primary"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.buttons["result-primary"].label, "Retry")
        XCTAssertTrue(app.buttons["result-more-upgrades"].exists)
        XCTAssertTrue(app.buttons["result-more-map"].exists)
        XCTAssertTrue(app.buttons["result-more-home"].exists)
        XCTAssertFalse(app.buttons["result-more-characters"].exists)
        XCTAssertFalse(app.buttons["result-more"].exists)
        XCTAssertFalse(app.otherElements["result-more-actions"].exists)

        app.buttons["result-more-upgrades"].tap()
        XCTAssertTrue(app.otherElements["upgrade-impact"].waitForExistence(timeout: 2))

        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["result-more-map"].waitForExistence(timeout: 3))
        app.buttons["result-more-map"].tap()
        XCTAssertTrue(app.otherElements["endless-last-run"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["start-endless"].exists)

        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["result-more-home"].waitForExistence(timeout: 3))
        app.buttons["result-more-home"].tap()
        XCTAssertTrue(app.otherElements["home-root"].waitForExistence(timeout: 2))
    }
}
