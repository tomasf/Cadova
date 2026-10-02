import Foundation

extension MeshOffset {
    struct Contour {
        var vertices: [Vector3D] = []
        var faces: [Face] = []
        var leafOfVertex: [Int] = []
        /// Empty regions next to crossing edges, whose quads couldn't be made: grid points in them, the size of the
        /// edge, and a face near them
        var missing: [(i: Int, j: Int, k: Int, size: Int, hint: Int)] = []
    }

    func contour(reusingFitEdges: Bool = false) -> Contour {
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

        // Grid-unit cells that a thin plate passes twice get one vertex per surface component. Found in parallel:
        // nearly every leaf is a grid-unit cell, and few are passed twice.
        var componentVertex: [Int: [UInt64: Int]] = [:]
        let plates = leaves.withUnsafeBufferPointer { leafBuffer in
            vertexOfLeaf.withUnsafeBufferPointer { vertexBuffer in
                nonisolated(unsafe) let leaves = leafBuffer, vertexOfLeaf = vertexBuffer
                return ConcurrentLoop.collect(leaves.count) { (index: Int, found: inout [(index: Int, groups: [[Int]])]) in
                    let leaf = leaves[index]
                    guard leaf.size == 1, vertexOfLeaf[index] >= 0, self.mayHaveSeveralComponents(leaf.i, leaf.j, leaf.k, size: 1) else { return }
                    let groups = self.components(leaf.i, leaf.j, leaf.k, size: 1)
                    if groups.count > 1 { found.append((index, groups)) }
                }
            }
        }
        for (index, groups) in plates {
            let leaf = leaves[index]
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
            guard v0 >= 0, v1 >= 0, v2 >= 0, v3 >= 0 else {
                // Quadrants in the order (+u, +v), (−u, +v), (−u, −v), (+u, −v), as the edge lists its leaves
                let u = (edge.axis + 1) % 3, v = (edge.axis + 2) % 3
                let quadrants = [edge.around.0, edge.around.1, edge.around.2, edge.around.3]
                for (q, leaf) in quadrants.enumerated() where leaf < 0 {
                    // The quadrant's cell's lowest corner: the edge's start, stepped back a cell on the negative sides
                    var point = [edge.i, edge.j, edge.k]
                    if q == 1 || q == 2 { point[u] -= edge.length }
                    if q == 2 || q == 3 { point[v] -= edge.length }
                    result.missing.append((point[0], point[1], point[2], edge.length, edge.hint))
                }
                continue
            }
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
}
