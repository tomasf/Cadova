import Foundation

public extension Geometry2D {
    /// Skews the geometry by repositioning the corners of its bounding rectangle.
    ///
    /// This method lets you move one or more corners of the geometry’s bounding box to new positions.
    /// The geometry is then smoothly warped to match the new shape using bilinear interpolation.
    ///
    /// Any corner you don’t specify will stay at its original location.
    ///
    /// - Parameters:
    ///   - minXminY: New position for the lower-left corner (optional).
    ///   - maxXminY: New position for the lower-right corner (optional).
    ///   - maxXmaxY: New position for the upper-right corner (optional).
    ///   - minXmaxY: New position for the upper-left corner (optional).
    /// - Returns: A new, skewed geometry.
    ///
    /// ```swift
    /// Circle(diameter: 10)
    ///     .skewingCorners(
    ///         minXminY: Vector2D(-7, -3),
    ///         maxXmaxY: Vector2D(12, 6)
    ///     )
    /// ```
    func skewingCorners(
        bottomLeft minXminY: Vector2D? = nil,
        bottomRight maxXminY: Vector2D? = nil,
        topRight maxXmaxY: Vector2D? = nil,
        topLeft minXmaxY: Vector2D? = nil
    ) -> any Geometry2D {
        measuringBounds { _, bounds in
            let original: [Vector2D] = [
                Vector2D(bounds.minimum.x, bounds.minimum.y),
                Vector2D(bounds.maximum.x, bounds.minimum.y),
                Vector2D(bounds.maximum.x, bounds.maximum.y),
                Vector2D(bounds.minimum.x, bounds.maximum.y)
            ]

            let target: [Vector2D] = [
                minXminY ?? original[0],
                maxXminY ?? original[1],
                maxXmaxY ?? original[2],
                minXmaxY ?? original[3]
            ]

            skewingCorners(from: original, to: target)
        }
    }

    /// Skews the geometry by offsetting the corners of its bounding rectangle.
    ///
    /// This is like `skewingCorners`, but you provide **relative offsets** instead of absolute positions.
    ///
    /// - Parameters:
    ///   - minXminY: Offset to apply to the lower-left corner (optional).
    ///   - maxXminY: Offset to apply to the lower-right corner (optional).
    ///   - maxXmaxY: Offset to apply to the upper-right corner (optional).
    ///   - minXmaxY: Offset to apply to the upper-left corner (optional).
    /// - Returns: A new, skewed geometry.
    func skewingCorners(
        relativeBottomLeft minXminY: Vector2D = .zero,
        relativeBottomRight maxXminY: Vector2D = .zero,
        relativeTopRight maxXmaxY: Vector2D = .zero,
        relativeTopLeft minXmaxY: Vector2D = .zero
    ) -> any Geometry2D {
        measuringBounds { _, bounds in
            let original = [
                Vector2D(bounds.minimum.x, bounds.minimum.y), Vector2D(bounds.maximum.x, bounds.minimum.y),
                Vector2D(bounds.maximum.x, bounds.maximum.y), Vector2D(bounds.minimum.x, bounds.maximum.y)
            ]

            let target: [Vector2D] = [
                original[0] + minXminY,
                original[1] + maxXminY,
                original[2] + maxXmaxY,
                original[3] + minXmaxY
            ]
            skewingCorners(from: original, to: target)
        }
    }
}

internal extension Geometry2D {
    func skewingCorners(from source: [Vector2D], to destination: [Vector2D]) -> any Geometry2D {
        assert(source.count == 4 && destination.count == 4)

        let min = Vector2D(source.map(\.x).min()!, source.map(\.y).min()!)
        let max = Vector2D(source.map(\.x).max()!, source.map(\.y).max()!)
        let delta = max - min
        guard delta.x > 1e-8, delta.y > 1e-8 else { return self }

        return warped(operationName: "skewCorners", cacheParameters: source, destination) { point in
            let t = (point - min) / delta
            let c0 = lerp(destination[0], destination[1], t: t.x)
            let c1 = lerp(destination[3], destination[2], t: t.x)
            return lerp(c0, c1, t: t.y)
        }
    }
}
