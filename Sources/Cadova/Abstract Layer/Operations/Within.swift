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
        measuringBounds { _, bounds in
            self.intersecting { bounds.within(x: x, y: y).mask }
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
        measuringBounds { _, bounds in
            self.intersecting { bounds.within(x: x, y: y, z: z).mask }
        }
    }
}


fileprivate extension BoundingBox {
    func partialBox(from: Double?, to: Double?, in axis: D.Axis) -> BoundingBox {
        BoundingBox(
            minimum: minimum.with(axis, as: from ?? minimum[axis] - 1),
            maximum: maximum.with(axis, as: to ?? maximum[axis] + 1)
        )
    }
}

internal extension BoundingBox2D {
    func within(x: (any WithinRange)? = nil, y: (any WithinRange)? = nil) -> Self {
        self
            .partialBox(from: x?.min, to: x?.max, in: .x)
            .partialBox(from: y?.min, to: y?.max, in: .y)
    }

    var mask: any Geometry2D {
        Rectangle(size).translated(minimum)
    }
}

internal extension BoundingBox3D {
    func within(x: (any WithinRange)? = nil, y: (any WithinRange)? = nil, z: (any WithinRange)? = nil) -> Self {
        self
            .partialBox(from: x?.min, to: x?.max, in: .x)
            .partialBox(from: y?.min, to: y?.max, in: .y)
            .partialBox(from: z?.min, to: z?.max, in: .z)
    }

    var mask: any Geometry3D {
        Box(size).translated(minimum)
    }
}
