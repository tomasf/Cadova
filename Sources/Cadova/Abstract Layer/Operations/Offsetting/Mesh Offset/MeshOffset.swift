import Foundation

/// Offsets a closed triangle mesh: the surface at a given signed distance from it, found by dual contouring the
/// exact signed distance on an adaptive octree.
///
/// - The octree only covers the band around the offset surface: the distance changes no faster than position, so a
///   node whose center is farther from the offset than its half-diagonal can't contain it.
/// - A node may stay large when every face that could be nearest to any offset point inside it lies in one plane,
///   because the offset there is provably that plane. Everything else is refined to the base cell size, and further
///   where the fit is poor, down to a quarter of it.
/// - Where the offset function changes sign along a cell edge, the exact crossing and the distance gradient there
///   give a plane; each cell places one vertex by fitting its planes, which keeps flat faces flat and sharp creases
///   sharp. Edges and vertices are taken on the finest cells around them (Ju et al., minimal edges).
/// - Cells are then merged bottom up where one vertex fits within the tolerance and merging can't change the
///   topology, and the result is repaired and cleaned until it's a 2-manifold.
internal final class MeshOffset: @unchecked Sendable {   // shared read-only by the concurrent loops
    typealias Face = (Int, Int, Int)

    private let field: MeshDistanceField
    private let amount: Double
    /// Corner pieces for sharp joins; nil for round
    private let corners: OffsetCorners?
    /// How far beyond the amount the surface can reach (the miter limit for sharp joins)
    private let reachFactor: Double
    private let cellSize: Double
    private let tolerance: Double

    /// Grid units per base cell: cells with poor fits can be split this far below the base size
    private static let refinementLevels = 2
    private let unitsPerCell = 1 << MeshOffset.refinementLevels
    /// The largest planar cell, in base cells
    private static let coarsestPlanarCells = 64

    private let unit: Double
    private let origin: Vector3D
    private var octree: OffsetOctree
    private let coarsest: Int

    private let gridValues = GridTable(capacity: 1 << 16, shards: 64)
    private let knownValues: GridTable.Reader
    private struct Crossing {
        let point: Vector3D
        let normal: Vector3D
    }
    /// Crossings found so far, indexed by edge and length: an edge's crossing never changes, so refitting after splits
    /// only has to find the new ones
    private var crossingStore: [Crossing] = []
    private let crossingIndex = GridTable()
    private let knownCrossings: GridTable.Reader
    private var fits: [PlaneFit] = []
    /// The minimal edges of the last fit, and which of them cross, for contouring the same tree without finding
    /// them again
    private var fittedEdges: (edges: [Edge], crossing: [Int])? = nil
    private var merges: [Int: (node: Int, child: Int, fit: PlaneFit)] = [:]

    init(field: MeshDistanceField, amount: Double, style: LineJoinStyle = .round, miterLimit: Double = 5, cellSize: Double, tolerance: Double) {
        self.field = field
        self.amount = amount
        self.tolerance = tolerance
        knownValues = gridValues.reader
        knownCrossings = crossingIndex.reader
        // Miters reach up to the limit; square and bevel corners stay within about 1.5 times the amount
        reachFactor = switch style {
        case .round: 1
        case .miter: max(miterLimit, 1.5)
        case .square, .bevel: 1.5
        }
        corners = style == .round ? nil : OffsetCorners(field: field, amount: amount, style: style, miterLimit: miterLimit, tolerance: tolerance)

        var lower = field.vertices.first ?? .zero, upper = lower
        for v in field.vertices { lower = .min(lower, v); upper = .max(upper, v) }
        let modelExtent = max(upper.x - lower.x, upper.y - lower.y, upper.z - lower.z) + 2 * max(0, amount) * reachFactor
        // Keys hold 19 bits per axis; cells grow on models too large for that at this resolution
        var cellSize = cellSize
        while (modelExtent / cellSize + 4) * Double(1 << MeshOffset.refinementLevels) > Double(MeshOffset.maximumExtent) / 2 { cellSize *= 2 }
        self.cellSize = cellSize
        unit = cellSize / Double(1 << MeshOffset.refinementLevels)

        let margin = max(0, amount) * reachFactor + 2 * cellSize
        lower = lower - margin
        upper = upper + margin
        origin = lower
        let size = upper - lower
        let extent = max(size.x, size.y, size.z)
        let depth = max(1, Int(ceil(log2(extent / cellSize))))
        octree = OffsetOctree(extent: (1 << depth) << MeshOffset.refinementLevels)
        coarsest = MeshOffset.coarsestPlanarCells << MeshOffset.refinementLevels
    }

    // MARK: - Grid

    private func point(_ i: Int, _ j: Int, _ k: Int) -> Vector3D {
        origin + Vector3D(Double(i), Double(j), Double(k)) * unit
    }

    /// Grid points take 19 bits per axis; edges add two bits for their axis, and spans five more for their length
    private static let axisBits = 19
    private static let maximumExtent = 1 << axisBits

    private static func key(_ i: Int, _ j: Int, _ k: Int) -> UInt64 {
        UInt64(i) | UInt64(j) << 19 | UInt64(k) << 38
    }

    private static func coordinates(_ key: UInt64) -> (Int, Int, Int) {
        let mask: UInt64 = (1 << 19) - 1
        return (Int(key & mask), Int(key >> 19 & mask), Int(key >> 38 & mask))
    }

    private static func edgeKey(_ i: Int, _ j: Int, _ k: Int, axis: Int) -> UInt64 {
        key(i, j, k) << 2 | UInt64(axis)
    }

    private static func spanKey(_ edgeKey: UInt64, length: Int) -> UInt64 {
        edgeKey | UInt64(length.trailingZeroBitCount) << 59
    }

    /// The offset function: negative inside the offset solid. With a face near p as a hint, it also returns the face
    /// closest to p, as a hint for nearby queries.
    private func sample(at p: Vector3D, hint: Int? = nil, cap: Double = .infinity) -> (value: Double, face: Int) {
        if let corners {
            let result = corners.evaluate(at: p, hint: hint, cap: cap)
            return (result.value, result.face)
        }
        let result = field.signedDistanceAndFace(at: p, hint: hint)
        return (result.value - amount, result.face)
    }

    /// The offset function and its gradient
    private func sampleWithGradient(at p: Vector3D, hint: Int?) -> (value: Double, gradient: Vector3D, face: Int) {
        if let corners { return corners.evaluate(at: p, hint: hint) }
        let result = field.signedDistanceAndGradient(at: p, hint: hint)
        return (result.value - amount, result.gradient, result.face)
    }

    private func value(at p: Vector3D) -> Double {
        sample(at: p).value
    }

