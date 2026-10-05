import SwiftUI
import CounterKit

struct ContentView: View {
    @State private var counter = Counter()

    var body: some View {
        VStack(spacing: 24) {
            Text("Hello from Linux")
                .font(.title)
            Text("\(counter.value)")
                .font(.system(size: 64, weight: .bold, design: .rounded))
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
    }
}

#Preview {
    ContentView()
}
