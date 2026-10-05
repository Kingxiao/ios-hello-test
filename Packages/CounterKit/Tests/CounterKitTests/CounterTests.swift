import XCTest
@testable import CounterKit

final class CounterTests: XCTestCase {
    func testIncrementStopsAtUpperBound() {
        var c = Counter(value: 98, range: 0...99)
        c.increment()
        c.increment()
        XCTAssertEqual(c.value, 99)
    }

    func testDecrementStopsAtLowerBound() {
        var c = Counter()
        c.decrement()
        XCTAssertEqual(c.value, 0)
    }

    func testInitClampsValue() {
        XCTAssertEqual(Counter(value: 500).value, 99)
    }

    func testReset() {
        var c = Counter(value: 5)
        c.reset()
        XCTAssertEqual(c.value, 0)
    }
}
