import Foundation

public extension Mesh {
    /// Generates a 3D visualization of the mesh for debugging.
    ///
    /// - Each face is projected and extruded as a thin slab so you can inspect orientation and layout.
    /// - Inward-facing polygons (wrong winding) are highlighted using the visualization primary color
    ///   (set with `withVisualizationColor(_:)`, default: pink).
    /// - Slab thickness scales with the visualization scale in the environment
    ///   (set with `withVisualizationScale(_:)`, default: 1.0).
    ///
    /// See EnvironmentValues for how environment values flow through geometry.
    ///
    /// > Important: This is a heavy operation intended for visual inspection only.
    /// It performs a full projection and extrusion of each face and is not optimized for performance.
    ///
    /// - Returns: A composite geometry consisting of extruded versions of each face in the mesh.
    func visualizedForDebugging() -> any Geometry3D {
        MeshVisualization(meshData: meshData)
    }
}

fileprivate struct MeshVisualization: Shape3D {
    let meshData: MeshData

    var body: any Geometry3D {
        for face in meshData.faces {
            let vertices = face.map { meshData.vertices[$0] }
            if vertices.count == 3 {
                Face(vertices: (vertices[0], vertices[1], vertices[2]))
            }
        }
    }

    struct Face: Shape3D {
        let vertices: (Vector3D, Vector3D, Vector3D)

        @Environment(\.visualizationOptions) var options

        var body: any Geometry3D {
            let scale = options[.scale] as? Double ?? 1.0
            let backColor = options[.primaryColor] as? Color ?? .pink

            let thickness = 0.005 * scale
            let (v0, v1, v2) = vertices
            let normal = ((v1 - v0) × (v2 - v0)).normalized

            let u = (v1 - v0).normalized
            let v = (normal × u).normalized
            let projected2D = [v0, v1, v2].map {
                Vector2D(x: ($0 - v0) ⋅ u, y: ($0 - v0) ⋅ v)
            }

            let surface = Polygon(projected2D).extruded(height: thickness)

            let extruded = surface
                .colored(backColor)
                .adding {
                    surface.translated(z: thickness)
                }

            let rotation = Transform3D([
                [u.x, v.x, normal.x, 0],
                [u.y, v.y, normal.y, 0],
                [u.z, v.z, normal.z, 0],
                [0, 0, 0, 1]
            ])
            extruded.transformed(rotation.translated(v0))
        }
    }
}
