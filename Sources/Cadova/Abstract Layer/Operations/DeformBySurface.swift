import Foundation

public extension Geometry3D {
    /// Distorts the geometry by mapping its X/Y footprint onto a surface.
    ///
    /// This method warps the geometry to follow a given surface, such as a ``BezierPatch``. It works by
    /// measuring the geometry’s bounding box in the X/Y plane, then mapping each point to
    /// a normalized UV coordinate (from 0 to 1) and evaluating the surface at that location.
    /// The resulting surface point becomes the new position, with the original Z value
    /// added on top of it.
    ///
    /// This is useful for shaping flat geometry (like a box or extruded shape) to follow
    /// a curved surface.
    ///
    /// - Parameters:
    ///   - surface: The surface to map the geometry onto.
    /// - Returns: A new 3D geometry, deformed to match the surface’s shape.
    ///
    /// ```swift
    /// Box([40, 40, 2])
    ///     .deformed(by: myPatch)
    /// ```
    ///
    /// In this example, a flat box is bent into the shape of `myPatch`,
    /// with its thickness stacked vertically on top of the surface.
    ///
    func deformed<Surface: ParametricSurface>(by surface: Surface) -> any Geometry3D {
        @Environment(\.segmentation) var segmentation
        return measuringBounds { geometry, bounds in
            let maxLength = max(bounds.size.x, bounds.size.y)

            // The X/Y footprint is what gets normalized into the surface's UV space. Geometry with no
            // extent along either of those axes has no footprint to map, and normalizing it would
            // divide by zero.
            if bounds.size.x > .ulpOfOne && bounds.size.y > .ulpOfOne {
                geometry
                    .refined(maxEdgeLength: maxLength / Double(segmentation.segmentCount(length: maxLength)))
                    .warped(operationName: "Cadova.DeformBySurface", cacheParameters: surface) { point in
                        let uv = Vector2D(
                            (point.x - bounds.minimum.x) / bounds.size.x,
                            (point.y - bounds.minimum.y) / bounds.size.y
                        )
                        return surface.point(at: uv) + .z(point.z)
                    }
                    .simplified()
            } else {
                logger.warning("""
                    Cannot deform geometry measuring \(bounds.size) by a surface; it has no extent in X or Y \
                    to map onto the surface. Leaving it unchanged.
                    """)
                geometry
            }
        }
    }
}
