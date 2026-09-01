import Foundation
import Manifold3D

/// An arbitrary three-dimensional shape made up of flat polygonal faces.
///
/// A `Mesh` represents a solid, manifold 3D object constructed from a list of vertices and polygonal faces.
/// Each face must consist of at least three vertices, and the combined faces must form a watertight surface
/// of a solid 3D volume.
///
/// This mesh system supports internal caching based on an operation name and parameters to avoid redundant
/// geometry computation. The `name` and `cacheParameters` uniquely identify cached geometry results, enabling
/// Cadova to reuse previous computations when the same parameters are provided.
///
/// > Important: The combination of `name` and `cacheParameters` *must uniquely identify* the resulting mesh.
/// A good rule of thumb is: any inputs that affect faces or their vertex positions should be included in
/// `cacheParameters`. Values that are closed over inside the lookup closure may be omitted only if they never
/// change for the same operation. If different inputs can yield different geometry under the same cache key,
/// Cadova may incorrectly reuse stale results.
///
/// Use this type when importing or constructing complex geometry manually, such as converting from external
/// sources, procedural generation, or custom geometry definitions.
///
public struct Mesh<Vertex: Hashable & Sendable>: Geometry3D {
    private let storage: MeshStorage<Vertex>
    let lookup: @Sendable (Vertex) -> Vector3D
    let cacheName: String
    let cacheParameters: [any CacheKey]

    var faces: [[Vertex]] { storage.faces }

    internal init<Face: Sequence<Vertex>, FaceList: Sequence<Face>>(
        faces: FaceList,
        name cacheName: String,
        cacheParameters: [any Hashable & Sendable & Codable],
        value lookup: @escaping @Sendable (Vertex) -> Vector3D
    ){
        self.init(
            storage: MeshStorage(faces: faces.map { Array($0) }, lookup: lookup),
            name: cacheName,
            cacheParameters: cacheParameters,
            value: lookup
        )
    }

    internal init(
        storage: MeshStorage<Vertex>,
        name cacheName: String,
        cacheParameters: [any Hashable & Sendable & Codable],
        value lookup: @escaping @Sendable (Vertex) -> Vector3D
    ){
        self.storage = storage
        self.lookup = lookup
        self.cacheName = cacheName
        self.cacheParameters = cacheParameters
    }

    public var body: any Geometry3D {
        CachedNode(labeledCacheKey: LabeledCacheKey(operationName: cacheName, parameters: cacheParameters)) {
            StaticNodeGeometry(.shape(.mesh(meshData)))
        }
    }

    /// The mesh's vertex table and index-based faces, built at most once per mesh.
    internal var meshData: MeshData {
        storage.meshData
    }
}

/// Backing store for a `Mesh`, holding its faces and the `MeshData` derived from them and building each at most
/// once.
///
/// `Mesh` is an immutable `Sendable` value that gets captured by the `@Sendable` closure behind `body`'s
/// `CachedNode`, so a `lazy var` can't memoize anything here: the closure works on its own copy of the struct and
/// any value computed there is discarded along with it. A lock-guarded reference box gives compute-once behavior
/// that survives copying and stays safe to share across concurrency domains.
///
/// The work is also deferred rather than done in `init`, because a `Mesh` frequently never needs its `MeshData` at
/// all — `body`'s `CachedNode` only asks for it when the geometry cache misses, and sweeps and lofts produce these
/// meshes in bulk.
internal final class MeshStorage<Vertex: Hashable & Sendable>: @unchecked Sendable {
    /// A mesh's faces, optionally accompanied by an already-built `MeshData` describing exactly those faces.
    internal typealias Content = (faces: [[Vertex]], meshData: MeshData?)

    private enum State {
        case deferred(@Sendable () -> Content)
        case resolved(Content)
    }

    private let lock = NSLock()
    private let lookup: @Sendable (Vertex) -> Vector3D
    private var state: State

