import Foundation

struct Projection: CoreGeometry2D {
    let mode: Mode
    let body: any Geometry3D

    func call(in environment: Environment) -> SCADCall {
        switch mode {
        case .whole:
            return SCADCall(
                name: "projection",
                body: body
            )

        case .slice (let z):
            return SCADCall(
                name: "projection",
                params: ["cut": true],
                body: body.translated(z: -z)
            )
        }
    }

    enum Mode {
        case whole
        case slice (z: Double)
    }
}

public extension Geometry3D {
    /// Projects the 3D geometry onto a 2D plane.
    /// - Returns: A `Geometry2D` representing the projected shape.
    /// - Example:
    ///   ```
    ///   let sphere = Sphere(radius: 10)
    ///   let projectedSphere = sphere.projection()
    ///   ```
    func projection() -> any Geometry2D {
        Projection(mode: .whole, body: self)
    }

    /// Projects the 3D geometry onto a 2D plane, slicing at a specific Z value.
    /// The slicing at Z creates a 2D cross-section of the geometry at that Z height.
    /// - Parameter slicingAtZ: The Z value at which the geometry will be sliced when projecting. It defines the height at which the cross-section is taken.
    /// - Returns: A `Geometry2D` representing the projected shape.
    /// - Example:
    ///   ```swift
    ///   let truncatedCone = Cylinder(bottomDiameter: 10, topDiameter: 5, height: 15)
    ///   let slicedProjection = truncatedCone.projection(slicingAtZ: 5)
    ///   // The result will be a circle with a diameter that represents the cross-section of the truncated cone at Z = 5.
    ///   ```
    func projection(slicingAtZ z: Double) -> any Geometry2D {
        Projection(mode: .slice(z: z), body: self)
    }
}
