import Foundation

/// Cross-section curve generation.
///
/// Curves are expressed in the normalized frame described by `EdgeShapeParameters`:
/// origin on the edge, +X into the wedge being modified, faces at ±wedgeAngle/2 from X.
///
internal extension EdgeShape {
    // Segment count used when probing a custom curve to measure its extent
    private static let probeSegmentCount = 8

    /// The distance from the edge to where the shape meets the faces, measured along each face.
    func tangentSetback(wedgeAngle: Angle) -> Double {
        let wedgeAngle = wedgeAngle.clamped()
        switch kind {
        case .chamfer (let depth):
            return depth
        case .chamferByWidth (let width):
            return Self.chamferDepth(forWidth: width, wedgeAngle: wedgeAngle)
        case .fillet, .filletByDepth:
            return (filletRadius(wedgeAngle: wedgeAngle) ?? 0) / tan(wedgeAngle / 2)
        case .custom:
            return curvePoints(
                wedgeAngle: wedgeAngle, isConvex: true, segmentCount: Self.probeSegmentCount
            ).first?.magnitude ?? 0
        }
    }

    /// The chamfer depth (setback along each face) that produces a flat face of the given width
    /// at the given wedge angle: the two curve endpoints are `2·depth·sin(wedgeAngle/2)` apart.
    private static func chamferDepth(forWidth width: Double, wedgeAngle: Angle) -> Double {
        width / (2 * sin(wedgeAngle / 2))
    }

    /// The fillet radius at the given wedge angle, if this shape is a fillet — fixed-radius or
    /// depth-based. Used to continue fillet surfaces exactly through a corner with a sphere; for
    /// a depth-based fillet, the edges meeting at that corner must share (approximately) the same
    /// wedge angle for the sphere to be exact, since the equivalent radius is angle-dependent.
    /// `CornerPatch` falls back to a hull-only corner when that doesn't hold.
    func filletRadius(wedgeAngle: Angle) -> Double? {
        switch kind {
        case .fillet (let radius):
            radius
        case .filletByDepth (let depth):
            Self.filletRadius(forDepth: depth, wedgeAngle: wedgeAngle.clamped())
        case .chamfer, .chamferByWidth, .custom:
            nil
        }
    }

    /// The radius of the arc that reaches the given depth (measured along the bisector, from the
    /// edge to the arc's deepest point) at the given wedge angle.
    private static func filletRadius(forDepth depth: Double, wedgeAngle: Angle) -> Double {
        let halfAngle = wedgeAngle / 2
        return depth * sin(halfAngle) / (1 - sin(halfAngle))
    }

    /// The distance from each face plane at which a corner center should sit for chains of
    /// this shape meeting at a corner: the point where the shaped surfaces from the individual
    /// edges blend. For fillets, this is the arc center's distance from the faces, so that a
    /// sphere placed at the corner center continues the fillet cylinders. For flat shapes,
    /// it's the depth of the cross-section's midpoint, producing a flat corner facet.
    func cornerPlaneOffset(wedgeAngle: Angle) -> Double {
        let wedgeAngle = wedgeAngle.clamped()
        switch kind {
        case .chamfer, .chamferByWidth, .custom:
            return tangentSetback(wedgeAngle: wedgeAngle) * sin(wedgeAngle) / 2
        case .fillet, .filletByDepth:
            return filletRadius(wedgeAngle: wedgeAngle) ?? 0
        }
    }

    /// The number of curve segments this shape prefers at the given wedge angle.
    func preferredSegmentCount(wedgeAngle: Angle, segmentation: Segmentation) -> Int {
        let wedgeAngle = wedgeAngle.clamped()
        switch kind {
        case .chamfer, .chamferByWidth:
            return 1
        case .fillet, .filletByDepth:
            let radius = filletRadius(wedgeAngle: wedgeAngle) ?? 0
            return segmentation.segmentCount(arcRadius: radius, angle: 180° - wedgeAngle)
        case .custom:
            return segmentation.segmentCount(
                arcRadius: tangentSetback(wedgeAngle: wedgeAngle),
                angle: 180° - wedgeAngle
            )
        }
    }

    /// The cross-section curve, from a point on the positive-angle face to the mirrored point
    /// on the negative-angle face.
    ///
    /// For the same shape and segment count, the returned point count is always the same,
    /// allowing curves at different wedge angles to be stitched into one swept mesh.
    ///
    func curvePoints(wedgeAngle: Angle, isConvex: Bool, segmentCount: Int) -> [Vector2D] {
        let wedgeAngle = wedgeAngle.clamped()
        let halfAngle = wedgeAngle / 2

        switch kind {
        case .chamfer, .chamferByWidth:
            let depth = tangentSetback(wedgeAngle: wedgeAngle)
            return [
                depth * Vector2D(cos(halfAngle), sin(halfAngle)),
                depth * Vector2D(cos(halfAngle), -sin(halfAngle)),
            ]

        case .fillet, .filletByDepth:
            let radius = filletRadius(wedgeAngle: wedgeAngle) ?? 0
            // Arc center on the X axis, at the distance where the circle is tangent to both faces
            let center = Vector2D(radius / sin(halfAngle), 0)
            let startAngle = 90° + halfAngle
            let sweep = 180° - wedgeAngle
            return (0...segmentCount).map { index in
                let angle = startAngle + sweep * (Double(index) / Double(segmentCount))
                return center + radius * Vector2D(cos(angle), sin(angle))
            }

        case .custom:
            guard let customCurve else {
                preconditionFailure("A decoded custom EdgeShape has no curve and cannot generate geometry")
            }
            return customCurve(EdgeShapeParameters(
                wedgeAngle: wedgeAngle, isConvex: isConvex, segmentCount: segmentCount
            ))
        }
    }
}

private extension Angle {
    func clamped() -> Angle {
        Angle(degrees: degrees.clamped(to: 1.0...179.0))
    }
}
