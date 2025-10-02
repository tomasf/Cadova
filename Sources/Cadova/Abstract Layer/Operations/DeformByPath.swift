import Foundation

public extension Geometry2D {
    /// Deforms 2D geometry by offsetting Y as a function of X using a parametric curve.
    ///
    /// The input `path` is interpreted as a function `y(x)`. Each point `(x, y)` along the curve
    /// indicates that when the geometry is at X = `x`, it is offset along Y by `y`.
    /// This produces smooth bends, tapers, or other shape variations along the X-axis.
    ///
    /// - Important: The curve must be monotonic in X across the geometry’s domain.
    ///
    /// - Parameter curve: A parametric curve interpreted as `(x, y(x))`.
    /// - Returns: A 2D geometry deformed so that Y is offset according to the provided function of X.
    ///
    func deformed<Curve: ParametricCurve<Vector2D>>(by curve: Curve) -> D.Geometry {
        measuringBounds { body, bounds in
            @Environment(\.segmentation) var segmentation
            let min = curve.parameter(matching: bounds.minimum.x, along: .x) ?? curve.domain.lowerBound
            let max = curve.parameter(matching: bounds.maximum.x, along: .x) ?? curve.domain.upperBound
            let approximateLength = curve.length(in: min...max, segmentation: .fixed(curve.sampleCountForLengthApproximation))
            let segmentCount = segmentation.segmentCount(length: approximateLength)
            let segmentLength = bounds.size.x / Double(segmentCount)

            refined(maxEdgeLength: segmentLength)
                .warped(operationName: "deformByPath", cacheParameters: curve, segmentation) {
                    (0...segmentCount).map {
                        let value = bounds.minimum.x + bounds.size.x * Double($0) / Double(segmentCount)
                        guard let parameter = curve.parameter(matching: value, along: .x) else {
                            preconditionFailure("Failed to locate X = \(value) along curve. Make sure the curve is monotonic along the X axis and valid for all X values in the geometry.")
                        }
                        var point = curve.point(at: parameter)
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
    /// Deforms 3D geometry by offsetting X and Y as a function of Z using a parametric curve.
    ///
    /// The input `curve` is interpreted as a function `(dx(z), dy(z), z)`. Each point `(x, y, z)` along the curve
    /// indicates that when the geometry is at Z = `z`, it is offset along X by `x` and along Y by `y`.
    /// This produces smooth bends, tapers, or flowing deformations that vary along the Z-axis.
    ///
    /// - Important: The curve must be monotonic in Z across the geometry’s domain.
    ///
    /// - Parameter curve: A parametric curve interpreted as `(dx(z), dy(z), z)`.
    /// - Returns: A 3D geometry deformed so that X/Y are offset according to the provided function of Z.
    ///
    func deformed<Curve: ParametricCurve<Vector3D>>(by curve: Curve) -> D.Geometry {
        measuringBounds { body, bounds in
            @Environment(\.segmentation) var segmentation
            let min = curve.parameter(matching: bounds.minimum.z, along: .z) ?? curve.domain.lowerBound
            let max = curve.parameter(matching: bounds.maximum.z, along: .z) ?? curve.domain.upperBound
            let approximateLength = curve.length(in: min...max, segmentation: .fixed(curve.sampleCountForLengthApproximation))
            let segmentCount = segmentation.segmentCount(length: approximateLength)
            let segmentLength = bounds.size.z / Double(segmentCount)

            refined(maxEdgeLength: segmentLength)
                .warped(operationName: "deformByPath", cacheParameters: curve, segmentation) {
                    (0...segmentCount).map {
                        let value = bounds.minimum.z + bounds.size.z * Double($0) / Double(segmentCount)
                        guard let parameter = curve.parameter(matching: value, along: .z) else {
                            preconditionFailure("Failed to locate Z = \(value) along curve. Make sure the curve is monotonic along the Z axis and valid for all Z values in the geometry.")
                        }
                        var point = curve.point(at: parameter)
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

    /// Deforms 3D geometry by offsetting Y as a function of X using a 2D parametric curve.
    ///
    /// The input `curve` is interpreted as a scalar offset function y(x): each point `(x, y)`
    /// means “at source X = x, offset along Y by y”. This is useful for adding bends,
    /// tapers, and smooth warps that vary across the X axis while leaving Z unchanged.
    ///
    /// - Important: The curve must be monotonic in X across the geometry’s X‑span so that sampling is well‑defined.
    ///
    /// - Parameter curve: A 2D parametric curve interpreted as `(x, y(x))`.
    /// - Returns: A 3D geometry deformed so that Y is offset according to the provided function of X.
    ///
    /// - SeeAlso: ``deformed(by:)``
    ///
    func deformed<Curve: ParametricCurve<Vector2D>>(by curve: Curve) -> any Geometry3D {
        rotated(y: -90°)
            .deformed(by: curve.mapPoints { Vector3D(0, $0.y, $0.x) })
            .rotated(y: 90°)
    }
}
