import Foundation

public extension Geometry2D {
    /// Deforms 2D geometry by offsetting Y as a function of X using a Bézier path.
    ///
    /// The input `path` is interpreted as a function `y(x)`. Each point `(x, y)` along the path
    /// indicates that when the geometry is at X = `x`, it is offset along Y by `y`.
    /// This produces smooth bends, tapers, or other shape variations along the X-axis.
    ///
    /// - Important: The path must be monotonic in X across the geometry’s domain.
    ///
    /// - Parameter path: A Bézier path interpreted as `(x, y(x))`.
    /// - Returns: A 2D geometry deformed so that Y is offset according to the provided function of X.
    ///
    func deformed(by path: BezierPath<D.Vector>) -> D.Geometry {
        measuringBounds { body, bounds in
            @Environment(\.segmentation) var segmentation
            let min = path.position(for: bounds.minimum.x, in: .x) ?? 0
            let max = path.position(for: bounds.maximum.x, in: .x) ?? path.fractionRange.upperBound
            let approximateLength = path[ClosedRange(min, max)].approximateLength
            let segmentCount = segmentation.segmentCount(length: approximateLength)
            let segmentLength = bounds.size.x / Double(segmentCount)

            refined(maxEdgeLength: segmentLength)
                .warped(operationName: "deformByPath", cacheParameters: path, segmentation) {
                    (0...segmentCount).map {
                        let value = bounds.minimum.x + bounds.size.x * Double($0) / Double(segmentCount)
                        guard let position = path.position(for: value, in: .x) else {
                            preconditionFailure("Failed to locate X = \(value) along path. Make sure the path is monotonic along the X axis and valid for all X values in the geometry.")
                        }
                        var point = path[position]
                        let x = point.x
                        point.x = 0
                        return (x, point)
                    }
                } transform: {
                    $0 + $1.binarySearchInterpolate(key: $0.x)
                }
                .simplified()
        }
    }
}

public extension Geometry3D {
    /// Deforms 3D geometry by offsetting X and Y as a function of Z using a Bézier path.
    ///
    /// The input `path` is interpreted as a function `(dx(z), dy(z))`. Each point `(x, y, z)` along the path
    /// indicates that when the geometry is at Z = `z`, it is offset along X by `x` and along Y by `y`.
    /// This produces smooth bends, tapers, or flowing deformations that vary along the Z-axis.
    ///
    /// - Important: The path must be monotonic in Z across the geometry’s domain.
    ///
    /// - Parameter path: A Bézier path interpreted as `(dx(z), dy(z), z)`.
    /// - Returns: A 3D geometry deformed so that X/Y are offset according to the provided function of Z.
    ///
    func deformed(by path: BezierPath<D.Vector>) -> D.Geometry {
        measuringBounds { body, bounds in
            @Environment(\.segmentation) var segmentation
            let min = path.position(for: bounds.minimum.z, in: .z) ?? 0
            let max = path.position(for: bounds.maximum.z, in: .z) ?? path.fractionRange.upperBound
            let approximateLength = path[ClosedRange(min, max)].approximateLength
            let segmentCount = segmentation.segmentCount(length: approximateLength)
            let segmentLength = bounds.size.z / Double(segmentCount)

            refined(maxEdgeLength: segmentLength)
                .warped(operationName: "deformByPath", cacheParameters: path, segmentation) {
                    (0...segmentCount).map {
                        let value = bounds.minimum.z + bounds.size.z * Double($0) / Double(segmentCount)
                        guard let position = path.position(for: value, in: .z) else {
                            preconditionFailure("Failed to locate Z = \(value) along path. Make sure the path is monotonic along the Z axis and valid for all Z values in the geometry.")
                        }
                        var point = path[position]
                        let z = point.z
                        point.z = 0
                        return (z, point)
                    }
                } transform: {
                    $0 + $1.binarySearchInterpolate(key: $0.z)
                }
                .simplified()
        }
    }

    /// Deforms 3D geometry by offsetting Y as a function of X using a 2D Bézier path.
    ///
    /// The input `path` is interpreted as a scalar offset function y(x): each point `(x, y)`
    /// means “at source X = x, offset along Y by y”. This is useful for adding bends,
    /// tapers, and smooth warps that vary across the X axis while leaving Z unchanged.
    ///
    /// - Important: The path must be monotonic in X across the geometry’s X‑span so that sampling is well‑defined.
    ///
    /// - Parameter path: A 2D Bézier path interpreted as `(x, y(x))`.
    /// - Returns: A 3D geometry deformed so that Y is offset according to the provided function of X.
    ///
    /// - SeeAlso: ``deformed(by:)``
    ///
    func deformed(by path: BezierPath2D) -> any Geometry3D {
        rotated(y: -90°)
            .deformed(by: path.mapPoints { Vector3D(0, $0.y, $0.x) })
            .rotated(y: 90°)
    }
}
