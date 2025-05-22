import Foundation
internal import Collections
import Manifold3D

/// An arbitrary three-dimensional shape made up of flat polygonal faces.
///
/// A `Mesh` represents a solid, manifold 3D object constructed from a list of vertices and polygonal faces.
/// Each face must consist of at least three vertices, and the combined faces must form a watertight surface
/// of a solid 3D volume.
///
/// Use this type when importing or constructing complex geometry manually, such as converting from external
/// sources, procedural generation, or custom geometry definitions.

public struct Mesh: CompositeGeometry {
    public typealias D = D3

    let meshData: MeshData

    internal init(_ meshData: MeshData) {
        self.meshData = meshData
    }

    internal init(vertices: [Vector3D], faces: [MeshData.Face]) {
        assert(vertices.count >= 4, "At least four points are needed for a Mesh")
        assert(faces.allSatisfy { $0.count >= 3 }, "Each face must contain at least three points")

        self.init(MeshData(vertices: vertices, faces: faces))
    }

    public var body: any Geometry3D {
        NodeBasedGeometry(.shape(.mesh(meshData)))
    }
}

public extension Mesh {
    /// Creates a mesh from a list of polygonal faces, using hashable keys to define points.
    ///
    /// This initializer is useful when you want to reference vertices by symbolic keys (e.g., enums, structs, numbers)
    /// and provide their 3D positions via a closure. Vertices are automatically deduplicated and indexed.
    ///
    /// - Parameters:
    ///   - faces: A sequence of faces, where each face is a sequence of keys representing points.
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
    ///           Mesh(faces: sides + [baseFace]) { vertex in
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

    init<
        Key: Hashable, Face: Sequence<Key>, FaceList: Sequence<Face>
    >(faces: FaceList, value: (Key) -> Vector3D) {
        var pointValues: [Vector3D] = []
        let orderedKeys = OrderedSet(faces.joined())
        let keyIndices: [Key: Int] = orderedKeys.reduce(into: [:]) { table, key in
            pointValues.append(value(key))
            table[key] = pointValues.endIndex - 1
        }

        self.init(vertices: pointValues, faces: faces.map {
            $0.map {
                guard let index = keyIndices[$0] else {
                    preconditionFailure("Undefined point key: \($0)")
                }
                return index
            }
        })
    }

    /// Creates a mesh from a list of polygonal faces defined directly by 3D coordinates.
    ///
    /// This initializer is useful for simpler use cases where each face is already defined by its vertex coordinates.
    ///
    /// - Parameter faces: A sequence of polygonal faces, where each face is a sequence of `Vector3D` points.
    ///
    /// - Important: All faces must contain at least 3 points. The combined set of faces must define a closed and manifold solid.
    init<Face: Sequence<Vector3D>, FaceList: Sequence<Face>>(faces: FaceList) {
        self.init(faces: faces, value: \.self)
    }
}

public extension Mesh {
    /// Returns a new mesh with corrected face winding based on volume orientation.
    ///
    /// If the mesh's signed volume is negative (indicating inward-facing normals),
    /// the face windings are flipped to ensure outward orientation.
    ///
    /// - Returns: A mesh with outward-facing normals.
    func correctingFaceWinding() -> Mesh {
        meshData.signedVolume < 0 ? Self(meshData.flipped()) : self
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
