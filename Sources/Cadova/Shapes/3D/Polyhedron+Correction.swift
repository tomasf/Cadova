import Foundation

internal extension Mesh {
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

    func flipped() -> Mesh {
        Mesh(vertices: vertices, faces: faces.map { $0.reversed() })
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
        signedVolume < 0 ? flipped() : self
    }
}
