import Foundation

internal extension EdgeToolSweep {
    /// The cross-section frame of one segment: right-handed with Z along the segment,
    /// X pointing into the wedge being modified. Cross-sections are constant along a segment.
    struct SegmentBasis {
        let xAxis: Vector3D
        let yAxis: Vector3D
        let wedgeAngle: Angle
    }

    /// The most a miter projection is allowed to stretch a cross-section, limiting extreme joints.
    private static let maxMiterStretch = 4.0

    /// The in-plane directions pointing away from the edge along each of the segment's faces.
    static func faceRays(of segment: EdgeSegment) -> (left: Vector3D, right: Vector3D) {
        let direction = segment.direction.unitVector
        return (
            left: segment.leftFaceNormal.unitVector × direction,
            right: direction × segment.rightFaceNormal.unitVector
        )
    }

    static func basis(for segment: EdgeSegment) -> SegmentBasis? {
        let rays = faceRays(of: segment)
        let bisector = rays.left + rays.right
        guard bisector.magnitude > 1e-9 else { return nil }

        let xAxis = bisector.normalized
        let yAxis = segment.direction.unitVector × xAxis
        return SegmentBasis(xAxis: xAxis, yAxis: yAxis, wedgeAngle: segment.wedgeAngle)
    }

    /// Places a segment's 2D cross-section at a joint vertex and projects it along the segment
    /// direction onto the joint's miter plane.
    static func projectedSection(
        section: [Vector2D],
        basis: SegmentBasis,
        direction: Vector3D,
        vertex: Vector3D,
        miterNormal: Vector3D
    ) -> [Vector3D] {
        let alignment = direction ⋅ miterNormal
        // Limit the stretch at extreme turns to keep the mesh sane
        let slope = abs(alignment) > 1 / maxMiterStretch ? 1 / alignment : 0

        return section.map { local in
            let point = vertex + basis.xAxis * local.x + basis.yAxis * local.y
            return point - direction * (((point - vertex) ⋅ miterNormal) * slope)
        }
    }
}
