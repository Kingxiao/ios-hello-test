import XCTest

final class HelloAppUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// 截图名前缀，由 CI 通过 TEST_RUNNER_SHOT_PREFIX 传入，如 "iPhone-SE-dark"
    private var shotPrefix: String {
        ProcessInfo.processInfo.environment["SHOT_PREFIX"] ?? "local"
    }

    @MainActor
    private func launch(language: String = "en", contentSize: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestReset", "-AppleLanguages", "(\(language))", "-AppleLocale", language]
        if let contentSize {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", contentSize]
        }
        app.launch()
        return app
    }

    /// 核心交互：加减、重置、下限、持久化
    @MainActor
    func testCounterFlow() {
        var app = launch()
        let value = app.staticTexts["counterValue"]
        XCTAssertTrue(value.waitForExistence(timeout: 10))
        XCTAssertEqual(value.label, "0")

        for _ in 0..<3 { app.buttons["increment"].tap() }
        XCTAssertEqual(value.label, "3")
        app.buttons["decrement"].tap()
        XCTAssertEqual(value.label, "2")
        app.buttons["reset"].tap()
        app.buttons["decrement"].tap()
        XCTAssertEqual(value.label, "0")

        // 持久化：改成 5，不带重置参数重启，值应保留
        for _ in 0..<5 { app.buttons["increment"].tap() }
        app.terminate()
        app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["counterValue"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["counterValue"].label, "5")
    }

    /// 语言 × 字号 截图；深浅色由 CI 在外层切换
    @MainActor
    func testScreenshotMatrix() {
        let sizes: [(String, String?)] = [("default", nil), ("ax-xxxl", "UICTContentSizeCategoryAccessibilityXXXL")]
        let titles = ["en": "Hello from Linux", "zh-Hans": "来自 Linux 的问候"]
        for (language, title) in titles.sorted(by: { $0.key < $1.key }) {
            for (sizeName, size) in sizes {
                let app = launch(language: language, contentSize: size)
                let titleText = app.staticTexts["title"]
                XCTAssertTrue(titleText.waitForExistence(timeout: 10))
                XCTAssertEqual(titleText.label, title, "\(language) 本地化未生效")
                app.buttons["increment"].tap()
                app.buttons["increment"].tap()
                // 大字号下按钮必须仍在屏幕内、可点
                XCTAssertTrue(app.buttons["reset"].isHittable, "\(language)/\(sizeName) Reset 按钮不可点")
                snapshot("\(shotPrefix)-\(language)-\(sizeName)")
                app.terminate()
            }
        }
    }

    /// 苹果自带无障碍审计：对比度、元素标签、点击区域、动态字体等
    @MainActor
    func testAccessibilityAudit() throws {
        let app = launch()
        XCTAssertTrue(app.staticTexts["counterValue"].waitForExistence(timeout: 10))
        try app.performAccessibilityAudit()
    }

    @MainActor
    private func snapshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
