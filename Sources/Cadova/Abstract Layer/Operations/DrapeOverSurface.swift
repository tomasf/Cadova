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
    /// Geometry outside the domain is clamped to the surface's edge, and a warning is logged.
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

            let tolerance = 1e-9 * max(1, uDomain.length, vDomain.length)
            if bounds.minimum.x < uDomain.lowerBound - tolerance || bounds.maximum.x > uDomain.upperBound + tolerance
                || bounds.minimum.y < vDomain.lowerBound - tolerance || bounds.maximum.y > vDomain.upperBound + tolerance {
                logger.warning("""
                    Draping geometry spanning X \(bounds.minimum.x)...\(bounds.maximum.x), Y \(bounds.minimum.y)...\
                    \(bounds.maximum.y) over a surface with domain u \(uDomain), v \(vDomain). The parts outside the \
                    domain are clamped to the surface's edge. Use remapped(u:v:) to give the surface a domain that \
                    covers the geometry.
                    """)
            }

            // A surface whose u and v run as a left-handed pair in XY mirrors whatever is mapped onto it, and a
            // warp can't reverse the faces that a mirroring leaves inside out. So for such a surface, mirror the
            // geometry in Y first, which transforms handle correctly, and undo it in the mapping: every point lands
            // where it would anyway, but the two mirrorings cancel out and the solid stays valid.
            geometry
                .refined(maxEdgeLength: surface.tessellationStep(segmentation: segmentation))
                .flipped(along: isMirrored ? .y : [])
                .warped(operationName: "Cadova.DrapeOverSurface", cacheParameters: surface, isMirrored) { point in
                    let y = isMirrored ? -point.y : point.y
                    let uv = Vector2D(point.x.clamped(to: uDomain), y.clamped(to: vDomain))
                    return surface.point(at: uv) + .z(point.z)
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
