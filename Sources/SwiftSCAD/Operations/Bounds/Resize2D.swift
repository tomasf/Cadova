import Foundation

/// Describes how a geometry's dimensions should be adjusted during a resize operation.
public enum ResizeBehavior {
    /// Maintains the current dimension value unchanged, regardless of other resizing factors.
    case fixed
    /// Adjusts the dimension proportionally based on the ratio of the target size to the original size.
    case proportional

    internal func value(current: Double, from: Double, to: Double) -> Double {
        switch self {
        case .fixed: return current
        case .proportional: return (to / from) * current
        }
    }
}

public extension Geometry2D {
    private func resized(_ alignment: GeometryAlignment2D, _ calculator: @escaping (Vector2D) -> Vector2D) -> any Geometry2D {
        return measuringBounds { geometry, box in
            geometry
                .translated(-box.minimum - alignment.factors * box.size)
                .scaled(calculator(box.size) / box.size)
                .translated(box.minimum + alignment.factors * box.size)
        }
    }

    /// Resizes the geometry to specific dimensions.
    /// - Parameters:
    ///   - x: The target size in the X direction.
    ///   - y: The target size in the Y direction.
    ///   - alignment: Determines the reference point for the geometry's position during resizing. Aligning affects how the geometry is repositioned to maintain its alignment relative to its bounding box after resizing. For example, `.center` keeps the geometry centered around its original center point, while `.top` ensures the top edge remains aligned with the geometry's original top edge position. By default, a geometry is resized relative to its origin.
    /// - Returns: A new geometry resized and repositioned according to the specified dimensions and alignment.

    func resized(x: Double, y: Double, alignment: GeometryAlignment2D...) -> any Geometry2D {
        resized(alignment.merged) { _ in [x, y] }
    }

    /// Resizes the geometry in the X direction with an optional behavior in the Y direction.
    /// - Parameters:
    ///   - x: The target size in the X direction.
    ///   - y: The resize behavior for the Y direction, either fixed or proportional to the X direction resizing.
    ///   - alignment: Determines the reference point for the geometry's position during resizing. Aligning affects how the geometry is repositioned to maintain its alignment relative to its bounding box after resizing. For example, `.center` keeps the geometry centered around its original center point, while `.top` ensures the top edge remains aligned with the geometry's original top edge position. By default, a geometry is resized relative to its origin.
    /// - Returns: The geometry, resized and repositioned according to the specified criteria.

    func resized(x: Double, y: ResizeBehavior = .fixed, alignment: GeometryAlignment2D...) -> any Geometry2D {
        resized(alignment.merged) { currentSize in
            Vector2D(x, y.value(current: currentSize.y, from: currentSize.x, to: x))
        }
    }

    /// Resizes the geometry in the Y direction with an optional behavior in the X direction.
    /// - Parameters:
    ///   - x: The resize behavior for the X direction.
    ///   - y: The target size in the Y direction.
    ///   - alignment: Determines the reference point for the geometry's position during resizing. Aligning affects how the geometry is repositioned to maintain its alignment relative to its bounding box after resizing. For example, `.center` keeps the geometry centered around its original center point, while `.top` ensures the top edge remains aligned with the geometry's original top edge position. By default, a geometry is resized relative to its origin.
    /// - Returns: The geometry, resized and repositioned according to the specified criteria.

    func resized(x: ResizeBehavior = .fixed, y: Double, alignment: GeometryAlignment2D...) -> any Geometry2D {
        resized(alignment.merged) { currentSize in
            Vector2D(x.value(current: currentSize.x, from: currentSize.y, to: y), y)
        }
    }
}
