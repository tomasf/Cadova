import Foundation
import Manifold3D

public extension Geometry3D {
    /// Projects the 3D geometry orthogonally onto the XY plane, removing depth information.
    ///
    /// This method flattens the geometry by projecting all points along the Z-axis onto the XY plane.
    /// It effectively reduces a 3D shape to its 2D outline or silhouette as seen from above (top-down view),
    /// discarding the Z-coordinate.
    ///
    /// The projection is purely geometric and does not simulate perspective—it's an orthographic projection.
    ///
    /// - Returns: A `Geometry2D` representing the 2D projection of the original 3D shape.
    ///
    /// - Example:
    ///   ```swift
    ///   let circle = Sphere(radius: 10).projected()
    ///   ```
    ///   This creates a circle in 2D that represents the top-down outline of a 3D sphere.
    func projected() -> any Geometry2D {
        modifyingPrimitive { primitive, _ in
            primitive.projection()
        }
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
    func sliced(atZ z: Double) -> any Geometry2D {
        modifyingPrimitive { primitive, _ in
            primitive.slice(at: z)
        }
    }

    /// Creates a 2D cross-section of the geometry where it intersects with a given plane.
    ///
    /// This method returns the shape formed by slicing the 3D geometry along an arbitrary plane.
    /// The result is a flat 2D outline of the intersection.
    ///
    /// - Parameter plane: The plane along which the geometry will be sliced.
    /// - Returns: A `Geometry2D` representing the flat cross-section along the specified plane.
    ///
    /// - Example:
    ///   ```swift
    ///   let angledPlane = Plane(z: 6).rotated(y: 30°)
    ///   let coneSlice = Cylinder(bottomDiameter: 10, topDiameter: 0, height: 15)
    ///       .sliced(along: angledPlane)
    ///   // coneSlice is a 2D shape where the cone intersects with the slanted plane.
    ///   ```
    func sliced(along plane: Plane) -> any Geometry2D {
        transformed(plane.transform.inverse).sliced(atZ: 0)
    }
}
