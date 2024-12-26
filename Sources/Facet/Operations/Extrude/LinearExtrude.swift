import Foundation
import Manifold

struct LinearExtrude: ExtrusionGeometry {
    let body: any Geometry2D
    let height: Double
    let twist: Angle?
    let scale: Vector2D

    func extrude(_ child: CrossSection, in environment: EnvironmentValues) -> Mesh {
        guard !child.isEmpty else { return .empty }
        return child.extrude(height: height, divisions: 0, twist: twist?.degrees ?? 0, scaleTop: scale)
    }
}

public extension Geometry2D {
    /// Extrude two-dimensional geometry in the Z axis, creating three-dimensional geometry
    /// - Parameters:
    ///   - height: The height of the resulting geometry, in the Z axis
    ///   - twist: The rotation of the top surface, gradually rotating the geometry around the Z axis, resulting in a twisted shape. Defaults to no twist. Note that the twist direction follows the right-hand rule, which is the opposite of OpenSCAD's behavior.
    ///   - scale: The final scale at the top of the extruded shape. The geometry is scaled linearly from 1.0 at the bottom.
    func extruded(height: Double, twist: Angle? = nil, scale: Vector2D = [1, 1]) -> any Geometry3D {
        LinearExtrude(body: self, height: height, twist: twist, scale: scale)
    }
}
