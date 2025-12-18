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
public struct Mesh<Vertex: Hashable & Sendable>: Shape3D {
    let faces: [[Vertex]]
    let lookup: @Sendable (Vertex) -> Vector3D
    let cacheName: String
    let cacheParameters: [any CacheKey]

    internal init<Face: Sequence<Vertex>, FaceList: Sequence<Face>>(
        faces: FaceList,
        name cacheName: String,
        cacheParameters: [any Hashable & Sendable & Codable],
        value lookup: @escaping @Sendable (Vertex) -> Vector3D
    ){
        self.faces = faces.map { Array($0) }
        self.lookup = lookup
        self.cacheName = cacheName
        self.cacheParameters = cacheParameters
    }

    public var body: any Geometry3D {
        CachedNode(labeledCacheKey: LabeledCacheKey(operationName: cacheName, parameters: cacheParameters)) {
            NodeBasedGeometry(.shape(.mesh(meshData)))
        }
    }

    internal var meshData: MeshData {
        var vertices: [Vector3D] = []
        var keyIndices: [Vertex: Int] = [:]

        vertices.reserveCapacity(faces.count * 2)
        keyIndices.reserveCapacity(faces.count * 2)

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
    ///   struct Pyramid: Shape3D {
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
    /// - Parameter faces: A sequence of polygonal faces, where each face is a sequence of `Vector3D` points.
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
        Mesh<Vertex>(
            faces: meshData.signedVolume < 0 ? faces.map { $0.reversed() } : faces,
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
        meshData.faces.reduce(0.0) { total, face in
            guard face.count >= 3 else { return total }
            let p0 = meshData.vertices[face[0]]
            var faceArea = 0.0
            for i in 1..<(face.count - 1) {
                let p1 = meshData.vertices[face[i]]
                let p2 = meshData.vertices[face[i + 1]]
                faceArea += ((p1 - p0) × (p2 - p0)).magnitude * 0.5
            }
            return total + faceArea
        }
    }
}
