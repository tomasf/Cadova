import Foundation

/// Exact signed distance to a closed triangle mesh, negative inside.
///
/// Closest points come from a bounding volume hierarchy. The sign comes from the angle-weighted pseudonormal of the
/// closest feature (Bærentzen and Aanæs), which is exact for clean meshes. Near defects such as slivers and folded
/// edges, where pseudonormals can't be trusted, the generalized winding number decides instead (Jacobson et al.),
/// evaluated quickly by treating distant parts of the hierarchy as dipoles (Barill et al.).
///
/// Queries run concurrently from every core, so the read-only data lives in unsafe buffers: reading shared arrays
/// retains and releases them, and in unoptimized builds, that reference counting from all threads at once costs far
/// more than the geometry.
internal final class MeshDistanceField: @unchecked Sendable {
    typealias Face = (Int, Int, Int)

    struct Closest {
        var distanceSquared: Double
        var point: Vector3D
        var pseudonormal: Vector3D
        var face: Int
    }

    private struct Node {
        var lower: Vector3D
        var upper: Vector3D
        var left = -1
        var right = -1
        var first = 0
        var count = 0
        // Dipole: area vector, area-weighted center, and how far the node reaches from it
        var area = Vector3D.zero
        var center = Vector3D.zero
        var radius = 0.0
    }

    let vertices: [Vector3D]
    private let vertexBuffer: UnsafeBufferPointer<Vector3D>
    private let faces: UnsafeBufferPointer<Face>
    private let faceNormals: UnsafeBufferPointer<Vector3D>
    private let vertexNormals: UnsafeBufferPointer<Vector3D>
    private let edgeNormals: UnsafeBufferPointer<(Vector3D, Vector3D, Vector3D)>   // per face, edge k runs from corner k to k + 1
    private let suspect: UnsafeBufferPointer<Bool>
    private let nodes: UnsafeBufferPointer<Node>
    private let order: UnsafeBufferPointer<Int>

    private static func buffer<T>(_ array: [T]) -> UnsafeBufferPointer<T> {
        let buffer = UnsafeMutableBufferPointer<T>.allocate(capacity: array.count)
        _ = buffer.initialize(from: array)
        return UnsafeBufferPointer(buffer)
    }

    deinit {
        vertexBuffer.deallocate(); faces.deallocate(); faceNormals.deallocate(); vertexNormals.deallocate()
        edgeNormals.deallocate(); suspect.deallocate(); nodes.deallocate(); order.deallocate()
    }

    init(vertices: [Vector3D], faces: [Face]) {
        self.vertices = vertices
        vertexBuffer = Self.buffer(vertices)
        self.faces = Self.buffer(faces)

        let normals = faces.map { face in
            ((vertices[face.1] - vertices[face.0]) × (vertices[face.2] - vertices[face.0])).safelyNormalized
        }
        faceNormals = Self.buffer(normals)

        var vertexSums = [Vector3D](repeating: .zero, count: vertices.count)
        var edgeSums: [UInt64: Vector3D] = [:]
        for (index, face) in faces.enumerated() {
            let corners = [face.0, face.1, face.2]
            for k in 0..<3 {
                let here = vertices[corners[k]]
                let toNext = (vertices[corners[(k + 1) % 3]] - here).safelyNormalized
                let toPrevious = (vertices[corners[(k + 2) % 3]] - here).safelyNormalized
                let angle = Foundation.acos(min(max(toNext ⋅ toPrevious, -1), 1))
                vertexSums[corners[k]] = vertexSums[corners[k]] + normals[index] * angle
                edgeSums[Self.edgeKey(corners[k], corners[(k + 1) % 3]), default: .zero] += normals[index]
            }
        }
        vertexNormals = Self.buffer(vertexSums)
        edgeNormals = Self.buffer(faces.map { face in
            (edgeSums[Self.edgeKey(face.0, face.1)]!, edgeSums[Self.edgeKey(face.1, face.2)]!, edgeSums[Self.edgeKey(face.2, face.0)]!)
        })
        suspect = Self.buffer(Self.suspectFaces(vertices: vertices, faces: faces, normals: normals))

        var hierarchy = Hierarchy(vertices: vertices, faces: faces)
        if !faces.isEmpty {
            _ = hierarchy.build(first: 0, count: faces.count)
        }
        nodes = Self.buffer(hierarchy.nodes)
        order = Self.buffer(hierarchy.order)
    }

