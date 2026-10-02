import Foundation

extension MeshOffset {
    /// Merged leaves with a vertex on a triangle facing against the surface: its normal points away from the offset
    /// function's gradient at its center
    func foldingMerges(in contour: Contour) -> Set<Int> {
        guard !merges.isEmpty else { return [] }
        // Flags rather than the dictionary: looking it up from every core for every face costs more than sampling
        var merged = [Bool](repeating: false, count: octree.leaves.count)
        for leaf in merges.keys where leaf < merged.count { merged[leaf] = true }
        let found = contour.faces.withUnsafeBufferPointer { faceBuffer in
            contour.vertices.withUnsafeBufferPointer { vertexBuffer in
                contour.leafOfVertex.withUnsafeBufferPointer { leafBuffer in
                merged.withUnsafeBufferPointer { mergedBuffer in
                octree.leaves.withUnsafeBufferPointer { leavesBuffer in
                    nonisolated(unsafe) let faces = faceBuffer, vertices = vertexBuffer, leafOfVertex = leafBuffer
                    nonisolated(unsafe) let merged = mergedBuffer, octreeLeaves = leavesBuffer
                    return ConcurrentLoop.collect(faces.count) { (index: Int, found: inout [Int]) in
                        let face = faces[index]
                        let leaves = (leafOfVertex[face.0], leafOfVertex[face.1], leafOfVertex[face.2])
                        let merged0 = merged[leaves.0], merged1 = merged[leaves.1], merged2 = merged[leaves.2]
                        guard merged0 || merged1 || merged2 else { return }
                        let a = vertices[face.0], b = vertices[face.1], c = vertices[face.2]
                        let normal = ((b - a) × (c - a)).safelyNormalized
                        guard normal != .zero else { return }
                        // The leaf's face near it gives the distance search an early bound
                        let hint = octreeLeaves[leaves.0].hint
                        let gradient = self.sampleWithGradient(at: (a + b + c) / 3, hint: hint >= 0 ? hint : nil).gradient
                        guard normal ⋅ gradient < 0 else { return }
                        if merged0 { found.append(leaves.0) }
                        if merged1 { found.append(leaves.1) }
                        if merged2 { found.append(leaves.2) }
                    }
                }
                }
                }
            }
        }
        return Set(found)
    }

    /// Makes leaves where contouring found empty regions next to crossing edges. The tree leaves a region empty
    /// when the offset function at its center says the surface can't reach it, which holds unless the function is
    /// wrong there, as the sign of a mesh that intersects itself can be. Every crossing then has its cells, so the
    /// surface closes, whatever the function says.
    func fillMissing(_ missing: [(i: Int, j: Int, k: Int, size: Int, hint: Int)]) -> Bool {
        var filled = false
        for cell in missing {
            guard var index = octree.node(at: cell.i, cell.j, cell.k, size: cell.size) else { continue }
            var node = octree.nodes[index]
            guard node.leaf < 0, node.child < 0, node.size >= cell.size else { continue }
            while node.size > cell.size {
                let first = octree.subdivide(node: index)
                let half = node.size / 2
                index = first + ((cell.i >= node.i + half ? 1 : 0) | (cell.j >= node.j + half ? 2 : 0) | (cell.k >= node.k + half ? 4 : 0))
                // The other children split their larger neighbors' edges, which those then leave to them: any the
                // surface may reach must be leaves too, or crossings on those edges go unreported
                var c = 0
                while c < 8 {
                    if first + c != index {
                        let (contains, face) = nodeMayContainSurface(octree.nodes[first + c], hint: cell.hint >= 0 ? cell.hint : nil)
                        if contains { octree.makeLeaf(node: first + c, hint: face) }
                    }
                    c += 1
                }
                node = octree.nodes[index]
            }
            octree.makeLeaf(node: index, hint: cell.hint)
            filled = true
        }
        return filled
    }

    /// Contours, and where two sheets share an edge (used by more than two triangles), unmerges or splits the cells
    /// involved and contours again
    func contourWithRepair() -> Contour {
        var result = contour()
        var previous = Int.max
        for _ in 0..<12 {
            if !result.missing.isEmpty && fillMissing(result.missing) {
                balance()
                computeFits()
                result = contour(reusingFitEdges: true)
                continue
            }
            let fans = VertexFans(faces: result.faces, vertexCount: result.vertices.count)
            var culprits = Set<Int>()
            for (a, b) in fans.irregularEdges(in: result.faces) where fans.faces(around: a, with: b, in: result.faces).count > 2 {
                culprits.insert(result.leafOfVertex[a])
                culprits.insert(result.leafOfVertex[b])
            }
            // Merged cells whose vertex folds a triangle over: one vertex can fit all of a cell's planes within the
            // tolerance and still sit wrong relative to its neighbors
            culprits.formUnion(foldingMerges(in: result))
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
}
