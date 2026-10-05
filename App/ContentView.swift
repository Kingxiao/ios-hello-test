import SwiftUI
import CounterKit

struct ContentView: View {
    static let storageKey = "counterValue"

    @AppStorage(storageKey) private var storedValue = 0
    // 随系统字号缩放，满足 Dynamic Type
    @ScaledMetric(relativeTo: .largeTitle) private var counterSize: CGFloat = 64
    @State private var counter = Counter()

    var body: some View {
        GeometryReader { geo in
            // 大字号或小屏时可滚动，避免内容被裁切
            ScrollView {
                VStack(spacing: 24) {
                    Text("Hello from Linux")
                        .font(.title)
                        .accessibilityIdentifier("title")
                    Text("A counter built on Linux and compiled in the cloud.")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("\(counter.value)")
                        .font(.system(size: counterSize, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .accessibilityIdentifier("counterValue")
                    // 横排放不下时改竖排
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 16) { buttons }
                        VStack(spacing: 12) { buttons }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .frame(maxWidth: .infinity, minHeight: geo.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .onAppear { counter = Counter(value: storedValue) }
        .onChange(of: counter.value) { _, newValue in storedValue = newValue }
    }

    @ViewBuilder private var buttons: some View {
        Button("−") { counter.decrement() }
            .accessibilityLabel("Decrease")
            .accessibilityIdentifier("decrement")
        Button("+") { counter.increment() }
            .accessibilityLabel("Increase")
            .accessibilityIdentifier("increment")
        Button("Reset") { counter.reset() }
            .accessibilityIdentifier("reset")
    }
}

#Preview {
    ContentView()
}
