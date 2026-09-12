import Foundation
import Manifold3D

internal struct MeshData: Sendable, Hashable, Codable {
    internal let vertices: [Vector3D]
    internal let faces: [Face]

    /// The materials of the faces, or `nil` when no face has one.
    internal let faceMaterials: FaceMaterials?

    internal typealias Face = [[Vector3D].Index]

    internal init(vertices: [Vector3D], faces: [Face], faceMaterials: FaceMaterials? = nil) {
        precondition(
            faceMaterials.map { $0.indices.count == faces.count } ?? true,
            "One material entry is needed per face"
        )
        self.vertices = vertices
        self.faces = faces
        // Materials nothing uses make no difference to the mesh, so they make none to its identity either.
        self.faceMaterials = faceMaterials.flatMap { $0.materials.isEmpty ? nil : $0 }
    }

    /// The faces cut into triangles. Faces with more than three vertices are triangulated; the rest
    /// pass through as they are.
    private func triangulated() -> Triangulation {
        guard faces.contains(where: { $0.count > 3 }) else {
            return Triangulation(triangles: faces, sourceFaces: Array(faces.indices))
        }

        var triangles: [Face] = []
        var sourceFaces: [Int] = []
        for (faceIndex, face) in faces.enumerated() {
            guard face.count > 3 else {
                triangles.append(face)
                sourceFaces.append(faceIndex)
                continue
            }
            let flat = Manifold3D.Polygon(vertices: face.map { vertices[$0] }.flattenCoplanar())
            for triangle in flat.triangulate(epsilon: 1e-6) {
                triangles.append([face[triangle.a], face[triangle.b], face[triangle.c]])
                sourceFaces.append(faceIndex)
            }
        }
        return Triangulation(triangles: triangles, sourceFaces: sourceFaces)
    }

    private struct Triangulation {
        let triangles: [Face]
        /// For each triangle, the index of the face it was cut from.
        let sourceFaces: [Int]

        var manifoldTriangles: [Manifold3D.Triangle] {
            triangles.map { Manifold3D.Triangle(.init($0[0]), .init($0[1]), .init($0[2])) }
        }
    }
}

internal extension MeshData {
    /// The materials of a mesh's faces: a palette of distinct materials, and for each face the index
    /// of its material in the palette, or `nil` for a face without one.
    struct FaceMaterials: Sendable, Hashable, Codable {
        let materials: [Material]
        let indices: [Int?]

        /// Creates face materials from one optional material per face, sharing a palette entry
        /// among the faces with equal materials.
        init(perFace: [Material?]) {
            var materials: [Material] = []
            var indexByMaterial: [Material: Int] = [:]
            indices = perFace.map { material in
                guard let material else { return nil }
                if let index = indexByMaterial[material] {
                    return index
                }
                materials.append(material)
                indexByMaterial[material] = materials.endIndex - 1
                return materials.endIndex - 1
            }
            self.materials = materials
        }
    }
}

internal extension MeshData {
    /// Builds the solid this mesh describes.
    ///
    /// A mesh without materials becomes a single original. With materials, the triangles of each
    /// material are given an original ID of their own, and the result maps those IDs to the
    /// materials, so the materials follow the faces through later operations the same way
    /// ``Geometry/colored(_:)`` ones do. Faces without a material share one more ID that maps to
    /// nothing.
    func evaluate() throws -> EvaluationResult<D3> {
        let triangulation = triangulated()
        do {
            guard let faceMaterials else {
                let manifold = try Manifold(MeshGL(vertices: vertices, triangles: triangulation.manifoldTriangles))
                return try EvaluationResult(manifold.asOriginal())
            }

            // Triangles are bucketed by material so that each material forms one run; the last
            // bucket holds the triangles without a material.
            let unmaterialedBucket = faceMaterials.materials.count
            var trianglesByBucket = Array(repeating: [Manifold3D.Triangle](), count: unmaterialedBucket + 1)
            for (triangleIndex, triangle) in triangulation.manifoldTriangles.enumerated() {
                let bucket = faceMaterials.indices[triangulation.sourceFaces[triangleIndex]] ?? unmaterialedBucket
                trianglesByBucket[bucket].append(triangle)
            }

            let usedBuckets = trianglesByBucket.indices.filter { !trianglesByBucket[$0].isEmpty }
            let firstID = Manifold.reserveOriginalIDs(usedBuckets.count)

            var triangles: [Manifold3D.Triangle] = []
            var originalIDs: [Manifold.OriginalID] = []
            var materialMapping: [Manifold.OriginalID: Material] = [:]
            triangles.reserveCapacity(triangulation.triangles.count)
            originalIDs.reserveCapacity(triangulation.triangles.count)

            for (offset, bucket) in usedBuckets.enumerated() {
                let originalID = firstID + offset
                triangles += trianglesByBucket[bucket]
                originalIDs += repeatElement(originalID, count: trianglesByBucket[bucket].count)
                if bucket < unmaterialedBucket {
                    materialMapping[originalID] = faceMaterials.materials[bucket]
                }
            }

            let manifold = try Manifold(MeshGL(vertices: vertices, triangles: triangles, originalIDs: originalIDs))
            return try EvaluationResult(concrete: manifold, materialMapping: materialMapping)
        } catch ManifoldError.notManifold {
            throw MeshNotManifoldError()
        }
    }
}

struct MeshNotManifoldError: LocalizedError {
    var errorDescription: String? {
"""
Mesh creation failed: The mesh is not manifold.

This means some edges or vertices are shared in a way that makes the shape ambiguous or invalid for solid geometry.
Common causes include:
- Holes or missing faces
- Edges shared by more than two faces
- Non-contiguous face loops
- Duplicate or misordered vertices

Ensure that your mesh defines a closed, watertight surface where every edge is shared by exactly two faces, and all
faces have consistent winding. Try visualizedForDebugging() to visualize the faces of a mesh without requiring it to
be manifold.
"""
    }
}

internal extension MeshData {
    // Calculates the signed volume of the mesh. A positive volume indicates that the faces are consistently
    // outward-facing. A negative volume indicates that the faces are inward-facing (inside out). This assumes the
    // mesh is closed and manifold.
    var signedVolume: Double {
        var volume = 0.0
        for face in faces {
            guard face.count >= 3 else { continue }
            let p0 = vertices[face[0]]
            for i in 1..<(face.count - 1) {
                let p1 = vertices[face[i]]
                let p2 = vertices[face[i + 1]]
                volume += p0 ⋅ (p1 × p2)
            }
        }
        return volume / 6.0
    }
}

internal extension [Vector3D] {
    // Flatten an array of coplanar 3D points into 2D. The output has the same ordering as the input.
    func flattenCoplanar() -> [Vector2D] {
        precondition(count >= 3)

        let v1 = (self[1] - self[0]).normalized
        let v2 = ((self[1] - self[0]) × (self[2] - self[0])).normalized × v1

        return map { Vector2D(
            ($0 - self[0]) ⋅ v1,
            ($0 - self[0]) ⋅ v2
        )}
    }
}
