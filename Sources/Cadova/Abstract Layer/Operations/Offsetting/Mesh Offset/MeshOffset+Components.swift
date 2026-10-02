import Foundation

extension MeshOffset {
    static let cubeEdges = [(0, 1), (2, 3), (4, 5), (6, 7), (0, 2), (1, 3), (4, 6), (5, 7), (0, 4), (1, 5), (2, 6), (3, 7)]

    /// Whether the surface may pass a cube cell more than once: that takes at least six crossing edges. A quick
    /// check without allocations, since it runs for every leaf.
    func mayHaveSeveralComponents(_ i: Int, _ j: Int, _ k: Int, size: Int) -> Bool {
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
    func components(_ i: Int, _ j: Int, _ k: Int, size: Int) -> [[Int]] {
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
}
