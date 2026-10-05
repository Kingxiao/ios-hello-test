import XCTest

final class HelloAppUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testCounterFlow() {
        let app = XCUIApplication()
        app.launch()

        let value = app.staticTexts["counterValue"]
        XCTAssertTrue(value.waitForExistence(timeout: 10))
        XCTAssertEqual(value.label, "0")
        snapshot("01-launch")

        for _ in 0..<3 { app.buttons["increment"].tap() }
        XCTAssertEqual(value.label, "3")
        snapshot("02-plus-3")

        app.buttons["decrement"].tap()
        XCTAssertEqual(value.label, "2")
        snapshot("03-minus-1")

        app.buttons["reset"].tap()
        XCTAssertEqual(value.label, "0")

        // 下限不越界
        app.buttons["decrement"].tap()
        XCTAssertEqual(value.label, "0")
        snapshot("04-reset-and-floor")
    }

    @MainActor
    private func snapshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
