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

    private let gridValues = GridTable()
    private struct Crossing {
        let point: Vector3D
        let normal: Vector3D
    }
    /// Crossings found so far, indexed by edge and length: an edge's crossing never changes, so refitting after splits
    /// only has to find the new ones
    private var crossingStore: [Crossing] = []
    private let crossingIndex = GridTable()
    private var fits: [PlaneFit] = []
    private var merges: [Int: (node: Int, child: Int, fit: PlaneFit)] = [:]

    init(field: MeshDistanceField, amount: Double, cellSize: Double, tolerance: Double) {
        self.field = field
        self.amount = amount
        self.tolerance = tolerance

        var lower = field.vertices.first ?? .zero, upper = lower
        for v in field.vertices { lower = .min(lower, v); upper = .max(upper, v) }
        let modelExtent = max(upper.x - lower.x, upper.y - lower.y, upper.z - lower.z) + 2 * max(0, amount)
        // Keys hold 19 bits per axis; cells grow on models too large for that at this resolution
        var cellSize = cellSize
        while (modelExtent / cellSize + 4) * Double(1 << MeshOffset.refinementLevels) > Double(MeshOffset.maximumExtent) / 2 { cellSize *= 2 }
        self.cellSize = cellSize
        unit = cellSize / Double(1 << MeshOffset.refinementLevels)

        let margin = max(0, amount) + 2 * cellSize
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

    /// The offset function: negative inside the offset solid
    private func value(at p: Vector3D) -> Double {
        field.signedDistance(at: p) - amount
    }

    private func nodeMayContainSurface(_ node: OffsetOctree.Node, hint: Int? = nil) -> (Bool, Int) {
        let half = Double(node.size) * unit / 2
        let center = point(node.i, node.j, node.k) + Vector3D(half, half, half)
        let sample = field.signedDistanceAndFace(at: center, hint: hint)
        return (abs(sample.value - amount) <= half * 3.0.squareRoot() * (1 + 1e-9), sample.face)
    }

    private func ensureValues(_ keys: [UInt64]) {
        // Plain loops and a table for duplicates: generic collection chains are slow in unoptimized builds
        var missing: [UInt64] = []
        let pending = GridTable(capacity: 1024)
        for key in keys where gridValues.value(for: key) == nil && pending.value(for: key) == nil {
            pending.set(0, for: key)
            missing.append(key)
        }
        let toCompute = missing
        let values = ConcurrentLoop.map(toCompute.count) { n in
            let (i, j, k) = Self.coordinates(toCompute[n])
            return self.value(at: self.point(i, j, k))
        }
        for (key, value) in zip(missing, values) { gridValues.set(value, for: key) }
    }

    private func gridValue(_ i: Int, _ j: Int, _ k: Int) -> Double {
        gridValues.value(for: Self.key(i, j, k)) ?? value(at: point(i, j, k))
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
            // 0: empty, 1: leaf, 2: subdivide; with the closest face at the node's center
            let level = frontier, levelHints = hints, tree = octree
            let decisions = ConcurrentLoop.map(level.count) { n -> Decision in
                let node = tree.nodes[level[n]]
                let (contains, face) = self.nodeMayContainSurface(node, hint: levelHints[n])
                guard contains else { return Decision(kind: 0, face: face) }
                if node.size == self.unitsPerCell { return Decision(kind: 1, face: face) }
                if node.size <= self.coarsest {
                    let half = Double(node.size) * self.unit / 2
                    let center = self.point(node.i, node.j, node.k) + Vector3D(half, half, half)
                    let reach = abs(self.amount) + half * 3.0.squareRoot() * (1 + 1e-9)
                    if self.field.facesAreCoplanar(within: reach, of: center) { return Decision(kind: 1, face: face) }
                }
                return Decision(kind: 2, face: face)
            }
            var next: [Int] = []
            var nextHints: [Int] = []
            for (n, index) in frontier.enumerated() {
                switch decisions[n].kind {
                case 1: octree.makeLeaf(node: index)
                case 2:
                    let first = octree.subdivide(node: index)
                    next.append(contentsOf: first..<(first + 8))
                    nextHints.append(contentsOf: repeatElement(decisions[n].face, count: 8))
                default: break
                }
            }
            frontier = next
            hints = nextHints
        }
    }

    private func split(leaf index: Int) {
        let leaf = octree.leaves[index]
        octree.leaves[index].size = 0
        octree.nodes[leaf.node].leaf = -1
        let first = octree.subdivide(node: leaf.node)
        for c in 0..<8 where nodeMayContainSurface(octree.nodes[first + c]).0 {
            octree.makeLeaf(node: first + c)
        }
    }

    /// 2:1 balance: no leaf may touch a leaf smaller than half its size
    @discardableResult
    private func balance() -> Int {
        var count = 0
        var candidates = Array(octree.leaves.indices)
        while !candidates.isEmpty {
            let tree = octree, current = candidates
            let flags = ConcurrentLoop.map(current.count) { n -> Bool in
                let leaf = tree.leaves[current[n]]
                return leaf.size >= 4 && tree.hasMuchSmallerNeighbor(leaf.i, leaf.j, leaf.k, size: leaf.size)
            }
            let split = zip(candidates, flags).filter(\.1).map(\.0)
            if split.isEmpty { break }
            // Splitting can only unbalance the split leaves' neighbors
            var next = Set<Int>()
            for index in split {
                let leaf = octree.leaves[index]
                self.split(leaf: index)
                for dx in -1...1 {
                    for dy in -1...1 {
                        for dz in -1...1 where dx != 0 || dy != 0 || dz != 0 {
                            let found = octree.locate(
                                Double(leaf.i) + (Double(dx) + 0.5) * Double(leaf.size),
                                Double(leaf.j) + (Double(dy) + 0.5) * Double(leaf.size),
                                Double(leaf.k) + (Double(dz) + 0.5) * Double(leaf.size)
                            )
                            if let neighbor = found.leaf { next.insert(neighbor) }
                        }
                    }
                }
            }
            count += split.count
            candidates = next.filter { octree.leaves[$0].size >= 4 }
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
                return OffsetOctree.locate(center.0 + Double(dx) * step, center.1 + Double(dy) * step, center.2 + Double(dz) * step, in: nodes, extent: extent)
            }
            func offset(_ axis: Int, _ sign: Int) -> (Int, Int, Int) {
                (axis == 0 ? sign : 0, axis == 1 ? sign : 0, axis == 2 ? sign : 0)
            }
            // Cells align, so the region across a face (or diagonally across an edge) the size of this leaf is either
            // covered by one node at least as large, or subdivided: one probe at its center answers for every edge
            // bordering it. Faces are indexed by axis * 2 + (positive ? 1 : 0).
            var faceNeighbor: [OffsetOctree.Location] = []
            faceNeighbor.reserveCapacity(6)
            for face in 0..<6 {
                let d = offset(face / 2, face % 2 == 1 ? 1 : -1)
                faceNeighbor.append(probe(d.0, d.1, d.2))
            }
            for axis in 0..<3 {
                let u = (axis + 1) % 3, v = (axis + 2) % 3
                for e in 0..<4 {
                    let du = e & 1, dv = e >> 1 & 1   // which side of the leaf the edge lies on, along u and v
                    let acrossU = faceNeighbor[u * 2 + du], acrossV = faceNeighbor[v * 2 + dv]
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
                        case (false, true): return acrossU.leaf ?? -1
                        case (true, false): return acrossV.leaf ?? -1
                        case (false, false): return diagonal.leaf ?? -1
                        }
                    }
                    let around = (quadrant(true, true), quadrant(false, true), quadrant(false, false), quadrant(true, false))
                    // Leaves of this size around the edge all find it; the lowest-numbered one keeps it
                    var owner = index
                    for other in [around.0, around.1, around.2, around.3] where other >= 0 && leaves[other].size == size {
                        owner = min(owner, other)
                    }
                    guard owner == index else { continue }
                    edges.append(Edge(key: Self.edgeKey(i, j, k, axis: axis), i: i, j: j, k: k, axis: axis, length: size, around: around))
                }
            }
        }
        }
        }
        var endpoints: [UInt64] = []
        endpoints.reserveCapacity(2 * edges.count)
        for edge in edges {
            let (ei, ej, ek) = edge.end
            endpoints.append(Self.key(edge.i, edge.j, edge.k))
            endpoints.append(Self.key(ei, ej, ek))
        }
        ensureValues(endpoints)
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
        var hint: Int? = nil
        for _ in 0..<40 {
            p = start + direction * t
            let sample = field.signedDistanceAndGradient(at: p, hint: hint)
            hint = sample.face
            gradient = sample.gradient
            let v = sample.value - amount
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
        let edges = minimalEdges().filter { crosses($0).crosses }
        let missing = edges.filter { crossingIndex.value(for: Self.spanKey($0.key, length: $0.length)) == nil }
        let found = ConcurrentLoop.map(missing.count) { self.crossing(on: missing[$0]) }
        for (edge, result) in zip(missing, found) {
            crossingIndex.set(Double(crossingStore.count), for: Self.spanKey(edge.key, length: edge.length))
            crossingStore.append(result)
        }
        let results = edges.map { crossingStore[Int(crossingIndex.value(for: Self.spanKey($0.key, length: $0.length))!)] }
        fits = [PlaneFit](repeating: PlaneFit(), count: octree.leaves.count)
        for (edge, result) in zip(edges, results) {
            let around = [edge.around.0, edge.around.1, edge.around.2, edge.around.3]
            for (q, leaf) in around.enumerated() where leaf >= 0 && !around[..<q].contains(leaf) {
                fits[leaf].add(point: result.point, normal: result.normal)
            }
        }
        for (leaf, merge) in merges where leaf < fits.count {
            fits[leaf] = merge.fit
        }
    }

    // MARK: - Components

    private static let cubeEdges = [(0, 1), (2, 3), (4, 5), (6, 7), (0, 2), (1, 3), (4, 6), (5, 7), (0, 4), (1, 5), (2, 6), (3, 7)]

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
            let leaves = octree.leaves, currentFits = fits
            let flags = ConcurrentLoop.map(leaves.count) { index -> Bool in
                let leaf = leaves[index]
                guard leaf.size > 1, leaf.size <= self.unitsPerCell, currentFits[index].count > 0 else { return false }
                let x = currentFits[index].solve()
                let lower = self.point(leaf.i, leaf.j, leaf.k), extent = Double(leaf.size) * self.unit
                let outside = (0..<3).contains { x[$0] < lower[$0] - 0.1 * extent || x[$0] > lower[$0] + 1.1 * extent }
                return outside || currentFits[index].rootMeanSquareError(at: x) > self.tolerance
                    || self.components(leaf.i, leaf.j, leaf.k, size: leaf.size).count > 1
            }
            let poor = leaves.indices.filter { flags[$0] }
            if poor.isEmpty { break }
            for index in poor { split(leaf: index) }
            balance()
            computeFits()
        }
    }

    /// A node whose children are all leaves becomes one leaf when a single vertex fits all their planes within the
    /// tolerance, keeps the tree balanced, and merging can't change the topology
    private func simplify() {
        guard tolerance > 0 else { return }
        var size = 2
        while size <= coarsest {
            let tree = octree
            let level = tree.nodes.indices.filter { index in
                let node = tree.nodes[index]
                guard node.size == size, node.child >= 0 else { return false }
                return (0..<8).allSatisfy { tree.nodes[node.child + $0].child < 0 }
            }
            let decisions = ConcurrentLoop.map(level.count) { n -> PlaneFit? in
                self.mergedFit(node: tree.nodes[level[n]], tree: tree)
            }
            for (n, fit) in decisions.enumerated() {
                guard let fit else { continue }
                let index = level[n]
                let node = octree.nodes[index]
                for c in 0..<8 {
                    let leaf = octree.nodes[node.child + c].leaf
                    if leaf >= 0 { octree.leaves[leaf].size = 0 }
                }
                let leafIndex = octree.leaves.count
                merges[leafIndex] = (index, node.child, fit)
                octree.nodes[index].child = -1
                octree.makeLeaf(node: index)
                fits.append(fit)
            }
            size *= 2
        }
    }

    private func mergedFit(node: OffsetOctree.Node, tree: OffsetOctree) -> PlaneFit? {
        if tree.hasMuchSmallerNeighbor(node.i, node.j, node.k, size: node.size) { return nil }
        var fit = PlaneFit()
        for c in 0..<8 {
            let leaf = tree.nodes[node.child + c].leaf
            if leaf >= 0 { fit.add(fits[leaf]) }
        }
        guard fit.count > 0 else { return nil }

        // Signs on the node's 3x3x3 lattice
        let half = node.size / 2
        var sign = [Bool](repeating: false, count: 27)
        var hint: Int? = nil
        for n in 0..<27 {
            let sample = field.signedDistanceAndFace(at: point(node.i + n % 3 * half, node.j + n / 3 % 3 * half, node.k + n / 9 * half), hint: hint)
            sign[n] = sample.value - amount < 0
            hint = sample.face
        }
        func at(_ x: Int, _ y: Int, _ z: Int) -> Bool { sign[x + y * 3 + z * 9] }

        // The coarse corners must see the surface
        let insideCorners = (0..<8).filter { at(($0 & 1) * 2, ($0 >> 1 & 1) * 2, ($0 >> 2 & 1) * 2) }.count
        if insideCorners == 0 || insideCorners == 8 { return nil }
        // Each coarse edge crosses at most once
        for axis in 0..<3 {
            let u = (axis + 1) % 3, v = (axis + 2) % 3
            for e in 0..<4 {
                var changes = 0
                var previous = false
                for t in 0..<3 {
                    var index = [0, 0, 0]
                    index[axis] = t; index[u] = (e & 1) * 2; index[v] = (e >> 1 & 1) * 2
                    let s = at(index[0], index[1], index[2])
                    if t > 0 && s != previous { changes += 1 }
                    previous = s
                }
                if changes > 1 { return nil }
            }
        }
        // Each face: at most two changes around its boundary, and no island at its center
        let ring = [(0, 0), (1, 0), (2, 0), (2, 1), (2, 2), (1, 2), (0, 2), (0, 1)]
        for axis in 0..<3 {
            let u = (axis + 1) % 3, v = (axis + 2) % 3
            for side in [0, 2] {
                func face(_ x: Int, _ y: Int) -> Bool {
                    var index = [0, 0, 0]
                    index[axis] = side; index[u] = x; index[v] = y
                    return at(index[0], index[1], index[2])
                }
                var changes = 0
                for m in 0..<8 where face(ring[m].0, ring[m].1) != face(ring[(m + 1) % 8].0, ring[(m + 1) % 8].1) {
                    changes += 1
                }
                if changes > 2 { return nil }
                if changes == 0 && face(1, 1) != face(0, 0) { return nil }
            }
        }
        // Inside and outside samples each form one connected region
        for wanted in [false, true] {
            let members = (0..<27).filter { sign[$0] == wanted }
            guard let start = members.first else { continue }
            var seen = [Bool](repeating: false, count: 27)
            var queue = [start]
            seen[start] = true
            var reached = 0
            while let n = queue.popLast() {
                reached += 1
                let x = n % 3, y = n / 3 % 3, z = n / 9
                for (dx, dy, dz) in [(1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1)] {
                    let nx = x + dx, ny = y + dy, nz = z + dz
                    guard (0...2).contains(nx), (0...2).contains(ny), (0...2).contains(nz) else { continue }
                    let m = nx + ny * 3 + nz * 9
                    if !seen[m] && sign[m] == wanted { seen[m] = true; queue.append(m) }
                }
            }
            if reached != members.count { return nil }
        }
        // One vertex must fit within the tolerance, inside the node
        let x = fit.solve()
        let lower = point(node.i, node.j, node.k), extent = Double(node.size) * unit
        if (0..<3).contains(where: { x[$0] < lower[$0] - 0.1 * unit || x[$0] > lower[$0] + extent + 0.1 * unit }) { return nil }
        if fit.rootMeanSquareError(at: x) > tolerance { return nil }
        if abs(value(at: x)) > tolerance { return nil }
        return fit
    }

    // MARK: - Contouring

    private struct Contour {
        var vertices: [Vector3D] = []
        var faces: [Face] = []
        var leafOfVertex: [Int] = []
    }

    private func contour() -> Contour {
        var result = Contour()
        let leaves = octree.leaves
        var vertexOfLeaf = [Int](repeating: -1, count: leaves.count)
        for index in leaves.indices where leaves[index].size > 0 && fits[index].count > 0 {
            let leaf = leaves[index]
            let lower = point(leaf.i, leaf.j, leaf.k), extent = Double(leaf.size) * unit
            var x = fits[index].solve()
            if (0..<3).contains(where: { x[$0] < lower[$0] - 0.5 * unit || x[$0] > lower[$0] + extent + 0.5 * unit }) {
                x = fits[index].solve(within: lower, lower + Vector3D(extent, extent, extent))
            }
            vertexOfLeaf[index] = result.vertices.count
            result.vertices.append(x)
            result.leafOfVertex.append(index)
        }

        // Grid-unit cells that a thin plate passes twice get one vertex per surface component
        var componentVertex: [Int: [UInt64: Int]] = [:]
        for index in leaves.indices where leaves[index].size == 1 && vertexOfLeaf[index] >= 0 {
            let leaf = leaves[index]
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

        for edge in minimalEdges() {
            let (crosses, rising) = crosses(edge)
            guard crosses else { continue }
            var order = [edge.around.0, edge.around.1, edge.around.2, edge.around.3]
            if !rising { order.swapAt(1, 3) }
            var ring: [Int] = []
            var complete = true
            for leaf in order {
                guard leaf >= 0, vertexOfLeaf[leaf] >= 0 else { complete = false; break }
                var vertex = vertexOfLeaf[leaf]
                if let specific = componentVertex[leaf]?[edge.key] { vertex = specific }
                if ring.last != vertex { ring.append(vertex) }
            }
            guard complete else { continue }
            if ring.count > 1 && ring.last == ring.first { ring.removeLast() }
            if ring.count == 3 {
                result.faces.append((ring[0], ring[1], ring[2]))
            } else if ring.count == 4 {
                result.faces.append((ring[0], ring[1], ring[2]))
                result.faces.append((ring[0], ring[2], ring[3]))
            }
        }
        return result
    }

    /// Contours, and where two sheets share an edge (used by more than two triangles), unmerges or splits the cells
    /// involved and contours again
    private func contourWithRepair() -> Contour {
        var result = contour()
        for _ in 0..<12 {
            var uses: [UInt64: Int] = [:]
            for face in result.faces {
                for (a, b) in [(face.0, face.1), (face.1, face.2), (face.2, face.0)] {
                    uses[MeshDistanceField.edgeKey(a, b), default: 0] += 1
                }
            }
            var culprits = Set<Int>()
            for (key, count) in uses where count > 2 {
                culprits.insert(result.leafOfVertex[Int(key >> 32)])
                culprits.insert(result.leafOfVertex[Int(key & 0xffffffff)])
            }
            if culprits.isEmpty { break }

            var acted = false, refit = false
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
                    split(leaf: index)
                    for other in neighbors.sorted() where octree.leaves[other].size > 1 { split(leaf: other) }
                    acted = true
                    refit = true
                }
            }
            guard acted else { break }
            // Unmerged children were out of reach of the last fit, so fit again either way
            if refit { balance() }
            computeFits()
            result = contour()
        }
        return result
    }

    // MARK: - Clean-up

    /// Removes fins (two copies of a triangle facing opposite ways, enclosing nothing), then separates sheets that
    /// touch along an edge or at a vertex: around a shared edge, each triangle pairs with its neighbor across a wedge
    /// of solid, and each vertex gets one copy per fan of triangles connected through edges
    private static func cleanedUp(_ contour: Contour) -> (vertices: [Vector3D], faces: [Face]) {
        var vertices = contour.vertices
        var faces = contour.faces.filter { $0.0 != $0.1 && $0.1 != $0.2 && $0.0 != $0.2 }

        // Fins
        struct Corners: Hashable { let a: Int, b: Int, c: Int }
        var byCorners: [Corners: (up: [Int], down: [Int])] = [:]
        for (index, face) in faces.enumerated() {
            let sorted = [face.0, face.1, face.2].sorted()
            let minimum = [face.0, face.1, face.2].firstIndex(of: sorted[0])!
            let corners = [face.0, face.1, face.2]
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
        }

        // Pair triangles around edges shared by more than two
        var facesOfEdge: [UInt64: [Int]] = [:]
        for (index, face) in faces.enumerated() {
            for (a, b) in [(face.0, face.1), (face.1, face.2), (face.2, face.0)] {
                facesOfEdge[MeshDistanceField.edgeKey(a, b), default: []].append(index)
            }
        }
        func corners(_ index: Int) -> [Int] { [faces[index].0, faces[index].1, faces[index].2] }
        var partner: [UInt64: [Int: Int]] = [:]
        for (key, sharing) in facesOfEdge where sharing.count > 2 {
            let a = Int(key >> 32), b = Int(key & 0xffffffff)
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
        }

        // One vertex copy per fan
        var incident = [[Int]](repeating: [], count: vertices.count)
        for (index, face) in faces.enumerated() {
            incident[face.0].append(index); incident[face.1].append(index); incident[face.2].append(index)
        }
        for v in 0..<incident.count where incident[v].count > 1 {
            let fan = incident[v]
            var parent = Array(fan.indices)
            func root(_ x: Int) -> Int {
                var x = x
                while parent[x] != x { parent[x] = parent[parent[x]]; x = parent[x] }
                return x
            }
            var slot: [Int: Int] = [:]
            for (n, face) in fan.enumerated() { slot[face] = n }
            for (n, face) in fan.enumerated() {
                for w in corners(face) where w != v {
                    let key = MeshDistanceField.edgeKey(v, w)
                    guard let sharing = facesOfEdge[key] else { continue }
                    if sharing.count == 2 {
                        let other = sharing[0] == face ? sharing[1] : sharing[0]
                        if let m = slot[other] { parent[root(n)] = root(m) }
                    } else if let other = partner[key]?[face], let m = slot[other] {
                        parent[root(n)] = root(m)
                    }
                }
            }
            var copyOf: [Int: Int] = [:]
            for (n, face) in fan.enumerated() {
                let group = root(n)
                let copy: Int
                if let existing = copyOf[group] {
                    copy = existing
                } else if copyOf.isEmpty {
                    copy = v
                    copyOf[group] = v
                } else {
                    copy = vertices.count
                    vertices.append(vertices[v])
                    copyOf[group] = copy
                }
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
