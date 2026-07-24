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
        XCTAssertTrue(app.buttons["level-1"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.buttons["level-2"].isEnabled)
        app.buttons["Home"].tap()
        app.buttons["upgrades"].tap()
        XCTAssertTrue(app.otherElements["upgrade-impact"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["upgrade-purchase-impact"].waitForExistence(timeout: 2))
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
        XCTAssertTrue(app.staticTexts["RANK 0 • UNLIMITED"].exists)

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

        XCTAssertTrue(app.staticTexts["WAVE 1 OF 3"].waitForExistence(timeout: 3))
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

        XCTAssertTrue(app.staticTexts["Upgrade for Wave 2 of 3"].waitForExistence(timeout: 3))
        XCTAssertTrue(
            app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "ability-"))
                .firstMatch.exists
        )

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

        XCTAssertTrue(app.staticTexts["BOSS • WAVE 5 OF 5"].waitForExistence(timeout: 3))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Earth Mega Boss Wave"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    func testEarthEnemyArtPreviewCapturesEveryRole() {
        let previews: [(level: Int, wave: Int, name: String)] = [
            (1, 1, "Scout Runner"),
            (2, 2, "Blocker Defender"),
            (3, 3, "Tackle Bot"),
            (4, 4, "Aegis Keeper"),
            (6, 3, "Ball Launcher"),
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
            (11, 1, "Dust Sprite"),
            (12, 2, "Rover Raider"),
            (13, 3, "Crater Crawler"),
            (14, 4, "Saucer Keeper"),
            (16, 3, "Plasma Striker"),
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
        XCTAssertTrue(app.staticTexts["Clear Level 10"].exists)
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

    func testUnlockedMarsCampaignTabIsSelectable() {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-save", "--unlock-worlds", "--screen", "levels"]
        app.launch()

        let mars = app.buttons["world-mars"]
        XCTAssertTrue(mars.waitForExistence(timeout: 3))
        XCTAssertTrue(mars.isEnabled)
        mars.tap()
        XCTAssertTrue(app.staticTexts["Mars Levels"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["level-11"].exists)
    }

    func testCampaignLevelShowsPreviewBeforeLaunch() {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-save", "--screen", "levels"]
        app.launch()

        XCTAssertFalse(app.otherElements["level-preview"].exists)
        let lockedLevel = app.buttons["level-2"]
        XCTAssertTrue(lockedLevel.exists)
        XCTAssertTrue(
            lockedLevel.label.contains("Clear Earth challenge 1 to unlock"),
            "Unexpected locked level label: \(lockedLevel.label)"
        )
        app.buttons["level-1"].tap()
        XCTAssertTrue(app.otherElements["level-preview"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["level-preview-play"].exists)
    }

    func testMarsEndlessStartsFromHubAndAdvances() {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-save", "--unlock-worlds", "--screen", "endless", "--fixed-seed", "42"]
        app.launch()

        let mars = app.buttons["endless-world-mars"]
        XCTAssertTrue(mars.waitForExistence(timeout: 3))
        mars.tap()
        let start = app.buttons["start-endless"]
        XCTAssertTrue(start.label.contains("Mars"))
        start.tap()

        let ability = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "ability-")).firstMatch
        XCTAssertTrue(ability.waitForExistence(timeout: 3))
        ability.tap()

        let progress = app.progressIndicators["run-progress"]
        XCTAssertTrue(progress.waitForExistence(timeout: 2))
        let initialValue = String(describing: progress.value)
        expectation(for: NSPredicate(format: "value != %@", initialValue), evaluatedWith: progress)
        waitForExpectations(timeout: 4)
    }

    func testMarsEndlessAdvancesAfterInitialDraft() {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-save", "--unlock-worlds", "--endless", "mars", "--fixed-seed", "42"]
        app.launch()

        let ability = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "ability-")).firstMatch
        XCTAssertTrue(ability.waitForExistence(timeout: 3))
        ability.tap()

        let progress = app.progressIndicators["run-progress"]
        XCTAssertTrue(progress.waitForExistence(timeout: 2))
        let initialValue = String(describing: progress.value)
        let advanced = NSPredicate(format: "value != %@", initialValue)
        expectation(for: advanced, evaluatedWith: progress)
        waitForExpectations(timeout: 4)
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
        XCTAssertFalse(app.staticTexts["Mission progress"].exists)
        XCTAssertFalse(app.staticTexts["Progress and rewards saved"].exists)
        XCTAssertFalse(
            app.staticTexts.matching(
                NSPredicate(format: "label CONTAINS[c] %@", "claim on Home")
            ).firstMatch.exists
        )
    }

    func testResultExposesThreeDirectCircularDestinations() {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-save", "--screen", "result-endless"]
        app.launch()

        XCTAssertTrue(app.buttons["result-primary"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.buttons["result-primary"].label, "Retry")
        XCTAssertTrue(app.buttons["result-more-upgrades"].exists)
        XCTAssertTrue(app.buttons["result-more-characters"].exists)
        XCTAssertTrue(app.buttons["result-more-map"].exists)
        XCTAssertFalse(app.buttons["result-more"].exists)
        XCTAssertFalse(app.otherElements["result-more-actions"].exists)

        app.buttons["result-more-upgrades"].tap()
        XCTAssertTrue(app.otherElements["upgrade-impact"].waitForExistence(timeout: 2))

        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["result-more-characters"].waitForExistence(timeout: 3))
        app.buttons["result-more-characters"].tap()
        XCTAssertTrue(app.buttons["character-ace"].waitForExistence(timeout: 2))

        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["result-more-map"].waitForExistence(timeout: 3))
        app.buttons["result-more-map"].tap()
        XCTAssertTrue(app.buttons["endless-world-earth"].waitForExistence(timeout: 2))
    }
}
