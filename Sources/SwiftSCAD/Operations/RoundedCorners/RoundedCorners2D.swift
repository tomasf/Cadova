import Foundation

public extension Geometry2D {
    /// Rounds the corners of the geometry using its bounding rectangle dimensions.
    ///
    /// This method assumes that the geometry is a rectangle or something similar and rounds its corners as if it were a rectangle.
    ///
    /// - Parameters:
    ///   - corners: The corners of the rectangle to round. Defaults to `.all`.
    ///   - radius: The radius of the rounding.
    ///   - style: The style of the rounded corners. Defaults to `.circular`.
    ///
    /// - Returns: A new `Geometry2D` object with rounded corners applied to the geometry.
    ///
    /// This method uses the bounding rectangle of the geometry to determine the appropriate size for the rounding mask.
    /// It is intended for geometries that are rectangular or similar enough for this approximation to be effective.

    func roundingRectangleCorners(_ corners: Rectangle.Corners = .all, radius: Double, style: RoundedCornerStyle = .circular) -> any Geometry2D {
        let epsilon = 0.001
        return measuringBounds { child, box in
            let box = box.requireNonNil()
            child.intersecting {
                RoundedRectangleMask(size: box.size + 2 * epsilon, radius: radius, corners: corners, style: style)
                    .translated(box.minimum - epsilon)
            }
        }
    }
}
