import Foundation

internal extension Polyhedron {
    // Calculates the signed volume of the polyhedron. A positive volume indicates that the faces are consistently outward-facing. A negative volume indicates that the faces are inward-facing (inside out). This assumes the polyhedron is closed and manifold.
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

    func flipped() -> Polyhedron {
        Polyhedron(vertices: vertices, faces: faces.map { $0.reversed() })
    }
}

public extension Polyhedron {
    /// Returns a new polyhedron with corrected face winding based on volume orientation.
    ///
    /// If the polyhedron's signed volume is negative (indicating inward-facing normals),
    /// the face windings are flipped to ensure outward orientation.
    ///
    /// - Returns: A polyhedron with outward-facing normals.
    func correctingFaceWinding() -> Polyhedron {
        signedVolume < 0 ? flipped() : self
    }
}
