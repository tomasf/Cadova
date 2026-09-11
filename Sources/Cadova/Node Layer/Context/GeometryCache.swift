import Foundation
import Manifold3D

// GeometryCache maintains a mapping between geometry nodes and concrete geometry to avoid repeated evaluation

internal actor GeometryCache<D: Dimensionality> {
    private var entries: [D.Node: Task<D.Node.Result, any Error>] = [:]
    private var bodyEntries: [AnyCacheKey: Task<BuildResult<D>, any Error>] = [:]
    private var measurementsCache: [D.Node: CachedMeasurements<D>] = [:]

    @_specialize(exported: false, where D == D2)
    @_specialize(exported: false, where D == D3)
    func result(for node: D.Node, in context: EvaluationContext) async throws -> D.Node.Result {
        guard !node.isEmpty else { return .empty }

        if let cached = try await entries[node]?.value {
            return cached
        }
        let task = Task { try await node.evaluate(in: context) }
        entries[node] = task
        return try await task.value
    }

    func declareGenerator(for node: D.Node, generator: @escaping @Sendable () async throws -> D.Node.Result) async throws {
        if entries[node] == nil {
            entries[node] = Task(operation: generator)
        }
    }

    // Coalesces concurrent/repeated calls sharing the same key onto a single `body` build, so
    // `CachedGeometry` bodies run at most once per key while still surfacing that build's result
    // elements (which, unlike node evaluation, can't be deferred to mesh-realization time).
    func bodyResult(for key: AnyCacheKey, generator: @escaping @Sendable () async throws -> BuildResult<D>) async throws -> BuildResult<D> {
        if let existing = bodyEntries[key] {
            return try await existing.value
        }
        let task = Task(operation: generator)
        bodyEntries[key] = task
        return try await task.value
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

    func debugPrint() {
        for key in entries.keys {
            print(key.debugDescription)
        }
    }
}