    static func edgeKey(_ a: Int, _ b: Int) -> UInt64 {
        a < b ? UInt64(a) << 32 | UInt64(b) : UInt64(b) << 32 | UInt64(a)
    }

    /// Faces whose pseudonormals can't be trusted: slivers (normals unreliable), faces along folded edges
    /// (neighbors facing opposite ways), and every face sharing a vertex with one, since that vertex's pseudonormal
    /// is contaminated too
    private static func suspectFaces(vertices: [Vector3D], faces: [Face], normals: [Vector3D]) -> [Bool] {
        guard let first = vertices.first else { return [] }
        let bounds = vertices.reduce((first, first)) { (Vector3D.min($0.0, $1), Vector3D.max($0.1, $1)) }
        let minimumHeight = 1e-5 * (bounds.1 - bounds.0).magnitude

        var defective = [Bool](repeating: false, count: faces.count)
        var facesOfEdge: [UInt64: [Int]] = [:]
        for (index, face) in faces.enumerated() {
            let a = vertices[face.0], b = vertices[face.1], c = vertices[face.2]
            let longest = max((b - a).magnitude, (c - b).magnitude, (a - c).magnitude)
            let area = ((b - a) × (c - a)).magnitude / 2
            if longest <= 0 || 2 * area / longest < minimumHeight { defective[index] = true }
            for (u, v) in [(face.0, face.1), (face.1, face.2), (face.2, face.0)] {
                facesOfEdge[edgeKey(u, v), default: []].append(index)
            }
        }
        for sharing in facesOfEdge.values {
            if sharing.count != 2 {
                for index in sharing { defective[index] = true }
            } else if normals[sharing[0]] ⋅ normals[sharing[1]] < -0.95 {
                defective[sharing[0]] = true
                defective[sharing[1]] = true
            }
        }
        var badVertex = [Bool](repeating: false, count: vertices.count)
        for (index, face) in faces.enumerated() where defective[index] {
            badVertex[face.0] = true; badVertex[face.1] = true; badVertex[face.2] = true
        }
        return faces.map { badVertex[$0.0] || badVertex[$0.1] || badVertex[$0.2] }
    }

    /// Builds the bounding volume hierarchy, splitting at the median centroid along the longest axis
    private struct Hierarchy {
        let vertices: [Vector3D]
        let faces: [Face]
        var nodes: [Node] = []
        var order: [Int]

        init(vertices: [Vector3D], faces: [Face]) {
            self.vertices = vertices
            self.faces = faces
            order = Array(faces.indices)
            nodes.reserveCapacity(2 * faces.count)
        }

            mutating func build(first: Int, count: Int) -> Int {
            let index = nodes.count
            let seed = vertices[faces[order[first]].0]
            var lower = seed, upper = seed
            var area = Vector3D.zero, weightedCenter = Vector3D.zero, totalArea = 0.0
            for i in first..<(first + count) {
                let face = faces[order[i]]
                let a = vertices[face.0], b = vertices[face.1], c = vertices[face.2]
                lower = .min(lower, .min(a, .min(b, c)))
                upper = .max(upper, .max(a, .max(b, c)))
                let doubleArea = (b - a) × (c - a)
                let weight = doubleArea.magnitude / 2
                area = area + doubleArea * 0.5
                weightedCenter = weightedCenter + (a + b + c) * (weight / 3)
                totalArea += weight
            }
            let center = totalArea > 0 ? weightedCenter / totalArea : (lower + upper) / 2
            var radius = 0.0
            for corner in 0..<8 {
                let point = Vector3D(corner & 1 == 0 ? lower.x : upper.x, corner & 2 == 0 ? lower.y : upper.y, corner & 4 == 0 ? lower.z : upper.z)
                radius = max(radius, (point - center).magnitude)
            }
            nodes.append(Node(lower: lower, upper: upper, area: area, center: center, radius: radius))

            if count <= 4 {
                nodes[index].first = first
                nodes[index].count = count
                return index
            }
            let extent = upper - lower
            let axis = extent.x >= extent.y && extent.x >= extent.z ? 0 : (extent.y >= extent.z ? 1 : 2)
            let middle = first + count / 2
            let faces = faces, vertices = vertices
            order[first..<(first + count)].sort { lhs, rhs in
                let l = faces[lhs], r = faces[rhs]
                return vertices[l.0][axis] + vertices[l.1][axis] + vertices[l.2][axis] < vertices[r.0][axis] + vertices[r.1][axis] + vertices[r.2][axis]
            }
            let left = build(first: first, count: middle - first)
            let right = build(first: middle, count: first + count - middle)
            nodes[index].left = left
            nodes[index].right = right
            return index
        }
    }

