import Foundation

extension Sequence {
    func paired() -> some Sequence<(Element, Element)> {
        zip(self, dropFirst())
    }

    func wrappedPairs() -> [(Element, Element)] {
        .init(zip(self, dropFirst() + Array(prefix(1))))
    }

    func reduce(_ function: (Element, Element) -> Element) -> Element? {
        reduce(nil as Element?) { output, input in
            output.map { function($0, input) } ?? input
        }
    }
}

extension Sequence {
    func sum<Value: AdditiveArithmetic>(_ accessor: (Element) -> Value) -> Value {
        map(accessor).reduce(Value.zero, +)
    }
}

extension Sequence where Element: AdditiveArithmetic {
    func sum() -> Element {
        reduce(.zero, +)
    }
}

extension Collection where Element: Sendable {
    func wrappedTriplets() -> [(Element, Element, Element)] where Index == Int {
        let n = count
        return (0..<n).map { i in
            (self[i], self[(i + 1) % n], self[(i + 2) % n])
        }
    }
}

extension Sequence where Element: Sendable {
    func asyncMap<T: Sendable>(_ transform: @Sendable @escaping (Element) async throws -> T) async rethrows -> [T] {
        try await withThrowingTaskGroup(of: (Int, T).self) { group in
            var count = 0
            for (index, element) in self.enumerated() {
                group.addTask {
                    let value = try await transform(element)
                    return (index, value)
                }
                count += 1
            }

            var results = Array<T?>(repeating: nil, count: count)
            for try await (index, result) in group {
                results[index] = result
            }

            return results.map { $0! }
        }
    }

    func asyncCompactMap<T: Sendable>(_ transform: @Sendable @escaping (Element) async throws -> T?) async rethrows -> [T] {
        try await withThrowingTaskGroup(of: (Int, T?).self) { group in
            var count = 0
            for (index, element) in self.enumerated() {
                group.addTask {
                    let value = try await transform(element)
                    return (index, value)
                }
                count += 1
            }

            var results = Array<T?>(repeating: nil, count: count)
            for try await (index, result) in group {
                results[index] = result
            }

            return results.compactMap { $0 }
        }
    }
}

extension Collection where Element: Comparable {
    var isSortedNondecreasing: Bool { zip(self, dropFirst()).allSatisfy(<=) }
}

extension BidirectionalCollection where Index == Int {
    func binarySearchInterpolate<V: Vector>(key: Double) -> V where Element == (Double, V) {
        precondition(!isEmpty, "Array must not be empty")

        guard key > self.first!.0 else { return self.first!.1 }
        guard key < self.last!.0 else { return self.last!.1 }

        // Binary search for the correct interval
        var low = 0
        var high = self.count - 1

        while low <= high {
            let mid = (low + high) / 2
            let midKey = self[mid].0

            if midKey < key {
                low = mid + 1
            } else {
                high = mid - 1
            }
        }

        let (k0, v0) = self[high]
        let (k1, v1) = self[low]
        guard k1 - k0 != 0 else { return v0 }
        return v0 + (v1 - v0) * (key - k0) / (k1 - k0)
    }

    func binarySearchInterpolate<Result: LinearInterpolation>(
        target: Double,
        key: (Element) -> Double,
        result: (Element) -> Result
    ) -> Result {
        precondition(!isEmpty, "Array must not be empty")

        guard target > key(self.first!) else { return result(self.first!) }
        guard target < key(self.last!) else { return result(self.last!) }

        // Binary search for the correct interval
        var low = 0
        var high = self.count - 1

        while low <= high {
            let mid = (low + high) / 2
            let midKey = key(self[mid])

            if midKey < target {
                low = mid + 1
            } else {
                high = mid - 1
            }
        }

        let k0 = key(self[high]), k1 = key(self[low])
        guard k1 - k0 != 0 else { return result(self[high]) }

        return Result.linearInterpolation(result(self[high]), result(self[low]), factor: (target - k0) / (k1 - k0))
    }

    func binarySearch<Key: FloatingPoint>(target: Key, key: (Element) -> Key) -> (Index, fraction: Key) {
        precondition(!isEmpty, "Array must not be empty")

        guard target > key(self.first!) else { return (0, 0) }
        guard target < key(self.last!) else { return (count - 1, 0) }

        // Binary search for the correct interval
        var low = 0
        var high = self.count - 1

        while low <= high {
            let mid = (low + high) / 2
            let midKey = key(self[mid])

            if midKey < target {
                low = mid + 1
            } else {
                high = mid - 1
            }
        }

        let k0 = key(self[high]), k1 = key(self[low])
        guard k1 - k0 != 0 else { return (high, 0) }
        return (high, (target - k0) / (k1 - k0))
    }
}

extension Collection where Index == Int {
    subscript(wrap index: Int) -> Element {
        let m = index % count
        return self[m >= 0 ? m : m + count]
    }
}
