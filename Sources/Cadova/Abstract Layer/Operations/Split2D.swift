import Foundation

public extension Geometry2D {
    /// Splits the geometry into two parts along the specified line.
    ///
    /// This method slices the geometry in two using a given line and passes the resulting parts
    /// to a closure for further transformation or arrangement.
    ///
    /// - Parameters:
    ///   - line: The `Line2D` used to split the geometry.
    ///   - reader: A closure that receives the two resulting geometry parts (on opposite sides of the line)
    ///             and returns a new composed geometry. The first geometry is the side facing the clockwise
    ///             normal of the line (right side relative to the line's direction).
    ///
    /// - Returns: A new geometry resulting from the closure.
    ///
    /// ## Example
    /// ```swift
    /// Circle(diameter: 10)
    ///     .split(along: Line2D(point: [0, 2], direction: .x)) { a, b in
    ///         a.colored(.red)
    ///         b.colored(.blue)
    ///     }
    /// ```
    ///
    func split(
        along line: Line2D,
        @GeometryBuilder2D reader: @Sendable @escaping (_ right: any Geometry2D, _ left: any Geometry2D) -> any Geometry2D
    ) -> any Geometry2D {
        reader(trimmed(along: line), trimmed(along: line.flipped))
    }

    /// Trims the geometry along the specified line, keeping only the portion on the clockwise side.
    ///
    /// This method behaves like a one-sided split: it cuts the geometry by a line and removes everything
    /// on the opposite side. The result is the portion of the geometry that remains on the clockwise side
    /// of the line (right side relative to the line's direction).
    ///
    /// - Parameter line: The `Line2D` defining the trimming boundary.
    /// - Returns: A new geometry containing only the portion on the clockwise side of the line.
    ///
    /// ## Example
    /// ```swift
    /// Circle(diameter: 10)
    ///     .trimmed(along: Line2D.y)  // Keeps the right half
    /// ```
    ///
    func trimmed(along line: Line2D) -> any Geometry2D {
        measuringBounds { geometry, box in
            let mask = buildTrimMask(for: box, along: line)
            geometry.intersecting { mask }
        }
    }
}

private func buildTrimMask(for box: BoundingBox2D, along line: Line2D) -> Polygon {
    let margin = 1.0
    let expandedMin = box.minimum - Vector2D(margin, margin)
    let expandedMax = box.maximum + Vector2D(margin, margin)

    let corners = [
        expandedMin,
        Vector2D(expandedMax.x, expandedMin.y),
        expandedMax,
        Vector2D(expandedMin.x, expandedMax.y)
    ]

    // Project corners onto the line direction to find extent
    let projections = corners.map { corner in
        (corner - line.point) ⋅ line.direction.unitVector
    }
    let minT = projections.min()! - margin
    let maxT = projections.max()! + margin

    // Line endpoints within the bounding box
    let lineStart = line.point(at: minT)
    let lineEnd = line.point(at: maxT)

    // Extend perpendicular to the line (clockwise normal side)
    let normal = line.direction.clockwiseNormal.unitVector
    let extent = (expandedMax - expandedMin).magnitude + margin

    // Build a quad covering the clockwise side of the line
    return Polygon([
        lineStart,
        lineEnd,
        lineEnd + normal * extent,
        lineStart + normal * extent
    ])
}
