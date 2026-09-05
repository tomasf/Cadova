import Foundation

public extension Geometry3D {
    /// Distorts the geometry by mapping its X/Y surface to a Bézier patch.
    ///
    /// This method warps the geometry’s surface to match a given Bézier patch. It works by
    /// measuring the geometry’s bounding box in the X/Y plane, then mapping each point to
    /// a normalized UV coordinate (from 0 to 1) and evaluating the patch at that location.
    /// The resulting patch point becomes the new X and Y, while the original Z value is
    /// added on top of the patch.
    ///
    /// This is useful for shaping flat geometry (like a box or extruded shape) to follow
    /// a curved surface.
    ///
    /// - Parameters:
    ///   - patch: A Bézier patch to apply. This defines the curved surface to map to.
    /// - Returns: A new 3D geometry, deformed to match the patch’s shape.
    ///
    /// ```swift
    /// Box([40, 40, 2])
    ///     .deformed(by: myPatch)
    /// ```
    ///
    /// In this example, a flat box is bent into the shape of `myPatch`,
    /// with its thickness stacked vertically on top of the patch’s surface.
    ///
    func deformed(by patch: BezierPatch) -> any Geometry3D {
        @Environment(\.scaledSegmentation) var segmentation
        return measuringBounds { geometry, bounds in
            let maxLength = max(bounds.size.x, bounds.size.y)

            // The X/Y footprint is what gets normalized into the patch's UV space. Geometry with no
            // extent along either of those axes has no footprint to map, and normalizing it would
            // divide by zero.
            if bounds.size.x > .ulpOfOne && bounds.size.y > .ulpOfOne {
                geometry
                    .refined(maxEdgeLength: maxLength / Double(segmentation.segmentCount(length: maxLength)))
                    .warped(operationName: "Cadova.DeformByPatch", cacheParameters: patch) { point in
                        let uv = Vector2D(
                            (point.x - bounds.minimum.x) / bounds.size.x,
                            (point.y - bounds.minimum.y) / bounds.size.y
                        )
                        return patch.point(at: uv) + .z(point.z)
                    }
                    .simplified()
            } else {
                let _ = logger.warning("""
                    Cannot deform geometry measuring \(bounds.size) by a patch; it has no extent in X or Y \
                    to map onto the patch. Leaving it unchanged.
                    """)
                geometry
            }
        }
    }
}
