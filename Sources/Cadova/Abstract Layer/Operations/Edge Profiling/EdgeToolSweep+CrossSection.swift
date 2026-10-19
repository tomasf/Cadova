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

        let behindApex: [Vector2D]
        if isConvex {
            // Behind a convex edge is empty space, so the section can close well clear of it
            behindApex = [Vector2D(-apexDepth, lastExtended.y), Vector2D(-apexDepth, firstExtended.y)]
        } else {
            // Behind a concave edge is the body itself, which can be thinner than the shape is
            // deep, so the section stays as close behind the faces as its endpoints do. Lines
            // offset from both faces by that much meet at this point on the bisector; the two
            // corners straddle it, each still behind both faces.
            let offsetApex = Vector2D(-faceOvershoot / sin(halfAngle), 0)
            let spread = Vector2D(0, faceOvershoot / 2)
            behindApex = [offsetApex - spread, offsetApex + spread]
        }

        let section = [firstExtended] + curve + [lastExtended] + behindApex

        // The construction above runs clockwise; reverse for counterclockwise winding
        return section.reversed()
    }
}
