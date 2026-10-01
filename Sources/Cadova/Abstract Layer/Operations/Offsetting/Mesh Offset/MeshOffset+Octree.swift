import Foundation

extension MeshOffset {
    /// What to do with a node: 0 leave it empty, 1 make it a leaf, 2 subdivide it; and the face closest to its center
    struct Decision {
        let kind: Int
        let face: Int
    }

    func buildTree() {
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
                        let planar = if let rounding = self.rounding {
                            rounding.isPlanar(within: halfDiagonal, of: center)
                        } else {
                            self.field.facesAreCoplanar(within: abs(self.amount) + halfDiagonal, of: center)
                                && !(self.corners?.mayAffect(center, radius: halfDiagonal) ?? false)
                        }
                        if planar { return Decision(kind: 1, face: face) }
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
    func makeCells(in parents: [Int], hints: [Int]) {
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
        // Which of each parent's eight cells the surface crosses, from the signs at their corners, found in parallel;
        // only adding the nodes is serial
        let crossed = nodes.withUnsafeBufferPointer { nodeBuffer in
            parents.withUnsafeBufferPointer { parentBuffer in
                nonisolated(unsafe) let nodes = nodeBuffer, parents = parentBuffer
                return ConcurrentLoop.map(parents.count) { n -> UInt8 in
                    let node = nodes[parents[n]]
                    // The signs at the parent's 27 grid points, as bits
                    var inside: UInt32 = 0
                    var point = 0
                    while point < 27 {
                        let key = Self.key(node.i + point % 3 * size, node.j + point / 3 % 3 * size, node.k + point / 9 * size)
                        if self.knownValues.value(for: key)! < 0 { inside |= 1 << UInt32(point) }
                        point += 1
                    }
                    var mask: UInt8 = 0
                    var c = 0
                    while c < 8 {
                        let base = (c & 1) + (c >> 1 & 1) * 3 + (c >> 2 & 1) * 9
                        var count = 0
                        var q = 0
                        while q < 8 {
                            if inside & (1 << UInt32(base + (q & 1) + (q >> 1 & 1) * 3 + (q >> 2 & 1) * 9)) != 0 { count += 1 }
                            q += 1
                        }
                        if count > 0 && count < 8 { mask |= 1 << UInt8(c) }
                        c += 1
                    }
                    return mask
                }
            }
        }
        octree.nodes.reserveCapacity(octree.nodes.count + 8 * parents.count)
        var n = 0
        while n < parents.count {
            let parent = parents[n], hint = hints[n], mask = crossed[n]
            n += 1
            let first = octree.subdivide(node: parent)
            var c = 0
            while c < 8 {
                if mask & (1 << UInt8(c)) != 0 { octree.makeLeaf(node: first + c, hint: hint) }
                c += 1
            }
        }
    }

    /// Splits leaves into their children that may contain the surface. Finer cells need their neighbors as leaves
    /// wherever the surface comes near, crossing or not, so this also brings back the base cells around split base
    /// cells that making cells from corner signs left out. The sampling for all of them runs on every core.
    func split(leaves indices: [Int]) {
        guard !indices.isEmpty else { return }
        // Nodes to test: empty base cells next to split base cells, then every split leaf's eight children to be
        var tested: [OffsetOctree.Node] = []
        var hints: [Int] = []
        var restored: [Int] = []
        var seen = Set<Int>()
        for index in indices where octree.leaves[index].size <= unitsPerCell {
            // Around the base cell the leaf is in, however far it's been split already
            let leaf = octree.leaves[index]
            let size = unitsPerCell
            let (bi, bj, bk) = (leaf.i / size * size, leaf.j / size * size, leaf.k / size * size)
            var neighbor = 0
            while neighbor < 27 {
                let dx = neighbor % 3 - 1, dy = neighbor / 3 % 3 - 1, dz = neighbor / 9 - 1
                neighbor += 1
                guard dx != 0 || dy != 0 || dz != 0,
                      let found = octree.node(at: bi + dx * size, bj + dy * size, bk + dz * size, size: size)
                else { continue }
                let node = octree.nodes[found]
                guard node.size == size, node.leaf < 0, node.child < 0, seen.insert(found).inserted else { continue }
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
    func balance() -> Int {
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
}
