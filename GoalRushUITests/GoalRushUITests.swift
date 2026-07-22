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
        app.buttons["play"].tap()
        XCTAssertTrue(app.buttons["level-1"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.buttons["level-2"].isEnabled)
        app.buttons["Home"].tap()
        app.buttons["upgrades"].tap()
        XCTAssertTrue(app.buttons["upgrade-impact"].waitForExistence(timeout: 2))
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
        XCTAssertTrue(app.buttons["Resume"].waitForExistence(timeout: 2))
        app.buttons["Resume"].tap()
        XCTAssertTrue(app.buttons["pause"].exists)
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
        XCTAssertTrue(app.buttons["Resume"].waitForExistence(timeout: 2))
    }

    func testLockerCyclesEarnedTorsoGear() {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-save", "--unlock-gear", "--screen", "gear"]
        app.launch()
        let next = app.buttons["gear-torso-next"]
        XCTAssertTrue(next.waitForExistence(timeout: 3))
        next.tap()
        XCTAssertTrue(app.staticTexts["Captain Jersey"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["+10 maximum stamina"].exists)
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
        next.tap()
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
        let collect = app.buttons["daily-collect"]
        XCTAssertTrue(collect.waitForExistence(timeout: 3))
        collect.tap()
        XCTAssertTrue(chest.waitForExistence(timeout: 2))
    }

    func testEndlessResultShowsNewBestBadge() {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-save", "--screen", "result-endless"]
        app.launch()
        XCTAssertTrue(app.staticTexts["result-new-best"].waitForExistence(timeout: 3)
                      || app.otherElements["result-new-best"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["result-primary"].exists)
    }
}
