import Foundation
import Manifold3D

internal struct Projection: Geometry2D {
    var body: any Geometry3D
    var projection: (D3.Primitive, EnvironmentValues) -> D2.Primitive

    func evaluated(in environment: EnvironmentValues) -> Output2D {
        .init(child: body, environment: environment, transformation: { projection($0, environment) })
    }
}

internal extension Geometry3D {
    func projected(action: @escaping (D3.Primitive, EnvironmentValues) -> D2.Primitive) -> any Geometry2D {
        Projection(body: self, projection: action)
    }
}

public extension Geometry3D {
    /// Projects the 3D geometry onto the 2D plane.
    /// - Returns: A `Geometry2D` representing the projected shape.
    /// - Example:
    ///   ```
    ///   let circle = Sphere(radius: 10).projected()
    ///   ```
    func projected() -> any Geometry2D {
        projected { p, _ in p.projection() }
    }

    /// Projects the 3D geometry the a 2D plane, slicing at a specific Z value.
    /// The slicing at Z creates a 2D cross-section of the geometry at that Z height.
    /// - Parameter z: The Z value at which the geometry will be sliced when projecting. It defines the height at which the cross-section is taken.
    /// - Returns: A `Geometry2D` representing the projected shape.
    /// - Example:
    ///   ```swift
    ///   let truncatedCone = Cylinder(bottomDiameter: 10, topDiameter: 5, height: 15)
    ///   let slicedProjection = truncatedCone.sliced(at: 5)
    ///   // The result will be a circle with a diameter that represents the cross-section of the truncated cone at Z = 5.
    ///   ```
    func sliced(at z: Double) -> any Geometry2D {
        projected { p, _ in p.slice(at: z) }
    }
}
