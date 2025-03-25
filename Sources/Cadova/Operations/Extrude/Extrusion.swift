import Foundation
import Manifold3D

internal struct Extrusion: Geometry3D {
    var body: any Geometry2D
    var extrusion: (D2.Primitive, EnvironmentValues) -> D3.Primitive

    func evaluated(in environment: EnvironmentValues) -> Output3D {
        .init(child: body, environment: environment, transformation: { extrusion($0, environment) })
    }
}

internal extension Geometry2D {
    func extruded(action: @escaping (D2.Primitive, EnvironmentValues) -> D3.Primitive) -> any Geometry3D {
        Extrusion(body: self, extrusion: action)
    }
}

public extension Geometry2D {
    /// Extrude two-dimensional geometry in the Z axis, creating three-dimensional geometry
    /// - Parameters:
    ///   - height: The height of the resulting geometry, in the Z axis
    ///   - twist: The rotation of the top surface, gradually rotating the geometry around the Z axis, resulting in a twisted shape. Defaults to no twist. Note that the twist direction follows the right-hand rule, which is the opposite of OpenSCAD's behavior.
    ///   - scale: The final scale at the top of the extruded shape. The geometry is scaled linearly from 1.0 at the bottom.
    func extruded(height: Double, twist: Angle = 0°, scale: Vector2D = [1, 1]) -> any Geometry3D {
        extruded { primitive, _ in
            if primitive.isEmpty {
                .empty
            } else {
                primitive.extrude(height: height, divisions: 0, twist: twist.degrees, scaleTop: scale)
            }
        }
    }

    /// Extrude two-dimensional geometry around the Z axis, creating three-dimensional geometry
    /// - Parameters:
    ///   - angles: The angle range in which to extrude. The resulting shape is formed around the Z axis in this range.
    func extruded(angles: Range<Angle> = 0°..<360°) -> any Geometry3D {
        extruded { primitive, e in
            let bounds = primitive.bounds
            let radius = bounds.min.x < 0 && bounds.max.x <= 0 ? -bounds.min.x : bounds.max.x
            return primitive.revolve(
                degrees: (angles.upperBound - angles.lowerBound).degrees,
                circularSegments: e.facets.facetCount(circleRadius: radius)
            )
        }
        .rotated(z: angles.lowerBound)
    }
}
