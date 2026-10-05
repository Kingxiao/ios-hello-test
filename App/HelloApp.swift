import SwiftUI

@main
struct HelloApp: App {
    init() {
        // UI 测试用：每次启动从干净状态开始
        if CommandLine.arguments.contains("-uiTestReset") {
            UserDefaults.standard.removeObject(forKey: ContentView.storageKey)
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