    private static func boxDistanceSquared(_ node: Node, _ p: Vector3D) -> Double {
        let dx = max(node.lower.x - p.x, 0, p.x - node.upper.x)
        let dy = max(node.lower.y - p.y, 0, p.y - node.upper.y)
        let dz = max(node.lower.z - p.z, 0, p.z - node.upper.z)
        return dx * dx + dy * dy + dz * dz
    }

    /// The closest point on one face, and the pseudonormal of the feature (face, edge or vertex) it lies on.
    /// Ericson, Real-Time Collision Detection 5.1.5.
    private func closest(to p: Vector3D, onFace index: Int) -> Closest {
        let face = faces[index]
        let a = vertexBuffer[face.0], b = vertexBuffer[face.1], c = vertexBuffer[face.2]
        let ab = b - a, ac = c - a, ap = p - a
        func result(_ q: Vector3D, _ normal: Vector3D) -> Closest {
            let d = p - q
            return Closest(distanceSquared: d ⋅ d, point: q, pseudonormal: normal, face: index)
        }
        let d1 = ab ⋅ ap, d2 = ac ⋅ ap
        if d1 <= 0 && d2 <= 0 { return result(a, vertexNormals[face.0]) }
        let bp = p - b
        let d3 = ab ⋅ bp, d4 = ac ⋅ bp
        if d3 >= 0 && d4 <= d3 { return result(b, vertexNormals[face.1]) }
        let vc = d1 * d4 - d3 * d2
        if vc <= 0 && d1 >= 0 && d3 <= 0 { return result(a + ab * (d1 / (d1 - d3)), edgeNormals[index].0) }
        let cp = p - c
        let d5 = ab ⋅ cp, d6 = ac ⋅ cp
        if d6 >= 0 && d5 <= d6 { return result(c, vertexNormals[face.2]) }
        let vb = d5 * d2 - d1 * d6
        if vb <= 0 && d2 >= 0 && d6 <= 0 { return result(a + ac * (d2 / (d2 - d6)), edgeNormals[index].2) }
        let va = d3 * d6 - d5 * d4
        if va <= 0 && (d4 - d3) >= 0 && (d5 - d6) >= 0 {
            return result(b + (c - b) * ((d4 - d3) / ((d4 - d3) + (d5 - d6))), edgeNormals[index].1)
        }
        let denominator = 1 / (va + vb + vc)
        return result(a + ab * (vb * denominator) + ac * (vc * denominator), faceNormals[index])
    }

    /// The closest point on the mesh. A hint, a face likely to be near (such as the answer for a nearby point),
    /// gives the search an early bound; the result is exact either way.
    func closest(to p: Vector3D, hint: Int? = nil) -> Closest {
        var best = Closest(distanceSquared: .infinity, point: .zero, pseudonormal: .zero, face: -1)
        guard !nodes.isEmpty else { return best }
        if let hint, hint >= 0 { best = closest(to: p, onFace: hint) }
        return withUnsafeTemporaryAllocation(of: Int.self, capacity: 128) { stack in
            var top = 1
            stack[0] = 0
            while top > 0 {
                top -= 1
                let index = stack[top]
                let node = nodes[index]
                if Self.boxDistanceSquared(node, p) >= best.distanceSquared { continue }
                if node.left < 0 {
                    for i in node.first..<(node.first + node.count) {
                        let candidate = closest(to: p, onFace: order[i])
                        if candidate.distanceSquared < best.distanceSquared { best = candidate }
                    }
                    continue
                }
                let dl = Self.boxDistanceSquared(nodes[node.left], p), dr = Self.boxDistanceSquared(nodes[node.right], p)
                if dl < dr { stack[top] = node.right; stack[top + 1] = node.left; top += 2 }
                else { stack[top] = node.left; stack[top + 1] = node.right; top += 2 }
            }
            return best
        }
    }

