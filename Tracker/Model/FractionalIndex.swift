import Foundation

// MARK: - Protocol

/// Any Core Data entity (or plain object) that participates in fractional-index ordering.
protocol Orderable: AnyObject {
    var order: String? { get set }
}

// MARK: - Fractional Indexing

/// String-based fractional indexing so reordering touches only the moved item (O(1)).
/// Keys sort lexicographically; no rebalancing required.
enum FractionalIndex {

    /// Base-62 digit set: 0-9, A-Z, a-z. Lexicographic order = sort order.
    private static let digits = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz")
    private static let digitCount = digits.count
    private static let firstDigit = digits[0]
    private static let lastDigit = digits[digitCount - 1]
    /// Default first key when list is empty.
    private static let defaultStart = "a0"

    // MARK: - Public API

    /// Returns a key that sorts strictly between `a` and `b`.
    /// - Parameters:
    ///   - a: Key before (nil = start of list).
    ///   - b: Key after (nil = end of list).
    /// - Returns: A key such that (a ?? "") < result < (b ?? "").
    static func generateKeyBetween(a: String?, b: String?) -> String {
        let a = a ?? ""
        let b = b ?? ""

        if a.isEmpty && b.isEmpty { return defaultStart }
        if a.isEmpty { return keyBefore(b) }
        if b.isEmpty { return keyAfter(a) }
        if a >= b { return keyAfter(a) }

        var result: [Character] = []
        var i = 0
        while i < a.count {
            guard i < b.count else { break }
            let ca = a[a.index(a.startIndex, offsetBy: i)]
            let cb = b[b.index(b.startIndex, offsetBy: i)]
            if ca == cb {
                result.append(ca)
                i += 1
                continue
            }
            let idxA = digits.firstIndex(of: ca) ?? 0
            let idxB = digits.firstIndex(of: cb) ?? digitCount
            if idxB - idxA > 1 {
                let mid = idxA + (idxB - idxA) / 2
                result.append(digits[mid])
                return String(result)
            }
            if idxB - idxA == 1 {
                result.append(ca)
                let rest = keyAfter(String(a.dropFirst(i + 1)))
                return String(result) + rest
            }
            result.append(ca)
            i += 1
        }
        if i < b.count {
            let cb = b[b.index(b.startIndex, offsetBy: i)]
            let idxB = digits.firstIndex(of: cb) ?? 0
            if idxB > 0 {
                result.append(digits[(idxB - 1) / 2])
                return String(result)
            }
            result.append(cb)
            let rest = keyBefore(String(b.dropFirst(i + 1)))
            return String(result) + rest
        }
        return keyAfter(a)
    }

    /// Returns the key for a new item after the last in the list.
    static func nextKey<T: Orderable>(after items: [T]) -> String {
        let sorted = items.compactMap(\.order).sorted { $0.compare($1, options: .literal) == .orderedAscending }
        let last = sorted.last
        return generateKeyBetween(a: last, b: nil)
    }

    /// After a drag-and-drop reorder, updates only the moved item's order.
    /// `items` must already be in the desired final order.
    static func applyReorder<T: Orderable>(_ items: [T]) {
        guard items.count > 1 else { return }

        let orders = items.map { $0.order ?? "" }
        if isMonotonicallyIncreasing(orders) { return }

        guard let movedIndex = findMovedItemIndex(orders: orders) else { return }
        let before = movedIndex > 0 ? (items[movedIndex - 1].order ?? "") : nil
        let after = movedIndex < items.count - 1 ? (items[movedIndex + 1].order ?? "") : nil
        let newKey = generateKeyBetween(a: before, b: after)
        items[movedIndex].order = newKey
    }

    // MARK: - Helpers

    private static func keyBefore(_ key: String) -> String {
        guard !key.isEmpty else { return String(lastDigit) }
        let first = key.first!
        guard let idx = digits.firstIndex(of: first), idx > 0 else {
            return String(first) + keyBefore(String(key.dropFirst()))
        }
        return String(digits[idx - 1]) + String(repeating: lastDigit, count: key.count - 1)
    }

    private static func keyAfter(_ key: String) -> String {
        guard !key.isEmpty else { return defaultStart }
        let last = key.last!
        guard let idx = digits.firstIndex(of: last), idx < digitCount - 1 else {
            return key + String(firstDigit)
        }
        let mid = idx + (digitCount - 1 - idx) / 2
        return String(key.dropLast()) + String(digits[mid])
    }

    private static func isMonotonicallyIncreasing(_ orders: [String]) -> Bool {
        for i in 1..<orders.count {
            if orders[i].compare(orders[i - 1], options: .literal) != .orderedDescending {
                return false
            }
        }
        return true
    }

    /// Finds the single index such that removing it leaves the rest in ascending order.
    private static func findMovedItemIndex(orders: [String]) -> Int? {
        for candidate in 0..<orders.count {
            var remaining = orders
            remaining.remove(at: candidate)
            let sorted = remaining.sorted { $0.compare($1, options: .literal) == .orderedAscending }
            if remaining.elementsEqual(sorted) { return candidate }
        }
        return nil
    }
}
