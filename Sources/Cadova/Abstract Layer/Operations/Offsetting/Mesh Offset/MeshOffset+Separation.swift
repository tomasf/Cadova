import Foundation

extension MeshOffset {
    static func separated(vertices: [Vector3D], faces: [Face]) -> (vertices: [Vector3D], faces: [Face]) {
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
}
