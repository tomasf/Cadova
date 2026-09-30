import Foundation

public extension Geometry2D {
    /// Applies rounding to the geometry's corners with separate control over inside and outside radii.
    ///
    /// This method modifies the geometry to round its corners, with the extent of rounding determined by the
    /// `insideRadius` and `outsideRadius` parameters. Positive values specify the radius of the rounding effect. If
    /// only one of the parameters is specified, rounding will be applied only on that side.
    ///
    /// - Parameters:
    ///   - insideRadius: The radius of rounding applied to interior corners of the geometry.
    ///   - outsideRadius: The radius of rounding applied to exterior corners of the geometry.
    /// - Returns: A new geometry object with rounded corners.
    ///
    func rounded(insideRadius: Double? = nil, outsideRadius: Double? = nil) -> any Geometry2D {
        var body: any Geometry2D = self
        if let outsideRadius {
            body = body
                .offset(amount: -outsideRadius, style: .miter)
                .offset(amount: outsideRadius, style: .round)
        }
        if let insideRadius {
            body = body
                .offset(amount: insideRadius, style: .miter)
                .offset(amount: -insideRadius, style: .round)
        }
        return body
    }

    /// Applies uniform rounding to both inside and outside corners of the geometry.
    ///
    /// This is a convenience method that applies the same rounding radius to both the inside and outside edges of the
    /// geometry. Equivalent to calling `rounded(insideRadius:radius, outsideRadius:radius)`.
    ///
    /// - Parameter radius: The radius to apply to both inside and outside edges.
    /// - Returns: A new geometry object with uniformly rounded corners.
    ///
    func rounded(radius: Double) -> any Geometry2D {
        rounded(insideRadius: radius, outsideRadius: radius)
    }

    /// Applies chamfering to the geometry's corners with separate control over inside and outside sizes.
    ///
    /// This method modifies the geometry to chamfer (cut at 45°) its corners, with the extent of chamfering determined by the
    /// `insideDepth` and `outsideDepth` parameters. Positive values specify the size of the chamfer. If
    /// only one of the parameters is specified, chamfering will be applied only on that side.
    ///
    /// - Parameters:
    ///   - insideDepth: The depth of chamfering applied to interior corners of the geometry.
    ///   - outsideDepth: The depth of chamfering applied to exterior corners of the geometry.
    /// - Returns: A new geometry object with chamfered corners.
    ///
    func chamfered(insideDepth: Double? = nil, outsideDepth: Double? = nil) -> any Geometry2D {
        var body: any Geometry2D = self
        if let outsideDepth {
            body = body
                .offset(amount: -outsideDepth, style: .miter)
                .offset(amount: outsideDepth, style: .square)
        }
        if let insideDepth {
            body = body
                .offset(amount: insideDepth, style: .miter)
                .offset(amount: -insideDepth, style: .square)
        }
        return body
    }

    /// Applies uniform chamfering to both inside and outside corners of the geometry.
    ///
    /// This is a convenience method that applies the same chamfer depth to both the inside and outside edges of the
    /// geometry. Equivalent to calling `chamfered(insideDepth:depth, outsideDepth:depth)`.
    ///
    /// - Parameter depth: The chamfer depth to apply to both inside and outside edges.
    /// - Returns: A new geometry object with uniformly chamfered corners.
    ///
    func chamfered(depth: Double) -> any Geometry2D {
        chamfered(insideDepth: depth, outsideDepth: depth)
    }
}

public extension Geometry3D {
    /// Rounds the geometry's edges and corners with separate control over inside and outside radii.
    ///
    /// Outside rounding rounds every convex edge and corner with the given radius, like a ball rolled around the
    /// outside, and removes parts thinner than twice the radius. Inside rounding fillets every concave edge and
    /// corner, like a ball rolled around the inside, and fills gaps narrower than twice the radius. If only one of
    /// the parameters is specified, rounding is applied only on that side. Flat faces and the remaining sharp edges
    /// stay exact.
    ///
    /// Each side takes two offsets (see ``offset(amount:style:)``), so this is slower than most operations on large
    /// models. Rounded parts follow the environment's segmentation, and edges sharper than the environment's miter
    /// limit are squared off before rounding. To round only chosen edges, use edge shaping instead.
    ///
    /// - Parameters:
    ///   - insideRadius: The radius of rounding applied to concave edges and corners.
    ///   - outsideRadius: The radius of rounding applied to convex edges and corners.
    /// - Returns: A new geometry with rounded edges and corners.
    ///
    func rounded(insideRadius: Double? = nil, outsideRadius: Double? = nil) -> any Geometry3D {
        if let insideRadius, let outsideRadius, insideRadius > 0, outsideRadius > 0 {
            return RoundedOnBothSides(source: self, outside: outsideRadius, inside: insideRadius)
        }
        var body: any Geometry3D = self
        if let outsideRadius {
            body = body
                .offset(amount: -outsideRadius, style: .miter)
                .offset(amount: outsideRadius, style: .round)
        }
        if let insideRadius {
            body = body
                .offset(amount: insideRadius, style: .miter)
                .offset(amount: -insideRadius, style: .round)
        }
        return body
    }

