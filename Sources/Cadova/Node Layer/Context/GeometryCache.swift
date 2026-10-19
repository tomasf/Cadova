import Foundation
import Manifold3D
import Synchronization

// GeometryCache maintains a mapping between geometry nodes and concrete geometry to avoid repeated
// evaluation. To bound its memory, the least recently used results can be pruned (see
// EvaluationContext.pruneCache); anything pruned is evaluated again if it's needed later.

internal actor GeometryCache<D: Dimensionality> {
    typealias Generator = @Sendable () async throws -> D.Node.Result

    private var entries = CacheTable<D.Node, D.Node.Result>()
    private var bodyEntries = CacheTable<AnyCacheKey, BuildResult<D>>()
    private var measurementsCache: [D.Node: CachedMeasurements<D>] = [:]

    // A materialized node can't evaluate itself, so its generator is the only way to get its result.
    // Generators are kept when results are pruned, since build results that refer to the node can
    // outlive the build, such as a ModelFile or a CachedGeometry body's result.
    private var generators: [D.Node: Generator] = [:]

    private let clock: CacheClock

    init(clock: CacheClock) {
        self.clock = clock
    }

    @_specialize(exported: false, where D == D2)
    @_specialize(exported: false, where D == D3)
    func result(for node: D.Node, in context: EvaluationContext) async throws -> D.Node.Result {
        guard !node.isEmpty else { return .empty }

        if let state = entries.use(node, at: clock.tick()) {
            return try await state.value
        } else if let generator = generators[node] {
            return try await startEntry(for: node, operation: generator).value
        } else {
            return try await startEntry(for: node) { try await node.evaluate(in: context) }.value
        }
    }

    func declareGenerator(for node: D.Node, generator: @escaping Generator) async throws {
        if generators[node] == nil {
            generators[node] = generator
        }
        if !entries.contains(node) {
            startEntry(for: node, operation: generator)
        }
    }

    @discardableResult
    private func startEntry(for node: D.Node, operation: @escaping Generator) -> Task<D.Node.Result, any Error> {
        let id = entries.nextID()
        let task = Task {
            let outcome: Result<D.Node.Result, any Error>
            do { outcome = .success(try await operation()) } catch { outcome = .failure(error) }
            entries.finish(node, id: id, with: outcome)
            return try outcome.get()
        }
        entries.insert(node, id: id, task: task, at: clock.tick())
        return task
    }

    // Coalesces concurrent/repeated calls sharing the same key onto a single `body` build, so
    // `CachedGeometry` bodies run at most once per key while still surfacing that build's result
    // elements (which, unlike node evaluation, can't be deferred to mesh-realization time).
    func bodyResult(for key: AnyCacheKey, generator: @escaping @Sendable () async throws -> BuildResult<D>) async throws -> BuildResult<D> {
        if let state = bodyEntries.use(key, at: clock.tick()) {
            return try await state.value
        }
        let id = bodyEntries.nextID()
        let task = Task {
            let outcome: Result<BuildResult<D>, any Error>
            do { outcome = .success(try await generator()) } catch { outcome = .failure(error) }
            bodyEntries.finish(key, id: id, with: outcome)
            return try outcome.get()
        }
        bodyEntries.insert(key, id: id, task: task, at: clock.tick())
        return try await task.value
    }
}

// Pruning. Results still being evaluated are left alone, and don't count towards the size.
internal extension GeometryCache {
    /// When each finished result was last used, and its estimated size in bytes.
    func finishedEntryUsage() -> [(lastUse: Int, byteCount: Int)] {
        entries.finishedUsage { $0.estimatedByteCount }
    }

    /// Removes every finished result and body result last used at or before the given time.
    func removeEntries(lastUsedAtOrBefore cutoff: Int) {
        entries.removeFinished(lastUsedAtOrBefore: cutoff)
        bodyEntries.removeFinished(lastUsedAtOrBefore: cutoff)
        measurementsCache = measurementsCache.filter { entries.contains($0.key) }
    }
}

/// Cached values by key, each evaluated at most once at a time. A value is evaluated by a task, which
/// concurrent requests for it share, and once the task is done, the entry holds its outcome instead.
private struct CacheTable<Key: Hashable, Value: Sendable> {
    enum State {
        case evaluating(Task<Value, any Error>)
        case finished(Value)
        case failed(any Error)

        var value: Value {
            get async throws {
                switch self {
                case .evaluating(let task): try await task.value
                case .finished(let value): value
                case .failed(let error): throw error
                }
            }
        }
    }

    private struct Entry {
        let id: Int
        var state: State
        var lastUse: Int
    }

    private var entries: [Key: Entry] = [:]
    private var lastID = 0

    var count: Int { entries.count }
    var keys: some Collection<Key> { entries.keys }

    func contains(_ key: Key) -> Bool {
        entries[key] != nil
    }

