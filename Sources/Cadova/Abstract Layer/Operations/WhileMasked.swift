import Foundation

public extension Geometry {
    /// Applies a transformation only to the parts of a geometry that intersect a specified mask.
    ///
    /// This method removes the masked area from the original geometry, applies a transformation to the full geometry,
    /// then intersects the result with the mask, and finally adds the transformed result back into the shape.
    /// It's useful for selectively applying modifications such as rounding, offsetting, or translation.
    ///
    /// - Parameters:
    ///   - inverted: If `true`, inverts the mask logic so that the operations are applied to the complement of the mask
    ///               (outside the masked region). If `false` (default), operations are applied only inside the mask.
    ///   - mask: A closure that returns the mask geometry. The transformation will only be applied within this region
    ///           unless `inverted` is `true`, in which case the transformation is applied outside this region.
    ///   - operations: A closure that takes the *original geometry* and returns a modified version, to be restricted to the mask area (or its complement if `inverted` is `true`).
    /// - Returns: A new geometry where the specified transformation is applied only inside the masked region, or outside it when `inverted` is `true`.
    ///
    /// ## Example
    /// Round only one point of a five-pointed star:
    ///
    /// ```swift
    /// Circle(diameter: 5)
    ///     .convexHull(adding: [10, 0])
    ///     .repeated(count: 5)
    ///     .whileMasked {
    ///         Rectangle(10)
    ///             .aligned(at: .centerY)
    ///             .translated(x: 2.5)
    ///     } do: {
    ///         $0.rounded(outsideRadius: 0.5)
    ///     }
    /// ```
    ///
    /// In this example, a vertical rectangle defines a mask over one of the star’s points.
    /// The `rounded` operation is applied only within that region. All other points remain sharp.
    ///
    @GeometryBuilder<D>
    func whileMasked(
        inverted: Bool = false,
        @GeometryBuilder<D> using mask: @Sendable @escaping () -> D.Geometry,
        @GeometryBuilder<D> do operations: @Sendable @escaping (D.Geometry) -> D.Geometry
    ) -> D.Geometry {
        let mask = mask()
        if inverted {
            intersecting(mask).adding(operations(self).subtracting(mask))
        } else {
            subtracting(mask).adding(operations(self).intersecting(mask))
        }
    }
}

public extension Geometry2D {
    /// Applies additional operations only within a specified region, preserving the original geometry outside.
    ///
    /// This is a variant of `whileMasked(using:do:)` that uses axis-aligned bounds for masking.
    /// It allows you to modify a portion of the shape while leaving the rest untouched.
    /// Useful for local changes such as translating or rounding part of a shape.
    ///
    /// - Parameters:
    ///   - x: Optional range along the x-axis for the masked region. If `nil`, the mask is unbounded in x.
    ///   - y: Optional range along the y-axis for the masked region. If `nil`, the mask is unbounded in y.
    ///   - inverted: If `true`, inverts the mask logic so that the operations are applied to the complement of the bounded region
    ///               (outside the mask). If `false` (default), operations are applied only inside the bounded region.
    ///   - operations: A closure that receives the full geometry and returns a new geometry to be inserted within the masked region (or its complement if `inverted` is `true`).
    ///
    func whileMasked(
        x: (any WithinRange)? = nil,
        y: (any WithinRange)? = nil,
        inverted: Bool = false,
        @GeometryBuilder<D> do operations: @Sendable @escaping (D.Geometry) -> D.Geometry
    ) -> D.Geometry {
        measuringBounds { _, bounds in
            whileMasked(inverted: inverted, using: {
                bounds.within(x: x, y: y).mask
            }, do: operations)
        }
    }
}


public extension Geometry3D {
    /// Applies additional operations only within a specified 3D region, preserving the original geometry outside.
    ///
    /// This is a variant of `whileMasked(using:do:)` that uses axis-aligned bounds for masking.
    /// It allows you to perform localized transformations within a specified 3D subregion.
    ///
    /// - Parameters:
    ///   - x: Optional range along the x-axis for the masked region. If `nil`, the mask is unbounded in x.
    ///   - y: Optional range along the y-axis for the masked region. If `nil`, the mask is unbounded in y.
    ///   - z: Optional range along the z-axis for the masked region. If `nil`, the mask is unbounded in z.
    ///   - inverted: If `true`, inverts the mask logic so that the operations are applied to the complement of the bounded region
    ///               (outside the mask). If `false` (default), operations are applied only inside the bounded region.
    ///   - operations: A closure that receives the full geometry and returns a new geometry to be inserted within the masked region (or its complement if `inverted` is `true`).
    ///
    func whileMasked(
        x: (any WithinRange)? = nil,
        y: (any WithinRange)? = nil,
        z: (any WithinRange)? = nil,
        inverted: Bool = false,
        @GeometryBuilder<D> do operations: @Sendable @escaping (D.Geometry) -> D.Geometry
    ) -> D.Geometry {
        measuringBounds { _, bounds in
            whileMasked(inverted: inverted, using: {
                bounds.within(x: x, y: y, z: z).mask
            }, do: operations)
        }
    }
}
