import Foundation

internal extension Geometry3D {
    func repeatedInternal<Path: D3.Curve>(
        along path: Path,
        target: ReferenceTarget?,
        reference: Direction2D,
        calculator: @escaping @Sendable (_ pathLength: Double) -> (count: Int, spacing: Double)
    ) -> any Geometry3D {
        measuringBounds { _, bounds in
            @Environment var environment
            let frames = path.frames(
                environment: environment,
                target: target ?? .direction(.down),
                targetReference: reference,
                perpendicularBounds: bounds.bounds2D
            )

            let pathLength = frames.last!.distance
            let (count, spacing) = calculator(pathLength)

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

public extension Geometry3D {
    /// Repeats a 3D geometry along a path.
    ///
    /// This function places multiple copies of the geometry along a path, spaced evenly. If `target` is provided,
    /// each instance is oriented so that the geometry's local positive Z-axis points forward along the path
    /// direction. The rotation around the Z-axis is determined by the `target` and `reference` parameters:
    ///
    /// `reference` defines a direction in the geometry's local XY-plane, and `target` specifies what that
    /// direction should align with at each point along the path. If `target` is `nil`, then the geometry is not
    /// rotated, only translated along the path.
    ///
    /// - Parameters:
    ///   - path: The ParametricCurve to follow.
    ///   - target: The optional direction or point to align the geometry with, controlling rotation around the
    ///             Z-axis. If `nil`, the geometry is only translated.
    ///   - reference: A local 2D direction in the XY-plane of the geometry used to resolve rotation when `target`
    ///                is specified. Defaults to `.down`.
    ///   - count: The number of instances to repeat.
    ///   - spacing: The distance between the origin of each instance along the path.
    /// - Returns: A composite 3D geometry containing all repeated instances.
    ///
    func repeated<Path: ParametricCurve>(
        along path: Path,
        target: ReferenceTarget? = nil,
        reference: Direction2D = .down,
        count: Int,
        spacing: Double
    ) -> any Geometry3D {
        repeatedInternal(along: path.curve3D, target: target, reference: reference) { _ in (count, spacing) }
    }

    /// Repeats a 3D geometry along a path using an exact instance count.
    ///
    /// The geometry is placed `count` times from the beginning to the end of the path. The spacing is computed
    /// from the actual path length so that the first instance sits at distance `0` and the last sits exactly at
    /// the end of the path. If `target` is provided, each instance is oriented to face the path direction and
    /// then rotated so the local `reference` direction aligns with the `target`. If `target` is `nil`, instances
    /// are only translated.
    ///
    /// - Parameters:
    ///   - path: The ParametricCurve to follow.
    ///   - target: Optional orientation target used to resolve rotation around the path tangent. If `nil`,
    ///             instances are not rotated.
    ///   - reference: A local 2D direction used with `target` to resolve roll about the tangent. Defaults to
    ///                `.down`.
    ///   - count: The number of instances to place. Must be ≥ 2 so the first and last land on the path ends.
    /// - Returns: A composite 3D geometry containing all instances.
    ///
    func repeated<Path: ParametricCurve>(
        along path: Path,
        target: ReferenceTarget? = nil,
        reference: Direction2D = .down,
        count: Int
    ) -> any Geometry3D {
        precondition(count >= 2, "Repeating along a path without an explicit spacing requires at least two instances.")

        return repeatedInternal(along: path.curve3D, target: target, reference: reference) {
            (count, $0 / Double(count - 1))
        }
    }

    /// Repeats a 3D geometry along a path using a fixed spacing.
    ///
    /// The geometry is placed at distances `0, spacing, 2*spacing, ...` up to (but not exceeding) the path
    /// length. If `target` is provided, each instance is oriented to face the path direction and then
    /// rotated so the local `reference` direction aligns with the `target`. If `target` is `nil`, instances
    /// are only translated.
    ///
    /// - Parameters:
    ///   - path: The ParametricCurve to follow.
    ///   - target: Optional orientation target used to resolve rotation around the path tangent. If `nil`,
    ///             instances are not rotated.
    ///   - reference: A local 2D direction used with `target` to resolve roll about the tangent. Defaults
    ///                to `.down`.
    ///   - spacing: The distance between successive instances along the path. Must be > 0.
    /// - Returns: A composite 3D geometry containing all instances.
    ///
    func repeated<Path: ParametricCurve>(
        along path: Path,
        target: ReferenceTarget? = nil,
        reference: Direction2D = .down,
        spacing: Double
    ) -> any Geometry3D {
        precondition(spacing > 0, "Spacing needs to be greater than zero.")

        return repeatedInternal(along: path.curve3D, target: target, reference: reference) {
            (Int(floor($0 / spacing)), spacing)
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
    ///   - path: The 2D ParametricCurve to follow.
    ///   - rotating: If `true`, each instance is rotated to align with the path direction (default is `true`).
    ///   - count: The number of instances to repeat.
    ///   - spacing: The distance between each instance along the path.
    /// - Returns: A 2D composite geometry containing all repeated instances.
    ///
    func repeated<Path: ParametricCurve<Vector2D>>(
        along path: Path,
        rotating: Bool = true,
        count: Int,
        spacing: Double
    ) -> any Geometry2D {
        measuringBounds { _, bounds in
            @Environment var environment
            let frames = path.curve3D.frames(
                environment: environment,
                target: .direction(.down),
                targetReference: .down,
                perpendicularBounds: nil
            )

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
