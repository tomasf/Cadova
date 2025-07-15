import Foundation

public extension Geometry2D {
    /// Applies an edge profile to the corners of a 2D rectangular geometry.
    ///
    /// This method assumes that the geometry is rectangular or approximately rectangular, and applies an edge profile
    /// to the specified corners. The profile determines the shape of the corners — for example, a chamfer or a fillet.
    ///
    /// - Parameters:
    ///   - edgeProfile: The edge profile to apply. Defines the 2D cross-sectional shape to use at each corner.
    ///   - corners: The corners of the rectangle where the profile should be applied. Defaults to `.all`.
    /// - Returns: A new `Geometry2D` with the edge profile applied to the selected corners.
    ///
    /// This method uses the bounding rectangle of the geometry to determine how to place and size the profile.
    /// It is suitable for geometries that are rectangular or similar enough for this approximation to be effective.
    ///
    func applyingEdgeProfile(_ edgeProfile: EdgeProfile, to corners: Rectangle.Corners = .all) -> any Geometry2D {
        measuringBounds { child, bounds in
            child.intersecting {
                ProfiledRectangleMask(size: bounds.size, profile: edgeProfile, corners: corners)
                    .translated(bounds.center)
            }
        }
    }
}

public extension Geometry3D {
    /// Applies an edge profile to selected corners of the geometry along a specific axis.
    ///
    /// This method assumes that the geometry is a box or something similar and modifies its corners
    /// as if it were a box.
    ///
    /// - Parameters:
    ///   - edgeProfile: The profile shape to apply (e.g., `.fillet(radius:)`, `.chamfer(depth:height:)`).
    ///   - corners: The corners to which the profile is applied. Defaults to `.all`.
    ///   - axis: The axis along which to apply the edge profile.
    ///     - For the Z axis, the corners are as seen from positive Z, looking down at the origin with positive X
    ///       pointing right and positive Y pointing up.
    ///     - For the X axis, the corners are as seen from the origin, with the positive Y axis pointing left and Z
    ///       pointing up.
    ///     - For the Y axis, the corners are as seen from the origin, with the positive X axis pointing right and Z
    ///       pointing up.
    ///
    /// - Returns: A new `Geometry3D` object with the edge profile applied to the specified corners along the given
    ///   axis.
    ///
    /// This method uses the bounding box of the geometry to determine the appropriate size and position for the
    /// profile. It is intended for geometries that are box-like or similar enough for this approximation to be
    /// effective. The shape of fillets is determined by the environment’s `cornerRoundingStyle`, which controls whether
    /// corners are shaped as simple circular arcs or smoother, squircle-like transitions.
    ///
    func applyingEdgeProfile(
        _ edgeProfile: EdgeProfile,
        to corners: Rectangle.Corners = .all,
        along axis: Axis3D
    ) -> any Geometry3D {
        let adjustments = [90°, 0°, 180°]
        
        return self
            .rotated(from: axis.direction(.negative), to: .up)
            .rotated(z: adjustments[axis.index])
            .measuring { body, measurements in
                let box = measurements.boundingBox.requireNonNil()
                body.intersecting {
                    ProfiledRectangleMask(size: box.size.xy, profile: edgeProfile, corners: corners)
                        .extruded(height: box.size.z)
                        .translated(z: -box.size.z / 2)
                        .translated(box.center)
                }
            }
            .rotated(z: -adjustments[axis.index])
            .rotated(from: .up, to: axis.direction(.negative))
    }
}
