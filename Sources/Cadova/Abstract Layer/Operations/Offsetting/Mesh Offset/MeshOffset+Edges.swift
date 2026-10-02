import Foundation

extension MeshOffset {
    struct Crossing {
        let point: Vector3D
        let normal: Vector3D
    }

    struct Edge {
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
    func minimalEdges() -> [Edge] {
        let tree = octree
        // Every leaf's corner values first: only edges the surface crosses matter, and a leaf's edges run between its
        // corners, so where those all agree in sign, there's nothing to look up around the leaf
        tree.leaves.withUnsafeBufferPointer { leafBuffer in
            nonisolated(unsafe) let leaves = leafBuffer
            ensureValues(leaves.count, pointsEach: 8) { n, corner in
                let leaf = leaves[n]
                let size = leaf.size
                return Request(key: Self.key(leaf.i + (corner & 1) * size, leaf.j + (corner >> 1 & 1) * size, leaf.k + (corner >> 2 & 1) * size), hint: leaf.hint)
            }
        }
        let edges = tree.nodes.withUnsafeBufferPointer { nodeBuffer in
        tree.leaves.withUnsafeBufferPointer { leafBuffer in
        nonisolated(unsafe) let nodes = nodeBuffer, leaves = leafBuffer
        let extent = tree.extent
        return ConcurrentLoop.collect(leaves.count) { (index: Int, edges: inout [Edge]) in
            let leaf = leaves[index]
            guard leaf.size > 0 else { return }
            let size = leaf.size
            // The corners inside, as bits indexed by x + 2y + 4z
            var inside = 0
            var corner = 0
            while corner < 8 {
                let key = Self.key(leaf.i + (corner & 1) * size, leaf.j + (corner >> 1 & 1) * size, leaf.k + (corner >> 2 & 1) * size)
                if self.knownValues.value(for: key)! < 0 { inside |= 1 << corner }
                corner += 1
            }
            guard inside != 0 && inside != 255 else { return }
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
            // Looked up once each, when an edge first needs them. Six plain values rather than an array: this runs
            // for every leaf, in unoptimized builds too.
            let unknown = OffsetOctree.Location(leaf: nil, size: -1)
            var n0 = unknown, n1 = unknown, n2 = unknown, n3 = unknown, n4 = unknown, n5 = unknown
            func faceNeighbor(_ face: Int) -> OffsetOctree.Location {
                switch face {
                case 0: if n0.size < 0 { n0 = probe(-1, 0, 0) }; return n0
                case 1: if n1.size < 0 { n1 = probe(1, 0, 0) }; return n1
                case 2: if n2.size < 0 { n2 = probe(0, -1, 0) }; return n2
                case 3: if n3.size < 0 { n3 = probe(0, 1, 0) }; return n3
                case 4: if n4.size < 0 { n4 = probe(0, 0, -1) }; return n4
                default: if n5.size < 0 { n5 = probe(0, 0, 1) }; return n5
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
                    // Its ends' corners: offset by du along u and dv along v, and at either end along the axis
                    let start = du << u | dv << v
                    guard (inside >> start & 1) != (inside >> (start | 1 << axis) & 1) else { continue }
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

    func crosses(_ edge: Edge) -> (crosses: Bool, rising: Bool) {
        let (ei, ej, ek) = edge.end
        let a = gridValue(edge.i, edge.j, edge.k), b = gridValue(ei, ej, ek)
        return ((a < 0) != (b < 0), a < 0)
    }

    /// Where the offset surface crosses an edge, and the distance gradient there, by safeguarded Newton steps:
    /// every distance query also yields the gradient
    func crossing(on edge: Edge) -> Crossing {
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
            if abs(v) < 1e-7 * unit { break }
            if (v < 0) == (lowerValue < 0) { lower = t; lowerValue = v } else { upper = t; upperValue = v }
            if upper - lower < 1e-9 * length { break }
            let slope = gradient[edge.axis]
            var next = slope != 0 ? t - v / slope : -1
            if !(next > lower && next < upper) { next = lower - lowerValue * (upper - lower) / (upperValue - lowerValue) }
            if !(next > lower && next < upper) { next = (lower + upper) / 2 }
            t = next
        }
        return Crossing(point: p, normal: gradient)
    }
}
