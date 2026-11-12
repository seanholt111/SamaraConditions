import XCTest

final class StatesUITests: XCTestCase {
    private let now = "2026-11-11T17:00:00-06:00"

    private func launch(_ extra: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-use-fixture", "-now", now] + extra
        app.launch()
        return app
    }

    func testLoading() {
        let app = launch(["-ui-state", "loading"])
        XCTAssertTrue(app.staticTexts["Getting today's conditions…"].waitForExistence(timeout: 8))
    }

    func testFresh() {
        let app = launch(["-ui-state", "fresh"])
        XCTAssertTrue(app.staticTexts["as of 5:02a"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["27.9°"].exists)
        XCTAssertTrue(app.staticTexts["26.6°"].exists)
    }

    func testStale() {
        let app = launch(["-ui-state", "stale"])
        XCTAssertTrue(app.staticTexts["as of yesterday 5:02a · may be out of date"].waitForExistence(timeout: 8))
    }

    func testStaleTide() {
        let app = launch(["-ui-state", "stale-tide"])
        XCTAssertTrue(app.staticTexts["as of 5:02a"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["Tide · as of yesterday 5:02a"].exists)
    }

    func testOffline() {
        let app = launch(["-ui-state", "offline"])
        XCTAssertTrue(app.staticTexts["Offline · showing 5:02a data"].waitForExistence(timeout: 8))
    }

    func testError() {
        let app = launch(["-ui-state", "error"])
        XCTAssertTrue(app.staticTexts["Couldn't load conditions. Pull to retry."].waitForExistence(timeout: 8))
    }

    func testIMN() {
        let app = launch(["-ui-state", "imn"])
        let banner = app.buttons["imn-banner"]
        XCTAssertTrue(banner.waitForExistence(timeout: 8))
        XCTAssertTrue(banner.label.contains("IMN: EXAMPLE High surf, Puntarenas"))
        XCTAssertTrue(banner.label.contains("official notice"))
    }

    func testTodayBeach() {
        let app = launch(["-ui-state", "fresh", "-activity", "beach"])
        XCTAssertTrue(app.staticTexts["5:50–7:30a"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["Tide · Calm at shore 7:30a–12:40p · Waves normal"].exists)
    }

    func testLowTide() {
        let app = launch(["-ui-state", "fresh", "-activity", "beach", "-low-tide", "1"])
        XCTAssertTrue(app.staticTexts["No window"].waitForExistence(timeout: 8))
    }

    func testWeekSea() {
        let app = launch(["-ui-state", "fresh", "-tab", "week", "-week", "sea"])
        XCTAssertTrue(app.staticTexts["full height = 210 kJ"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["model, not measured · reef size and gaps guessed"].exists)
    }

    func testSources() {
        let app = launch(["-ui-state", "fresh", "-show-sources", "1"])
        let credit = app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Open-Meteo")).firstMatch
        XCTAssertTrue(credit.waitForExistence(timeout: 8))
    }
}