    internal init(faces: [[Vertex]], lookup: @escaping @Sendable (Vertex) -> Vector3D) {
        self.lookup = lookup
        self.state = .resolved((faces: faces, meshData: nil))
    }

    /// Creates a store whose faces — and possibly a `MeshData` inherited from another mesh — are produced on first
    /// use, so a mesh that is never realized costs nothing to build.
    internal init(
        deferring provider: @escaping @Sendable () -> Content,
        lookup: @escaping @Sendable (Vertex) -> Vector3D
    ) {
        self.lookup = lookup
        self.state = .deferred(provider)
    }

    internal var faces: [[Vertex]] {
        lock.lock()
        defer { lock.unlock() }
        return resolvedContent().faces
    }

    internal var meshData: MeshData {
        lock.lock()
        defer { lock.unlock() }

        let content = resolvedContent()
        if let meshData = content.meshData {
            return meshData
        }

        let meshData = Self.buildMeshData(faces: content.faces, lookup: lookup)
        state = .resolved((faces: content.faces, meshData: meshData))
        return meshData
    }

    private func resolvedContent() -> Content {
        switch state {
        case .resolved(let content):
            return content

        case .deferred(let provider):
            let content = provider()
            state = .resolved(content)
            return content
        }
    }

    private static func buildMeshData(
        faces: [[Vertex]],
        lookup: @Sendable (Vertex) -> Vector3D
    ) -> MeshData {
        var vertices: [Vector3D] = []
        var keyIndices: [Vertex: Int] = [:]

        // A closed triangle mesh has roughly half as many vertices as faces, and a polygonal one fewer still, so
        // the face count is already a generous estimate.
        vertices.reserveCapacity(faces.count)
        keyIndices.reserveCapacity(faces.count)

        let indexedFaces = faces.map {
            $0.map { key in
                if let index = keyIndices[key] {
                    return index
                } else {
                    vertices.append(lookup(key))
                    let index = vertices.endIndex - 1
                    keyIndices[key] = index
                    return index
                }
            }
        }

        return MeshData(vertices: vertices, faces: indexedFaces)
    }
}

public extension Mesh {
    /// Creates a mesh from a list of polygonal faces, using hashable keys to define points.
    ///
    /// The `name` and `cacheParameters` identify and differentiate cached geometry results,
    /// allowing Cadova to reuse previous results when the same parameters are used.
    ///
    /// The `value` closure converts each symbolic vertex key into its 3D coordinate, effectively
    /// defining the shape of the mesh by mapping keys to points in space.
    ///
    /// > Important: Ensure `name` + `cacheParameters` uniquely describe the produced mesh. Include in
    /// `cacheParameters` any inputs that influence the included faces or the positions returned from
    /// `value` and are not constant inside that closure. This prevents stale cache hits when modeling
    /// parameters change.
    ///
    /// - Parameters:
    ///   - faces: A sequence of faces, where each face is a sequence of keys representing points.
    ///   - name: A string identifying this mesh operation for caching purposes.
    ///   - cacheParameters: Values that differentiate cached results to avoid redundant computation.
    ///   - value: A closure that resolves a key to a 3D position (`Vector3D`).
    ///
    /// - Important: All faces must be closed (at least 3 points), and together they must define a complete solid
    ///              without holes or non-manifold edges.
    ///
    /// - Example:
    ///   ```swift
    ///   struct Pyramid: Geometry3D {
    ///       let sideCount: Int
    ///       let radius: Double
    ///       let height: Double
    ///
    ///       private enum Vertex: Hashable {
    ///           case apex
    ///           case base(Angle)
    ///       }
    ///
    ///       var body: any Geometry3D {
    ///           let angles = stride(from: 0°, to: 360°, by: 360° / Double(sideCount))
    ///
    ///           let sides: [[Vertex]] = angles.enumerated().map { i, angle in
    ///               let next = angles[(i + 1) % sideCount]
    ///               return [.apex, .base(angle), .base(next)]
    ///           }
    ///           let baseFace = angles.reversed().map { Vertex.base($0) }
    ///
    ///           Mesh(
    ///               faces: sides + [baseFace],
    ///               name: "Pyramid",
    ///               cacheParameters: sideCount, radius, height
    ///           ) { vertex in
    ///               switch vertex {
    ///               case .apex:
    ///                   Vector3D(z: height)
    ///
    ///               case .base(let angle):
    ///                   Vector3D(x: cos(angle) * radius, y: sin(angle) * radius)
    ///               }
    ///           }
    ///       }
    ///   }
    ///
    init<Face: Sequence<Vertex>, FaceList: Sequence<Face>>(
        faces: FaceList,
        name: String,
        cacheParameters: any Hashable & Sendable & Codable...,
        value: @escaping @Sendable (Vertex) -> Vector3D
    ) {
        self.init(faces: faces, name: name, cacheParameters: cacheParameters, value: value)
    }

