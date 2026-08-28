import Foundation

/// A `Geometry` that caches its built result automatically, keyed by reflecting over its own
/// stored properties.
///
/// Each stored property is classified automatically:
/// - An `@Environment`-wrapped property contributes its resolved value (read once, at build time)
///   to the key. The wrapped type must itself be `Hashable` and `Codable`.
/// - A `Geometry`-typed property contributes the built identity of that geometry.
/// - Any other property must conform to `Hashable` and `Codable`.
///
/// A property that fits none of these traps at runtime with a message naming the offending
/// property.
///
/// Only directly-typed `Geometry`/`@Environment` stored properties are recognized. Arrays or
/// optionals of `Geometry`, for instance, fall through to the `CacheKey` case and will trap unless
/// the wrapping type itself happens to conform to `CacheKey`.
///
/// Only stored properties determine the key: if `body` composes another operation that itself
/// reads environment values, that dependency is not automatically captured. Expose it yourself
/// as a stored `@Environment` property on your own type if it should vary the key.
///
/// A `CachedGeometry`'s `body` runs at most once per distinct key within a single top-level build;
/// later requests with an equal key reuse the previously produced result, including its result
/// elements (`.inPart` assignments, tags/anchors, `only()` isolation), instead of rebuilding
/// `body`.
///
/// Unlike `CachedNode`, `body` here runs eagerly (as soon as a distinct key is first built) rather
/// than being deferred until the resulting mesh is actually realized, since result elements have
/// to be known synchronously wherever the rest of the geometry pipeline reads them. Mesh
/// evaluation itself is still deduplicated separately, keyed on the node `body` produces.
///
public protocol CachedGeometry<D>: Geometry {}

/// A `CachedGeometry` producing two-dimensional geometry.
public typealias CachedGeometry2D = CachedGeometry<D2>

/// A `CachedGeometry` producing three-dimensional geometry.
public typealias CachedGeometry3D = CachedGeometry<D3>

public extension CachedGeometry {
    func _build(in environment: EnvironmentValues, context: _EvaluationContext) async throws -> _BuildResult<D> {
        let key = try await ReflectedCacheKey(reflecting: self, in: environment, context: context)
        return try await context.cachedBodyResult(key: key) {
            try await context.buildResult(for: body, in: environment)
        }
    }
}
