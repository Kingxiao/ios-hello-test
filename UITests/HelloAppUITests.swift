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
        snapshot("\(shotPrefix)-flow-01-launch")

        for expected in 1...3 {
            tapButton("increment", in: app)
            XCTAssertEqual(value.label, "\(expected)")
        }
        XCTAssertEqual(value.label, "3")
        snapshot("\(shotPrefix)-flow-02-increment")
        tapButton("decrement", in: app)
        XCTAssertEqual(value.label, "2")
        snapshot("\(shotPrefix)-flow-03-decrement")
        tapButton("reset", in: app)
        XCTAssertEqual(value.label, "0")
        snapshot("\(shotPrefix)-flow-04-reset")
        tapButton("decrement", in: app)
        XCTAssertEqual(value.label, "0")
        snapshot("\(shotPrefix)-flow-05-floor")

        // 持久化：改成 5，不带重置参数重启，值应保留
        for expected in 1...5 {
            tapButton("increment", in: app)
            XCTAssertEqual(value.label, "\(expected)")
        }
        app.terminate()
        app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["counterValue"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["counterValue"].label, "5")
        snapshot("\(shotPrefix)-flow-06-persistence")
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
                let value = app.staticTexts["counterValue"]
                XCTAssertEqual(value.label, "0")
                tapButton("increment", in: app)
                XCTAssertEqual(value.label, "1")
                tapButton("increment", in: app)
                XCTAssertEqual(value.label, "2")
                // 数值截图和点击检查分别滚动到目标，内容无需挤进同一屏。
                XCTAssertTrue(reveal(value, in: app), "\(language)/\(sizeName) 数值未完整显示")
                snapshot("\(shotPrefix)-\(language)-\(sizeName)-count-2")
                tapButton("reset", in: app)
                XCTAssertEqual(value.label, "0")
                XCTAssertTrue(reveal(value, in: app), "\(language)/\(sizeName) 重置数值未完整显示")
                snapshot("\(shotPrefix)-\(language)-\(sizeName)-reset-0")
                app.terminate()
            }
        }
    }

    /// 不能只检查 isHittable：按钮部分露出时也可能可点击。
    @MainActor
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) -> Bool {
        let scroll = app.scrollViews["counterScroll"]
        guard element.waitForExistence(timeout: 10), scroll.exists else { return false }
        for attempt in 0...8 {
            let viewport = scroll.frame
            let frame = element.frame
            if !frame.isEmpty && viewport.contains(frame) && element.isHittable {
                return true
            }
            if attempt == 8 { break }
            if frame.minY < viewport.minY {
                scroll.swipeDown(velocity: .slow)
            } else {
                scroll.swipeUp(velocity: .slow)
            }
        }
        return false
    }

    @MainActor
    private func tapButton(_ identifier: String, in app: XCUIApplication,
                           file: StaticString = #filePath, line: UInt = #line) {
        let button = app.buttons[identifier]
        guard reveal(button, in: app) else {
            XCTFail("\(identifier) 滚动后仍未完整位于视口内或不可点击", file: file, line: line)
            return
        }
        button.tap()
    }

    /// 苹果自带无障碍审计：对比度、元素标签、点击区域、动态字体等
    /// 收集全部问题再一起报告；审计偶发超时（Code -56）时重试一次
    @MainActor
    func testAccessibilityAudit() throws {
        let app = launch()
        XCTAssertTrue(app.staticTexts["counterValue"].waitForExistence(timeout: 10))
        var issues: [String] = []
        for attempt in 1...2 {
            issues = []
            do {
                try app.performAccessibilityAudit { issue in
                    let el = issue.element
                    issues.append("[\(issue.compactDescription)] id=\(el?.identifier ?? "-") label=\(el?.label ?? "-") type=\(el?.elementType.rawValue ?? 0)")
                    return true
                }
                break
            } catch let error as NSError where error.code == -56 && attempt == 1 {
                continue
            }
        }
        XCTAssertTrue(issues.isEmpty, "无障碍问题：\n" + issues.joined(separator: "\n"))
    }

    @MainActor
    private func snapshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
