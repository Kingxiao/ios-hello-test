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
            HStack(spacing: 16) {
                Button("−") { counter.decrement() }
                Button("+") { counter.increment() }
                Button("Reset") { counter.reset() }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
