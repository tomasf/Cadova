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
    /// X maps to the surface's `u` and Y to its `v`. For a design to keep its orientation, build the surface so that
    /// `u` runs along X: for a grid of points such as a ``BezierPatch``, where `u` runs across the rows, that means
    /// each row runs along Y. Otherwise the design comes out mirrored.
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
                // A surface whose u and v run as a left-handed pair in XY mirrors whatever is mapped onto it, and a
                // warp can't reverse the faces that a mirroring leaves inside out. So for such a surface, mirror
                // the geometry in Y first, which transforms handle correctly, and undo it in the mapping: every
                // point lands where it would anyway, but the two mirrorings cancel out and the solid stays valid.
                let isMirrored = surface.isMirroredInXY
                geometry
                    .refined(maxEdgeLength: maxLength / Double(segmentation.segmentCount(length: maxLength)))
                    .flipped(along: isMirrored ? .y : [])
                    .warped(operationName: "Cadova.DeformBySurface", cacheParameters: surface, isMirrored) { point in
                        let y = isMirrored ? -point.y : point.y
                        let uv = Vector2D(
                            (point.x - bounds.minimum.x) / bounds.size.x,
                            (y - bounds.minimum.y) / bounds.size.y
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

internal extension ParametricSurface {
    /// Whether the surface's u and v directions form a left-handed pair when seen from above, so that mapping
    /// X to u and Y to v mirrors the geometry. Decided by the signed area of the surface projected onto XY, summed
    /// over a coarse grid, so a surface that folds over itself goes by whichever orientation covers more of it.
    var isMirroredInXY: Bool {
        let grid = points(segmentation: .fixed(16))
        var signedArea = 0.0
        for u in grid.indices.dropLast() {
            for v in grid[u].indices.dropLast() {
                let alongU = grid[u + 1][v] - grid[u][v]
                let alongV = grid[u][v + 1] - grid[u][v]
                signedArea += alongU.x * alongV.y - alongU.y * alongV.x
            }
        }
        return signedArea < 0
    }
}
