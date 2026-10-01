import Foundation

extension MeshOffset {
    /// Splits cells whose planes no single vertex inside fits well (a feature smaller than the cell, such as a thin
    /// spike), or that a thin plate passes twice
    func refine() {
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
    func simplify() {
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

    func mergedFit(node: OffsetOctree.Node, index: Int, nodes: UnsafeBufferPointer<OffsetOctree.Node>, extent: Int, fits: UnsafeBufferPointer<PlaneFit>) -> PlaneFit? {
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
        let lower = point(node.i, node.j, node.k), span = Double(node.size) * unit
        // Curved parts fit within as much as a circle of their curvature strays from its arc, their radius estimated
        // from the node's width and how far its normals turn across it. Flat parts and creases, which one vertex fits
        // exactly, keep the tolerance.
        var tolerance = self.tolerance
        if let segmentation {
            let spread = fit.normalSpread
            if spread > 1e-9 { tolerance = min(tolerance, segmentation.sagitta(radius: span / spread)) }
        }
        // One vertex must fit within the tolerance, inside the node
        let x = fit.solve()
        let upper = lower + Vector3D(span, span, span)
        if x.x < lower.x - 0.1 * unit || x.y < lower.y - 0.1 * unit || x.z < lower.z - 0.1 * unit
            || x.x > upper.x + 0.1 * unit || x.y > upper.y + 0.1 * unit || x.z > upper.z + 0.1 * unit { return nil }
        if fit.rootMeanSquareError(at: x) > tolerance { return nil }
        // Merging must keep the tree balanced
        if OffsetOctree.hasMuchSmallerNeighbor(node.i, node.j, node.k, size: node.size, near: index, in: nodes, extent: extent) { return nil }
        if abs(value(at: x)) > tolerance { return nil }
        return fit
    }
}
