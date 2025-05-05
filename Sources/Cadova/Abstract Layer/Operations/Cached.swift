import Foundation

extension Geometry {
    /// Caches this geometry under a specified name and optional parameters.
    ///
    /// Use this method to optimize complex or expensive geometry by wrapping it in a caching layer.
    /// Caching helps avoid redundant computation of both the geometry node and the underlying primitive data.
    ///
    /// The operation is cached based on the supplied `name` and `parameters`. If the same
    /// combination of name and cache parameters has been previously evaluated, the cached result is reused
    /// to avoid redundant computation. Ensure that these parameters are stable and deterministic;
    /// the same set of name + parameters should always result in an identical operation.
    ///
    /// - Parameters:
    ///   - name: A descriptive name identifying the cached geometry operation.
    ///   - cacheKeys: Additional values that influence caching behavior.
    /// - Returns: A new, cached version of this geometry.
    ///
    func cached(as name: String, parameters cacheKeys: any CacheKey...) -> D.Geometry {
        CachedBoxedGeometry<D, _, D>(key: NamedCacheKey(operationName: name, parameters: cacheKeys), geometry: nil) {
            self
        }
    }

    /// Caches this geometry under a specified name, including another geometry as part of the cache identity.
    ///
    /// Use this method when the result of the geometry depends on another input geometry that should
    /// be included in the cache key. This ensures that changes to the input geometry will invalidate
    /// the cache appropriately.
    ///
    /// This overload takes an explicit `geometry` parameter, which is incorporated into the cache key,
    /// allowing for more granular cache invalidation when dependent geometries change.
    ///
    /// - Parameters:
    ///   - name: A descriptive name identifying the cached geometry operation.
    ///   - geometry: A geometry input that contributes to the cache identity.
    ///   - cacheKeys: Additional values that influence caching behavior.
    /// - Returns: A new, cached version of this geometry.
    func cached<CD: Dimensionality>(as name: String, geometry: any Geometry<CD>, parameters cacheKeys: any CacheKey...) -> D.Geometry {
        CachedBoxedGeometry(key: NamedCacheKey(operationName: name, parameters: cacheKeys), geometry: geometry) {
            self
        }
    }
}
