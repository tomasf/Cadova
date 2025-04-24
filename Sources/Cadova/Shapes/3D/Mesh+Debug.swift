import Foundation

public extension Mesh {
    /// Generates a 3D visualization of the mesh for debugging purposes.
    ///
    /// This method constructs thin extrusions for each face in the mesh, allowing you to
    /// inspect face orientation, layout, and normals without requiring the mesh to be manifold.
    /// Inward-facing polygons (with incorrect winding) are visually distinguished by being colored pink.
    ///
    /// > Important: This is a heavy operation intended primarily for visual inspection during development.
    /// It performs a full projection and extrusion of every face individually and is not optimized for performance.
    /// Use only with relatively simple meshes or subsets of geometry.
    ///
    /// - Returns: A composite geometry consisting of extruded versions of each face in the mesh.
    @GeometryBuilder3D
    func visualizedForDebugging() -> any Geometry3D {
        for face in meshData.faces {
            visualizeFace(face.map { meshData.vertices[$0] })
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
