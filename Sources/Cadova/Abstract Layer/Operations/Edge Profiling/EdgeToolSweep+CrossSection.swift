import Foundation

internal extension EdgeToolSweep {
    /// How far the cross-section extends past the body's faces, ensuring boolean operations
    /// cross the surfaces cleanly instead of leaving coplanar slivers.
    static let faceOvershoot = 1e-3

    /// Builds the closed 2D cross-section polygon for a segment, in counterclockwise order.
    ///
    /// The polygon consists of the shape's curve (running from face to face), endpoints
    /// extended slightly past the faces, and a closing edge behind the edge apex.
    ///
    /// Layout (relied upon by the ring envelope in `tool(for:...)`): indices 0–1 are the
    /// behind-apex corners, 2 is the extended endpoint of the negative-angle face, then the
    /// curve from its negative-angle end to its positive-angle end, and finally the extended
    /// endpoint of the positive-angle face. The curve's interior therefore spans indices
    /// 4 through `count - 3`.
    static func crossSection(
        shape: EdgeShape,
        wedgeAngle: Angle,
        isConvex: Bool,
        segmentCount: Int,
        apexDepth: Double
    ) -> [Vector2D] {
        let curve = shape.curvePoints(wedgeAngle: wedgeAngle, isConvex: isConvex, segmentCount: segmentCount)
        guard let first = curve.first, let last = curve.last else { return [] }

        let halfAngle = wedgeAngle / 2
        // Perpendicular to each face, pointing out of the wedge
        let firstExtended = first + Vector2D(-sin(halfAngle), cos(halfAngle)) * faceOvershoot
        let lastExtended = last + Vector2D(-sin(halfAngle), -cos(halfAngle)) * faceOvershoot

        let section = [firstExtended] + curve + [
            lastExtended,
            Vector2D(-apexDepth, lastExtended.y),
            Vector2D(-apexDepth, firstExtended.y),
        ]

        // The construction above runs clockwise; reverse for counterclockwise winding
        return section.reversed()
    }
}
