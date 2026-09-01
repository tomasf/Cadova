import Foundation

/// A `Geometry` that automatically caches its built result, keyed by reflecting over its own
/// stored properties.
///
/// Each stored property is classified automatically:
/// - An `@Environment`-wrapped property contributes its resolved value (read once, at build time)
///   to the key. The wrapped type must itself be `Hashable` and `Codable`.
/// - A `Geometry`-typed property contributes the built identity of that geometry.
/// - Any other property must conform to `Hashable` and `Codable`.
///
/// A property that fits none of these traps at runtime with a message naming the offending
/// property. Only directly-typed `Geometry`/`@Environment` stored properties are recognized.
/// Arrays or optionals of `Geometry`, for instance, fall through to the `Hashable & Codable` case
/// and will trap unless the wrapping type itself happens to conform to that.
///
/// A `CachedGeometry`'s `body` runs at most once per distinct key within a single top-level build;
/// later requests with an equal key reuse the previously produced result, including its result
/// elements (parts, tags, anchors, etc.), instead of rebuilding `body`.
///
/// > Important: It's your responsibility to make sure your stored properties, together with any
/// > `@Environment` values you expose as properties, fully and correctly identify the
/// > geometry `body` produces. The key is derived purely from what reflection can see on your
/// > type; nothing checks that it actually distinguishes different outputs. If two instances that
/// > would build different geometry end up with the same key, the second one silently reuses the
/// > first instance's result instead of building its own.
///
/// The most common way to violate this: `body` reads an environment value that isn't also exposed
/// as a stored `@Environment` property. Only stored properties are reflected into the key, so a
/// read like that is invisible to caching: a build that should produce different geometry under
/// a different environment will instead reuse a stale cached result. The same goes for anything
/// else `body` depends on: if it isn't a stored property on your type, it isn't part of the key.
///
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
