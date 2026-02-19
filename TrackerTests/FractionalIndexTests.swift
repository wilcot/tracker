import XCTest
@testable import Tracker

private final class MockOrderable: Orderable {
    var order: String?
    init(order: String?) { self.order = order }
}

final class FractionalIndexTests: XCTestCase {

    // MARK: - generateKeyBetween

    func testGenerateKeyBetween_nilNil_returnsDefaultStart() {
        let key = FractionalIndex.generateKeyBetween(a: nil, b: nil)
        XCTAssertEqual(key, "a0")
    }

    func testGenerateKeyBetween_nilAfter_returnsKeyBefore() {
        let key = FractionalIndex.generateKeyBetween(a: nil, b: "a0")
        XCTAssertTrue(key.compare("a0", options: .literal) == .orderedAscending)
    }

    func testGenerateKeyBetween_beforeNil_returnsKeyAfter() {
        let key = FractionalIndex.generateKeyBetween(a: "a0", b: nil)
        XCTAssertTrue(key.compare("a0", options: .literal) == .orderedDescending)
    }

    func testGenerateKeyBetween_bothPresent_returnsKeyBetween() {
        let key = FractionalIndex.generateKeyBetween(a: "a0", b: "a1")
        XCTAssertTrue(key.compare("a0", options: .literal) == .orderedDescending)
        XCTAssertTrue(key.compare("a1", options: .literal) == .orderedAscending)
    }

    func testGenerateKeyBetween_lexicographicOrder() {
        let k1 = FractionalIndex.generateKeyBetween(a: nil, b: nil)
        let k2 = FractionalIndex.generateKeyBetween(a: k1, b: nil)
        let k3 = FractionalIndex.generateKeyBetween(a: k2, b: nil)
        XCTAssertTrue(k1.compare(k2, options: .literal) == .orderedAscending)
        XCTAssertTrue(k2.compare(k3, options: .literal) == .orderedAscending)
    }

    // MARK: - nextKey

    func testNextKey_emptyList_returnsDefaultStart() {
        let items: [MockOrderable] = []
        XCTAssertEqual(FractionalIndex.nextKey(after: items), "a0")
    }

    func testNextKey_existingItems_returnsKeyAfterLast() {
        let items = [
            MockOrderable(order: "a0"),
            MockOrderable(order: "a1"),
            MockOrderable(order: "a2")
        ]
        let key = FractionalIndex.nextKey(after: items)
        XCTAssertTrue(key.compare("a2", options: .literal) == .orderedDescending)
    }

    // MARK: - applyReorder — already ordered (no-op)

    func testApplyReorder_alreadyOrdered_doesNotChangeValues() {
        let items = [
            MockOrderable(order: "a0"),
            MockOrderable(order: "a1"),
            MockOrderable(order: "a2")
        ]
        let original = items.map { $0.order }

        FractionalIndex.applyReorder(items)

        XCTAssertEqual(items.map { $0.order }, original)
    }

    // MARK: - applyReorder — single move

    func testApplyReorder_moveMiddleToFirst_onlyMovedItemChanges() {
        let a = MockOrderable(order: "a0")
        let b = MockOrderable(order: "a1")
        let c = MockOrderable(order: "a2")
        let items = [c, a, b]

        FractionalIndex.applyReorder(items)

        XCTAssertTrue((c.order ?? "").compare(a.order ?? "", options: .literal) == .orderedAscending)
        XCTAssertEqual(a.order, "a0")
        XCTAssertEqual(b.order, "a1")
        let orders = items.map { $0.order ?? "" }
        XCTAssertTrue(orders.sorted(by: { $0.compare($1, options: .literal) == .orderedAscending }) == orders)
    }

    func testApplyReorder_moveFirstToLast_onlyMovedItemChanges() {
        let a = MockOrderable(order: "a0")
        let b = MockOrderable(order: "a1")
        let c = MockOrderable(order: "a2")
        let items = [b, c, a]

        FractionalIndex.applyReorder(items)

        XCTAssertTrue((a.order ?? "").compare(c.order ?? "", options: .literal) == .orderedDescending)
        XCTAssertEqual(b.order, "a1")
        XCTAssertEqual(c.order, "a2")
    }

    func testApplyReorder_moveLastToMiddle_onlyMovedItemChanges() {
        let a = MockOrderable(order: "a0")
        let b = MockOrderable(order: "a1")
        let c = MockOrderable(order: "a2")
        let d = MockOrderable(order: "a3")
        let items = [a, d, b, c]

        FractionalIndex.applyReorder(items)

        let dOrder = d.order ?? ""
        XCTAssertTrue(dOrder.compare("a0", options: .literal) == .orderedDescending)
        XCTAssertTrue(dOrder.compare("a1", options: .literal) == .orderedAscending)
        XCTAssertEqual(a.order, "a0")
        XCTAssertEqual(b.order, "a1")
        XCTAssertEqual(c.order, "a2")
    }

    func testApplyReorder_singleItem_doesNotCrash() {
        let items = [MockOrderable(order: "a0")]
        FractionalIndex.applyReorder(items)
        XCTAssertEqual(items[0].order, "a0")
    }

    func testApplyReorder_twoItems_swap() {
        let a = MockOrderable(order: "a0")
        let b = MockOrderable(order: "a1")
        let items = [b, a]

        FractionalIndex.applyReorder(items)

        XCTAssertTrue((b.order ?? "").compare(a.order ?? "", options: .literal) == .orderedAscending)
        XCTAssertEqual(a.order, "a0")
    }
}
