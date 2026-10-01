import Foundation

extension MeshDistanceField {
    /// Per face: the normals summed over the faces sharing each of its edges, and whether it's defective, or
    /// unusable for the sign
    struct FaceInfo {
        let sums: (Vector3D, Vector3D, Vector3D)
        let defective: Bool
        let unsigned: Bool
    }

    /// Per vertex: its angle-weighted normal, and whether a face around it is defective, or unusable for the sign
    struct VertexInfo {
        let sum: Vector3D
        let bad: Bool
        let unsigned: Bool
    }

    /// Edge and vertex normals, and the defective faces: slivers, faces along edges not shared by exactly two faces,
    /// and faces along folded edges (neighbors facing opposite ways). Their normals can't be trusted, nor the
    /// pseudonormals of vertices touching them. For the sign, faces along any edge turning more than a right angle
    /// count too: such edges are rare in designed shapes, but they're where a mesh can fold over itself (as meshes
    /// from earlier offsets occasionally do), and near a fold, pseudonormals point the wrong way.
    ///
    /// Gathered per face and per vertex from the topology, in parallel, over raw buffers: in unoptimized builds,
    /// every array access would retain and release the array's storage, all cores contending for its count.
    static func surfaceInfo(vertices: [Vector3D], faces: [Face], normals: [Vector3D], topology: Topology,
                            minimumHeight: Double) -> (faces: [FaceInfo], vertices: [VertexInfo]) {
        return faces.withUnsafeBufferPointer { faceBuffer in
            vertices.withUnsafeBufferPointer { vertexBuffer in
            normals.withUnsafeBufferPointer { normalBuffer in
                nonisolated(unsafe) let faces = faceBuffer, vertices = vertexBuffer, normals = normalBuffer
                let info = ConcurrentLoop.map(faces.count) { index -> FaceInfo in
                    let face = faces[index]
                    let a = vertices[face.0], b = vertices[face.1], c = vertices[face.2]
                    let normal = normals[index]
                    let longest = max((b - a).magnitude, max((c - b).magnitude, (a - c).magnitude))
                    let area = ((b - a) × (c - a)).magnitude / 2
                    var defective = longest <= 0 || 2 * area / longest < minimumHeight, unsigned = defective
                    // Edge normals summed over the faces sharing each edge
                    var sums = (normal, normal, normal)
                    var k = 0
                    while k < 3 {
                        var sum = normal, sharing = 1, other = -1
                        topology.forEachSharing(face: index, edge: k) { neighbor in
                            sum = sum + normals[neighbor]
                            sharing += 1
                            other = neighbor
                        }
                        if sharing != 2 || normal ⋅ normals[other] < -0.95 { defective = true }
                        if sharing != 2 || normal ⋅ normals[other] < 0 { unsigned = true }
                        if k == 0 { sums.0 = sum } else if k == 1 { sums.1 = sum } else { sums.2 = sum }
                        k += 1
                    }
                    return FaceInfo(sums: sums, defective: defective, unsigned: unsigned)
                }
                // Angle-weighted vertex normals, and whether any face around each vertex is defective
                let vertexInfo = info.withUnsafeBufferPointer { infoBuffer in
                    nonisolated(unsafe) let info = infoBuffer
                    return ConcurrentLoop.map(vertices.count) { v -> VertexInfo in
                        var sum = Vector3D.zero, bad = false, unsigned = false
                        var n = topology.offsets[v]
                        let end = topology.offsets[v + 1]
                        while n < end {
                            let index = topology.members[n]
                            n += 1
                            let face = faces[index]
                            let a = vertices[face.0], b = vertices[face.1], c = vertices[face.2]
                            let angle = face.0 == v ? Self.angle(b - a, c - a) : face.1 == v ? Self.angle(c - b, a - b) : Self.angle(a - c, b - c)
                            sum = sum + normals[index] * angle
                            if info[index].defective { bad = true }
                            if info[index].unsigned { unsigned = true }
                        }
                        return VertexInfo(sum: sum, bad: bad, unsigned: unsigned)
                    }
                }
                return (info, vertexInfo)
            }
            }
        }
    }

