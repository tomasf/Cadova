import Foundation

extension Sequence {
    func paired() -> [(Element, Element)] {
        .init(zip(self, dropFirst()))
    }

    func wrappedPairs() -> [(Element, Element)] {
        .init(zip(self, dropFirst() + Array(prefix(1))))
    }

    func reduce(_ function: (Element, Element) -> Element) -> Element? {
        reduce(nil as Element?) { output, input in
            output.map { function($0, input) } ?? input
        }
    }

    func cumulativeCombination(_ function: (Element, Element) -> Element) -> [Element] {
        reduce([]) {
            if let last = $0.last { $0 + [function(last, $1)] } else { [$1] }
        }
    }
}

extension Collection where Element: Sendable {
    func wrappedTriplets() -> [(Element, Element, Element)] where Index == Int {
        let n = count
        return (0..<n).map { i in
            (self[i], self[(i + 1) % n], self[(i + 2) % n])
        }
    }

    func asyncMap<T: Sendable>(_ transform: @Sendable @escaping (Element) async throws -> T) async rethrows -> [T] {
        try await withThrowingTaskGroup(of: (Int, T).self) { group in
            for (index, element) in self.enumerated() {
                group.addTask {
                    let value = try await transform(element)
                    return (index, value)
                }
            }

            var results = Array<T?>(repeating: nil, count: self.count)
            for try await (index, result) in group {
                results[index] = result
            }

            return results.map { $0! }
        }
    }

    func asyncCompactMap<T: Sendable>(_ transform: @Sendable @escaping (Element) async throws -> T?) async rethrows -> [T] {
        try await withThrowingTaskGroup(of: (Int, T?).self) { group in
            for (index, element) in self.enumerated() {
                group.addTask {
                    let value = try await transform(element)
                    return (index, value)
                }
            }

            var results = Array<T?>(repeating: nil, count: self.count)
            for try await (index, result) in group {
                results[index] = result
            }

            return results.compactMap { $0 }
        }
    }
}

extension Sequence where Element: Sendable {
    @inlinable
    public func concurrentAsyncForEach(
        _ operation: @Sendable @escaping (Element) async throws -> Void
    ) async rethrows {
        try await withThrowingTaskGroup(of: Void.self) { group in
            for element in self {
                group.addTask {
                    try await operation(element)
                }
            }
            try await group.waitForAll()
        }
    }
}

extension Range {
    init(_ first: Bound, _ second: Bound) {
        self.init(uncheckedBounds: (
            lower: Swift.min(first, second),
            upper: Swift.max(first, second))
        )
    }
}

extension Range where Bound: AdditiveArithmetic {
    var length: Bound { upperBound - lowerBound }
}

extension Range where Bound: FloatingPoint {
    var mid: Bound { (lowerBound + upperBound) / 2 }
}

extension URL {
    init(expandingFilePath path: String, extension requiredExtension: String? = nil, relativeTo: URL? = nil) {
        var url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath, relativeTo: relativeTo)
        if let requiredExtension, url.pathExtension != requiredExtension {
            url.appendPathExtension(requiredExtension)
        }
        self = url
    }

    func withRequiredExtension(_ requiredExtension: String) -> URL {
        pathExtension == requiredExtension ? self : appendingPathExtension(requiredExtension)
    }
}

extension Dictionary {
    func setting(_ key: Key, to value: Value) -> Self {
        var dict = self
        dict[key] = value
        return dict
    }

    init<S: Sequence<Key>>(keys: S, values: (Key) -> Value) {
        self.init(keys.map { ($0, values($0)) }) { $1 }
    }
}

extension RangeExpression {
    var min: Bound? {
        switch self {
        case let self as ClosedRange<Bound>: self.lowerBound
        case let self as Range<Bound>: self.lowerBound
        case let self as PartialRangeFrom<Bound>: self.lowerBound
        default: nil
        }
    }

    var max: Bound? {
        switch self {
        case let self as ClosedRange<Bound>: self.upperBound
        case let self as Range<Bound>: self.upperBound
        case let self as PartialRangeThrough<Bound>: self.upperBound
        case let self as PartialRangeUpTo<Bound>: self.upperBound
        default: nil
        }
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        max(range.lowerBound, min(range.upperBound, self))
    }
}

extension Double {
    var unitClamped: Double {
        clamped(to: 0...1)
    }

    var roundedForHash: Int {
        Int((self * 1000000000.0).rounded())
    }
}

extension Set {
    init(_ sets: Self...) {
        self = sets.reduce([]) { $0.union($1) }
    }

    static func +(lhs: Self, rhs: Element) -> Self {
        lhs.union([rhs])
    }

    static func -(lhs: Self, rhs: Element) -> Self {
        lhs.subtracting([rhs])
    }
}

// Hack until we have a better solution
extension KeyPath: @unchecked @retroactive Sendable {}

extension Clock {
    func measure<T>(work: () async throws -> T, results: (Instant.Duration, T) -> Void) async rethrows -> T {
        var result: T?
        let duration = try await measure {
            result = try await work()
        }
        results(duration, result!)
        return result!
    }
}

func combinations<A, B, C>(_ a: [A], _ b: [B], _ c: [C]) -> [(A, B, C)] {
    var result: [(A, B, C)] = []
    for itemA in a {
        for itemB in b {
            for itemC in c {
                result.append((itemA, itemB, itemC))
            }
        }
    }
    return result
}

func unpacked<A, B, C, D>(_ tuple: (A, (B, C, D))) -> (A, B, C, D) {
    (tuple.0, tuple.1.0, tuple.1.1, tuple.1.2)
}

func unpacked<A, B, C, D>(_ tuple: ((A, B), (C, D))) -> (A, B, C, D) {
    (tuple.0.0, tuple.0.1, tuple.1.0, tuple.1.1)
}

func unpacked<A, B, C>(_ tuple: ((A, B), C)) -> (A, B, C) {
    (tuple.0.0, tuple.0.1, tuple.1)
}

func unpacked<A, B, C>(_ tuple: (A, (B, C))) -> (A, B, C) {
    (tuple.0, tuple.1.0, tuple.1.1)
}
