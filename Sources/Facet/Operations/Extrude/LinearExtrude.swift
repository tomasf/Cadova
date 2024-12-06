import Foundation

struct LinearExtrude: ExtrusionGeometry {
    let body: any Geometry2D
    let height: Double
    let twist: Angle?
    let scale: Vector2D

    let moduleName = "linear_extrude"
    var moduleParameters: CodeFragment.Parameters {[
        "height": height,
        "twist": twist.map { -$0 } ?? 0°,
        "scale": scale,
    ]}

    func boundary(for boundary2D: Boundary2D, facets: EnvironmentValues.Facets) -> Boundary3D {
        boundary2D.extruded(
            height: height,
            twist: twist ?? 0°,
            topScale: scale,
            facets: facets
        )
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
