import Foundation

public extension Polyhedron {
    /// Returns a visual debugging version of the polyhedron
    /// built from thin extruded faces without requiring manifold correctness.
    /// Inward faces are colored pink.
    @GeometryBuilder3D
    func debugVisualization() -> any Geometry3D {
        for face in faces {
            visualizeFace(face.map { vertices[$0] })
        }
    }

    private func visualizeFace(_ faceVertices: [Vector3D]) -> any Geometry3D {
        let thickness = 0.005
        guard faceVertices.count >= 3 else { return Empty() }
        let v0 = faceVertices[0]
        let v1 = faceVertices[1]
        let v2 = faceVertices[2]
        let normal = ((v1 - v0) × (v2 - v0)).normalized

        let u = (v1 - v0).normalized
        let v = (normal × u).normalized
        let projected2D = faceVertices.map {
            Vector2D(x: ($0 - v0) ⋅ u, y: ($0 - v0) ⋅ v)
        }

        let polygon = Polygon(projected2D)
        let extruded = polygon.extruded(height: thickness)
            .colored(.lightPink)
            .adding {
                polygon.extruded(height: thickness)
                    .translated(z: thickness)
            }

        let rotation = AffineTransform3D([
            [u.x, v.x, normal.x, 0],
            [u.y, v.y, normal.y, 0],
            [u.z, v.z, normal.z, 0],
            [0, 0, 0, 1]
        ])
        return extruded.transformed(rotation.translated(v0))
    }
}
