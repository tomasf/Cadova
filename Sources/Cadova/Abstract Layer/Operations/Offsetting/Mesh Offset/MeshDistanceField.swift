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

    struct Node {
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
    let vertexBuffer: UnsafeBufferPointer<Vector3D>
    let faces: UnsafeBufferPointer<Face>
    let faceNormals: UnsafeBufferPointer<Vector3D>
    let vertexNormals: UnsafeBufferPointer<Vector3D>
    let edgeNormals: UnsafeBufferPointer<(Vector3D, Vector3D, Vector3D)>   // per face, edge k runs from corner k to k + 1
    let suspect: UnsafeBufferPointer<Bool>
    /// Per face, whether the pseudonormals of its interior (bit 0) and of its edges (bits 1 to 3) can be trusted
    let reliableFeatures: UnsafeMutableBufferPointer<UInt8>
    let reliableVertices: UnsafeMutableBufferPointer<Bool>
    let nodes: UnsafeBufferPointer<Node>
    let order: UnsafeBufferPointer<Int>
    /// Vertex coordinates and node boxes as plain doubles (x, y, z per vertex; lower then upper per node): the hot
    /// loops work on scalars, since every vector operation checks its elements are finite, which unoptimized builds
    /// don't inline
    let coordinates: UnsafeBufferPointer<Double>
    /// How far a vertex may lie from a plane and still count as on it: the precision of single-precision
    /// coordinates at the mesh's scale, since meshes often come from single-precision storage
    let planeTolerance: Double
    let boxes: UnsafeBufferPointer<Double>
    /// For the closest point search, the tree in a compact form. Per node, its children, or for a leaf, minus one
    /// minus the position of its first face in `order` and its face count.
    let links: UnsafeBufferPointer<Int32>
    /// Per node, its children's boxes (lower then upper, first child then second) in single precision, rounded
    /// outward, so the search rules a child out without loading it
    let childBoxes: UnsafeBufferPointer<Float>
    /// Face corner coordinates in the tree's order, nine per face, so a leaf's faces are read in one sweep
    let orderedCorners: UnsafeBufferPointer<Double>

    static func mutableBuffer<T>(_ array: [T]) -> UnsafeMutableBufferPointer<T> {
        let buffer = UnsafeMutableBufferPointer<T>.allocate(capacity: max(array.count, 1))
        _ = buffer.initialize(from: array)
        return buffer
    }

    static func buffer<T>(_ array: [T]) -> UnsafeBufferPointer<T> {
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

        let (info, vertexInfo) = Self.surfaceInfo(vertices: vertices, faces: faces, normals: normals, topology: topology,
                                                  minimumHeight: minimumHeight)
        vertexNormals = Self.buffer(vertexInfo.map(\.sum))
        edgeNormals = Self.buffer(info.map(\.sums))
        let (suspectFlags, featureBits) = Self.trust(faces: faces, info: info, vertexInfo: vertexInfo, topology: topology)
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

        let tree = Self.compactTree(hierarchy.nodes, order: order, faces: faces, vertices: vertices)
        boxes = Self.buffer(tree.boxes)
        links = Self.buffer(tree.links)
        childBoxes = Self.buffer(tree.childBoxes)
        orderedCorners = Self.buffer(tree.corners)

        distrustInnerFaces(vertices: vertices, faces: faces, normals: normals, topology: topology,
                           diagonal: (bounds.1 - bounds.0).magnitude)
        topology.deallocate()
    }

    /// The angle between two vectors
    static func angle(_ u: Vector3D, _ v: Vector3D) -> Double {
        let lengths = u.magnitude * v.magnitude
        guard lengths > 0 else { return 0 }
        return Foundation.acos(min(max((u ⋅ v) / lengths, -1), 1))
    }

    var faceCount: Int { faces.count }
    func face(_ index: Int) -> Face { faces[index] }
    func faceNormal(_ index: Int) -> Vector3D { faceNormals[index] }
    /// Whether a face is a sliver, lies along a possibly folded edge, or touches one: its normal can't be trusted
    func isSuspect(_ index: Int) -> Bool { suspect[index] }
}
