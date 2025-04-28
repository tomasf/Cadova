import Foundation
import Manifold3D

public extension Geometry2D {
    /// Extrude two-dimensional geometry in the Z axis, creating three-dimensional geometry
    /// - Parameters:
    ///   - height: The height of the resulting geometry, in the Z axis
    ///   - twist: The rotation of the top surface, gradually rotating the geometry around the Z axis, resulting in a twisted shape. Defaults to no twist.
    ///   - scale: The final scale at the top of the extruded shape. The geometry is scaled linearly from 1.0 at the bottom.
    func extruded(height: Double, twist: Angle = 0°, scale: Vector2D = [1, 1]) -> any Geometry3D {
        if twist.isZero {
            extruded(height: height, twist: twist, scale: scale, divisions: 0)
        } else {
            measureBoundsIfNonEmpty { _, e, bounds in
                let numRevolutions = twist / 360°
                let maxRadius = bounds.maximumDistanceToOrigin

                let pitch = height / numRevolutions
                let helixLength = sqrt(pow(maxRadius * 2 * .pi, 2) + pow(pitch, 2)) * numRevolutions

                let segmentsPerRevolution = e.segmentation.segmentCount(circleRadius: maxRadius)
                let twistSegments = Int(Double(segmentsPerRevolution) * numRevolutions)
                let lengthSegments = e.segmentation.segmentCount(length: helixLength)
                extruded(height: height, twist: twist, scale: scale, divisions: max(twistSegments, lengthSegments))
            }
        }
    }

    internal func extruded(height: Double, twist: Angle = 0°, scale: Vector2D = [1,1], divisions: Int) -> any Geometry3D {
        GeometryExpressionTransformer(body: self) {
            GeometryExpression3D.extrusion($0, type: .linear(
                height: height, twist: twist, divisions: divisions, scaleTop: scale
            ))
        }
    }


    /// Revolves a two-dimensional geometry around the Z-axis to create three-dimensional solid geometry.
    ///
    /// This operation takes the portion of the 2D shape lying on or to the right of the X=0 line (positive X-axis)
    /// and sweeps it around the Z-axis to form a solid. Any parts of the shape with negative X-coordinates
    /// are ignored during the revolution.
    ///
    /// - Parameter range: The angular range over which the geometry is revolved, specified as a `Range<Angle>`.
    ///   By default, the geometry is rotated a full circle (0°..<360°). Specifying a smaller range
    ///   creates partial revolutions, useful for generating open structures or segments.
    ///
    /// - Returns: A new 3D solid formed by revolving the original shape within the given angle range.
    ///
    /// - Example:
    /// ```swift
    /// let hemisphere = Circle(radius: 10).revolved(in: 0°..<180°)
    /// ```
    func revolved(in range: Range<Angle> = 0°..<360°) -> any Geometry3D {
        readEnvironment(\.segmentation) { segmentation in
            self.measuring { geometry, measurements in
                let bounds = measurements.boundingBox ?? .zero
                let radius = max(bounds.maximum.x, 0)

                GeometryExpressionTransformer(body: geometry) {
                    GeometryExpression3D.extrusion($0, type: .rotational(
                        angle: range.length,
                        segments: segmentation.segmentCount(circleRadius: radius)
                    ))
                }
                .rotated(z: range.lowerBound)
            }
        }
    }
}