    /// Creates a mesh from a list of polygonal faces defined directly by 3D coordinates.
    ///
    /// > Important: Ensure `name` + `cacheParameters` uniquely describe the produced mesh. Include
    /// any variable inputs that affect the resulting geometry so Cadova can safely reuse cached
    /// results without returning stale meshes.
    ///
    /// - Parameters:
    ///   - faces: A sequence of polygonal faces, where each face is a sequence of `Vector3D` points.
    ///   - name: A name used for caching the mesh.
    ///   - cacheParameters: Additional hashable parameters that uniquely identify this mesh for caching purposes.
    ///
    /// - Important: All faces must contain at least 3 points. The combined set of faces must define a closed and manifold solid.
    init<Face: Sequence<Vector3D>, FaceList: Sequence<Face>>(
        faces: FaceList,
        name: String,
        cacheParameters: any Hashable & Sendable & Codable...
    ) where Vertex == Vector3D {
        self.init(faces: faces, name: name, cacheParameters: cacheParameters, value: \.self)
    }
}

public extension Mesh {
    /// Returns a new mesh with corrected face winding based on volume orientation.
    ///
    /// If the mesh's signed volume is negative (indicating inward-facing normals),
    /// the face windings are flipped to ensure outward orientation.
    ///
    /// - Returns: A mesh with outward-facing normals.
    func correctingFaceWinding() -> Mesh<Vertex> {
        // The resulting cache key doesn't depend on the winding decision, so the decision itself — and the
        // `MeshData` it needs — can wait until something actually asks for this mesh's faces. That keeps a cache
        // hit on the returned mesh free. When the winding already points outward, the faces are unchanged and the
        // `MeshData` built to answer the question describes the new mesh just as well, so it carries over.
        let source = self

        return Mesh<Vertex>(
            storage: MeshStorage(deferring: {
                let meshData = source.meshData
                return meshData.signedVolume < 0
                    ? (faces: source.faces.map { $0.reversed() }, meshData: nil)
                    : (faces: source.faces, meshData: meshData)
            }, lookup: lookup),
            name: cacheName,
            cacheParameters: cacheParameters + ["flippedWinding"],
            value: lookup
        )
    }
}


public extension Mesh {
    /// Returns the total enclosed volume of the mesh, assuming a watertight solid.
    ///
    /// A positive value indicates outward-facing face winding. If the result is negative,
    /// consider calling `correctingFaceWinding()` to fix the orientation.
    var volume: Double {
        meshData.signedVolume
    }

    /// Returns the total surface area of the mesh, calculated from triangulated faces.
    var surfaceArea: Double {
        let data = meshData

        return data.faces.reduce(0.0) { total, face in
            guard face.count >= 3 else { return total }
            let p0 = data.vertices[face[0]]
            var faceArea = 0.0
            for i in 1..<(face.count - 1) {
                let p1 = data.vertices[face[i]]
                let p2 = data.vertices[face[i + 1]]
                faceArea += ((p1 - p0) × (p2 - p0)).magnitude * 0.5
            }
            return total + faceArea
        }
    }
}
