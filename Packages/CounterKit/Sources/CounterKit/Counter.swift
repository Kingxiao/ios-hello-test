/// 与平台无关的业务逻辑，可在 Linux 上用 `swift test` 验证。
public struct Counter: Equatable, Sendable {
    public private(set) var value: Int
    public let range: ClosedRange<Int>

    public init(value: Int = 0, range: ClosedRange<Int> = 0...99) {
        self.range = range
        self.value = min(max(value, range.lowerBound), range.upperBound)
    }

    public mutating func increment() {
        if value < range.upperBound { value += 1 }
    }

    public mutating func decrement() {
        if value > range.lowerBound { value -= 1 }
    }

    public mutating func reset() {
        value = range.lowerBound
    }
}
