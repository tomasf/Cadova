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
    ///
    /// - SeeAlso: ``projected(_:)``
    func projected() -> any Geometry2D {
        GeometryNodeTransformer(body: self) {
            .projection($0, type: .full)
        }
    }

    /// Performs an orthographic projection of this 3D geometry onto the XY plane and
    /// passes the original 3D geometry and the resulting 2D projection to a builder.
    ///
    /// This method flattens the geometry along the Z axis so each 3D point `(x, y, z)` maps to `(x, y)`.
    /// The projection is purely geometric—no perspective is applied—and represents the top‑down outlines
    /// of the geometry in the XY plane. The `reader` closure receives two values: the original geometry
    /// (`self`) and the produced 2D projection. Use this when you need to construct a result that depends on
    /// both, such as composing, annotating, or comparing the 3D source and its 2D outline.
    ///
    /// - Parameter reader: A geometry builder that takes `(self, projection)` and builds a new geometry.
    /// - Returns: Whatever the builder produces; commonly a composite that combines the original 3D geometry
    ///   with its 2D XY projection.
    ///
    /// - SeeAlso: ``projected()``
    ///
    func projected<D: Dimensionality>(
        @GeometryBuilder<D> _ reader: @escaping @Sendable (_ self: Self, _ projection: any Geometry2D) -> D.Geometry
    ) -> D.Geometry {
        reader(self, projected())
    }

    /// Projects the 3D geometry the a 2D plane, slicing at a specific Z value.
    /// The slicing at Z creates a 2D cross-section of the geometry at that Z height.
    /// - Parameter z: The Z value at which the geometry will be sliced when projecting. It defines the height at
    ///   which the cross-section is taken.
    /// - Returns: A `Geometry2D` representing the projected shape.
    ///
    /// - Example:
    ///   ```swift
    ///   let truncatedCone = Cylinder(bottomDiameter: 10, topDiameter: 5, height: 15)
    ///   let slicedProjection = truncatedCone.sliced(at: 5)
    ///   // The result will be a circle with a diameter that represents the cross-section of the
    ///   // truncated cone at Z = 5.
    ///   ```
    ///
    /// - SeeAlso: ``sliced(atZ:_:)``
    func sliced(atZ z: Double) -> any Geometry2D {
        GeometryNodeTransformer(body: self) {
            .projection($0, type: .slice(z: z))
        }
    }

    /// Intersects this 3D geometry with the horizontal plane `Z = z`, producing a 2D cross‑section,
    /// and passes the original 3D geometry and the 2D slice to a builder.
    ///
    /// The resulting 2D shape represents the outline where the geometry meets the plane at the given height.
    /// The `reader` receives `(self, slice)` so you can build results that depend on both.
    ///
    /// - Parameters:
    ///   - z: The Z height at which the cross‑section is taken.
    ///   - reader: A geometry builder that takes `(self, slice)` and builds a new geometry.
    /// - Returns: Whatever the builder produces; often a composite involving the solid and its 2D section.
    ///
    /// - SeeAlso: ``sliced(atZ:)``
    ///
    func sliced<D: Dimensionality>(
        atZ z: Double,
        @GeometryBuilder<D> _ reader: @escaping @Sendable (_ self: Self, _ slice: any Geometry2D) -> D.Geometry
    ) -> D.Geometry {
        reader(self, sliced(atZ: z))
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
    ///
    /// - SeeAlso: ``sliced(along:_:)``
    func sliced(along plane: Plane) -> any Geometry2D {
        transformed(plane.transform.inverse).sliced(atZ: 0)
    }

    /// Computes the planar intersection of this 3D geometry with an arbitrary plane and passes
    /// the original 3D geometry and the 2D intersection to a builder.
    ///
    /// - Parameters:
    ///   - plane: The slicing plane (position and orientation).
    ///   - reader: A geometry builder that takes `(self, slice)` and builds a new geometry.
    /// - Returns: Whatever the builder produces; typically a composite that includes both the
    ///   original body and the extracted planar intersection.
    ///
    /// - SeeAlso: ``sliced(atZ:)``
    ///
    func sliced<D: Dimensionality>(
        along plane: Plane,
        @GeometryBuilder<D> _ reader: @escaping @Sendable (_ self: Self, _ slice: any Geometry2D) -> D.Geometry
    ) -> D.Geometry {
        reader(self, sliced(along: plane))
    }
}
