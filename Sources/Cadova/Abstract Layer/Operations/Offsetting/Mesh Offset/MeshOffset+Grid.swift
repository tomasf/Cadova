import Foundation

extension MeshOffset {
    func point(_ i: Int, _ j: Int, _ k: Int) -> Vector3D {
        origin + Vector3D(Double(i), Double(j), Double(k)) * unit
    }

    /// Grid points take 19 bits per axis; edges add two bits for their axis, and spans five more for their length
    static let axisBits = 19
    static let maximumExtent = 1 << axisBits

    static func key(_ i: Int, _ j: Int, _ k: Int) -> UInt64 {
        UInt64(i) | UInt64(j) << 19 | UInt64(k) << 38
    }

    static func coordinates(_ key: UInt64) -> (Int, Int, Int) {
        let mask: UInt64 = (1 << 19) - 1
        return (Int(key & mask), Int(key >> 19 & mask), Int(key >> 38 & mask))
    }

    static func edgeKey(_ i: Int, _ j: Int, _ k: Int, axis: Int) -> UInt64 {
        key(i, j, k) << 2 | UInt64(axis)
    }

    static func spanKey(_ edgeKey: UInt64, length: Int) -> UInt64 {
        edgeKey | UInt64(length.trailingZeroBitCount) << 59
    }

    /// The offset function: negative inside the offset solid. With a face near p as a hint, it also returns the face
    /// closest to p, as a hint for nearby queries.
    func sample(at p: Vector3D, hint: Int? = nil, cap: Double = .infinity) -> (value: Double, face: Int) {
        if let rounding { return rounding.value(at: p, hint: hint) }
        if let corners {
            let result = corners.evaluate(at: p, hint: hint, cap: cap)
            return (result.value, result.face)
        }
        if cap.isFinite {
            // Only whether the value is within the cap matters: the surface can only be that close if the mesh is
            // within the amount plus the cap
            let closest = field.closest(to: p, hint: hint, within: abs(amount) + cap)
            guard closest.face >= 0 else { return (cap, hint ?? -1) }
            let distance = closest.distanceSquared.squareRoot()
            return ((field.isInside(p, closest: closest) ? -distance : distance) - amount, closest.face)
        }
        let result = field.signedDistanceAndFace(at: p, hint: hint)
        return (result.value - amount, result.face)
    }

    /// The offset function and its gradient
    func sampleWithGradient(at p: Vector3D, hint: Int?) -> (value: Double, gradient: Vector3D, face: Int) {
        if let rounding { return rounding.valueAndGradient(at: p, hint: hint) }
        if let corners { return corners.evaluate(at: p, hint: hint) }
        let result = field.signedDistanceAndGradient(at: p, hint: hint)
        return (result.value - amount, result.gradient, result.face)
    }

    func value(at p: Vector3D) -> Double {
        sample(at: p).value
    }

    func nodeMayContainSurface(_ node: OffsetOctree.Node, hint: Int? = nil) -> (Bool, Int) {
        let half = Double(node.size) * unit / 2
        let center = point(node.i, node.j, node.k) + Vector3D(half, half, half)
        let halfDiagonal = half * 3.0.squareRoot() * (1 + 1e-9)
        // Only whether the value is within the half-diagonal matters
        let result = sample(at: center, hint: hint, cap: 2 * halfDiagonal)
        return (abs(result.value) <= halfDiagonal, result.face)
    }

    /// Samples the offset function at both ends of every edge that doesn't have its values yet. The table's shards
    /// work independently: each takes its own keys, drops the ones it has, samples the rest and stores them, so no
    /// step runs serially over all keys.
    struct Request {
        let key: UInt64
        /// A face near the point, from the leaf the edge came from
        let hint: Int
    }

    func ensureValues(_ edges: [Edge]) {
        edges.withUnsafeBufferPointer { buffer in
            nonisolated(unsafe) let edges = buffer
            ensureValues(edges.count, pointsEach: 2) { n, point in
                let edge = edges[n]
                if point == 0 { return Request(key: Self.key(edge.i, edge.j, edge.k), hint: edge.hint) }
                let (ei, ej, ek) = edge.end
                return Request(key: Self.key(ei, ej, ek), hint: edge.hint)
            }
        }
    }

    /// The same for any set of grid points, given as a number of items with the same number of points each
    func ensureValues(_ count: Int, pointsEach: Int, _ request: @Sendable (_ item: Int, _ point: Int) -> Request) {
        let table = gridValues
        let shardCount = table.shardCount
        // Each chunk of items sorts its points by shard
        let chunk = max(1, 8192 / pointsEach)
        let chunkCount = (count + chunk - 1) / chunk
        let sorted = ConcurrentLoop.map(chunkCount) { c -> [[Request]] in
            var byShard = [[Request]](repeating: [], count: shardCount)
            var n = c * chunk
            let end = min(count, n + chunk)
            let reader = table.reader
            while n < end {
                var point = 0
                while point < pointsEach {
                    let wanted = request(n, point)
                    // Most points are known on later calls: skipping them here spares sorting them
                    if reader.value(for: wanted.key) == nil { byShard[table.shard(of: wanted.key)].append(wanted) }
                    point += 1
                }
                n += 1
            }
            return byShard
        }
        sorted.withUnsafeBufferPointer { buffer in
            nonisolated(unsafe) let sorted = buffer
            ConcurrentLoop.perform(shardCount) { shard in
                var missing: [Request] = []
                for part in sorted {
                    for request in part[shard] where table.value(for: request.key) == nil {
                        table.set(.nan, for: request.key)
                        missing.append(request)
                    }
                }
                for request in missing {
                    let (i, j, k) = Self.coordinates(request.key)
                    let result = self.sample(at: self.point(i, j, k), hint: request.hint >= 0 ? request.hint : nil)
                    table.set(result.value, for: request.key)
                }
            }
        }
    }

    func gridValue(_ i: Int, _ j: Int, _ k: Int) -> Double {
        // Not `??`: its autoclosure is a generic call on every read in unoptimized builds
        if let known = knownValues.value(for: Self.key(i, j, k)) { return known }
        return value(at: point(i, j, k))
    }
}