    /// Rounds both concave and convex edges and corners of the geometry with the same radius.
    ///
    /// Equivalent to calling `rounded(insideRadius: radius, outsideRadius: radius)`.
    ///
    /// - Parameter radius: The radius to apply to both inside and outside edges and corners.
    /// - Returns: A new geometry with rounded edges and corners.
    ///
    func rounded(radius: Double) -> any Geometry3D {
        rounded(insideRadius: radius, outsideRadius: radius)
    }

    /// Chamfers the geometry's edges and corners with separate control over inside and outside sizes.
    ///
    /// Like ``rounded(insideRadius:outsideRadius:)``, but edges and corners are cut flat instead of rounded, with the
    /// cuts shaped by the square join style of ``offset(amount:style:)``. Outside chamfering applies to convex edges
    /// and corners, inside chamfering to concave ones. If only one of the parameters is specified, chamfering is
    /// applied only on that side.
    ///
    /// - Parameters:
    ///   - insideDepth: The depth of chamfering applied to concave edges and corners.
    ///   - outsideDepth: The depth of chamfering applied to convex edges and corners.
    /// - Returns: A new geometry with chamfered edges and corners.
    ///
    func chamfered(insideDepth: Double? = nil, outsideDepth: Double? = nil) -> any Geometry3D {
        var body: any Geometry3D = self
        if let outsideDepth {
            body = body
                .offset(amount: -outsideDepth, style: .miter)
                .offset(amount: outsideDepth, style: .square)
        }
        if let insideDepth {
            body = body
                .offset(amount: insideDepth, style: .miter)
                .offset(amount: -insideDepth, style: .square)
        }
        return body
    }

    /// Chamfers both concave and convex edges and corners of the geometry with the same depth.
    ///
    /// Equivalent to calling `chamfered(insideDepth: depth, outsideDepth: depth)`.
    ///
    /// - Parameter depth: The chamfer depth to apply to both inside and outside edges and corners.
    /// - Returns: A new geometry with chamfered edges and corners.
    ///
    func chamfered(depth: Double) -> any Geometry3D {
        chamfered(insideDepth: depth, outsideDepth: depth)
    }
}

/// Rounds both sides in one contouring: rounding the outside and then the inside with two offsets each would
/// contour the outside's fillets again, and contouring a surface at the resolution it was contoured at coarsens it
private struct RoundedOnBothSides: Geometry3D {
    let source: any Geometry3D
    let outside: Double
    let inside: Double

    var body: any Geometry3D {
        @Environment(\.segmentation) var segmentation
        @Environment(\.miterLimit) var miterLimit
        let cellSize = segmentation.offsetCellSize(radius: min(outside, inside))
        let tolerance = cellSize / 10
        CachedConcreteTransformer(body: source, name: "Cadova.RoundedOnBothSides", parameters: outside, inside, segmentation, miterLimit) { manifold in
            guard let sourceField = MeshOffset.distanceField(for: manifold) else { return manifold }
            // The source eroded with sharp joins, exact where the source is flat, straight from the contour
            let erodedMesh = MeshOffset(field: sourceField, amount: -outside, style: .miter, miterLimit: miterLimit, cellSize: cellSize, tolerance: tolerance).run()
            // Eroded away entirely: rounding the outside leaves nothing to round the inside of
            guard !erodedMesh.faces.isEmpty else { return .empty }
            let erodedField = MeshDistanceField(vertices: erodedMesh.vertices, faces: erodedMesh.faces)
            // Grown by both radii: the outside rounding grown for the inside rounding, straight from the contour. Its
            // curved parts are contoured at half the cell size, which leaves them off by about a quarter as much, so
            // the margin keeping its term from winning there can be small
            let dilatedCell = cellSize / 2
            let dilated = MeshOffset(field: erodedField, amount: outside + inside, cellSize: dilatedCell, tolerance: dilatedCell / 10, segmentation: segmentation).run()
            guard !dilated.faces.isEmpty else { return .empty }
            let dilatedField = MeshDistanceField(vertices: dilated.vertices, faces: dilated.faces)
            // Contouring a surface of radius R with cells of size h leaves it off by up to about h² / 8R, and measured,
            // by up to about twice that: the margin is twice that again
            let margin = dilatedCell * dilatedCell / (2 * (outside + inside))
            let rounding = RoundingField(eroded: erodedField, dilated: dilatedField, outside: outside, inside: inside, margin: margin)
            return try MeshOffset.manifold(from: MeshOffset(rounding: rounding, dilated: dilatedField, cellSize: cellSize, tolerance: tolerance, segmentation: segmentation).run())
        }
        .simplified(maximumThreshold: MeshOffset.simplificationThreshold(forTolerance: tolerance))
    }
}
