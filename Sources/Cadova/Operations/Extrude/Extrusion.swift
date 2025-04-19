import Foundation
import Manifold3D

public extension Geometry2D {
    /// Extrude two-dimensional geometry in the Z axis, creating three-dimensional geometry
    /// - Parameters:
    ///   - height: The height of the resulting geometry, in the Z axis
    ///   - twist: The rotation of the top surface, gradually rotating the geometry around the Z axis, resulting in a twisted shape. Defaults to no twist.
    ///   - scale: The final scale at the top of the extruded shape. The geometry is scaled linearly from 1.0 at the bottom.
    func extruded(height: Double, twist: Angle = 0°, scale: Vector2D = [1, 1]) -> any Geometry3D {
        GeometryExpressionTransformer(body: self) {
            GeometryExpression3D.extrusion($0, type: .linear(
                height: height, twist: twist, divisions: 0, scaleTop: scale
            ))
        }
    }

    /// Extrude two-dimensional geometry around the Z axis, creating three-dimensional geometry
    /// - Parameters:
    ///   - angles: The angle range in which to extrude. The resulting shape is formed around the Z axis in this range.
    func extruded(angles: Range<Angle> = 0°..<360°) -> any Geometry3D {
        readEnvironment(\.facets) { facets in
            self.measuring { geometry, measurements in
                let bounds = measurements.boundingBox ?? .zero
                let radius = bounds.minimum.x < 0 && bounds.maximum.x <= 0 ? -bounds.minimum.x : bounds.maximum.x

                GeometryExpressionTransformer(body: geometry) {
                    GeometryExpression3D.extrusion($0, type: .rotational(
                        angle: (angles.upperBound - angles.lowerBound),
                        segments: facets.facetCount(circleRadius: radius)
                    ))
                }
                .rotated(z: angles.lowerBound)
            }
        }
    }
}
