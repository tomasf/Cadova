import Foundation

public extension Geometry3D {
    /// Wraps the current geometry around the Z axis, effectively creating
    /// a cylindrical shape from the original geometry.
    ///
    /// - Important:
    ///   - The X axis of the original geometry is wrapped around the Z axis
    ///     counter-clockwise (right-hand rule) around the cylinder’s
    ///     circumference. This axis effectively corresponds to the angular
    ///     coordinate in a polar coordinate system.
    ///   - The Y axis becomes the new Z height.
    ///   - The Z axis of the geometry becomes the thickness around the wrapped
    ///     cylinder, effectively corresponding to the radial coordinate in a
    ///     polar coordinate system.
    ///   - Wrapping starts at the origin, which becomes 0°, inner radius, Z = 0
    ///
    /// - Parameters:
    ///   - diameter: The inner cylinder’s diameter. If omitted, the diameter is
    ///     automatically inferred from the geometry’s bounding box by using the
    ///     maximum X extent as one full turn of the circle.
    ///
    func wrappedAroundCylinder(diameter: Double? = nil) -> any Geometry3D {
        measureBoundsIfNonEmpty { geometry, e, bounds in
            let innerRadius = (diameter ?? bounds.maximum.x / .pi) / 2
            let maximumRadius = innerRadius + bounds.maximum.z
            let segmentLength = (maximumRadius * 2 * .pi) / Double(e.segmentation.segmentCount(circleRadius: maximumRadius))
            let innerCircumference = innerRadius * 2 * .pi

            geometry
                .refined(maxEdgeLength: segmentLength)
                .warped(operationName: "wrapAroundCylinder", cacheParameters: innerCircumference, innerRadius) {
                    let angle = 360° * $0.x / innerCircumference
                    let radius = innerRadius + $0.z
                    return Vector3D(cos(angle) * radius, sin(angle) * radius, $0.y)
                }
        }
    }
}

public extension Geometry2D {
    /// Wraps the current geometry around the origin, effectively creating
    /// a circular shape from the original geometry.
    ///
    /// - Important:
    ///   - The X axis of the original geometry is wrapped around the origin
    ///     clockwise around the circle’s circumference. This axis effectively
    ///     corresponds to the angular coordinate in a polar coordinate system.
    ///   - The Y axis of the geometry becomes the thickness around the wrapped
    ///     circle, effectively corresponding to the radial coordinate in a
    ///     polar coordinate system.
    ///   - Wrapping starts at the origin, which becomes 0°, inner radius
    ///
    /// - Parameters:
    ///   - diameter: The inner circle's diameter. If omitted, the diameter is
    ///     automatically inferred from the geometry’s bounding box by using the
    ///     maximum X extent as one full turn of the circle.
    ///
    func wrappedAroundCircle(diameter: Double? = nil) -> any Geometry2D {
        measureBoundsIfNonEmpty { geometry, e, bounds in
            let innerRadius = (diameter ?? bounds.maximum.x / .pi) / 2
            let maximumRadius = innerRadius + bounds.maximum.y
            let segmentLength = (maximumRadius * 2 * .pi) / Double(e.segmentation.segmentCount(circleRadius: maximumRadius))
            let innerCircumference = innerRadius * 2 * .pi

            geometry
                .refined(maxSegmentLength: segmentLength)
                .warped(operationName: "wrapAroundCircle", cacheParameters: diameter) {
                    let angle = -360° * $0.x / innerCircumference
                    let radius = innerRadius + $0.y
                    return Vector2D(cos(angle) * radius, sin(angle) * radius)
                }
        }
    }
}