    /// Which faces are suspect: they touch a vertex next to a defect. And per face, whether the pseudonormals of its
    /// interior and of each of its edges can be trusted for the sign: none of the faces involved is one that can't.
    static func trust(faces: [Face], info: [FaceInfo], vertexInfo: [VertexInfo], topology: Topology) -> (suspect: [Bool], features: [UInt8]) {
        return faces.withUnsafeBufferPointer { faceBuffer in
            info.withUnsafeBufferPointer { infoBuffer in
            vertexInfo.withUnsafeBufferPointer { vertexInfoBuffer in
                nonisolated(unsafe) let faces = faceBuffer, info = infoBuffer, vertexInfo = vertexInfoBuffer
                let suspect = ConcurrentLoop.map(faces.count) { index -> Bool in
                    let face = faces[index]
                    return vertexInfo[face.0].bad || vertexInfo[face.1].bad || vertexInfo[face.2].bad
                }
                let bits = ConcurrentLoop.map(faces.count) { index -> UInt8 in
                    guard !info[index].unsigned else { return 0 }
                    var bits: UInt8 = 1
                    var k = 0
                    while k < 3 {
                        var sound = true
                        topology.forEachSharing(face: index, edge: k) { if info[$0].unsigned { sound = false } }
                        if sound { bits |= 2 << UInt8(k) }
                        k += 1
                    }
                    return bits
                }
                return (suspect, bits)
            }
            }
        }
    }

    /// The hierarchy in the forms the searches read: node boxes as scalars, the compact links and single-precision
    /// child boxes, and the faces' corners in the tree's order
    static func compactTree(_ nodes: [Node], order: UnsafeBufferPointer<Int>, faces: [Face], vertices: [Vector3D])
        -> (boxes: [Double], links: [Int32], childBoxes: [Float], corners: [Double]) {
        var flatBoxes = [Double](repeating: 0, count: 6 * nodes.count)
        for (n, node) in nodes.enumerated() {
            flatBoxes[6 * n] = node.lower.x; flatBoxes[6 * n + 1] = node.lower.y; flatBoxes[6 * n + 2] = node.lower.z
            flatBoxes[6 * n + 3] = node.upper.x; flatBoxes[6 * n + 4] = node.upper.y; flatBoxes[6 * n + 5] = node.upper.z
        }

        let nodeCount = nodes.count
        var linkArray = [Int32](repeating: 0, count: 2 * nodeCount)
        var childBoxArray = [Float](repeating: 0, count: 12 * nodeCount)
        func lowered(_ value: Double) -> Float { let f = Float(value); return Double(f) > value ? f.nextDown : f }
        func raised(_ value: Double) -> Float { let f = Float(value); return Double(f) < value ? f.nextUp : f }
        var n = 0
        while n < nodeCount {
            let node = nodes[n]
            if node.left < 0 {
                linkArray[2 * n] = Int32(-1 - node.first); linkArray[2 * n + 1] = Int32(node.count)
            } else {
                linkArray[2 * n] = Int32(node.left); linkArray[2 * n + 1] = Int32(node.right)
                var slot = 0
                while slot < 2 {
                    let child = nodes[slot == 0 ? node.left : node.right]
                    let base = 12 * n + 6 * slot
                    childBoxArray[base] = lowered(child.lower.x); childBoxArray[base + 1] = lowered(child.lower.y)
                    childBoxArray[base + 2] = lowered(child.lower.z); childBoxArray[base + 3] = raised(child.upper.x)
                    childBoxArray[base + 4] = raised(child.upper.y); childBoxArray[base + 5] = raised(child.upper.z)
                    slot += 1
                }
            }
            n += 1
        }
        var cornerArray = [Double](repeating: 0, count: 9 * faces.count)
        n = 0
        while n < faces.count {
            let face = faces[order[n]]
            let a = vertices[face.0], b = vertices[face.1], c = vertices[face.2]
            cornerArray[9 * n] = a.x; cornerArray[9 * n + 1] = a.y; cornerArray[9 * n + 2] = a.z
            cornerArray[9 * n + 3] = b.x; cornerArray[9 * n + 4] = b.y; cornerArray[9 * n + 5] = b.z
            cornerArray[9 * n + 6] = c.x; cornerArray[9 * n + 7] = c.y; cornerArray[9 * n + 8] = c.z
            n += 1
        }
        return (flatBoxes, linkArray, childBoxArray, cornerArray)
    }

