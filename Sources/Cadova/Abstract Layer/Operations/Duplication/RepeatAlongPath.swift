import Foundation

public extension Geometry3D {
    /// Repeats a 3D geometry along a path.
    ///
    /// This function places multiple copies of the geometry along a path, spaced evenly,
    /// with each instance optionally aligned to a reference direction.
    ///
    /// - Parameters:
    ///   - path: The Bezier path to follow.
    ///   - target: The optional target direction or point to align each instance to. If `nil`,
    ///     the geometry is only translated, not rotated.
    ///   - reference: The 2D direction in the geometry that should align with the path direction (default is `.down`).
    ///                Ignored if `target` is nil.
    ///   - count: The number of instances to repeat.
    ///   - spacing: The distance between each instance along the path.
    /// - Returns: A composite 3D geometry containing all repeated instances.
    ///
    func repeated<V: Vector>(
        along path: BezierPath<V>,
        target: ReferenceTarget? = nil,
        reference: Direction2D = .down,
        count: Int,
        spacing: Double
    ) -> any Geometry3D {
        measureBoundsIfNonEmpty { _, e, bounds in
            let path = path.path3D.extendedToMinimumLength(Double(count) * spacing)
            let frames = path.frames(
                environment: e,
                target: target ?? .direction(.down),
                targetReference: reference,
                perpendicularBounds: bounds.bounds2D
            )

            for i in 0..<count {
                let distance = Double(i) * spacing
                var transform = frames.binarySearchInterpolate(target: distance, key: \.distance, result: \.transform)
                if target == nil {
                    transform = .translation(transform.offset)
                }
                self.transformed(transform)
            }
        }
    }
}

public extension Geometry2D {
    /// Repeats a 2D geometry along a 2D path.
    ///
    /// This function places multiple copies of the 2D geometry along a path, spaced evenly.
    /// Each instance can optionally be rotated to align with the path direction.
    ///
    /// - Parameters:
    ///   - path: The 2D Bezier path to follow.
    ///   - rotating: If `true`, each instance is rotated to align with the path direction (default is `true`).
    ///   - count: The number of instances to repeat.
    ///   - spacing: The distance between each instance along the path.
    /// - Returns: A 2D composite geometry containing all repeated instances.
    ///
    func repeated(
        along path: BezierPath2D,
        rotating: Bool = true,
        count: Int,
        spacing: Double
    ) -> any Geometry2D {
        measureBoundsIfNonEmpty { _, e, bounds in
            let path = path.path3D.extendedToMinimumLength(Double(count) * spacing)
            let frames = path.frames(environment: e, target: .direction(.down), targetReference: .down, perpendicularBounds: nil)

            for i in 0..<count {
                var transform = frames.binarySearchInterpolate(target: Double(i) * spacing, key: \.distance, result: \.transform)
                if rotating {
                    transform = Transform3D.rotation(x: -90°, y: -90°).concatenated(with: transform)
                } else {
                    transform = .translation(transform.offset)
                }
                self.transformed(Transform2D(transform))
            }
        }
    }
}

fileprivate extension BezierPath {
    func extendedToMinimumLength(_ length: Double) -> Self {
        var path = self
        while path.length(segmentation: .fixed(10)) < length {
            path = path[0..<(path.fractionRange.upperBound + 1)]
        }
        return path
    }
}