    /// The state of a key's entry, if it has one, marking it as used at the given time.
    mutating func use(_ key: Key, at time: Int) -> State? {
        guard entries[key] != nil else { return nil }
        entries[key]?.lastUse = time
        return entries[key]?.state
    }

    /// An ID for a new entry, which tells it apart from entries the key had before or gets later.
    mutating func nextID() -> Int {
        lastID += 1
        return lastID
    }

    mutating func insert(_ key: Key, id: Int, task: Task<Value, any Error>, at time: Int) {
        entries[key] = Entry(id: id, state: .evaluating(task), lastUse: time)
    }

    // The entry may have been pruned, and even replaced, while its task ran
    mutating func finish(_ key: Key, id: Int, with outcome: Result<Value, any Error>) {
        guard entries[key]?.id == id else { return }
        switch outcome {
        case .success(let value): entries[key]?.state = .finished(value)
        case .failure(let error): entries[key]?.state = .failed(error)
        }
    }

    /// When each finished entry was last used, and its size. A failure has no size.
    func finishedUsage(byteCount: (Value) -> Int) -> [(lastUse: Int, byteCount: Int)] {
        entries.values.compactMap { entry in
            switch entry.state {
            case .evaluating: nil
            case .finished(let value): (entry.lastUse, byteCount(value))
            case .failed: (entry.lastUse, 0)
            }
        }
    }

    mutating func removeFinished(lastUsedAtOrBefore cutoff: Int) {
        entries = entries.filter { _, entry in
            if case .evaluating = entry.state { return true }
            return entry.lastUse > cutoff
        }
    }
}

/// Counts uses of cached results, so that the least recently used can be pruned first. Shared by a
/// context's 2D and 3D caches, so that their uses compare.
internal final class CacheClock: Sendable {
    private let time = Atomic<Int>(0)

    func tick() -> Int {
        time.wrappingAdd(1, ordering: .relaxed).newValue
    }
}

// Memoizes Measurements' expensive derived properties (volume, surface area, centroid,
// convexity) per node, so repeated measurement of the same geometry is free after the first call.
// Each accessor below runs entirely within one actor call, so there's no race window between
// checking the cache and storing a freshly computed value.
internal extension GeometryCache where D == D2 {
    func cachedArea(for node: D.Node, compute: () -> Double) -> Double {
        if let value = measurementsCache[node]?.area { return value }
        if let value = measurementsCache[node]?.centroidAndWeight?.weight { return value }
        let value = compute()
        measurementsCache[node, default: CachedMeasurements()].area = value
        return value
    }

    func cachedIsConvex(for node: D.Node, compute: () -> Bool) -> Bool {
        if let value = measurementsCache[node]?.isConvex { return value }
        let value = compute()
        measurementsCache[node, default: CachedMeasurements()].isConvex = value
        return value
    }

    // Deriving the centroid also derives area as a byproduct of the same triangulation pass, so
    // it's stashed into `area` too (unless something else already settled that value first).
    func cachedCentroidAndWeight(
        for node: D.Node,
        compute: () -> (centroid: Vector2D, weight: Double)
    ) -> (centroid: Vector2D, weight: Double) {
        if let value = measurementsCache[node]?.centroidAndWeight { return value }
        let value = compute()
        measurementsCache[node, default: CachedMeasurements()].centroidAndWeight = value
        if measurementsCache[node]?.area == nil { measurementsCache[node]?.area = value.weight }
        return value
    }
}

internal extension GeometryCache where D == D3 {
    func cachedVolume(for node: D.Node, compute: () -> Double) -> Double {
        if let value = measurementsCache[node]?.volume { return value }
        if let value = measurementsCache[node]?.centroidAndWeight?.weight { return value }
        let value = compute()
        measurementsCache[node, default: CachedMeasurements()].volume = value
        return value
    }

    func cachedSurfaceArea(for node: D.Node, compute: () -> Double) -> Double {
        if let value = measurementsCache[node]?.surfaceArea { return value }
        let value = compute()
        measurementsCache[node, default: CachedMeasurements()].surfaceArea = value
        return value
    }

    // Deriving the centroid also derives volume as a byproduct of the same mesh traversal, so
    // it's stashed into `volume` too (unless something else already settled that value first).
    func cachedCentroidAndWeight(
        for node: D.Node,
        compute: () -> (centroid: Vector3D, weight: Double)
    ) -> (centroid: Vector3D, weight: Double) {
        if let value = measurementsCache[node]?.centroidAndWeight { return value }
        let value = compute()
        measurementsCache[node, default: CachedMeasurements()].centroidAndWeight = value
        if measurementsCache[node]?.volume == nil { measurementsCache[node]?.volume = value.weight }
        return value
    }
}

internal extension GeometryCache {
    var count: Int {
        entries.count
    }

    func hasResult(for node: D.Node) -> Bool {
        entries.contains(node)
    }

    func debugPrint() {
        for key in entries.keys {
            print(key.debugDescription)
        }
    }
}
