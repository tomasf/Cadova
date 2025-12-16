import Foundation

public typealias WithinRange = RangeExpression<Double> & Sendable

public extension Geometry2D {
    /// Returns a geometry that is clipped within the specified ranges along the x and y axes.
    ///
    /// This method is useful for trimming a geometry to a specific region of space. Axes that are `nil` are left unbounded. You can use
    /// any `Range` expression, including open, closed, partial, and infinite ranges.
    ///
    /// - Parameters:
    ///   - x: Optional range along the x-axis. If `nil`, no clipping occurs along this axis.
    ///   - y: Optional range along the y-axis. If `nil`, no clipping occurs along this axis.
    /// - Returns: A geometry clipped to the specified region.
    ///
    /// ## Example
    /// ```swift
    /// Circle(diameter: 10)
    ///     .within(y: 0...)
    /// ```
    /// This trims a circle to only include the upper (y > 0) part.
    ///
    func within(
        x: (any WithinRange)? = nil,
        y: (any WithinRange)? = nil
    ) -> any Geometry2D {
        measuringBounds { body, bounds in
            body.intersecting { bounds.within(x: x, y: y, margin: 1).mask }
        }
    }
}

public extension Geometry3D {
    /// Returns a geometry that is clipped within the specified ranges along the x, y, and z axes.
    ///
    /// This method is useful for trimming a 3D geometry to a specific region of space. Axes that are `nil` are left unbounded. You can use
    /// any `Range` expression, including open, closed, partial, and infinite ranges.
    ///
    /// - Parameters:
    ///   - x: Optional range along the x-axis. If `nil`, no clipping occurs along this axis.
    ///   - y: Optional range along the y-axis. If `nil`, no clipping occurs along this axis.
    ///   - z: Optional range along the z-axis. If `nil`, no clipping occurs along this axis.
    /// - Returns: A geometry clipped to the specified region.
    ///
    /// ## Example
    /// ```swift
    /// Sphere(diameter: 10)
    ///     .within(z: ...0)
    /// ```
    /// This trims a sphere to only include the lower (z < 0) hemisphere.
    ///
    func within(
        x: (any WithinRange)? = nil,
        y: (any WithinRange)? = nil,
        z: (any WithinRange)? = nil
    ) -> any Geometry3D {
        measuringBounds { body, bounds in
            body.intersecting { bounds.within(x: x, y: y, z: z, margin: 1).mask }
        }
    }
}

public extension Geometry2D {
    /// Applies additional operations only within a specified region.
    ///
    /// This variant of `within` allows you to selectively apply geometry operations to a subregion of a shape.
    /// The original geometry is preserved outside the specified region, while the intersected region is transformed
    /// using the provided `operations` closure.
    ///
    /// - Parameters:
    ///   - x: Optional range along the x-axis. If `nil`, the region is unbounded in the x direction.
    ///   - y: Optional range along the y-axis. If `nil`, the region is unbounded in the y direction.
    ///   - operations: A closure that receives the clipped region and returns a new modified geometry.
    ///
    /// ## Example
    /// ```swift
    /// Circle(diameter: 10)
    ///     .within(y: 0...) {
    ///         $0.translated(y: 1)
    ///     }
    /// ```
    /// This leaves the lower half of the circle unchanged, and moves the upper half (y > 0) up.
    ///
    func within(
        x: (any WithinRange)? = nil,
        y: (any WithinRange)? = nil,
        @GeometryBuilder<D> do operations: @escaping @Sendable (D.Geometry) -> D.Geometry
    ) -> any Geometry2D {
        measuringBounds { body, bounds in
            let mask = bounds.within(x: x, y: y, margin: 1).mask
            body
                .subtracting(mask)
                .adding {
                    operations(body.intersecting(mask))
                }
        }
    }
}

public extension Geometry3D {
    /// Applies additional operations only within a specified 3D region.
    ///
    /// This variant of `within` allows you to apply geometry modifications to a subregion of a 3D shape.
    /// The original geometry is preserved outside the specified region, and the intersected region is passed
    /// into the `operations` closure for transformation.
    ///
    /// - Parameters:
    ///   - x: Optional range along the x-axis. If `nil`, the region is unbounded in the x direction.
    ///   - y: Optional range along the y-axis. If `nil`, the region is unbounded in the y direction.
    ///   - z: Optional range along the z-axis. If `nil`, the region is unbounded in the z direction.
    ///   - operations: A closure that receives the clipped region and returns a new modified geometry.
    ///
    /// ## Example
    /// ```swift
    /// Sphere(diameter: 10)
    ///     .within(z: ...0) {
    ///         $0.colored(.red)
    ///             .translated(z: -1)
    ///     }
    /// ```
    /// This leaves the upper hemisphere of the sphere unchanged, and moves the lower half (z < 0) down and colors it red.
    ///
    func within(
        x: (any WithinRange)? = nil,
        y: (any WithinRange)? = nil,
        z: (any WithinRange)? = nil,
        @GeometryBuilder<D> do operations: @escaping @Sendable (D.Geometry) -> D.Geometry
    ) -> any Geometry3D {
        measuringBounds { _, bounds in
            let mask = bounds.within(x: x, y: y, z: z, margin: 1).mask

            self
                .subtracting(mask)
                .adding {
                    operations(self.intersecting(mask))
                }
        }
    }
}