    /// Revokes trust in the pseudonormals of faces inside the solid, once everything else is in place to find them
    func distrustInnerFaces(vertices: [Vector3D], faces: [Face], normals: [Vector3D], topology: Topology, diagonal: Double) {
        // Faces inside the solid, as meshes that intersect themselves have: material in front of them, or none
        // behind. Their pseudonormals say nothing about the solid, so near them the winding number decides.
        let isInner: @Sendable (Int) -> Bool = { index in
            let face = faces[index], normal = normals[index]
            guard normal != .zero else { return false }
            let a = vertices[face.0], b = vertices[face.1], c = vertices[face.2]
            let longest = max((b - a).magnitude, max((c - b).magnitude, (a - c).magnitude))
            let step = max(1e-3 * longest, 1e-7 * diagonal)
            let center = (a + b + c) / 3
            return self.windingNumber(at: center + normal * step) > 0.5 || self.windingNumber(at: center - normal * step) < 0.5
        }
        // A connected piece of the surface that crosses no other face lies wholly on one side of the rest, inside or
        // out, so one face answers for all of it; only pieces that cross or overlap something need every face tested
        let crossing = ConcurrentLoop.map(faces.count) { self.intersectsOtherFaces($0) }
        var piece = [Int](repeating: 0, count: faces.count)
        var index = 0
        while index < faces.count { piece[index] = index; index += 1 }
        func root(_ start: Int) -> Int {
            var x = start
            while piece[x] != x { piece[x] = piece[piece[x]]; x = piece[x] }
            return x
        }
        index = 0
        while index < faces.count {
            var k = 0
            while k < 3 {
                topology.forEachSharing(face: index, edge: k) { other in
                    let a = root(index), b = root(other)
                    if a != b { piece[max(a, b)] = min(a, b) }
                }
                k += 1
            }
            index += 1
        }
        var pieceCrosses = [Bool](repeating: false, count: faces.count)
        var representative = [Int](repeating: -1, count: faces.count)
        var representativeArea = [Double](repeating: -1, count: faces.count)
        index = 0
        while index < faces.count {
            let r = root(index)
            piece[index] = r
            if crossing[index] { pieceCrosses[r] = true }
            let face = faces[index]
            let area = ((vertices[face.1] - vertices[face.0]) × (vertices[face.2] - vertices[face.0])).magnitude
            if area > representativeArea[r] { representativeArea[r] = area; representative[r] = index }
            index += 1
        }
        let chosen = representative.indices.filter { representative[$0] >= 0 && !pieceCrosses[$0] }.map { representative[$0] }
        let chosenInner = ConcurrentLoop.map(chosen.count) { isInner(chosen[$0]) }
        var pieceInner = [Bool](repeating: false, count: faces.count)
        for (n, face) in chosen.enumerated() { pieceInner[piece[face]] = chosenInner[n] }
        let pieces = piece, crosses = pieceCrosses, piecesInner = pieceInner
        let inner = ConcurrentLoop.map(faces.count) { index -> Bool in
            let r = pieces[index]
            return crossing[index] || (crosses[r] ? isInner(index) : piecesInner[r])
        }
        let features = reliableFeatures
        for (index, face) in faces.enumerated() where inner[index] {
            reliableFeatures[index] = 0
            reliableVertices[face.0] = false; reliableVertices[face.1] = false; reliableVertices[face.2] = false
            var k = 0
            while k < 3 {
                topology.forEachSharing(face: index, edge: k) { neighbor in
                    // The neighbor's edge shared with this face
                    let other = faces[neighbor]
                    let corners = [face.0, face.1, face.2]
                    for (m, (u, w)) in [(other.0, other.1), (other.1, other.2), (other.2, other.0)].enumerated()
                        where corners.contains(u) && corners.contains(w) {
                        features[neighbor] &= ~(2 << UInt8(m))
                    }
                }
                k += 1
            }
        }
    }
}
