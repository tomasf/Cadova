import Foundation

public extension Geometry3D {
    /// Rounds all eight corners of the geometry using its bounding box dimensions.
    ///
    /// This method assumes that the geometry is a box or something similar and rounds all its corners as if it were a
    /// box.
    ///
    /// - Parameter radius: The radius of the rounding applied to each corner.
    /// - Returns: A new `Geometry3D` object with all eight corners of the geometry rounded in a spherical fashion.
    ///
    /// This method uses the bounding box of the geometry to determine the appropriate size for the rounding mask.
    /// It is intended for geometries that are box-like or similar enough for this approximation to be effective.
    ///
    /// The rounding is done in a spherical manner, affecting all eight corners of the bounding box uniformly.
    /// The shape of the rounded corners is determined by the environment’s `cornerRoundingStyle`, which controls
    /// whether corners are shaped as simple circular arcs or smoother, squircle-like transitions.
    /// 
    func roundingBoxCorners(radius: Double) -> any Geometry3D {
        measuring { child, measurements in
            child.intersecting {
                let box = measurements.boundingBox.requireNonNil()
                RoundedBoxCornerMask(boxSize: box.size / 2, radius: radius)
                    .translated(-box.size / 2)
                    .symmetry(over: .all)
                    .translated(box.center)
            }
        }
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
    /// is desired. The specified side’s four corners are smoothly rounded based on the given radius. The shape
    /// of the rounded corners is determined by the environment’s `cornerRoundingStyle`, which affects whether
    /// corners use a standard circular arc or a more gradual, squircular curve.
    ///
    func roundingBoxCorners(side: Box.Side, radius: Double) -> any Geometry3D {
        self
            .rotated(from: side.direction, to: .down)
            .measuring { child, measurements in
                child.intersecting {
                    let box = measurements.boundingBox.requireNonNil()
                    RoundedBoxCornerMask(boxSize: .init(box.size.x / 2, box.size.y / 2, box.size.z), radius: radius)
                        .translated(-box.size / 2)
                        .symmetry(over: .xy)
                        .translated(box.center)
                }
            }
            .rotated(from: .down, to: side.direction)
    }

    /// Rounds the specified corner and its adjacent edges based on the geometry's bounding box dimensions.
    ///
    /// This method applies rounding to a single corner of the geometry, smoothing the transition between the
    /// three edges that converge at the specified corner. The rounding effect is localized to the given corner
    /// and provides a softened appearance at that point.
    ///
    /// - Parameters:
    ///   - corner: The corner to round, specified using `Box.Corner` (e.g., `.minXminYminZ`).
    ///   - radius: The radius of the rounding applied to the selected corner and its adjacent edges.
    ///
    /// - Returns: A new `Geometry3D` object with the specified corner and its adjacent edges rounded.
    ///
    /// This method is intended for box-like geometries where rounding only one corner is desired.
    /// It uses the bounding box of the geometry to determine the correct positioning and size for the rounding
    /// effect. The specified corner is rounded in a way that affects the three edges meeting at that corner.
    /// The appearance of the rounded corner is controlled by the environment’s `cornerRoundingStyle`, determining
    /// if the corner uses a circular or a smoother squircular shape.
    ///
    func roundingBoxCorner(_ corner: Box.Corner, radius: Double) -> any Geometry3D {
        self
            .flipped(along: corner.maxAxes)
            .measuring { child, measurements in
                child.intersecting {
                    let box = measurements.boundingBox.requireNonNil()
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
    /// This method applies rounding to multiple corners of the geometry, smoothing the transition at each selected
    /// corner. Each corner is rounded individually, providing a softened appearance at the points specified by the
    /// `corners` parameter.
    ///
    /// - Parameters:
    ///   - corners: A set of corners to round, specified using `Box.Corner` (e.g., `[.minXminYminZ, .maxXminYminZ]`).
    ///   - radius: The radius of the rounding applied to each specified corner and its adjacent edges.
    ///
    /// - Returns: A new `Geometry3D` object with the specified corners rounded.
    ///
    /// This method is intended for box-like geometries where rounding multiple corners is desired. It uses the
    /// bounding box of the geometry to determine the correct positioning and size for the rounding effect. Each
    /// specified corner is rounded individually, affecting the three edges that meet at each corner. The look of each
    /// rounded corner depends on the environment’s `cornerRoundingStyle`, which sets whether corners are circular or
    /// use a squircle profile for a softer result.
    ///
    func roundingBoxCorners(_ corners: Set<Box.Corner>, radius: Double) -> any Geometry3D {
        corners.reduce(self) {
            $0.roundingBoxCorner($1, radius: radius)
        }
    }
}
