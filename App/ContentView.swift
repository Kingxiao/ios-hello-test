import SwiftUI
import CounterKit

struct ContentView: View {
    static let storageKey = "counterValue"

    @AppStorage(storageKey) private var storedValue = 0
    // 随系统字号缩放，满足 Dynamic Type
    @ScaledMetric(relativeTo: .largeTitle) private var counterSize: CGFloat = 64
    @State private var counter = Counter()

    var body: some View {
        VStack(spacing: 24) {
            Text("Hello from Linux")
                .font(.title)
                .accessibilityIdentifier("title")
            Text("A counter built on Linux and compiled in the cloud.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Text("\(counter.value)")
                .font(.system(size: counterSize, weight: .bold, design: .rounded))
                .monospacedDigit()
                .accessibilityIdentifier("counterValue")
            HStack(spacing: 16) {
                Button("−") { counter.decrement() }
                    .accessibilityIdentifier("decrement")
                Button("+") { counter.increment() }
                    .accessibilityIdentifier("increment")
                Button("Reset") { counter.reset() }
                    .accessibilityIdentifier("reset")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .onAppear { counter = Counter(value: storedValue) }
        .onChange(of: counter.value) { _, newValue in storedValue = newValue }
    }
}

#Preview {
    ContentView()
}
