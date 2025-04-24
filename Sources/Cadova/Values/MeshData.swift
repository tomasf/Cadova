import Foundation
import Manifold3D

public struct MeshData: Sendable, Hashable, Codable {
    internal let vertices: [Vector3D]
    internal let faces: [Face]

    internal typealias Face = [[Vector3D].Index]

    internal init(vertices: [Vector3D], faces: [Face]) {
        self.vertices = vertices
        self.faces = faces
    }

    internal func meshGL() -> MeshGL {
        let triangles = triangulatedFaces().map { indices in
            Triangle(.init(indices[0]), .init(indices[1]), .init(indices[2]))
        }
        return MeshGL(vertices: vertices, triangles: triangles)
    }

    private func triangulatedFaces() -> [Face] {
        return faces.flatMap { face in
            guard face.count > 3 else { return [face] }
            let flat = Manifold3D.Polygon(vertices: face.map { vertices[$0] }.flattenCoplanar())
            return triangulate(polygons: [flat], epsilon: 1e-6).map {
                [face[$0.a], face[$0.b], face[$0.c]]
            }
        }
    }
}

internal extension MeshData {
    // Calculates the signed volume of the mesh. A positive volume indicates that the faces are consistently outward-facing. A negative volume indicates that the faces are inward-facing (inside out). This assumes the mesh is closed and manifold.
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

    func flipped() -> Self {
        MeshData(vertices: vertices, faces: faces.map { $0.reversed() })
    }
}

internal extension [Vector3D] {
    // Flatten an array of coplanar 3D points into 2D. The output has the same ordering as the input.
    func flattenCoplanar() -> [Vector2D] {
        assert(count >= 3)

        let firstToSecond = self[1] - self[0]
        let firstToThird = self[2] - self[0]
        let planeNormal = (firstToSecond × firstToThird).normalized
        let v1 = firstToSecond.normalized
        let v2 = planeNormal × v1

        return map { Vector2D(($0 - self[0]) ⋅ v1, ($0 - self[0]) ⋅ v2) }
    }
}