    /// Generalized winding number: about 1 inside, 0 outside
    func windingNumber(at p: Vector3D) -> Double {
        guard !nodes.isEmpty else { return 0 }
        var total = 0.0
        return withUnsafeTemporaryAllocation(of: Int.self, capacity: 128) { stack in
            var top = 1
            stack[0] = 0
            while top > 0 {
                top -= 1
                let index = stack[top]
                let node = nodes[index]
                let toward = node.center - p
                let distance = toward.magnitude
                if distance > 2 * node.radius {
                    total += (node.area ⋅ toward) / (distance * distance * distance)
                    continue
                }
                if node.left < 0 {
                    for i in node.first..<(node.first + node.count) {
                        let face = faces[order[i]]
                        let a = vertexBuffer[face.0] - p, b = vertexBuffer[face.1] - p, c = vertexBuffer[face.2] - p
                        let la = a.magnitude, lb = b.magnitude, lc = c.magnitude
                        total += 2 * Foundation.atan2(a ⋅ (b × c), la * lb * lc + (a ⋅ b) * lc + (a ⋅ c) * lb + (b ⋅ c) * la)
                    }
                    continue
                }
                stack[top] = node.left; stack[top + 1] = node.right; top += 2
            }
            return total / (4 * .pi)
        }
    }

    /// Whether p is inside. The pseudonormal decides when it clearly can; near defective faces, or where the
    /// pseudonormal runs nearly along the surface, the winding number does.
    func isInside(_ p: Vector3D, closest: Closest) -> Bool {
        let toward = p - closest.point
        let along = toward ⋅ closest.pseudonormal
        let lengths = toward.magnitude * closest.pseudonormal.magnitude
        if closest.face >= 0, !suspect[closest.face], lengths > 0, abs(along) > 0.2 * lengths {
            return along < 0
        }
        return windingNumber(at: p) > 0.5
    }

    func signedDistance(at p: Vector3D, hint: Int? = nil) -> Double {
        signedDistanceAndFace(at: p, hint: hint).value
    }

    /// The signed distance, and the face the closest point lies on (a hint for nearby queries)
    func signedDistanceAndFace(at p: Vector3D, hint: Int? = nil) -> (value: Double, face: Int) {
        let closest = closest(to: p, hint: hint)
        let distance = closest.distanceSquared.squareRoot()
        return (isInside(p, closest: closest) ? -distance : distance, closest.face)
    }

    /// The signed distance, its gradient (the unit direction away from the surface), and the closest face
    func signedDistanceAndGradient(at p: Vector3D, hint: Int? = nil) -> (value: Double, gradient: Vector3D, face: Int) {
        let closest = closest(to: p, hint: hint)
        let toward = p - closest.point
        let distance = closest.distanceSquared.squareRoot()
        let inside = isInside(p, closest: closest)
        let gradient = distance > 0 ? toward * ((inside ? -1 : 1) / distance) : closest.pseudonormal.safelyNormalized
        return (inside ? -distance : distance, gradient, closest.face)
    }

    /// Whether every face within `radius` of p lies in one plane (or there are none). The offset surface near p is
    /// then provably that plane moved along its normal.
    func facesAreCoplanar(within radius: Double, of p: Vector3D) -> Bool {
        guard !nodes.isEmpty else { return true }
        let radiusSquared = radius * radius
        var reference: (normal: Vector3D, offset: Double)? = nil
        return withUnsafeTemporaryAllocation(of: Int.self, capacity: 128) { stack in
            var top = 1
            stack[0] = 0
            while top > 0 {
                top -= 1
                let index = stack[top]
                let node = nodes[index]
                if Self.boxDistanceSquared(node, p) > radiusSquared { continue }
                if node.left < 0 {
                    for i in node.first..<(node.first + node.count) {
                        let faceIndex = order[i]
                        if closest(to: p, onFace: faceIndex).distanceSquared > radiusSquared { continue }
                        let face = faces[faceIndex]
                        let normal = faceNormals[faceIndex]
                        guard let plane = reference else {
                            reference = (normal, normal ⋅ vertexBuffer[face.0])
                            continue
                        }
                        if normal ⋅ plane.normal < 1 - 1e-10 { return false }
                        for corner in [face.0, face.1, face.2] where abs(plane.normal ⋅ vertexBuffer[corner] - plane.offset) > 1e-6 {
                            return false
                        }
                    }
                    continue
                }
                stack[top] = node.left; stack[top + 1] = node.right; top += 2
            }
            return true
        }
    }
}

internal extension Vector3D {
    /// The unit vector in this direction, or zero for a zero vector
    var safelyNormalized: Vector3D {
        let length = magnitude
        return length > 0 ? self / length : .zero
    }
}
