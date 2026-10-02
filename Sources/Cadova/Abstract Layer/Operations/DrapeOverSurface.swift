import Foundation

public extension Geometry3D {
    /// Lays the geometry onto a surface, bending it to follow the surface's shape.
    ///
    /// The geometry's X and Y are used directly as the surface's `u` and `v`: a point at `(x, y)` moves to the point
    /// on the surface at `(u, v) = (x, y)`, and its Z is added on top of the surface as height. Where you place the
    /// geometry in X and Y is where it ends up on the surface, so you position a design by moving it, and separate
    /// pieces draped over the same surface line up with each other.
    ///
    /// A surface's domain sets the scale. A ``BezierPatch`` spans `0...1` in both directions, so remap it to its size
    /// with ``ParametricSurface/remapped(u:v:)`` first:
    ///
    /// ```swift
    /// Text("Cadova")
    ///     .extruded(height: 1)
    ///     .translated(x: 10, y: 12)
    ///     .draped(over: patch.remapped(u: 0...60, v: 0...30))
    /// ```
    ///
    /// Geometry reaching past the domain carries on past the surface's edges, continuing along its tangent planes the
    /// way a sweep continues straight past the end of its path. A design can overhang a surface's edge a little this
    /// way, and keeps its shape there.
    ///
    /// For a design to keep its orientation, build the surface so that `u` runs along X: for a grid of points such as
    /// a ``BezierPatch``, where `u` runs across the rows, that means each row runs along Y. Otherwise the design comes
    /// out mirrored.
    ///
    /// - Parameter surface: The surface to lay the geometry onto.
    /// - Returns: The geometry, bent to follow the surface.
    ///
    func draped<Surface: ParametricSurface>(over surface: Surface) -> any Geometry3D {
        @Environment(\.segmentation) var segmentation
        return measuringBounds { geometry, bounds in
            let uDomain = surface.uDomain, vDomain = surface.vDomain
            let isMirrored = surface.isMirroredInXY

            // Refined as finely as the surface is tessellated, but never into more edges across the geometry than the
            // surface's grid has across its domain. Geometry much larger than the domain (usually a surface that
            // wasn't remapped to it) would otherwise be refined into millions of edges.
            let spread = max(1, uDomain.length > 0 ? bounds.size.x / uDomain.length : 1, vDomain.length > 0 ? bounds.size.y / vDomain.length : 1)
            let step = surface.tessellationStep(segmentation: segmentation) * spread

            // A surface whose u and v run as a left-handed pair in XY mirrors whatever is mapped onto it, and a
            // warp can't reverse the faces that a mirroring leaves inside out. So for such a surface, mirror the
            // geometry in Y first, which transforms handle correctly, and undo it in the mapping: every point lands
            // where it would anyway, but the two mirrorings cancel out and the solid stays valid.
            geometry
                .refined(maxEdgeLength: step)
                .flipped(along: isMirrored ? .y : [])
                .warped(operationName: "Cadova.DrapeOverSurface", cacheParameters: surface, isMirrored) { point in
                    let y = isMirrored ? -point.y : point.y
                    // Extended here, not left to the surface, which might be one of your own that only handles its
                    // domain.
                    return surface.point(at: Vector2D(point.x, y), extendingPast: surface.point(at:)) + .z(point.z)
                }
                .simplified()
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

    /// The finest spacing, in domain units, of the grid the surface is tessellated with. Draped geometry is refined
    /// to this, so it follows the surface as closely as the surface's own tessellation does.
    func tessellationStep(segmentation: Segmentation) -> Double {
        let grid = points(segmentation: segmentation)
        let uCells = Double(max(grid.count - 1, 1))
        let vCells = Double(max(grid[0].count - 1, 1))
        return min(uDomain.length / uCells, vDomain.length / vCells)
    }
}
