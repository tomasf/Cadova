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
        measuringBounds { geometry, bounds in
            @Environment(\.scaledSegmentation) var segmentation
            let innerRadius = (diameter ?? bounds.maximum.x / .pi) / 2
            let maximumRadius = innerRadius + bounds.maximum.z
            let segmentLength = (maximumRadius * 2 * .pi) / Double(segmentation.segmentCount(circleRadius: maximumRadius))
            let innerCircumference = innerRadius * 2 * .pi

            geometry
                .refined(maxEdgeLength: segmentLength)
                .warped(operationName: "wrapAroundCylinder", cacheParameters: innerCircumference, innerRadius) {
                    let angle = 360° * $0.x / innerCircumference
                    let radius = innerRadius + $0.z
                    return Vector3D(cos(angle) * radius, sin(angle) * radius, $0.y)
                }
                .simplified()
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
    ///   - radius: The inner circle's radius. If omitted, the radius is
    ///     automatically inferred from the geometry’s bounding box by using the
    ///     maximum X extent as one full turn of the circle.
    ///
    /// - Rotation Direction:
    ///   - Rotation is measured clockwise around the origin. This is opposite of
    ///     the standard counter-clockwise convention, but chosen to ensure that
    ///     the resulting wrapped geometry faces upward.
    ///
    func wrappedAroundCircle(radius: Double? = nil) -> any Geometry2D {
        measuringBounds { geometry, bounds in
            @Environment(\.scaledSegmentation) var segmentation
            let innerRadius = radius ?? bounds.maximum.x / 2 / .pi
            let maximumRadius = innerRadius + bounds.maximum.y
            let segmentLength = (maximumRadius * 2 * .pi) / Double(segmentation.segmentCount(circleRadius: maximumRadius))
            let innerCircumference = innerRadius * 2 * .pi

            geometry
                .refined(maxEdgeLength: segmentLength)
                .warped(operationName: "wrapAroundCircle", cacheParameters: radius) {
                    let angle = -360° * $0.x / innerCircumference
                    let radius = innerRadius + $0.y
                    return Vector2D(cos(angle) * radius, sin(angle) * radius)
                }
                .simplified()
        }
    }

    /// Wraps the current geometry around the origin using a circle of the specified diameter.
    ///
    /// See `wrappedAroundCircle(radius:)` for more information.
    ///
    func wrappedAroundCircle(diameter: Double) -> any Geometry2D {
        wrappedAroundCircle(radius: diameter / 2)
    }

    /// Wraps the current geometry around a circular arc defined by an angular span.
    ///
    /// The geometry is wrapped clockwise around the origin, occupying the angular span
    /// specified by `angleRange`. The diameter of the circular arc is calculated so that
    /// the geometry fits within the given angle range based on its maximum X extent.
    ///
    /// - Parameters:
    ///   - angleRange: The span of angles that the wrapped geometry will occupy. The
    ///   wrapping occurs clockwise starting from `angleRange.lowerBound`.
    ///
    /// - Returns: A new `Geometry2D` wrapped around a circular arc defined by the angle range.
    ///
    /// See `wrappedAroundCircle(radius:)` for more information.
    ///
    func wrappedAroundCircle(spanning angleRange: Range<Angle>) -> any Geometry2D {
        measuringBounds { body, bounds in
            let fraction = angleRange.length / 360°
            let targetCircumference = bounds.maximum.x / fraction
            wrappedAroundCircle(diameter: targetCircumference / .pi)
                .rotated(-angleRange.lowerBound)
        }
    }
}

public extension Geometry3D {
    /// Wraps a flat 3D geometry around a sphere.
    ///
    /// This operation transforms a geometry into spherical coordinates, effectively wrapping it over the surface of
    /// a sphere.
    ///
    /// - Coordinate Mapping:
    ///   - The **X axis** controls the **longitude** (rotation around the vertical axis).
    ///     - X = 0 maps to longitude 0°.
    ///     - As X increases, the geometry wraps counter-clockwise when viewed from above (right-hand rule).
    ///     - The entire horizontal range starting from X = 0 is mapped proportionally over 360°.
    ///     - **Important**: If the geometry extends into negative X values, the "wrap" will overlap itself at the
    ///       longitude seam.
    ///   - The **Y axis** controls the **latitude** (vertical position):
    ///     - Y = 0 maps to the equator.
    ///     - Positive Y moves toward the north pole, negative Y toward the south pole.
    ///     - The vertical Y range is mapped proportionally between -90° and +90°.
    ///     - **Important**: If the minimum and maximum Y extents are not symmetrical (e.g., minY ≠ -maxY), the mapping
    ///       may be uneven, causing a distortion in how the surface stretches across the poles.
    ///   - The **Z axis** controls the **radial distance**:
    ///     - Z = 0 lies on the sphere's surface.
    ///     - Positive Z values expand outward from the surface, adding thickness.
    ///
    /// - Sphere Size:
    ///   - If `radius` is provided, it defines the base sphere’s radius.
    ///   - If `radius` is omitted, the radius is inferred from the **maximum X extent** of the geometry.
    ///     - Specifically, the maximum X value determines the circumference of the equator.
    ///     - This makes it important for the geometry to start at X = 0 to fully wrap cleanly.
    ///
    /// - Notes:
    ///   - The geometry is automatically refined for appropriate smoothness based on sphere size.
    ///   - Designed primarily for positive X and a symmetric Y range, but flexible for creative effects.
    ///
    /// - Returns: A new `Geometry3D` that wraps the original shape around a sphere.
    ///
    /// - Example:
    /// ```swift
    /// Rectangle([10, 5])
    ///     .extruded(height: 0.2)
    ///     .wrappedAroundSphere()
    /// ```
    /// This creates a thin, curved shell wrapping around a sphere.
    ///
    func wrappedAroundSphere(radius: Double? = nil) -> any Geometry3D {
        measuringBounds { geometry, bounds in
            @Environment(\.scaledSegmentation) var segmentation
            let naturalCircumference = bounds.maximum.x
            let baseRadius = radius ?? (naturalCircumference / .pi / 2.0)
            let circumference = baseRadius * 2.0 * .pi
            let circumferenceScale = circumference / naturalCircumference
            let yExtent = max(bounds.maximum.y, -bounds.minimum.y)
            let maximumRadius = baseRadius + bounds.maximum.z

            let sphereSegmentLength = maximumRadius * 2 * .pi / Double(segmentation.segmentCount(circleRadius: maximumRadius)) / circumferenceScale

            geometry
                .refined(maxEdgeLength: sphereSegmentLength)
                .warped(operationName: "wrapAroundSphere", cacheParameters: baseRadius) { point in
                    let longitude = 360° * point.x * circumferenceScale / circumference
                    let latitude = 90° * point.y / yExtent
                    let radius = baseRadius + point.z
                    let cosLat = cos(latitude)
                    return Vector3D(
                        radius * cosLat * cos(longitude),
                        radius * cosLat * sin(longitude),
                        radius * sin(latitude)
                    )
                }
                .simplified()
        }
    }

    /// Wraps the current geometry around a sphere using a specified diameter.
    ///
    /// See `wrappedAroundSphere(radius:)` for more information.
    ///
    func wrappedAroundSphere(diameter: Double) -> any Geometry3D {
        wrappedAroundSphere(radius: diameter / 2)
    }
}