    private func nodeMayContainSurface(_ node: OffsetOctree.Node, hint: Int? = nil) -> (Bool, Int) {
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
    private struct Request {
        let key: UInt64
        /// A face near the point, from the leaf the edge came from
        let hint: Int
    }

    private func ensureValues(_ edges: [Edge]) {
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
    private func ensureValues(_ count: Int, pointsEach: Int, _ request: @Sendable (_ item: Int, _ point: Int) -> Request) {
        let table = gridValues
        let shardCount = table.shardCount
        // Each chunk of items sorts its points by shard
        let chunk = max(1, 8192 / pointsEach)
        let chunkCount = (count + chunk - 1) / chunk
        let sorted = ConcurrentLoop.map(chunkCount) { c -> [[Request]] in
            var byShard = [[Request]](repeating: [], count: shardCount)
            var n = c * chunk
            let end = min(count, n + chunk)
            while n < end {
                var point = 0
                while point < pointsEach {
                    let wanted = request(n, point)
                    byShard[table.shard(of: wanted.key)].append(wanted)
                    point += 1
                }
                n += 1
            }
            return byShard
        }
        sorted.withUnsafeBufferPointer { buffer in
            nonisolated(unsafe) let sorted = buffer
            DispatchQueue.concurrentPerform(iterations: shardCount) { shard in
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

    private func gridValue(_ i: Int, _ j: Int, _ k: Int) -> Double {
        // Not `??`: its autoclosure is a generic call on every read in unoptimized builds
        if let known = knownValues.value(for: Self.key(i, j, k)) { return known }
        return value(at: point(i, j, k))
    }

    // MARK: - Octree

    /// What to do with a node: 0 leave it empty, 1 make it a leaf, 2 subdivide it; and the face closest to its center
    private struct Decision {
        let kind: Int
        let face: Int
    }

    private func buildTree() {
        var frontier = [0]
        var hints: [Int] = [-1]   // per frontier node, the closest face found for its parent
        while !frontier.isEmpty {
            let level = frontier, levelHints = hints
            let decisions = octree.nodes.withUnsafeBufferPointer { nodeBuffer in
                nonisolated(unsafe) let nodes = nodeBuffer
                return ConcurrentLoop.map(level.count) { n -> Decision in
                    let node = nodes[level[n]]
                    let (contains, face) = self.nodeMayContainSurface(node, hint: levelHints[n])
                    guard contains else { return Decision(kind: 0, face: face) }
                    if node.size == self.unitsPerCell { return Decision(kind: 1, face: face) }
                    if node.size <= self.coarsest {
                        // Planar where every face the round offset in here can come from lies in one plane, and no
                        // corner piece reaches in
                        let half = Double(node.size) * self.unit / 2
                        let center = self.point(node.i, node.j, node.k) + Vector3D(half, half, half)
                        let halfDiagonal = half * 3.0.squareRoot() * (1 + 1e-9)
                        if self.field.facesAreCoplanar(within: abs(self.amount) + halfDiagonal, of: center)
                            && !(self.corners?.mayAffect(center, radius: halfDiagonal) ?? false) {
                            return Decision(kind: 1, face: face)
                        }
                    }
                    return Decision(kind: 2, face: face)
                }
            }
            // Counted loops: this handles every node, in unoptimized builds too
            var next: [Int] = []
            var nextHints: [Int] = []
            var parentsOfCells: [Int] = [], parentHints: [Int] = []
            var n = 0
            while n < level.count {
                let index = level[n], decision = decisions[n]
                n += 1
                if decision.kind == 1 {
                    octree.makeLeaf(node: index, hint: decision.face)
                } else if decision.kind == 2 {
                    if octree.nodes[index].size == 2 * unitsPerCell {
                        parentsOfCells.append(index)
                        parentHints.append(decision.face)
                        continue
                    }
                    let first = octree.subdivide(node: index)
                    var c = 0
                    while c < 8 { next.append(first + c); nextHints.append(decision.face); c += 1 }
                }
            }
            if !parentsOfCells.isEmpty { makeCells(in: parentsOfCells, hints: parentHints) }
            frontier = next
            hints = nextHints
        }
    }

    /// Divides nodes twice the base cell size into base cells, keeping the cells the surface crosses: those with
    /// corners on both sides. The corners are grid points that contouring samples anyway, so this costs no samples of
    /// its own, unlike testing each cell's center. The cells this leaves out have no crossing edges; they only matter
    /// next to finer cells, and splitting a cell brings back its neighbors (see ``split(leaves:)``).
    private func makeCells(in parents: [Int], hints: [Int]) {
        let size = unitsPerCell
        let nodes = octree.nodes
        nodes.withUnsafeBufferPointer { nodeBuffer in
            parents.withUnsafeBufferPointer { parentBuffer in
                hints.withUnsafeBufferPointer { hintBuffer in
                    nonisolated(unsafe) let nodes = nodeBuffer, parents = parentBuffer, hints = hintBuffer
                    ensureValues(parents.count, pointsEach: 27) { n, point in
                        let node = nodes[parents[n]]
                        return Request(key: Self.key(node.i + point % 3 * size, node.j + point / 3 % 3 * size, node.k + point / 9 * size), hint: hints[n])
                    }
                }
            }
        }
        var n = 0
        while n < parents.count {
            let parent = parents[n], hint = hints[n]
            n += 1
            let first = octree.subdivide(node: parent)
            var c = 0
            while c < 8 {
                let cell = octree.nodes[first + c]
                c += 1
                var inside = 0
                var q = 0
                while q < 8 {
                    let value = knownValues.value(for: Self.key(cell.i + (q & 1) * size, cell.j + (q >> 1 & 1) * size, cell.k + (q >> 2 & 1) * size))!
                    if value < 0 { inside += 1 }
                    q += 1
                }
                if inside > 0 && inside < 8 { octree.makeLeaf(node: first + c - 1, hint: hint) }
            }
        }
    }

    /// Splits leaves into their children that may contain the surface. Finer cells need their neighbors as leaves
    /// wherever the surface comes near, crossing or not, so this also brings back the base cells around split base
    /// cells that making cells from corner signs left out. The sampling for all of them runs on every core.
    private func split(leaves indices: [Int]) {
        guard !indices.isEmpty else { return }
        // Nodes to test: empty base cells next to split base cells, then every split leaf's eight children to be
        var tested: [OffsetOctree.Node] = []
        var hints: [Int] = []
        var restored: [Int] = []
        var seen = Set<Int>()
        for index in indices where octree.leaves[index].size == unitsPerCell {
            let leaf = octree.leaves[index]
            var neighbor = 0
            while neighbor < 27 {
                let dx = neighbor % 3 - 1, dy = neighbor / 3 % 3 - 1, dz = neighbor / 9 - 1
                neighbor += 1
                guard dx != 0 || dy != 0 || dz != 0,
                      let found = octree.node(at: leaf.i + dx * leaf.size, leaf.j + dy * leaf.size, leaf.k + dz * leaf.size, size: leaf.size)
                else { continue }
                let node = octree.nodes[found]
                guard node.size == leaf.size, node.leaf < 0, node.child < 0, seen.insert(found).inserted else { continue }
                restored.append(found)
                tested.append(node)
                hints.append(leaf.hint)
            }
        }
        for index in indices {
            let leaf = octree.leaves[index]
            let half = leaf.size / 2
            var c = 0
            while c < 8 {
                tested.append(OffsetOctree.Node(i: leaf.i + (c & 1 != 0 ? half : 0), j: leaf.j + (c & 2 != 0 ? half : 0), k: leaf.k + (c & 4 != 0 ? half : 0), size: half))
                hints.append(leaf.hint)
                c += 1
            }
        }
        let nodes = tested, nodeHints = hints
        let results = ConcurrentLoop.map(nodes.count) { n -> Decision in
            let (contains, face) = self.nodeMayContainSurface(nodes[n], hint: nodeHints[n] >= 0 ? nodeHints[n] : nil)
            return Decision(kind: contains ? 1 : 0, face: face)
        }
        var n = 0
        for node in restored {
            if results[n].kind == 1 { octree.makeLeaf(node: node, hint: results[n].face) }
            n += 1
        }
        for index in indices {
            let leaf = octree.leaves[index]
            octree.leaves[index].size = 0
            octree.nodes[leaf.node].leaf = -1
            // Children come in the same order as tested above
            let first = octree.subdivide(node: leaf.node)
            var c = 0
            while c < 8 {
                if results[n].kind == 1 { octree.makeLeaf(node: first + c, hint: results[n].face) }
                n += 1
                c += 1
            }
        }
    }

    /// 2:1 balance: no leaf may touch a leaf smaller than half its size
    @discardableResult
    private func balance() -> Int {
        var count = 0
        var candidates = Array(octree.leaves.indices)
        while !candidates.isEmpty {
            let current = candidates
            let flags = octree.nodes.withUnsafeBufferPointer { nodeBuffer in
                octree.leaves.withUnsafeBufferPointer { leafBuffer in
                    nonisolated(unsafe) let nodes = nodeBuffer, leaves = leafBuffer
                    let extent = octree.extent
                    return ConcurrentLoop.map(current.count) { n -> Bool in
                        let leaf = leaves[current[n]]
                        return leaf.size >= 4 && OffsetOctree.hasMuchSmallerNeighbor(leaf.i, leaf.j, leaf.k, size: leaf.size, near: leaf.node, in: nodes, extent: extent)
                    }
                }
            }
            var split: [Int] = []
            var n = 0
            while n < current.count { if flags[n] { split.append(current[n]) }; n += 1 }
            if split.isEmpty { break }
            // Splitting can only unbalance the split leaves' neighbors
            var next = Set<Int>()
            let splitLeaves = split.map { octree.leaves[$0] }
            self.split(leaves: split)
            for leaf in splitLeaves {
                var neighbor = 0
                while neighbor < 27 {
                    let dx = neighbor % 3 - 1, dy = neighbor / 3 % 3 - 1, dz = neighbor / 9 - 1
                    neighbor += 1
                    if dx == 0 && dy == 0 && dz == 0 { continue }
                    let found = octree.locate(
                        Double(leaf.i) + (Double(dx) + 0.5) * Double(leaf.size),
                        Double(leaf.j) + (Double(dy) + 0.5) * Double(leaf.size),
                        Double(leaf.k) + (Double(dz) + 0.5) * Double(leaf.size)
                    )
                    if let other = found.leaf, octree.leaves[other].size >= 4 { next.insert(other) }
                }
            }
            count += split.count
            // Sorted: a set's order changes from run to run, and the result shouldn't
            candidates = next.sorted()
        }
        return count
    }

    // MARK: - Edges

    private struct Edge {
        let key: UInt64
        let i: Int, j: Int, k: Int
        let axis: Int
        let length: Int
        let around: (Int, Int, Int, Int)   // the leaves around it, -1 where empty
        let hint: Int

        var end: (Int, Int, Int) {
            (i + (axis == 0 ? length : 0), j + (axis == 1 ? length : 0), k + (axis == 2 ? length : 0))
        }
    }

    /// Minimal edges: edges of leaves that no smaller node, leaf or empty, subdivides
    private func minimalEdges() -> [Edge] {
        let tree = octree
        let edges = tree.nodes.withUnsafeBufferPointer { nodeBuffer in
        tree.leaves.withUnsafeBufferPointer { leafBuffer in
        nonisolated(unsafe) let nodes = nodeBuffer, leaves = leafBuffer
        let extent = tree.extent
        return ConcurrentLoop.collect(leaves.count) { (index: Int, edges: inout [Edge]) in
            let leaf = leaves[index]
            guard leaf.size > 0 else { return }
            let size = leaf.size
            let center = (Double(leaf.i) + Double(size) / 2, Double(leaf.j) + Double(size) / 2, Double(leaf.k) + Double(size) / 2)
            func probe(_ dx: Int, _ dy: Int, _ dz: Int) -> OffsetOctree.Location {
                let step = Double(size)
                return OffsetOctree.locate(center.0 + Double(dx) * step, center.1 + Double(dy) * step, center.2 + Double(dz) * step, near: leaf.node, in: nodes, extent: extent)
            }
            func offset(_ axis: Int, _ sign: Int) -> (Int, Int, Int) {
                (axis == 0 ? sign : 0, axis == 1 ? sign : 0, axis == 2 ? sign : 0)
            }
            // Cells align, so the region across a face (or diagonally across an edge) the size of this leaf is either
            // covered by one node at least as large, or subdivided: one probe at its center answers for every edge
            // bordering it. Faces are indexed by axis * 2 + (positive ? 1 : 0).
            // Six plain values rather than an array: this runs for every leaf, in unoptimized builds too
            let n0 = probe(-1, 0, 0), n1 = probe(1, 0, 0), n2 = probe(0, -1, 0), n3 = probe(0, 1, 0), n4 = probe(0, 0, -1), n5 = probe(0, 0, 1)
            func faceNeighbor(_ face: Int) -> OffsetOctree.Location {
                switch face {
                case 0: return n0
                case 1: return n1
                case 2: return n2
                case 3: return n3
                case 4: return n4
                default: return n5
                }
            }
            var axis = -1
            while axis < 2 {
                axis += 1
                let u = (axis + 1) % 3, v = (axis + 2) % 3
                var e = -1
                while e < 3 {
                    e += 1
                    let du = e & 1, dv = e >> 1 & 1   // which side of the leaf the edge lies on, along u and v
                    let acrossU = faceNeighbor(u * 2 + du), acrossV = faceNeighbor(v * 2 + dv)
                    if acrossU.size < size || acrossV.size < size { continue }
                    let uOffset = offset(u, du == 1 ? 1 : -1), vOffset = offset(v, dv == 1 ? 1 : -1)
                    let diagonal = probe(uOffset.0 + vOffset.0, uOffset.1 + vOffset.1, uOffset.2 + vOffset.2)
                    if diagonal.size < size { continue }

                    let (i, j, k): (Int, Int, Int)
                    switch axis {
                    case 0: (i, j, k) = (leaf.i, leaf.j + du * size, leaf.k + dv * size)
                    case 1: (i, j, k) = (leaf.i + dv * size, leaf.j, leaf.k + du * size)
                    default: (i, j, k) = (leaf.i + du * size, leaf.j + dv * size, leaf.k)
                    }
                    // Quadrants around the edge, in the order (+u, +v), (−u, +v), (−u, −v), (+u, −v); the leaf lies on
                    // the +u side of an edge at its low u face (du = 0), and so on
                    func quadrant(_ positiveU: Bool, _ positiveV: Bool) -> Int {
                        let leafSideU = positiveU == (du == 0), leafSideV = positiveV == (dv == 0)
                        switch (leafSideU, leafSideV) {
                        case (true, true): return index
                        case (false, true): if let leaf = acrossU.leaf { return leaf } else { return -1 }
                        case (true, false): if let leaf = acrossV.leaf { return leaf } else { return -1 }
                        case (false, false): if let leaf = diagonal.leaf { return leaf } else { return -1 }
                        }
                    }
                    let around = (quadrant(true, true), quadrant(false, true), quadrant(false, false), quadrant(true, false))
                    // Leaves of this size around the edge all find it; the lowest-numbered one keeps it
                    var owner = index
                    if around.1 >= 0 && around.1 < owner && leaves[around.1].size == size { owner = around.1 }
                    if around.2 >= 0 && around.2 < owner && leaves[around.2].size == size { owner = around.2 }
                    if around.3 >= 0 && around.3 < owner && leaves[around.3].size == size { owner = around.3 }
                    if around.0 >= 0 && around.0 < owner && leaves[around.0].size == size { owner = around.0 }
                    guard owner == index else { continue }
                    edges.append(Edge(key: Self.edgeKey(i, j, k, axis: axis), i: i, j: j, k: k, axis: axis, length: size, around: around, hint: leaf.hint))
                }
            }
        }
        }
        }
        ensureValues(edges)
        return edges
    }

    private func crosses(_ edge: Edge) -> (crosses: Bool, rising: Bool) {
        let (ei, ej, ek) = edge.end
        let a = gridValue(edge.i, edge.j, edge.k), b = gridValue(ei, ej, ek)
        return ((a < 0) != (b < 0), a < 0)
    }

    /// Where the offset surface crosses an edge, and the distance gradient there, by safeguarded Newton steps:
    /// every distance query also yields the gradient
    private func crossing(on edge: Edge) -> Crossing {
        let (ei, ej, ek) = edge.end
        let start = point(edge.i, edge.j, edge.k)
        let direction = Vector3D(edge.axis == 0 ? 1 : 0, edge.axis == 1 ? 1 : 0, edge.axis == 2 ? 1 : 0)
        let length = Double(edge.length) * unit
        var lower = 0.0, upper = length
        var lowerValue = gridValue(edge.i, edge.j, edge.k), upperValue = gridValue(ei, ej, ek)
        var t = lower - lowerValue * (upper - lower) / (upperValue - lowerValue)
        var p = start, gradient = Vector3D.zero
        var hint: Int? = edge.hint >= 0 ? edge.hint : nil
        for _ in 0..<40 {
            p = start + direction * t
            let sample = sampleWithGradient(at: p, hint: hint)
            hint = sample.face
            gradient = sample.gradient
            let v = sample.value
            if abs(v) < 1e-10 * unit { break }
            if (v < 0) == (lowerValue < 0) { lower = t; lowerValue = v } else { upper = t; upperValue = v }
            if upper - lower < 1e-12 * length { break }
            let slope = gradient[edge.axis]
            var next = slope != 0 ? t - v / slope : -1
            if !(next > lower && next < upper) { next = lower - lowerValue * (upper - lower) / (upperValue - lowerValue) }
            if !(next > lower && next < upper) { next = (lower + upper) / 2 }
            t = next
        }
        return Crossing(point: p, normal: gradient)
    }

    /// Hermite data on every sign-changing minimal edge, and each leaf's planes
    private func computeFits() {
        let all = minimalEdges()
        // The edges that cross, and those among them with no crossing found yet
        let (crossingEdges, missingEdges) = all.withUnsafeBufferPointer { buffer in
            nonisolated(unsafe) let all = buffer
            let crossing = ConcurrentLoop.collect(all.count) { (n: Int, found: inout [Int]) in
                if self.crosses(all[n]).crosses { found.append(n) }
            }
            let missing = crossing.withUnsafeBufferPointer { crossingBuffer in
                nonisolated(unsafe) let crossing = crossingBuffer
                return ConcurrentLoop.collect(crossing.count) { (n: Int, found: inout [Edge]) in
                    let edge = all[crossing[n]]
                    if self.knownCrossings.value(for: Self.spanKey(edge.key, length: edge.length)) == nil { found.append(edge) }
                }
            }
            return (crossing, missing)
        }
        let missing = missingEdges
        let found = ConcurrentLoop.map(missing.count) { self.crossing(on: missing[$0]) }
        for (edge, result) in zip(missing, found) {
            crossingIndex.set(Double(crossingStore.count), for: Self.spanKey(edge.key, length: edge.length))
            crossingStore.append(result)
        }

        // Each leaf's planes. Leaves are dealt out to workers by index, and every worker reads all edges but only
        // adds to its own leaves, so no two write the same fit.
        var accumulated = [PlaneFit](repeating: PlaneFit(), count: octree.leaves.count)
        let workers = ProcessInfo.processInfo.activeProcessorCount * 2
        all.withUnsafeBufferPointer { allBuffer in
        crossingEdges.withUnsafeBufferPointer { crossingBuffer in
        crossingStore.withUnsafeBufferPointer { storeBuffer in
        accumulated.withUnsafeMutableBufferPointer { fitBuffer in
            nonisolated(unsafe) let all = allBuffer, crossing = crossingBuffer, store = storeBuffer, fits = fitBuffer
            DispatchQueue.concurrentPerform(iterations: workers) { worker in
                var n = 0
                while n < crossing.count {
                    let edge = all[crossing[n]]
                    n += 1
                    let a = edge.around
                    // Each distinct leaf around the edge once
                    let mine0 = a.0 >= 0 && a.0 % workers == worker
                    let mine1 = a.1 >= 0 && a.1 % workers == worker && a.1 != a.0
                    let mine2 = a.2 >= 0 && a.2 % workers == worker && a.2 != a.0 && a.2 != a.1
                    let mine3 = a.3 >= 0 && a.3 % workers == worker && a.3 != a.0 && a.3 != a.1 && a.3 != a.2
                    guard mine0 || mine1 || mine2 || mine3 else { continue }
                    let result = store[Int(self.knownCrossings.value(for: Self.spanKey(edge.key, length: edge.length))!)]
                    if mine0 { fits[a.0].add(point: result.point, normal: result.normal) }
                    if mine1 { fits[a.1].add(point: result.point, normal: result.normal) }
                    if mine2 { fits[a.2].add(point: result.point, normal: result.normal) }
                    if mine3 { fits[a.3].add(point: result.point, normal: result.normal) }
                }
            }
        }
        }
        }
        }
        for (leaf, merge) in merges where leaf < accumulated.count {
            accumulated[leaf] = merge.fit
        }
        fits = accumulated
        fittedEdges = (all, crossingEdges)
    }

    // MARK: - Components

    private static let cubeEdges = [(0, 1), (2, 3), (4, 5), (6, 7), (0, 2), (1, 3), (4, 6), (5, 7), (0, 4), (1, 5), (2, 6), (3, 7)]

    /// Whether the surface may pass a cube cell more than once: that takes at least six crossing edges. A quick
    /// check without allocations, since it runs for every leaf.
    private func mayHaveSeveralComponents(_ i: Int, _ j: Int, _ k: Int, size: Int) -> Bool {
        var inside: UInt8 = 0
        var c = 0
        while c < 8 {
            if gridValue(i + (c & 1) * size, j + (c >> 1 & 1) * size, k + (c >> 2 & 1) * size) < 0 { inside |= 1 << UInt8(c) }
            c += 1
        }
        // Corners differ along an axis where their bits differ in that axis
        var crossings = 0
        var axis = 0
        while axis < 3 {
            let bit = 1 << axis
            c = 0
            while c < 8 {
                if c & bit == 0 && ((inside >> UInt8(c)) & 1) != ((inside >> UInt8(c | bit)) & 1) { crossings += 1 }
                c += 1
            }
            axis += 1
        }
        return crossings >= 6
    }

    /// Surface components through a cube cell, as groups of its twelve edges: crossing edges on a common face
    /// connect, and an ambiguous face (alternating corners) is resolved by the sign at its center
    private func components(_ i: Int, _ j: Int, _ k: Int, size: Int) -> [[Int]] {
        var inside = [Bool](repeating: false, count: 8)
        for c in 0..<8 {
            inside[c] = gridValue(i + (c & 1) * size, j + (c >> 1 & 1) * size, k + (c >> 2 & 1) * size) < 0
        }
        let crossing = Self.cubeEdges.map { inside[$0.0] != inside[$0.1] }
        let crossingCount = crossing.filter { $0 }.count
        if crossingCount < 6 {
            return crossingCount > 0 ? [crossing.indices.filter { crossing[$0] }] : []
        }
        var parent = Array(0..<12)
        func root(_ x: Int) -> Int {
            var x = x
            while parent[x] != x { parent[x] = parent[parent[x]]; x = parent[x] }
            return x
        }
        func unite(_ a: Int, _ b: Int) { parent[root(a)] = root(b) }

        for axis in 0..<3 {
            for side in 0..<2 {
                let faceEdges = (0..<12).filter { e in
                    let (c0, c1) = Self.cubeEdges[e]
                    return (c0 >> axis & 1) == side && (c1 >> axis & 1) == side
                }
                let crossingEdges = faceEdges.filter { crossing[$0] }
                if crossingEdges.count == 2 {
                    unite(crossingEdges[0], crossingEdges[1])
                } else if crossingEdges.count == 4 {
                    let s = Double(size) * unit
                    var center = point(i, j, k) + Vector3D(s / 2, s / 2, s / 2)
                    let axisName: Axis3D = axis == 0 ? .x : axis == 1 ? .y : .z
                    center = center.with(axisName, as: point(i, j, k)[axis] + Double(side) * s)
                    let centerInside = value(at: center) < 0
                    // The corners sharing the center's sign connect through it, so each corner of the other sign is
                    // cut off by its own two edges
                    for c in 0..<8 where (c >> axis & 1) == side && inside[c] != centerInside {
                        let incident = faceEdges.filter { Self.cubeEdges[$0].0 == c || Self.cubeEdges[$0].1 == c }
                        if incident.count == 2 { unite(incident[0], incident[1]) }
                    }
                }
            }
        }
        var groups: [Int: [Int]] = [:]
        for e in 0..<12 where crossing[e] { groups[root(e), default: []].append(e) }
        return Array(groups.values)
    }

    // MARK: - Refinement and simplification

    /// Splits cells whose planes no single vertex inside fits well (a feature smaller than the cell, such as a thin
    /// spike), or that a thin plate passes twice
    private func refine() {
        for _ in 0..<MeshOffset.refinementLevels {
            let flags = octree.leaves.withUnsafeBufferPointer { leafBuffer in
                fits.withUnsafeBufferPointer { fitBuffer in
                    nonisolated(unsafe) let leaves = leafBuffer, fits = fitBuffer
                    return ConcurrentLoop.map(leaves.count) { index -> Bool in
                        let leaf = leaves[index]
                        guard leaf.size > 1, leaf.size <= self.unitsPerCell, fits[index].count > 0 else { return false }
                        let x = fits[index].solve()
                        let lower = self.point(leaf.i, leaf.j, leaf.k), extent = Double(leaf.size) * self.unit
                        let low = lower - Vector3D(0.1, 0.1, 0.1) * extent, high = lower + Vector3D(1.1, 1.1, 1.1) * extent
                        let outside = x.x < low.x || x.y < low.y || x.z < low.z || x.x > high.x || x.y > high.y || x.z > high.z
                        return outside || fits[index].rootMeanSquareError(at: x) > self.tolerance
                            || (self.mayHaveSeveralComponents(leaf.i, leaf.j, leaf.k, size: leaf.size)
                                && self.components(leaf.i, leaf.j, leaf.k, size: leaf.size).count > 1)
                    }
                }
            }
            var poor: [Int] = []
            var n = 0
            while n < flags.count { if flags[n] { poor.append(n) }; n += 1 }
            if poor.isEmpty { break }
            split(leaves: poor)
            balance()
            computeFits()
        }
    }

    /// A node whose children are all leaves becomes one leaf when a single vertex fits all their planes within the
    /// tolerance, keeps the tree balanced, and merging can't change the topology
    private func simplify() {
        guard tolerance > 0 else { return }
        // Nodes with children, by size: merging only ever removes children, so these are all the candidates
        var bySize: [Int: [Int]] = [:]
        octree.nodes.withUnsafeBufferPointer { nodes in
            var index = 0
            while index < nodes.count {
                let node = nodes[index]
                if node.child >= 0 && node.size <= coarsest { bySize[node.size, default: []].append(index) }
                index += 1
            }
        }
        var size = 2
        while size <= coarsest {
            let decisions = octree.nodes.withUnsafeBufferPointer { nodeBuffer in
                fits.withUnsafeBufferPointer { fitBuffer in
                    nonisolated(unsafe) let nodes = nodeBuffer, fits = fitBuffer
                    let extent = octree.extent
                    // Those whose children are all leaves (or empty)
                    var level: [Int] = []
                    for index in bySize[size] ?? [] {
                        let child = nodes[index].child
                        var c = 0
                        while c < 8 && nodes[child + c].child < 0 { c += 1 }
                        if c == 8 { level.append(index) }
                    }
                    let candidates = level
                    let fitted = ConcurrentLoop.map(candidates.count) { n -> PlaneFit? in
                        self.mergedFit(node: nodes[candidates[n]], index: candidates[n], nodes: nodes, extent: extent, fits: fits)
                    }
                    return zip(candidates, fitted).compactMap { index, fit in fit.map { (index, $0) } }
                }
            }
            for (index, fit) in decisions {
                let node = octree.nodes[index]
                var c = 0
                while c < 8 {
                    let leaf = octree.nodes[node.child + c].leaf
                    if leaf >= 0 { octree.leaves[leaf].size = 0 }
                    c += 1
                }
                let leafIndex = octree.leaves.count
                merges[leafIndex] = (index, node.child, fit)
                octree.nodes[index].child = -1
                octree.makeLeaf(node: index, hint: octree.nodes[node.child].leaf >= 0 ? octree.leaves[octree.nodes[node.child].leaf].hint : -1)
                fits.append(fit)
            }
            size *= 2
        }
    }

    private func mergedFit(node: OffsetOctree.Node, index: Int, nodes: UnsafeBufferPointer<OffsetOctree.Node>, extent: Int, fits: UnsafeBufferPointer<PlaneFit>) -> PlaneFit? {
        var fit = PlaneFit()
        var c = 0
        while c < 8 {
            let leaf = nodes[node.child + c].leaf
            if leaf >= 0 { fit.add(fits[leaf]) }
            c += 1
        }
        guard fit.count > 0 else { return nil }

        // Signs on the node's 3x3x3 lattice: the children's corners, mostly sampled already. Checked over a
        // temporary buffer with counted loops, since this runs for every node in unoptimized builds too.
        let half = node.size / 2
        let topologyKept = withUnsafeTemporaryAllocation(of: Bool.self, capacity: 54) { buffer -> Bool in
            let sign = buffer.baseAddress!, seen = sign + 27
            var hint: Int? = nil
            var n = 0
            while n < 27 {
                let (i, j, k) = (node.i + n % 3 * half, node.j + n / 3 % 3 * half, node.k + n / 9 * half)
                if let known = knownValues.value(for: Self.key(i, j, k)) {
                    sign[n] = known < 0
                } else {
                    let result = self.sample(at: point(i, j, k), hint: hint)
                    sign[n] = result.value < 0
                    hint = result.face
                }
                n += 1
            }
            func at(_ x: Int, _ y: Int, _ z: Int) -> Bool { sign[x + y * 3 + z * 9] }
            // Lattice coordinates with the given axis, and the two after it, set
            func index(axis: Int, _ a: Int, _ u: Int, _ v: Int) -> Int {
                switch axis {
                case 0: return a + u * 3 + v * 9
                case 1: return v + a * 3 + u * 9
                default: return u + v * 3 + a * 9
                }
            }

            // The coarse corners must see the surface
            var insideCorners = 0
            n = 0
            while n < 8 {
                if at((n & 1) * 2, (n >> 1 & 1) * 2, (n >> 2 & 1) * 2) { insideCorners += 1 }
                n += 1
            }
            if insideCorners == 0 || insideCorners == 8 { return false }
            var axis = 0
            while axis < 3 {
                // Each coarse edge crosses at most once
                var e = 0
                while e < 4 {
                    let u = (e & 1) * 2, v = (e >> 1 & 1) * 2
                    let s0 = sign[index(axis: axis, 0, u, v)], s1 = sign[index(axis: axis, 1, u, v)], s2 = sign[index(axis: axis, 2, u, v)]
                    if s0 != s1 && s1 != s2 { return false }
                    e += 1
                }
                // Each face: at most two changes around its boundary, and no island at its center
                var side = 0
                while side <= 2 {
                    // The ring (0, 0), (1, 0), (2, 0), (2, 1), (2, 2), (1, 2), (0, 2), (0, 1) around the face
                    var changes = 0
                    var m = 0
                    while m < 8 {
                        let r0 = m, r1 = (m + 1) % 8
                        let x0 = r0 < 3 ? r0 : r0 < 5 ? 2 : r0 < 7 ? 6 - r0 : 0, y0 = r0 < 3 ? 0 : r0 < 5 ? r0 - 2 : r0 < 7 ? 2 : 1
                        let x1 = r1 < 3 ? r1 : r1 < 5 ? 2 : r1 < 7 ? 6 - r1 : 0, y1 = r1 < 3 ? 0 : r1 < 5 ? r1 - 2 : r1 < 7 ? 2 : 1
                        if sign[index(axis: axis, side, x0, y0)] != sign[index(axis: axis, side, x1, y1)] { changes += 1 }
                        m += 1
                    }
                    if changes > 2 { return false }
                    if changes == 0 && sign[index(axis: axis, side, 1, 1)] != sign[index(axis: axis, side, 0, 0)] { return false }
                    side += 2
                }
                axis += 1
            }
            // Inside and outside samples each form one connected region
            return withUnsafeTemporaryAllocation(of: Int.self, capacity: 27) { stack in
                for wanted in [false, true] {
                    var members = 0, start = -1
                    n = 0
                    while n < 27 {
                        seen[n] = false
                        if sign[n] == wanted { members += 1; if start < 0 { start = n } }
                        n += 1
                    }
                    guard start >= 0 else { continue }
                    var top = 1
                    stack[0] = start
                    seen[start] = true
                    var reached = 0
                    while top > 0 {
                        top -= 1
                        let n = stack[top]
                        reached += 1
                        let x = n % 3, y = n / 3 % 3, z = n / 9
                        var d = 0
                        while d < 6 {
                            let step = d / 2, forward = d % 2 == 0
                            d += 1
                            let coordinate = step == 0 ? x : step == 1 ? y : z
                            if forward ? coordinate == 2 : coordinate == 0 { continue }
                            let m = n + (forward ? 1 : -1) * (step == 0 ? 1 : step == 1 ? 3 : 9)
                            if !seen[m] && sign[m] == wanted { seen[m] = true; stack[top] = m; top += 1 }
                        }
                    }
                    if reached != members { return false }
                }
                return true
            }
        }
        if !topologyKept { return nil }
        // One vertex must fit within the tolerance, inside the node
        let x = fit.solve()
        let lower = point(node.i, node.j, node.k), span = Double(node.size) * unit
        let upper = lower + Vector3D(span, span, span)
        if x.x < lower.x - 0.1 * unit || x.y < lower.y - 0.1 * unit || x.z < lower.z - 0.1 * unit
            || x.x > upper.x + 0.1 * unit || x.y > upper.y + 0.1 * unit || x.z > upper.z + 0.1 * unit { return nil }
        if fit.rootMeanSquareError(at: x) > tolerance { return nil }
        // Merging must keep the tree balanced
        if OffsetOctree.hasMuchSmallerNeighbor(node.i, node.j, node.k, size: node.size, near: index, in: nodes, extent: extent) { return nil }
        if abs(value(at: x)) > tolerance { return nil }
        return fit
    }

    // MARK: - Contouring

    private struct Contour {
        var vertices: [Vector3D] = []
        var faces: [Face] = []
        var leafOfVertex: [Int] = []
    }

    private func contour(reusingFitEdges: Bool = false) -> Contour {
        var result = Contour()
        let leaves = octree.leaves
        var vertexOfLeaf = [Int](repeating: -1, count: leaves.count)
        // Each leaf's vertex, solved on every core; nil for leaves without one
        struct Placement { let x: Vector3D?; }
        let placements = leaves.withUnsafeBufferPointer { leafBuffer in
            fits.withUnsafeBufferPointer { fitBuffer in
                nonisolated(unsafe) let leaves = leafBuffer, fits = fitBuffer
                return ConcurrentLoop.map(leaves.count) { index -> Placement in
                    let leaf = leaves[index]
                    guard leaf.size > 0 && fits[index].count > 0 else { return Placement(x: nil) }
                    let span = Double(leaf.size) * self.unit
                    let lower = self.point(leaf.i, leaf.j, leaf.k), upper = lower + Vector3D(span, span, span)
                    let margin = 0.5 * self.unit
                    let x = fits[index].solve()
                    if x.x < lower.x - margin || x.y < lower.y - margin || x.z < lower.z - margin
                        || x.x > upper.x + margin || x.y > upper.y + margin || x.z > upper.z + margin {
                        return Placement(x: fits[index].solve(within: lower, upper))
                    }
                    return Placement(x: x)
                }
            }
        }
        var index = 0
        while index < placements.count {
            if let x = placements[index].x {
                vertexOfLeaf[index] = result.vertices.count
                result.vertices.append(x)
                result.leafOfVertex.append(index)
            }
            index += 1
        }

        // Grid-unit cells that a thin plate passes twice get one vertex per surface component
        var componentVertex: [Int: [UInt64: Int]] = [:]
        for index in leaves.indices where leaves[index].size == 1 && vertexOfLeaf[index] >= 0 {
            let leaf = leaves[index]
            guard mayHaveSeveralComponents(leaf.i, leaf.j, leaf.k, size: 1) else { continue }
            let groups = components(leaf.i, leaf.j, leaf.k, size: 1)
            guard groups.count > 1 else { continue }
            for group in groups {
                var fit = PlaneFit()
                var keys: [UInt64] = []
                for e in group {
                    let (c0, c1) = Self.cubeEdges[e]
                    let axis = (0..<3).first { ((c0 ^ c1) >> $0) & 1 == 1 }!
                    let key = Self.edgeKey(leaf.i + (c0 & 1), leaf.j + (c0 >> 1 & 1), leaf.k + (c0 >> 2 & 1), axis: axis)
                    keys.append(key)
                    if let stored = crossingIndex.value(for: Self.spanKey(key, length: 1)) {
                        let hit = crossingStore[Int(stored)]
                        fit.add(point: hit.point, normal: hit.normal)
                    }
                }
                guard fit.count > 0 else { continue }
                let lower = point(leaf.i, leaf.j, leaf.k)
                var x = fit.solve()
                if (0..<3).contains(where: { x[$0] < lower[$0] || x[$0] > lower[$0] + unit }) {
                    x = fit.solve(within: lower, lower + Vector3D(unit, unit, unit))
                }
                let vertex = result.vertices.count
                result.vertices.append(x)
                result.leafOfVertex.append(index)
                for key in keys { componentVertex[index, default: [:]][key] = vertex }
            }
        }

        // The edges the last fit found crossing, when the tree hasn't changed since; otherwise found again
        let edges: [Edge], crossing: [Int]
        if reusingFitEdges, let fitted = fittedEdges {
            (edges, crossing) = (fitted.edges, fitted.crossing)
        } else {
            edges = minimalEdges()
            crossing = edges.indices.filter { crosses(edges[$0]).crosses }
        }
        // A quad around each crossing edge, from the vertices of the four leaves around it, in plain values rather
        // than small arrays: there's one per crossing edge
        for index in crossing {
            let edge = edges[index]
            let rising = crosses(edge).rising
            let around = rising ? edge.around : (edge.around.0, edge.around.3, edge.around.2, edge.around.1)
            func vertex(_ leaf: Int) -> Int {
                guard leaf >= 0, vertexOfLeaf[leaf] >= 0 else { return -1 }
                if !componentVertex.isEmpty, let specific = componentVertex[leaf]?[edge.key] { return specific }
                return vertexOfLeaf[leaf]
            }
            let v0 = vertex(around.0), v1 = vertex(around.1), v2 = vertex(around.2), v3 = vertex(around.3)
            guard v0 >= 0, v1 >= 0, v2 >= 0, v3 >= 0 else { continue }
            // Consecutive leaves can share a vertex (a larger leaf spans two quadrants): drop the repeats
            var ring = (v0, -1, -1, -1), count = 1
            var k = 1
            while k < 4 {
                let v = k == 1 ? v1 : k == 2 ? v2 : v3
                k += 1
                if v == (count == 1 ? ring.0 : count == 2 ? ring.1 : ring.2) { continue }
                if count == 1 { ring.1 = v } else if count == 2 { ring.2 = v } else { ring.3 = v }
                count += 1
            }
            let last = count == 2 ? ring.1 : count == 3 ? ring.2 : ring.3
            if count > 1 && last == ring.0 { count -= 1 }
            if count == 3 {
                result.faces.append((ring.0, ring.1, ring.2))
            } else if count == 4 {
                result.faces.append((ring.0, ring.1, ring.2))
                result.faces.append((ring.0, ring.2, ring.3))
            }
        }
        return result
    }

    /// Contours, and where two sheets share an edge (used by more than two triangles), unmerges or splits the cells
    /// involved and contours again
    private func contourWithRepair() -> Contour {
        var result = contour()
        var previous = Int.max
        for _ in 0..<12 {
            let fans = VertexFans(faces: result.faces, vertexCount: result.vertices.count)
            var culprits = Set<Int>()
            for (a, b) in fans.irregularEdges(in: result.faces) where fans.faces(around: a, with: b, in: result.faces).count > 2 {
                culprits.insert(result.leafOfVertex[a])
                culprits.insert(result.leafOfVertex[b])
            }
            // Each round fits and contours everything again. Where the culprits don't at least halve, the rest are
            // sheets that genuinely touch, which clean-up separates just as well, so stop there.
            if culprits.isEmpty || culprits.count > previous / 2 { break }
            previous = culprits.count

            var acted = false, refit = false
            var toSplit = Set<Int>()
            for index in culprits.sorted() {
                if let merge = merges.removeValue(forKey: index) {
                    octree.nodes[merge.node].child = merge.child
                    octree.nodes[merge.node].leaf = -1
                    octree.leaves[index].size = 0
                    for c in 0..<8 {
                        let child = octree.nodes[merge.child + c]
                        if child.leaf >= 0 { octree.leaves[child.leaf].size = child.size }
                    }
                    acted = true
                } else if octree.leaves[index].size > 1 {
                    // A thin plate usually runs on through the neighbors too: split those along with it
                    let leaf = octree.leaves[index]
                    var neighbors = Set<Int>()
                    for dx in -1...1 {
                        for dy in -1...1 {
                            for dz in -1...1 {
                                let found = octree.locate(
                                    Double(leaf.i) + (Double(dx) + 0.5) * Double(leaf.size),
                                    Double(leaf.j) + (Double(dy) + 0.5) * Double(leaf.size),
                                    Double(leaf.k) + (Double(dz) + 0.5) * Double(leaf.size)
                                )
                                if let other = found.leaf, other != index, merges[other] == nil { neighbors.insert(other) }
                            }
                        }
                    }
                    toSplit.insert(index)
                    for other in neighbors where octree.leaves[other].size > 1 { toSplit.insert(other) }
                    acted = true
                    refit = true
                }
            }
            // All at once, so their sampling runs in parallel; leaves unmerged meanwhile have no size left
            split(leaves: toSplit.sorted().filter { octree.leaves[$0].size > 1 })
            guard acted else { break }
            // Unmerged children were out of reach of the last fit, so fit again either way
            if refit { balance() }
            computeFits()
            result = contour(reusingFitEdges: true)
        }
        return result
    }

    // MARK: - Clean-up

    /// Removes fins (two copies of a triangle facing opposite ways, enclosing nothing), then separates sheets that
    /// touch along an edge or at a vertex: around a shared edge, each triangle pairs with its neighbor across a wedge
    /// of solid, and each vertex gets one copy per fan of triangles connected through edges
    private static func cleanedUp(_ contour: Contour) -> (vertices: [Vector3D], faces: [Face]) {
        var result = (vertices: contour.vertices, faces: contour.faces)
        // Separating one configuration can expose another, so repeat until every edge has two faces, and end on a
        // separation, which also splits the vertices cutting fans pinches
        for round in 0..<4 {
            result = separated(vertices: result.vertices, faces: result.faces)
            if round == 3 || VertexFans(faces: result.faces, vertexCount: result.vertices.count).irregularEdges(in: result.faces).isEmpty { break }
            result = cutLoopedFans(vertices: result.vertices, faces: result.faces)
        }
        return result
    }

    /// An edge still shared by four triangles after separating has an end whose fan loops through the other end
    /// twice. Cutting that fan at the edge leaves two arcs from the other end back to it; one of them gets its own
    /// copy of the vertex.
    private static func cutLoopedFans(vertices: [Vector3D], faces: [Face]) -> (vertices: [Vector3D], faces: [Face]) {
        var vertices = vertices
        var faces = faces
        // Everything is decided on the faces as they are; renaming as we go would hide edges from later ones
        let original = faces
        let fans = VertexFans(faces: original, vertexCount: vertices.count)
        func corners(_ index: Int) -> [Int] { [original[index].0, original[index].1, original[index].2] }
        var touched = Set<Int>()
        for (a, b) in fans.irregularEdges(in: original) where fans.faces(around: a, with: b, in: original).count == 4 {
            for (v, w) in [(a, b), (b, a)] {
                guard !touched.contains(v), !touched.contains(w) else { break }
                // Group v's triangles through shared edges other than v-w
                let fan = Array(fans.members[fans.offsets[v]..<fans.offsets[v + 1]])
                var parent = Array(fan.indices)
                func root(_ x: Int) -> Int {
                    var x = x
                    while parent[x] != x { parent[x] = parent[parent[x]]; x = parent[x] }
                    return x
                }
                var slot: [Int: Int] = [:]
                for (n, face) in fan.enumerated() { slot[face] = n }
                for (n, face) in fan.enumerated() {
                    for u in corners(face) where u != v && u != w {
                        let shared = fans.faces(around: v, with: u, in: original)
                        guard shared.count == 2 else { continue }
                        let other = shared[0] == face ? shared[1] : shared[0]
                        if let m = slot[other] { parent[root(n)] = root(m) }
                    }
                }
                // Ordered by their first triangle, so which arc gets the copy doesn't change from run to run
                let arcs = Dictionary(grouping: fan.indices, by: root).values.map { $0.map { fan[$0] } }.sorted { $0[0] < $1[0] }
                guard arcs.count == 2 else { continue }
                // Each arc must hold one triangle of the edge each way
                let balanced = arcs.allSatisfy { arc in
                    let directed = arc.flatMap { index in
                        let c = corners(index)
                        return (0..<3).map { (c[$0], c[($0 + 1) % 3]) }
                    }
                    return directed.filter { $0 == (v, w) }.count == 1 && directed.filter { $0 == (w, v) }.count == 1
                }
                guard balanced else { continue }
                let copy = vertices.count
                vertices.append(vertices[v])
                for face in arcs[1] {
                    if faces[face].0 == v { faces[face].0 = copy }
                    if faces[face].1 == v { faces[face].1 = copy }
                    if faces[face].2 == v { faces[face].2 = copy }
                }
                touched.insert(v)
                touched.insert(w)
                break
            }
        }
        return (vertices, faces)
    }

    /// The triangles around each vertex, in one flat array: no allocation per vertex, and safe to read from every core
    private struct VertexFans {
        let offsets: [Int]
        let members: [Int]

        init(faces: [Face], vertexCount: Int) {
            var counts = [Int](repeating: 0, count: vertexCount + 1)
            for face in faces { counts[face.0 + 1] += 1; counts[face.1 + 1] += 1; counts[face.2 + 1] += 1 }
            for v in 0..<vertexCount { counts[v + 1] += counts[v] }
            var next = counts
            var members = [Int](repeating: 0, count: 3 * faces.count)
            for (index, face) in faces.enumerated() {
                members[next[face.0]] = index; next[face.0] += 1
                members[next[face.1]] = index; next[face.1] += 1
                members[next[face.2]] = index; next[face.2] += 1
            }
            offsets = counts
            self.members = members
        }

        /// Runs body with the offsets and members as buffers, which concurrent loops can read without retaining them
        func withBuffers<R>(_ body: (UnsafeBufferPointer<Int>, UnsafeBufferPointer<Int>) -> R) -> R {
            offsets.withUnsafeBufferPointer { offsets in members.withUnsafeBufferPointer { members in body(offsets, members) } }
        }

        /// The triangles around v that also have w as a corner
        func faces(around v: Int, with w: Int, in faces: [Face]) -> [Int] {
            var found: [Int] = []
            for n in offsets[v]..<offsets[v + 1] {
                let face = faces[members[n]]
                if face.0 == w || face.1 == w || face.2 == w { found.append(members[n]) }
            }
            return found
        }

        /// Edges used by other than two triangles, as (lower, higher) vertex pairs
        func irregularEdges(in faces: [Face]) -> [(Int, Int)] {
            let vertexCount = offsets.count - 1
            return offsets.withUnsafeBufferPointer { offsetBuffer in
            members.withUnsafeBufferPointer { memberBuffer in
            faces.withUnsafeBufferPointer { faceBuffer in
                nonisolated(unsafe) let offsets = offsetBuffer, members = memberBuffer, faces = faceBuffer
                return ConcurrentLoop.collect(vertexCount) { (v: Int, found: inout [(Int, Int)]) in
                    let first = offsets[v], end = offsets[v + 1]
                    var n = first
                    while n < end {
                        let face = faces[members[n]]
                        var k = 0
                        while k < 3 {
                            let w = k == 0 ? face.0 : k == 1 ? face.1 : face.2
                            k += 1
                            guard w > v else { continue }
                            // Counted once, at its first triangle around v
                            var uses = 0, earlier = false
                            var m = first
                            while m < end {
                                let other = faces[members[m]]
                                if other.0 == w || other.1 == w || other.2 == w {
                                    if m < n { earlier = true }
                                    uses += 1
                                }
                                m += 1
                            }
                            if !earlier && uses != 2 { found.append((v, w)) }
                        }
                        n += 1
                    }
                }
            }
            }
            }
        }
    }

    private static func separated(vertices: [Vector3D], faces: [Face]) -> (vertices: [Vector3D], faces: [Face]) {
        var vertices = vertices
        var faces = faces.filter { $0.0 != $0.1 && $0.1 != $0.2 && $0.0 != $0.2 }
        var fans = VertexFans(faces: faces, vertexCount: vertices.count)

        // Fins: a triangle with a twin facing the other way, found around its lowest corner
        let twinned = faces.withUnsafeBufferPointer { faceBuffer in fans.withBuffers { offsetBuffer, memberBuffer in
            nonisolated(unsafe) let faces = faceBuffer, offsets = offsetBuffer, members = memberBuffer
            return ConcurrentLoop.collect(faces.count) { (index: Int, found: inout [Int]) in
                let face = faces[index]
                let lowest = face.0 < face.1 ? (face.0 < face.2 ? face.0 : face.2) : (face.1 < face.2 ? face.1 : face.2)
                var n = offsets[lowest]
                while n < offsets[lowest + 1] {
                    let other = faces[members[n]]
                    n += 1
                    guard members[n - 1] != index else { continue }
                    func has(_ w: Int) -> Bool { w == face.0 || w == face.1 || w == face.2 }
                    if has(other.0) && has(other.1) && has(other.2) { found.append(index); return }
                }
            }
        } }
        if !twinned.isEmpty {
            struct Corners: Hashable { let a: Int, b: Int, c: Int }
            var byCorners: [Corners: (up: [Int], down: [Int])] = [:]
            for index in twinned {
                let face = faces[index]
                let corners = [face.0, face.1, face.2]
                let sorted = corners.sorted()
                let minimum = corners.firstIndex(of: sorted[0])!
                let ascending = corners[(minimum + 1) % 3] < corners[(minimum + 2) % 3]
                let key = Corners(a: sorted[0], b: sorted[1], c: sorted[2])
                if ascending { byCorners[key, default: ([], [])].up.append(index) }
                else { byCorners[key, default: ([], [])].down.append(index) }
            }
            var dropped = Set<Int>()
            for (up, down) in byCorners.values {
                for n in 0..<min(up.count, down.count) { dropped.insert(up[n]); dropped.insert(down[n]) }
            }
            if !dropped.isEmpty {
                faces = faces.enumerated().filter { !dropped.contains($0.offset) }.map(\.element)
                fans = VertexFans(faces: faces, vertexCount: vertices.count)
            }
        }

        // Pair triangles around edges shared by more than two
        func corners(_ index: Int) -> [Int] { [faces[index].0, faces[index].1, faces[index].2] }
        var partner: [UInt64: [Int: Int]] = [:]
        for (a, b) in fans.irregularEdges(in: faces) {
            let sharing = fans.faces(around: a, with: b, in: faces)
            guard sharing.count > 2 else { continue }
            let key = MeshDistanceField.edgeKey(a, b)
            let axis = (vertices[b] - vertices[a]).safelyNormalized
            func third(_ index: Int) -> Int { corners(index).first { $0 != a && $0 != b }! }
            func perpendicular(_ index: Int) -> Vector3D {
                let r = vertices[third(index)] - vertices[a]
                return r - axis * (r ⋅ axis)
            }
            let reference = perpendicular(sharing[0]).safelyNormalized
            let side = axis × reference
            let ordered = sharing.map { index -> (Double, Int) in
                let p = perpendicular(index)
                var angle = Foundation.atan2(p ⋅ side, p ⋅ reference)
                if angle < 0 { angle += 2 * .pi }
                return (angle, index)
            }.sorted { $0.0 < $1.0 }.map(\.1)
            func forward(_ index: Int) -> Bool {
                let c = corners(index)
                return (0..<3).contains { c[$0] == a && c[($0 + 1) % 3] == b }
            }
            // Normals point out of the solid; turning forward about a→b, a forward triangle's front faces the turn
            for n in ordered.indices {
                let first = ordered[n], second = ordered[(n + 1) % ordered.count]
                if !forward(first) && forward(second) {
                    partner[key, default: [:]][first] = second
                    partner[key, default: [:]][second] = first
                }
            }
            // Where a tiny fold breaks the alternation, pair what's left with the nearest opposite-facing triangle, so
            // the result stays manifold
            if partner[key, default: [:]].count != ordered.count {
                for step in 1..<ordered.count {
                    for n in ordered.indices {
                        let first = ordered[n], second = ordered[(n + step) % ordered.count]
                        guard partner[key]?[first] == nil, partner[key]?[second] == nil, forward(first) != forward(second) else { continue }
                        partner[key, default: [:]][first] = second
                        partner[key, default: [:]][second] = first
                    }
                }
            }
        }

        // One vertex copy per fan of triangles connected through edges: found for every vertex at once, on the faces
        // as they are, then applied
        struct Split { let vertex: Int; let groups: [Int] }   // a group per triangle around the vertex, in fan order
        let pairs = partner
        let splits = faces.withUnsafeBufferPointer { faceBuffer in fans.withBuffers { offsetBuffer, memberBuffer in
            nonisolated(unsafe) let faces = faceBuffer, offsets = offsetBuffer, members = memberBuffer
            return ConcurrentLoop.collect(vertices.count) { (v: Int, found: inout [Split]) in
                let first = offsets[v], count = offsets[v + 1] - first
                guard count > 1 else { return }
                // Counted loops over a temporary buffer: this runs for every vertex, in unoptimized builds too
                withUnsafeTemporaryAllocation(of: Int.self, capacity: count) { parent in
                    func root(_ x: Int) -> Int {
                        var x = x
                        while parent[x] != x { parent[x] = parent[parent[x]]; x = parent[x] }
                        return x
                    }
                    var n = 0
                    while n < count { parent[n] = n; n += 1 }
                    n = 0
                    while n < count {
                        let face = faces[members[first + n]]
                        var k = 0
                        while k < 3 {
                            let w = k == 0 ? face.0 : k == 1 ? face.1 : face.2
                            k += 1
                            guard w != v else { continue }
                            // The triangles around v across the edge v-w: usually just this one and one other
                            var sharing = 0, firstOther = -1, partnerSlot = -1
                            let pairedWith = pairs.isEmpty ? nil : pairs[MeshDistanceField.edgeKey(v, w)]?[members[first + n]]
                            var m = 0
                            while m < count {
                                let other = faces[members[first + m]]
                                if other.0 == w || other.1 == w || other.2 == w {
                                    sharing += 1
                                    if m != n && firstOther < 0 { firstOther = m }
                                    if members[first + m] == pairedWith { partnerSlot = m }
                                }
                                m += 1
                            }
                            if sharing == 2 && firstOther >= 0 {
                                parent[root(n)] = root(firstOther)
                            } else if sharing > 2 && partnerSlot >= 0 {
                                parent[root(n)] = root(partnerSlot)
                            }
                        }
                        n += 1
                    }
                    let base = root(0)
                    var split = false
                    n = 1
                    while n < count { if root(n) != base { split = true }; n += 1 }
                    if split { found.append(Split(vertex: v, groups: (0..<count).map { root($0) })) }
                }
            }
        } }
        for split in splits {
            let v = split.vertex
            let first = fans.offsets[v]
            var copyOf: [Int: Int] = [split.groups[0]: v]
            for (n, group) in split.groups.enumerated() {
                let copy: Int
                if let existing = copyOf[group] {
                    copy = existing
                } else {
                    copy = vertices.count
                    vertices.append(vertices[v])
                    copyOf[group] = copy
                }
                let face = fans.members[first + n]
                if faces[face].0 == v { faces[face].0 = copy }
                if faces[face].1 == v { faces[face].1 = copy }
                if faces[face].2 == v { faces[face].2 = copy }
            }
        }
        return (vertices, faces)
    }

    // MARK: -

    func run() -> (vertices: [Vector3D], faces: [Face]) {
        buildTree()
        // Balancing only depends on the tree, so it comes before the first fit; refinement rebalances what it splits
        balance()
        computeFits()
        refine()
        simplify()
        return Self.cleanedUp(contourWithRepair())
    }
}

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
