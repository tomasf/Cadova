import Foundation

/// Exact signed distance to a closed triangle mesh, negative inside.
///
/// Closest points come from a bounding volume hierarchy. The sign comes from the angle-weighted pseudonormal of the
/// closest feature (Bærentzen and Aanæs), which is exact for clean meshes. Where the closest feature's pseudonormal
/// involves a defect such as a sliver or a folded edge, and can't be trusted, the generalized winding number decides
/// instead (Jacobson et al.), evaluated quickly by treating distant parts of the hierarchy as dipoles (Barill et al.).
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
        /// Whether the pseudonormal comes only from sound faces, so its sign can be trusted
        var isReliable: Bool
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
        /// Total area, for combining children's centers
        var weight = 0.0
    }

    let vertices: [Vector3D]
    private let vertexBuffer: UnsafeBufferPointer<Vector3D>
    private let faces: UnsafeBufferPointer<Face>
    private let faceNormals: UnsafeBufferPointer<Vector3D>
    private let vertexNormals: UnsafeBufferPointer<Vector3D>
    private let edgeNormals: UnsafeBufferPointer<(Vector3D, Vector3D, Vector3D)>   // per face, edge k runs from corner k to k + 1
    private let suspect: UnsafeBufferPointer<Bool>
    /// Per face, whether the pseudonormals of its interior (bit 0) and of its edges (bits 1 to 3) can be trusted
    private let reliableFeatures: UnsafeMutableBufferPointer<UInt8>
    private let reliableVertices: UnsafeMutableBufferPointer<Bool>
    private let nodes: UnsafeBufferPointer<Node>
    private let order: UnsafeBufferPointer<Int>
    /// Vertex coordinates and node boxes as plain doubles (x, y, z per vertex; lower then upper per node): the hot
    /// loops work on scalars, since every vector operation checks its elements are finite, which unoptimized builds
    /// don't inline
    private let coordinates: UnsafeBufferPointer<Double>
    /// How far a vertex may lie from a plane and still count as on it: the precision of single-precision
    /// coordinates at the mesh's scale, since meshes often come from single-precision storage
    private let planeTolerance: Double
    private let boxes: UnsafeBufferPointer<Double>
    /// For the closest point search, the tree in a compact form. Per node, its children, or for a leaf, minus one
    /// minus the position of its first face in `order` and its face count.
    private let links: UnsafeBufferPointer<Int32>
    /// Per node, its children's boxes (lower then upper, first child then second) in single precision, rounded
    /// outward, so the search rules a child out without loading it
    private let childBoxes: UnsafeBufferPointer<Float>
    /// Face corner coordinates in the tree's order, nine per face, so a leaf's faces are read in one sweep
    private let orderedCorners: UnsafeBufferPointer<Double>

    private static func mutableBuffer<T>(_ array: [T]) -> UnsafeMutableBufferPointer<T> {
        let buffer = UnsafeMutableBufferPointer<T>.allocate(capacity: max(array.count, 1))
        _ = buffer.initialize(from: array)
        return buffer
    }

    private static func buffer<T>(_ array: [T]) -> UnsafeBufferPointer<T> {
        let buffer = UnsafeMutableBufferPointer<T>.allocate(capacity: array.count)
        _ = buffer.initialize(from: array)
        return UnsafeBufferPointer(buffer)
    }

    deinit {
        vertexBuffer.deallocate(); faces.deallocate(); faceNormals.deallocate(); vertexNormals.deallocate()
        edgeNormals.deallocate(); suspect.deallocate(); nodes.deallocate(); order.deallocate()
        reliableFeatures.deallocate(); reliableVertices.deallocate(); coordinates.deallocate(); boxes.deallocate()
        links.deallocate(); childBoxes.deallocate(); orderedCorners.deallocate()
    }

    init(vertices: [Vector3D], faces: [Face]) {
        self.vertices = vertices
        vertexBuffer = Self.buffer(vertices)
        self.faces = Self.buffer(faces)
        // Built with plain loops over scalars: this runs once per offset, but on large meshes, and unoptimized
        // builds would otherwise spend longer here than on the offset itself
        var flat = [Double](repeating: 0, count: 3 * vertices.count)
        for (v, vertex) in vertices.enumerated() { flat[3 * v] = vertex.x; flat[3 * v + 1] = vertex.y; flat[3 * v + 2] = vertex.z }
        coordinates = Self.buffer(flat)

        let normals = faces.map { face in
            ((vertices[face.1] - vertices[face.0]) × (vertices[face.2] - vertices[face.0])).safelyNormalized
        }
        faceNormals = Self.buffer(normals)

        let topology = Topology(vertexCount: vertices.count, faces: faces)
        let bounds = vertices.isEmpty ? (Vector3D.zero, Vector3D.zero) : vertices.reduce((vertices[0], vertices[0])) { (Vector3D.min($0.0, $1), Vector3D.max($0.1, $1)) }
        let minimumHeight = 1e-5 * (bounds.1 - bounds.0).magnitude
        let largest = max(abs(bounds.0.x), abs(bounds.0.y), abs(bounds.0.z), abs(bounds.1.x), abs(bounds.1.y), abs(bounds.1.z))
        planeTolerance = max(1e-6, 4e-7 * largest)

        // Defective faces: slivers, faces along edges not shared by exactly two faces, and faces along folded edges
        // (neighbors facing opposite ways). Their normals can't be trusted, nor the pseudonormals of vertices
        // touching them. For the sign, faces along any edge turning more than a right angle count too: such edges
        // are rare in designed shapes, but they're where a mesh can fold over itself (as meshes from earlier
        // offsets occasionally do), and near a fold, pseudonormals point the wrong way.
        // Gathered per face and per vertex from the topology, in parallel, over raw buffers: in unoptimized builds,
        // every array access would retain and release the array's storage, all cores contending for its count.
        struct FaceInfo {
            let sums: (Vector3D, Vector3D, Vector3D)
            let defective: Bool
            let unsigned: Bool
        }
        struct VertexInfo {
            let sum: Vector3D
            let bad: Bool
            let unsigned: Bool
        }
        let (info, vertexInfo) = faces.withUnsafeBufferPointer { faceBuffer in
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
        vertexNormals = Self.buffer(vertexInfo.map(\.sum))
        edgeNormals = Self.buffer(info.map(\.sums))
        let (suspectFlags, featureBits) = faces.withUnsafeBufferPointer { faceBuffer in
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
        suspect = Self.buffer(suspectFlags)
        reliableVertices = Self.mutableBuffer(vertexInfo.map { !$0.unsigned })
        reliableFeatures = Self.mutableBuffer(featureBits)

        var hierarchy = Hierarchy(coordinates: flat, faces: faces)
        if !faces.isEmpty {
            hierarchy.build()
        }
        nodes = Self.buffer(hierarchy.nodes)
        order = Self.buffer(hierarchy.order)
        hierarchy.deallocate()

        var flatBoxes = [Double](repeating: 0, count: 6 * hierarchy.nodes.count)
        for (n, node) in hierarchy.nodes.enumerated() {
            flatBoxes[6 * n] = node.lower.x; flatBoxes[6 * n + 1] = node.lower.y; flatBoxes[6 * n + 2] = node.lower.z
            flatBoxes[6 * n + 3] = node.upper.x; flatBoxes[6 * n + 4] = node.upper.y; flatBoxes[6 * n + 5] = node.upper.z
        }
        boxes = Self.buffer(flatBoxes)

        let nodeCount = hierarchy.nodes.count
        var linkArray = [Int32](repeating: 0, count: 2 * nodeCount)
        var childBoxArray = [Float](repeating: 0, count: 12 * nodeCount)
        func lowered(_ value: Double) -> Float { let f = Float(value); return Double(f) > value ? f.nextDown : f }
        func raised(_ value: Double) -> Float { let f = Float(value); return Double(f) < value ? f.nextUp : f }
        var n = 0
        while n < nodeCount {
            let node = hierarchy.nodes[n]
            if node.left < 0 {
                linkArray[2 * n] = Int32(-1 - node.first); linkArray[2 * n + 1] = Int32(node.count)
            } else {
                linkArray[2 * n] = Int32(node.left); linkArray[2 * n + 1] = Int32(node.right)
                var slot = 0
                while slot < 2 {
                    let child = hierarchy.nodes[slot == 0 ? node.left : node.right]
                    let base = 12 * n + 6 * slot
                    childBoxArray[base] = lowered(child.lower.x); childBoxArray[base + 1] = lowered(child.lower.y)
                    childBoxArray[base + 2] = lowered(child.lower.z); childBoxArray[base + 3] = raised(child.upper.x)
                    childBoxArray[base + 4] = raised(child.upper.y); childBoxArray[base + 5] = raised(child.upper.z)
                    slot += 1
                }
            }
            n += 1
        }
        links = Self.buffer(linkArray)
        childBoxes = Self.buffer(childBoxArray)
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
        orderedCorners = Self.buffer(cornerArray)

        // Faces inside the solid, as meshes that intersect themselves have: material in front of them, or none
        // behind. Their pseudonormals say nothing about the solid, so near them the winding number decides.
        let diagonal = (bounds.1 - bounds.0).magnitude
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
        topology.deallocate()
    }

    /// The angle between two vectors
    private static func angle(_ u: Vector3D, _ v: Vector3D) -> Double {
        let lengths = u.magnitude * v.magnitude
        guard lengths > 0 else { return 0 }
        return Foundation.acos(min(max((u ⋅ v) / lengths, -1), 1))
    }

    var faceCount: Int { faces.count }
    func face(_ index: Int) -> Face { faces[index] }
    func faceNormal(_ index: Int) -> Vector3D { faceNormals[index] }
    /// Whether a face is a sliver, lies along a possibly folded edge, or touches one: its normal can't be trusted
    func isSuspect(_ index: Int) -> Bool { suspect[index] }

    static func edgeKey(_ a: Int, _ b: Int) -> UInt64 {
        a < b ? UInt64(a) << 32 | UInt64(b) : UInt64(b) << 32 | UInt64(a)
    }

    /// The faces around each vertex, in one flat array, to find the faces sharing each edge without a table of edges
    /// Raw buffers, not arrays: it's read from every core at once, and in unoptimized builds every array access
    /// would retain and release the storage, all cores contending for its reference count. The one who creates it
    /// deallocates it.
    private struct Topology: @unchecked Sendable {
        let faces: UnsafeBufferPointer<Face>
        let offsets: UnsafeBufferPointer<Int>
        let members: UnsafeBufferPointer<Int>

        func deallocate() {
            faces.deallocate(); offsets.deallocate(); members.deallocate()
        }

        init(vertexCount: Int, faces: [Face]) {
            self.faces = MeshDistanceField.buffer(faces)
            var counts = [Int](repeating: 0, count: vertexCount + 1)
            for face in faces { counts[face.0 + 1] += 1; counts[face.1 + 1] += 1; counts[face.2 + 1] += 1 }
            var v = 0
            while v < vertexCount { counts[v + 1] += counts[v]; v += 1 }
            var next = counts
            var members = [Int](repeating: 0, count: 3 * faces.count)
            var index = 0
            while index < faces.count {
                let face = faces[index]
                members[next[face.0]] = index; next[face.0] += 1
                members[next[face.1]] = index; next[face.1] += 1
                members[next[face.2]] = index; next[face.2] += 1
                index += 1
            }
            offsets = MeshDistanceField.buffer(counts)
            self.members = MeshDistanceField.buffer(members)
        }

        /// Calls body with every other face sharing edge k of a face (from corner k to k + 1)
        func forEachSharing(face index: Int, edge k: Int, _ body: (Int) -> Void) {
            let face = faces[index]
            let a = k == 0 ? face.0 : k == 1 ? face.1 : face.2
            let b = k == 0 ? face.1 : k == 1 ? face.2 : face.0
            var n = offsets[a]
            while n < offsets[a + 1] {
                let other = faces[members[n]]
                if members[n] != index && (other.0 == b || other.1 == b || other.2 == b) { body(members[n]) }
                n += 1
            }
        }
    }

    /// Builds the bounding volume hierarchy, splitting at the median centroid along the centroids' longest extent.
    /// Medians come from selection rather than sorting, and each node's box and dipole from its children.
    private struct Hierarchy {
        // Raw buffers while building: array accesses in this recursion pay for uniqueness checks and reference
        // counting in unoptimized builds
        private let coordinates: UnsafeMutableBufferPointer<Double>
        private let faces: UnsafeMutableBufferPointer<Face>
        private let orderBuffer: UnsafeMutableBufferPointer<Int>
        /// Three times each face's centroid, per axis
        private let centroids: UnsafeMutableBufferPointer<Double>
        private let faceCount: Int
        var nodes: [Node] = []
        var order: [Int] { Array(orderBuffer) }

        init(coordinates: [Double], faces: [Face]) {
            faceCount = faces.count
            self.coordinates = .allocate(capacity: max(coordinates.count, 1))
            _ = self.coordinates.initialize(from: coordinates)
            self.faces = .allocate(capacity: max(faces.count, 1))
            _ = self.faces.initialize(from: faces)
            orderBuffer = .allocate(capacity: max(faces.count, 1))
            centroids = .allocate(capacity: max(3 * faces.count, 1))
            nodes.reserveCapacity(2 * faces.count)
            var index = 0
            while index < faces.count {
                orderBuffer[index] = index
                let face = faces[index]
                var axis = 0
                while axis < 3 {
                    centroids[3 * index + axis] = coordinates[3 * face.0 + axis] + coordinates[3 * face.1 + axis] + coordinates[3 * face.2 + axis]
                    axis += 1
                }
                index += 1
            }
        }

        func deallocate() {
            coordinates.deallocate(); faces.deallocate(); orderBuffer.deallocate(); centroids.deallocate()
        }

        private func vertex(_ v: Int) -> Vector3D {
            Vector3D(coordinates[3 * v], coordinates[3 * v + 1], coordinates[3 * v + 2])
        }

        /// Builds the tree over all faces, with its root first. The top levels split serially into subtrees of
        /// disjoint face ranges, which build in parallel into their own node lists and are then joined.
        mutating func build() {
            guard faceCount > 0 else { return }
            let serialLimit = max(1024, faceCount / 64)
            // Nodes above the subtrees, in creation order (parents before children), with where their faces start
            struct Pending { let index: Int; var left = -1, right = -1 }
            var pending: [Pending] = []
            var tasks: [(first: Int, count: Int, parent: Int, isLeft: Bool)] = []
            func split(_ first: Int, _ count: Int, parent: Int, isLeft: Bool) {
                if count <= serialLimit {
                    tasks.append((first, count, parent, isLeft))
                    return
                }
                let index = nodes.count
                nodes.append(Node(lower: .zero, upper: .zero))
                if parent >= 0 {
                    if isLeft { pending[parent].left = index } else { pending[parent].right = index }
                }
                let slot = pending.count
                pending.append(Pending(index: index))
                let middle = splitPoint(first: first, count: count)
                split(first, middle - first, parent: slot, isLeft: true)
                split(middle, first + count - middle, parent: slot, isLeft: false)
            }
            split(0, faceCount, parent: -1, isLeft: true)
            // The subtrees, each into its own list with its root first. Their face ranges are disjoint, so they
            // reorder their own parts of the shared order concurrently.
            nonisolated(unsafe) let builder = self
            let ranges = tasks.map { (first: $0.first, count: $0.count) }
            // Dispatched one per subtree: they're few and large, too few for a concurrent loop to split up
            var built = [[Node]](repeating: [], count: ranges.count)
            built.withUnsafeMutableBufferPointer { buffer in
                nonisolated(unsafe) let built = buffer
                DispatchQueue.concurrentPerform(iterations: ranges.count) { n in
                    var local: [Node] = []
                    local.reserveCapacity(2 * ranges[n].count / 3 + 1)
                    _ = builder.build(first: ranges[n].first, count: ranges[n].count, into: &local)
                    built[n] = local
                }
            }
            for (n, task) in tasks.enumerated() {
                let offset = nodes.count
                for var node in built[n] {
                    if node.left >= 0 { node.left += offset; node.right += offset }
                    nodes.append(node)
                }
                if task.parent >= 0 {
                    if task.isLeft { pending[task.parent].left = offset } else { pending[task.parent].right = offset }
                }
            }
            // The nodes above them, children first
            for entry in pending.reversed() {
                let l = nodes[entry.left], r = nodes[entry.right]
                let leftArea = l.weight, rightArea = r.weight
                nodes[entry.index] = Self.finished(lower: .min(l.lower, r.lower), upper: .max(l.upper, r.upper), area: l.area + r.area,
                                                   weightedCenter: l.center * leftArea + r.center * rightArea, totalArea: leftArea + rightArea)
                nodes[entry.index].left = entry.left
                nodes[entry.index].right = entry.right
            }
        }

        /// Where to split the faces in first..<first + count: along the centroids' longest extent
        private func splitPoint(first: Int, count: Int) -> Int {
            var low = (Double.infinity, Double.infinity, Double.infinity), high = (-Double.infinity, -Double.infinity, -Double.infinity)
            var i = first
            while i < first + count {
                let f = orderBuffer[i]
                low = (min(low.0, centroids[3 * f]), min(low.1, centroids[3 * f + 1]), min(low.2, centroids[3 * f + 2]))
                high = (max(high.0, centroids[3 * f]), max(high.1, centroids[3 * f + 1]), max(high.2, centroids[3 * f + 2]))
                i += 1
            }
            let extent = (high.0 - low.0, high.1 - low.1, high.2 - low.2)
            let axis = extent.0 >= extent.1 && extent.0 >= extent.2 ? 0 : (extent.1 >= extent.2 ? 1 : 2)
            return splitBySurfaceArea(first: first, count: count, axis: axis,
                                      low: axis == 0 ? low.0 : axis == 1 ? low.1 : low.2,
                                      high: axis == 0 ? high.0 : axis == 1 ? high.1 : high.2)
        }

        /// Builds the subtree over first..<first + count into a node list, and returns its root's index there
        private func build(first: Int, count: Int, into nodes: inout [Node]) -> Int {
            let index = nodes.count
            nodes.append(Node(lower: .zero, upper: .zero))

            if count <= 4 {
                let seed = vertex(faces[orderBuffer[first]].0)
                var lower = seed, upper = seed
                var area = Vector3D.zero, weightedCenter = Vector3D.zero, totalArea = 0.0
                var i = first
                while i < first + count {
                    let face = faces[orderBuffer[i]]
                    let a = vertex(face.0), b = vertex(face.1), c = vertex(face.2)
                    lower = .min(lower, .min(a, .min(b, c)))
                    upper = .max(upper, .max(a, .max(b, c)))
                    let doubleArea = (b - a) × (c - a)
                    let weight = doubleArea.magnitude / 2
                    area = area + doubleArea * 0.5
                    weightedCenter = weightedCenter + (a + b + c) * (weight / 3)
                    totalArea += weight
                    i += 1
                }
                nodes[index] = Self.finished(lower: lower, upper: upper, area: area, weightedCenter: weightedCenter, totalArea: totalArea)
                nodes[index].first = first
                nodes[index].count = count
                return index
            }

            let middle = splitPoint(first: first, count: count)
            let left = build(first: first, count: middle - first, into: &nodes)
            let right = build(first: middle, count: first + count - middle, into: &nodes)
            let l = nodes[left], r = nodes[right]
            // Dipoles combine as sums; their weighted centers are recovered from center times area
            let leftArea = l.weight, rightArea = r.weight
            nodes[index] = Self.finished(lower: .min(l.lower, r.lower), upper: .max(l.upper, r.upper), area: l.area + r.area,
                                         weightedCenter: l.center * leftArea + r.center * rightArea, totalArea: leftArea + rightArea)
            nodes[index].left = left
            nodes[index].right = right
            return index
        }

        private static func finished(lower: Vector3D, upper: Vector3D, area: Vector3D, weightedCenter: Vector3D, totalArea: Double) -> Node {
            let center = totalArea > 0 ? weightedCenter / totalArea : (lower + upper) / 2
            var radius = 0.0
            var corner = 0
            while corner < 8 {
                let point = Vector3D(corner & 1 == 0 ? lower.x : upper.x, corner & 2 == 0 ? lower.y : upper.y, corner & 4 == 0 ? lower.z : upper.z)
                radius = max(radius, (point - center).magnitude)
                corner += 1
            }
            return Node(lower: lower, upper: upper, area: area, center: center, radius: radius, weight: totalArea)
        }

        /// Splits the faces in first..<first + count where the children's boxes have the least surface area for the faces
        /// they hold (binned along the axis), so queries visit fewer nodes; or at the median where that's degenerate.
        /// Returns where the second child starts.
        private func splitBySurfaceArea(first: Int, count: Int, axis: Int, low: Double, high: Double) -> Int {
            let binCount = 16
            guard high > low else {
                select(first + count / 2, from: first, to: first + count, axis: axis)
                return first + count / 2
            }
            let scale = Double(binCount) / (high - low)
            func bin(_ face: Int) -> Int { min(binCount - 1, Int((centroids[3 * face + axis] - low) * scale)) }
            // Each bin's face count and box, as lower then upper corner, and the cost of splitting after it, on the
            // stack: this runs for every node, and arrays allocate
            let best = withUnsafeTemporaryAllocation(of: Int.self, capacity: binCount) { counts in
            withUnsafeTemporaryAllocation(of: Double.self, capacity: 7 * binCount) { storage in
                let boxes = storage.baseAddress!, leftCost = storage.baseAddress! + 6 * binCount
                return bestSplit(first: first, count: count, binCount: binCount, bin: bin, counts: counts.baseAddress!, boxes: boxes, leftCost: leftCost)
            }
            }
            guard best >= 0 else {
                select(first + count / 2, from: first, to: first + count, axis: axis)
                return first + count / 2
            }
            // Partition: faces in bins up to the best one first
            var lower = first, upper = first + count - 1
            while lower <= upper {
                if bin(orderBuffer[lower]) <= best { lower += 1 }
                else {
                    let swapped = orderBuffer[lower]; orderBuffer[lower] = orderBuffer[upper]; orderBuffer[upper] = swapped
                    upper -= 1
                }
            }
            return lower
        }

        /// The bin after which splitting costs least, or -1 where no split separates anything
        private func bestSplit(first: Int, count: Int, binCount: Int, bin: (Int) -> Int, counts: UnsafeMutablePointer<Int>,
                               boxes: UnsafeMutablePointer<Double>, leftCost: UnsafeMutablePointer<Double>) -> Int {
            var b = 0
            while b < binCount { counts[b] = 0; leftCost[b] = 0; b += 1 }
            b = 0
            while b < binCount {
                boxes[6 * b] = .infinity; boxes[6 * b + 1] = .infinity; boxes[6 * b + 2] = .infinity
                boxes[6 * b + 3] = -.infinity; boxes[6 * b + 4] = -.infinity; boxes[6 * b + 5] = -.infinity
                b += 1
            }
            var i = first
            while i < first + count {
                let f = orderBuffer[i]
                let target = bin(f)
                counts[target] += 1
                let face = faces[f]
                var corner = 0
                while corner < 3 {
                    let v = corner == 0 ? face.0 : corner == 1 ? face.1 : face.2
                    var a = 0
                    while a < 3 {
                        boxes[6 * target + a] = min(boxes[6 * target + a], coordinates[3 * v + a])
                        boxes[6 * target + 3 + a] = max(boxes[6 * target + 3 + a], coordinates[3 * v + a])
                        a += 1
                    }
                    corner += 1
                }
                i += 1
            }
            func area(_ box: (Double, Double, Double, Double, Double, Double)) -> Double {
                let dx = box.3 - box.0, dy = box.4 - box.1, dz = box.5 - box.2
                return dx >= 0 ? dx * dy + dy * dz + dz * dx : 0
            }
            func merged(_ box: (Double, Double, Double, Double, Double, Double), _ b: Int) -> (Double, Double, Double, Double, Double, Double) {
                (min(box.0, boxes[6 * b]), min(box.1, boxes[6 * b + 1]), min(box.2, boxes[6 * b + 2]),
                 max(box.3, boxes[6 * b + 3]), max(box.4, boxes[6 * b + 4]), max(box.5, boxes[6 * b + 5]))
            }
            let empty = (Double.infinity, Double.infinity, Double.infinity, -Double.infinity, -Double.infinity, -Double.infinity)
            // Cost of splitting after each bin: the left side's area and count from the left, the right's from the right
            var box = empty, running = 0
            b = 0
            while b < binCount - 1 {
                box = merged(box, b); running += counts[b]
                leftCost[b] = area(box) * Double(running)
                b += 1
            }
            var best = -1, bestCost = Double.infinity
            box = empty; running = 0
            b = binCount - 1
            while b > 0 {
                box = merged(box, b); running += counts[b]
                let left = count - running
                if left > 0 && running > 0 {
                    let cost = leftCost[b - 1] + area(box) * Double(running)
                    if cost < bestCost { bestCost = cost; best = b - 1 }
                }
                b -= 1
            }
            return best
        }

        /// Reorders the faces in first..<end so the one at `nth` is the one sorting would put there, with no larger
        /// one before it and no smaller one after (Hoare's selection)
        private func select(_ nth: Int, from first: Int, to end: Int, axis: Int) {
            var low = first, high = end - 1
            while low < high {
                let pivot = centroids[3 * orderBuffer[(low + high) / 2] + axis]
                var i = low, j = high
                while i <= j {
                    while centroids[3 * orderBuffer[i] + axis] < pivot { i += 1 }
                    while centroids[3 * orderBuffer[j] + axis] > pivot { j -= 1 }
                    if i <= j {
                        let swapped = orderBuffer[i]; orderBuffer[i] = orderBuffer[j]; orderBuffer[j] = swapped
                        i += 1; j -= 1
                    }
                }
                if nth <= j { high = j } else if nth >= i { low = i } else { return }
            }
        }
    }

    /// Squared distance from a point to a node's box, zero inside
    private func boxDistanceSquared(_ index: Int, _ x: Double, _ y: Double, _ z: Double) -> Double {
        let b = boxes.baseAddress! + 6 * index
        var total = 0.0
        if x < b[0] { total += (b[0] - x) * (b[0] - x) } else if x > b[3] { total += (x - b[3]) * (x - b[3]) }
        if y < b[1] { total += (b[1] - y) * (b[1] - y) } else if y > b[4] { total += (y - b[4]) * (y - b[4]) }
        if z < b[2] { total += (b[2] - z) * (b[2] - z) } else if z > b[5] { total += (z - b[5]) * (z - b[5]) }
        return total
    }

    /// The closest point on a face to (px, py, pz), in scalars: its squared distance, its position, and which feature
    /// it lies on (0 to 2: corners, 3 to 5: edges from corner k to k + 1, 6: the interior).
    /// Ericson, Real-Time Collision Detection 5.1.5.
    private struct FacePoint {
        var distanceSquared: Double
        var x: Double, y: Double, z: Double
        var feature: Int
    }

    private func facePoint(_ index: Int, _ px: Double, _ py: Double, _ pz: Double) -> FacePoint {
        let face = faces[index]
        let c = coordinates.baseAddress!
        return Self.facePoint(
            c[3 * face.0], c[3 * face.0 + 1], c[3 * face.0 + 2],
            c[3 * face.1], c[3 * face.1 + 1], c[3 * face.1 + 2],
            c[3 * face.2], c[3 * face.2 + 1], c[3 * face.2 + 2],
            px, py, pz
        )
    }

    /// The same for a face given by the coordinates of its corners
    @inline(__always)
    private static func facePoint(
        _ ax: Double, _ ay: Double, _ az: Double, _ bx: Double, _ by: Double, _ bz: Double,
        _ cx: Double, _ cy: Double, _ cz: Double, _ px: Double, _ py: Double, _ pz: Double
    ) -> FacePoint {
        func result(_ x: Double, _ y: Double, _ z: Double, _ feature: Int) -> FacePoint {
            let dx = px - x, dy = py - y, dz = pz - z
            return FacePoint(distanceSquared: dx * dx + dy * dy + dz * dz, x: x, y: y, z: z, feature: feature)
        }
        let abx = bx - ax, aby = by - ay, abz = bz - az
        let acx = cx - ax, acy = cy - ay, acz = cz - az
        let apx = px - ax, apy = py - ay, apz = pz - az
        let d1 = abx * apx + aby * apy + abz * apz, d2 = acx * apx + acy * apy + acz * apz
        if d1 <= 0 && d2 <= 0 { return result(ax, ay, az, 0) }
        let bpx = px - bx, bpy = py - by, bpz = pz - bz
        let d3 = abx * bpx + aby * bpy + abz * bpz, d4 = acx * bpx + acy * bpy + acz * bpz
        if d3 >= 0 && d4 <= d3 { return result(bx, by, bz, 1) }
        let vc = d1 * d4 - d3 * d2
        // Each edge's squared length is the denominator of its parameter; one of zero length (two corners
        // coinciding) is its corner, which is where the point projects anyway
        if vc <= 0 && d1 >= 0 && d3 <= 0 {
            guard d1 - d3 > 0 else { return result(ax, ay, az, 0) }
            let t = d1 / (d1 - d3)
            return result(ax + abx * t, ay + aby * t, az + abz * t, 3)
        }
        let cpx = px - cx, cpy = py - cy, cpz = pz - cz
        let d5 = abx * cpx + aby * cpy + abz * cpz, d6 = acx * cpx + acy * cpy + acz * cpz
        if d6 >= 0 && d5 <= d6 { return result(cx, cy, cz, 2) }
        let vb = d5 * d2 - d1 * d6
        if vb <= 0 && d2 >= 0 && d6 <= 0 {
            guard d2 - d6 > 0 else { return result(ax, ay, az, 0) }
            let t = d2 / (d2 - d6)
            return result(ax + acx * t, ay + acy * t, az + acz * t, 5)
        }
        let va = d3 * d6 - d5 * d4
        if va <= 0 && (d4 - d3) >= 0 && (d5 - d6) >= 0 {
            guard (d4 - d3) + (d5 - d6) > 0 else { return result(bx, by, bz, 1) }
            let t = (d4 - d3) / ((d4 - d3) + (d5 - d6))
            return result(bx + (cx - bx) * t, by + (cy - by) * t, bz + (cz - bz) * t, 4)
        }
        // A degenerate triangle (all corners on a line) has no interior: the edges above have already covered it
        let sum = va + vb + vc
        guard sum > 0 else { return result(ax, ay, az, 0) }
        let denominator = 1 / sum
        let v = vb * denominator, w = vc * denominator
        return result(ax + abx * v + acx * w, ay + aby * v + acy * w, az + abz * v + acz * w, 6)
    }

    /// The full answer for a face point: its pseudonormal, and whether that can be trusted
    private func closest(_ point: FacePoint, onFace index: Int) -> Closest {
        let face = faces[index]
        let reliable = reliableFeatures[index]
        let normal: Vector3D, isReliable: Bool
        switch point.feature {
        case 0: normal = vertexNormals[face.0]; isReliable = reliableVertices[face.0]
        case 1: normal = vertexNormals[face.1]; isReliable = reliableVertices[face.1]
        case 2: normal = vertexNormals[face.2]; isReliable = reliableVertices[face.2]
        case 3: normal = edgeNormals[index].0; isReliable = reliable & 2 != 0
        case 4: normal = edgeNormals[index].1; isReliable = reliable & 4 != 0
        case 5: normal = edgeNormals[index].2; isReliable = reliable & 8 != 0
        default: normal = faceNormals[index]; isReliable = reliable & 1 != 0
        }
        return Closest(distanceSquared: point.distanceSquared, point: Vector3D(point.x, point.y, point.z), pseudonormal: normal, face: index, isReliable: isReliable)
    }

    /// The closest point on one face, and the pseudonormal of the feature (face, edge or vertex) it lies on
    private func closest(to p: Vector3D, onFace index: Int) -> Closest {
        closest(facePoint(index, p.x, p.y, p.z), onFace: index)
    }

    /// The closest point on the mesh. A hint, a face likely to be near (such as the answer for a nearby point),
    /// gives the search an early bound; the result is exact either way. With a limit, only points closer than it
    /// are looked for, which ends searches from far away much sooner; where there are none, the face is -1.
    func closest(to p: Vector3D, hint: Int? = nil, within limit: Double = .infinity) -> Closest {
        let none = Closest(distanceSquared: .infinity, point: .zero, pseudonormal: .zero, face: -1, isReliable: false)
        guard !nodes.isEmpty else { return none }
        let px = p.x, py = p.y, pz = p.z
        var best = FacePoint(distanceSquared: limit * limit, x: 0, y: 0, z: 0, feature: 0)
        var bestFace = -1
        if let hint, hint >= 0 {
            let candidate = facePoint(hint, px, py, pz)
            if candidate.distanceSquared < best.distanceSquared { best = candidate; bestFace = hint }
        }
        // Nodes to visit, with the squared distance to their boxes when they were queued: the bound may have
        // tightened since, ruling them out without a look
        let rootDistance = boxDistanceSquared(0, px, py, pz)
        if rootDistance < best.distanceSquared {
            let links = self.links.baseAddress!, childBoxes = self.childBoxes.baseAddress!
            let corners = orderedCorners.baseAddress!, order = self.order.baseAddress!
            withUnsafeTemporaryAllocation(of: Int32.self, capacity: 128) { stack in
            withUnsafeTemporaryAllocation(of: Double.self, capacity: 128) { bounds in
                var top = 1
                stack[0] = 0
                bounds[0] = rootDistance
                while top > 0 {
                    top -= 1
                    if bounds[top] >= best.distanceSquared { continue }
                    let index = Int(stack[top])
                    let first = Int(links[2 * index]), second = Int(links[2 * index + 1])
                    if first < 0 {
                        // Counted loops: range iteration is generic, and slow in unoptimized builds
                        var position = -1 - first
                        let end = position + second
                        while position < end {
                            let c = corners + 9 * position
                            let candidate = Self.facePoint(c[0], c[1], c[2], c[3], c[4], c[5], c[6], c[7], c[8], px, py, pz)
                            if candidate.distanceSquared < best.distanceSquared { best = candidate; bestFace = order[position] }
                            position += 1
                        }
                        continue
                    }
                    // Written out rather than called: unoptimized builds don't inline, and this is the innermost loop
                    let box = childBoxes + 12 * index
                    var dl = 0.0, dr = 0.0
                    var lo = Double(box[0]), hi = Double(box[3])
                    if px < lo { dl += (lo - px) * (lo - px) } else if px > hi { dl += (px - hi) * (px - hi) }
                    lo = Double(box[1]); hi = Double(box[4])
                    if py < lo { dl += (lo - py) * (lo - py) } else if py > hi { dl += (py - hi) * (py - hi) }
                    lo = Double(box[2]); hi = Double(box[5])
                    if pz < lo { dl += (lo - pz) * (lo - pz) } else if pz > hi { dl += (pz - hi) * (pz - hi) }
                    lo = Double(box[6]); hi = Double(box[9])
                    if px < lo { dr += (lo - px) * (lo - px) } else if px > hi { dr += (px - hi) * (px - hi) }
                    lo = Double(box[7]); hi = Double(box[10])
                    if py < lo { dr += (lo - py) * (lo - py) } else if py > hi { dr += (py - hi) * (py - hi) }
                    lo = Double(box[8]); hi = Double(box[11])
                    if pz < lo { dr += (lo - pz) * (lo - pz) } else if pz > hi { dr += (pz - hi) * (pz - hi) }
                    // The nearer child on top, to be searched first
                    let (near, nearDistance, far, farDistance) = dl < dr ? (first, dl, second, dr) : (second, dr, first, dl)
                    if farDistance < best.distanceSquared { stack[top] = Int32(far); bounds[top] = farDistance; top += 1 }
                    if nearDistance < best.distanceSquared { stack[top] = Int32(near); bounds[top] = nearDistance; top += 1 }
                }
            }
            }
        }
        guard bestFace >= 0 else { return none }
        return closest(best, onFace: bestFace)
    }

    /// Whether a face crosses another face it doesn't share a corner with, as where a mesh intersects itself: there,
    /// a face lies partly inside the solid, so its pseudonormals can't be trusted anywhere along it
    private func intersectsOtherFaces(_ index: Int) -> Bool {
        let face = faces[index]
        let a = vertexBuffer[face.0], b = vertexBuffer[face.1], c = vertexBuffer[face.2]
        // Grown by the tolerance coplanar faces are allowed: flat faces off each other's plane by less than it
        // still overlap, though their boxes miss each other
        let margin = Vector3D(planeTolerance, planeTolerance, planeTolerance)
        let lower = Vector3D.min(a, .min(b, c)) - margin, upper = Vector3D.max(a, .max(b, c)) + margin
        return withUnsafeTemporaryAllocation(of: Int.self, capacity: 128) { stack in
            var top = 1
            stack[0] = 0
            while top > 0 {
                top -= 1
                let nodeIndex = stack[top]
                let box = boxes.baseAddress! + 6 * nodeIndex
                if box[0] > upper.x || box[3] < lower.x || box[1] > upper.y || box[4] < lower.y || box[2] > upper.z || box[5] < lower.z { continue }
                let node = nodes[nodeIndex]
                if node.left < 0 {
                    var i = node.first
                    while i < node.first + node.count {
                        let other = order[i]
                        i += 1
                        guard other != index else { continue }
                        let o = faces[other]
                        let p = vertexBuffer[o.0], q = vertexBuffer[o.1], r = vertexBuffer[o.2]
                        // Faces whose boxes don't touch can neither overlap nor cross
                        if min(p.x, min(q.x, r.x)) > upper.x || max(p.x, max(q.x, r.x)) < lower.x
                            || min(p.y, min(q.y, r.y)) > upper.y || max(p.y, max(q.y, r.y)) < lower.y
                            || min(p.z, min(q.z, r.z)) > upper.z || max(p.z, max(q.z, r.z)) < lower.z { continue }
                        // Coplanar faces can overlap even where they share a corner, as where a sheet folds flat
                        // onto its neighbor's; a shared corner alone lies on both, which doesn't count as overlap
                        if Self.coplanarTrianglesOverlap(a, b, c, normal: faceNormals[index], p, q, r, tolerance: planeTolerance) { return true }
                        // Faces sharing a corner meet there by construction
                        if o.0 == face.0 || o.0 == face.1 || o.0 == face.2 || o.1 == face.0 || o.1 == face.1 || o.1 == face.2
                            || o.2 == face.0 || o.2 == face.1 || o.2 == face.2 { continue }
                        if Self.segmentCrossesTriangle(a, b, p, q, r) || Self.segmentCrossesTriangle(b, c, p, q, r)
                            || Self.segmentCrossesTriangle(c, a, p, q, r) || Self.segmentCrossesTriangle(p, q, a, b, c)
                            || Self.segmentCrossesTriangle(q, r, a, b, c) || Self.segmentCrossesTriangle(r, p, a, b, c) {
                            return true
                        }
                    }
                    continue
                }
                stack[top] = node.left; stack[top + 1] = node.right; top += 2
            }
            return false
        }
    }

    /// Whether two triangles lie in one plane and overlap there, as where two sheets touch face to face: between
    /// them is no solid, whichever way their normals point
    private static func coplanarTrianglesOverlap(_ a: Vector3D, _ b: Vector3D, _ c: Vector3D, normal: Vector3D, _ p: Vector3D, _ q: Vector3D, _ r: Vector3D, tolerance: Double) -> Bool {
        guard normal != .zero else { return false }
        let offset = normal ⋅ a
        guard abs(normal ⋅ p - offset) <= tolerance, abs(normal ⋅ q - offset) <= tolerance, abs(normal ⋅ r - offset) <= tolerance else { return false }
        // In the plane of the axes the normal is least aligned with. Plain values throughout: this runs for every
        // pair of nearby faces, and small arrays and closures are slow in unoptimized builds.
        let nx = abs(normal.x), ny = abs(normal.y), nz = abs(normal.z)
        let drop = nx >= ny && nx >= nz ? 0 : (ny >= nz ? 1 : 2)
        func flat(_ v: Vector3D) -> (Double, Double) { drop == 0 ? (v.y, v.z) : drop == 1 ? (v.z, v.x) : (v.x, v.y) }
        let a2 = flat(a), b2 = flat(b), c2 = flat(c), p2 = flat(p), q2 = flat(q), r2 = flat(r)
        func cross(_ o: (Double, Double), _ u: (Double, Double), _ v: (Double, Double)) -> Double {
            (u.0 - o.0) * (v.1 - o.1) - (u.1 - o.1) * (v.0 - o.0)
        }
        // Separated if an edge of either has the whole other triangle strictly on its outer side
        func separates(_ u: (Double, Double), _ v: (Double, Double), _ orientation: Double,
                       _ x: (Double, Double), _ y: (Double, Double), _ z: (Double, Double)) -> Bool {
            cross(u, v, x) * orientation <= 0 && cross(u, v, y) * orientation <= 0 && cross(u, v, z) * orientation <= 0
        }
        let firstOrientation = cross(a2, b2, c2), secondOrientation = cross(p2, q2, r2)
        guard firstOrientation != 0, secondOrientation != 0 else { return false }
        if separates(a2, b2, firstOrientation, p2, q2, r2) || separates(b2, c2, firstOrientation, p2, q2, r2)
            || separates(c2, a2, firstOrientation, p2, q2, r2) { return false }
        if separates(p2, q2, secondOrientation, a2, b2, c2) || separates(q2, r2, secondOrientation, a2, b2, c2)
            || separates(r2, p2, secondOrientation, a2, b2, c2) { return false }
        return true
    }

    /// Whether the segment from s to e passes through the triangle (a, b, c), strictly: two non-coplanar triangles
    /// intersect exactly when an edge of one passes through the other
    private static func segmentCrossesTriangle(_ s: Vector3D, _ e: Vector3D, _ a: Vector3D, _ b: Vector3D, _ c: Vector3D) -> Bool {
        // (q − p) ⋅ ((r − p) × (t − p)) in scalars, in the same order: vector operations check their elements are
        // finite, which unoptimized builds don't inline, and this runs for every pair of nearby faces
        func volume(_ p: Vector3D, _ q: Vector3D, _ r: Vector3D, _ t: Vector3D) -> Double {
            let ux = q.x - p.x, uy = q.y - p.y, uz = q.z - p.z
            let vx = r.x - p.x, vy = r.y - p.y, vz = r.z - p.z
            let wx = t.x - p.x, wy = t.y - p.y, wz = t.z - p.z
            return ux * (vy * wz - vz * wy) + uy * (vz * wx - vx * wz) + uz * (vx * wy - vy * wx)
        }
        let side1 = volume(a, b, c, s), side2 = volume(a, b, c, e)
        guard (side1 > 0 && side2 < 0) || (side1 < 0 && side2 > 0) else { return false }
        let v1 = volume(s, e, a, b), v2 = volume(s, e, b, c), v3 = volume(s, e, c, a)
        return (v1 > 0 && v2 > 0 && v3 > 0) || (v1 < 0 && v2 < 0 && v3 < 0)
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
                    var i = node.first
                    while i < node.first + node.count {
                        let face = faces[order[i]]
                        let a = vertexBuffer[face.0] - p, b = vertexBuffer[face.1] - p, c = vertexBuffer[face.2] - p
                        let la = a.magnitude, lb = b.magnitude, lc = c.magnitude
                        total += 2 * Foundation.atan2(a ⋅ (b × c), la * lb * lc + (a ⋅ b) * lc + (a ⋅ c) * lb + (b ⋅ c) * la)
                        i += 1
                    }
                    continue
                }
                stack[top] = node.left; stack[top + 1] = node.right; top += 2
            }
            return total / (4 * .pi)
        }
    }

    /// Whether p is inside. The pseudonormal decides when it clearly can; where it involves defective faces, or runs
    /// nearly along the surface, the winding number does.
    func isInside(_ p: Vector3D, closest: Closest) -> Bool {
        let toward = p - closest.point
        let along = toward ⋅ closest.pseudonormal
        let lengths = toward.magnitude * closest.pseudonormal.magnitude
        if closest.isReliable, lengths > 0, abs(along) > 0.2 * lengths {
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
        coplanarNormal(within: radius, of: p).coplanar
    }

    /// The same, and the plane's normal, if there are faces within reach
    func coplanarNormal(within radius: Double, of p: Vector3D) -> (coplanar: Bool, normal: Vector3D?) {
        guard !nodes.isEmpty else { return (true, nil) }
        let radiusSquared = radius * radius
        var reference: (normal: Vector3D, offset: Double)? = nil
        let coplanar = withUnsafeTemporaryAllocation(of: Int.self, capacity: 128) { stack in
            var top = 1
            stack[0] = 0
            while top > 0 {
                top -= 1
                let index = stack[top]
                let node = nodes[index]
                if boxDistanceSquared(index, p.x, p.y, p.z) > radiusSquared { continue }
                if node.left < 0 {
                    var i = node.first
                    while i < node.first + node.count {
                        let faceIndex = order[i]
                        i += 1
                        if facePoint(faceIndex, p.x, p.y, p.z).distanceSquared > radiusSquared { continue }
                        let face = faces[faceIndex]
                        let normal = faceNormals[faceIndex]
                        // A degenerate face has no plane of its own; its corners still have to lie on the others'
                        if normal == .zero && reference == nil { continue }
                        guard let plane = reference else {
                            reference = (normal, normal ⋅ vertexBuffer[face.0])
                            continue
                        }
                        // Corners on the plane decide; the normal only has to face the same way, since meshes with
                        // single-precision coordinates tilt small faces' normals slightly
                        if normal != .zero && normal ⋅ plane.normal < 0.99 { return false }
                        if abs(plane.normal ⋅ vertexBuffer[face.0] - plane.offset) > planeTolerance
                            || abs(plane.normal ⋅ vertexBuffer[face.1] - plane.offset) > planeTolerance
                            || abs(plane.normal ⋅ vertexBuffer[face.2] - plane.offset) > planeTolerance {
                            return false
                        }
                    }
                    continue
                }
                stack[top] = node.left; stack[top + 1] = node.right; top += 2
            }
            return true
        }
        return (coplanar, coplanar ? reference?.normal : nil)
    }
}

internal extension Vector3D {
    /// The unit vector in this direction, or zero for a zero vector
    var safelyNormalized: Vector3D {
        let length = magnitude
        return length > 0 ? self / length : .zero
    }
}
