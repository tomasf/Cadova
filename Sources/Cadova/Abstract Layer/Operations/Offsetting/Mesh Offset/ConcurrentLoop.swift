import Foundation

/// Runs work across all cores
internal enum ConcurrentLoop {
    /// Collects elements from 0..<count concurrently: each chunk of indices appends to its own array, and the chunks
    /// are joined in order. Cheaper than an array per index when most produce few elements or none.
    static func collect<T>(_ count: Int, _ body: @Sendable (_ index: Int, _ output: inout [T]) -> Void) -> [T] {
        guard count > 0 else { return [] }
        let chunk = max(64, count / (ProcessInfo.processInfo.activeProcessorCount * 8))
        let chunks = (count + chunk - 1) / chunk
        let parts = map(chunks) { c -> [T] in
            var output: [T] = []
            for index in (c * chunk)..<min(count, (c + 1) * chunk) { body(index, &output) }
            return output
        }
        var result: [T] = []
        result.reserveCapacity(parts.reduce(0) { $0 + $1.count })
        for part in parts { result.append(contentsOf: part) }
        return result
    }

    /// Maps 0..<count concurrently, in chunks, preserving order
    static func map<T>(_ count: Int, _ transform: @Sendable (Int) -> T) -> [T] {
        guard count > 0 else { return [] }
        if count < 64 { return (0..<count).map(transform) }
        let chunk = max(16, count / (ProcessInfo.processInfo.activeProcessorCount * 8))
        let chunks = (count + chunk - 1) / chunk
        return [T](unsafeUninitializedCapacity: count) { buffer, initialized in
            nonisolated(unsafe) let base = buffer.baseAddress!
            DispatchQueue.concurrentPerform(iterations: chunks) { c in
                for i in (c * chunk)..<min(count, (c + 1) * chunk) {
                    (base + i).initialize(to: transform(i))
                }
            }
            initialized = count
        }
    }
}
