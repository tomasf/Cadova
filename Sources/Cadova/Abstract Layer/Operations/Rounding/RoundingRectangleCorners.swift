import Foundation

public extension Geometry2D {
    /// Rounds the corners of the geometry using its bounding rectangle dimensions.
    ///
    /// This method assumes that the geometry is a rectangle or something similar and rounds its corners as if it were a
    /// rectangle.
    ///
    /// - Parameters:
    ///   - corners: The corners of the rectangle to round. Defaults to `.all`.
    ///   - radius: The radius of the rounding.
    ///
    /// - Returns: A new `Geometry2D` object with rounded corners applied to the geometry.
    ///
    /// This method uses the bounding rectangle of the geometry to determine the appropriate size for the rounding mask. It
    /// is intended for geometries that are rectangular or similar enough for this approximation to be effective. The shape
    /// of the rounded corners is determined by the environment’s `roundedCornerStyle`, which controls whether corners are
    /// shaped as simple circular arcs or smoother, squircle-like transitions.
    ///
    func roundingRectangleCorners(_ corners: Rectangle.Corners = .all, radius: Double) -> any Geometry2D {
        measuring { child, measurements in
            let box = measurements.boundingBox.requireNonNil()
            child.intersecting {
                RoundedRectangleMask(size: box.size, radius: radius, corners: corners)
                    .translated(box.center)
            }
        }
    }
}
