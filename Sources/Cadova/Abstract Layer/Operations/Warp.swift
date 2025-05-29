import Foundation

internal extension Geometry {
    func warped(
        operationName name: String,
        cacheParameters params: [any Hashable & Sendable & Codable],
        transform: @Sendable @escaping (D.Vector) -> D.Vector
    ) -> D.Geometry {
        CachedConcreteTransformer(body: self, key: NamedCacheKey(operationName: name, parameters: params)) {
            $0.warp(transform)
        }
    }

    func warped<Shared>(
        operationName name: String,
        cacheParameters params: any Hashable & Sendable & Codable...,
        initialization: @Sendable @escaping () -> Shared,
        transform: @Sendable @escaping (D.Vector, Shared) -> D.Vector
    ) -> D.Geometry {
        CachedConcreteTransformer(body: self, key: NamedCacheKey(operationName: name, parameters: params)) {
            let initData = initialization()
            return $0.warp { v in
                transform(v, initData)
            }
        }
    }
}

public extension Geometry {
    /// Returns a new geometry by applying a custom point-wise transformation to the geometry.
    ///
    /// This method allows you to arbitrarily warp or deform a geometry by providing a transformation closure that maps
    /// each point in the shape to a new location.
    ///
    /// The operation is cached based on the supplied `operationName` and `cacheParameters`. If the same
    /// combination of input geometry and cache parameters has been previously evaluated, the cached result is reused
    /// to avoid redundant computation. Ensure that these parameters are stable and deterministic; the same set of name + parameters should always result in an identical operation.
    ///
    /// - Parameters:
    ///   - name: A string identifying the transformation operation. Used as part of the cache key.
    ///   - params: Optional parameters that further define the transformation. These should be values that uniquely
    ///             describe the warp operation so that results can be cached correctly.
    ///   - transform: A closure that takes a point in the original geometry and returns a new, transformed point.
    ///
    /// - Returns: A new warped geometry with the transformation applied.
    ///
    /// - Example:
    /// ```swift
    /// let wavy = Circle(radius: 10).warped(
    ///     operationName: "ripple",
    ///     cacheParameters: amplitude, frequency
    /// ) {
    ///     var p = $0
    ///     p.z += sin(p.x * frequency) * amplitude
    ///     return p
    /// }
    /// ```
    ///
    func warped(
        operationName name: String,
        cacheParameters params: any Hashable & Sendable & Codable...,
        transform: @Sendable @escaping (D.Vector) -> D.Vector
    ) -> D.Geometry {
        warped(operationName: name, cacheParameters: params, transform: transform)
    }
}
