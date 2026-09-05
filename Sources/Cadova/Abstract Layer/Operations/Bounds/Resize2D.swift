import Foundation

/// Describes how a geometry's dimensions should be adjusted during a resize operation.
public enum ResizeBehavior: Sendable {
    /// Maintains the current dimension value unchanged, regardless of other resizing factors.
    case fixed
    /// Adjusts the dimension proportionally based on the ratio of the target size to the original size.
    case proportional

    internal func value(current: Double, from: Double, to: Double) -> Double {
        switch self {
        case .fixed:
            return current
        case .proportional:
            // Geometry with no extent along the driving axis has no ratio to scale by. Leaving this
            // dimension as it is keeps the geometry valid; dividing would make it infinite.
            guard from > .ulpOfOne else {
                logger.warning("""
                    Resizing proportionally to an axis with no extent (\(from)). \
                    That dimension is left unchanged.
                    """)
                return current
            }
            return (to / from) * current
        }
    }
}

internal extension BoundingBox {
    /// The per-axis factors that scale this box to `newSize`.
    ///
    /// An axis along which the box has no extent cannot be scaled to any particular size, so it is left
    /// alone rather than producing an infinite or undefined factor that would corrupt the whole transform.
    func scaleFactors(to newSize: D.Vector) -> D.Vector {
        D.Vector { axis in
            guard size[axis] > .ulpOfOne else {
                logger.warning("Resizing geometry with no extent along \(axis). That axis is left unchanged.")
                return 1
            }
            return newSize[axis] / size[axis]
        }
    }
}

/// Whether every requested resize target is a real length.
///
/// Resizing to zero used to scale by exactly zero, collapsing the geometry into a zero-volume mesh that
/// `measurements.isEmpty` still reported as solid; a negative length turns geometry inside out. Neither is
/// worth crashing over — parametric design produces non-positive intermediate values easily — so a resize
/// asked for an impossible size resolves to empty geometry, the way the primitives do.
internal func resizeTargetsAreValid(_ targets: (name: String, value: Double)...) -> Bool {
    var valid = true
    for target in targets where !(target.value > 0) {
        logger.warning("""
            Resize target \(target.name) must be greater than zero, but was \(target.value). \
            The resized geometry is empty.
            """)
        valid = false
    }
    return valid
}

public extension Geometry2D {
    private func resized(
        _ alignment: GeometryAlignment2D,
        calculator: @Sendable @escaping (Vector2D) -> Vector2D
    ) -> any Geometry2D {
        measuringBounds { geometry, box in
            // Every public overload checks the sizes it was handed, but a calculator produces them
            // here, after that check. Without this one, a calculator returning zero collapses the
            // geometry into exactly the zero-volume mesh the other overloads now refuse to make.
            let target = calculator(box.size)
            if resizeTargetsAreValid(("x", target.x), ("y", target.y)) {
                let translation = box.translation(for: alignment)
                geometry
                    .translated(translation)
                    .scaled(box.scaleFactors(to: target))
                    .translated(-translation)
            }
        }
    }

    /// Resizes the geometry to specific dimensions.
    /// - Parameters:
    ///   - x: The target size in the X direction. A value of zero or less results in empty geometry.
    ///   - y: The target size in the Y direction. A value of zero or less results in empty geometry.
    ///   - alignment: Determines the reference point for the geometry's position during resizing. Aligning affects how
    ///     the geometry is repositioned to maintain its alignment relative to its bounding box after resizing. For
    ///     example, `.center` keeps the geometry centered around its original center point, while `.top` ensures the
    ///     top edge remains aligned with the geometry's original top edge position. By default, a geometry is resized
    ///     relative to its origin.
    /// - Returns: A new geometry resized and repositioned according to the specified dimensions and alignment.

    @GeometryBuilder2D
    func resized(x: Double, y: Double, alignment: GeometryAlignment2D...) -> any Geometry2D {
        if resizeTargetsAreValid(("x", x), ("y", y)) {
            resized(alignment.merged.defaultingToOrigin()) { _ in [x, y] }
        }
    }

    /// Resizes the geometry in the X direction with an optional behavior in the Y direction.
    /// - Parameters:
    ///   - x: The target size in the X direction. A value of zero or less results in empty geometry.
    ///   - y: The resize behavior for the Y direction, either fixed or proportional to the X direction resizing.
    ///   - alignment: Determines the reference point for the geometry's position during resizing. Aligning affects how
    ///     the geometry is repositioned to maintain its alignment relative to its bounding box after resizing. For
    ///     example, `.center` keeps the geometry centered around its original center point, while `.top` ensures the
    ///     top edge remains aligned with the geometry's original top edge position. By default, a geometry is resized
    ///     relative to its origin.
    /// - Returns: The geometry, resized and repositioned according to the specified criteria.

    @GeometryBuilder2D
    func resized(x: Double, y: ResizeBehavior = .fixed, alignment: GeometryAlignment2D...) -> any Geometry2D {
        if resizeTargetsAreValid(("x", x)) {
            resized(alignment.merged.defaultingToOrigin()) { currentSize in
                Vector2D(x, y.value(current: currentSize.y, from: currentSize.x, to: x))
            }
        }
    }

    /// Resizes the geometry in the Y direction with an optional behavior in the X direction.
    /// - Parameters:
    ///   - x: The resize behavior for the X direction.
    ///   - y: The target size in the Y direction. A value of zero or less results in empty geometry.
    ///   - alignment: Determines the reference point for the geometry's position during resizing. Aligning affects how
    ///     the geometry is repositioned to maintain its alignment relative to its bounding box after resizing. For
    ///     example, `.center` keeps the geometry centered around its original center point, while `.top` ensures the
    ///     top edge remains aligned with the geometry's original top edge position. By default, a geometry is resized
    ///     relative to its origin.
    /// - Returns: The geometry, resized and repositioned according to the specified criteria.

    @GeometryBuilder2D
    func resized(x: ResizeBehavior = .fixed, y: Double, alignment: GeometryAlignment2D...) -> any Geometry2D {
        if resizeTargetsAreValid(("y", y)) {
            resized(alignment.merged.defaultingToOrigin()) { currentSize in
                Vector2D(x.value(current: currentSize.x, from: currentSize.y, to: y), y)
            }
        }
    }

    /// Resizes the geometry based on its current bounding box
    /// - Parameters:
    ///   - alignment: Determines the reference point for the geometry's position during resizing. Aligning affects how
    ///     the geometry is repositioned to maintain its alignment relative to its bounding box after resizing. For
    ///     example, aligning to `.center` maintains the geometry's center, while `.top` aligns with the top edge of
    ///     its original position. By default, a geometry is resized relative to its origin.
    ///   - calculator: A closure that accepts the current bounding box and returns the new size
    /// - Returns: A new geometry resized and aligned according to the specified behaviors and alignment.

    func resized(
        alignment: GeometryAlignment2D...,
        calculator: @Sendable @escaping (Vector2D) -> Vector2D
    ) -> any Geometry2D {
        resized(alignment.merged.defaultingToOrigin(), calculator: calculator)
    }
}
