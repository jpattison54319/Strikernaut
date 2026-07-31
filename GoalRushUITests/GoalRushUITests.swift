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
        XCTAssertTrue(app.buttons["relics"].exists)
        XCTAssertTrue(app.buttons["upgrades"].exists)

        app.buttons["trophies"].tap()
        XCTAssertTrue(
            app.otherElements["progress-trophy-widget"]
                .waitForExistence(timeout: 2)
        )
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

    func testRelicsEmptyStateExplainsTheFirstDropAndStartsEndless() {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-save", "--screen", "relics"]
        app.launch()

        XCTAssertTrue(app.staticTexts["No Relics Yet"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Inventory"].exists)
        XCTAssertTrue(app.buttons["destination-forge"].exists)
        XCTAssertFalse(app.otherElements["relic-rarity-odds"].exists)
        let start = app.buttons["relics-empty-start-endless"]
        XCTAssertTrue(start.exists)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Relics Empty State Start Endless Padding"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        start.tap()
        XCTAssertTrue(
            app.buttons.matching(
                NSPredicate(format: "identifier BEGINSWITH %@", "ability-")
            ).firstMatch.waitForExistence(timeout: 3)
        )
    }

    func testRelicForgeRevealInventoryComparisonEquipAndScrapFlow() {
        let app = XCUIApplication()
        app.launchArguments = [
            "--reset-save", "--screen", "relics", "--relic-fixtures",
        ]
        app.launch()

        let forgeDestination = app.buttons["destination-forge"]
        XCTAssertTrue(forgeDestination.waitForExistence(timeout: 3))
        XCTAssertFalse(app.otherElements["relic-rarity-odds"].exists)
        XCTAssertFalse(app.staticTexts["Relic Forge"].exists)
        forgeDestination.tap()

        XCTAssertTrue(app.staticTexts["relic-scrap-balance"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.staticTexts["relic-scrap-balance"].label, "165 Scrap")
        XCTAssertEqual(
            app.staticTexts.matching(
                NSPredicate(format: "label CONTAINS[c] %@", "tier")
            ).count,
            0
        )
        let forgeMode = app.buttons["relic-forge-mode"]
        XCTAssertTrue(forgeMode.exists)
        XCTAssertEqual(forgeMode.value as? String, "Random")
        XCTAssertFalse(app.otherElements["relic-rarity-odds"].exists)

        let forge = app.buttons["forge-relic"]
        XCTAssertTrue(forge.exists)
        XCTAssertTrue(forge.isEnabled)
        forgeMode.tap()
        app.buttons["Focused"].tap()
        XCTAssertTrue(app.buttons["relic-focused-stat"].waitForExistence(timeout: 2))
        XCTAssertTrue(forge.label.contains("Forge Focused"))
        XCTAssertTrue(forge.label.contains("80"))
        forgeMode.tap()
        app.buttons["Random"].tap()
        XCTAssertTrue(forge.label.contains("Forge Random"))
        XCTAssertTrue(forge.label.contains("40"))
        forge.tap()
        XCTAssertTrue(
            app.otherElements["forge-relic-reveal"].waitForExistence(timeout: 3)
        )
        let revealName = app.staticTexts["forge-reveal-name"]
        if app.buttons["forge-reveal-skip"].exists {
            XCTAssertFalse(revealName.exists)
        }
        XCTAssertTrue(revealName.waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["relic-reveal-keep"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.otherElements["relic-comparison"].exists)
        let revealScreenshot = XCTAttachment(screenshot: app.screenshot())
        revealScreenshot.name = "Forged Relic Celebration"
        revealScreenshot.lifetime = .keepAlways
        add(revealScreenshot)
        app.buttons["relic-reveal-keep"].tap()

        XCTAssertEqual(
            app.staticTexts["relic-scrap-balance"].label,
            "125 Scrap"
        )
        app.buttons["destination-relics"].tap()

        let firstRelic = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "relic-card-")
        ).firstMatch
        XCTAssertTrue(firstRelic.waitForExistence(timeout: 3))
        firstRelic.tap()
        XCTAssertTrue(
            String(describing: firstRelic.value).contains("Equipped")
        )
        XCTAssertFalse(app.otherElements["relic-comparison"].exists)
        let equippedScreenshot = XCTAttachment(screenshot: app.screenshot())
        equippedScreenshot.name = "Equipped Relic Checkmark"
        equippedScreenshot.lifetime = .keepAlways
        add(equippedScreenshot)
        firstRelic.tap()
        XCTAssertTrue(
            String(describing: firstRelic.value).contains("Not equipped")
        )
        XCTAssertTrue(app.staticTexts["Inventory"].waitForExistence(timeout: 2))

        app.buttons["relic-inventory-salvage"].tap()
        let cancelCandidate = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "relic-card-")
        ).firstMatch
        XCTAssertTrue(cancelCandidate.waitForExistence(timeout: 2))
        cancelCandidate.tap()
        XCTAssertTrue(app.buttons["relic-salvage-confirm"].label.contains("Salvage 1"))
        app.buttons["relic-salvage-cancel"].tap()
        XCTAssertTrue(app.staticTexts["Inventory"].waitForExistence(timeout: 2))

        app.buttons["relic-inventory-salvage"].tap()
        let salvageCandidates = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "relic-card-")
        )
        XCTAssertGreaterThanOrEqual(salvageCandidates.count, 2)
        salvageCandidates.element(boundBy: 0).tap()
        salvageCandidates.element(boundBy: 1).tap()

        let salvage = app.buttons["relic-salvage-confirm"]
        XCTAssertTrue(salvage.isEnabled)
        XCTAssertTrue(salvage.label.contains("Salvage 2"))
        salvage.tap()
        let confirmSalvage = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Salvage 2 for")
        ).firstMatch
        XCTAssertTrue(confirmSalvage.waitForExistence(timeout: 2))
        confirmSalvage.tap()
        XCTAssertTrue(app.staticTexts["7 relics"].waitForExistence(timeout: 3))

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Relic Inventory and Salvage"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    func testRelicsRemainUsableAtAccessibilityExtraExtraExtraLarge() {
        let app = XCUIApplication()
        app.launchArguments = [
            "--reset-save", "--screen", "relics", "--relic-fixtures",
            "--dynamic-type-accessibility-xxxl",
        ]
        app.launch()

        XCTAssertTrue(app.staticTexts["Inventory"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["relic-inventory-salvage"].isHittable)

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Relics Accessibility XXXL"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        app.buttons["destination-forge"].tap()
        XCTAssertTrue(app.staticTexts["relic-scrap-balance"].waitForExistence(timeout: 3))
        let forge = app.buttons["forge-relic"]
        for _ in 0..<4 where !forge.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(forge.isHittable)
        XCTAssertTrue(forge.label.contains("Forge Random"))

        let forgeScreenshot = XCTAttachment(screenshot: app.screenshot())
        forgeScreenshot.name = "Relic Forge Accessibility XXXL"
        forgeScreenshot.lifetime = .keepAlways
        add(forgeScreenshot)
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

        let nextCost = NSPredicate(format: "label == %@", "Upgrade Impact for 275 Training Tokens")
        expectation(for: nextCost, evaluatedWith: purchase)
        waitForExpectations(timeout: 2)
        XCTAssertFalse(app.otherElements["upgrade-detail"].exists)
    }

    func testUpgradeHowItWorksMatchesLivePrestigeRules() {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-save", "--screen", "upgrades"]
        app.launch()

        let info = app.buttons["How It Works"]
        XCTAssertTrue(info.waitForExistence(timeout: 3))
        info.tap()

        XCTAssertTrue(
            app.otherElements["upgrade-how-it-works"]
                .waitForExistence(timeout: 2)
        )
        XCTAssertTrue(
            app.staticTexts[
                "Prestige changes the badge only—rank and stat bonuses never reset."
            ].exists
        )
        XCTAssertTrue(
            app.staticTexts[
                "Each badge costs 2.6K Training Tokens."
            ].exists
        )

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Current Upgrade Rules"
        screenshot.lifetime = .keepAlways
        add(screenshot)
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

        let nextLevel = NSPredicate(format: "label == %@", "Upgrade Impact for 3,050 Training Tokens")
        expectation(for: nextLevel, evaluatedWith: prestige)
        waitForExpectations(timeout: 2)
        XCTAssertEqual(app.staticTexts["upgrade-rank-impact"].label, "Bronze level 0")
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

    func testRecoveredCampaignRunOffersContinueOrStartOver() {
        let app = XCUIApplication()
        app.launchArguments = [
            "--reset-save", "--level", "1", "--fixed-seed", "42",
            "--run-checkpoint-preview",
        ]
        app.launch()

        let offer = app.otherElements["run-checkpoint-offer"]
        XCTAssertTrue(offer.waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["RUN RECOVERED"].exists)
        XCTAssertTrue(app.staticTexts["Wave 3"].exists)
        XCTAssertTrue(app.buttons["run-checkpoint-continue"].isHittable)
        XCTAssertTrue(app.buttons["run-checkpoint-start-over"].isHittable)

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Recovered Campaign Run Prompt"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        app.buttons["run-checkpoint-continue"].tap()
        XCTAssertTrue(app.staticTexts["PICK A POWER"].waitForExistence(timeout: 3))
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
        let previews: [(character: String, level: Int)] = [
            ("ace", 1),
            ("volt", 11),
            ("nova", 21),
            ("aegis", 30),
            ("gale", 31),
            ("halo", 41),
            ("flux", 51),
            ("surge", 61),
        ]
        for preview in previews {
            let app = XCUIApplication()
            app.launchArguments = [
                "--reset-save", "--level", "\(preview.level)", "--fixed-seed", "42",
                "--character", preview.character
            ]
            app.launch()
            XCTAssertTrue(app.buttons["Kick Off"].waitForExistence(timeout: 3))
            app.buttons["Kick Off"].tap()
            XCTAssertTrue(app.buttons["pause"].waitForExistence(timeout: 3))

            Thread.sleep(forTimeInterval: 1.02)
            for frame in 1...3 {
                let screenshot = XCTAttachment(screenshot: app.screenshot())
                screenshot.name = "\(preview.character.capitalized) Live Kick Frame \(frame)"
                screenshot.lifetime = .keepAlways
                add(screenshot)
                Thread.sleep(forTimeInterval: 0.055)
            }
            app.terminate()
        }
    }

    func testEveryCharacterAbilityHasLiveVisualFeedback() {
        let previews: [
            (character: String, level: Int, captureDelay: TimeInterval)
        ] = [
            ("volt", 11, 0.18),
            ("nova", 21, 0.58),
            ("aegis", 30, 0.18),
            ("gale", 31, 1.02),
            ("halo", 41, 0.30),
            ("flux", 51, 1.35),
            ("surge", 61, 0.72),
        ]
        for preview in previews {
            let app = XCUIApplication()
            app.launchArguments = [
                "--reset-save", "--level", "\(preview.level)", "--fixed-seed", "42",
                "--boss-preview", "--enemy-swarm-preview",
                "--character", preview.character, "--character-ability-ready"
            ]
            app.launch()
            XCTAssertTrue(app.buttons["Kick Off"].waitForExistence(timeout: 3))
            app.buttons["Kick Off"].tap()
            XCTAssertTrue(app.buttons["character-ability"].waitForExistence(timeout: 3))
            Thread.sleep(forTimeInterval: 0.45)
            app.buttons["character-ability"].tap()
            Thread.sleep(forTimeInterval: preview.captureDelay)

            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.name = preview.character == "nova"
                ? "Nova Character Ability In Flight"
                : "\(preview.character.capitalized) Character Ability"
            screenshot.lifetime = .keepAlways
            add(screenshot)
            if preview.character == "nova" {
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

        XCTAssertTrue(app.buttons["pause"].waitForExistence(timeout: 2))
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
        XCTAssertFalse(app.otherElements["endless-live-score"].exists)

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
        XCTAssertTrue(combo.label.hasPrefix("Combo times "))
        XCTAssertGreaterThanOrEqual(
            Int(combo.label.split(separator: " ").last ?? "") ?? 0,
            7
        )
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

    func testProgressShowsClosestTrophiesAndEveryLifetimeStat() {
        let app = XCUIApplication()
        app.launchArguments = [
            "--reset-save", "--screen", "trophies", "--progress-fixtures",
        ]
        app.launch()

        XCTAssertTrue(
            app.otherElements["progress-trophy-widget"]
                .waitForExistence(timeout: 3)
        )
        XCTAssertFalse(app.staticTexts["MILESTONE COMPLETION"].exists)
        XCTAssertFalse(app.staticTexts["NEXT MILESTONE"].exists)
        XCTAssertFalse(app.staticTexts["Collections"].exists)

        let previews = app.descendants(matching: .any).matching(
            NSPredicate(
                format: "identifier BEGINSWITH %@",
                "progress-trophy-preview-"
            )
        )
        XCTAssertEqual(previews.count, 3)
        XCTAssertTrue(app.buttons["progress-trophies-all"].isHittable)

        XCTAssertTrue(
            app.otherElements["progress-lifetime-widget"].exists
        )
        for metric in [
            "runs", "endlessWaves", "targets", "bosses",
            "bestCombo", "runTokens", "upgrades", "abilityDefeats",
        ] {
            XCTAssertTrue(
                app.descendants(matching: .any)[
                    "progress-lifetime-\(metric)"
                ].exists,
                "Missing lifetime metric \(metric)"
            )
        }

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Progress Trophy and Lifetime Widgets"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        app.buttons["progress-trophies-all"].tap()
        let trophies = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "trophy-")
        )
        XCTAssertTrue(trophies.firstMatch.waitForExistence(timeout: 2))
        XCTAssertGreaterThan(trophies.count, 3)
    }

    func testProgressWidgetsRemainUsableAtAccessibilityExtraExtraExtraLarge() {
        let app = XCUIApplication()
        app.launchArguments = [
            "--reset-save", "--screen", "trophies", "--progress-fixtures",
            "--dynamic-type-accessibility-xxxl",
        ]
        app.launch()

        XCTAssertTrue(
            app.otherElements["progress-trophy-widget"]
                .waitForExistence(timeout: 3)
        )
        XCTAssertTrue(app.buttons["progress-trophies-all"].isHittable)

        let topScreenshot = XCTAttachment(screenshot: app.screenshot())
        topScreenshot.name = "Progress Accessibility XXXL Trophies"
        topScreenshot.lifetime = .keepAlways
        add(topScreenshot)

        let finalMetric = app.descendants(matching: .any)[
            "progress-lifetime-abilityDefeats"
        ]
        for _ in 0..<12 {
            if finalMetric.exists, finalMetric.isHittable {
                break
            }
            app.swipeUp()
        }
        XCTAssertTrue(finalMetric.waitForExistence(timeout: 2))
        XCTAssertTrue(finalMetric.isHittable)

        let lifetimeScreenshot = XCTAttachment(screenshot: app.screenshot())
        lifetimeScreenshot.name = "Progress Accessibility XXXL Lifetime"
        lifetimeScreenshot.lifetime = .keepAlways
        add(lifetimeScreenshot)
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

    func testCampaignLevelShowsBriefingBeforeLaunch() {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-save", "--screen", "levels"]
        app.launch()

        XCTAssertFalse(app.buttons["briefing-start"].exists)
        XCTAssertTrue(app.buttons["planet-earth"].waitForExistence(timeout: 3))
        app.buttons["planet-earth"].tap()
        let lockedLevel = app.buttons["level-2"]
        XCTAssertTrue(lockedLevel.waitForExistence(timeout: 2))
        XCTAssertTrue(
            lockedLevel.label.localizedCaseInsensitiveContains("locked"),
            "Unexpected locked level label: \(lockedLevel.label)"
        )
        app.buttons["level-1"].tap()
        XCTAssertTrue(app.buttons["briefing-start"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["pause"].isHittable)
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

    func testEndlessHubKeepsEquippedRelicOnlyOnRelicsScreen() {
        let app = XCUIApplication()
        app.launchArguments = [
            "--reset-save", "--screen", "endless", "--relic-fixtures",
        ]
        app.launch()

        XCTAssertTrue(app.buttons["start-endless"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.otherElements["equipped-relic"].exists)
        XCTAssertFalse(app.buttons["manage-relics"].exists)
        XCTAssertFalse(app.staticTexts["Equipped Relic"].exists)

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Endless Hub Without Equipped Relic"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    func testRecoveredEndlessRunKeepsItsOriginalRelicSnapshot() {
        let app = XCUIApplication()
        app.launchArguments = [
            "--reset-save", "--endless", "--relic-fixtures",
            "--run-checkpoint-preview", "--fixed-seed", "42",
        ]
        app.launch()

        XCTAssertTrue(app.otherElements["run-checkpoint-offer"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.otherElements["run-checkpoint-relic"].exists)
        XCTAssertTrue(app.buttons["run-checkpoint-continue"].isHittable)
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

    func testEndlessHeaderCentersLiveScoreBetweenStaminaAndTokens() {
        let app = XCUIApplication()
        app.launchArguments = [
            "--reset-save", "--endless", "--fixed-seed", "42"
        ]
        app.launch()

        let ability = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "ability-")
        ).firstMatch
        XCTAssertTrue(ability.waitForExistence(timeout: 3))
        ability.tap()

        let stamina = app.otherElements["stamina-meter"]
        let score = app.otherElements["endless-live-score"]
        let tokens = app.otherElements["training-token-counter"]
        XCTAssertTrue(score.waitForExistence(timeout: 3))
        XCTAssertEqual(score.label, "Score 0")
        XCTAssertTrue(stamina.exists)
        XCTAssertTrue(tokens.exists)
        XCTAssertGreaterThan(score.frame.minX, stamina.frame.maxX)
        XCTAssertLessThan(score.frame.maxX, tokens.frame.minX)

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Endless Header With Live Score"
        screenshot.lifetime = .keepAlways
        add(screenshot)
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
        app.launchArguments = [
            "--reset-save", "--screen", "result-endless",
            "--rewarded-ad-stub",
        ]
        app.launch()
        XCTAssertTrue(app.staticTexts["result-new-best"].waitForExistence(timeout: 3)
                      || app.otherElements["result-new-best"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["result-relic-found"].exists)
        XCTAssertTrue(app.otherElements["result-relic-summary"].exists)
        XCTAssertFalse(app.buttons["result-relic-equip"].exists)
        XCTAssertTrue(app.buttons["result-primary"].waitForExistence(timeout: 2))
        assertRewardButtonIsRightOfTokens(in: app)
    }

    func testEndlessDeathShowsRelicRevealBeforeCompactResult() {
        let app = XCUIApplication()
        app.launchArguments = [
            "--reset-save", "--endless", "--endless-wave", "12",
            "--death-save-preview", "--disable-ads",
        ]
        app.launch()

        XCTAssertTrue(
            app.otherElements["death-save-offer"].waitForExistence(timeout: 4)
        )
        app.buttons["death-save-decline"].tap()

        let reveal = app.otherElements["relic-drop-reveal"]
        XCTAssertTrue(reveal.waitForExistence(timeout: 4))
        XCTAssertFalse(app.staticTexts["result-title"].exists)

        let skip = app.buttons["relic-drop-skip"]
        if skip.waitForExistence(timeout: 1) {
            skip.tap()
        }

        XCTAssertTrue(
            app.staticTexts["relic-drop-name"].waitForExistence(timeout: 3)
        )
        let continueButton = app.buttons["relic-drop-continue"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 3))
        continueButton.tap()

        let title = app.staticTexts["result-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 4))
        XCTAssertEqual(title.label, "Wave 12")
        XCTAssertTrue(app.otherElements["result-stats"].exists)
        XCTAssertTrue(app.otherElements["result-wave"].exists)
        XCTAssertTrue(app.otherElements["result-score"].exists)
        XCTAssertTrue(app.otherElements["result-best"].exists)
        XCTAssertTrue(app.otherElements["result-relic-summary"].exists)
        XCTAssertFalse(app.buttons["result-relic-equip"].exists)
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

    func testRewardedAdGrantsHalfTheDisplayedCampaignTokens() {
        let app = XCUIApplication()
        app.launchArguments = [
            "--reset-save", "--screen", "result-world", "--rewarded-ad-stub",
        ]
        app.launch()

        let reward = app.buttons["rewarded-token-bonus"]
        XCTAssertTrue(reward.waitForExistence(timeout: 3))
        assertRewardButtonIsRightOfTokens(in: app)
        XCTAssertEqual(reward.label, "Watch video ad")
        XCTAssertTrue(String(describing: reward.value).contains("50 percent"))
        reward.tap()

        let claimed = app.descendants(matching: .any)["rewarded-token-bonus-claimed"]
        XCTAssertTrue(claimed.waitForExistence(timeout: 2))
        XCTAssertEqual(claimed.label, "50 percent token bonus added")
        XCTAssertFalse(reward.exists)
    }

    private func assertRewardButtonIsRightOfTokens(in app: XCUIApplication) {
        let tokens = app.otherElements["result-tokens"]
        let reward = app.buttons["rewarded-token-bonus"]
        XCTAssertTrue(tokens.waitForExistence(timeout: 3))
        XCTAssertTrue(reward.waitForExistence(timeout: 3))
        XCTAssertGreaterThan(reward.frame.minX, tokens.frame.maxX)
        XCTAssertLessThan(abs(reward.frame.midY - tokens.frame.midY), 2)
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

    func testCampaignDeathSaveDeclineShowsFinalLossAndTokenReward() {
        let app = XCUIApplication()
        app.launchArguments = [
            "--reset-save", "--level", "1", "--death-save-preview",
            "--rewarded-ad-stub",
        ]
        app.launch()

        XCTAssertTrue(
            app.otherElements["death-save-offer"].waitForExistence(timeout: 3)
        )
        XCTAssertTrue(app.buttons["death-save-watch"].exists)
        let decline = app.buttons["death-save-decline"]
        XCTAssertTrue(decline.exists)
        XCTAssertEqual(decline.label, "Let Me Die")

        decline.tap()

        let title = app.staticTexts["result-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 3))
        XCTAssertEqual(title.label, "GAME OVER")
        XCTAssertTrue(
            app.buttons["rewarded-token-bonus"].waitForExistence(timeout: 2)
        )
    }

    func testEndlessRewardedDeathSaveContinuesTheRun() {
        verifyRewardedDeathSaveContinues(modeArguments: ["--endless"])
    }

    func testCampaignRewardedDeathSaveContinuesTheRun() {
        verifyRewardedDeathSaveContinues(modeArguments: ["--level", "1"])
    }

    func testEndlessFailureCanRetryRepeatedlyWithoutTerminating() {
        verifyRepeatedFailureRetries(modeArguments: ["--endless"])
    }

    func testCampaignFailureCanRetryRepeatedlyWithoutTerminating() {
        verifyRepeatedFailureRetries(modeArguments: ["--level", "1"])
    }

    func testEndlessPauseCanRetryRepeatedlyWithoutTerminating() {
        verifyRepeatedPauseRetries(modeArguments: ["--endless"])
    }

    func testCampaignPauseCanRetryRepeatedlyWithoutTerminating() {
        verifyRepeatedPauseRetries(modeArguments: ["--level", "1"])
    }

    func testEndlessResultExposesOnlyRelicsEndlessAndHomeDestinations() {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-save", "--screen", "result-endless"]
        app.launch()

        XCTAssertTrue(app.buttons["result-primary"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.buttons["result-primary"].label, "Retry")
        XCTAssertTrue(app.buttons["result-more-relics"].exists)
        XCTAssertTrue(app.buttons["result-more-map"].exists)
        XCTAssertTrue(app.buttons["result-more-home"].exists)
        XCTAssertFalse(app.buttons["result-more-characters"].exists)
        XCTAssertFalse(app.buttons["result-more"].exists)
        XCTAssertFalse(app.otherElements["result-more-actions"].exists)

        app.buttons["result-more-relics"].tap()
        XCTAssertTrue(app.staticTexts["Inventory"].waitForExistence(timeout: 2))

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

    private func verifyRepeatedFailureRetries(modeArguments: [String]) {
        let app = XCUIApplication()
        app.launchArguments = [
            "--reset-save", "--death-save-preview", "--disable-ads",
        ] + modeArguments
        app.launch()

        for attempt in 1...4 {
            let offer = app.otherElements["death-save-offer"]
            XCTAssertTrue(
                offer.waitForExistence(timeout: 4),
                "Death-save offer was missing on attempt \(attempt)"
            )
            app.buttons["death-save-decline"].tap()

            let retry = app.buttons["result-primary"]
            XCTAssertTrue(
                retry.waitForExistence(timeout: 4),
                "Result retry was missing on attempt \(attempt)"
            )
            XCTAssertEqual(retry.label, "Retry")
            XCTAssertEqual(
                app.state,
                .runningForeground,
                "The app terminated after failure \(attempt)"
            )
            retry.tap()
        }

        XCTAssertTrue(
            app.otherElements["death-save-offer"].waitForExistence(timeout: 4)
        )
        XCTAssertEqual(app.state, .runningForeground)
    }

    private func verifyRewardedDeathSaveContinues(
        modeArguments: [String]
    ) {
        let app = XCUIApplication()
        app.launchArguments = [
            "--reset-save", "--death-save-preview",
            "--rewarded-ad-stub", "--gameplay-runtime-probe",
        ] + modeArguments
        app.launch()

        let continueButton = app.buttons["death-save-watch"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 3))
        XCTAssertEqual(continueButton.label, "Watch Ad & Continue")
        continueButton.tap()

        let countdown = app.otherElements["death-save-countdown"]
        XCTAssertTrue(countdown.waitForExistence(timeout: 2))
        XCTAssertTrue(countdown.label.contains("Resuming in"))
        XCTAssertFalse(app.buttons["pause"].isHittable)
        XCTAssertFalse(app.otherElements["death-save-offer"].exists)

        let countdownFinished = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: countdown
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [countdownFinished], timeout: 4),
            .completed,
            "The recovery countdown did not complete after three seconds."
        )
        XCTAssertTrue(app.buttons["pause"].isHittable)

        let runtimeProbe =
            app.descendants(matching: .any)["gameplay-runtime-probe"]
        XCTAssertTrue(runtimeProbe.waitForExistence(timeout: 2))
        let simulationAdvanced = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value != %@", "0"),
            object: runtimeProbe
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [simulationAdvanced], timeout: 3),
            .completed,
            "The simulation remained paused after the rewarded continue."
        )
    }

    private func verifyRepeatedPauseRetries(modeArguments: [String]) {
        let app = XCUIApplication()
        app.launchArguments = [
            "--reset-save", "--auto-kick-off", "--disable-ads",
        ] + modeArguments
        app.launch()

        for attempt in 1...4 {
            let pause = app.buttons["pause"]
            XCTAssertTrue(
                pause.waitForExistence(timeout: 4),
                "Gameplay did not restart on attempt \(attempt)"
            )
            pause.tap()

            let retry = app.buttons["pause-retry"]
            XCTAssertTrue(retry.waitForExistence(timeout: 2))
            retry.tap()
            XCTAssertEqual(
                app.state,
                .runningForeground,
                "The app terminated after pause retry \(attempt)"
            )
        }

        XCTAssertTrue(app.buttons["pause"].waitForExistence(timeout: 4))
        XCTAssertEqual(app.state, .runningForeground)
    }
}
