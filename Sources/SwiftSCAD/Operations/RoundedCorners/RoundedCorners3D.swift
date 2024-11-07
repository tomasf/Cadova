import Foundation

internal extension Geometry3D {
    func roundingBoxCorners(radius: Double, mode: RoundedBoxMask3D.Mode) -> any Geometry3D {
        let epsilon = 0.001
        return measuringBounds { child, box in
            child.intersecting {
                let box = box.requireNonNil()
                RoundedBoxMask3D(size: box.size + 2 * epsilon, cornerRadius: radius, mode: mode)
                    .translated(box.center)
            }
        }
    }
}

public extension Geometry3D {
    /// Rounds the corners of the geometry using its bounding box dimensions along a specified axis.
    ///
    /// This method assumes that the geometry is a box or something similar and rounds its corners as if it were a box.
    ///
    /// - Parameters:
    ///   - corners: The corners of the geometry to round. Defaults to `.all`.
    ///   - axis: The axis along which to round the corners.
    ///     - For the Z axis, the corners are as seen from positive Z, looking down at the origin with positive X pointing right and positive Y pointing up.
    ///     - For the X axis, the corners are as seen from the origin, with the positive Y axis pointing left and Z pointing up.
    ///     - For the Y axis, the corners are as seen from the origin, with the positive X axis pointing right and Z pointing up.
    ///   - radius: The radius of the rounding.
    ///   - style: The style of the rounded corners. Defaults to `.circular`.
    ///
    /// - Returns: A new `Geometry3D` object with rounded corners applied to the geometry.
    ///
    /// This method uses the bounding box of the geometry to determine the appropriate size for rounding.
    /// It is intended for geometries that are box-like or similar enough for this approximation to be effective.

    func roundingBoxCorners(_ corners: Rectangle.Corners = .all, axis: Axis3D, radius: Double, style: RoundedCornerStyle = .circular) -> any Geometry3D {
        roundingBoxCorners(axis: axis, .init(radius, corners: corners), style: style)
    }

    /// Rounds all eight corners of the geometry using its bounding box dimensions.
    ///
    /// This method assumes that the geometry is a box or something similar and rounds all its corners as if it were a box.
    ///
    /// - Parameter radius: The radius of the rounding applied to each corner.
    ///
    /// - Returns: A new `Geometry3D` object with all eight corners of the geometry rounded in a spherical fashion.
    ///
    /// This method uses the bounding box of the geometry to determine the appropriate size for the rounding mask.
    /// It is intended for geometries that are box-like or similar enough for this approximation to be effective.
    ///
    /// The rounding is done in a spherical manner, affecting all eight corners of the bounding box uniformly.
    
    func roundingBoxCorners(radius: Double) -> any Geometry3D {
        roundingBoxCorners(radius: radius, mode: .full)
    }

    /// Rounds the four corners of the specified side of the geometry.
    ///
    /// This method applies rounding to the four corners of the chosen side of the geometry.
    ///
    /// - Parameters:
    ///   - radius: The radius of the rounding applied to the four corners.
    ///   - side: The side of the box to round, specified using `Box.Side` (e.g., `.minY`, `.top`, `.back`).
    ///
    /// - Returns: A new `Geometry3D` object with the specified side's corners rounded.
    ///
    /// This method is intended for geometries with box-like structures, where rounding only one side’s corners
    /// is desired. The specified side’s four corners are smoothly rounded based on the given radius.
    ///
    func roundingBoxCorners(side: Box.Side, radius: Double) -> any Geometry3D {
        self
            .rotated(from: side.direction, to: .up)
            .roundingBoxCorners(radius: radius, mode: .top)
            .rotated(from: .up, to: side.direction)
    }

    /// Rounds the specified corner and its adjacent edges based on the geometry's bounding box dimensions.
    ///
    /// This method applies rounding to a single corner of the geometry, smoothing the transition between the three edges that converge at the specified corner.
    /// The rounding effect is localized to the given corner and provides a softened appearance at that point.
    ///
    /// - Parameters:
    ///   - corner: The corner to round, specified using `Box.Corner` (e.g., `.minXminYminZ`).
    ///   - radius: The radius of the rounding applied to the selected corner and its adjacent edges.
    ///
    /// - Returns: A new `Geometry3D` object with the specified corner and its adjacent edges rounded.
    ///
    /// This method is intended for box-like geometries where rounding only one corner is desired.
    /// It uses the bounding box of the geometry to determine the correct positioning and size for the rounding effect.
    /// The specified corner is rounded in a way that affects the three edges meeting at that corner.
    ///
    func roundingBoxCorner(_ corner: Box.Corner, radius: Double) -> any Geometry3D {
        self
            .flipped(along: corner.maxAxes)
            .measuringBounds { child, box in
                child.intersecting {
                    let box = box.requireNonNil()
                    child.intersecting {
                        RoundedBoxCornerMask(boxSize: box.size, radius: radius)
                            .translated(box.minimum)
                    }
                }
            }
            .flipped(along: corner.maxAxes)
    }

    /// Rounds the specified corners of the geometry based on its bounding box dimensions.
    ///
    /// This method applies rounding to multiple corners of the geometry, smoothing the transition at each selected corner.
    /// Each corner is rounded individually, providing a softened appearance at the points specified by the `corners` parameter.
    ///
    /// - Parameters:
    ///   - corners: A set of corners to round, specified using `Box.Corner` (e.g., `[.minXminYminZ, .maxXminYminZ]`).
    ///   - radius: The radius of the rounding applied to each specified corner and its adjacent edges.
    ///
    /// - Returns: A new `Geometry3D` object with the specified corners rounded.
    ///
    /// This method is intended for box-like geometries where rounding multiple corners is desired.
    /// It uses the bounding box of the geometry to determine the correct positioning and size for the rounding effect.
    /// Each specified corner is rounded individually, affecting the three edges that meet at each corner.
    ///
    func roundingBoxCorners(_ corners: Set<Box.Corner>, radius: Double) -> any Geometry3D {
        corners.reduce(self) {
            $0.roundingBoxCorner($1, radius: radius)
        }
    }
}

internal extension Geometry3D {
    func roundingBoxCorners(axis: Axis3D, _ radii: RectangleCornerRadii, style: RoundedCornerStyle = .circular) -> any Geometry3D {
        let adjustments = [90°, 0°, 180°]

        return self
            .rotated(from: axis.direction * -1, to: .up)
            .rotated(z: adjustments[axis.index])
            .measuringBounds { body, box in
                let box = box.requireNonNil()
                body.intersecting {
                    RoundedRectangleMask(box.size.xy, style: style, radii: radii)
                        .extruded(height: box.size.z)
                        .translated(box.minimum)
                }
            }
            .rotated(z: -adjustments[axis.index])
            .rotated(from: .up, to: axis.direction * -1)
    }
}
