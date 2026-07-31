import Foundation

public extension EdgeShape {
    /// A flat chamfer cutting the edge at the angle bisecting its two faces.
    ///
    /// - Parameter depth: The distance from the original edge to the chamfer, measured along
    ///   each face. For a square edge, this is the width of material removed from each face.
    ///
    static func chamfer(depth: Double) -> EdgeShape {
        precondition(depth > 0, "Chamfer depth must be positive")
        return EdgeShape(kind: .chamfer(depth: depth))
    }

    /// A flat chamfer with a fixed face width, regardless of the angle between the edge's faces.
    ///
    /// Unlike `chamfer(depth:)`, which measures along each face, this measures the width of the
    /// resulting flat face itself — the distance straight across the cut. At a given width, a
    /// sharper wedge angle produces a deeper cut (a larger setback along each face) than a
    /// shallower one, since the same width spans more material.
    ///
    /// - Parameter width: The width of the flat face left by the chamfer.
    ///
    static func chamfer(width: Double) -> EdgeShape {
        precondition(width > 0, "Chamfer width must be positive")
        return EdgeShape(kind: .chamferByWidth(width: width))
    }

    /// A rounded fillet, forming a circular arc tangent to both of the edge's faces.
    ///
    /// The arc has the given radius regardless of the angle between the faces.
    ///
    /// - Parameter radius: The radius of the arc.
    ///
    static func fillet(radius: Double) -> EdgeShape {
        precondition(radius > 0, "Fillet radius must be positive")
        return EdgeShape(kind: .fillet(radius: radius))
    }

    /// A rounded fillet specified by how far it reaches into the material, rather than by its
    /// arc radius.
    ///
    /// Unlike `fillet(radius:)`, whose curvature (and therefore how far the cut reaches) varies
    /// with the angle between the edge's faces, this keeps the reach constant and lets the arc's
    /// radius adjust instead. That makes it useful for a visually consistent cut across edges
    /// whose dihedral angle wanders slightly, at the cost of a curvature that's no longer fixed.
    ///
    /// The equivalent radius grows without bound as the wedge angle approaches flat (180°) and
    /// shrinks toward zero as it approaches a knife edge (0°) — the opposite extremes from
    /// `fillet(radius:)`, whose own reach behaves that way instead.
    ///
    /// - Parameter depth: The distance from the edge to the fillet's surface, measured along the
    ///   bisector of the two faces to the arc's deepest point. Unlike `chamfer(depth:)`, which
    ///   measures along each face, this measures straight to the surface.
    ///
    static func fillet(depth: Double) -> EdgeShape {
        precondition(depth > 0, "Fillet depth must be positive")
        return EdgeShape(kind: .filletByDepth(depth: depth))
    }

    /// A custom edge cross-section defined by a curve.
    ///
    /// The curve closure receives the wedge angle between the edge's faces and returns the
    /// points of the cross-section curve in the normalized frame described by
    /// ``EdgeShapeParameters``: from a point on one face (at angle +`wedgeAngle`/2 from the
    /// X axis) to the mirrored point on the other face (at −`wedgeAngle`/2), ordered from the
    /// positive-angle side to the negative-angle side. The first and last points must lie on
    /// the faces; they determine how far from the edge the shape reaches.
    ///
    /// Which of the edge's two faces corresponds to the positive side is unspecified, so the
    /// curve should be symmetric across the X axis. The closure must be deterministic and must
    /// return the same number of points for the same `segmentCount`.
    ///
    /// Because closures can't be compared or serialized, the `name` and `parameters` are used
    /// to identify the shape for caching. They must uniquely represent the curve: if the curve
    /// logic or its inputs change, the name or parameters must change too.
    ///
    /// - Parameters:
    ///   - name: A unique, stable name identifying the curve logic.
    ///   - parameters: Values that affect the generated curve.
    ///   - curve: Generates the cross-section curve points.
    ///
    static func custom(
        name: String,
        parameters: any CacheKey...,
        curve: @escaping @Sendable (EdgeShapeParameters) -> [Vector2D]
    ) -> EdgeShape {
        EdgeShape(
            kind: .custom(name: name, parameters: parameters.map { OpaqueKey($0) }),
            customCurve: curve
        )
    }
}
