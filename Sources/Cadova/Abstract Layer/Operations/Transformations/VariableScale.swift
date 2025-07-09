import Foundation

public extension Geometry3D {
    /// Scales the geometry along a specified axis based on a user-defined scaling function.
    ///
    /// This method applies a non-uniform, dynamic scaling to the geometry by evaluating a closure
    /// that specifies how much to scale based on the position along the given axis.
    /// Only the existing vertices are transformed; no new points are inserted automatically.
    /// For best results, you should refine the geometry first if smoothness is important.
    ///
    /// The returned `Vector2D` specifies how the other two axes are scaled:
    /// - If scaling along `.x`, the `.y` and `.z` axes are scaled according to `Vector2D(x: ..., y: ...)`
    /// - If scaling along `.y`, the `.x` and `.z` axes are scaled
    /// - If scaling along `.z`, the `.x` and `.y` axes are scaled
    ///
    /// - Parameters:
    ///   - axis: The axis along which the scaling function is evaluated.
    ///   - operationName: A descriptive name used for caching.
    ///   - params: Parameters that influence the scaling, used in the cache key.
    ///   - scale: A closure that returns a `Vector2D` representing the scale factors for the two other axes.
    /// - Returns: A new geometry with dynamic, per-point scaling applied.
    ///
    /// ## Example
    /// Create a sinusoidal bulge along the Z axis:
    ///
    /// ```swift
    /// extension Geometry3D {
    ///     func sinusoidallyScaled(in scaleRange: Range<Double>, period: Double) -> any Geometry3D {
    ///         refined(maxEdgeLength: 0.5)
    ///             .scaled(along: .z, operationName: "sinusoidallyScaled", cacheParameters: scaleRange, period) { z in
    ///                 let t = (sin(z * 360° / period) + 1) * 0.5
    ///                 let scale = scaleRange.lowerBound + t * (scaleRange.upperBound - scaleRange.lowerBound)
    ///                 return Vector2D(scale, scale)
    ///             }
    ///             .simplified()
    ///     }
    /// }
    /// ```
    func scaled(
        along axis: Axis3D,
        operationName: String,
        cacheParameters params: any Hashable & Sendable & Codable...,
        scale: @Sendable @escaping (Double) -> Vector2D
    ) -> any Geometry3D {
        warped(operationName: operationName, cacheParameters: params) { point in
            let value = point[axis]
            let scaleFactors = scale(value)

            return switch axis {
            case .x: Vector3D(point.x, point.y * scaleFactors.x, point.z * scaleFactors.y)
            case .y: Vector3D(point.x * scaleFactors.x, point.y, point.z * scaleFactors.y)
            case .z: Vector3D(point.x * scaleFactors.x, point.y * scaleFactors.y, point.z)
            }
        }
    }

    /// Scales the geometry uniformly along both axes perpendicular to the specified axis,
    /// based on a user-defined scaling function.
    ///
    /// Only the existing vertices are transformed; consider refining the geometry beforehand
    /// if higher smoothness is desired.
    ///
    /// - Parameters:
    ///   - axis: The axis along which scaling is evaluated.
    ///   - operationName: A descriptive name for caching.
    ///   - params: Parameters influencing the scaling, included in the cache key.
    ///   - scale: A closure returning a `Double` scale factor applied to both perpendicular axes.
    /// - Returns: A new geometry with dynamic uniform scaling applied.
    func scaled(
        along axis: Axis3D,
        operationName: String,
        cacheParameters params: any Hashable & Sendable & Codable...,
        scale: @Sendable @escaping (Double) -> Double
    ) -> any Geometry3D {
        warped(operationName: operationName, cacheParameters: params) { point in
            let scaleFactor = scale(point[axis])

            return switch axis {
            case .x: Vector3D(point.x, point.y * scaleFactor, point.z * scaleFactor)
            case .y: Vector3D(point.x * scaleFactor, point.y, point.z * scaleFactor)
            case .z: Vector3D(point.x * scaleFactor, point.y * scaleFactor, point.z)
            }
        }
    }
}

public extension Geometry2D {
    /// Scales the 2D geometry dynamically along one axis based on a user-defined scaling function.
    ///
    /// Only the existing vertices are transformed. For best results when significant deformation
    /// is expected, consider refining the geometry first.
    ///
    /// - Parameters:
    ///   - axis: The axis along which scaling is evaluated.
    ///   - operationName: A descriptive name for caching.
    ///   - params: Parameters influencing the scaling, included in the cache key.
    ///   - scale: A closure returning a `Double` representing the scale factor for the other axis.
    /// - Returns: A new geometry with axis-dependent scaling applied.
    ///
    func scaled(
        along axis: Axis2D,
        operationName: String,
        cacheParameters params: any Hashable & Sendable & Codable...,
        scale: @Sendable @escaping (Double) -> Double
    ) -> any Geometry2D {
        warped(operationName: operationName, cacheParameters: params) { point in
            let scaleFactor = scale(point[axis])

            return switch axis {
            case .x: Vector2D(point.x, point.y * scaleFactor)
            case .y: Vector2D(point.x * scaleFactor, point.y)
            }
        }
    }
}
