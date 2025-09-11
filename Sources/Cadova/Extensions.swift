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

extension ClosedRange {
    init(_ first: Bound, _ second: Bound) {
        self.init(uncheckedBounds: (
            lower: Swift.min(first, second),
            upper: Swift.max(first, second))
        )
    }
}

extension ClosedRange where Bound: AdditiveArithmetic {
    var length: Bound { upperBound - lowerBound }
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

    func resolved(with range: ClosedRange<Bound>) -> ClosedRange<Bound> {
        switch self {
        case let self as ClosedRange<Bound>: self
        case let self as Range<Bound>: self.lowerBound...self.upperBound
        case let self as PartialRangeFrom<Bound>: self.lowerBound...range.upperBound
        case let self as PartialRangeThrough<Bound>: range.lowerBound...self.upperBound
        case let self as PartialRangeFrom<Bound>: self.lowerBound...range.upperBound
        default: range
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

func waitForTask(operation: @Sendable @escaping () async -> Void) {
    let semaphore = DispatchSemaphore(value: 0)

    Task {
        await operation()
        semaphore.signal()
    }

    while semaphore.wait(timeout: .now()) == .timedOut {
        RunLoop.current.run(until: .now)
    }
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

extension String {
    var simpleIdentifier: String {
        var string = lowercased()
        string = string.applyingTransform(.toLatin, reverse: false) ?? string
        string = string.applyingTransform(.stripDiacritics, reverse: false) ?? string
        string = string.replacingOccurrences(of: " ", with: "-")

        let allowedCharacters = CharacterSet(charactersIn: "a"..."z")
            .union(CharacterSet(charactersIn: "0"..."9"))
            .union(CharacterSet(charactersIn: "_-"))

        return String(string.unicodeScalars.filter { allowedCharacters.contains($0) })
    }
}
